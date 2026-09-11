function [Next,selected] = ArchiveMaximinSelection(Candidates,ArchiveDec,lower,upper,scores,batchSize)
%ArchiveMaximinSelection Select candidates by archive maximin distance.
%   NEXT = ArchiveMaximinSelection(CANDIDATES,ARCHIVEDEC,LOWER,UPPER,SCORES,BATCHSIZE)
%   scales decision variables by their bounds and greedily maximizes the
%   minimum distance to the archive and the selected batch. Fixed variables
%   are ignored. Duplicate and previously evaluated candidates are excluded.
%   Distance ties prefer larger relation scores, then original row order.
%
%   [NEXT,SELECTED] = ArchiveMaximinSelection(...) also returns the original
%   candidate row indices. BATCHSIZE is a cap, already limited by FE budget.

    selected = zeros(0,1);
    Next = Candidates([],:);
    if isempty(Candidates) || batchSize <= 0
        return;
    end
    lower = lower(:)';
    upper = upper(:)';
    scores = scores(:);
    assert(numel(scores) == size(Candidates,1), ...
        'AdaMaO:InvalidScores','One relation score is required per candidate.');
    assert(numel(lower) == size(Candidates,2) && ...
        numel(upper) == size(Candidates,2) && all(upper >= lower), ...
        'AdaMaO:InvalidBounds','Bounds must match the decision variables.');
    [~,available] = unique(Candidates,'rows','stable');
    if ~isempty(ArchiveDec)
        available(ismember(Candidates(available,:),ArchiveDec,'rows')) = [];
    end
    if isempty(available)
        return;
    end
    active = upper > lower;
    X = (Candidates(:,active)-lower(active))./(upper(active)-lower(active));
    minDistanceSquared = inf(size(Candidates,1),1);
    % Squared distances give identical rankings without square roots.
    % Update one archive row at a time to avoid a large distance matrix.
    for j = 1:size(ArchiveDec,1)
        z = (ArchiveDec(j,active)-lower(active))./(upper(active)-lower(active));
        minDistanceSquared = min(minDistanceSquared,sum((X-z).^2,2));
    end
    scores(~isfinite(scores)) = -inf;
    target = min(floor(batchSize),numel(available));
    while numel(selected) < target
        farthest = max(minDistanceSquared(available));
        tied = available(minDistanceSquared(available) == farthest);
        [~,best] = max(scores(tied));
        chosen = tied(best);
        selected(end+1,1) = chosen; %#ok<AGROW>
        available(available == chosen) = [];
        minDistanceSquared = min(minDistanceSquared,sum((X-X(chosen,:)).^2,2));
    end
    Next = Candidates(selected,:);
end
