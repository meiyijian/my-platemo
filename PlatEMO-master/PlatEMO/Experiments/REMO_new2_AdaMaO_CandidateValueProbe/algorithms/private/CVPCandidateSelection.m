function [Next, trace] = CVPCandidateSelection( ...
    Problem, Ref, Input, wmax, Smodel, qKeep, nMin, nMax, armID)
%CVPCANDIDATESELECTION Five candidate-selection rules on ONE shared host.
%   [NEXT, TRACE] = CVPCANDIDATESELECTION(...) generates the inner-loop
%   candidate pool exactly once and then applies the rule selected by
%   ARMID. Framework, HPC labels, k_eff, GA operator, indicator model and
%   environmental selection are supplied by the caller and are identical
%   across arms, so ARMID is the single manipulated factor.
%
%   Arm rules
%     0  V0_REMO_RULE      last inner round only; score>3.9 else top-4
%     1  V1_POOL_ONLY      accumulated pool; relation top-nMax
%     2  V2_EXPLORE_ONLY   accumulated pool; ambiguity + dispersion
%     3  V3_INDICATOR_ONLY accumulated pool; relation coarse + SDE rerank
%     4  V4_FULL           accumulated pool; pMix draw between 2 and 3
%
%   Inner-loop parent scoring is FROZEN to the simple (unweighted) mean for
%   every arm so the candidate pool is generated identically. The shipped
%   algorithm instead uses the confidence-weighted mean while in explore
%   mode; TRACE.GenerationAggregationChanged counts how often that frozen
%   choice would have altered the parent set, which bounds the cost of the
%   freeze rather than hiding it.

    mode = resolveMode(armID, Smodel);

    %% ---- Inner-loop candidate generation (identical for all arms) ----
    NextRound = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    accumulated = NextRound;
    generated = size(NextRound, 1);
    roundNumber = 1;
    lastRound = NextRound;
    aggregationEligible = 0;
    aggregationChanged = 0;

    while generated < wmax && ~isempty(NextRound)
        [simpleScore, weightedScore] = CVPRelationScores(Smodel, NextRound);
        keepNumber = min(length(Ref), size(NextRound, 1));
        if keepNumber < 1
            break;
        end
        simpleParents = topKIndex(simpleScore, keepNumber);
        weightedParents = topKIndex(weightedScore, keepNumber);
        aggregationEligible = aggregationEligible + 1;
        aggregationChanged = aggregationChanged + ...
            ~isequal(sort(simpleParents), sort(weightedParents));

        parents = NextRound(simpleParents, :);
        NextRound = OperatorGA(Problem, [parents; Ref.decs], {1, 15, 1, 5});
        roundNumber = roundNumber + 1;
        lastRound = NextRound;
        accumulated = [accumulated; NextRound]; %#ok<AGROW>
        generated = generated + size(NextRound, 1);
    end

    if isempty(accumulated)
        Next = zeros(0, size(Input, 2));
        trace = emptyTrace(mode, armID);
        return;
    end

    candidates = unique(accumulated, 'rows', 'stable');
    lastUnique = unique(lastRound, 'rows', 'stable');
    inLastRound = ismember(candidates, lastUnique, 'rows');

    %% ---- Relation scores on the shared pool ----
    [simpleScore, weightedScore, ambiguity] = ...
        CVPRelationScores(Smodel, candidates);
    lambda = ambiguityWeight(Smodel);

    %% ---- Arm-specific final selection ----
    indicatorOperational = false;
    switch armID
        case 0
            [selected, retainedCount] = selectRemoRule( ...
                simpleScore, inLastRound);
        case 1
            [selected, retainedCount] = selectRelationTopK( ...
                simpleScore, true(size(candidates, 1), 1), nMax);
        case 2
            [selected, retainedCount] = selectExplore( ...
                candidates, weightedScore, ambiguity, lambda, qKeep, nMax);
        case 3
            [selected, retainedCount, indicatorOperational] = ...
                selectIndicator(Smodel, candidates, simpleScore, nMax);
        case 4
            if mode == "indicator"
                [selected, retainedCount, indicatorOperational] = ...
                    selectIndicator(Smodel, candidates, simpleScore, nMax);
            else
                [selected, retainedCount] = selectExplore( ...
                    candidates, weightedScore, ambiguity, lambda, qKeep, nMax);
            end
        otherwise
            error("CVP:UnknownArm", "Unsupported arm identifier: %d", armID);
    end

    selected = selected(:);
    Next = candidates(selected, :);

    %% ---- Trace ----
    trace = struct();
    trace.ArmID = armID;
    trace.Mode = mode;
    trace.AttemptedMode = string(Smodel.mode);
    trace.Candidates = candidates;
    trace.SelectedIndex = selected;
    trace.SelectedK = numel(selected);
    trace.RetainedCount = retainedCount;
    trace.SimpleScore = simpleScore;
    trace.WeightedScore = weightedScore;
    trace.Ambiguity = ambiguity;
    trace.LambdaT = lambda;
    trace.PErr = Smodel.p_err;
    trace.InLastRound = inLastRound;
    trace.AccumRawCount = size(accumulated, 1);
    trace.AccumUniqueCount = size(candidates, 1);
    trace.LastRoundUniqueCount = size(lastUnique, 1);
    trace.RoundCount = roundNumber;
    trace.GenerationAggregationEligible = aggregationEligible;
    trace.GenerationAggregationChanged = aggregationChanged;
    trace.IndicatorAvailable = ~isempty(Smodel.IndicatorModel);
    trace.IndicatorOperational = indicatorOperational;
    trace.FinalAggregationWeighted = ismember(armID, [2, 4]) && mode ~= "indicator";
end

%% ======================= arm routing =======================
function mode = resolveMode(armID, Smodel)
    switch armID
        case 2
            mode = "explore";
        case 3
            if isempty(Smodel.IndicatorModel)
                mode = "indicator_fallback";
            else
                mode = "indicator";
            end
        case 4
            mode = string(Smodel.mode);
        otherwise
            mode = "relation";
    end
end

%% ======================= selection rules =======================
function [selected, retainedCount] = selectRemoRule(simpleScore, inLastRound)
% Original REMO rule: last inner round only, score>3.9 else top-4.
    index = find(inLastRound);
    retainedCount = numel(index);
    if isempty(index)
        selected = zeros(0, 1);
        return;
    end
    localScore = simpleScore(index);
    above = localScore > 3.9;
    if nnz(above) < 4
        [~, order] = sort(localScore, 'descend');
        selected = index(order(1:min(4, numel(order))));
    else
        selected = index(above);
    end
end

function [selected, retainedCount] = selectRelationTopK(score, universe, K)
    index = find(universe);
    retainedCount = numel(index);
    if isempty(index) || K < 1
        selected = zeros(0, 1);
        return;
    end
    [~, order] = sort(score(index), 'descend');
    selected = index(order(1:min(K, numel(order))));
end

function [selected, retainedCount] = selectExplore( ...
        candidates, weightedScore, ambiguity, lambda, qKeep, K)
% Shipped explore branch: ambiguity-augmented score, qKeep retention,
% then quality/dispersion greedy batch selection.
    count = size(candidates, 1);
    augmented = norm01(weightedScore) + lambda .* norm01(ambiguity);
    retained = find(augmented >= quantile(augmented, qKeep));
    if numel(retained) < K
        [~, order] = sort(augmented, 'descend');
        retained = order(1:min(K, count));
    end
    retainedCount = numel(retained);
    evaluationNumber = min(K, retainedCount);
    selected = dispersionGreedy(candidates, retained, augmented, evaluationNumber);
end

function [selected, retainedCount, operational] = selectIndicator( ...
        Smodel, candidates, simpleScore, K)
% Shipped indicator branch: relation coarse screening then SVR reranking.
    count = numel(simpleScore);
    keep = min(count, max(20, ceil(0.30 * count)));
    [~, order] = sort(simpleScore, 'descend');
    coarseIndex = order(1:keep);
    retainedCount = numel(coarseIndex);

    indicatorScore = simpleScore(coarseIndex);
    operational = false;
    if ~isempty(Smodel.IndicatorModel)
        try
            prediction = predict(Smodel.IndicatorModel, candidates(coarseIndex, :));
            if numel(prediction) == numel(coarseIndex) && all(isfinite(prediction))
                indicatorScore = prediction(:);
                operational = true;
            end
        catch
        end
    end

    [~, localOrder] = sort(indicatorScore, 'descend');
    selected = coarseIndex(localOrder(1:min(K, numel(localOrder))));
end

function selected = dispersionGreedy(candidates, index, score, K)
    index = index(:);
    if isempty(index) || K < 1
        selected = zeros(0, 1);
        return;
    end
    if numel(index) <= K
        [~, order] = sort(score(index), 'descend');
        selected = index(order);
        return;
    end
    [~, first] = max(score(index));
    selected = index(first);
    remain = index;
    remain(first) = [];
    while numel(selected) < K && ~isempty(remain)
        distance = min(pdist2(candidates(remain, :), candidates(selected, :)), [], 2);
        acquisition = 0.75 .* norm01(score(remain)) + 0.25 .* norm01(distance);
        [~, best] = max(acquisition);
        selected(end+1, 1) = remain(best); %#ok<AGROW>
        remain(best) = [];
    end
end

%% ======================= helpers =======================
function lambda = ambiguityWeight(Smodel)
    pError = Smodel.p_err;
    if ~isscalar(pError) || ~isfinite(pError)
        pError = 1;
    end
    lambda = Smodel.lambda0 * (1 - Smodel.ratio) * max(0, 1 - pError / 0.45);
end

function index = topKIndex(score, K)
    [~, order] = sort(score, 'descend');
    index = order(1:min(K, numel(order)));
end

function scaled = norm01(value)
    value = value(:);
    if isempty(value)
        scaled = value;
    elseif max(value) - min(value) < 1e-12
        scaled = 0.5 .* ones(size(value));
    else
        scaled = (value - min(value)) ./ (max(value) - min(value));
    end
end

function trace = emptyTrace(mode, armID)
    trace = struct( ...
        'ArmID', armID, 'Mode', mode, 'AttemptedMode', mode, ...
        'Candidates', zeros(0, 0), 'SelectedIndex', zeros(0, 1), ...
        'SelectedK', 0, 'RetainedCount', 0, ...
        'SimpleScore', zeros(0, 1), 'WeightedScore', zeros(0, 1), ...
        'Ambiguity', zeros(0, 1), 'LambdaT', 0, 'PErr', NaN, ...
        'InLastRound', false(0, 1), 'AccumRawCount', 0, ...
        'AccumUniqueCount', 0, 'LastRoundUniqueCount', 0, 'RoundCount', 0, ...
        'GenerationAggregationEligible', 0, 'GenerationAggregationChanged', 0, ...
        'IndicatorAvailable', false, 'IndicatorOperational', false, ...
        'FinalAggregationWeighted', false);
end
