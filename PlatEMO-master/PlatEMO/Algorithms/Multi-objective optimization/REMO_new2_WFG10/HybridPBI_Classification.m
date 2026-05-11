function [good_idx, bad_idx, Catalog, confidence, Ref] = HybridPBI_Classification(Population, ratio, varargin)
% 混合 PBI 分类（Hybrid PBI Classification）
% 结合参考向量场和动态参考解对种群进行好坏分类
%
% 输入:
%   Population - 种群对象
%   ratio      - 进化比例（已评估次数/总预算，0~1）
%   可选参数:
%     'Nref'  - 参考向量数量（默认 = 种群规模）
%     'k'     - 参考解数量（默认 = 6）
%     'theta' - PBI 惩罚系数（默认 = 5）
%
% 输出:
%   good_idx   - 好解的索引（前 N/4）
%   bad_idx    - 坏解的索引（后 N/4）
%   Catalog    - N x 1 logical，好=true，坏=false
%   confidence - N x 1 置信度（两个信号一致则高）
%   Ref        - 动态参考解（k 个）

    %% ============ 参数解析 ============
    N = length(Population);
    M = size(Population(1).obj, 2);
    Nref = get_option(varargin, 'Nref', N);    % 参考向量数量
    k = get_option(varargin, 'k', 6);          % 参考解数量
    theta = get_option(varargin, 'theta', 5);  % PBI 惩罚系数

    PopObj = [Population.objs];  % N x M 目标值矩阵
    PopDec = [Population.decs];  % N x D 决策变量矩阵

    %% ============ 步骤一：自适应参考向量场 ============
    % 若目标维数很低或种群很小，使用均匀参考向量（省时且足够）
    if M <= 3 || N < 50
        V = UniformPoint(Nref, M, 'ILD');  % 均匀分布的参考向量
        V = V ./ vecnorm(V, 2, 2);         % 归一化为单位向量
    else
        % 高维目标：用 K-means 聚类非支配解生成自适应参考向量
        V = AdaptiveReferenceVectors(PopObj, Nref);
    end

    %% ============ 步骤二：动态参考解选择 ============
    % 使用 RSEA 策略从种群中选 k 个代表性参考解
    Ref = RefSelect(Population, k);
    RefObj = [Ref.objs];

    % 理想点（每个目标的最小值）
    Zmin = min(PopObj, [], 1);

    %% ============ 步骤三：计算参考向量场得分 score_v ============
    % 对每个解，找到夹角最小的参考向量
    cosine = 1 - pdist2(PopObj, V, 'cosine');  % 余弦相似度
    [~, ref_idx] = max(cosine, [], 2);         % 最相似的参考向量索引

    d1 = zeros(N,1);  % 投影长度
    d2 = zeros(N,1);  % 垂直距离
    for i = 1:N
        vi = ref_idx(i);
        w = V(vi,:);  % 对应的参考向量方向

        % d1 = 解到理想点沿 w 方向的投影长度
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
        % 投影点
        proj = Zmin + d1(i) * w;
        % d2 = 解到投影点的垂直距离
        d2(i) = norm(PopObj(i,:) - proj);
    end

    % PBI 距离 = d1 + theta * d2（theta 越大，对偏离方向的惩罚越重）
    PBI_v = d1 + theta * d2;
    % 得分 = 1/(1+PBI)，PBI 越小得分越高（越好）
    score_v = 1 ./ (1 + PBI_v);

    %% ============ 步骤四：动态标签（基于参考解） ============
    % label_dyn: 1=好, 0=坏（基于 PBI 阈值划分）
    label_dyn = GetOutput_PBI(PopObj, RefObj);

    %% ============ 步骤五：融合得分 ============
    % alpha = 1 - ratio
    %   早期 (ratio 小, alpha 大): 侧重全局参考向量场（score_v）
    %   后期 (ratio 大, alpha 小): 侧重局部动态标签（label_dyn）
    alpha = 1 - ratio;
    score_hybrid = alpha * score_v + (1-alpha) * double(label_dyn);

    %% ============ 步骤六：置信度 ============
    % 置信度 = 1 - |score_v - label_dyn|
    % 两个信号越接近，置信度越高（分类越可靠）
    confidence = 1 - abs(score_v - double(label_dyn));

    %% ============ 步骤七：选出好/坏解 ============
    % 按融合得分降序排列
    [~, idx_sorted] = sort(score_hybrid, 'descend');

    % 前 N/4 为好解，后 N/4 为坏解
    good_num = ceil(N / 4);
    bad_num  = good_num;
    good_idx = idx_sorted(1:good_num);
    bad_idx  = idx_sorted(end-bad_num+1:end);

    %% ============ 输出 Catalog ============
    % Catalog: 好=true，其余=false（与原 REMO 兼容）
    Catalog = false(N,1);
    Catalog(good_idx) = true;
    % 注意：中间解和坏解都标记为 false，合并为"坏类"
end

%% ============ 内部函数：解析可选参数 ============
function val = get_option(args, name, default)
% 从 varargin 中提取指定名称的参数值
    for i = 1:2:length(args)
        if strcmpi(args{i}, name)
            val = args{i+1};
            return;
        end
    end
    val = default;  % 未找到则返回默认值
end

%% ============ 内部函数：自适应参考向量 ============
function V = AdaptiveReferenceVectors(PopObj, Nref)
% 根据当前种群的非支配解生成自适应参考向量
% 思路：非支配解的分布反映了当前 Pareto 前沿的形状
%       用 K-means 聚类得到的中心作为参考向量方向
%
% 输入:
%   PopObj - N x M 目标值矩阵
%   Nref   - 所需参考向量数量
% 输出:
%   V      - Nref x M 单位参考向量

    M = size(PopObj, 2);

    % 提取非支配解（第一前沿）
    try
        FrontNo = NDSort(PopObj, 1);
        ParetoIdx = (FrontNo == 1);
        ParetoObj = PopObj(ParetoIdx, :);
        nPareto = size(ParetoObj, 1);
    catch
        % 若 NDSort 出错，直接使用均匀向量
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 若非支配解数量太少，则使用均匀参考向量
    if nPareto < max(10, Nref/2) || nPareto < 2
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 对非支配解的目标值归一化到 [0,1]
    Zmin = min(ParetoObj, [], 1);
    Zmax = max(ParetoObj, [], 1);
    range = Zmax - Zmin;
    if any(range < 1e-12)
        % 若某目标无变化，则使用均匀向量（避免除零）
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end
    ParetoObj_norm = (ParetoObj - Zmin) ./ range;

    % K-means 聚类，簇数取 min(Nref, nPareto)
    nClusters = min(Nref, nPareto);
    try
        [~, C] = kmeans(ParetoObj_norm, nClusters, ...
                       'MaxIter', 100, 'Replicates', 5, ...
                       'EmptyAction', 'singleton');
        if size(C,1) < 1
            error('聚类返回空中心');
        end
    catch
        % 聚类失败，回退均匀向量
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 若聚类中心数不足 Nref，则通过重复扩充
    if size(C,1) < Nref
        repTimes = ceil(Nref / size(C,1));
        C = repmat(C, repTimes, 1);
        C = C(1:Nref, :);
    end

    % 将聚类中心映射回原始空间
    V = C .* range + Zmin;
    % 归一化为单位向量
    V = V ./ vecnorm(V, 2, 2);
end