function [catalog, order] = LVTopQDeterministic(score, rGood)
%LVTopQDeterministic Deterministic top-quantile positive-group selector.
%   [catalog, order] = LVTopQDeterministic(score, rGood) returns a logical
%   Nx1 catalog with ceil(N*rGood) true entries, selected by:
%     1st key: score descending
%     2nd key: PopulationRow 1:N ascending (ties broken by row order)
%   implemented explicitly via sortrows([-score(:),(1:N)']). This matches
%   the production semantics of sorting the current Population by row
%   order without relying on MATLAB's unstable tie handling.
%
%   Inputs:
%     score - Nx1 numeric score vector (higher = more positive)
%     rGood - scalar fraction in (0,0.5]
%   Outputs:
%     catalog - Nx1 logical
%     order   - Nx1 index vector of the selected rows (descending quality)

    N = numel(score);
    if isempty(N) || N == 0
        catalog = false(0,1);
        order   = zeros(0,1);
        return;
    end
    assert(isscalar(rGood) && isfinite(rGood) && rGood > 0 && rGood <= 0.5, ...
        'LVTopQ:BadRGood','rGood must be in (0,0.5]');

    k = ceil(N * rGood);
    k = max(1, min(k, N));

    % Row-order tie-break: sortrows([-score, 1:N]) selects higher score
    % first, and among equal scores the smaller row index first.
    [~, order] = sortrows([-score(:), (1:N)']);

    catalog = false(N,1);
    catalog(order(1:k)) = true;
    order   = order(1:k);
end
