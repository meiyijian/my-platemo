function Next = DiversifiedInfillSelection(Problem,Ref,Input,wmax,Smodel,ArchiveDec,n_min,n_max)
%DiversifiedInfillSelection Generate candidates and select an infill batch.
%   NEXT = DiversifiedInfillSelection(PROBLEM,REF,INPUT,WMAX,SMODEL,ARCHIVEDEC,N_MIN,N_MAX)
%   keeps the original relation-guided GA and indicator selection. Explore
%   mode uses archive maximin distance with at most six real evaluations.
%   ARCHIVEDEC contains all previously evaluated decision vectors.
    % 获取选择模式
    mode = 'conservative';
    if isfield(Smodel,'mode') && ~isempty(Smodel.mode)
        mode = Smodel.mode;
    end

    %% ============ 代理辅助 GA 内循环 ============
    % 使用 GA 生成候选解，然后用代理模型打分筛选
    % 保留关系得分较高的候选作为下一轮父代，同时累积所有生成的候选。
    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    all_candidates = Next;
    i = size(Next,1);

    while i < wmax && ~isempty(Next)
        % 用代理模型对候选解打分
        [sorted_index,~] = model_select(Smodel,Next);
        % 保留评分最好的 |Ref| 个候选
        keepNum = min(length(Ref),size(Next,1));
        if keepNum < 1
            break;
        end
        Input = Next(sorted_index(1:keepNum),:);
        % 用保留的候选继续 GA 生成新候选
        Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        all_candidates = [all_candidates;Next]; %#ok<AGROW>
        i = i + size(Next,1);
    end

    % 如果没有候选解，返回空
    if isempty(all_candidates)
        Next = [];
        return;
    end
    % 去重（保持顺序）
    all_candidates = unique(all_candidates,'rows','stable');

    %% ============ 根据模式选择最终候选 ============
    switch mode
        case 'indicator'
            % 指标模式：关系得分粗筛 + 可用时由 SVR 指标值重排序
            Next = IndicatorBasedInfill(Smodel,all_candidates,n_min,n_max);
        case 'explore'
            % 探索模式：历史档案与当前批次的最大最小距离。
            [~,scores] = model_select(Smodel,all_candidates);
            remainingBudget = max(0,floor(Problem.maxFE - Problem.FE));
            Next = ArchiveMaximinSelection(all_candidates,ArchiveDec, ...
                Problem.lower,Problem.upper,scores,min(6,remainingBudget));
        otherwise
            % 纯关系小批量模式：仅使用关系得分
            Next = select_conservative(Smodel,all_candidates,n_min);
    end
end

%% ============ 关系得分回退选择 ============
function Next = select_conservative(Smodel,Candidates,n_min)
%select_conservative 按关系得分选择至多 n_min 个候选的回退分支。

    % 用代理模型打分
    [~,scores] = model_select(Smodel,Candidates);
    % 按得分降序排序
    [~,order] = sort(scores,'descend');
    % 选择前 n_min 个
    n_eval = min(n_min,numel(order));
    if n_eval < 1
        Next = [];
    else
        Next = Candidates(order(1:n_eval),:);
    end
end

%% ============ 基于指标准则的填充选择 ============
function Next = IndicatorBasedInfill(Smodel,Candidates,n_min,n_max)
%IndicatorBasedInfill 根据关系得分和预测指标构造评价批次。
%   先按关系得分保留前 30%，并在候选池允许时至少保留 20 个。
%   RBF-SVR 根据已评价解的决策向量与 SDE 指标训练，预测筛选后候选的指标值。
%   再按预测指标的第 70 百分位筛选，候选集合允许时补足 n_min 个，
%   按指标降序返回至多 n_max 个候选。模型不可用或预测异常时使用关系得分。

    % 第一步：用关系得分粗筛，保留前 30%（至少 20 个）
    [~,scores_rel] = model_select(Smodel,Candidates);
    n_keep = max(20,ceil(size(Candidates,1)*0.30));
    n_keep = min(n_keep,size(Candidates,1));
    [~,idx_rel] = sort(scores_rel,'descend');
    coarse_idx = idx_rel(1:n_keep);
    coarse_set = Candidates(coarse_idx,:);

    % 第二步：用 SVR 指标模型重排序
    scores_ind = scores_rel(coarse_idx);
    if isfield(Smodel,'IndicatorModel') && ~isempty(Smodel.IndicatorModel)
        try
            pred = predict(Smodel.IndicatorModel,coarse_set);
            if all(~isnan(pred)) && all(~isinf(pred))
                scores_ind = pred;
            end
        catch
            % 如果 SVR 预测失败，回退到关系得分
            scores_ind = scores_rel(coarse_idx);
        end
    end

    % 第三步：保留不低于第 70 百分位的候选，通常约为最高 30%。
    threshold = quantile(scores_ind,0.70);
    cand_idx = find(scores_ind >= threshold);
    % 如果候选数不足 n_min，取得分最高的 n_min 个
    if numel(cand_idx) < n_min
        [~,order] = sort(scores_ind,'descend');
        cand_idx = order(1:min(n_min,numel(order)));
    end

    % 第四步：按指标得分排序，选择前 n_eval 个
    [~,order] = sort(scores_ind(cand_idx),'descend');
    n_eval = min(n_max,max(n_min,numel(cand_idx)));
    n_eval = min(n_eval,numel(cand_idx));
    selected = cand_idx(order(1:n_eval));

    if isempty(selected)
        Next = [];
    else
        Next = coarse_set(selected,:);
    end
end

%% ============ 代理模型打分函数 ============
function [ind,scores] = model_select(Smodel,Next)
%model_select 汇总有序解对的预测概率，计算关系得分。
%   每个候选 Xi 与正组 C1、非正组 C2 分别构造四类有序比较：
%   [C1,Xi]、[Xi,C1]、[C2,Xi]、[Xi,C2]。
%   网络输出顺序为 [+1,0,-1]，表示前者属于更高组、同组、前者属于更低组。
%   四类平均概率对应论文的 a、b、c、d，关系得分为
%   R(Xi) = 2*(c(-1)+d(+1)-a(+1)-b(-1))。
%
%   探索准则使用最大类别概率作为解对权重；指标准则使用算术平均。
%   scores 返回关系得分，ind 返回降序索引。

    model_x = Smodel.X;
    % 按 PAQC 的 Catalog 分离正组 C1 和非正组 C2。
    C1_data = model_x(Smodel.Y == 1,:);
    C2_data = model_x(Smodel.Y ~= 1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    scores      = zeros(Next_num,1);

    % 任一训练组或候选集为空时，返回初始得分及原始顺序。
    if C1_num == 0 || C2_num == 0 || Next_num == 0
        ind = (1:Next_num)';
        return;
    end

    % 计算每个候选的测试样本数
    nPairPerSol = 2*(C1_num+C2_num);
    all_testdata = zeros(nPairPerSol*Next_num,2*size(C1_data,2));

    % 为每个候选构造 4 类样本对
    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        % [C1, Xi] 和 [Xi, C1]
        Xi = repmat(Next(i,:),C1_num,1);
        all_testdata(original+1:original+C1_num,:) = [C1_data,Xi];
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data];

        % [C2, Xi] 和 [Xi, C2]
        Xi = repmat(Next(i,:),C2_num,1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:) = [C2_data,Xi];
        all_testdata(original+1+C1_num*2+C2_num:original+nPairPerSol,:) = [Xi,C2_data];
    end

    % 用网络预测所有测试样本
    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';
    % pair_conf 为每个有序解对的最大预测类别概率。
    pair_conf = max(pre_out,[],2);

    % 为每个候选计算关系得分 R。
    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        % 索引范围
        idx_C1Xi = original+1 : original+C1_num;
        idx_XiC1 = original+C1_num+1 : original+C1_num*2;
        idx_C2Xi = original+C1_num*2+1 : original+C1_num*2+C2_num;
        idx_XiC2 = original+C1_num*2+C2_num+1 : original+nPairPerSol;

        % 根据模式选择平均方式
        mode = 'conservative';
        if isfield(Smodel,'mode') && ~isempty(Smodel.mode)
            mode = Smodel.mode;
        end
        if strcmp(mode,'explore')
            % 探索模式：使用 softmax 最大类别概率作为加权平均权重
            pre_C1Xi = weighted_mean(pre_out(idx_C1Xi,:),pair_conf(idx_C1Xi));
            pre_XiC1 = weighted_mean(pre_out(idx_XiC1,:),pair_conf(idx_XiC1));
            pre_C2Xi = weighted_mean(pre_out(idx_C2Xi,:),pair_conf(idx_C2Xi));
            pre_XiC2 = weighted_mean(pre_out(idx_XiC2,:),pair_conf(idx_XiC2));
        else
            % 指标准则及关系得分回退分支：使用算术平均。
            pre_C1Xi = mean(pre_out(idx_C1Xi,:),1);
            pre_XiC1 = mean(pre_out(idx_XiC1,:),1);
            pre_C2Xi = mean(pre_out(idx_C2Xi,:),1);
            pre_XiC2 = mean(pre_out(idx_XiC2,:),1);
        end

        % 累加得分
        C_SCORE = zeros(1,2);
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);

        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);

        % 汇总四类比较结果，得到相对于正组和非正组的关系得分 R。
        scores(i) = C_SCORE(1) - C_SCORE(2);
    end

    % 按得分降序排序
    [~,ind] = sort(scores,'descend');
end

%% ============ softmax 尖锐度加权平均 ============
function y = weighted_mean(x,w)
%weighted_mean 按解对的最大类别概率加权汇总预测概率。

    w = w(:);
    y = sum(x.*w,1)./(sum(w) + eps);
end


