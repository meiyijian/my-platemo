function [XXs,Ls] = GetRelationPairsBudgeted(Input, Catalog, pairMax)
%GetRelationPairsBudgeted - Balanced relation-pair sampling with a hard cap.
%
% The original REMO pair builder enumerates almost all pairs. That is fine
% for small populations, but it becomes a dominant cost once DiRel trains
% both full-objective and sub-objective relation models. This local helper
% keeps the same 1/0/-1 relation semantics while sampling a bounded,
% approximately balanced training set.

    if nargin < 3 || isempty(pairMax)
        pairMax = 6000;
    end

    Catalog = Catalog(:);
    C1      = find(Catalog == 1);
    C2      = find(Catalog ~= 1);

    if isempty(C1) || isempty(C2) || size(Input,1) < 2
        XXs = zeros(0, 2*size(Input,2));
        Ls  = zeros(0, 1);
        return;
    end

    pairMax  = max(3, pairMax);
    perClass = max(1, floor(pairMax/3));

    [XXp,Lp] = sampleCross(Input, C1, C2, perClass, 1);
    [XXn,Ln] = sampleCross(Input, C2, C1, perClass, -1);
    [XXz,Lz] = sampleSame(Input, C1, C2, perClass);

    XXs = [XXz; XXp; XXn];
    Ls  = [Lz;  Lp;  Ln ];

    if size(XXs,1) > pairMax
        keep = randperm(size(XXs,1), pairMax);
        XXs  = XXs(keep,:);
        Ls   = Ls(keep);
    else
        order = randperm(size(XXs,1));
        XXs   = XXs(order,:);
        Ls    = Ls(order);
    end
end

function [XX,L] = sampleCross(Input, A, B, nPair, label)
    nPair = min(nPair, numel(A)*numel(B));
    if nPair <= 0
        XX = zeros(0, 2*size(Input,2));
        L  = zeros(0, 1);
        return;
    end

    lin = randperm(numel(A)*numel(B), nPair);
    [ia,ib] = ind2sub([numel(A), numel(B)], lin);
    XX = [Input(A(ia),:), Input(B(ib),:)];
    L  = label .* ones(nPair, 1);
end

function [XX,L] = sampleSame(Input, C1, C2, nPair)
    n1 = floor(nPair/2);
    n2 = nPair - n1;

    [XX1,L1] = sampleWithin(Input, C1, n1);
    [XX2,L2] = sampleWithin(Input, C2, n2);

    missing = nPair - size(XX1,1) - size(XX2,1);
    if missing > 0
        if size(XX1,1) < n1
            [XXextra,Lextra] = sampleWithin(Input, C2, missing);
        else
            [XXextra,Lextra] = sampleWithin(Input, C1, missing);
        end
        XX = [XX1; XX2; XXextra];
        L  = [L1;  L2;  Lextra];
    else
        XX = [XX1; XX2];
        L  = [L1;  L2 ];
    end
end

function [XX,L] = sampleWithin(Input, A, nPair)
    m = numel(A);
    if m < 2 || nPair <= 0
        XX = zeros(0, 2*size(Input,2));
        L  = zeros(0, 1);
        return;
    end

    maxPair = m*(m-1);
    nPair   = min(nPair, maxPair);
    lin     = randperm(maxPair, nPair);
    [ia,ib] = directedNoSelfSub(m, lin);

    XX = [Input(A(ia),:), Input(A(ib),:)];
    L  = zeros(nPair, 1);
end

function [ia,ib] = directedNoSelfSub(m, lin)
    ia = floor((lin-1)/(m-1)) + 1;
    ib = mod(lin-1, m-1) + 1;
    ib(ib >= ia) = ib(ib >= ia) + 1;
end
