function val = LVIGDPlus(A, R)
%LVIGDPlus Deterministic IGD+ metric for minimization (Stage-3 §4.3).
%   val = LVIGDPlus(A, R)
%   A: nA x M approximation-set objective matrix.
%   R: nR x M reference-set objective matrix.
%
%   dplus(r,a) = sqrt(sum(max(a-r,0).^2,2))
%   IGDplus(A,R) = mean_r  min_a dplus(r,a)
%
%   A and R must be finite and non-empty. This is a local reimplementation
%   that does NOT depend on PlatEMO's metric wrappers, so the definition
%   cannot drift across PlatEMO versions.

    if isempty(A) || isempty(R)
        val = Inf;
        return;
    end
    if size(A,2) ~= size(R,2)
        error('LVIGDPlus:DimMismatch','A and R must have the same number of columns (objectives).');
    end
    if ~all(isfinite(A(:))) || ~all(isfinite(R(:)))
        error('LVIGDPlus:NonFinite','A and R must be finite.');
    end

    nR = size(R,1);
    mins = zeros(nR,1);
    for r = 1:nR
        d = sqrt(sum(max(A - R(r,:), 0).^2, 2));
        mins(r) = min(d);
    end
    val = mean(mins);
end
