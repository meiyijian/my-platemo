function State = DR_BuildLKCReduction(PopDec, PopObj, k_red, cfg)
% DR_BuildLKCReduction - Fixed-k LKC-style structure-aware reduction.
%
% The grouping is built from local LMVT slope features and Pearson
% structural similarity. Unlike REMO_DiRel_LKC, this function always returns
% exactly min(k_red,M) non-empty groups and does not call difficulty modules.

    if nargin < 4 || isempty(cfg)
        cfg = struct();
    end
    if isvector(PopDec)
        PopDec = PopDec(:);
    end
    if isvector(PopObj)
        PopObj = PopObj(:);
    end
    if isempty(PopObj)
        State = emptyState();
        State.Note = 'Empty PopObj.';
        return;
    end

    [N, D] = size(PopDec);
    [NObj, M] = size(PopObj);
    if N ~= NObj
        error('DR_BuildLKCReduction:SizeMismatch', 'PopDec and PopObj must have the same number of rows.');
    end

    k_eff = max(1, min(round(k_red), M));
    nCells = getCfg(cfg, 'nCells', max(3, min(10, floor(sqrt(max(N, 1))))));
    nCells = max(1, round(nCells));
    maxKMeansIter = getCfg(cfg, 'maxKMeansIter', 60);
    kmeansRepeats = getCfg(cfg, 'kmeansRepeats', 8);
    epsDx = getCfg(cfg, 'epsDx', 1e-10);

    [X, ~, ~] = safeMinMax(PopDec);
    [F, ~, ~] = safeMinMax(PopObj);
    [Gamma, PairIndex, PairQuality, CellEdges] = buildGammaLMVT(X, F, nCells, epsDx);
    Sim = pearsonRows(Gamma);

    isFallback = false;
    note = '';
    if k_eff >= M
        Groups = singleObjectiveGroups(M);
        note = 'No reduction because k_red >= M.';
    elseif D == 0 || size(Gamma, 2) < 2 || all(PairQuality(:) <= 0) || ...
            all(rowNorm(centerRows(Gamma)) <= 1e-12)
        Groups = contiguousGroupsByOrder(M, k_eff);
        isFallback = true;
        note = 'Fallback to balanced objective-order groups because structural features are insufficient.';
    else
        Z = normalizeRows(centerRows(Gamma));
        labels = kmeansCorrelation(Z, k_eff, maxKMeansIter, kmeansRepeats);
        Groups = labelsToGroups(labels, k_eff);
        if numel(Groups) ~= k_eff || any(cellfun(@isempty, Groups))
            Groups = contiguousGroupsByOrder(M, k_eff);
            isFallback = true;
            note = 'Fallback to balanced objective-order groups because k-means returned empty groups.';
        end
    end

    [AggregatedObj, GroupWeights, GroupReliability] = aggregateGroups(PopObj, Gamma, Groups, Sim);

    State = struct();
    State.Method = 'LKC';
    State.IsFixed = false;
    State.Groups = Groups;
    State.GroupWeights = GroupWeights;
    State.GroupReliability = GroupReliability;
    State.AggregatedObj = AggregatedObj;
    State.Sim = Sim;
    State.Gamma = Gamma;
    State.ClusterK = k_eff;
    State.PairIndex = PairIndex;
    State.PairQuality = PairQuality;
    State.CellEdges = CellEdges;
    State.IsFallback = isFallback;
    State.Note = note;
end


function [Gamma, PairIndex, PairQuality, CellEdges] = buildGammaLMVT(X, F, nCells, epsDx)
    [N, D] = size(X);
    M = size(F, 2);
    Gamma = zeros(M, nCells * D);
    PairIndex = zeros(nCells, D, 2);
    PairQuality = zeros(nCells, D);
    CellEdges = linspace(0, 1, nCells + 1);

    if N < 2 || D == 0
        return;
    end

    diagCoord = mean(X, 2);
    for c = 1:nCells
        left = CellEdges(c);
        right = CellEdges(c + 1);
        center = 0.5 * (left + right);
        for k = 1:D
            col = (c - 1) * D + k;
            [a, b, q] = selectLmvtPair(X, diagCoord, left, right, center, k, epsDx, c == nCells);
            PairIndex(c, k, :) = [a, b];
            PairQuality(c, k) = q;
            if q <= 0 || a == b
                continue;
            end
            if X(b, k) < X(a, k)
                tmp = a; a = b; b = tmp;
            end
            dx = abs(X(b, k) - X(a, k));
            if dx > epsDx
                Gamma(:, col) = (F(b, :) - F(a, :))' ./ dx;
            end
        end
    end
end


function [a, b, quality] = selectLmvtPair(X, diagCoord, left, right, center, k, epsDx, isLastCell)
    N = size(X, 1);
    D = size(X, 2);
    if isLastCell
        pool = find(diagCoord >= left & diagCoord <= right);
    else
        pool = find(diagCoord >= left & diagCoord < right);
    end

    if numel(pool) < 2
        pool = (1:N)';
        poolQuality = 0.50;
    else
        poolQuality = 1.00;
    end

    protoA = center .* ones(1, D);
    protoB = protoA;
    protoA(k) = left;
    protoB(k) = right;
    [a, b, ok] = nearestEndpointPair(X, pool, protoA, protoB, k, epsDx);
    if ok
        quality = poolQuality;
        return;
    end

    [a, b, ok] = maxSpreadPair(X, pool, k, epsDx);
    if ok
        quality = 0.75 * poolQuality;
        return;
    end

    a = 1;
    b = min(2, N);
    quality = 0;
end


function [a, b, ok] = nearestEndpointPair(X, pool, protoA, protoB, k, epsDx)
    XA = X(pool, :);
    dA = sum(bsxfun(@minus, XA, protoA).^2, 2);
    dB = sum(bsxfun(@minus, XA, protoB).^2, 2);
    [~, ordA] = sort(dA, 'ascend');
    [~, ordB] = sort(dB, 'ascend');
    limitA = min(8, numel(ordA));
    limitB = min(8, numel(ordB));
    best = inf;
    a = pool(ordA(1));
    b = pool(ordB(1));
    ok = false;

    for ia = 1:limitA
        candA = pool(ordA(ia));
        for ib = 1:limitB
            candB = pool(ordB(ib));
            if candA == candB
                continue;
            end
            dx = abs(X(candB, k) - X(candA, k));
            if dx <= epsDx
                continue;
            end
            score = dA(ordA(ia)) + dB(ordB(ib));
            if score < best
                best = score;
                a = candA;
                b = candB;
                ok = true;
            end
        end
    end
end


function [a, b, ok] = maxSpreadPair(X, pool, k, epsDx)
    vals = X(pool, k);
    [vmin, imin] = min(vals);
    [vmax, imax] = max(vals);
    a = pool(imin);
    b = pool(imax);
    ok = a ~= b && abs(vmax - vmin) > epsDx;
end


function labels = kmeansCorrelation(Z, k, maxIter, repeats)
    M = size(Z, 1);
    repeats = max(1, repeats);
    labels = balancedInitialLabels(M, k);
    bestLoss = inf;

    for r = 1:repeats
        centers = initCenters(Z, k, r);
        oldLabels = zeros(M, 1);
        curLabels = ones(M, 1);

        for iter = 1:maxIter
            sim = Z * centers';
            [~, curLabels] = max(sim, [], 2);
            curLabels = repairEmptyLabels(curLabels, sim, k);
            if isequal(curLabels, oldLabels)
                break;
            end
            oldLabels = curLabels;
            for c = 1:k
                members = find(curLabels == c);
                centers(c, :) = mean(Z(members, :), 1);
            end
            centers = normalizeRows(centers);
        end

        sim = Z * centers';
        idx = sub2ind(size(sim), (1:M)', curLabels);
        loss = sum(1 - sim(idx));
        if loss < bestLoss
            bestLoss = loss;
            labels = curLabels;
        end
    end
end


function labels = balancedInitialLabels(M, k)
    labels = zeros(M, 1);
    for i = 1:M
        labels(i) = mod(i - 1, k) + 1;
    end
end


function labels = repairEmptyLabels(labels, sim, k)
    for c = 1:k
        if any(labels == c)
            continue;
        end
        counts = accumarray(labels, 1, [k, 1]);
        donorClusters = find(counts > 1);
        if isempty(donorClusters)
            labels(c) = c;
            continue;
        end
        donorMask = ismember(labels, donorClusters);
        donorIdx = find(donorMask);
        assignedSim = sim(sub2ind(size(sim), donorIdx, labels(donorIdx)));
        [~, worstLocal] = min(assignedSim);
        labels(donorIdx(worstLocal)) = c;
    end
end


function centers = initCenters(Z, k, seedIndex)
    M = size(Z, 1);
    centers = zeros(k, size(Z, 2));
    first = mod(seedIndex - 1, M) + 1;
    chosen = first;
    centers(1, :) = Z(first, :);

    for c = 2:k
        sim = Z * centers(1:c-1, :)';
        dist = 1 - max(sim, [], 2);
        dist(chosen) = -inf;
        [~, idx] = max(dist);
        chosen = [chosen; idx]; %#ok<AGROW>
        centers(c, :) = Z(idx, :);
    end
    centers = normalizeRows(centers);
end


function Groups = labelsToGroups(labels, k)
    Groups = cell(1, k);
    for c = 1:k
        Groups{c} = find(labels(:)' == c);
    end
    Groups = sortGroups(Groups);
end


function Groups = contiguousGroupsByOrder(M, k)
    Groups = cell(1, k);
    for i = 1:M
        g = mod(i - 1, k) + 1;
        Groups{g}(end+1) = i; %#ok<AGROW>
    end
    Groups = sortGroups(Groups);
end


function Groups = singleObjectiveGroups(M)
    Groups = cell(1, M);
    for i = 1:M
        Groups{i} = i;
    end
end


function [AggregatedObj, GroupWeights, GroupReliability] = aggregateGroups(PopObj, Gamma, Groups, Sim)
    F = safeMinMaxLocal(PopObj);
    N = size(F, 1);
    K = numel(Groups);
    AggregatedObj = zeros(N, K);
    GroupWeights = cell(1, K);
    GroupReliability = ones(1, K);
    Z = normalizeRows(centerRows(Gamma));

    for g = 1:K
        C = Groups{g}(:)';
        if numel(C) == 1
            w = 1;
            rel = 1;
        else
            rel = mean(pairwiseValues(Sim, C));
            center = mean(Z(C, :), 1);
            dist = sqrt(sum(bsxfun(@minus, Z(C, :), center).^2, 2));
            if any(~isfinite(dist))
                dist = zeros(numel(C), 1);
            end
            w = exp(-dist(:)');
            if sum(w) <= 0 || any(~isfinite(w))
                w = ones(1, numel(C)) ./ numel(C);
            else
                w = w ./ sum(w);
            end
        end
        GroupWeights{g} = w;
        GroupReliability(g) = rel;
        AggregatedObj(:, g) = F(:, C) * w(:);
    end
end


function Sim = pearsonRows(A)
    M = size(A, 1);
    Sim = eye(M);
    if M == 0
        Sim = zeros(0, 0);
        return;
    end

    B = centerRows(A);
    nr = rowNorm(B);
    for i = 1:M
        for j = i+1:M
            den = nr(i) * nr(j);
            if den <= 1e-12
                rho = 0;
            else
                rho = (B(i, :) * B(j, :)') ./ den;
                rho = max(-1, min(1, rho));
            end
            Sim(i, j) = rho;
            Sim(j, i) = rho;
        end
    end
end


function [Xn, xmin, span] = safeMinMax(X)
    X = double(X);
    [N, D] = size(X);
    Xn = zeros(N, D);
    xmin = zeros(1, D);
    span = ones(1, D);
    for d = 1:D
        col = X(:, d);
        finite = isfinite(col);
        if any(finite)
            fill = median(col(finite));
            col(~finite) = fill;
            lo = min(col);
            hi = max(col);
            sp = hi - lo;
            xmin(d) = lo;
            if sp > 1e-12
                span(d) = sp;
                Xn(:, d) = (col - lo) ./ sp;
            end
        end
    end
    Xn = min(max(Xn, 0), 1);
end


function Xn = safeMinMaxLocal(X)
    [Xn, ~, ~] = safeMinMax(X);
end


function B = centerRows(A)
    if isempty(A)
        B = A;
    else
        B = bsxfun(@minus, A, mean(A, 2));
    end
end


function Z = normalizeRows(A)
    n = rowNorm(A);
    Z = zeros(size(A));
    for i = 1:size(A, 1)
        if n(i) > 1e-12
            Z(i, :) = A(i, :) ./ n(i);
        end
    end
end


function n = rowNorm(A)
    n = sqrt(sum(A.^2, 2));
end


function vals = pairwiseValues(Sim, C)
    vals = [];
    for i = 1:numel(C)
        for j = i+1:numel(C)
            vals(end+1) = Sim(C(i), C(j)); %#ok<AGROW>
        end
    end
    if isempty(vals)
        vals = 1;
    end
end


function Groups = sortGroups(Groups)
    keep = ~cellfun(@isempty, Groups);
    Groups = Groups(keep);
    firstIdx = zeros(1, numel(Groups));
    for i = 1:numel(Groups)
        Groups{i} = sort(unique(Groups{i}(:)'));
        firstIdx(i) = min(Groups{i});
    end
    [~, ord] = sort(firstIdx, 'ascend');
    Groups = Groups(ord);
end


function value = getCfg(cfg, name, defaultValue)
    if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
        value = cfg.(name);
    else
        value = defaultValue;
    end
end


function S = emptyState()
    S = struct();
    S.Method = 'LKC';
    S.IsFixed = false;
    S.Groups = {};
    S.GroupWeights = {};
    S.GroupReliability = [];
    S.AggregatedObj = [];
    S.Sim = [];
    S.Gamma = [];
    S.ClusterK = 0;
    S.IsFallback = true;
    S.Note = '';
end
