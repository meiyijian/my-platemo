classdef REMO_LKCRed < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO with LKC Structure-Aware Objective Reduction — 方案三
% 基于 LKC 局部斜率特征 + Pearson 结构相似度 + correlation k-means
% 将 M 个目标聚类为 k_red 个新目标，每 updateFreq 代重新聚类
% 其余框架与原始 REMO 完全一致
%
% 聚类原理：
%   1. 在决策空间划分网格，每格内计算 LMVT 局部斜率 Gamma(M × nCells*D)
%   2. 对 Gamma 的行计算 Pearson 相似度矩阵 Sim(M×M)
%   3. 对 Gamma 中心化+归一化后做 correlation k-means 聚类
%   4. 若 LMVT 特征不足则 fallback 到顺序均衡分组
%   5. 组内 min-max 归一化 + 等权重平均 → 聚合目标
%
% k_red      --- 3 --- 降维后的目标组数
% updateFreq --- 4 --- 分组更新频率（每 updateFreq 代重新聚类）
% k          --- 6 --- 参考解数量
% gmax       --- 3000 --- 代理模型评估的解数量上限
%
%------------------------------- Reference --------------------------------
% H. Hao, A. Zhou, H. Qian, and H. Zhang. Expensive multiobjective
% optimization by relation learning and prediction. IEEE TEVC, 2022.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group.

    methods
        function main(Algorithm, Problem)
            %% Parameter setting
            [k_red, updateFreq, k, gmax] = Algorithm.ParameterSet(3, 4, 6, 3000);

            %% Add REMO path for shared utility functions
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', 'REMO'));

            %% Check parameter validity
            if Problem.M <= k_red
                error('REMO_LKCRed:InvalidParam', ...
                    'k_red (%d) must be strictly less than M (%d).', k_red, Problem.M);
            end

            %% Initialize population
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower, N, 1).*PopDec + repmat(Problem.lower, N, 1));
            Archive    = Population;

            %% LKC parameters
            nCells   = 5;      % LMVT 网格划分数
            epsDx    = 1e-10;  % 决策变量变化阈值

            %% ★ 初始化时构建 LKC 聚类
            Groups = lkcCluster(Population.decs, Population.objs, k_red, nCells, epsDx);

            %% Optimization loop
            gen = 0;
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                % ★ 每 updateFreq 代重新聚类（跳过第1代，因为已初始化）
                if gen > 1 && mod(gen - 1, updateFreq) == 0
                    Groups = lkcCluster(Population.decs, Population.objs, k_red, nCells, epsDx);
                end

                % Step 1: 选择参考解（在原 M 维目标空间）
                Ref = RefSelect(Population, k);

                % Step 2: ★ 降维 + PBI 分类
                Input       = Population.decs;
                PopObj_red  = applyReduction(Population.objs, Groups);
                RefObj_red  = applyReduction(Ref.objs, Groups);
                Catalog     = GetOutput_PBI(PopObj_red, RefObj_red);

                % Step 3: 构建关系对
                [XXs, YYs] = GetRelationPairs(Input, Catalog);

                % Step 4: 划分训练/测试集
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);

                % Step 5: 训练神经网络
                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut, 1);
                net = patternnet([ceil(xDim*1.5), xDim*1, ceil(xDim/2)]);
                net.trainParam.showWindow = 0;
                net        = train(net, TrainIn_nor', TrainOut_onehot');
                TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre    = onehotconv(net(TestIn_nor')', 2);
                p_err      = sum(TestPre ~= TestOut) / size(TestPre, 1);

                % Step 6: 打包代理模型
                Smodel.X         = Input;
                Smodel.Y         = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;

                % Step 7: 代理模型辅助选择 + 真实评估
                Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % Step 8: 重新选择下一代种群（在原 M 维目标空间）
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end


%% =========================================================================
%  LKC 聚类主函数
%  =========================================================================

function Groups = lkcCluster(PopDec, PopObj, k_red, nCells, epsDx)
% 基于 LKC (Local Monotonicity Verification Technique) 的目标聚类
% 1. 归一化解和目标值
% 2. 构建 LMVT 局部斜率特征 Gamma
% 3. Pearson 相似度 + correlation k-means 聚类
% 4. fallback: 若特征不足则退化为顺序均衡分组

    if nargin < 4, nCells = 5; end
    if nargin < 5, epsDx = 1e-10; end

    [N, D] = size(PopDec);
    M = size(PopObj, 2);
    k_eff = max(1, min(round(k_red), M));
    maxIter = 60;
    repeats = 8;

    [X, ~, ~] = safeMinMax(PopDec);
    [F, ~, ~] = safeMinMax(PopObj);
    Gamma = buildGammaLMVT(X, F, nCells, epsDx);

    % 判断 LMVT 特征是否有效
    if D == 0 || size(Gamma, 2) < 2 || all(Gamma(:) == 0)
        Groups = contiguousGroups(M, k_eff);
        return;
    end

    B = centerRows(Gamma);
    nr = rowNorm(B);
    if all(nr <= 1e-12)
        Groups = contiguousGroups(M, k_eff);
        return;
    end

    Z = normalizeRows(B);
    labels = kmeansCorrelation(Z, k_eff, maxIter, repeats);
    Groups = labelsToGroups(labels, k_eff);

    if numel(Groups) ~= k_eff || any(cellfun(@isempty, Groups))
        Groups = contiguousGroups(M, k_eff);
    end
end


%% =========================================================================
%  LMVT 局部斜率特征构建
%  =========================================================================

function Gamma = buildGammaLMVT(X, F, nCells, epsDx)
% 在决策空间网格中估计局部斜率，构建 M × (nCells*D) 特征矩阵
    [N, D] = size(X);
    M = size(F, 2);
    Gamma = zeros(M, nCells * D);
    if N < 2 || D == 0, return; end

    diagCoord = mean(X, 2);         % 每个解在"对角方向"上的投影坐标
    CellEdges = linspace(0, 1, nCells + 1);

    for c = 1:nCells
        left  = CellEdges(c);
        right = CellEdges(c + 1);
        centerVal = 0.5 * (left + right);
        isLast = (c == nCells);

        for k = 1:D
            col = (c - 1) * D + k;
            [a, b, q] = selectLmvtPair(X, diagCoord, left, right, centerVal, k, epsDx, isLast);
            if q <= 0 || a == b, continue; end
            if X(b, k) < X(a, k), tmp = a; a = b; b = tmp; end
            dx = abs(X(b, k) - X(a, k));
            if dx > epsDx
                Gamma(:, col) = (F(b, :) - F(a, :))' ./ dx;
            end
        end
    end
end


function [a, b, q] = selectLmvtPair(X, diagCoord, left, right, centerVal, k, epsDx, isLast)
% 在每个网格单元格中选择一对端点解来估计斜率
    N = size(X, 1);
    D = size(X, 2);
    if isLast
        pool = find(diagCoord >= left & diagCoord <= right);
    else
        pool = find(diagCoord >= left & diagCoord < right);
    end
    poolQ = 1.0;
    if numel(pool) < 2
        pool = (1:N)';
        poolQ = 0.50;
    end

    protoA = centerVal * ones(1, D);
    protoB = protoA;
    protoA(k) = left;
    protoB(k) = right;

    [a, b, ok] = nearestEndpointPair(X, pool, protoA, protoB, k, epsDx);
    if ok
        q = poolQ; return;
    end
    [a, b, ok] = maxSpreadPair(X, pool, k, epsDx);
    if ok
        q = 0.75 * poolQ; return;
    end
    a = 1; b = min(2, N); q = 0;
end


function [a, b, ok] = nearestEndpointPair(X, pool, protoA, protoB, k, epsDx)
    XA = X(pool, :);
    dA = sum(bsxfun(@minus, XA, protoA).^2, 2);
    dB = sum(bsxfun(@minus, XA, protoB).^2, 2);
    [~, ordA] = sort(dA, 'ascend');
    [~, ordB] = sort(dB, 'ascend');
    limA = min(8, numel(ordA));
    limB = min(8, numel(ordB));
    best = inf;
    a = pool(ordA(1)); b = pool(ordB(1));
    ok = false;

    for ia = 1:limA
        candA = pool(ordA(ia));
        for ib = 1:limB
            candB = pool(ordB(ib));
            if candA == candB, continue; end
            dx = abs(X(candB, k) - X(candA, k));
            if dx <= epsDx, continue; end
            score = dA(ordA(ia)) + dB(ordB(ib));
            if score < best, best = score; a = candA; b = candB; ok = true; end
        end
    end
end


function [a, b, ok] = maxSpreadPair(X, pool, k, epsDx)
    vals = X(pool, k);
    [vmin, imin] = min(vals);
    [vmax, imax] = max(vals);
    a = pool(imin); b = pool(imax);
    ok = (a ~= b) && (abs(vmax - vmin) > epsDx);
end


%% =========================================================================
%  Pearson 行相似度
%  =========================================================================

function Sim = pearsonRows(A)
% 对矩阵的每一行（目标）计算 Pearson 相似度矩阵
    M = size(A, 1);
    Sim = eye(M);
    if M == 0, Sim = zeros(0); return; end
    B = centerRows(A);
    nr = rowNorm(B);
    for i = 1:M
        for j = i+1:M
            den = nr(i) * nr(j);
            if den <= 1e-12
                rho = 0;
            else
                rho = (B(i,:) * B(j,:)') / den;
                rho = max(-1, min(1, rho));
            end
            Sim(i,j) = rho; Sim(j,i) = rho;
        end
    end
end


%% =========================================================================
%  Correlation k-means
%  =========================================================================

function labels = kmeansCorrelation(Z, k, maxIter, repeats)
% 基于余弦相似度的 k-means（等价于 correlation distance 聚类）
    M = size(Z, 1);
    repeats = max(1, repeats);
    labels = balancedInit(M, k);
    bestLoss = inf;

    for r = 1:repeats
        centers = initCenters(Z, k, r);
        old = zeros(M, 1);
        cur = ones(M, 1);
        for iter = 1:maxIter
            sim = Z * centers';
            [~, cur] = max(sim, [], 2);
            cur = repairEmpty(cur, sim, k);
            if isequal(cur, old), break; end
            old = cur;
            for c = 1:k
                members = find(cur == c);
                if ~isempty(members)
                    centers(c, :) = mean(Z(members, :), 1);
                end
            end
            centers = normalizeRows(centers);
        end
        sim = Z * centers';
        idx = sub2ind(size(sim), (1:M)', cur);
        loss = sum(1 - sim(idx));
        if loss < bestLoss, bestLoss = loss; labels = cur; end
    end
end


function labels = balancedInit(M, k)
    labels = mod((0:M-1)', k) + 1;
end


function labels = repairEmpty(labels, sim, k)
    for c = 1:k
        if any(labels == c), continue; end
        cnt = accumarray(labels, 1, [k, 1]);
        donor = find(cnt > 1);
        if isempty(donor), labels(c) = c; continue; end
        mask = ismember(labels, donor);
        idx = find(mask);
        assigned = sim(sub2ind(size(sim), idx, labels(idx)));
        [~, worst] = min(assigned);
        labels(idx(worst)) = c;
    end
end


function centers = initCenters(Z, k, seed)
    M = size(Z, 1);
    centers = zeros(k, size(Z, 2));
    first = mod(seed - 1, M) + 1;
    chosen = first;
    centers(1, :) = Z(first, :);
    for c = 2:k
        simVal = Z * centers(1:c-1, :)';
        dist = 1 - max(simVal, [], 2);
        dist(chosen) = -inf;
        [~, idx] = max(dist);
        chosen = [chosen; idx]; %#ok<AGROW>
        centers(c, :) = Z(idx, :);
    end
    centers = normalizeRows(centers);
end


%% =========================================================================
%  向量/矩阵工具函数
%  =========================================================================

function B = centerRows(A)
    if isempty(A), B = A; else, B = bsxfun(@minus, A, mean(A, 2)); end
end

function Z = normalizeRows(A)
    n = rowNorm(A);
    Z = zeros(size(A));
    for i = 1:size(A, 1)
        if n(i) > 1e-12, Z(i, :) = A(i, :) ./ n(i); end
    end
end

function n = rowNorm(A)
    n = sqrt(sum(A.^2, 2));
end

function [Xn, xmin, span] = safeMinMax(X)
    X = double(X);
    [N, D] = size(X);
    Xn = zeros(N, D); xmin = zeros(1, D); span = ones(1, D);
    for d = 1:D
        col = X(:, d);
        fin = isfinite(col);
        if any(fin)
            fillv = median(col(fin)); col(~fin) = fillv;
            lo = min(col); hi = max(col); sp = hi - lo;
            xmin(d) = lo;
            if sp > 1e-12, span(d) = sp; Xn(:, d) = (col - lo) ./ sp; end
        end
    end
    Xn = min(max(Xn, 0), 1);
end


%% =========================================================================
%  分组工具函数
%  =========================================================================

function Groups = labelsToGroups(labels, k)
    Groups = cell(1, k);
    for g = 1:k
        Groups{g} = find(labels(:)' == g);
    end
    Groups = sortGroups(Groups);
end

function Groups = sortGroups(Groups)
    keep = ~cellfun(@isempty, Groups);
    Groups = Groups(keep);
    firstIdx = zeros(1, numel(Groups));
    for i = 1:numel(Groups)
        Groups{i} = sort(unique(Groups{i}(:)'));  %#ok<AGROW>
        firstIdx(i) = min(Groups{i});
    end
    [~, ord] = sort(firstIdx, 'ascend');
    Groups = Groups(ord);
end

function Groups = contiguousGroups(M, k)
% fallback: 按顺序均衡分配目标到各组
    Groups = cell(1, k);
    for i = 1:M
        g = mod(i - 1, k) + 1;
        Groups{g}(end + 1) = i; %#ok<AGROW>
    end
end


%% =========================================================================
%  降维应用函数（等权重，与 RandRed/SpCorrRed 一致）
%  =========================================================================

function ReducedObj = applyReduction(PopObj, Groups)
    [N, M] = size(PopObj);
    K = numel(Groups);

    % Step 1: 逐列 min-max 归一化
    F = double(PopObj);
    for d = 1:M
        col = F(:, d);
        fin = isfinite(col);
        if any(fin)
            fillv = median(col(fin)); col(~fin) = fillv;
        end
        lo = min(col); hi = max(col);
        sp = hi - lo;
        if sp > 1e-12, F(:, d) = (col - lo) ./ sp;
        else, F(:, d) = 0; end
    end

    % Step 2: 组内等权重平均
    ReducedObj = zeros(N, K);
    for g = 1:K
        C = Groups{g}(:)';
        w = ones(1, numel(C)) ./ numel(C);
        ReducedObj(:, g) = F(:, C) * w(:);
    end
end
