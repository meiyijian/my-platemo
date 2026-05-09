function [XXs, Ls] = GetRelationPairs_Curriculum(Input, Catalog, stage)
% 课程化关系对构造（REMO_C2RL 创新点 1）
%
% 输入：
%   Input    : N×D 决策变量矩阵
%   Catalog  : N×1 logical 数组（true=好解, false=非好解）
%   stage    : 课程阶段
%              1 = "易"：只用极端对（top-25% 与"硬负例"组成的子种群）
%              2 = "难"：使用全部解（与 REMO_new2 原版一致）
%
% 输出：
%   XXs      : 关系对矩阵（每行是 [solA, solB] 拼接）
%   Ls       : 对应标签 ∈ {-1, 0, +1}
%
% 设计动机：
%   M = 10 时 HPC 二分类边界模糊，"中间解"被强行归为非好类，
%   造成训练标签噪声大。课程学习思想：早期只学清晰对（极端对），
%   等模型成熟后再挑战边界对。

    if stage == 1
        %% 阶段 1：只用极端对（先易后难的"易"）
        % 思路：保留所有 good_idx (Catalog==1)，从非好解中再挑出"硬负例"
        %   "硬负例"= 在决策空间中距离 good 解中心最远的那批非好解
        %   这样配对时 good vs hard-bad 的关系最清晰，训练标签噪声最低

        good_idx = find(Catalog == 1);
        bad_pool = find(Catalog ~= 1);
        N        = size(Input, 1);

        % 兜底：若 good 解或非好解过少，直接退化为阶段 2（避免训练样本崩溃）
        if length(good_idx) < 2 || length(bad_pool) < 2
            [XXs, Ls] = GetRelationPairs(Input, Catalog);
            return;
        end

        % 计算 good 解的中心点（决策空间）
        good_center = mean(Input(good_idx, :), 1);

        % 计算每个非好解到 good 中心的距离，选最远的作为"硬负例"
        dists = vecnorm(Input(bad_pool, :) - good_center, 2, 2);
        [~, sort_idx] = sort(dists, 'descend');
        n_bad = ceil(N / 4);     % "硬负例"数量 = 总种群 25%
        n_bad = min(n_bad, length(bad_pool));
        bad_idx = bad_pool(sort_idx(1:n_bad));

        % 构造子种群：good_idx + bad_idx
        sub_idx       = [good_idx; bad_idx];
        Sub_Input     = Input(sub_idx, :);
        Sub_Catalog   = false(length(sub_idx), 1);
        Sub_Catalog(1:length(good_idx)) = true;     % 子种群中 good 在前

        % 兜底：若子种群过小（< 4），直接退化为阶段 2
        if length(sub_idx) < 4
            [XXs, Ls] = GetRelationPairs(Input, Catalog);
            return;
        end

        % 用原 GetRelationPairs 的逻辑构造关系对（输入为子种群）
        [XXs, Ls] = GetRelationPairs(Sub_Input, Sub_Catalog);

        % 兜底：若关系对数量过少（< 20），退化为阶段 2
        if size(XXs, 1) < 20
            [XXs, Ls] = GetRelationPairs(Input, Catalog);
        end

    else
        %% 阶段 2：与 REMO_new2 原版一致（先易后难的"难"）
        % 全部 N 个解参与配对，包括边界 / 中间解
        [XXs, Ls] = GetRelationPairs(Input, Catalog);
    end
end
