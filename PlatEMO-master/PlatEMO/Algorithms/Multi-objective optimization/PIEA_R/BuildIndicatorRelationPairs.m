function [XXs, YYs] = BuildIndicatorRelationPairs(Input, Fitness, q)
% BuildIndicatorRelationPairs - 用性能指标连续值构建关系对
%
% 替代 REMO 中 PBI 分类 + GetRelationPairs 的流程。
% 直接用指标 Fitness 的成对差值生成三类关系标签 {-1, 0, +1}。
%
% 输入：
%   Input   : N x D 决策变量矩阵
%   Fitness : N x 1 指标适应度值（越大越好）
%   q       : 阈值分位数（0~1），默认 0.3
%             threshold = quantile(|Fitness_i - Fitness_j|, q)
%             q 越小 → 更多 +/-1 标签（激进）
%             q 越大 → 更多 0 标签（保守）
%
% 输出：
%   XXs : P x 2D 关系对（每行是 [x_i, x_j]）
%   YYs : P x 1 标签
%          +1 = x_i 明显优于 x_j（Fitness_i - Fitness_j > threshold）
%          -1 = x_j 明显优于 x_i（Fitness_i - Fitness_j < -threshold）
%           0 = x_i 与 x_j 大致等价

    N = size(Input, 1);

    %% 生成所有上三角索引（唯一对，排除对角线）
    [ii, jj] = find(triu(true(N), 1));
    n_total = length(ii);

    if n_total == 0
        XXs = []; YYs = [];
        return;
    end

    %% 计算所有选中对的 Fitness 差值
    diffs = Fitness(ii) - Fitness(jj);

    %% 计算自适应阈值
    threshold = quantile(abs(diffs), q);

    %% 若阈值为 0（所有 Fitness 完全相同），无法区分
    if threshold < eps
        XXs = []; YYs = [];
        return;
    end

    %% 三类标签赋值
    label_vec = zeros(n_total, 1);
    label_vec(diffs >  threshold) =  1;   % i 优于 j
    label_vec(diffs < -threshold) = -1;   % j 优于 i
    % |diffs| <= threshold → 0（等价）

    %% 检查三类是否都有样本
    idx_p1 = find(label_vec ==  1);
    idx_0  = find(label_vec ==  0);
    idx_n1 = find(label_vec == -1);

    % 若正类或负类为空，无法构建有效关系对
    if isempty(idx_p1) || isempty(idx_n1)
        XXs = []; YYs = [];
        return;
    end

    %% 三类别均衡采样（参考 GetRelationPairs.m 的平衡策略）
    % 目标：每类至少 20 对，最多不超过最小类的 1.5 倍
    min_class_size = min([length(idx_p1), length(idx_n1)]);
    n_target = max(20, ceil(min_class_size * 1.5));

    % 正类采样
    if length(idx_p1) > n_target
        idx_p1 = idx_p1(randperm(length(idx_p1), n_target));
    end

    % 负类采样
    if length(idx_n1) > n_target
        idx_n1 = idx_n1(randperm(length(idx_n1), n_target));
    end

    % 等价类可以多一些（最多 2 倍），提供更多"等价"训练信号
    n_target_eq = n_target * 2;
    if length(idx_0) > n_target_eq
        idx_0 = idx_0(randperm(length(idx_0), n_target_eq));
    end

    %% 组装最终关系对
    all_idx = [idx_p1; idx_0; idx_n1];
    XXs = [Input(ii(all_idx), :), Input(jj(all_idx), :)];
    YYs = label_vec(all_idx);
end
