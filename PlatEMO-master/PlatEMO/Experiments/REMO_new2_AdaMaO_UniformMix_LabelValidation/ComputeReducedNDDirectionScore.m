function [score, V, nDir, dirSource] = ComputeReducedNDDirectionScore(PopObj, kEff, theta, seed)
%ComputeReducedNDDirectionScore L8: reduced-resolution ND direction score.
%   [score, V, nDir, dirSource] = ComputeReducedNDDirectionScore(...)
%   reproduces the frozen score_v computation but with the direction
%   count reduced to kEff (M10 -> 15, M20 -> 30) instead of Nref=100.
%   The K-means clustering uses an OFFLINE seed and must restore the
%   global RNG afterwards (random negative-control rule).
%
%   Direction-source decision mirrors the frozen AdaptiveReferenceVectors:
%     - if the non-dominated front is large enough: ND_KMEANS with
%       nClusters = min(kEff, nPareto)
%     - otherwise: uniform directions (kEff of them)
%   The caller is responsible for passing the SAME fallback eligibility
%   recorded in Stage 1 (via snapshot.FallbackReason); this function only
%   re-derives the direction set for an already-eligible ND snapshot.
%
%   Inputs:
%     PopObj - N x M objective matrix
%     kEff   - scalar direction budget (frozen M10=15, M20=30)
%     theta  - scalar PBI penalty
%     seed   - scalar offline seed for the K-means call
%   Outputs:
%     score    - N x 1 score vector
%     V        - nDir x M direction matrix
%     nDir     - scalar, size(V,1)
%     dirSource- 1=ND_KMEANS, 3=UNIFORM_FRONT_TOO_SMALL, 4=UNIFORM_ZERO_RANGE

    N = size(PopObj,1);
    M = size(PopObj,2);

    savedState = rng;
    cleanup    = onCleanup(@() rng(savedState));
    rng(seed,'twister');

    dirSource = 1;   % ND_KMEANS unless a guard triggers
    try
        FrontNo   = NDSort(PopObj, 1);
        ParetoIdx = (FrontNo == 1);
        ParetoObj = PopObj(ParetoIdx, :);
        nPareto   = size(ParetoObj,1);
    catch
        nPareto = 0;
    end

    if nPareto < max(10, kEff/2) || nPareto < 2
        V = UniformPoint(kEff, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        dirSource = 3;   % UNIFORM_FRONT_TOO_SMALL
        nDir = size(V,1);
        score = lvPbiScore(PopObj, V, theta);
        return;
    end

    Zmin  = min(ParetoObj, [], 1);
    Zmax  = max(ParetoObj, [], 1);
    range = Zmax - Zmin;
    if any(range < 1e-12)
        V = UniformPoint(kEff, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        dirSource = 4;   % UNIFORM_ZERO_RANGE
        nDir = size(V,1);
        score = lvPbiScore(PopObj, V, theta);
        return;
    end
    ParetoObj_norm = (ParetoObj - Zmin) ./ range;

    nClusters = min(kEff, nPareto);
    try
        [~, C] = kmeans(ParetoObj_norm, nClusters, ...
            'MaxIter', 100, 'Replicates', 5, 'EmptyAction', 'singleton');
        if size(C,1) < 1
            error('empty centers');
        end
    catch
        V = UniformPoint(kEff, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        dirSource = 6;   % UNIFORM_KMEANS_FAILURE
        nDir = size(V,1);
        score = lvPbiScore(PopObj, V, theta);
        return;
    end

    if size(C,1) < kEff
        repTimes = ceil(kEff / size(C,1));
        C = repmat(C, repTimes, 1);
        C = C(1:kEff, :);
    end

    V = C .* range + Zmin;
    V = V ./ vecnorm(V, 2, 2);
    nDir = size(V,1);
    score = lvPbiScore(PopObj, V, theta);
end

%% ============ shared frozen score_v statements ============
function score = lvPbiScore(PopObj, V, theta)
    N = size(PopObj,1);
    Zmin = min(PopObj, [], 1);
    cosine = 1 - pdist2(PopObj, V, 'cosine');
    [~, ref_idx] = max(cosine, [], 2);

    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        vi = ref_idx(i);
        w  = V(vi,:);
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
        proj  = Zmin + d1(i) * w;
        d2(i) = norm(PopObj(i,:) - proj);
    end
    PBI_v = d1 + theta * d2;
    score = 1 ./ (1 + PBI_v);
end
