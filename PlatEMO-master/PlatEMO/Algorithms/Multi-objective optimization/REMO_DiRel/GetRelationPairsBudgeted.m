function [XXs, Ls] = GetRelationPairsBudgeted(Input, Catalog, pairMax)
% GetRelationPairsBudgeted - 有上限的平衡关系对构造
%
% 功能概述：
%   从种群中构造用于训练神经网络的"关系对"
%   每个关系对包含两个解 [x_i, x_j] 和一个标签（+1/0/-1）
%
% 什么是关系对？
%   关系对是代理模型的训练数据：
%   - 输入：[x_i的决策变量, x_j的决策变量] 的拼接（2D维）
%   - 标签：表示x_i和x_j的优劣关系
%     +1: x_i ≻ x_j（x_i支配x_j，即x_i在所有目标上都不差于x_j，且至少一个目标更好）
%      0: x_i ~ x_j（两者互不支配，各有优劣）
%     -1: x_j ≻ x_i（x_j支配x_i）
%
% 为什么需要有上限采样？
%   - 原始REMO枚举所有组合：O(n²)复杂度
%   - 种群n=100时：100×99=9900个关系对
%   - 双尺度训练：2×9900=19800个关系对 → 训练慢
%   - 有上限采样：pairMax=6000 → 训练快3倍
%
% 为什么需要平衡采样？
%   - 如果90%的关系对标签是0（互不支配），网络会偏向预测0
%   - 平衡采样：三种标签各占约1/3，避免类别不平衡
%
% 输入：
%   Input   - N×D 矩阵，种群决策变量
%   Catalog - N×1 向量，PBI分类标签（1或非1）
%             1表示"正类"（靠近某个参考向量）
%             非1表示"负类"
%   pairMax - 关系对数量上限，默认6000
%
% 输出：
%   XXs - n×2D 矩阵，关系对输入
%   Ls  - n×1 向量，关系对标签（+1/0/-1）
%
% 调用示例：
%   [XXs, Ls] = GetRelationPairsBudgeted(Input, Catalog, 6000);

    if nargin < 3 || isempty(pairMax)
        pairMax = 6000;
    end

    % 将 Catalog 转为列向量
    Catalog = Catalog(:);

    % 按PBI分类分组
    C1 = find(Catalog == 1);    % 正类索引
    C2 = find(Catalog ~= 1);    % 负类索引

    % 特殊情况处理
    if isempty(C1) || isempty(C2) || size(Input,1) < 2
        XXs = zeros(0, 2*size(Input,2));
        Ls  = zeros(0, 1);
        return;
    end

    % ===================================================================
    % 计算每类关系对的数量
    % ===================================================================
    % 三种关系对：正类≻负类(+1)、负类≻正类(-1)、同类~同类(0)
    % 每类最多 pairMax/3 个，保证平衡
    pairMax  = max(3, pairMax);
    perClass = max(1, floor(pairMax/3));

    % ===================================================================
    % 采样三种关系对
    % ===================================================================

    % +1类：正类 ≻ 负类
    % 从C1和C2中各随机选一个，构造关系对
    [XXp, Lp] = sampleCross(Input, C1, C2, perClass, 1);

    % -1类：负类 ≻ 正类
    [XXn, Ln] = sampleCross(Input, C2, C1, perClass, -1);

    % 0类：同类 ~ 同类
    % 从C1内部或C2内部选两个解，它们互不支配
    [XXz, Lz] = sampleSame(Input, C1, C2, perClass);

    % ===================================================================
    % 合并并打乱
    % ===================================================================
    XXs = [XXz; XXp; XXn];
    Ls  = [Lz;  Lp;  Ln ];

    % 硬上限：如果总数超过pairMax，随机采样
    if size(XXs,1) > pairMax
        keep = randperm(size(XXs,1), pairMax);
        XXs  = XXs(keep,:);
        Ls   = Ls(keep);
    else
        % 否则只是打乱顺序
        order = randperm(size(XXs,1));
        XXs   = XXs(order,:);
        Ls    = Ls(order);
    end
end


%% ========================================================================
%  局部辅助函数
%  ========================================================================

function [XX, L] = sampleCross(Input, A, B, nPair, label)
% sampleCross - 采样跨类关系对
%
% 功能：从集合A和B中各选一个解，构造关系对 [a, b]
%       标签为 label（+1或-1）
%
% 输入：
%   Input - 决策变量矩阵
%   A, B  - 两个集合的索引
%   nPair - 要采样的关系对数量
%   label - 标签值
%
% 输出：
%   XX    - nPair×2D 关系对输入
%   L     - nPair×1 标签

    % 实际能构造的最大对数 = |A| × |B|
    nPair = min(nPair, numel(A)*numel(B));
    if nPair <= 0
        XX = zeros(0, 2*size(Input,2));
        L  = zeros(0, 1);
        return;
    end

    % 随机选择 nPair 个组合
    % lin 是线性索引，需要转换为 (i, j) 下标
    lin = randperm(numel(A)*numel(B), nPair);
    [ia, ib] = ind2sub([numel(A), numel(B)], lin);

    % 构造关系对：[A(ia), B(ib)]
    XX = [Input(A(ia),:), Input(B(ib),:)];
    L  = label .* ones(nPair, 1);
end


function [XX, L] = sampleSame(Input, C1, C2, nPair)
% sampleSame - 采样同类关系对
%
% 功能：从同一类（C1或C2）内部选两个解，构造关系对
%       同类的两个解互不支配，标签为0
%
% 输入：
%   Input - 决策变量矩阵
%   C1, C2 - 正类和负类的索引
%   nPair - 要采样的关系对数量
%
% 输出：
%   XX    - nPair×2D 关系对输入
%   L     - nPair×1 标签（全0）

    % 从C1和C2各采样一半
    n1 = floor(nPair/2);
    n2 = nPair - n1;

    [XX1, L1] = sampleWithin(Input, C1, n1);
    [XX2, L2] = sampleWithin(Input, C2, n2);

    % 如果某个类采样不足，从另一个类补充
    missing = nPair - size(XX1,1) - size(XX2,1);
    if missing > 0
        if size(XX1,1) < n1
            [XXextra, Lextra] = sampleWithin(Input, C2, missing);
        else
            [XXextra, Lextra] = sampleWithin(Input, C1, missing);
        end
        XX = [XX1; XX2; XXextra];
        L  = [L1;  L2;  Lextra];
    else
        XX = [XX1; XX2];
        L  = [L1;  L2 ];
    end
end


function [XX, L] = sampleWithin(Input, A, nPair)
% sampleWithin - 从同一集合内部采样关系对
%
% 功能：从集合A中选两个不同的解，构造关系对 [a_i, a_j]
%       标签为0（互不支配）
%
% 输入：
%   Input - 决策变量矩阵
%   A     - 集合索引
%   nPair - 要采样的关系对数量
%
% 输出：
%   XX    - nPair×2D 关系对输入
%   L     - nPair×1 标签（全0）

    m = numel(A);
    if m < 2 || nPair <= 0
        XX = zeros(0, 2*size(Input,2));
        L  = zeros(0, 1);
        return;
    end

    % 最大可能的对数 = m*(m-1)（有向，不含自环）
    maxPair = m*(m-1);
    nPair   = min(nPair, maxPair);

    % 随机选择 nPair 个组合
    lin = randperm(maxPair, nPair);

    % 将线性索引转换为 (i, j) 下标，确保 i ≠ j
    [ia, ib] = directedNoSelfSub(m, lin);

    % 构造关系对
    XX = [Input(A(ia),:), Input(A(ib),:)];
    L  = zeros(nPair, 1);   % 同类关系，标签为0
end


function [ia, ib] = directedNoSelfSub(m, lin)
% directedNoSelfSub - 将线性索引转换为有向对下标（不含自环）
%
% 功能：
%   将 1~m*(m-1) 的线性索引转换为 (i, j) 下标
%   其中 i ≠ j（不含自环）
%
% 输入：
%   m   - 集合大小
%   lin - 线性索引（1~m*(m-1)）
%
% 输出：
%   ia, ib - 行列下标

    % 公式推导：
    % 对于 m=3，所有有向对（不含自环）：
    % (1,2), (1,3), (2,1), (2,3), (3,1), (3,2)
    % 线性索引：1, 2, 3, 4, 5, 6
    ia = floor((lin-1)/(m-1)) + 1;   % 行下标
    ib = mod(lin-1, m-1) + 1;        % 列下标（初步）
    ib(ib >= ia) = ib(ib >= ia) + 1; % 跳过自环
end
