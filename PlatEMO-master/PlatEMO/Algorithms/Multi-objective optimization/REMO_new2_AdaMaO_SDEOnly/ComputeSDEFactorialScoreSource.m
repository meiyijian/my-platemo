function [score,Ref,detail] = ComputeSDEFactorialScoreSource( ...
    Population,sourceBit,Vglobal,ratio,k,theta,runId,generation)
%ComputeSDEFactorialScoreSource Build the factorial quality-score source.
%   sourceBit=0 reproduces the score immediately before the legacy
%   HybridPBI catalog truncation. sourceBit=1 uses the continuous fixed
%   global/dynamic local dual-view score.

    [PopObj,N,M] = validateSourceInputs( ...
        Population,sourceBit,ratio,k,theta);
    ratio = min(1,max(0,ratio));
    runId = normalizeRunId(runId);
    generation = normalizeGeneration(generation);

    if sourceBit == 0
        directions = legacyReferenceDirections( ...
            PopObj,N,M,runId,generation);
        Ref = RefSelect(Population,k);
        RefObj = Ref.objs;
        [scoreV,pbiV] = legacyDirectionScore(PopObj,directions,theta);
        dynamicLabel = GetOutput_PBI(PopObj,RefObj);
        localScore = double(dynamicLabel);
        score = (1-ratio).*scoreV + ratio.*localScore;

        zmin = min(PopObj,[],1);
        detail = struct( ...
            'sourceBit',0, ...
            'globalScore',scoreV, ...
            'localScore',localScore, ...
            'globalPBI',pbiV, ...
            'localLabel',dynamicLabel, ...
            'globalDirections',directions, ...
            'localDirections',normalizeRows(RefObj-zmin), ...
            'referenceObjectives',RefObj);
    else
        validateGlobalDirections(Vglobal,M);
        Ref = RefSelect(Population,k);
        RefObj = Ref.objs;
        [score,detail] = ComputeSDEFactorialContinuousScore( ...
            PopObj,RefObj,Vglobal,ratio,theta);

        zmin = min(PopObj,[],1);
        span = max(PopObj,[],1)-zmin;
        span(span == 0) = 1;
        detail.sourceBit = 1;
        detail.globalDirections = normalizeRows(Vglobal);
        detail.localDirections = normalizeRows((RefObj-zmin)./span);
        detail.referenceObjectives = RefObj;
    end

    score = score(:);
end

function [PopObj,N,M] = validateSourceInputs( ...
    Population,sourceBit,ratio,k,theta)
    if isempty(Population)
        error('AdaMaO:InvalidScoreSourcePopulation', ...
            'Population must contain at least one evaluated solution.');
    end
    try
        PopObj = Population.objs;
    catch
        error('AdaMaO:InvalidScoreSourcePopulation', ...
            'Population must expose a numeric objective matrix.');
    end
    if ~isnumeric(PopObj) || ~isreal(PopObj) || ~ismatrix(PopObj) || ...
            isempty(PopObj) || ...
            any(~isfinite(PopObj(:)))
        error('AdaMaO:InvalidScoreSourcePopulation', ...
            'Population objectives must form a nonempty finite matrix.');
    end
    N = size(PopObj,1);
    M = size(PopObj,2);
    if length(Population) ~= N || M < 1
        error('AdaMaO:InvalidScoreSourcePopulation', ...
            'Population length and objective rows must agree.');
    end
    if ~isscalar(sourceBit) || ~isnumeric(sourceBit) || ~isreal(sourceBit) || ...
            ~isfinite(sourceBit) || ~ismember(sourceBit,[0,1])
        error('AdaMaO:InvalidScoreSourceBit', ...
            'sourceBit must be either zero or one.');
    end
    if ~isscalar(ratio) || ~isnumeric(ratio) || ~isreal(ratio) || ...
            ~isfinite(ratio)
        error('AdaMaO:InvalidScoreSourceParameter', ...
            'ratio must be a finite numeric scalar.');
    end
    if ~isscalar(k) || ~isnumeric(k) || ~isreal(k) || ~isfinite(k) || ...
            k < 1 || k ~= floor(k)
        error('AdaMaO:InvalidScoreSourceParameter', ...
            'k must be a positive integer.');
    end
    if ~isscalar(theta) || ~isnumeric(theta) || ~isreal(theta) || ...
            ~isfinite(theta) || theta < 0
        error('AdaMaO:InvalidScoreSourceParameter', ...
            'theta must be finite and nonnegative.');
    end
end

function validateGlobalDirections(Vglobal,M)
    if ~isnumeric(Vglobal) || ~isreal(Vglobal) || ~ismatrix(Vglobal) || ...
            isempty(Vglobal) || ...
            size(Vglobal,2) ~= M || any(~isfinite(Vglobal(:))) || ...
            all(vecnorm(Vglobal,2,2) == 0)
        error('AdaMaO:InvalidGlobalDirections', ...
            'Vglobal must contain a finite nonzero M-dimensional direction.');
    end
end

function directions = legacyReferenceDirections( ...
    PopObj,N,M,runId,generation)
    if M <= 3 || N < 50
        directions = UniformPoint(N,M,'ILD');
        directions = directions./vecnorm(directions,2,2);
    else
        directions = seededAdaptiveDirections( ...
            PopObj,N,runId,generation);
    end
end

function directions = seededAdaptiveDirections( ...
    PopObj,Nref,runId,generation)
    previousState = rng;
    restoreState = onCleanup(@() rng(previousState));
    seed = MakeSDEFactorialSeed(runId,generation,0,'legacy');
    rng(double(seed),'twister');
    directions = adaptiveReferenceDirections(PopObj,Nref);
end

function directions = adaptiveReferenceDirections(PopObj,Nref)
    M = size(PopObj,2);
    try
        frontNo = NDSort(PopObj,1);
        paretoObj = PopObj(frontNo == 1,:);
        nPareto = size(paretoObj,1);
    catch
        directions = uniformDirections(Nref,M);
        return;
    end

    if nPareto < max(10,Nref/2) || nPareto < 2
        directions = uniformDirections(Nref,M);
        return;
    end

    zmin = min(paretoObj,[],1);
    zmax = max(paretoObj,[],1);
    objectiveRange = zmax-zmin;
    if any(objectiveRange < 1e-12)
        directions = uniformDirections(Nref,M);
        return;
    end
    normalizedObj = (paretoObj-zmin)./objectiveRange;
    nClusters = min(Nref,nPareto);
    try
        [~,centers] = kmeans(normalizedObj,nClusters, ...
            'MaxIter',100,'Replicates',5,'EmptyAction','singleton');
        if isempty(centers)
            error('AdaMaO:EmptyAdaptiveDirections', ...
                'K-means returned no reference-vector centers.');
        end
    catch
        directions = uniformDirections(Nref,M);
        return;
    end

    if size(centers,1) < Nref
        centers = repmat(centers,ceil(Nref/size(centers,1)),1);
        centers = centers(1:Nref,:);
    end
    directions = centers.*objectiveRange + zmin;
    directions = directions./vecnorm(directions,2,2);
end

function directions = uniformDirections(Nref,M)
    directions = UniformPoint(Nref,M,'ILD');
    directions = directions./vecnorm(directions,2,2);
end

function [scoreV,pbiV] = legacyDirectionScore(PopObj,directions,theta)
    N = size(PopObj,1);
    zmin = min(PopObj,[],1);
    cosine = 1-pdist2(PopObj,directions,'cosine');
    [~,referenceIndex] = max(cosine,[],2);
    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        direction = directions(referenceIndex(i),:);
        d1(i) = (PopObj(i,:)-zmin)*direction'/norm(direction);
        projection = zmin+d1(i)*direction;
        d2(i) = norm(PopObj(i,:)-projection);
    end
    pbiV = d1+theta.*d2;
    scoreV = 1./(1+pbiV);
end

function normalized = normalizeRows(values)
    rowNorm = vecnorm(values,2,2);
    normalized = values(rowNorm > 0,:)./rowNorm(rowNorm > 0);
    normalized = unique(normalized,'rows','stable');
end

function runId = normalizeRunId(runId)
    if isempty(runId) || ~isscalar(runId) || ...
            ~isnumeric(runId) || ~isreal(runId) || ...
            ~isfinite(runId) || runId <= 0
        runId = 1;
    else
        runId = floor(runId);
    end
end

function generation = normalizeGeneration(generation)
    if isempty(generation) || ~isscalar(generation) || ...
            ~isnumeric(generation) || ~isreal(generation) || ...
            ~isfinite(generation) || generation < 0
        generation = 0;
    else
        generation = floor(generation);
    end
end
