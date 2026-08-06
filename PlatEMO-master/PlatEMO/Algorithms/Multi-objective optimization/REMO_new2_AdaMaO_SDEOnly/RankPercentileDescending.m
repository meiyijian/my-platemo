function percentile = RankPercentileDescending(scores)
%RankPercentileDescending - Tie-aware percentile rank with larger as better.

    if ~isnumeric(scores) || ~isreal(scores) || ...
            (~isempty(scores) && ~isvector(scores)) || ...
            any(~isfinite(scores(:)))
        error('AdaMaO:InvalidCascadeRankScores', ...
            'Cascade rank scores must be a finite real numeric vector.');
    end
    scores = scores(:);
    n = numel(scores);
    if n == 0
        percentile = zeros(0,1);
    elseif n == 1
        percentile = 1;
    else
        percentile = 1 - (tiedrank(-scores)-1)./(n-1);
    end
end
