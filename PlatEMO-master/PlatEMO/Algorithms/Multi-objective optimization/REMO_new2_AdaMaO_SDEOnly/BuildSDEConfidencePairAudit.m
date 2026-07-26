function [solutionRows,pairRows] = BuildSDEConfidencePairAudit( ...
    generation,fe,evalIDs,objectives,constraints,catalog,confidence, ...
    sdeFitness,varargin)
%BuildSDEConfidencePairAudit Build deterministic current-population audits.

    probe = SDEConfidenceProbeSchema();
    options = parseOptions(probe,varargin{:});
    [evalIDs,objectives,constraints,catalog,confidence,sdeFitness] = ...
        validateSnapshot(generation,fe,evalIDs,objectives,constraints, ...
        catalog,confidence,sdeFitness);
    n = numel(evalIDs);

    solutionRows = nan(n,numel(probe.columns.solutionRows));
    solutionRows(:,col(probe,'solutionRows','Generation')) = generation;
    solutionRows(:,col(probe,'solutionRows','FE')) = fe;
    solutionRows(:,col(probe,'solutionRows','EvalID')) = evalIDs;
    solutionRows(:,col(probe,'solutionRows','RelationMode')) = ...
        options.RelationMode;
    solutionRows(:,col(probe,'solutionRows','CandidateMode')) = ...
        options.CandidateMode;
    solutionRows(:,col(probe,'solutionRows','Catalog')) = double(catalog);
    solutionRows(:,col(probe,'solutionRows','PBIConfidence')) = confidence;
    solutionRows(:,col(probe,'solutionRows','SDEFitness')) = sdeFitness;
    solutionRows(:,col(probe,'solutionRows','CurrentND')) = ...
        double(feasibilityFirstNondominated(objectives,constraints, ...
        options.Tolerance));

    if n < 2
        pairRows = zeros(0,numel(probe.columns.pbiPairRows));
        return;
    end

    pairIndex = nchoosek((1:n)',2);
    leftIndex = pairIndex(:,1);
    rightIndex = pairIndex(:,2);
    swap = ~catalog(leftIndex) & catalog(rightIndex);
    temporary = leftIndex(swap);
    leftIndex(swap) = rightIndex(swap);
    rightIndex(swap) = temporary;

    pairType = repmat(probe.codes.pairType.goodRest, ...
        size(pairIndex,1),1);
    pairType(catalog(leftIndex) & catalog(rightIndex)) = ...
        probe.codes.pairType.goodGood;
    pairType(~catalog(leftIndex) & ~catalog(rightIndex)) = ...
        probe.codes.pairType.restRest;
    predictedRelation = zeros(size(pairType));
    predictedRelation(pairType == probe.codes.pairType.goodRest) = 1;
    pairConfidence = sqrt(confidence(leftIndex).*confidence(rightIndex));
    paretoRelation = SDEConfidenceTrueRelation( ...
        objectives(leftIndex,:),objectives(rightIndex,:), ...
        constraints(leftIndex,:),constraints(rightIndex,:), ...
        options.Tolerance);
    sdeRelation = compareScores( ...
        sdeFitness(leftIndex),sdeFitness(rightIndex),options.Tolerance);

    pairRows = nan(size(pairIndex,1),numel(probe.columns.pbiPairRows));
    pairRows(:,col(probe,'pbiPairRows','Generation')) = generation;
    pairRows(:,col(probe,'pbiPairRows','FE')) = fe;
    pairRows(:,col(probe,'pbiPairRows','LeftEvalID')) = ...
        evalIDs(leftIndex);
    pairRows(:,col(probe,'pbiPairRows','RightEvalID')) = ...
        evalIDs(rightIndex);
    pairRows(:,col(probe,'pbiPairRows','PairType')) = pairType;
    pairRows(:,col(probe,'pbiPairRows','PredictedRelation')) = ...
        predictedRelation;
    pairRows(:,col(probe,'pbiPairRows','PairConfidence')) = ...
        pairConfidence;
    pairRows(:,col(probe,'pbiPairRows','ParetoRelation')) = ...
        paretoRelation;
    pairRows(:,col(probe,'pbiPairRows','SDERelation')) = sdeRelation;

    pairRows = deterministicSample(pairRows,probe, ...
        options.MaxPairsPerType);
end

function options = parseOptions(probe,varargin)
    options.RelationMode = probe.codes.relationMode.unknown;
    options.CandidateMode = probe.codes.candidateMode.unknown;
    options.MaxPairsPerType = probe.maxPairsPerType;
    options.Tolerance = 1e-12;
    if mod(numel(varargin),2) ~= 0
        error('AdaMaO:InvalidConfidenceAuditOption', ...
            'Probe audit options must be name-value pairs.');
    end
    for i = 1:2:numel(varargin)
        name = validatestring(varargin{i},{'RelationMode', ...
            'CandidateMode','MaxPairsPerType','Tolerance'});
        options.(name) = varargin{i+1};
    end
    validCode = @(x) isnumeric(x) && isreal(x) && isscalar(x) && ...
        isfinite(x);
    if ~validCode(options.RelationMode) || ...
            ~validCode(options.CandidateMode) || ...
            ~validCode(options.MaxPairsPerType) || ...
            options.MaxPairsPerType < 1 || ...
            options.MaxPairsPerType ~= floor(options.MaxPairsPerType) || ...
            ~validCode(options.Tolerance) || options.Tolerance < 0
        error('AdaMaO:InvalidConfidenceAuditOption', ...
            'Probe audit options contain an invalid numeric value.');
    end
end

function [evalIDs,objectives,constraints,catalog,confidence,sdeFitness] = ...
    validateSnapshot(generation,fe,evalIDs,objectives,constraints, ...
    catalog,confidence,sdeFitness)
    evalIDs = evalIDs(:);
    catalog = catalog(:);
    confidence = confidence(:);
    sdeFitness = sdeFitness(:);
    n = numel(evalIDs);
    if isempty(constraints)
        constraints = zeros(n,0);
    end
    scalarOK = @(x) isnumeric(x) && isreal(x) && isscalar(x) && ...
        isfinite(x);
    validCatalog = islogical(catalog) || ...
        (isnumeric(catalog) && isreal(catalog) && ...
        all(isfinite(catalog)) && all(catalog == 0 | catalog == 1));
    valid = scalarOK(generation) && generation >= 0 && ...
        generation == floor(generation) && scalarOK(fe) && fe >= 0 && ...
        isnumeric(evalIDs) && isreal(evalIDs) && ...
        numel(unique(evalIDs)) == n && all(isfinite(evalIDs)) && ...
        all(evalIDs > 0) && all(evalIDs == floor(evalIDs)) && ...
        isnumeric(objectives) && ...
        isreal(objectives) && ismatrix(objectives) && ...
        size(objectives,1) == n && size(objectives,2) > 0 && ...
        all(isfinite(objectives(:))) && isnumeric(constraints) && ...
        isreal(constraints) && ismatrix(constraints) && ...
        size(constraints,1) == n && all(isfinite(constraints(:))) && ...
        numel(catalog) == n && validCatalog && numel(confidence) == n && ...
        numel(sdeFitness) == n && all(isfinite(confidence)) && ...
        all(confidence >= 0 & confidence <= 1) && ...
        all(isfinite(sdeFitness));
    if ~valid
        error('AdaMaO:InvalidConfidenceSnapshot', ...
            'The confidence snapshot is inconsistent or nonfinite.');
    end
    catalog = logical(catalog);
end

function relation = compareScores(left,right,tolerance)
    relation = zeros(size(left));
    relation(left > right + tolerance) = 1;
    relation(right > left + tolerance) = -1;
end

function mask = feasibilityFirstNondominated(objectives,constraints,tolerance)
    n = size(objectives,1);
    mask = true(n,1);
    for i = 1:n
        other = [1:i-1,i+1:n];
        if isempty(other)
            continue;
        end
        relation = SDEConfidenceTrueRelation( ...
            objectives(other,:),repmat(objectives(i,:),n-1,1), ...
            constraints(other,:),repmat(constraints(i,:),n-1,1), ...
            tolerance);
        mask(i) = ~any(relation == 1);
    end
end

function rows = deterministicSample(rows,probe,maxRows)
    sampled = cell(3,1);
    typeColumn = col(probe,'pbiPairRows','PairType');
    confidenceColumn = col(probe,'pbiPairRows','PairConfidence');
    leftColumn = col(probe,'pbiPairRows','LeftEvalID');
    rightColumn = col(probe,'pbiPairRows','RightEvalID');
    for pairType = 1:3
        subset = rows(rows(:,typeColumn) == pairType,:);
        if isempty(subset)
            sampled{pairType} = subset;
            continue;
        end
        subset = sortrows(subset, ...
            [confidenceColumn,leftColumn,rightColumn]);
        if size(subset,1) > maxRows
            keep = round(linspace(1,size(subset,1),maxRows))';
            subset = subset(keep,:);
        end
        sampled{pairType} = subset;
    end
    rows = vertcat(sampled{:});
end

function index = col(probe,rowName,columnName)
    index = find(strcmp(probe.columns.(rowName),columnName),1);
end
