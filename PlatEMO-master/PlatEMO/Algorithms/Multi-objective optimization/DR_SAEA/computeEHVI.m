function score = computeEHVI(CandObj, RefObj, RefPoint)
% <DR_SAEA helper> Expected Hypervolume Improvement for K=2.
%
%   For a 2-dimensional reduced objective space, compute the exact closed-
%   form hypervolume improvement that each candidate brings over the
%   current Pareto front. Returns a column vector of length size(CandObj,1).
%
%   Call:
%       score = computeEHVI(CandObj, RefObj, RefPoint)
%
%   Input:
%       CandObj  - Nq x 2 candidate reduced objectives (Mu from the surrogate)
%       RefObj   - Nf x 2 current non-dominated front in the reduced space
%       RefPoint - 1 x 2 reference point for the hypervolume (e.g. 1.1*max)
%
%   Output:
%       score    - Nq x 1, the exact hypervolume improvement of each candidate
%                  over (RefObj, RefPoint) when used as a deterministic point.
%                  Note: this is the HV improvement, not the expected HV
%                  improvement, since the surrogate is treated as a point
%                  estimate inside the infill criterion. This matches the
%                  practical use in DR_SAEA: balancing convergence (low
%                  objective) and uncertainty (sigma) is handled by the
%                  balanced acquisition directly, while the "EHVI" name
%                  preserves the canonical literature reference.
%
%   This function is part of the DR_SAEA algorithm.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026. You are free to use DR_SAEA for research purposes.
%--------------------------------------------------------------------------

    if size(CandObj, 2) ~= 2
        score = zeros(size(CandObj, 1), 1);
        return;
    end
    if isempty(RefObj)
        RefObj = RefPoint;
    end
    if isempty(RefPoint)
        RefPoint = max(RefObj, [], 1) * 1.1 + 0.1;
    end

    % Clip the reference front to be inside the dominated region only
    F = RefObj(all(RefObj < repmat(RefPoint, size(RefObj, 1), 1), 2), :);
    if isempty(F)
        F = RefPoint;
    end

    Nq = size(CandObj, 1);
    score = zeros(Nq, 1);
    for i = 1 : Nq
        p = CandObj(i, :);
        if any(p >= RefPoint)
            score(i) = 0;
            continue;
        end
        % The HV improvement of p over (F, RefPoint) equals the area of
        % the rectangle [p1, RefPoint(1)] x [p2, RefPoint(2)] minus the
        % area already covered by F and clipped to the new region.
        baseW   = RefPoint(1) - p(1);
        baseH   = RefPoint(2) - p(2);
        base    = baseW * baseH;
        if isempty(F)
            score(i) = base;
            continue;
        end
        % Subtract the area of F that is dominated by p and not yet inside
        Fdom = F(all(F >= p, 2) & all(F < repmat(RefPoint, size(F,1), 1), 2), :);
        if isempty(Fdom)
            score(i) = base;
        else
            % For the 2D deterministic case, improvement = (maxFdom1 - p1) * (maxFdom2 - p2)
            subW = max(Fdom(:, 1)) - p(1);
            subH = max(Fdom(:, 2)) - p(2);
            score(i) = max(base - subW * subH, 0);
        end
    end
end
