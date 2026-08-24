function Next = AdaMaOSelection(Problem,Ref,Input,wmax,Smodel,q_keep,n_min,n_max)
% AdaMaOSelection - 按固定诊断阈值路由的代理辅助候选解选择
%
% 本函数是 REMO_new2_AdaMaO 的核心选择模块，根据 Smodel.mode 选择不同的策略：
%
% 模式说明：
%   'conservative'（纯关系小批量模式，名称为兼容保留）：
%     - 仅使用关系得分，选择 n_min 个候选
%     - 触发条件：其他两个分支不满足
%     - 特点：仍完全依赖关系模型，只是不加入预测模糊度和批次距离项
%
%   'explore'（预测模糊度探索模式）：
%     - 关系得分 + softmax 预测模糊度 + 决策空间分散性
%     - 触发条件：关系对留出误差不高且方向占用率低于固定阈值
%     - 特点：奖励输出概率较不尖锐的候选；该量不是认知不确定性
%
%   'indicator'（指标模式）：
%     - 关系得分粗筛 + 可用时由 SVR 指标值重排序
%     - 触发条件：指标分支启用、关系对留出误差不高且线性维数集中度达到阈值
%     - 注意：主程序触发该模式时未保证 IndicatorModel 非空；为空时回退到关系得分
%
% 输入：
%   Problem : 问题对象
%   Ref     : 参考解
%   Input   : 当前种群的决策变量
%   wmax    : 内层 GA 循环的累计样本上限
%   Smodel  : 代理模型结构体（包含 net、mode、IndicatorModel 等）
%   q_keep  : 分位点；0.80 通常保留高于 80% 分位点、即最高约 20% 的候选
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
            Next = select_indicator(Smodel,all_candidates,n_min,n_max);
        case 'explore'
            % 探索模式：关系得分 + softmax 预测模糊度 + 决策空间分散性
            Next = select_explore(Smodel,all_candidates,q_keep,n_min,n_max);
        otherwise
            % 纯关系小批量模式：仅使用关系得分
            Next = select_conservative(Smodel,all_candidates,n_min);
    end
end

%% ============ 保守模式选择 ============
function Next = select_conservative(Smodel,Candidates,n_min)
% select_conservative - 纯关系小批量模式的候选解选择
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
% 策略：关系得分 + softmax 预测模糊度奖励 + 决策空间分散性
%
% 设计动机：
%   1. 预测模糊度奖励：偏好 softmax 输出较不尖锐的候选，但不等同于认知不确定性
%   2. 分位数筛选：使用候选集合内部排名，不代表统计鲁棒性已被验证
%   3. 决策空间分散：防止同批候选决策向量过于接近
%
% 输入：
%   Smodel    : 代理模型结构体
%   Candidates: 所有候选解
%   q_keep    : 分位点；保留高于该分位点的候选
%   n_min     : 最少选择数量
%   n_max     : 最多选择数量
%
% 输出：
%   Next : 选出的候选解决策变量

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

    % 计算增强得分 = 关系得分 + lambda_t * 预测模糊度
    score_aug = score_n + lambda_t .* unc_n;

    % 分位数筛选：保留高于 q_keep 分位点的候选；q_keep=0.80 时通常约为最高 20%
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

    % 决策空间分散选择：质量/距离加权的贪心选择，并非纯 max-min
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
%   当线性维数集中度超过固定阈值时，代码尝试用 PIEA 风格指标值重排候选。
%   SVR 从已评价解的决策变量拟合当代指标值，用于预测未评价候选；
%   若 SVR 不可用，代码回退到关系得分，因此模式名不保证指标实际参与。
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

    % 第三步：保留高于 70% 分位点的候选，通常约为最高 30%
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
%     [C1, Xi]: 正组解在前，候选在后
%     [Xi, C1]: 候选在前，正组解在后
%     [C2, Xi]: 非正组解在前，候选在后
%     [Xi, C2]: 候选在前，非正组解在后
%
%   网络输出 3 类概率 [p+1, p0, p-1]
%   打分规则：
%     C_SCORE(1) 汇总候选被预测为正组同组、或高于正/非正组的组别证据
%     C_SCORE(2) 汇总候选低于正组、或被预测为非正组同组/更低的组别证据
%     ...（C_SCORE(2) 类似）
%     最终 score = C_SCORE(1) - C_SCORE(2)
%   该分数是相对粗质量组的启发式净证据，不是 Pareto 胜率。
%
% 输入：
%   Smodel : 代理模型结构体
%   Next   : 候选解决策变量
%
% 输出：
%   ind        : 按得分降序排列的索引
%   scores     : 每个候选的得分
%   uncertainty: 每个候选的平均 softmax 预测模糊度（旧变量名保留）

    model_x = Smodel.X;
    % 分离正组和非正组的基础解；非正组包含融合排名后 3/4 的全部解
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
    % softmax 尖锐度 = 最大类别概率；它不是校准置信度或认知不确定性
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
        % 由于非正组约占 3/4，该平均值通常由与非正组的比较数量主导。
        uncertainty(i) = 1 - mean(pair_conf([idx_C1Xi,idx_XiC1,idx_C2Xi,idx_XiC2]));
    end

    % 按得分降序排序
    [~,ind] = sort(scores,'descend');
end

%% ============ softmax 尖锐度加权平均 ============
function y = weighted_mean(x,w)
% weighted_mean - 使用 softmax 最大类别概率作为权重的加权平均
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
% diversity_select - 质量与决策空间距离加权的贪心批选择
%
% 策略：每次选一个候选加入已选集合，综合考虑增强得分和决策空间欧氏距离
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
%   该规则鼓励决策向量分散，但不保证目标空间或 PF 方向多样性
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
        selected(end+1,1) = remain(best); %#ok<AGROW>
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
