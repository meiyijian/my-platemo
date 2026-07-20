function [score,detail] = ComputeSDEFactorialContinuousScore( ...
    PopObj,RefObj,Vglobal,ratio,theta)
%ComputeSDEFactorialContinuousScore Continuous dual-view PBI utility.
%   The global view uses fixed reference directions, while the local view
%   uses directions induced by the current representative solutions. Both
%   PBI values are converted to tied rank scores before progress blending.

    validateInputs(PopObj,RefObj,Vglobal,ratio,theta);
    ratio = min(1,max(0,ratio));

    zmin = min(PopObj,[],1);
    span = max(PopObj,[],1) - zmin;
    span(span == 0) = 1;
    normalizedPop = (PopObj-zmin)./span;
    normalizedRef = (RefObj-zmin)./span;

    globalDirections = normalizeDirections(Vglobal);
    if isempty(globalDirections)
        error('AdaMaO:InvalidGlobalDirections', ...
            'At least one nonzero global direction is required.');
    end
    globalPBI   = assignedPBI(normalizedPop,globalDirections,theta);
    globalScore = rankUtility(globalPBI);

    localDirections = normalizeDirections(normalizedRef);
    if isempty(localDirections)
        localPBI   = globalPBI;
        localScore = globalScore;
    else
        localPBI   = assignedPBI(normalizedPop,localDirections,theta);
        localScore = rankUtility(localPBI);
    end

    score = (1-ratio).*globalScore + ratio.*localScore;
    score = min(1,max(0,score));

    detail = struct();
    detail.globalScore = globalScore;
    detail.localScore  = localScore;
    detail.globalPBI   = globalPBI;
    detail.localPBI    = localPBI;
end

function validateInputs(PopObj,RefObj,Vglobal,ratio,theta)
    if ~isnumeric(PopObj) || ~isreal(PopObj) || ~ismatrix(PopObj) || ...
            isempty(PopObj) || ...
            size(PopObj,2) < 1 || any(~isfinite(PopObj(:)))
        error('AdaMaO:InvalidContinuousScoreInput', ...
            'PopObj must be a nonempty finite numeric matrix.');
    end
    if ~isnumeric(RefObj) || ~isreal(RefObj) || ~ismatrix(RefObj) || ...
            ~isnumeric(Vglobal) || ~isreal(Vglobal) || ~ismatrix(Vglobal) || ...
            size(RefObj,2) ~= size(PopObj,2) || ...
            size(Vglobal,2) ~= size(PopObj,2)
        error('AdaMaO:InvalidContinuousScoreDimensions', ...
            'Population, reference solutions, and directions must agree.');
    end
    if any(~isfinite(RefObj(:))) || any(~isfinite(Vglobal(:)))
        error('AdaMaO:InvalidContinuousScoreInput', ...
            'Reference solutions and directions must be finite.');
    end
    if isempty(Vglobal) || all(vecnorm(Vglobal,2,2) == 0)
        error('AdaMaO:InvalidGlobalDirections', ...
            'At least one nonzero global direction is required.');
    end
    if ~isnumeric(ratio) || ~isreal(ratio) || ~isscalar(ratio) || ...
            ~isfinite(ratio) || ~isnumeric(theta) || ~isreal(theta) || ...
            ~isscalar(theta) || ~isfinite(theta) || theta < 0
        error('AdaMaO:InvalidContinuousScoreParameter', ...
            'ratio must be finite and theta must be finite and nonnegative.');
    end
end

function directions = normalizeDirections(directions)
    if isempty(directions)
        return;
    end
    rowNorm = vecnorm(directions,2,2);
    directions = directions(rowNorm > 0,:);
    rowNorm = rowNorm(rowNorm > 0);
    if isempty(directions)
        return;
    end
    directions = directions./rowNorm;
    directions = unique(directions,'rows','stable');
end

function pbi = assignedPBI(points,directions,theta)
    pointNorm = vecnorm(points,2,2);
    divisor = pointNorm;
    divisor(divisor == 0) = 1;
    unitPoint = bsxfun(@rdivide,points,divisor);
    cosine = unitPoint*directions';
    [~,assigned] = max(cosine,[],2);
    assignedDirection = directions(assigned,:);
    d1 = sum(points.*assignedDirection,2);
    projection = bsxfun(@times,d1,assignedDirection);
    d2 = vecnorm(points-projection,2,2);
    pbi = d1 + theta.*d2;
end

function utility = rankUtility(values)
    n = numel(values);
    if n == 1
        utility = 1;
        return;
    end

    [sortedValues,order] = sort(values(:),'ascend');
    ranks = zeros(n,1);
    first = 1;
    while first <= n
        last = first;
        while last < n && sortedValues(last+1) == sortedValues(first)
            last = last + 1;
        end
        ranks(order(first:last)) = (first+last)/2;
        first = last + 1;
    end
    utility = 1 - (ranks-1)./(n-1);
end
