function Next = RSurrogateAssistedSelection(Problem,Ref,Input,wmax,Smodel,q_keep,n_min,n_max)
% 代理模型辅助选择（改进版：含不确定性感知和多样性选择）
% 用于 WFG10 等高维多目标问题，避免候选解聚集
%
% 改进点：
% 1. 使用分位数 q_keep 筛选候选，替代固定阈值
% 2. 不确定性加权得分，鼓励探索模型不确定的区域
% 3. 多样性选择，防止候选解在决策空间聚集
%
% 输入:
%   Problem - 问题对象
%   Ref     - 参考解（来自 HPC 分类）
%   Input   - 当前种群的决策变量
%   wmax    - 内层 GA 累计样本上限（gmax）
%   Smodel  - 代理模型结构体（含 net, X, Y, p_err, lambda0, ratio）
%   q_keep  - 候选筛选分位数（默认 0.80）
%   n_min   - 每轮最少评估数（默认 4）
%   n_max   - 每轮最多评估数（默认 6）
%
% 输出:
%   Next - 最终选出的候选决策变量（将被真实评估）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ============ 代理辅助 GA 内循环 ============
    % 初始候选：当前种群和参考解的 GA 子代
    % OperatorGA 参数 {1,15,1,5}：
    %   SBX 交叉概率=1, SBX 分布指数=15, 多项式变异概率=1, 变异分布指数=5
    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;

    % 内层循环：用代理模型反复筛选和生成候选
    while i < wmax
        % 用神经网络对候选解打分
        [sorted_index,~] = model_select(Smodel,Next);
        % 保留评分最好的若干个（数量 = min(参考解数, 候选数)）
        keepNum = min(length(Ref),size(Next,1));
        Input   = Next(sorted_index(1:keepNum),:);
        % 用保留的候选生成新的 GA 子代
        Next    = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i       = i + size(Next,1);
    end

    %% ============ 最终候选筛选 ============
    % 获取所有候选的得分和不确定性
    [~,scores,uncertainty] = model_select(Smodel,Next);

    % 归一化得分和不确定性到 [0,1]
    score_n = norm01(scores);
    unc_n   = norm01(uncertainty);

    %% ---- 自适应不确定性权重 lambda_t ----
    % lambda_t 随进化递减：
    %   - (1-ratio): 早期大（鼓励探索），后期小（侧重开发）
    %   - max(0, 1-p_err/0.45): 模型越准，越信任不确定性信号
    p_err = Smodel.p_err;
    if isnan(p_err)
        p_err = 1;  % 防御：NaN 时假设误差最大
    end
    lambda_t  = Smodel.lambda0 * (1 - Smodel.ratio) * max(0,1 - p_err/0.45);

    %% ---- 增强得分：得分 + 不确定性加权 ----
    % 含义：高分且高不确定性的候选被优先选中（鼓励探索）
    score_aug = score_n + lambda_t .* unc_n;

    %% ---- 分位数筛选 ----
    % 保留得分前 q_keep (80%) 比例的候选
    threshold = quantile(score_aug,q_keep);
    cand_idx  = find(score_aug >= threshold);

    % 如果候选数太少，至少保留 n_min 个
    if numel(cand_idx) < n_min
        [~,order] = sort(score_aug,'descend');
        cand_idx  = order(1:min(n_min,numel(order)));
    end

    %% ---- 确定本轮评估数量 ----
    % 在 [n_min, n_max] 范围内，且不超过候选数
    n_eval = min(n_max,max(n_min,numel(cand_idx)));
    n_eval = min(n_eval,numel(cand_idx));

    %% ---- 多样性选择 ----
    % 贪心策略：综合考虑得分和与已选解的距离
    selected = diversity_select(Next,cand_idx,score_aug,n_eval);

    if isempty(selected)
        Next = [];
    else
        Next = Next(selected,:);
    end
end

%% ============ 内部函数：代理模型打分 ============
function [ind,scores,uncertainty] = model_select(Smodel,Next)
% 用训练好的神经网络对候选解打分
% 输入: Smodel - 代理模型, Next - 候选解
% 输出: ind - 按得分降序排列的索引, scores - 得分, uncertainty - 不确定性

    model_x = Smodel.X;
    % 分离好类和坏类的训练数据
    C1_data = model_x(Smodel.Y == 1,:);   % 好类
    C2_data = model_x(Smodel.Y ~= 1,:);   % 坏类

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    scores      = zeros(Next_num,1);
    uncertainty = ones(Next_num,1);  % 默认最大不确定性

    % 防御：任一集合为空则返回默认值
    if C1_num == 0 || C2_num == 0 || Next_num == 0
        ind = (1:Next_num)';
        return;
    end

    %% ---- 构造所有候选的测试样本对 ----
    % 每个候选 Xi 需要与所有好解和坏解配对
    % 4 类对: [C1,Xi], [Xi,C1], [C2,Xi], [Xi,C2]
    nPairPerSol = 2*(C1_num+C2_num);
    all_testdata = zeros(nPairPerSol*Next_num,2*size(C1_data,2));

    for i = 1 : Next_num
        original = (i-1)*nPairPerSol;

        % [C1, Xi]：好解在前，候选在后
        Xi = repmat(Next(i,:),C1_num,1);
        all_testdata(original+1:original+C1_num,:)          = [C1_data,Xi];
        % [Xi, C1]：候选在前，好解在后
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data];

        % [C2, Xi]：坏解在前，候选在后
        Xi = repmat(Next(i,:),C2_num,1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:) = [C2_data,Xi];
        % [Xi, C2]：候选在前，坏解在后
        all_testdata(original+1+C1_num*2+C2_num:original+nPairPerSol,:) = [Xi,C2_data];
    end

    %% ---- 神经网络预测 ----
    % 用训练集的归一化参数变换测试数据
    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    % 网络输出 3 类概率 [p+1, p0, p-1]
    pre_out    = Smodel.net(TestIn_nor')';
    % 预测置信度 = 最大概率（越高表示网络越确定）
    pair_conf  = max(pre_out,[],2);

    %% ---- 对每个候选打分 ----
    for i = 1 : Next_num
        original = (i-1)*nPairPerSol;

        % 获取 4 类对的索引范围
        idx_C1Xi = original+1 : original+C1_num;
        idx_XiC1 = original+C1_num+1 : original+C1_num*2;
        idx_C2Xi = original+C1_num*2+1 : original+C1_num*2+C2_num;
        idx_XiC2 = original+C1_num*2+C2_num+1 : original+nPairPerSol;

        % 加权平均（用 pair_conf 加权，高置信度预测贡献更大）
        pre_C1Xi = weighted_mean(pre_out(idx_C1Xi,:),pair_conf(idx_C1Xi));
        pre_XiC1 = weighted_mean(pre_out(idx_XiC1,:),pair_conf(idx_XiC1));
        pre_C2Xi = weighted_mean(pre_out(idx_C2Xi,:),pair_conf(idx_C2Xi));
        pre_XiC2 = weighted_mean(pre_out(idx_XiC2,:),pair_conf(idx_XiC2));

        %% ---- 打分规则 ----
        % C_SCORE(1): Xi 好的证据
        % C_SCORE(2): Xi 坏的证据
        C_SCORE = zeros(1,2);

        % [C1, Xi]: 若预测为"同类"或"Xi好"，说明 Xi 不错
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);

        % [Xi, C1]: 若预测为"同类"或"Xi好"，说明 Xi 不错
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);

        % [C2, Xi]: 若预测为"Xi好"，说明 Xi 比坏解好
        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);

        % [Xi, C2]: 若预测为"Xi好"，说明 Xi 比坏解好
        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);

        % 最终得分 = 好证据 - 坏证据（越高越好）
        scores(i)  = C_SCORE(1) - C_SCORE(2);

        %% ---- 不确定性计算 ----
        % 所有对的平均预测置信度
        w_all = [pair_conf(idx_C1Xi);pair_conf(idx_XiC1); ...
                 pair_conf(idx_C2Xi);pair_conf(idx_XiC2)];
        % 不确定性 = 1 - 平均置信度（越高表示网络越不确定）
        uncertainty(i) = 1 - mean(w_all);
    end

    % 按得分降序排列
    [~,ind] = sort(scores,'descend');
end

%% ============ 内部函数：加权平均 ============
function y = weighted_mean(x,w)
% 对矩阵 x 按权重 w 加权平均（按列）
    w = w(:);
    y = sum(x.*w,1)./(sum(w) + eps);  % eps 防止除零
end

%% ============ 内部函数：多样性选择 ============
function selected = diversity_select(Next,cand_idx,score_aug,n_eval)
% 贪心策略：每次选一个候选加入已选集合
% 选择标准综合考虑得分和与已选解的距离
%
% 输入:
%   Next      - 所有候选解
%   cand_idx  - 候选索引
%   score_aug - 增强得分
%   n_eval    - 需要选出的数量
% 输出:
%   selected  - 选中的索引

    cand_idx = cand_idx(:);
    % 如果候选数不足，直接按得分排序返回
    if numel(cand_idx) <= n_eval
        [~,order] = sort(score_aug(cand_idx),'descend');
        selected  = cand_idx(order);
        return;
    end

    %% ---- 第一个候选：得分最高者 ----
    [~,first] = max(score_aug(cand_idx));
    selected  = cand_idx(first);
    remain    = cand_idx;
    remain(first) = [];

    %% ---- 贪心选择后续候选 ----
    while numel(selected) < n_eval && ~isempty(remain)
        % 计算每个剩余候选到已选集合的最小距离
        dist_to_selected = min(pdist2(Next(remain,:),Next(selected,:)),[],2);
        % 归一化距离到 [0,1]
        div_n = norm01(dist_to_selected);

        % 综合得分 = 0.75*得分 + 0.25*距离
        % 含义：以得分为主，多样性为辅
        acq   = 0.75.*norm01(score_aug(remain)) + 0.25.*div_n;

        % 选综合得分最高的
        [~,best] = max(acq);
        selected(end+1,1) = remain(best); %#ok<AGROW>
        remain(best) = [];
    end
end

%% ============ 内部函数：归一化到 [0,1] ============
function s = norm01(x)
% 将向量 x 归一化到 [0,1]
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