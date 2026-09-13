function [Next,selected] = PrunedWeightedBatchSelection(Candidates,scores,qKeep,batchSize)
%PrunedWeightedBatchSelection Restore quality-distance weighting after filtering.
%   Uses the Pruned relation-score quantile and batch cap, with no ambiguity
%   reward or minimum batch completion. Selects the best score first, then
%   maximizes 0.75*normalized score + 0.25*normalized minimum Euclidean
%   distance to the selected batch. Both terms are normalized over remaining
%   candidates at every step, as in Original. Exact acquisition ties keep
%   candidate input order. No distance to the historical archive is used.

    scores = scores(:);
    selected = zeros(0,1);
    Next = Candidates([],:);
    if isempty(Candidates) || batchSize <= 0
        return;
    end
    assert(numel(scores) == size(Candidates,1) && all(isfinite(scores)), ...
        'AdaMaO:InvalidScores','Expected one finite score per candidate.');
    threshold = quantile(scores,qKeep);
    available = find(scores >= threshold);
    target = min(floor(batchSize),numel(available));
    if target == 0
        return;
    end
    if numel(available) <= target
        [~,order] = sort(scores(available),'descend');
        selected = available(order);
        Next = Candidates(selected,:);
        return;
    end
    [~,first] = max(scores(available));
    selected = zeros(target,1);
    selected(1) = available(first);
    available(first) = [];
    for i = 2:target
        distance = min(pdist2(Candidates(available,:), ...
            Candidates(selected(1:i-1),:)),[],2);
        acquisition = 0.75*normalizeRemaining(scores(available)) + ...
            0.25*normalizeRemaining(distance);
        [~,best] = max(acquisition);
        selected(i) = available(best);
        available(best) = [];
    end
    Next = Candidates(selected,:);
end

function values = normalizeRemaining(values)
%normalizeRemaining Match the Original selector's within-set normalization.
    values = values(:);
    low = min(values);
    high = max(values);
    if high-low < 1e-12
        values = 0.5*ones(size(values));
    else
        values = (values-low)/(high-low);
    end
end
