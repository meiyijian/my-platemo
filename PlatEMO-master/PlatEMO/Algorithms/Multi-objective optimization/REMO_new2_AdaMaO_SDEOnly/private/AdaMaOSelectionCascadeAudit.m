function [Next,trace] = AdaMaOSelectionCascadeAudit(Problem,Ref,Input,wmax,Smodel,q_keep,n_min,n_max)
%AdaMaOSelectionCascadeAudit - Read-only audit twin of AdaMaOSelection.
%
% 本函数是 AdaMaOSelection 的只读审计副本，继承自冻结 Git blob
% b2483d050e91586356871d56e4bbb6ca4cc0aabd（见计划 Section 0）。
% 操作选择结果 Next 与 AdaMaOSelection 完全一致；唯一差异是额外返回
% trace，暴露完整累积候选池、全池关系得分、全池 SDE-SVR 指标预测、
% 关系粗筛状态、最终选择状态和指标是否真正参与，供 CascadeAudit
% 反事实审计使用。trace 的任何值都不会反馈到 Next、模型训练、候选
% 生成或环境选择中。
%
% 输入输出约定与 AdaMaOSelection 相同（见该文件头部文档）。

    % 参数默认值处理（与 AdaMaOSelection 逐行一致）
    if nargin < 6 || isempty(q_keep)
        q_keep = 0.80;
    end
    if nargin < 7 || isempty(n_min)
        n_min = 4;
    end
    if nargin < 8 || isempty(n_max)
        n_max = 6;
    end

    % 获取选择模式（与 AdaMaOSelection 逐行一致）
    mode = 'conservative';
    if isfield(Smodel,'mode') && ~isempty(Smodel.mode)
        mode = Smodel.mode;
    end

    %% ============ 代理辅助 GA 内循环（与 AdaMaOSelection 完全一致） ============
    % 使用 GA 生成候选解，然后用代理模型打分筛选
    % 这个过程重复多轮，逐步优化候选解的质量
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
        all_candidates = [all_candidates;Next]; %#ok<AGROW> pool grows per inner-GA round
        i = i + size(Next,1);
    end

    % 如果没有候选解，返回空和 well-shaped 无效 trace
    if isempty(all_candidates)
        Next = [];
        trace = emptyTrace(mode);
        return;
    end
    % 去重（保持顺序）
    all_candidates = unique(all_candidates,'rows','stable');

    %% ============ 根据模式选择最终候选（操作逻辑逐行一致） ============
    relationScores = []; %#ok<NASGU> assigned by every selection branch
    operationalIndicatorUsed = false;
    switch mode
        case 'indicator'
            % 指标模式：关系得分粗筛 + 可用时由 SVR 指标值重排序
            [Next,relationScores,operationalIndicatorUsed] = ...
                select_indicator(Smodel,all_candidates,n_min,n_max);
        case 'explore'
            % 探索模式：关系得分 + softmax 预测模糊度 + 决策空间分散性
            [Next,relationScores] = ...
                select_explore(Smodel,all_candidates,q_keep,n_min,n_max);
        otherwise
            % 纯关系小批量模式：仅使用关系得分
            [Next,relationScores] = ...
                select_conservative(Smodel,all_candidates,n_min);
    end

    %% ============ 只读 trace 构建（不反馈任何值到 Next） ============
    trace = buildReadOnlyTrace(all_candidates,relationScores,Smodel, ...
        mode,Next,operationalIndicatorUsed);
end

%% ============ 只读 trace 构建 ============
function trace = buildReadOnlyTrace(candidates,relationScores,Smodel, ...
    mode,Next,operationalIndicatorUsed)
    candidateCount = size(candidates,1);
    trace.Candidates = candidates;
    trace.RelationScores = relationScores(:);
    trace.IndicatorScores = NaN(candidateCount,1);
    trace.CoarseMask = buildCoarseMask(trace.RelationScores);
    trace.SelectedMask = false(candidateCount,1);
    if ~isempty(Next)
        [~,row] = ismember(Next,candidates,'rows');
        row(row < 1) = [];
        if ~isempty(row)
            trace.SelectedMask(row) = true;
        end
    end
    trace.IndicatorAvailable = isfield(Smodel,'IndicatorModel') && ...
        ~isempty(Smodel.IndicatorModel);
    if trace.IndicatorAvailable
        % 全池指标预测仅用于审计 trace；失败或非有限则保持 NaN
        try
            fullPrediction = predict(Smodel.IndicatorModel,candidates);
            if isnumeric(fullPrediction) && isreal(fullPrediction) && ...
                    isvector(fullPrediction) && ...
                    numel(fullPrediction) == candidateCount && ...
                    all(isfinite(fullPrediction))
                trace.IndicatorScores = fullPrediction(:);
            end
        catch
            % Full-pool indicator prediction is best-effort for the trace.
        end
    end
    trace.OperationalIndicatorUsed = logical(operationalIndicatorUsed);
    trace.CandidateMode = mode;
    trace.Valid = true;
end

function coarseMask = buildCoarseMask(relationScores)
%buildCoarseMask - Exact current coarse-screen rule on relation scores.
    count = numel(relationScores);
    if count < 1
        coarseMask = false(0,1);
        return;
    end
    nKeep = min(count,max(20,ceil(0.30*count)));
    [~,order] = sort(relationScores,'descend');
    coarseMask = false(count,1);
    coarseMask(order(1:nKeep)) = true;
end

function trace = emptyTrace(mode)
    trace.Candidates = zeros(0,0);
    trace.RelationScores = zeros(0,1);
    trace.IndicatorScores = zeros(0,1);
    trace.CoarseMask = false(0,1);
    trace.SelectedMask = false(0,1);
    trace.IndicatorAvailable = false;
    trace.OperationalIndicatorUsed = false;
    trace.CandidateMode = mode;
    trace.Valid = false;
end

%% ============ 保守模式选择（与 AdaMaOSelection 逻辑一致，增加 scores 输出） ============
function [Next,scores] = select_conservative(Smodel,Candidates,n_min)
% select_conservative - 纯关系小批量模式的候选解选择
%
% 策略：仅使用关系得分，选择得分最高的 n_min 个候选

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

%% ============ 探索模式选择（与 AdaMaOSelection 逻辑一致，增加 scores 输出） ============
function [Next,scores] = select_explore(Smodel,Candidates,q_keep,n_min,n_max)
% select_explore - 探索模式的候选解选择
%
% 策略：关系得分 + softmax 预测模糊度奖励 + 决策空间分散性

    % 用代理模型打分，同时返回平均 softmax 预测模糊度
    [~,scores,uncertainty] = model_select(Smodel,Candidates);

    % 归一化得分和预测模糊度到 [0,1]
    score_n = norm01(scores);
    unc_n   = norm01(uncertainty);

    % 计算预测模糊度奖励权重 lambda_t
    p_err = Smodel.p_err;
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
    lambda_t = Smodel.lambda0 * (1 - Smodel.ratio) * max(0,1 - p_err/0.45);

    % 计算增强得分 = 关系得分 + lambda_t * 预测模糊度
    score_aug = score_n + lambda_t .* unc_n;

    % 分位数筛选：保留高于 q_keep 分位点的候选
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

    % 决策空间分散选择：质量/距离加权的贪心选择
    selected = diversity_select(Candidates,cand_idx,score_aug,n_eval);

    if isempty(selected)
        Next = [];
    else
        Next = Candidates(selected,:);
    end
end

%% ============ 指标模式选择（与 AdaMaOSelection 逻辑一致，暴露操作级 indicator 状态） ============
function [Next,scores_rel,operationalIndicatorUsed] = ...
    select_indicator(Smodel,Candidates,n_min,n_max)
% select_indicator - 指标模式的候选解选择
%
% 策略：关系得分粗筛 + SVR 指标重排序。
% operationalIndicatorUsed 记录操作级 coarse-set predict 是否真正成功，
% 该标志只用于审计 eligibility，不改变所选候选。

    % 第一步：用关系得分粗筛，保留前 30%（至少 20 个）
    [~,scores_rel] = model_select(Smodel,Candidates);
    n_keep = max(20,ceil(size(Candidates,1)*0.30));
    n_keep = min(n_keep,size(Candidates,1));
    [~,idx_rel] = sort(scores_rel,'descend');
    coarse_idx = idx_rel(1:n_keep);
    coarse_set = Candidates(coarse_idx,:);

    % 第二步：用 SVR 指标模型重排序
    scores_ind = scores_rel(coarse_idx);
    operationalIndicatorUsed = false;
    if isfield(Smodel,'IndicatorModel') && ~isempty(Smodel.IndicatorModel)
        try
            pred = predict(Smodel.IndicatorModel,coarse_set);
            if all(~isnan(pred)) && all(~isinf(pred))
                scores_ind = pred;
                operationalIndicatorUsed = true;
            end
        catch
            % 如果 SVR 预测失败，回退到关系得分
            scores_ind = scores_rel(coarse_idx);
        end
    end

    % 第三步：保留高于 70% 分位点的候选
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

%% ============ 代理模型打分函数（与 AdaMaOSelection 完全一致） ============
function [ind,scores,uncertainty] = model_select(Smodel,Next)
% model_select - 用代理模型对候选解打分
%
% 打分机制：
%   对每个候选解 Xi，构造 4 类样本对让网络预测：
%     [C1, Xi]: 正组解在前，候选在后
%     [Xi, C1]: 候选在前，正组解在后
%     [C2, Xi]: 非正组解在前，候选在后
%     [Xi, C2]: 候选在前，非正组解在后
%   该分数是相对粗质量组的启发式净证据，不是 Pareto 胜率。

    model_x = Smodel.X;
    % 分离正组和非正组的基础解
    C1_data = model_x(Smodel.Y == 1,:);
    C2_data = model_x(Smodel.Y ~= 1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    scores      = zeros(Next_num,1);
    uncertainty = ones(Next_num,1);

    % 防御：如果某一类为空，直接返回
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
    % softmax 尖锐度 = 最大类别概率
    pair_conf = max(pre_out,[],2);

    % 为每个候选计算组别净证据和 softmax 预测模糊度
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
            % 保守模式：使用简单平均
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

        % 最终得分 = 候选偏向正组的证据 - 候选偏向非正组的证据
        scores(i) = C_SCORE(1) - C_SCORE(2);
        % 预测模糊度 = 1 - 全部成对预测的平均最大类别概率
        uncertainty(i) = 1 - mean(pair_conf([idx_C1Xi,idx_XiC1,idx_C2Xi,idx_XiC2]));
    end

    % 按得分降序排序
    [~,ind] = sort(scores,'descend');
end

%% ============ softmax 尖锐度加权平均（与 AdaMaOSelection 完全一致） ============
function y = weighted_mean(x,w)
% weighted_mean - 使用 softmax 最大类别概率作为权重的加权平均
    w = w(:);
    y = sum(x.*w,1)./(sum(w) + eps);
end

%% ============ 多样性选择（与 AdaMaOSelection 完全一致） ============
function selected = diversity_select(Next,cand_idx,score_aug,n_eval)
% diversity_select - 质量与决策空间距离加权的贪心批选择
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
        % 计算 acquisition function：0.75 * 得分 + 0.25 * 距离
        acq = 0.75.*norm01(score_aug(remain)) + 0.25.*div_n;
        % 选 acq 最大的候选
        [~,best] = max(acq);
        selected(end+1,1) = remain(best); %#ok<AGROW> greedy batch grows to n_eval
        remain(best) = [];
    end
end

%% ============ 归一化到 [0,1]（与 AdaMaOSelection 完全一致） ============
function s = norm01(x)
% norm01 - 将向量归一化到 [0,1]
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
