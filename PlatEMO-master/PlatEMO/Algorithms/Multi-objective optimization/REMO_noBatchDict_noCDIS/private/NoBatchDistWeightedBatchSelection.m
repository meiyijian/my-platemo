function [Next,info] = NoBatchDistWeightedBatchSelection(Candidates,scores,uncertainty,qKeep,batchSize,ratio)
%NoBatchDistWeightedBatchSelection Quality filter plus ambiguity reward, no
%   in-batch distance term.
%   Stage 1, unchanged from the pruned baseline: compute the qKeep quantile of
%   the relation score R and keep every candidate at or above it.
%   Stage 2, unchanged from Lambdat030: inside the retained set only, normalize
%   R and the predicted ambiguity U to [0,1] and build the rewarded acquisition
%       A_t(x) = R~(x) + 0.30*U~(x),   ratio = FE/maxFE.
%   Stage 3 (the ONLY change): the source selector builds the batch by
%       0.75*A_t~ + 0.25*d~,   d = minimum distance to the members already picked.
%   Here the 0.25*d diversification term is deleted, so every member of the
%   batch maximizes A_t alone, re-normalized on the remaining candidates at each
%   step. Re-normalization is monotone, therefore the batch is exactly the
%   descending-A_t order of the retained set and no distance is ever computed.
%   Exact acquisition ties keep the earliest retained position.
%   The batch cap is floor(batchSize) candidates, no minimum completion is
%   applied, the weight stays fixed at 0.30 and the ambiguity reward itself is
%   untouched. Ratio is diagnostic metadata only.
%   info reports the effective reward weight, the (zero) distance weight, and how
%   far the rewarded batch departs from the same selector run with A_t = R.

    scores = scores(:);
    uncertainty = uncertainty(:);
    Next = Candidates([],:);
    lambdaT = 0.30;
    distWeight = 0.00;
    info = struct('nCandidates',size(Candidates,1),'nRetained',0, ...
        'batchSize',batchSize,'target',0,'ratio',ratio, ...
        'lambdaT',lambdaT,'distWeight',distWeight, ...
        'meanReward',NaN,'maxReward',NaN, ...
        'firstChanged',false,'setChanged',false,'orderChanged',false, ...
        'overlap',NaN,'meanAbsRankShift',NaN,'skipped','');
    if isempty(Candidates) || batchSize <= 0
        info.skipped = 'empty-candidates-or-zero-budget';
        return;
    end
    assert(numel(scores) == size(Candidates,1) && all(isfinite(scores)), ...
        'AdaMaO:InvalidScores','Expected one finite score per candidate.');
    assert(numel(uncertainty) == size(Candidates,1) && ...
        all(isfinite(uncertainty)), ...
        'AdaMaO:InvalidUncertainty','Expected one finite ambiguity per candidate.');
    threshold = quantile(scores,qKeep);
    available = find(scores >= threshold);
    target = min(floor(batchSize),numel(available));
    info.nRetained = numel(available);
    info.target = target;
    if target == 0
        info.skipped = 'no-retained-candidate';
        return;
    end
    % Reward term: U is normalized inside the retained set, exactly like R.
    reward = normalizeRemaining(uncertainty(available));
    acquisition = normalizeRemaining(scores(available)) + lambdaT*reward;
    info.meanReward = mean(reward);
    info.maxReward = max(reward);
    % Batch stage: pure acquisition ranking, the distance term is deleted.
    [~,order] = sort(acquisition,'descend');   % stable: ties keep earliest
    selected = available(order(1:target));
    [~,order] = sort(scores(available),'descend');
    baseline = available(order(1:target));
    Next = Candidates(selected,:);
    % How much the reward moved the batch relative to A_t = R.
    info.firstChanged = selected(1) ~= baseline(1);
    info.orderChanged = ~isequal(selected,baseline);
    info.setChanged = ~isequal(sort(selected),sort(baseline));
    info.overlap = numel(intersect(selected,baseline))/numel(baseline);
    keep = false(size(scores));
    keep(available) = true;
    rankScore = ordinalRank(scores(keep));
    rankAcq = ordinalRank(normalizeRemaining(scores(keep)) + ...
        lambdaT*normalizeRemaining(uncertainty(keep)));
    info.meanAbsRankShift = mean(abs(rankScore-rankAcq));
end

function values = normalizeRemaining(values)
%normalizeRemaining Match the pruned selector's within-set normalization.
    values = values(:);
    low = min(values);
    high = max(values);
    if high-low < 1e-12
        values = 0.5*ones(size(values));
    else
        values = (values-low)/(high-low);
    end
end

function r = ordinalRank(values)
%ordinalRank Ranks 1..n by ascending value, ties broken by position.
    [~,order] = sort(values(:));
    r = zeros(numel(order),1);
    r(order) = (1:numel(order))';
end
