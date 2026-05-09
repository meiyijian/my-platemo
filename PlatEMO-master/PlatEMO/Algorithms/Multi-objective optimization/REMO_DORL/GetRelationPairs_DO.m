function [XXs, Ls] = GetRelationPairs_DO(Decs, Objs, Catalog, stage)
% 决策-目标联合关系对构造（创新点 1 + 创新点 3）
%
% 输入：
%   Decs    : N×D 决策变量
%   Objs    : N×M 目标值（已评估，不需要预测）
%   Catalog : N×1 logical（true=好解, false=非好解）
%   stage   : 课程阶段
%             1 = "易"：仅保留目标空间距离 > median 的对（创新 3 ODC）
%             2 = "难"：使用全部对（与原 GetRelationPairs 一致）
%
% 输出：
%   XXs : N_pair × (2D + 2M) 关系对矩阵
%         每行 = [x_i, x_j, f̃_i, f̃_j]
%   Ls  : N_pair × 1 关系标签 ∈ {-1, 0, +1}
%
% 设计动机（创新 1）：
%   原 GetRelationPairs 只用决策变量 [x_i, x_j]，把已花昂贵代价评估出的
%   目标值 f(x) 完全丢弃。由于关系标签 Ls 本质是从 f 经 PBI 推出的，
%   网络得"凭 x 反推 f 的关系"，M ≥ 5 时这一冗余学习负担显著恶化。
%   本函数把归一化后的 f̃ 直接作为附加输入喂入网络，模型负担骤降。

    %% 目标值归一化（min-max，基于当前种群的 ideal/nadir 估计）
    z_min = min(Objs, [], 1);
    z_max = max(Objs, [], 1);
    Objs_norm = (Objs - z_min) ./ (z_max - z_min + eps);   % N×M

    %% 收集 good / bad 索引
    C1_idx = find(Catalog == 1);
    C2_idx = find(Catalog ~= 1);

    %% 构造 4 类索引对（与原 GetRelationPairs 等价，但显式记录索引以对齐 Objs）
    %  原 combvec(A', B') 返回每列 [a; b]，按 (a,b) 顺序为：
    %    a 内变 b 外变（即 a 走完一遍，b 取下一个）
    %  ndgrid(A, B) 返回 J1（A 维内变）, J2（B 维外变） — 顺序一致
    [J1, J2] = ndgrid(C1_idx, C1_idx);
    pairs_C1C1 = [J1(:), J2(:)];
    pairs_C1C1(pairs_C1C1(:,1) == pairs_C1C1(:,2), :) = [];

    [J1, J2] = ndgrid(C1_idx, C2_idx);
    pairs_C1C2 = [J1(:), J2(:)];     % 第一列 ∈ C1, 第二列 ∈ C2

    [J1, J2] = ndgrid(C2_idx, C1_idx);
    pairs_C2C1 = [J1(:), J2(:)];     % 第一列 ∈ C2, 第二列 ∈ C1

    [J1, J2] = ndgrid(C2_idx, C2_idx);
    pairs_C2C2 = [J1(:), J2(:)];
    pairs_C2C2(pairs_C2C2(:,1) == pairs_C2C2(:,2), :) = [];

    %% 平衡子采样（与原版一致）
    t_num = ceil(size(pairs_C1C2, 1) / 2);
    if size(pairs_C1C1, 1) > t_num && size(pairs_C2C2, 1) > t_num
        sel1 = randperm(size(pairs_C1C1, 1), t_num);
        sel2 = randperm(size(pairs_C2C2, 1), t_num);
        pairs_C1C1 = pairs_C1C1(sel1, :);
        pairs_C2C2 = pairs_C2C2(sel2, :);
    elseif size(pairs_C1C1, 1) < t_num
        n2 = min(size(pairs_C2C2, 1), t_num*2 - size(pairs_C1C1, 1));
        if n2 > 0 && n2 < size(pairs_C2C2, 1)
            pairs_C2C2 = pairs_C2C2(randperm(size(pairs_C2C2, 1), n2), :);
        end
    elseif size(pairs_C2C2, 1) < t_num
        n1 = min(size(pairs_C1C1, 1), t_num*2 - size(pairs_C2C2, 1));
        if n1 > 0 && n1 < size(pairs_C1C1, 1)
            pairs_C1C1 = pairs_C1C1(randperm(size(pairs_C1C1, 1), n1), :);
        end
    end

    %% 拼装索引对 + 标签
    %  原版顺序：[C1C1; C2C2; C1C2; C2C1]
    %  标签：    [ 0   ;  0  ;  +1 ;  -1 ]
    all_pairs = [pairs_C1C1; pairs_C2C2; pairs_C1C2; pairs_C2C1];
    Ls = [zeros(size(pairs_C1C1, 1), 1); ...
          zeros(size(pairs_C2C2, 1), 1); ...
          ones(size(pairs_C1C2, 1), 1); ...
          -1 * ones(size(pairs_C2C1, 1), 1)];

    if isempty(all_pairs)
        XXs = [];
        Ls  = [];
        return;
    end

    %% 用索引对从 Decs / Objs_norm 取数，构造 [x_i, x_j, f̃_i, f̃_j]
    XX_dec = [Decs(all_pairs(:,1), :),       Decs(all_pairs(:,2), :)];
    XX_obj = [Objs_norm(all_pairs(:,1), :),  Objs_norm(all_pairs(:,2), :)];
    XXs    = [XX_dec, XX_obj];     % 维度 = 2D + 2M

    %% 创新 3：阶段 1 课程化过滤（按目标距离过滤）
    if stage == 1 && size(XXs, 1) > 30
        D = size(Decs, 2);
        M = size(Objs, 2);
        f_i = XXs(:, 2*D+1     : 2*D+M);
        f_j = XXs(:, 2*D+M+1   : 2*D+2*M);
        gap = vecnorm(f_i - f_j, 2, 2);
        keep = gap > median(gap);
        if sum(keep) >= 20     % 兜底：保留对数太少则不过滤
            XXs = XXs(keep, :);
            Ls  = Ls(keep);
        end
    end
end
