function Next = RSurrogateAssistedSelection_v2(Problem, Ref, Input, wmax, Smodel)
% RSurrogateAssistedSelection_v2 - 代理辅助选择（分位数 + 不确定性引导）
%
% 输入：
%   Problem : PlatEMO 问题对象
%   Ref     : 参考解集合（融合得分 Top-k）
%   Input   : 当前种群决策变量（N×D）
%   wmax    : 代理评估上限
%   Smodel  : 代理模型结构体（含 nets/mp_struct/X/Y 等）
%
% 输出：
%   Next : 选出的真实评估候选解（行=解）
%
% 关键修复点：
%   1. 得分计算简化：onehot 改为 2 类 [p_good, p_bad]，score = p_good - p_bad
%   2. 阈值改用分位数 quantile(scores, 0.9) 替代硬编码 3.9
%   3. 不确定性引导：在 keep 中加入 score + 0.5 * uncertainty 重排，
%      每代真实评估 5~8 个解（替代固定 4）
%
% 借鉴源：
%   - 原 REMO_new2_clean/RSurrogateAssistedSelection.m（GA + 模型筛选骨架）
%   - EDN-ARMOEA/IndividualSelect.m（不确定性 + 收敛二选一）

    %% 用 GA 生成初始候选解
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    i = 0;
    while i < wmax
        [sorted_idx, ~, ~] = model_select(Smodel, Next);
        Input_new = Next(sorted_idx(1 : min(length(Ref), size(Next, 1))), :);
        Next = OperatorGA(Problem, [Input_new; Ref.decs], {1, 15, 1, 5});
        i = i + size(Next, 1);
    end

    %% 最终评分 + 不确定性
    [~, scores, uncertainty] = model_select(Smodel, Next);

    %% 分位数阈值筛选
    q90 = quantile(scores, 0.9);
    keep = scores > q90;
    if sum(keep) < 5
        [~, ind] = sort(scores, 'descend');
        keep = false(size(scores));
        keep(ind(1 : min(5, length(ind)))) = true;
    end

    %% 不确定性引导：在 keep 内重排，平衡利用与探索
    %   组合得分 = 归一化得分 + 0.5 * 归一化不确定性
    cand_idx = find(keep);
    if isempty(cand_idx)
        Next = [];
        return;
    end
    score_n = norm01(scores(cand_idx));
    unc_n   = norm01(uncertainty(cand_idx));
    combined = score_n + 0.5 * unc_n;
    [~, order] = sort(combined, 'descend');

    %% 每代真实评估 5~8 个解
    n_eval = min(8, max(5, length(cand_idx)));
    n_eval = min(n_eval, length(cand_idx));
    selected = cand_idx(order(1 : n_eval));
    Next = Next(selected, :);
end


function [ind, scores, uncertainty] = model_select(Smodel, Next)
% 用集成网络给候选解打分
%
% 评分逻辑：score = sum_over_pairs(p_good - p_bad)
%   其中 pair 来自候选解 Xi 与训练集中已知好/差解的两两组合
%   - [C1_data, Xi]：若 Xi 比 C1_data 差 → 期望网络输出 p_good=0
%   - [Xi, C1_data]：若 Xi 比 C1_data 差 → 期望网络输出 p_bad=1
%   - [C2_data, Xi]：若 Xi 比 C2_data 好 → 期望网络输出 p_good=1
%   - [Xi, C2_data]：若 Xi 比 C2_data 好 → 期望网络输出 p_bad=0

    model_x = Smodel.X;
    C1_data = model_x(Smodel.Y == 1, :);
    C2_data = model_x(Smodel.Y == 0, :);   % 注意：原版用 ~=1，但二分类下 0/1 都明确

    nC1 = size(C1_data, 1);
    nC2 = size(C2_data, 1);
    nNext = size(Next, 1);
    D = size(C1_data, 2);

    if nC1 == 0 || nC2 == 0
        scores      = zeros(nNext, 1);
        uncertainty = ones(nNext, 1);
        ind = (1 : nNext)';
        return;
    end

    %% 构造测试样本（4 种 pair 类型）
    nPair_per_solution = 2 * (nC1 + nC2);
    all_testdata = zeros(nPair_per_solution * nNext, 2 * D);
    for i = 1 : nNext
        base = (i - 1) * nPair_per_solution;
        Xi = repmat(Next(i, :), nC1, 1);
        all_testdata(base + 1            : base + nC1,         :) = [C1_data, Xi];   % C1_Xi
        all_testdata(base + nC1 + 1      : base + 2 * nC1,     :) = [Xi, C1_data];   % Xi_C1
        Xi = repmat(Next(i, :), nC2, 1);
        all_testdata(base + 2 * nC1 + 1                 : base + 2 * nC1 + nC2,         :) = [C2_data, Xi];   % C2_Xi
        all_testdata(base + 2 * nC1 + nC2 + 1           : base + 2 * nC1 + 2 * nC2,     :) = [Xi, C2_data];   % Xi_C2
    end

    %% 归一化
    TestIn_nor = mapminmax('apply', all_testdata', Smodel.mp_struct)';

    %% 集成预测
    K = length(Smodel.nets);
    pre_outs = zeros(size(TestIn_nor, 1), 2, K);
    for ki = 1 : K
        pre_outs(:, :, ki) = Smodel.nets{ki}(TestIn_nor')';
    end
    pre_mean = mean(pre_outs, 3);   % 集成均值
    pre_std  = std(pre_outs, 0, 3); % 集成方差

    %% 逐候选解汇总得分
    % onehotconv2 编码：l==1（前者优于后者）→ [1,0]，所以 col1="前者优"，col2="前者劣"
    %   pair=[C1,Xi]：col1 大 → C1 优于 Xi → Xi 较差（不利），col2 大 → Xi 较好（利好）
    %   pair=[Xi,C1]：col1 大 → Xi 优于 C1（利好），col2 大 → Xi 劣于 C1（不利）
    %   pair=[C2,Xi]：col1 大 → C2 优于 Xi（不利），col2 大 → Xi 优于 C2（利好）
    %   pair=[Xi,C2]：col1 大 → Xi 优于 C2（利好），col2 大 → Xi 劣于 C2（不利）
    scores      = zeros(nNext, 1);
    uncertainty = zeros(nNext, 1);
    for i = 1 : nNext
        base = (i - 1) * nPair_per_solution;

        p = pre_mean(base + 1 : base + nC1, :);
        s_C1Xi = mean(p(:, 2) - p(:, 1));

        p = pre_mean(base + nC1 + 1 : base + 2 * nC1, :);
        s_XiC1 = mean(p(:, 1) - p(:, 2));

        p = pre_mean(base + 2 * nC1 + 1 : base + 2 * nC1 + nC2, :);
        s_C2Xi = mean(p(:, 2) - p(:, 1));

        p = pre_mean(base + 2 * nC1 + nC2 + 1 : base + 2 * nC1 + 2 * nC2, :);
        s_XiC2 = mean(p(:, 1) - p(:, 2));

        scores(i) = s_C1Xi + s_XiC1 + s_C2Xi + s_XiC2;

        u = pre_std(base + 1 : base + nPair_per_solution, :);
        uncertainty(i) = mean(u(:));
    end

    [~, ind] = sort(scores, 'descend');
end


function s = norm01(x)
    a = min(x);
    b = max(x);
    if b - a < 1e-12
        s = ones(size(x)) * 0.5;
    else
        s = (x - a) / (b - a);
    end
end
