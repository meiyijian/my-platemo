function [Next,info] = Lambdat030WeightedBatchSelection(Candidates,scores,uncertainty,qKeep,batchSize,ratio)
%Lambdat030WeightedBatchSelection Quality filter followed by an ambiguity reward.
%   Stage 1, unchanged from the pruned baseline: compute the qKeep quantile of
%   the relation score R and keep every candidate at or above it.
%   Stage 2: inside the retained set only, normalize R and the predicted
%   ambiguity U to [0,1] and build the rewarded acquisition
%       A_t(x) = R~(x) + 0.30*U~(x),  ratio = FE/maxFE.
%   Stage 3: the first accepted candidate maximizes A_t; each further member
%   maximizes 0.75*A_t~ + 0.25*d~ over the remaining candidates, where both
%   terms are re-normalized on the remaining set at every step. The batch cap
%   is floor(batchSize) candidates and no minimum completion is applied.
%   No p_err gate and no second indicator filter are used.
%   The weight is fixed at 0.30. Ratio is diagnostic metadata only.
%   info reports the effective reward weight and how far the rewarded batch
%   departs from the same selector run with the reward switched off.

    scores = scores(:);
    uncertainty = uncertainty(:);
    selected = zeros(0,1);
    Next = Candidates([],:);
    lambdaT = 0.30;
    info = struct('nCandidates',size(Candidates,1),'nRetained',0, ...
        'batchSize',batchSize,'target',0,'ratio',ratio, ...
        'lambdaT',lambdaT,'meanReward',NaN,'maxReward',NaN, ...
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
    if numel(available) <= target
        [~,order] = sort(acquisition,'descend');
        selected = available(order);
        [~,order] = sort(scores(available),'descend');
        baseline = available(order);
    else
        selected = selectByAcquisition(Candidates,available, ...
            buildValues(size(Candidates,1),available,acquisition),target);
        baseline = selectByAcquisition(Candidates,available,scores,target);
    end
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

function values = buildValues(nTotal,available,acquisition)
%buildValues Spread the retained-set acquisition back to full candidate order.
%   The greedy builder always indexes a full-length vector with the shrinking
%   index set, which is how the pruned selector reads its scores.
    values = zeros(nTotal,1);
    values(available) = acquisition;
end

function selected = selectByAcquisition(Candidates,available,values,target)
%selectByAcquisition Greedy batch builder over the retained candidate set.
%   The first member maximizes VALUES; every later member maximizes
%   0.75*normalized VALUES + 0.25*normalized distance to the members already
%   selected. Both terms are re-normalized on the remaining candidates only.
%   Exact acquisition ties keep the earliest remaining position, as in the
%   pruned selector.
    available = available(:);
    [~,first] = max(values(available));
    selected = zeros(target,1);
    selected(1) = available(first);
    available(first) = [];
    for i = 2:target
        distance = min(pdist2(Candidates(available,:), ...
            Candidates(selected(1:i-1),:)),[],2);
        acquisition = 0.75*normalizeRemaining(values(available)) + ...
            0.25*normalizeRemaining(distance);
        [~,best] = max(acquisition);
        selected(i) = available(best);
        available(best) = [];
    end
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
