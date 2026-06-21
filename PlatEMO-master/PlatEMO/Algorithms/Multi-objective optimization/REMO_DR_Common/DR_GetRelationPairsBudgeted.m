function [XXs, Ls, Catalog] = DR_GetRelationPairsBudgeted(Input, Obj, pairMax, RefObj, scalarGap)
% DR_GetRelationPairsBudgeted - Pareto-first relation pairs with PBI fallback.

    if nargin < 3 || isempty(pairMax)
        pairMax = 6000;
    end
    if nargin < 4
        RefObj = [];
    end
    if nargin < 5 || isempty(scalarGap)
        scalarGap = 0.05;
    end

    N = size(Input, 1);
    D = size(Input, 2);
    Catalog = GetOutputPBI_DR(Obj, RefObj);

    if N < 2 || isempty(Obj)
        XXs = zeros(0, 2 * D);
        Ls = zeros(0, 1);
        return;
    end

    F = safeMinMaxLocal(Obj);
    maxDirected = N * (N - 1);
    pairI = zeros(maxDirected, 1);
    pairJ = zeros(maxDirected, 1);
    labels = zeros(maxDirected, 1);
    nPair = 0;

    for i = 1:N-1
        for j = i+1:N
            lab = compareObjectives(F(i, :), F(j, :), scalarGap);
            nPair = nPair + 1;
            pairI(nPair) = i;
            pairJ(nPair) = j;
            labels(nPair) = lab;
            nPair = nPair + 1;
            pairI(nPair) = j;
            pairJ(nPair) = i;
            labels(nPair) = -lab;
        end
    end

    pairI = pairI(1:nPair);
    pairJ = pairJ(1:nPair);
    labels = labels(1:nPair);

    if ~any(labels == 1) && ~any(labels == -1)
        [XXs, Ls] = relationPairsFromCatalog(Input, Catalog, pairMax);
        return;
    end

    keep = balancedSample(labels, pairMax);
    pairI = pairI(keep);
    pairJ = pairJ(keep);
    Ls = labels(keep);
    XXs = [Input(pairI, :), Input(pairJ, :)];

    if isempty(XXs)
        [XXs, Ls] = relationPairsFromCatalog(Input, Catalog, pairMax);
    end
end


function label = compareObjectives(fi, fj, scalarGap)
    iDomJ = all(fi <= fj) && any(fi < fj);
    jDomI = all(fj <= fi) && any(fj < fi);
    if iDomJ
        label = 1;
    elseif jDomI
        label = -1;
    else
        gap = mean(fi) - mean(fj);
        if gap < -scalarGap
            label = 1;
        elseif gap > scalarGap
            label = -1;
        else
            label = 0;
        end
    end
end


function keep = balancedSample(labels, pairMax)
    pairMax = max(3, pairMax);
    perClass = max(1, floor(pairMax / 3));
    keep = [];
    classes = [0, 1, -1];
    for c = classes
        idx = find(labels == c);
        if numel(idx) > perClass
            idx = idx(randperm(numel(idx), perClass));
        end
        keep = [keep; idx(:)]; %#ok<AGROW>
    end

    if numel(keep) < min(pairMax, numel(labels))
        rest = setdiff((1:numel(labels))', keep, 'stable');
        need = min(numel(rest), pairMax - numel(keep));
        if need > 0
            rest = rest(randperm(numel(rest), need));
            keep = [keep; rest(:)];
        end
    end
    if numel(keep) > pairMax
        keep = keep(randperm(numel(keep), pairMax));
    else
        keep = keep(randperm(numel(keep)));
    end
end


function [XXs, Ls] = relationPairsFromCatalog(Input, Catalog, pairMax)
    Catalog = Catalog(:);
    C1 = find(Catalog == 1);
    C2 = find(Catalog ~= 1);
    D = size(Input, 2);
    if isempty(C1) || isempty(C2) || size(Input, 1) < 2
        XXs = zeros(0, 2 * D);
        Ls = zeros(0, 1);
        return;
    end

    perClass = max(1, floor(max(3, pairMax) / 3));
    [XXp, Lp] = sampleCross(Input, C1, C2, perClass, 1);
    [XXn, Ln] = sampleCross(Input, C2, C1, perClass, -1);
    [XXz, Lz] = sampleSame(Input, C1, C2, perClass);
    XXs = [XXz; XXp; XXn];
    Ls = [Lz; Lp; Ln];

    if size(XXs, 1) > pairMax
        keep = randperm(size(XXs, 1), pairMax);
        XXs = XXs(keep, :);
        Ls = Ls(keep);
    elseif ~isempty(Ls)
        order = randperm(numel(Ls));
        XXs = XXs(order, :);
        Ls = Ls(order);
    end
end


function [XX, L] = sampleCross(Input, A, B, nPair, label)
    nPair = min(nPair, numel(A) * numel(B));
    if nPair <= 0
        XX = zeros(0, 2 * size(Input, 2));
        L = zeros(0, 1);
        return;
    end
    lin = randperm(numel(A) * numel(B), nPair);
    [ia, ib] = ind2sub([numel(A), numel(B)], lin);
    XX = [Input(A(ia), :), Input(B(ib), :)];
    L = label .* ones(nPair, 1);
end


function [XX, L] = sampleSame(Input, C1, C2, nPair)
    n1 = floor(nPair / 2);
    n2 = nPair - n1;
    [XX1, L1] = sampleWithin(Input, C1, n1);
    [XX2, L2] = sampleWithin(Input, C2, n2);
    missing = nPair - size(XX1, 1) - size(XX2, 1);
    if missing > 0
        if size(XX1, 1) < n1
            [XXextra, Lextra] = sampleWithin(Input, C2, missing);
        else
            [XXextra, Lextra] = sampleWithin(Input, C1, missing);
        end
        XX = [XX1; XX2; XXextra];
        L = [L1; L2; Lextra];
    else
        XX = [XX1; XX2];
        L = [L1; L2];
    end
end


function [XX, L] = sampleWithin(Input, A, nPair)
    m = numel(A);
    if m < 2 || nPair <= 0
        XX = zeros(0, 2 * size(Input, 2));
        L = zeros(0, 1);
        return;
    end
    maxPair = m * (m - 1);
    nPair = min(nPair, maxPair);
    lin = randperm(maxPair, nPair);
    ia = floor((lin - 1) / (m - 1)) + 1;
    ib = mod(lin - 1, m - 1) + 1;
    ib(ib >= ia) = ib(ib >= ia) + 1;
    XX = [Input(A(ia), :), Input(A(ib), :)];
    L = zeros(nPair, 1);
end


function Catalog = GetOutputPBI_DR(PopObj, RefObj)
    N = size(PopObj, 1);
    if N == 0
        Catalog = zeros(0, 1);
        return;
    end
    F = safeMinMaxLocal(PopObj);
    M = size(F, 2);
    if isempty(RefObj)
        score = mean(F, 2);
    else
        R = safeMinMaxLocal(RefObj);
        if size(R, 2) ~= M
            score = mean(F, 2);
        else
            ideal = min([F; R], [], 1);
            V = bsxfun(@minus, R, ideal);
            V = normalizeRows(V);
            V(sum(abs(V), 2) <= 1e-12, :) = [];
            if isempty(V)
                score = mean(F, 2);
            else
                Y = bsxfun(@minus, F, ideal);
                score = inf(N, 1);
                theta = 5;
                for r = 1:size(V, 1)
                    v = V(r, :);
                    d1 = Y * v';
                    proj = d1 * v;
                    d2 = sqrt(sum((Y - proj).^2, 2));
                    score = min(score, d1 + theta .* d2);
                end
            end
        end
    end

    nGood = max(1, min(N - 1, ceil(0.4 * N)));
    [~, ord] = sort(score, 'ascend');
    Catalog = zeros(N, 1);
    Catalog(ord(1:nGood)) = 1;
end


function Xn = safeMinMaxLocal(X)
    X = double(X);
    [N, D] = size(X);
    Xn = zeros(N, D);
    for d = 1:D
        col = X(:, d);
        finite = isfinite(col);
        if any(finite)
            fill = median(col(finite));
            col(~finite) = fill;
            lo = min(col);
            hi = max(col);
            sp = hi - lo;
            if sp > 1e-12
                Xn(:, d) = (col - lo) ./ sp;
            end
        end
    end
end


function Z = normalizeRows(A)
    n = sqrt(sum(A.^2, 2));
    Z = A;
    ok = n > 1e-12;
    Z(ok, :) = bsxfun(@rdivide, A(ok, :), n(ok));
    Z(~ok, :) = 0;
end
