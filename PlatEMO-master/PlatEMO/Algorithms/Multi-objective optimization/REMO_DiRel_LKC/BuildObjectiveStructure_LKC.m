function StructState = BuildObjectiveStructure_LKC(PopDec, PopObj, cfg)
% BuildObjectiveStructure_LKC - LMVT-based structure-aware objective grouping.
%
% This implementation follows the LKC idea in Liu et al. (2026): build a
% structural feature matrix Gamma from local slope estimates, measure
% positive structural similarity between objectives, cluster objectives, and
% aggregate all objectives inside each reliable group.  It never performs
% real evaluations; all LMVT slopes are approximated from evaluated samples.

    if nargin < 3 || isempty(cfg)
        cfg = struct();
    end

    if isempty(PopDec) || isempty(PopObj)
        StructState = emptyState();
        StructState.Note = 'Empty PopDec or PopObj.';
        StructState.IsFallback = true;
        return;
    end

    if isvector(PopObj)
        PopObj = PopObj(:);
    end
    if isvector(PopDec)
        PopDec = PopDec(:);
    end

    [N, D] = size(PopDec);
    [NObj, M] = size(PopObj);
    if N ~= NObj
        error('BuildObjectiveStructure_LKC:SizeMismatch', ...
              'PopDec and PopObj must have the same number of rows.');
    end

    nCells = getCfg(cfg, 'nCells', max(3, min(10, floor(sqrt(max(N, 1))))));
    nCells = max(1, round(nCells));
    minGroupReliability = getCfg(cfg, 'minGroupReliability', 0.65);
    maxKMeansIter       = getCfg(cfg, 'maxKMeansIter', 60);
    kmeansRepeats       = getCfg(cfg, 'kmeansRepeats', 5);
    epsDx               = getCfg(cfg, 'epsDx', 1e-10);

    [X, decMin, decSpan] = safeMinMax(PopDec);
    [F, objMin, objSpan] = safeMinMax(PopObj);

    [Gamma, PairIndex, PairQuality, CellEdges] = buildGammaLMVT(X, F, nCells, epsDx);
    Sim = pearsonRows(Gamma);

    isFallback = false;
    note = '';

    if M <= 2 || D == 0 || size(Gamma, 2) < 2 || all(PairQuality(:) <= 0) || ...
            all(rowNorm(centerRows(Gamma)) <= 1e-12)
        Groups = singleObjectiveGroups(M);
        ClusterK = numel(Groups);
        SilhouetteScores = nan(max(M-1, 1), 1);
        isFallback = true;
        note = 'Fallback to singleton groups because structural features are insufficient.';
    else
        Z = normalizeRows(centerRows(Gamma));
        [Groups, ClusterK, SilhouetteScores] = clusterObjectivesLKC( ...
            Z, maxKMeansIter, kmeansRepeats);

        [Groups, wasSplit] = repairGroupsBySimilarity(Groups, Sim, minGroupReliability);
        if wasSplit
            note = 'Unsafe clusters were split by positive similarity and reliability checks.';
        end
        if isempty(Groups)
            Groups = singleObjectiveGroups(M);
            ClusterK = numel(Groups);
            isFallback = true;
            note = 'Fallback to singleton groups because clustering returned no valid group.';
        end
    end

    [GroupReliability, GroupWeights, AggregatedObj] = aggregateGroups(F, Gamma, Groups, Sim);

    StructState = struct();
    StructState.Gamma           = Gamma;
    StructState.Sim             = Sim;
    StructState.Groups          = Groups;
    StructState.GroupReliability = GroupReliability;
    StructState.GroupWeights    = GroupWeights;
    StructState.AggregatedObj   = AggregatedObj;

    StructState.CellEdges       = CellEdges;
    StructState.PairIndex       = PairIndex;
    StructState.PairQuality     = PairQuality;
    StructState.ClusterK        = ClusterK;
    StructState.SilhouetteScores = SilhouetteScores;
    StructState.IsFallback      = isFallback;
    StructState.Note            = note;

    StructState.DecMin          = decMin;
    StructState.DecSpan         = decSpan;
    StructState.ObjMin          = objMin;
    StructState.ObjSpan         = objSpan;
end


function [Gamma, PairIndex, PairQuality, CellEdges] = buildGammaLMVT(X, F, nCells, epsDx)
% Approximate Eq. (4)/(12): columns are diagonal cells times coordinate axes.

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
            if dx <= epsDx
                continue;
            end
            Gamma(:, col) = (F(b, :) - F(a, :))' ./ dx;
        end
    end
end


function [a, b, quality] = selectLmvtPair(X, diagCoord, left, right, center, k, epsDx, isLastCell)
% Choose two evaluated samples that approximate the cell-axis endpoints.

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

    if numel(pool) < N
        [a, b, ok] = maxSpreadPair(X, (1:N)', k, epsDx);
        if ok
            quality = 0.25;
            return;
        end
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


function [Groups, bestK, silhouetteScores] = clusterObjectivesLKC(Z, maxIter, repeats)
    M = size(Z, 1);
    if M <= 2
        Groups = singleObjectiveGroups(M);
        bestK = M;
        silhouetteScores = nan(max(M - 1, 1), 1);
        return;
    end

    silhouetteScores = nan(M - 1, 1);
    bestScore = -inf;
    bestLabels = [];
    bestK = 1;

    for k = 2:(M - 1)
        labels = kmeansCorrelation(Z, k, maxIter, repeats);
        score = meanSilhouetteCorrelation(Z, labels);
        silhouetteScores(k) = score;
        if isfinite(score) && score > bestScore
            bestScore = score;
            bestLabels = labels;
            bestK = k;
        end
    end

    if isempty(bestLabels)
        Groups = singleObjectiveGroups(M);
        bestK = M;
        return;
    end

    Groups = labelsToGroups(bestLabels);
end


function labels = kmeansCorrelation(Z, k, maxIter, repeats)
    M = size(Z, 1);
    repeats = max(1, min(repeats, M));
    bestLoss = inf;
    labels = ones(M, 1);

    for r = 1:repeats
        centers = initCenters(Z, k, r);
        oldLabels = zeros(M, 1);
        curLabels = ones(M, 1);

        for iter = 1:maxIter
            sim = Z * centers';
            [~, curLabels] = max(sim, [], 2);

            if isequal(curLabels, oldLabels)
                break;
            end
            oldLabels = curLabels;

            for c = 1:k
                members = find(curLabels == c);
                if isempty(members)
                    centers(c, :) = farthestFromCenters(Z, centers);
                else
                    centers(c, :) = mean(Z(members, :), 1);
                end
            end
            centers = normalizeRows(centers);
        end

        sim = Z * centers';
        maxSim = max(sim, [], 2);
        loss = sum(1 - maxSim);
        if loss < bestLoss
            bestLoss = loss;
            labels = curLabels;
        end
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


function row = farthestFromCenters(Z, centers)
    sim = Z * centers';
    dist = 1 - max(sim, [], 2);
    [~, idx] = max(dist);
    row = Z(idx, :);
end


function score = meanSilhouetteCorrelation(Z, labels)
    M = size(Z, 1);
    K = max(labels);
    Dist = 1 - Z * Z';
    Dist = max(0, min(2, Dist));
    Dist(1:M+1:end) = 0;

    s = zeros(M, 1);
    for i = 1:M
        same = find(labels == labels(i));
        same(same == i) = [];
        if isempty(same)
            a = 0;
        else
            a = mean(Dist(i, same));
        end

        b = inf;
        for c = 1:K
            if c == labels(i)
                continue;
            end
            other = find(labels == c);
            if ~isempty(other)
                b = min(b, mean(Dist(i, other)));
            end
        end

        den = max(a, b);
        if isfinite(den) && den > 0
            s(i) = (b - a) ./ den;
        else
            s(i) = 0;
        end
    end
    score = mean(s);
end


function [Groups, wasSplit] = repairGroupsBySimilarity(Groups, Sim, minRel)
    repaired = {};
    wasSplit = false;

    for g = 1:numel(Groups)
        C = Groups{g}(:)';
        if numel(C) <= 1
            repaired{end+1} = C; %#ok<AGROW>
            continue;
        end

        off = pairwiseValues(Sim, C);
        if any(off <= 0)
            comps = positiveComponents(C, Sim);
            wasSplit = true;
        else
            comps = {C};
        end

        for c = 1:numel(comps)
            CC = comps{c}(:)';
            if numel(CC) <= 1
                repaired{end+1} = CC; %#ok<AGROW>
                continue;
            end
            rel = mean(pairwiseValues(Sim, CC));
            if rel < minRel
                singles = singleObjectiveGroups(numel(CC));
                for s = 1:numel(singles)
                    repaired{end+1} = CC(singles{s}); %#ok<AGROW>
                end
                wasSplit = true;
            else
                repaired{end+1} = CC; %#ok<AGROW>
            end
        end
    end

    Groups = sortGroups(repaired);
end


function comps = positiveComponents(C, Sim)
    n = numel(C);
    seen = false(1, n);
    comps = {};

    for i = 1:n
        if seen(i)
            continue;
        end
        queue = i;
        seen(i) = true;
        comp = [];
        while ~isempty(queue)
            q = queue(1);
            queue(1) = [];
            comp(end+1) = C(q); %#ok<AGROW>

            for r = 1:n
                if ~seen(r) && Sim(C(q), C(r)) > 0
                    seen(r) = true;
                    queue(end+1) = r; %#ok<AGROW>
                end
            end
        end
        comps{end+1} = comp; %#ok<AGROW>
    end
end


function [GroupReliability, GroupWeights, AggregatedObj] = aggregateGroups(F, Gamma, Groups, Sim)
    N = size(F, 1);
    K = numel(Groups);
    GroupReliability = ones(1, K);
    GroupWeights = cell(1, K);
    AggregatedObj = zeros(N, K);
    Z = normalizeRows(centerRows(Gamma));

    for g = 1:K
        C = Groups{g}(:)';
        if isempty(C)
            GroupWeights{g} = [];
            continue;
        end

        if numel(C) == 1
            w = 1;
            GroupReliability(g) = 1;
        else
            GroupReliability(g) = mean(pairwiseValues(Sim, C));
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
    Xclean = zeros(N, D);
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
                Xclean(:, d) = (col - lo) ./ sp;
            else
                span(d) = 1;
                Xclean(:, d) = 0;
            end
        else
            xmin(d) = 0;
            span(d) = 1;
            Xclean(:, d) = 0;
        end
    end
    Xn = min(max(Xclean, 0), 1);
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
    Z = A;
    nz = n > 1e-12;
    Z(nz, :) = bsxfun(@rdivide, A(nz, :), n(nz));
    Z(~nz, :) = 0;
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


function Groups = labelsToGroups(labels)
    labs = unique(labels(:)', 'stable');
    Groups = cell(1, numel(labs));
    for i = 1:numel(labs)
        Groups{i} = find(labels(:)' == labs(i));
    end
    Groups = sortGroups(Groups);
end


function Groups = singleObjectiveGroups(M)
    Groups = cell(1, M);
    for i = 1:M
        Groups{i} = i;
    end
end


function Groups = sortGroups(Groups)
    keep = ~cellfun(@isempty, Groups);
    Groups = Groups(keep);
    firstIdx = zeros(1, numel(Groups));
    for i = 1:numel(Groups)
        Groups{i} = unique(Groups{i}(:)', 'stable');
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
    S.Gamma = [];
    S.Sim = [];
    S.Groups = {};
    S.GroupReliability = [];
    S.GroupWeights = {};
    S.AggregatedObj = [];
    S.CellEdges = [];
    S.PairIndex = [];
    S.PairQuality = [];
    S.ClusterK = 0;
    S.SilhouetteScores = [];
    S.IsFallback = false;
    S.Note = '';
end
