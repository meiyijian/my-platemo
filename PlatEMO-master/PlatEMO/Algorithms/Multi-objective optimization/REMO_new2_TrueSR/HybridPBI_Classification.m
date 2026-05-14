function [good_idx,bad_idx,Catalog,confidence,Ref,score_hybrid] = HybridPBI_Classification(Population,ratio,varargin)
% 混合 PBI 分类：结合"基于参考向量的 PBI 分数"和"基于参考点的动态 PBI 标签"
%
% 主要用途：
%   为 REMO_new2_TrueSR 算法提供训练信号。
%   score_hybrid 是核心输出——一个连续的打分值，用于后续生成软排序对。
%   Catalog 仅保留用于兼容性/诊断。
%
% 核心思路：
%   1. 基于参考向量的 PBI（score_v）：
%      - 生成均匀参考向量 → 将解投影到向量上 → 计算 PBI 距离 → 转为分数
%   2. 基于参考点的动态 PBI（label_dyn）：
%      - 用 RefSelect 选参考解 → GetOutput_PBI 判断每个解是否"好"
%   3. 混合（score_hybrid）：
%      - 早期（ratio 小）：更信任参考向量的连续分数（探索阶段）
%      - 后期（ratio 大）：更信任参考点的硬标签（收敛阶段）
%
% 输入参数：
%   Population: 种群对象，包含每个解的决策变量和目标值
%   ratio     : 进化进度 = 当前评估次数 / 最大评估次数（0 到 1）
%   varargin  : 可选参数对
%              'Nref'  - 参考向量数量（默认 = 种群大小 N）
%              'k'     - 参考解数量（默认 6）
%              'theta' - PBI 惩罚参数（默认 5）
%
% 输出参数：
%   good_idx    : 好解的索引（分数最高的前 25%）
%   bad_idx     : 差解的索引（分数最低的前 25%）
%   Catalog     : 逻辑向量，标记哪些是"好解"（基于 score_hybrid 阈值）
%   confidence  : 两种方法的一致性程度（score_v 与 label_dyn 的接近度）
%   Ref         : 选出的参考解（种群对象）
%   score_hybrid: 混合分数（核心输出，用于训练神经网络）

    N     = length(Population);           % 种群中解的个数
    M     = size(Population(1).obj,2);    % 目标函数个数（优化问题的目标维度）

    % 从可选参数中提取配置
    Nref  = get_option(varargin,'Nref',N);
    k     = get_option(varargin,'k',6);
    theta = get_option(varargin,'theta',5);

    % 提取所有解的目标值矩阵（N 行 × M 列）
    PopObj = Population.objs;

    % ==================== 步骤1：生成参考向量 V ====================
    % 参考向量是目标空间中均匀分布的射线方向
    if M <= 3 || N < 50
        % 低维问题或种群较小时：直接使用均匀采样的参考向量
        % 'ILD' 表示 Incremental Lattice Design，保证向量均匀分布
        V = UniformPoint(Nref, M, 'ILD');
        % 将每个向量归一化为单位长度（方向不变，长度变为 1）
        V = V ./ vecnorm(V, 2, 2);
    else
        % 高维问题且种群较大：使用自适应参考向量
        % 根据当前种群中帕累托前沿的分布来调整向量方向
        V = AdaptiveReferenceVectors(PopObj, Nref);
    end

    % ==================== 步骤2：选择参考解 ====================
    % 用 RSEA 策略从种群中选择 k 个有代表性的参考解
    Ref    = RefSelect(Population, k);
    RefObj = Ref.objs;  % 参考解的目标值

    % 理想点 Zmin：当前种群中每个目标的最小值
    Zmin = min(PopObj, [], 1);

    % ==================== 步骤3：将每个解分配给最近的参考向量 ====================
    % 用余弦相似度衡量：1 - pdist2(..., 'cosine') = 余弦相似度
    cosine = 1 - pdist2(PopObj, V, 'cosine');
    % max(..., [], 2)：对每一行（每个解）找到最相似的参考向量的索引
    [~, ref_idx] = max(cosine, [], 2);

    % ==================== 步骤4：计算基于参考向量的 PBI 分数 ====================
    d1 = zeros(N, 1);  % 沿参考向量方向的投影距离
    d2 = zeros(N, 1);  % 垂直于参考向量方向的偏离距离

    for i = 1:N
        % w：当前解被分配到的参考向量方向
        w = V(ref_idx(i), :);

        % d1：沿参考向量的投影距离 = (解向量)·(单位方向向量)
        % 公式：(PopObj(i,:) - Zmin) * w' 是点积，除以 norm(w) 是因为 w 不一定单位
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);

        % proj：解在参考向量方向上的投影点坐标
        proj = Zmin + d1(i) * w;

        % d2：解到投影点的欧氏距离（即垂直偏离量）
        d2(i) = norm(PopObj(i,:) - proj);
    end

    % 经典 PBI 聚合公式：PBI = d1 + theta * d2
    % d1 越小越好（更靠近理想点），d2 越小越好（更贴近参考方向）
    PBI_v   = d1 + theta .* d2;

    % 将 PBI 值转为分数：PBI 越小分数越高
    % max(PBI_v, 0) 确保非负，1/(1+x) 将 [0,∞) 映射到 (0,1]
    score_v = 1 ./ (1 + max(PBI_v, 0));

    % ==================== 步骤5：计算基于参考点的动态 PBI 标签 ====================
    % label_dyn 是二值标签（0 或 1），由 GetOutput_PBI 自适应产生
    label_dyn = GetOutput_PBI(PopObj, RefObj);

    % ==================== 步骤6：混合两种信号 ====================
    % alpha：进化早期的权重更高，更信任 score_v（连续分数）
    % 1-alpha：进化后期的权重更高，更信任 label_dyn（硬标签）
    alpha        = 1 - ratio;                          % ratio 从 0→1，alpha 从 1→0
    score_hybrid = alpha .* score_v + (1-alpha) .* double(label_dyn);

    % 置信度 = 两种方法意见的一致性
    % 当 score_v 和 label_dyn 接近时，confidence 高（两人意见一致）
    % 当两者相差大时，confidence 低（说明该解的评价存在分歧）
    confidence = 1 - abs(score_v - double(label_dyn));

    % ==================== 步骤7：选出最好和最差的解 ====================
    % 按混合分数从高到低排序
    [~, idx_sorted] = sort(score_hybrid, 'descend');

    good_num = ceil(N/4);  % 取前 25% 作为好解
    bad_num  = good_num;   % 取后 25% 作为差解（数量相同）
    good_idx = idx_sorted(1:good_num);                % 好解索引
    bad_idx  = idx_sorted(end-bad_num+1:end);          % 差解索引

    % Catalog：标记好解的逻辑向量（兼容旧接口）
    Catalog = false(N, 1);
    Catalog(good_idx) = true;
end

function val = get_option(args,name,default)
% 从可选参数列表中提取参数值的小工具函数
    val = default;
    for i = 1:2:length(args)
        if strcmpi(args{i}, name)
            val = args{i+1};
            return;
        end
    end
end

function V = AdaptiveReferenceVectors(PopObj, Nref)
% 自适应生成参考向量：根据当前帕累托前沿的分布调整向量方向
% 目的：使参考向量集中分布在有解的区域，避免浪费到空区域
%
% 步骤：
%   1. 找出当前种群中的非支配解（帕累托前沿）
%   2. 对这些解做 k-means 聚类
%   3. 将聚类中心作为参考向量的方向

    M = size(PopObj, 2);  % 目标个数

    % ---- 尝试获取非支配解（帕累托前沿） ----
    try
        FrontNo   = NDSort(PopObj, 1);             % 非支配排序，FrontNo==1 是第一前沿
        ParetoObj = PopObj(FrontNo == 1, :);        % 提取帕累托前沿上的解
        nPareto   = size(ParetoObj, 1);             % 帕累托解的数量
    catch
        % 如果非支配排序失败，回退到均匀参考向量
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 如果帕累托解太少，回退到均匀参考向量
    if nPareto < max(10, Nref/2) || nPareto < 2
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % ---- 对帕累托解做归一化和聚类 ----
    Zmin  = min(ParetoObj, [], 1);    % 帕累托前沿的最小值
    Zmax  = max(ParetoObj, [], 1);    % 帕累托前沿的最大值
    range = Zmax - Zmin;              % 各目标的范围

    % 如果某个目标维度范围太小（所有解在这个维度几乎相同），回退到均匀向量
    if any(range < 1e-12)
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 将帕累托解归一化到 [0,1] 区间
    ParetoObj_norm = (ParetoObj - Zmin) ./ range;

    % 聚类：将帕累托解聚为最多 Nref 个簇，簇中心作为参考向量方向
    nClusters = min(Nref, nPareto);
    try
        [~, C] = kmeans(ParetoObj_norm, nClusters, ...
            'MaxIter', 100, 'Replicates', 5, 'EmptyAction', 'singleton');
        % MaxIter=100：k-means 最多迭代 100 次
        % Replicates=5：从 5 个不同的初始点出发，取最好的结果
        % EmptyAction='singleton'：如果某个簇变空，随机选一个点作为新中心
    catch
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 如果聚类中心数量不够 Nref，通过复制来补齐
    if size(C, 1) < Nref
        repTimes = ceil(Nref / size(C, 1));  % 需要复制的次数
        C = repmat(C, repTimes, 1);           % 复制
        C = C(1:Nref, :);                     % 截取前 Nref 个
    end

    % 将聚类中心还原到原始尺度，并归一化为单位向量
    V = C .* range + Zmin;          % 反归一化到原始尺度
    V = V ./ vecnorm(V, 2, 2);      % 归一化为方向向量（长度=1）
end
