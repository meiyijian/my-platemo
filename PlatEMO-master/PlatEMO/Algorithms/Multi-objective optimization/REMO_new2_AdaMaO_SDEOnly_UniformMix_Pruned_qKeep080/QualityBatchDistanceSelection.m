function [Next,selected] = QualityBatchDistanceSelection(Candidates,scores,qKeep,batchSize)
%QualityBatchDistanceSelection Filter by quality, then spread a batch.
%   Retains scores at or above their qKeep quantile. Selects the highest
%   score first, then maximizes minimum raw decision-space distance to the
%   selected batch. Distance ties prefer higher scores, then input order.
%   No archive distance, ambiguity reward, score-distance weight or minimum
%   batch completion is used. Input rows must already be unique and finite.

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
    [~,first] = max(scores(available));
    chosen = available(first);
    selected = zeros(target,1);
    minDistance = inf(size(Candidates,1),1);
    for i = 1:target
        selected(i) = chosen;
        available(available == chosen) = [];
        if i == target
            break;
        end
        minDistance = min(minDistance, ...
            sum((Candidates-Candidates(chosen,:)).^2,2));
        farthest = max(minDistance(available));
        tied = available(minDistance(available) == farthest);
        [~,best] = max(scores(tied));
        chosen = tied(best);
    end
    Next = Candidates(selected,:);
end
