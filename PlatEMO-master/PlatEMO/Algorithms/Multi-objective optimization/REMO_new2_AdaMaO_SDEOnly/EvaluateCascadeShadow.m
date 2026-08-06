function shadow = EvaluateCascadeShadow(Problem,candidateDec,archiveObj,archiveCon,referenceObj)
%EvaluateCascadeShadow - Evaluate audit candidates without consuming FE.

    if nargin ~= 5
        error('AdaMaO:InvalidCascadeShadowInputs', ...
            ['EvaluateCascadeShadow requires Problem, candidate decisions, ', ...
            'archive objectives, archive constraints, and reference points.']);
    end

    callerRng = rng;
    restoreRng = onCleanup(@() rng(callerRng));

    problemClass = class(Problem);
    if isempty(regexp(problemClass,'^(DTLZ[1-7]|WFG[1-9])$','once'))
        error('AdaMaO:CascadeAuditUnsupportedProblem', ...
            'Cascade shadow evaluation does not support problem class %s.', ...
            problemClass);
    end
    if ~(isnumeric(Problem.maxRuntime) && isreal(Problem.maxRuntime) && ...
            isscalar(Problem.maxRuntime) && Problem.maxRuntime == inf)
        error('AdaMaO:CascadeAuditRuntimeCap', ...
            'Cascade shadow evaluation requires Problem.maxRuntime to be inf.');
    end

    if ~finiteRealMatrix(candidateDec) || isempty(candidateDec) || ...
            size(candidateDec,2) ~= Problem.D
        error('AdaMaO:InvalidCascadeShadowInputs', ...
            'Candidate decisions must be a nonempty finite real N-by-D matrix.');
    end
    if ~finiteRealMatrix(archiveObj) || isempty(archiveObj) || ...
            size(archiveObj,2) ~= Problem.M
        error('AdaMaO:InvalidCascadeShadowInputs', ...
            'Archive objectives must be a nonempty finite real N-by-M matrix.');
    end
    if ~finiteRealMatrix(referenceObj) || isempty(referenceObj) || ...
            size(referenceObj,2) ~= Problem.M
        error('AdaMaO:InvalidCascadeShadowInputs', ...
            'Reference objectives must be a nonempty finite real R-by-M matrix.');
    end
    if ~isempty(archiveCon) && ...
            (~finiteRealMatrix(archiveCon) || ...
             size(archiveCon,1) ~= size(archiveObj,1))
        error('AdaMaO:InvalidCascadeShadowInputs', ...
            ['Archive constraints must be empty or a finite real matrix ', ...
            'with one row per archive objective vector.']);
    end

    feBefore = Problem.FE;
    repairedDec = Problem.CalDec(candidateDec);
    candidateObj = Problem.CalObj(repairedDec);
    candidateCon = Problem.CalCon(repairedDec);
    if ~isequal(Problem.FE,feBefore)
        error('AdaMaO:CascadeAuditFEChanged', ...
            'Shadow evaluation changed Problem.FE.');
    end

    candidateCount = size(candidateDec,1);
    if ~finiteRealMatrix(repairedDec) || ...
            ~isequal(size(repairedDec),size(candidateDec))
        error('AdaMaO:InvalidCascadeShadowEvaluation', ...
            'CalDec returned an invalid or incorrectly sized decision matrix.');
    end
    if ~finiteRealMatrix(candidateObj) || ...
            size(candidateObj,1) ~= candidateCount || ...
            size(candidateObj,2) ~= Problem.M
        error('AdaMaO:InvalidCascadeShadowEvaluation', ...
            'CalObj returned an invalid or incorrectly sized objective matrix.');
    end
    if ~isempty(candidateCon) && ...
            (~finiteRealMatrix(candidateCon) || ...
             size(candidateCon,1) ~= candidateCount)
        error('AdaMaO:InvalidCascadeShadowEvaluation', ...
            'CalCon returned an invalid or incorrectly sized constraint matrix.');
    end

    archiveFeasible = feasibleRows(archiveCon,size(archiveObj,1));
    if ~any(archiveFeasible)
        error('AdaMaO:CascadeAuditNoFeasibleArchive', ...
            'Cascade shadow evaluation requires at least one feasible archive row.');
    end
    candidateFeasible = feasibleRows(candidateCon,candidateCount);

    [feasibleUtility,baselineIGDp,referenceCount,baselineDistance, ...
        feasibleDistance] = ComputeMarginalIGDp( ...
        archiveObj(archiveFeasible,:),candidateObj(candidateFeasible,:), ...
        referenceObj);
    marginalIGDp = zeros(candidateCount,1);
    marginalIGDp(candidateFeasible) = feasibleUtility;
    candidateDistance = inf(referenceCount,candidateCount);
    candidateDistance(:,candidateFeasible) = feasibleDistance;

    shadow = struct();
    shadow.CandidateObjectives = candidateObj;
    shadow.CandidateConstraints = candidateCon;
    shadow.FeasibleMask = candidateFeasible;
    shadow.MarginalIGDp = marginalIGDp;
    shadow.BaselineIGDp = baselineIGDp;
    shadow.BaselineDistance = baselineDistance;
    shadow.CandidateDistance = candidateDistance;
    shadow.ReferenceCount = referenceCount;
    shadow.ShadowEvaluationCount = candidateCount;
end

function valid = finiteRealMatrix(value)
    valid = isnumeric(value) && isreal(value) && ismatrix(value) && ...
        all(isfinite(value(:)));
end

function feasible = feasibleRows(constraints,rowCount)
    if isempty(constraints)
        feasible = true(rowCount,1);
    else
        feasible = all(constraints <= 0,2);
    end
    feasible = logical(feasible(:));
end
