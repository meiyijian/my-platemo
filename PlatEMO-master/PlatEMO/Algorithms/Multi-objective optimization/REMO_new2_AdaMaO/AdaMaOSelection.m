function Next = AdaMaOSelection(Problem,Ref,Input,wmax,Smodel,q_keep,n_min,n_max)
% AdaMaOSelection - 自适应代理辅助候选解选择
%
% 本函数是 REMO_new2_AdaMaO 的核心选择模块，根据 Smodel.mode 选择不同的策略：
%
% 模式说明：
%   'conservative'（保守模式）：
%     - 仅使用关系得分，选择 n_min 个候选
%     - 适用条件：模型精度不高或默认模式
%     - 特点：简单稳定，避免过度依赖不确定的模型
%
%   'explore'（探索模式）：
%     - 关系得分 + 不确定性 + 决策空间多样性
%     - 适用条件：模型精度好 且 覆盖率低
%     - 特点：鼓励探索不确定性高的区域，同时保持多样性
%
%   'indicator'（指标模式）：
%     - 关系得分粗筛 + SVR 指标重排序
%     - 适用条件：有指标模型 且 模型精度好 且 种群退化度高
%     - 特点：使用 PIEA 的指标思想，优先选择指标值好的候选
%
% 输入：
%   Problem : 问题对象
%   Ref     : 参考解
%   Input   : 当前种群的决策变量
%   wmax    : 内层 GA 循环的累计样本上限
%   Smodel  : 代理模型结构体（包含 net、mode、IndicatorModel 等）
%   q_keep  : 分位数阈值
%   n_min   : 每轮最少评估数
%   n_max   : 每轮最多评估数
%
% 输出：
%   Next : 选出的候选解决策变量

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
            Next = select_indicator(Smodel,all_candidates,n_min,n_max);
        case 'explore'
            % 探索模式：关系得分 + 不确定性 + 决策空间多样性
            Next = select_explore(Smodel,all_candidates,q_keep,n_min,n_max);
        otherwise
            % 保守模式：仅使用关系得分
            Next = select_conservative(Smodel,all_candidates,n_min);
    end
end

%% ============ 保守模式选择 ============
function Next = select_conservative(Smodel,Candidates,n_min)
% select_conservative - 保守模式的候选解选择
%
% 策略：仅使用关系得分，选择得分最高的 n_min 个候选
%
% 输入：
%   Smodel    : 代理模型结构体
%   Candidates: 所有候选解
%   n_min     : 最少选择数量
%
% 输出：
%   Next : 选出的候选解决策变量

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

%% ============ 探索模式选择 ============
function Next = select_explore(Smodel,Candidates,q_keep,n_min,n_max)
% select_explore - 探索模式的候选解选择
%
% 策略：关系得分 + 不确定性加权 + 决策空间多样性
%
% 设计动机：
%   1. 不确定性加权：让算法在模型不够确信的区域多探索
%   2. 分位数筛选：替代固定阈值，更鲁棒
%   3. 多样性选择：防止候选解聚集在同一区域
%
% 输入：
%   Smodel    : 代理模型结构体
%   Candidates: 所有候选解
%   q_keep    : 分位数阈值
%   n_min     : 最少选择数量
%   n_max     : 最多选择数量
%
% 输出：
%   Next : 选出的候选解决策变量

    % 用代理模型打分，同时返回不确定性
    [~,scores,uncertainty] = model_select(Smodel,Candidates);

    % 归一化得分和不确定性到 [0,1]
    score_n = norm01(scores);
    unc_n   = norm01(uncertainty);

    % 计算不确定性权重 lambda_t
    % lambda_t 的含义：
    %   - lambda0: 基础系数（0.35）
    %   - (1-ratio): 随进化递减（早期大，鼓励探索）
    %   - max(0, 1 - p_err/0.45): 模型越准，越信任不确定性信号
    p_err = Smodel.p_err;
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
    lambda_t = Smodel.lambda0 * (1 - Smodel.ratio) * max(0,1 - p_err/0.45);

    % 计算增强得分 = 关系得分 + lambda_t * 不确定性
    score_aug = score_n + lambda_t .* unc_n;

    % 分位数筛选：保留得分前 q_keep 比例的候选
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

    % 多样性选择：贪心最大化最小距离
    selected = diversity_select(Candidates,cand_idx,score_aug,n_eval);

    if isempty(selected)
        Next = [];
    else
        Next = Candidates(selected,:);
    end
end

%% ============ 指标模式选择 ============
function Next = select_indicator(Smodel,Candidates,n_min,n_max)
% select_indicator - 指标模式的候选解选择
%
% 策略：关系得分粗筛 + SVR 指标重排序
%
% 设计动机：
%   当种群退化度高时，关系得分可能不够区分候选解
%   此时使用 PIEA 的指标思想（SDE、I_epsilon+、Minkowski）来评估候选解
%   SVR 模型用于快速预测候选解的指标值，避免重复计算
%
% 输入：
%   Smodel    : 代理模型结构体（包含 IndicatorModel）
%   Candidates: 所有候选解
%   n_min     : 最少选择数量
%   n_max     : 最多选择数量
%
% 输出：
%   Next : 选出的候选解决策变量

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

    % 第三步：分位数筛选，保留得分前 70% 的候选
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
% model_select - 用代理模型对候选解打分
%
% 打分机制：
%   对每个候选解 Xi，构造 4 类样本对让网络预测：
%     [C1, Xi]: 好解 在前，候选 在后
%     [Xi, C1]: 候选 在前，好解 在后
%     [C2, Xi]: 坏解 在前，候选 在后
%     [Xi, C2]: 候选 在前，坏解 在后
%
%   网络输出 3 类概率 [p+1, p0, p-1]
%   打分规则：
%     C_SCORE(1) += pre_C1Xi(2) + pre_C1Xi(3)  // C1 在前，Xi 被支配或同类 → Xi 好
%     C_SCORE(1) += pre_XiC1(2) + pre_XiC1(1)  // Xi 在前，C1 被支配或同类 → Xi 好
%     C_SCORE(1) += pre_C2Xi(3)                 // C2 在前，Xi 优于 C2 → Xi 好
%     C_SCORE(1) += pre_XiC2(1)                 // Xi 在前，C2 被支配 → Xi 好
%     ...（C_SCORE(2) 类似）
%     最终 score = C_SCORE(1) - C_SCORE(2)
%
% 输入：
%   Smodel : 代理模型结构体
%   Next   : 候选解决策变量
%
% 输出：
%   ind        : 按得分降序排列的索引
%   scores     : 每个候选的得分
%   uncertainty: 每个候选的不确定性（1 - 平均预测置信度）

    model_x = Smodel.X;
    % 分离好类和坏类的训练数据
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
    % 预测置信度 = 最大概率
    pair_conf = max(pre_out,[],2);

    % 为每个候选计算得分和不确定性
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
            % 探索模式：使用置信度加权平均
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

        % 最终得分 = 好的证据 - 坏的证据
        scores(i) = C_SCORE(1) - C_SCORE(2);
        % 不确定性 = 1 - 平均预测置信度
        uncertainty(i) = 1 - mean(pair_conf([idx_C1Xi,idx_XiC1,idx_C2Xi,idx_XiC2]));
    end

    % 按得分降序排序
    [~,ind] = sort(scores,'descend');
end

%% ============ 置信度加权平均 ============
function y = weighted_mean(x,w)
% weighted_mean - 使用置信度作为权重的加权平均
%
% 输入：
%   x : n x m 矩阵
%   w : n x 1 权重向量
%
% 输出：
%   y : 1 x m 加权平均结果

    w = w(:);
    y = sum(x.*w,1)./(sum(w) + eps);
end

%% ============ 多样性选择 ============
function selected = diversity_select(Next,cand_idx,score_aug,n_eval)
% diversity_select - 贪心多样性选择
%
% 策略：每次选一个候选加入已选集合，选择标准综合考虑得分和距离
%
% 算法步骤：
%   1. 先选 score_aug 最高的候选
%   2. 循环直到选满 n_eval 个：
%      对剩余候选 j：
%        dist_to_selected = min(||Next_j - 已选集合||)  // 到最近已选解的距离
%        acq_j = 0.75 * score_norm(j) + 0.25 * dist_norm(j)
%      选 acq 最大的 j 加入已选集合
%
% 设计动机：
%   0.75:0.25 的权重分配表明以得分为主，多样性为辅
%   这样选出的候选既高分又分散，避免聚集在单一区域
%
% 输入：
%   Next     : 所有候选解决策变量
%   cand_idx : 候选索引
%   score_aug: 增强得分
%   n_eval   : 需要选择的数量
%
% 输出：
%   selected : 选出的候选索引

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
        selected(end+1,1) = remain(best);
        remain(best) = [];
    end
end

%% ============ 归一化到 [0,1] ============
function s = norm01(x)
% norm01 - 将向量归一化到 [0,1]
%
% 输入：
%   x : 原始向量
%
% 输出：
%   s : 归一化后的向量

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
