function Anchors = SelectRelationAnchors_SGDA(ArchDec, ArchObj, cfg)
% SelectRelationAnchors_SGDA - Select elite and diverse archive anchors.

    if nargin < 3 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'anchorMax', 30);
    cfg = setIfMissing(cfg, 'nondomRatio', 0.6);

    Anchors = struct('elite', [], 'diverse', [], 'eliteObj', [], 'diverseObj', []);
    N = size(ArchDec, 1);
    if N == 0
        return;
    end

    try
        [FrontNo, ~] = NDSort(ArchObj, N);
    catch
        FrontNo = simpleND(ArchObj);
    end
    nondomIdx = find(FrontNo == 1);
    if isempty(nondomIdx)
        nondomIdx = 1:N;
    end

    nElite = min(numel(nondomIdx), ceil(cfg.anchorMax * cfg.nondomRatio));
    if numel(nondomIdx) > nElite
        loc = uniformSample(ArchObj(nondomIdx, :), nElite);
        eliteIdx = nondomIdx(loc);
    else
        eliteIdx = nondomIdx;
    end

    Anchors.elite = ArchDec(eliteIdx, :);
    Anchors.eliteObj = ArchObj(eliteIdx, :);

    nDiv = cfg.anchorMax - numel(eliteIdx);
    if nDiv > 0
        otherIdx = setdiff(1:N, eliteIdx, 'stable');
        if numel(otherIdx) > nDiv
            loc = uniformSample(ArchObj(otherIdx, :), nDiv);
            divIdx = otherIdx(loc);
        else
            divIdx = otherIdx;
        end
        Anchors.diverse = ArchDec(divIdx, :);
        Anchors.diverseObj = ArchObj(divIdx, :);
    end
end

function pick = uniformSample(F, k)
    n = size(F, 1);
    if k >= n
        pick = 1:n;
        return;
    end
    Fmin = min(F, [], 1);
    Fmax = max(F, [], 1);
    span = max(Fmax - Fmin, 1e-12);
    Fn = (F - Fmin) ./ span;

    pick = zeros(1, k);
    pick(1) = 1;
    dist = sqrt(sum((Fn - Fn(1, :)).^2, 2));
    for i = 2:k
        [~, idx] = max(dist);
        pick(i) = idx;
        dNew = sqrt(sum((Fn - Fn(idx, :)).^2, 2));
        dist = min(dist, dNew);
    end
end

function FrontNo = simpleND(Obj)
    N = size(Obj, 1);
    FrontNo = inf(1, N);
    rem = true(1, N);
    f = 0;
    while any(rem)
        f = f + 1;
        idx = find(rem);
        domByOther = false(1, numel(idx));
        for i = 1:numel(idx)
            for j = 1:numel(idx)
                if i == j, continue; end
                a = Obj(idx(i), :);
                b = Obj(idx(j), :);
                if all(b <= a) && any(b < a)
                    domByOther(i) = true;
                    break;
                end
            end
        end
        FrontNo(idx(~domByOther)) = f;
        rem(idx(~domByOther)) = false;
    end
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
