function [Catalog,agreement,Ref,score] = DualPBIContinuousSupervision( ...
    Population,ratio,Nref,k,theta)
%DualPBIContinuousSupervision Continuous dual-PBI relation supervision.
%   The direction-field branch is identical to HybridPBI_Classification.
%   Only the representative-solution branch is changed from a binary
%   threshold label to a continuous PBI score on the same objective scale.

    N = length(Population);
    M = size(Population(1).obj,2);
    PopObj = Population.objs;

    %% Current nondominated distribution direction field
    if M <= 3 || N < 50
        V = UniformPoint(Nref,M,'ILD');
        V = V./vecnorm(V,2,2);
    else
        V = AdaptiveReferenceVectors(PopObj, Nref);
    end

    %% Representative solutions from the current population
    Ref = RefSelect(Population, k);
    RefObj = Ref.objs;
    Zmin = min(PopObj,[],1);

    %% Original continuous direction-field PBI score
    cosine = 1-pdist2(PopObj,V,'cosine');
    [~,refIndex] = max(cosine,[],2);
    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        w = V(refIndex(i),:);
        d1(i) = (PopObj(i,:)-Zmin)*w'/norm(w);
        projection = Zmin+d1(i)*w;
        d2(i) = norm(PopObj(i,:)-projection);
    end
    pbiV = d1+theta*d2;
    scoreV = 1./(1+pbiV);

    %% Continuous representative-solution PBI score
    refDirection = RefObj-Zmin;
    refNorm = vecnorm(refDirection,2,2);
    validRef = find(refNorm > 0);
    if isempty(validRef)
        scoreRef = scoreV;
    else
        validRefObj = RefObj(validRef,:);
        W = refDirection(validRef,:)./refNorm(validRef);

        % Keep the original GetOutput_PBI region association: raw
        % objectives are associated to raw representative objectives.
        [~,assigned] = max( ...
            1-pdist2(PopObj,validRefObj,'cosine'),[],2);
        assignedW = W(assigned,:);
        shifted = PopObj-Zmin;
        d1Ref = sum(shifted.*assignedW,2);
        projectionRef = Zmin+d1Ref.*assignedW;
        d2Ref = vecnorm(PopObj-projectionRef,2,2);
        pbiRef = d1Ref+theta*d2Ref;
        scoreRef = 1./(1+pbiRef);
    end

    %% Progress-based continuous fusion and agreement
    score = (1-ratio)*scoreV+ratio*scoreRef;
    agreement = 1-abs(scoreV-scoreRef);

    %% Keep the original hard top-quarter Catalog
    [~,order] = sort(score,'descend');
    goodCount = ceil(N/4);
    Catalog = false(N,1);
    Catalog(order(1:goodCount)) = true;
end

function V = AdaptiveReferenceVectors(PopObj, Nref)
% AdaptiveReferenceVectors - 根据当前种群的非支配解生成数据依赖方向
%
% 思路：用当前非支配近似集的 K-means 中心概括已观测分布方向。
% 这些方向会继承当前种群的覆盖偏差，不能解释为独立的全局参考方向。
%
% 设计动机：
%   高维多目标问题中，数据依赖方向可能更贴近当前已观测非支配分布；
%   是否比均匀方向更有利需要通过独立消融验证。
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

    % 将聚类中心映射回原始目标坐标
    V = C .* range + Zmin;
    % 按当前实现相对坐标原点归一化为单位向量；这不等同于对 (V-Zmin) 方向单位化
    V = V ./ vecnorm(V, 2, 2);
end
