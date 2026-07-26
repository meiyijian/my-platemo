function relation = SDEConfidenceTrueRelation( ...
    leftObj,rightObj,leftCon,rightCon,tolerance)
%SDEConfidenceTrueRelation Feasibility-first strict Pareto relation.
%
% +1 means the left endpoint is strictly better, -1 means the right
% endpoint is strictly better, and 0 means incomparable or equal.

    if nargin < 3 || isempty(leftCon)
        leftCon = zeros(size(leftObj,1),0);
    end
    if nargin < 4 || isempty(rightCon)
        rightCon = zeros(size(rightObj,1),0);
    end
    if nargin < 5 || isempty(tolerance)
        tolerance = 1e-12;
    end

    validateInputs(leftObj,rightObj,leftCon,rightCon,tolerance);

    leftViolation  = sum(max(0,leftCon),2);
    rightViolation = sum(max(0,rightCon),2);
    relation = zeros(size(leftObj,1),1);

    leftLower = leftViolation < rightViolation - tolerance;
    rightLower = rightViolation < leftViolation - tolerance;
    relation(leftLower) = 1;
    relation(rightLower) = -1;

    bothFeasible = leftViolation <= tolerance & ...
        rightViolation <= tolerance;
    leftDominates = bothFeasible & ...
        all(leftObj <= rightObj + tolerance,2) & ...
        any(leftObj < rightObj - tolerance,2);
    rightDominates = bothFeasible & ...
        all(rightObj <= leftObj + tolerance,2) & ...
        any(rightObj < leftObj - tolerance,2);
    relation(leftDominates) = 1;
    relation(rightDominates) = -1;
end

function validateInputs(leftObj,rightObj,leftCon,rightCon,tolerance)
    validObjectives = isnumeric(leftObj) && isreal(leftObj) && ...
        ismatrix(leftObj) && isnumeric(rightObj) && isreal(rightObj) && ...
        ismatrix(rightObj) && isequal(size(leftObj),size(rightObj)) && ...
        size(leftObj,2) > 0 && all(isfinite(leftObj(:))) && ...
        all(isfinite(rightObj(:)));
    validConstraints = isnumeric(leftCon) && isreal(leftCon) && ...
        ismatrix(leftCon) && isnumeric(rightCon) && isreal(rightCon) && ...
        ismatrix(rightCon) && isequal(size(leftCon),size(rightCon)) && ...
        size(leftCon,1) == size(leftObj,1) && ...
        all(isfinite(leftCon(:))) && all(isfinite(rightCon(:)));
    validTolerance = isnumeric(tolerance) && isreal(tolerance) && ...
        isscalar(tolerance) && isfinite(tolerance) && tolerance >= 0;
    if ~validObjectives || ~validConstraints || ~validTolerance
        error('AdaMaO:InvalidConfidenceTruthInput', ...
            ['Objective and constraint endpoints must be equally sized ', ...
             'finite numeric matrices, with a nonnegative tolerance.']);
    end
end
