function [good_idx, bad_idx, Catalog, confidence, Ref] = HybridPBI_Classification(Population, ratio, varargin)
% HybridPBI_Classification - 混合 PBI 分类
%
% 结合当前种群派生的分布方向场和代表解锚点标签，对种群形成粗质量分组
% 这是 REMO_new2 系列算法的核心分类模块
%
% 分类原理：
%   使用两种信号对种群打分：
%   1. score_v: 当前非支配解自身方向上的连续 PBI 得分
%   2. label_dyn: 当前代表解锚点产生的二值 PBI 标签
% 两种信号都来自当前 Population，不是相互独立的全局先验与局部信息。
%
%   两种信号通过 alpha 权重融合：
%     alpha = 1 - ratio
%     早期 (ratio 小, alpha 大): 侧重分布方向场连续得分
%     后期 (ratio 大, alpha 小): 侧重代表解锚点二值标签
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
%   good_idx   - 融合排名前 N/4 的正组索引
%   bad_idx    - 融合排名后 N/4 的索引，仅作为输出；主程序的 Catalog 不单独使用它
%   Catalog    - N x 1 logical，前 N/4=true，其余 3N/4=false
%   confidence - N x 1 PBI 双表征一致性分数（变量名为兼容保留，不是校准置信概率）
%   Ref        - 从当前种群选出的代表解（k 个）

    %% ============ 参数解析 ============
    N = length(Population);
    M = size(Population(1).obj, 2);
    Nref = get_option(varargin, 'Nref', N);    % 参考向量数量
    k = get_option(varargin, 'k', 6);          % 参考解数量
    theta = get_option(varargin, 'theta', 5);  % PBI 惩罚系数
    rGood = get_option(varargin, 'rGood', 0.25); % 正组比例
    if ~isscalar(rGood) || ~isnumeric(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('AdaMaO:InvalidPositiveGroupRatio', ...
            'rGood must be a finite scalar in (0,0.5].');
    end

    PopObj = [Population.objs];  % N x M 目标值矩阵

    %% ============ 步骤一：当前非支配分布方向场 ============
    % 若目标维数很低或种群很小，使用均匀参考向量（省时且足够）
    if M <= 3 || N < 50
        V = UniformPoint(Nref, M, 'ILD');  % 均匀分布的参考向量
        V = V ./ vecnorm(V, 2, 2);         % 归一化为单位向量
    else
        % 高维目标：直接用当前非支配解自身方向作为数据依赖方向
        V = AdaptiveReferenceVectors(PopObj, Nref);
    end

    %% ============ 步骤二：当前种群代表解选择 ============
    % 使用 RefSelect 从同一当前种群中选 k 个实际评价代表解
    Ref = RefSelect(Population, k);
    RefObj = [Ref.objs];

    % 理想点（每个目标的最小值）
    Zmin = min(PopObj, [], 1);

    %% ============ 步骤三：计算参考向量场得分 score_v ============
    % 对每个解，使用原始目标向量与 V 的余弦相似度找到关联方向
    % 注意：此处分区未减 Zmin，而后续 PBI 投影使用 PopObj-Zmin，两步坐标原点并不一致。
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
    %   早期 (ratio 小, alpha 大): 侧重连续方向场得分 score_v
    %   后期 (ratio 大, alpha 小): 侧重二值锚点标签 label_dyn
    % 两项数值均在 [0,1]，但一个是连续 PBI 变换、一个是二值标签，统计语义并不相同。
    alpha = 1 - ratio;
    score_hybrid = alpha * score_v + (1-alpha) * double(label_dyn);

    %% ============ 步骤六：PBI 双表征一致性 ============
    % 一致性分数 = 1 - |score_v - label_dyn|
    % 数值越高仅表示连续方向场得分与二值锚点标签方向一致，不代表标签正确概率。
    confidence = 1 - abs(score_v - double(label_dyn));

    %% ============ 步骤七：确定正组及末端排名索引 ============
    % 按融合得分降序排列
    [~, idx_sorted] = sort(score_hybrid, 'descend');

    % 计算前 N*rGood 和后 N*rGood 索引；Catalog 只标记正组
    good_num = ceil(N * rGood);
    bad_num  = good_num;
    good_idx = idx_sorted(1:good_num);
    bad_idx  = idx_sorted(end-bad_num+1:end);

    %% ============ 输出 Catalog ============
    % Catalog: 前 N*rGood 正组=true，其余解为非正组
    Catalog = false(N,1);
    Catalog(good_idx) = true;
    % 注意：中间排名和末端排名解都标记为 false，统一作为非正组
end

%% ============ 内部函数：解析可选参数 ============
function val = get_option(args, name, default)
% get_option - 从 varargin 中提取指定名称的参数值
%
% 输入：
%   args    : varargin
%   name    : 参数名
%   default : 默认值
%
% 输出：
%   val : 参数值

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
% AdaptiveReferenceVectors - 根据当前种群的非支配解生成数据依赖方向
%
% 思路：直接把当前非支配近似集的每个解单位化，作为已观测分布方向。
% 这些方向会继承当前种群的覆盖偏差，不能解释为独立的全局参考方向。
%
% 设计动机：
%   高维多目标问题中，数据依赖方向可能更贴近当前已观测非支配分布；
%   是否比均匀方向更有利需要通过独立消融验证。
%
% 为什么不再做 K-means：
%   本算法中 Nref 恒等于种群规模 N，而进入本函数时 nPareto <= N，
%   因此原实现的簇数 min(Nref,nPareto) 恒等于 nPareto，即"每点自成一簇"，
%   聚类中心集合恒等于非支配解集合本身（仅次序不同）。既然聚类恒为恒等映射，
%   就不存在"把多个解归纳为一个方向"的语义，直接取解方向即可，
%   同时省掉 Replicates=5 的重复聚类开销。
%
% 输入:
%   PopObj - N x M 目标值矩阵
%   Nref   - 参考向量数量上限；仅用于回退判定与均匀向量生成
% 输出:
%   V      - nPareto x M 单位参考向量（回退时为 Nref x M）

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

    % 退化前沿判定：若某目标在非支配集上无变化，说明该集合落在更低维子空间，
    % 此时其方向不足以支撑逐目标的方向场，回退均匀向量。
    % （此判定原为 K-means 归一化的除零保护，现独立保留为退化门控，
    %   以维持与既有实验一致的回退条件）
    Zmin = min(ParetoObj, [], 1);
    Zmax = max(ParetoObj, [], 1);
    range = Zmax - Zmin;
    if any(range < 1e-12)
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 直接以每个非支配解自身方向作为参考方向
    % 不做重复扩充：下游只用 max(cosine,[],2) 取最近方向，
    % 重复行不会改变所取到的方向值，故补齐到 Nref 行是冗余操作。
    % 按当前实现相对坐标原点归一化为单位向量；这不等同于对 (V-Zmin) 方向单位化
    V = ParetoObj ./ vecnorm(ParetoObj, 2, 2);
end
