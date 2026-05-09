function [XXs, Ps] = GetSoftRelationPairsFromCatalog(Input, Catalog, Fitness, alpha)
% 对标 GetRelationPairs，但输出连续概率而非离散标签
%   Input   : N×D 决策变量矩阵
%   Catalog : N×1 布尔，true=好解，false=坏解
%   Fitness : N×1 连续质量分数（越大越好）
%   alpha   : sigmoid 陡峭度（默认 5）
%   XXs     : M×2D 配对特征矩阵
%   Ps      : M×1 目标概率 P(x_i优于x_j)

    if nargin < 4
        alpha = 5;
    end

    C1_index = Catalog == 1;
    C2_index = Catalog ~= 1;

    % --- 以下配对原则完全对标 GetRelationPairs ---
    % C1C1：好解之间配对
    C1C1 = combvec(Input(C1_index,:)', Input(C1_index,:)')';
    t_ind = combvec(1:sum(C1_index), 1:sum(C1_index));
    C1C1(t_ind(1,:) == t_ind(2,:), :) = [];  % 去掉自身配对

    % C2C2：坏解之间配对
    C2C2 = combvec(Input(C2_index,:)', Input(C2_index,:)')';
    t_ind = combvec(1:sum(C2_index), 1:sum(C2_index));
    C2C2(t_ind(1,:) == t_ind(2,:), :) = [];

    % C1C2：好解在前，坏解在后
    C1C2 = combvec(Input(C1_index,:)', Input(C2_index,:)')';

    % C2C1：坏解在前，好解在后
    C2C1 = combvec(Input(C2_index,:)', Input(C1_index,:)')';

    % --- 平衡采样，完全对标原版 ---
    t_num = ceil(size(C1C2,1) / 2);
    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        C1C1 = C1C1(randperm(size(C1C1,1), t_num), :);
        C2C2 = C2C2(randperm(size(C2C2,1), t_num), :);
    elseif size(C1C1,1) < t_num
        C2C2 = C2C2(randperm(size(C2C2,1), t_num*2-size(C1C1,1)), :);
    elseif size(C2C2,1) < t_num
        C1C1 = C1C1(randperm(size(C1C1,1), t_num*2-size(C2C2,1)), :);
    end

    % 拼接所有配对
    XXs = [C1C1; C2C2; C1C2; C2C1];

    % --- 关键区别：标签从离散变为连续概率 ---
    % 需要为每对解计算 fitness 差
    % 先获取每个解在原始 Input 中的索引
    [~, idx_all] = ismember(XXs(:, 1:end/2), Input(:, :), 'rows');
    [~, idx_partner] = ismember(XXs(:, end/2+1:end), Input(:, :), 'rows');

    % 计算连续概率
    delta = Fitness(idx_all) - Fitness(idx_partner);
    Ps = 1 ./ (1 + exp(-alpha * delta));
end