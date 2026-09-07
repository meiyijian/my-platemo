function Next = DiversifiedInfillSelection(Problem,Ref,Input,wmax,Smodel,q_keep,n_min,n_max)
%DiversifiedInfillSelection Criterion-diversified infill selection (CDIS).
%   Next = DiversifiedInfillSelection(Problem,Ref,Input,WMAX,Smodel)
%   从当前种群决策矩阵 Input 和已评价参考解 Ref 开始，进行关系模型引导的
%   遗传搜索，累积并去重候选解，再按 Smodel.mode 选择待真实评价的有序批次。
%   WMAX 为内循环累计生成候选解数量的停止阈值。
%
%   Next = DiversifiedInfillSelection(Problem,Ref,Input,WMAX,Smodel,q_keep,n_min,n_max)
%   指定探索得分的分位点、候选集合允许时的补足数量和评价批次上限。
%   默认值为 0.80、4 和 6；q_keep=0.80 通常筛出最高约 20% 的候选。
%   返回的 Next 仅含候选决策向量；主程序按剩余预算截断后执行真实评价。
%
%   主程序每轮选择一种准则：
%       'explore'   - ExplorationBasedInfill：关系得分、预测模糊度与决策空间距离。
%       'indicator' - IndicatorBasedInfill：关系得分筛选和预测指标重排序。
%   指标模型可用时，以 pMix 选择指标准则，否则使用探索准则。
%   Smodel.mode 为空或其他值时执行关系得分回退分支；当前主程序不选择该分支。

    % 参数默认值处理
    if nargin < 6 || isempty(q_keep)
        q_keep = 0.80;
    end
    if nargin < 7 || isempty(n_min)
        n_min = 4;
    end
    if nargin < 8 || isempty(n_max)
        n_max = 6;
    end

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
            % 探索模式：关系得分 + softmax 预测模糊度 + 决策空间分散性
            Next = ExplorationBasedInfill(Smodel,all_candidates,q_keep,n_min,n_max);
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

%% ============ 基于探索准则的填充选择 ============
function Next = ExplorationBasedInfill(Smodel,Candidates,q_keep,n_min,n_max)
%ExplorationBasedInfill 根据探索得分和决策空间距离构造评价批次。
%   用候选池内归一化的关系得分和预测模糊度构成探索得分 A_exp，按 q_keep
%   分位点筛选候选。候选池允许时补足 n_min 个，最终最多选择 n_max 个。
%   首先选择探索得分最高的候选，随后结合得分与到已选集合的距离逐个添加。

    % 用代理模型打分，同时返回平均 softmax 预测模糊度
    [~,scores,uncertainty] = model_select(Smodel,Candidates);

    % 归一化得分和预测模糊度到 [0,1]
    score_n = norm01(scores);
    unc_n   = norm01(uncertainty);

    % 计算预测模糊度奖励权重 lambda_t
    % lambda_t 的含义：
    %   - lambda0: 基础系数（0.35）
    %   - (1-ratio): 随进化递减
    %   - max(0, 1 - p_err/0.45): 关系对留出误差越低，预测模糊度奖励越大
    p_err = Smodel.p_err;
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
    lambda_t = Smodel.lambda0 * (1 - Smodel.ratio) * max(0,1 - p_err/0.45);

    % 探索得分 A_exp = 归一化关系得分 + lambda_t*归一化预测模糊度。
    score_aug = score_n + lambda_t .* unc_n;

    % 保留不低于 q_keep 分位点的候选；q_keep=0.80 时通常约为最高 20%。
    threshold = quantile(score_aug,q_keep);
    cand_idx = find(score_aug >= threshold);
    % 如果候选数不足 n_min，取得分最高的 n_min 个
    if numel(cand_idx) < n_min
        [~,order] = sort(score_aug,'descend');
        cand_idx = order(1:min(n_min,numel(order)));
    end

    % 确定最终选择数量
    n_eval = min(n_max,max(n_min,numel(cand_idx)));
    n_eval = min(n_eval,numel(cand_idx));

    % 根据探索得分和决策空间距离贪心构造评价批次。
    selected = diversity_select(Candidates,cand_idx,score_aug,n_eval);

    if isempty(selected)
        Next = [];
    else
        Next = Candidates(selected,:);
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
function [ind,scores,uncertainty] = model_select(Smodel,Next)
%model_select 汇总有序解对的预测概率，计算关系得分与预测模糊度。
%   每个候选 Xi 与正组 C1、非正组 C2 分别构造四类有序比较：
%   [C1,Xi]、[Xi,C1]、[C2,Xi]、[Xi,C2]。
%   网络输出顺序为 [+1,0,-1]，表示前者属于更高组、同组、前者属于更低组。
%   四类平均概率对应论文的 a、b、c、d，关系得分为
%   R(Xi) = 2*(c(-1)+d(+1)-a(+1)-b(-1))。
%
%   探索准则使用最大类别概率作为解对权重；指标准则使用算术平均。
%   scores 返回关系得分，ind 返回降序索引。
%   uncertainty 返回预测模糊度 U=1-mean(max(pi))，保留原有变量名。

    model_x = Smodel.X;
    % 按 PAQC 的 Catalog 分离正组 C1 和非正组 C2。
    C1_data = model_x(Smodel.Y == 1,:);
    C2_data = model_x(Smodel.Y ~= 1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    scores      = zeros(Next_num,1);
    uncertainty = ones(Next_num,1);

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

    % 为每个候选计算关系得分 R 和预测模糊度 U。
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
        % 预测模糊度 = 1 - 全部成对预测的平均最大类别概率
        % 对候选与两个训练组的全部有序解对取平均。
        uncertainty(i) = 1 - mean(pair_conf([idx_C1Xi,idx_XiC1,idx_C2Xi,idx_XiC2]));
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

%% ============ 多样性选择 ============
function selected = diversity_select(Next,cand_idx,score_aug,n_eval)
%diversity_select 结合探索得分与决策空间距离贪心构造评价批次。
%   先选探索得分最高的候选，再逐次计算剩余候选到已选集合的最小欧氏距离。
%   每步在剩余候选上分别归一化得分和距离，按 0.75*得分+0.25*距离排序。
%   selected 按加入顺序返回候选索引，对应论文的批次选择得分 A_batch。

    cand_idx = cand_idx(:);
    % 如果候选数不足，直接返回
    if numel(cand_idx) <= n_eval
        [~,order] = sort(score_aug(cand_idx),'descend');
        selected = cand_idx(order);
        return;
    end

    % 第一步：选得分最高的候选
    [~,first] = max(score_aug(cand_idx));
    selected = cand_idx(first);
    remain = cand_idx;
    remain(first) = [];

    % 第二步：贪心选择剩余候选
    while numel(selected) < n_eval && ~isempty(remain)
        % 计算每个剩余候选到已选集合的最小距离
        dist_to_selected = min(pdist2(Next(remain,:),Next(selected,:)),[],2);
        % 归一化距离
        div_n = norm01(dist_to_selected);
        % 批次选择得分 A_batch：0.75*归一化探索得分 + 0.25*归一化距离。
        acq = 0.75.*norm01(score_aug(remain)) + 0.25.*div_n;
        % 选 acq 最大的候选
        [~,best] = max(acq);
        selected(end+1,1) = remain(best); %#ok<AGROW>
        remain(best) = [];
    end
end

%% ============ 归一化到 [0,1] ============
function s = norm01(x)
%norm01 将向量按最小值和最大值归一化，取值范围过小时返回 0.5。

    x = x(:);
    if isempty(x)
        s = x;
        return;
    end
    a = min(x);
    b = max(x);
    if b - a < 1e-12
        % 所有值相同，返回 0.5
        s = ones(size(x))*0.5;
    else
        s = (x - a)./(b - a);
    end
end
