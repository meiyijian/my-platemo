function oracle = CVPOracleBatch(Problem, candidates, archiveObj, selectedIndex, K, options)
%CVPORACLEBATCH Off-budget greedy oracle batch diagnostic for one generation.
%   ORACLE = CVPORACLEBATCH(PROBLEM, CANDIDATES, ARCHIVEOBJ, SELECTEDINDEX,
%   K, OPTIONS) computes true objective values for the candidate pool
%   WITHOUT consuming the algorithm's FE budget, then finds the batch of K
%   candidates a greedy oracle would have evaluated, and reports the overlap
%   with the batch the algorithm actually chose.
%
%   FE accounting. Objectives come from PROBLEM.CalObj(PROBLEM.CalDec(dec)).
%   Only PROBLEM.Evaluation increments PROBLEM.FE, so this is off-budget.
%   The values are never returned to the optimizer.
%
%   Why a greedy BATCH oracle and not per-candidate ranking. The explore
%   branch optimizes BATCH marginal value. Two individually excellent but
%   mutually redundant candidates are worth one slot, not two. Ranking
%   candidates by individual gain would credit both and therefore
%   systematically penalise an anti-redundancy mechanism, which is the
%   failure mode this design avoids. The oracle picks
%       x1 = argmin_x  C(A u {x}),
%       x2 = argmin_x  C(A u {x1, x}), ...
%   which is the objective the algorithm's batch rule is trying to hit.
%
%   Coverage objective C. C(S) = mean over reference points of the distance
%   to the NEAREST member of S, using the whole set S rather than only its
%   non-dominated subset. This differs from PlatEMO's IGD metric, which
%   restricts to Population.best, and the difference is deliberate:
%   full-set coverage is monotone non-increasing when a point is added, so
%   the greedy oracle is well posed and each trial costs one distance
%   vector. Front-restricted IGD is not monotone (a new point can dominate
%   archive members and remove them), which would make "the best batch"
%   ill-defined and force a full NDSort per trial. The paper's headline IGD
%   column stays PlatEMO's IGD; C is used only inside this diagnostic, and
%   identically for every arm.
%
%   Cost control. Two subsamples, both recorded, both identical in size
%   across arms:
%     - the reference set is subsampled to OPTIONS.ReferenceSize once per
%       (problem, M) from a deterministic stream, shared by all arms;
%     - when the pool exceeds OPTIONS.PoolLimit the oracle searches a random
%       subsample that is FORCED to contain every actually-selected
%       candidate, so the reported overlap is exact with respect to the
%       algorithm's choice while the oracle's search space is a subsample.
%       HitRate must be read against PoolConsidered, which is recorded.

    oracle = emptyOracle();
    if isempty(candidates) || isempty(selectedIndex) || K < 1
        return;
    end
    reference = options.Reference;
    if isempty(reference) || size(reference, 2) ~= Problem.M
        return;
    end

    poolSize = size(candidates, 1);
    selectedIndex = unique(selectedIndex(:));
    selectedIndex = selectedIndex(selectedIndex >= 1 & selectedIndex <= poolSize);
    if isempty(selectedIndex)
        return;
    end

    considered = (1:poolSize)';
    subsampled = false;
    if poolSize > options.PoolLimit
        others = setdiff(considered, selectedIndex);
        quota = min(max(0, options.PoolLimit - numel(selectedIndex)), numel(others));
        if quota < numel(others)
            picked = others(randperm(options.Stream, numel(others), quota));
            considered = sort([selectedIndex; picked]);
            subsampled = true;
        end
    end

    poolObj = Problem.CalObj(Problem.CalDec(candidates(considered, :)));
    if size(poolObj, 2) ~= Problem.M || any(~isfinite(poolObj(:)))
        return;
    end
    [~, localSelected] = ismember(selectedIndex, considered);
    localSelected = localSelected(localSelected > 0);
    if isempty(localSelected)
        return;
    end

    % Distance from every reference point to the current archive, and to
    % every considered candidate. One pdist2 each, reused by all trials.
    archiveMin = min(pdist2(reference, archiveObj), [], 2);
    candidateDistance = pdist2(reference, poolObj);
    baselineCoverage = mean(archiveMin);

    % Algorithm batch: coverage after adding exactly what it chose.
    algorithmCoverage = mean(min([archiveMin, ...
        candidateDistance(:, localSelected)], [], 2));

    % Greedy oracle batch under the same coverage objective.
    remaining = (1:numel(considered))';
    chosen = zeros(0, 1);
    currentMin = archiveMin;
    oracleCoverage = baselineCoverage;
    for step = 1:min(K, numel(remaining)) %#ok<NASGU>
        trialCoverage = mean(min(currentMin, candidateDistance(:, remaining)), 1);
        [bestValue, bestLocal] = min(trialCoverage);
        if ~isfinite(bestValue)
            break;
        end
        chosen(end+1, 1) = remaining(bestLocal); %#ok<AGROW>
        currentMin = min(currentMin, candidateDistance(:, remaining(bestLocal)));
        oracleCoverage = bestValue;
        remaining(bestLocal) = [];
    end

    hitCount = numel(intersect(localSelected, chosen));
    oracle.Valid = true;
    oracle.HitCount = hitCount;
    oracle.HitRate = hitCount / numel(localSelected);
    oracle.AlgorithmK = numel(localSelected);
    oracle.OracleK = numel(chosen);
    oracle.BaselineCoverage = baselineCoverage;
    oracle.AlgorithmCoverage = algorithmCoverage;
    oracle.OracleCoverage = oracleCoverage;
    oracle.AlgorithmGain = baselineCoverage - algorithmCoverage;
    oracle.OracleGain = baselineCoverage - oracleCoverage;
    if oracle.OracleGain > 1e-12
        oracle.GainRatio = oracle.AlgorithmGain / oracle.OracleGain;
    else
        oracle.GainRatio = NaN;
    end
    oracle.PoolConsidered = numel(considered);
    oracle.PoolTotal = poolSize;
    oracle.Subsampled = subsampled;
end

function oracle = emptyOracle()
    oracle = struct( ...
        'Valid', false, 'HitCount', NaN, 'HitRate', NaN, ...
        'AlgorithmK', NaN, 'OracleK', NaN, ...
        'BaselineCoverage', NaN, 'AlgorithmCoverage', NaN, ...
        'OracleCoverage', NaN, 'AlgorithmGain', NaN, 'OracleGain', NaN, ...
        'GainRatio', NaN, 'PoolConsidered', NaN, 'PoolTotal', NaN, ...
        'Subsampled', false);
end
