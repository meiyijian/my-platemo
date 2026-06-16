function PairBank = BuildPairBank_ParetoPBI_SGDA(PopDec, PopObj, Subsets, RefCell, cfg)
% BuildPairBank_ParetoPBI_SGDA - Pair labels from subset Pareto + PBI.
%
% For each pair, the label is first decided by Pareto dominance in the
% expert's own objective subset. Only nondominated pairs use PBI/scalarizing
% fallback. This keeps group experts local: their labels describe only their
% objective group, never full-space dominance unless the subset is full.

    if nargin < 5 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'pairMaxPerExpert', 6000);
    cfg = setIfMissing(cfg, 'thetaPBI', 5);
    cfg = setIfMissing(cfg, 'tieMargin', 1e-3);
    cfg = setIfMissing(cfg, 'pairFeatureType', 'concat');
    cfg = setIfMissing(cfg, 'balanceLabels', true);
    cfg = setIfMissing(cfg, 'useLabelWeight', true);

    K = numel(Subsets);
    PairBank = repmat(struct('subset', [], 'X', [], 'Y', [], 'W', [], ...
        'stats', struct()), 1, K);

    [N, ~] = size(PopDec);
    if N < 2
        for k = 1:K
            PairBank(k).subset = Subsets{k};
            PairBank(k).stats = emptyStats();
        end
        return;
    end

    for k = 1:K
        S = unique(Subsets{k}(:)', 'stable');
        S = S(S >= 1 & S <= size(PopObj, 2));
        if isempty(S)
            PairBank(k).subset = S;
            PairBank(k).stats = emptyStats();
            continue;
        end

        Fsub = PopObj(:, S);
        V = RefCell{k};

        Pmin = quantile(Fsub, 0.10, 1);
        Pmax = quantile(Fsub, 0.90, 1);
        Pspan = max(Pmax - Pmin, 1e-12);
        Fnorm = (Fsub - Pmin) ./ Pspan;

        budget = max(3, cfg.pairMaxPerExpert);
        if N <= 120
            [ia, ib] = meshgrid(1:N, 1:N);
            ia = ia(:);
            ib = ib(:);
            keep = ia ~= ib;
            ia = ia(keep);
            ib = ib(keep);
        else
            nSample = min(4*budget, N*(N-1));
            ia = randi(N, nSample, 1);
            ib = randi(N, nSample, 1);
            keep = ia ~= ib;
            ia = ia(keep);
            ib = ib(keep);
        end

        nPair = numel(ia);
        Y = zeros(nPair, 1);
        W = ones(nPair, 1);
        srcPareto = false(nPair, 1);

        Fa = Fsub(ia, :);
        Fb = Fsub(ib, :);
        Fna = Fnorm(ia, :);
        Fnb = Fnorm(ib, :);

        leqAll = all(Fa <= Fb, 2);
        ltAny  = any(Fa <  Fb, 2);
        geqAll = all(Fa >= Fb, 2);
        gtAny  = any(Fa >  Fb, 2);
        aDomb = leqAll & ltAny;
        bDoma = geqAll & gtAny;
        nondom = ~(aDomb | bDoma);

        Y(aDomb) = +1;
        Y(bDoma) = -1;
        srcPareto(aDomb | bDoma) = true;

        idxNd = find(nondom);
        if ~isempty(idxNd)
            gA = minPBI(Fna(idxNd, :), V, cfg.thetaPBI);
            gB = minPBI(Fnb(idxNd, :), V, cfg.thetaPBI);
            scale = max(max(abs(gA), abs(gB)), 1e-12);
            relDiff = (gB - gA) ./ scale;

            yPBI = zeros(numel(idxNd), 1);
            yPBI(relDiff >  cfg.tieMargin) = +1;
            yPBI(relDiff < -cfg.tieMargin) = -1;

            wPBI = ones(numel(idxNd), 1);
            if cfg.useLabelWeight
                wPBI = min(1, abs(relDiff) ./ max(5*cfg.tieMargin, 1e-12));
                wPBI = max(wPBI, 0.1);
            end
            Y(idxNd) = yPBI;
            W(idxNd) = wPBI;
        end

        idxP = find(Y == +1);
        idxN = find(Y == -1);
        idxZ = find(Y == 0);

        if cfg.balanceLabels
            perClass = max(1, floor(budget/3));
            idxP = sampleRand(idxP, perClass);
            idxN = sampleRand(idxN, perClass);
            idxZ = sampleRand(idxZ, perClass);
            finalIdx = [idxP; idxN; idxZ];
        else
            finalIdx = [idxP; idxN; idxZ];
            if numel(finalIdx) > budget
                finalIdx = finalIdx(randperm(numel(finalIdx), budget));
            end
        end
        if isempty(finalIdx)
            PairBank(k).subset = S;
            PairBank(k).stats = emptyStats();
            continue;
        end
        finalIdx = finalIdx(randperm(numel(finalIdx)));

        Xa = PopDec(ia(finalIdx), :);
        Xb = PopDec(ib(finalIdx), :);
        switch lower(cfg.pairFeatureType)
            case 'diffabs'
                X = abs(Xa - Xb);
            otherwise
                X = [Xa, Xb];
        end

        PairBank(k).subset = S;
        PairBank(k).X = X;
        PairBank(k).Y = Y(finalIdx);
        PairBank(k).W = W(finalIdx);

        st = emptyStats();
        st.subsetSize = numel(S);
        st.nPosRaw = numel(idxP);
        st.nNegRaw = numel(idxN);
        st.nZeroRaw = numel(idxZ);
        st.paretoRatio = mean(srcPareto);
        if isempty(idxNd)
            st.lowMarginRate = 0;
        else
            st.lowMarginRate = mean(W(idxNd) < 0.5);
        end
        st.totalPair = numel(finalIdx);
        st.labelHist = [sum(PairBank(k).Y == +1), ...
                        sum(PairBank(k).Y == 0), ...
                        sum(PairBank(k).Y == -1)];
        PairBank(k).stats = st;
    end
end

function g = minPBI(F, V, theta)
    if isempty(F)
        g = zeros(0, 1);
        return;
    end
    if isempty(V) || size(V, 2) ~= size(F, 2)
        g = sum(F, 2);
        return;
    end
    Vn = V ./ max(sqrt(sum(V.^2, 2)), 1e-12);
    n = size(F, 1);
    g = inf(n, 1);
    for r = 1:size(Vn, 1)
        v = Vn(r, :);
        d1 = F * v';
        proj = d1 * v;
        d2 = sqrt(sum((F - proj).^2, 2));
        g = min(g, d1 + theta*d2);
    end
end

function s = sampleRand(idx, n)
    if isempty(idx) || n <= 0
        s = zeros(0, 1);
    elseif numel(idx) <= n
        s = idx(:);
    else
        s = idx(randperm(numel(idx), n));
        s = s(:);
    end
end

function s = emptyStats()
    s = struct('subsetSize', 0, 'nPosRaw', 0, 'nNegRaw', 0, ...
        'nZeroRaw', 0, 'paretoRatio', 0, 'lowMarginRate', 0, ...
        'totalPair', 0, 'labelHist', [0 0 0]);
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
