function [Next,selected] = PrunedIndicatorSelection(Candidates,scores,model,batchSize)
%PrunedIndicatorSelection Rank the top 30 percent by predicted SDE fitness.
%   The relation shortlist has ceil(0.30*C) rows, with no fixed count floor.
%   Selects up to batchSize candidates directly by descending prediction.
%   Empty, failed or nonfinite predictions fall back to relation scores.
%   No second quantile or minimum batch completion is used.

    scores = scores(:);
    selected = zeros(0,1);
    Next = Candidates([],:);
    if isempty(Candidates) || batchSize <= 0
        return;
    end
    assert(numel(scores) == size(Candidates,1) && all(isfinite(scores)), ...
        'AdaMaO:InvalidScores','Expected one finite score per candidate.');
    [~,order] = sort(scores,'descend');
    shortlist = order(1:ceil(0.30*size(Candidates,1)));
    ranking = scores(shortlist);
    if ~isempty(model)
        try
            prediction = predict(model,Candidates(shortlist,:));
            if numel(prediction) == numel(shortlist) && all(isfinite(prediction(:)))
                ranking = prediction(:);
            end
        catch
            % Preserve relation ranking if indicator prediction fails.
        end
    end
    [~,order] = sort(ranking,'descend');
    selected = shortlist(order(1:min(floor(batchSize),numel(shortlist))));
    Next = Candidates(selected,:);
end
