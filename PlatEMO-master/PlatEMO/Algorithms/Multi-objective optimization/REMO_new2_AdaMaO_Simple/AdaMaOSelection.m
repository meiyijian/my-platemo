function Next = AdaMaOSelection(Problem,Ref,Input,wmax,Smodel)
% AdaMaOSelection - 自适应代理辅助候选解选择（超参数削减版）
%
% 相对完整版的变化：
%   - 删除了 q_keep / n_min / n_max 三个外部参数
%   - 最终选择数量 n_eval 由主程序按覆盖率自动决定，经 Smodel.n_eval 传入
%   - select_explore 的探索强度由 model_gain（多数类基线相对增益）× coverage_gap
%     （1-覆盖率）连续控制，不再使用 lambda0 / p_err/0.45 / coverage<0.60 硬阈值
%   - 多样性准则保持内部固定 0.75*得分 + 0.25*距离（不暴露为超参）
%
% 输入：
%   Problem : 问题对象
%   Ref     : 参考解
%   Input   : 当前种群的决策变量
%   wmax    : 内层 GA 循环的累计样本上限（由主程序按 N 计算）
%   Smodel  : 代理模型结构体（包含 net、mode、IndicatorModel、model_gain、coverage_gap、n_eval 等）
%
% 输出：
%   Next : 选出的候选解决策变量

    % 获取选择模式
    mode = 'conservative';
    if isfield(Smodel,'mode') && ~isempty(Smodel.mode)
        mode = Smodel.mode;
    end

    % 覆盖感知的批量大小（主程序已按覆盖率算好，经 Smodel.n_eval 传入）
    n_eval = max(1, ceil(Problem.N/25));   % 防御性默认值
    if isfield(Smodel,'n_eval') && ~isempty(Smodel.n_eval)
        n_eval = Smodel.n_eval;
    end

    %% ============ 代理辅助 GA 内循环 ============
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
        all_candidates = [all_candidates;Next];
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
            % 指标模式：关系得分粗筛 + SVR 指标重排序
            Next = select_indicator(Smodel,all_candidates,n_eval);
        case 'explore'
            % 探索模式：关系得分 + 不确定性 + 决策空间多样性
            Next = select_explore(Smodel,all_candidates,n_eval);
        otherwise
            % 保守模式：仅使用关系得分
            Next = select_conservative(Smodel,all_candidates,n_eval);
    end
end

%% ============ 保守模式选择 ============
function Next = select_conservative(Smodel,Candidates,n_eval)
% select_conservative - 保守模式的候选解选择
%   策略：仅使用关系得分，选择得分最高的 n_eval 个候选
    [~,scores] = model_select(Smodel,Candidates);
    [~,order] = sort(scores,'descend');
    n_sel = min(n_eval,numel(order));
    if n_sel < 1
        Next = [];
    else
        Next = Candidates(order(1:n_sel),:);
    end
end

%% ============ 探索模式选择 ============
function Next = select_explore(Smodel,Candidates,n_eval)
% select_explore - 探索模式的候选解选择
%
% 策略：关系得分 + 不确定性加权 + 决策空间多样性
%   增强得分 score_aug = score_n + (1-ratio)*model_gain*coverage_gap.*unc_n
%     - model_gain：多数类基线相对增益（>0 表示模型比多数类猜测好），替代 p_err/0.45
%     - coverage_gap = 1 - coverage：覆盖率越低，探索加成越大，替代 coverage<0.60 硬阈值
%     - (1-ratio)：随进化递减，早期探索强、后期收缩
%   不再做分位数筛选（删除 q_keep）；直接由 diversity_select 选 n_eval 个
%
% 多样性准则保持内部固定 0.75*得分 + 0.25*距离（不暴露为超参）

    % 用代理模型打分，同时返回不确定性
    [~,scores,uncertainty] = model_select(Smodel,Candidates);

    % 归一化得分和不确定性到 [0,1]
    score_n = norm01(scores);
    unc_n   = norm01(uncertainty);

    % 连续控制的探索强度（替代 lambda0*(1-ratio)*max(0,1-p_err/0.45)）
    mg = 0; if isfield(Smodel,'model_gain'), mg = Smodel.model_gain; end
    cg = 1; if isfield(Smodel,'coverage_gap'), cg = Smodel.coverage_gap; end
    ratio = 0; if isfield(Smodel,'ratio'), ratio = Smodel.ratio; end
    lambda_t = (1 - ratio) * mg * cg;

    % 计算增强得分
    score_aug = score_n + lambda_t .* unc_n;

    % 不再做分位数筛选（删除 q_keep）：所有候选进入多样性选择
    cand_idx = (1:numel(score_aug))';

    % 多样性选择：内部固定 0.75/0.25 贪心准则
    selected = diversity_select(Candidates,cand_idx,score_aug,n_eval);

    if isempty(selected)
        Next = [];
    else
        Next = Candidates(selected,:);
    end
end

%% ============ 指标模式选择 ============
function Next = select_indicator(Smodel,Candidates,n_eval)
% select_indicator - 指标模式的候选解选择
%   策略：关系得分粗筛 + SVR 指标重排序
%   最终选择数量统一为 n_eval（替代 n_min/n_max）

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
            scores_ind = scores_rel(coarse_idx);
        end
    end

    % 第三步：分位数筛选，保留得分前 70% 的候选
    threshold = quantile(scores_ind,0.70);
    cand_idx = find(scores_ind >= threshold);
    % 如果候选数不足 n_eval，取得分最高的 n_eval 个
    if numel(cand_idx) < n_eval
        [~,order] = sort(scores_ind,'descend');
        cand_idx = order(1:min(n_eval,numel(order)));
    end

    % 第四步：按指标得分排序，选择前 n_eval 个
    [~,order] = sort(scores_ind(cand_idx),'descend');
    n_sel = min(n_eval,numel(cand_idx));
    selected = cand_idx(order(1:n_sel));

    if isempty(selected)
        Next = [];
    else
        Next = coarse_set(selected,:);
    end
end

%% ============ 代理模型打分函数 ============
function [ind,scores,uncertainty] = model_select(Smodel,Next)
% model_select - 用代理模型对候选解打分
%   对每个候选解 Xi，构造 4 类样本对让网络预测：
%     [C1, Xi] / [Xi, C1] / [C2, Xi] / [Xi, C2]
%   网络输出 3 类概率 [p+1, p0, p-1]
%   打分规则：score = (好证据) - (坏证据)
%   不确定性 = 1 - 平均预测置信度

    model_x = Smodel.X;
    C1_data = model_x(Smodel.Y == 1,:);
    C2_data = model_x(Smodel.Y ~= 1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    scores      = zeros(Next_num,1);
    uncertainty = ones(Next_num,1);

    if C1_num == 0 || C2_num == 0 || Next_num == 0
        ind = (1:Next_num)';
        return;
    end

    nPairPerSol = 2*(C1_num+C2_num);
    all_testdata = zeros(nPairPerSol*Next_num,2*size(C1_data,2));

    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        Xi = repmat(Next(i,:),C1_num,1);
        all_testdata(original+1:original+C1_num,:) = [C1_data,Xi];
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data];

        Xi = repmat(Next(i,:),C2_num,1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:) = [C2_data,Xi];
        all_testdata(original+1+C1_num*2+C2_num:original+nPairPerSol,:) = [Xi,C2_data];
    end

    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';
    pair_conf = max(pre_out,[],2);

    mode = 'conservative';
    if isfield(Smodel,'mode') && ~isempty(Smodel.mode)
        mode = Smodel.mode;
    end

    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        idx_C1Xi = original+1 : original+C1_num;
        idx_XiC1 = original+C1_num+1 : original+C1_num*2;
        idx_C2Xi = original+C1_num*2+1 : original+C1_num*2+C2_num;
        idx_XiC2 = original+C1_num*2+C2_num+1 : original+nPairPerSol;

        if strcmp(mode,'explore')
            pre_C1Xi = weighted_mean(pre_out(idx_C1Xi,:),pair_conf(idx_C1Xi));
            pre_XiC1 = weighted_mean(pre_out(idx_XiC1,:),pair_conf(idx_XiC1));
            pre_C2Xi = weighted_mean(pre_out(idx_C2Xi,:),pair_conf(idx_C2Xi));
            pre_XiC2 = weighted_mean(pre_out(idx_XiC2,:),pair_conf(idx_XiC2));
        else
            pre_C1Xi = mean(pre_out(idx_C1Xi,:),1);
            pre_XiC1 = mean(pre_out(idx_XiC1,:),1);
            pre_C2Xi = mean(pre_out(idx_C2Xi,:),1);
            pre_XiC2 = mean(pre_out(idx_XiC2,:),1);
        end

        C_SCORE = zeros(1,2);
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);

        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);

        scores(i) = C_SCORE(1) - C_SCORE(2);
        uncertainty(i) = 1 - mean(pair_conf([idx_C1Xi,idx_XiC1,idx_C2Xi,idx_XiC2]));
    end

    [~,ind] = sort(scores,'descend');
end

%% ============ 置信度加权平均 ============
function y = weighted_mean(x,w)
    w = w(:);
    y = sum(x.*w,1)./(sum(w) + eps);
end

%% ============ 多样性选择 ============
function selected = diversity_select(Next,cand_idx,score_aug,n_eval)
% diversity_select - 贪心多样性选择
%   策略：每次选一个候选加入已选集合，标准 = 0.75*得分 + 0.25*距离
%   0.75/0.25 为内部固定准则（不暴露为超参）

    cand_idx = cand_idx(:);
    if numel(cand_idx) <= n_eval
        [~,order] = sort(score_aug(cand_idx),'descend');
        selected = cand_idx(order);
        return;
    end

    [~,first] = max(score_aug(cand_idx));
    selected = cand_idx(first);
    remain = cand_idx;
    remain(first) = [];

    while numel(selected) < n_eval && ~isempty(remain)
        dist_to_selected = min(pdist2(Next(remain,:),Next(selected,:)),[],2);
        div_n = norm01(dist_to_selected);
        acq = 0.75.*norm01(score_aug(remain)) + 0.25.*div_n;
        [~,best] = max(acq);
        selected(end+1,1) = remain(best);
        remain(best) = [];
    end
end

%% ============ 归一化到 [0,1] ============
function s = norm01(x)
    x = x(:);
    if isempty(x)
        s = x;
        return;
    end
    a = min(x);
    b = max(x);
    if b - a < 1e-12
        s = ones(size(x))*0.5;
    else
        s = (x - a)./(b - a);
    end
end
