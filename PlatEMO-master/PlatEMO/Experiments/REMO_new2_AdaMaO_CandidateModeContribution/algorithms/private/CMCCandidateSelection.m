function [Next,trace] = CMCCandidateSelection( ...
    Problem,Ref,Input,wmax,Smodel,qKeep,nMin,nMax,armID,needTrace)
%CMCCANDIDATESELECTION Frozen HCV selection twin plus controlled arms.
%   Arm 100 follows the current HCV operational path. Other arms use a
%   common fixed K=6 host and differ only through CMCArmConfiguration.

    if nargin < 10
        needTrace = false;
    end
    config = CMCArmConfiguration(armID);
    mode = resolveMode(config,Smodel);

    NextRound = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    allRaw = NextRound;
    roundID = ones(size(NextRound,1),1);
    generated = size(NextRound,1);
    roundNumber = 1;
    lastRound = NextRound;
    generationAggregationEligible = 0;
    generationAggregationChanged = 0;

    while generated < wmax && ~isempty(NextRound)
        [simpleScore,weightedScore] = relationScores(Smodel,NextRound);
        keepNumber = min(length(Ref),size(NextRound,1));
        if keepNumber > 0
            simpleParents = topK(simpleScore,true(size(NextRound,1),1),keepNumber);
            weightedParents = topK(weightedScore,true(size(NextRound,1),1),keepNumber);
            generationAggregationEligible = generationAggregationEligible + 1;
            generationAggregationChanged = generationAggregationChanged + ...
                ~isequal(sort(simpleParents),sort(weightedParents));
        end
        generationScore = chooseAggregation( ...
            simpleScore,weightedScore,config.EGen,mode);
        [~,order] = sort(generationScore,'descend');
        if keepNumber < 1
            break;
        end
        parents = NextRound(order(1:keepNumber),:);
        NextRound = OperatorGA(Problem,[parents;Ref.decs],{1,15,1,5});
        roundNumber = roundNumber + 1;
        lastRound = NextRound;
        allRaw = [allRaw;NextRound]; %#ok<AGROW>
        roundID = [roundID;repmat(roundNumber,size(NextRound,1),1)]; %#ok<AGROW>
        generated = generated + size(NextRound,1);
    end

    if isempty(allRaw)
        Next = [];
        trace = emptyTrace(mode);
        return;
    end
    [candidates,firstIndex,groupIndex] = unique(allRaw,'rows','stable');
    firstRound = roundID(firstIndex);
    lastSeenRound = accumarray(groupIndex,roundID,[],@max);
    occurrenceCount = accumarray(groupIndex,1);
    finalRoundMask = lastSeenRound == roundNumber;
    lastUnique = unique(lastRound,'rows','stable');
    poolUniverse = true(size(candidates,1),1);
    if armID ~= 100 && ~config.PoolAll
        poolUniverse = ismember(candidates,lastUnique,'rows');
    end

    [simpleScore,weightedScore,ambiguity] = relationScores(Smodel,candidates);
    lambda = ambiguityWeight(Smodel,config);
    finalScore = chooseAggregation( ...
        simpleScore,weightedScore,config.EFinal,mode);
    ambiguityUsed = ambiguity;
    if config.ShuffleD
        ambiguityUsed = localPermutation(ambiguity,Smodel,81);
    end
    fixedK = min(nMax,nnz(poolUniverse));
    if armID == 100
        if mode == "indicator"
            [selected,retainedCount,operationalIndicator] = ...
                currentIndicatorSelection(Smodel,candidates,simpleScore, ...
                nMin,nMax);
        else
            [selected,retainedCount] = currentExploreSelection( ...
                candidates,weightedScore,ambiguity,Smodel,qKeep,nMin,nMax);
            operationalIndicator = false;
        end
    elseif mode == "indicator" && config.UseF
        [selected,retainedCount,operationalIndicator] = ...
            CMCFixedIndicatorSelection(Smodel,candidates,simpleScore, ...
                fixedK,config.ShuffleF,poolUniverse);
    elseif mode == "indicator"
        selected = topK(simpleScore,poolUniverse,fixedK);
        retainedCount = nnz(poolUniverse);
        operationalIndicator = false;
    else
        effectiveLambda = 0;
        if config.UseD || config.ShuffleD
            effectiveLambda = lambda;
        end
        [selected,retainedCount] = CMCFixedExploreSelection( ...
            candidates,finalScore,ambiguityUsed,effectiveLambda, ...
            qKeep,fixedK,config.UseQ,config.UseC,poolUniverse);
        operationalIndicator = false;
    end
    Next = candidates(selected,:);

    if ~needTrace
        trace = struct();
        return;
    end
    policy = buildPolicies(candidates,lastUnique,simpleScore, ...
        weightedScore,ambiguity,Smodel,qKeep,nMin,nMax,fixedK,lambda);
    trace = struct();
    trace.Candidates = candidates;
    trace.LastCandidates = lastUnique;
    trace.FirstRound = firstRound;
    trace.LastRound = lastSeenRound;
    trace.OccurrenceCount = occurrenceCount;
    trace.InFinalRound = finalRoundMask;
    trace.RoundCount = roundNumber;
    trace.GenerationAggregationEligible = generationAggregationEligible;
    trace.GenerationAggregationChanged = generationAggregationChanged;
    trace.AccumRawCount = size(allRaw,1);
    trace.AccumUniqueCount = size(candidates,1);
    trace.LastPoolCount = size(lastUnique,1);
    trace.SimpleScore = simpleScore;
    trace.WeightedScore = weightedScore;
    trace.Ambiguity = ambiguity;
    trace.LambdaT = lambda;
    trace.PErr = Smodel.p_err;
    trace.Mode = mode;
    trace.AttemptedMode = string(Smodel.AttemptedMode);
    trace.IndicatorAvailable = ~isempty(Smodel.IndicatorModel);
    trace.OperationalIndicatorUsed = operationalIndicator;
    trace.FallbackReason = fallbackReason(trace);
    trace.RequestedK = nMax;
    trace.SelectedIndex = selected(:);
    trace.SelectedK = numel(selected);
    trace.RetainedCount = retainedCount;
    trace.Policy = policy;
    trace.ArchiveDuplicateCount = countExactDuplicates( ...
        candidates,Smodel.ArchiveDec);
    trace.ArchiveNearDuplicateCount = countNearDuplicates( ...
        candidates,Smodel.ArchiveDec,Problem.lower,Problem.upper);
end

function mode = resolveMode(config,Smodel)
    mode = string(Smodel.mode);
    if config.Route == "explore"
        mode = "explore";
    elseif config.Route == "indicator"
        if isempty(Smodel.IndicatorModel)
            mode = "explore";
        else
            mode = "indicator";
        end
    end
end

function score = chooseAggregation(simple,weighted,setting,mode)
    if setting == "simple"
        score = simple;
    elseif setting == "weighted" || ...
            (setting == "current" && mode == "explore")
        score = weighted;
    else
        score = simple;
    end
end

function lambda = ambiguityWeight(Smodel,config)
    pError = Smodel.p_err;
    if ~isscalar(pError) || ~isfinite(pError)
        pError = 1;
    end
    if config.RemovePErrGate
        gate = 1;
    else
        gate = max(0,1-pError/0.45);
    end
    lambda = Smodel.lambda0*(1-Smodel.ratio)*gate;
end

function policy = buildPolicies(candidates,lastCandidates,simpleScore, ...
        weightedScore,ambiguity,Smodel,qKeep,nMin,nMax,K,lambda)
    count = size(candidates,1);
    allMask = true(count,1);
    lastMask = ismember(candidates,lastCandidates,'rows');
    augmented = norm01(weightedScore) + lambda.*norm01(ambiguity);
    retained = augmented >= quantile(augmented,qKeep);
    if nnz(retained) < K
        retained = allMask;
    end
    policy = struct();
    policy.FINAL_MATCHED = maskFromIndex(count, ...
        topK(simpleScore,lastMask,min(K,nnz(lastMask))));
    policy.ACCUM_MATCHED = maskFromIndex(count,topK(simpleScore,allMask,K));
    policy.EXP_SIMPLE = policy.ACCUM_MATCHED;
    policy.EXP_WEIGHTED = maskFromIndex(count,topK(weightedScore,allMask,K));
    simpleAugmented = norm01(simpleScore) + lambda.*norm01(ambiguity);
    simpleRetained = simpleAugmented >= quantile(simpleAugmented,qKeep);
    if nnz(simpleRetained) < K
        simpleRetained = allMask;
    end
    policy.EXP_SIMPLE_FULL = maskFromIndex(count,diversitySelection( ...
        candidates,find(simpleRetained),simpleAugmented,K));
    noDScore = norm01(weightedScore);
    noDRetained = noDScore >= quantile(noDScore,qKeep);
    if nnz(noDRetained) < K
        noDRetained = allMask;
    end
    policy.EXP_NO_D = maskFromIndex(count,diversitySelection( ...
        candidates,find(noDRetained),noDScore,K));
    policy.EXP_NO_C = maskFromIndex(count,topK(augmented,retained,K));
    policy.EXP_FULL = maskFromIndex(count, ...
        diversitySelection(candidates,find(retained),augmented,K));
    policy.EXP_NO_Q = maskFromIndex(count, ...
        diversitySelection(candidates,find(allMask),augmented,K));
    relationCoarse = coarseMask(simpleScore);
    policy.IND_RELATION_ONLY = maskFromIndex(count, ...
        topK(simpleScore,relationCoarse,K));
    [indicatorIndex,~,operational] = fixedIndicatorSelection( ...
        Smodel,candidates,simpleScore,K,false);
    policy.IND_FULL = maskFromIndex(count,indicatorIndex);
    policy.IND_OPERATIONAL = operational;
    shuffledD = localPermutation(ambiguity,Smodel,82);
    shuffledAugmented = norm01(weightedScore) + lambda.*norm01(shuffledD);
    shuffledRetained = shuffledAugmented >= quantile(shuffledAugmented,qKeep);
    if nnz(shuffledRetained) < K
        shuffledRetained = allMask;
    end
    policy.SHUFFLED_D = maskFromIndex(count,diversitySelection( ...
        candidates,find(shuffledRetained),shuffledAugmented,K));
    noGateAugmented = norm01(weightedScore) + ...
        Smodel.lambda0*(1-Smodel.ratio).*norm01(ambiguity);
    noGateRetained = noGateAugmented >= quantile(noGateAugmented,qKeep);
    if nnz(noGateRetained) < K
        noGateRetained = allMask;
    end
    policy.EXP_NO_PERR_GATE = maskFromIndex(count,diversitySelection( ...
        candidates,find(noGateRetained),noGateAugmented,K));
    [shuffledF,~,~] = fixedIndicatorSelection( ...
        Smodel,candidates,simpleScore,K,true);
    policy.SHUFFLED_F = maskFromIndex(count,shuffledF);
    policy.RelationCoarse = relationCoarse;
    policy.ExploreRetained = retained;
    policy.K = K;
    policy.NMin = nMin;
    policy.NMax = nMax;
end

function [selected,retainedCount] = currentExploreSelection( ...
        candidates,weightedScore,ambiguity,Smodel,qKeep,nMin,nMax)
    pError = Smodel.p_err;
    if ~isfinite(pError)
        pError = 1;
    end
    lambda = Smodel.lambda0*(1-Smodel.ratio)*max(0,1-pError/0.45);
    augmented = norm01(weightedScore) + lambda.*norm01(ambiguity);
    retained = augmented >= quantile(augmented,qKeep);
    if nnz(retained) < nMin
        retained = maskFromIndex(size(candidates,1), ...
            topK(augmented,true(size(candidates,1),1),nMin));
    end
    retainedCount = nnz(retained);
    evaluationNumber = min(nMax,max(nMin,retainedCount));
    evaluationNumber = min(evaluationNumber,retainedCount);
    selected = diversitySelection( ...
        candidates,find(retained),augmented,evaluationNumber);
end

function [selected,retainedCount,operational] = ...
        currentIndicatorSelection(Smodel,candidates,simpleScore,nMin,nMax)
    coarse = coarseMask(simpleScore);
    coarseIndex = find(coarse);
    indicatorScore = simpleScore(coarseIndex);
    operational = false;
    if ~isempty(Smodel.IndicatorModel)
        try
            prediction = predict(Smodel.IndicatorModel,candidates(coarseIndex,:));
            if all(isfinite(prediction))
                indicatorScore = prediction;
                operational = true;
            end
        catch
        end
    end
    retained = indicatorScore >= quantile(indicatorScore,0.70);
    if nnz(retained) < nMin
        retained = maskFromIndex(numel(indicatorScore), ...
            topK(indicatorScore,true(numel(indicatorScore),1),nMin));
    end
    retainedCount = nnz(retained);
    localIndex = find(retained);
    [~,order] = sort(indicatorScore(localIndex),'descend');
    evaluationNumber = min(nMax,max(nMin,numel(localIndex)));
    evaluationNumber = min(evaluationNumber,numel(localIndex));
    selected = coarseIndex(localIndex(order(1:evaluationNumber)));
end

function [selected,retainedCount,operational] = fixedIndicatorSelection( ...
        Smodel,candidates,simpleScore,K,shuffle)
    coarse = coarseMask(simpleScore);
    coarseIndex = find(coarse);
    indicatorScore = simpleScore(coarseIndex);
    operational = false;
    if ~isempty(Smodel.IndicatorModel)
        try
            prediction = predict(Smodel.IndicatorModel,candidates(coarseIndex,:));
            if all(isfinite(prediction))
                indicatorScore = prediction;
                operational = true;
            end
        catch
        end
    end
    if shuffle && operational
        indicatorScore = localPermutation(indicatorScore,Smodel,91);
    end
    retainedCount = numel(coarseIndex);
    local = topK(indicatorScore,true(numel(indicatorScore),1), ...
        min(K,numel(indicatorScore)));
    selected = coarseIndex(local);
end

function mask = coarseMask(score)
    count = numel(score);
    keep = min(count,max(20,ceil(0.30*count)));
    mask = maskFromIndex(count,topK(score,true(count,1),keep));
end

function selected = topK(score,universe,K)
    index = find(universe);
    if isempty(index) || K < 1
        selected = zeros(0,1);
        return;
    end
    [~,order] = sort(score(index),'descend');
    selected = index(order(1:min(K,numel(order))));
end

function selected = diversitySelection(candidates,index,score,K)
    index = index(:);
    if isempty(index) || K < 1
        selected = zeros(0,1);
        return;
    end
    if numel(index) <= K
        [~,order] = sort(score(index),'descend');
        selected = index(order);
        return;
    end
    [~,first] = max(score(index));
    selected = index(first);
    remain = index;
    remain(first) = [];
    while numel(selected) < K && ~isempty(remain)
        distance = min(pdist2(candidates(remain,:),candidates(selected,:)),[],2);
        acquisition = 0.75.*norm01(score(remain)) + 0.25.*norm01(distance);
        [~,best] = max(acquisition);
        selected(end+1,1) = remain(best); %#ok<AGROW>
        remain(best) = [];
    end
end

function [simpleScore,weightedScore,ambiguity] = relationScores(Smodel,candidates)
    modelX = Smodel.X;
    positive = modelX(Smodel.Y == 1,:);
    negative = modelX(Smodel.Y ~= 1,:);
    nPositive = size(positive,1);
    nNegative = size(negative,1);
    nCandidates = size(candidates,1);
    simpleScore = zeros(nCandidates,1);
    weightedScore = zeros(nCandidates,1);
    ambiguity = ones(nCandidates,1);
    if nPositive == 0 || nNegative == 0 || nCandidates == 0
        return;
    end
    pairsPerCandidate = 2*(nPositive+nNegative);
    testData = zeros(pairsPerCandidate*nCandidates,2*size(positive,2));
    for candidate = 1:nCandidates
        offset = (candidate-1)*pairsPerCandidate;
        xi = repmat(candidates(candidate,:),nPositive,1);
        testData(offset+1:offset+nPositive,:) = [positive,xi];
        testData(offset+nPositive+1:offset+2*nPositive,:) = [xi,positive];
        xi = repmat(candidates(candidate,:),nNegative,1);
        testData(offset+2*nPositive+1:offset+2*nPositive+nNegative,:) = ...
            [negative,xi];
        testData(offset+2*nPositive+nNegative+1:offset+pairsPerCandidate,:) = ...
            [xi,negative];
    end
    normalized = mapminmax('apply',testData',Smodel.mp_struct)';
    prediction = Smodel.net(normalized')';
    confidence = max(prediction,[],2);
    for candidate = 1:nCandidates
        offset = (candidate-1)*pairsPerCandidate;
        groups = { ...
            offset+(1:nPositive), ...
            offset+nPositive+(1:nPositive), ...
            offset+2*nPositive+(1:nNegative), ...
            offset+2*nPositive+nNegative+(1:nNegative)};
        simpleMeans = cellfun(@(idx)mean(prediction(idx,:),1), ...
            groups,'UniformOutput',false);
        weightedMeans = cellfun(@(idx)weightedMean( ...
            prediction(idx,:),confidence(idx)),groups,'UniformOutput',false);
        simpleScore(candidate) = evidenceScore(simpleMeans);
        weightedScore(candidate) = evidenceScore(weightedMeans);
        ambiguity(candidate) = 1-mean(confidence([groups{:}]));
    end
end

function score = evidenceScore(parts)
    a = parts{1}; b = parts{2}; c = parts{3}; d = parts{4};
    positive = a(2)+a(3) + b(2)+b(1) + c(3) + d(1);
    negative = a(1) + b(3) + c(2)+c(1) + d(2)+d(3);
    score = positive-negative;
end

function value = weightedMean(x,w)
    value = sum(x.*w(:),1)./(sum(w)+eps);
end

function value = localPermutation(value,Smodel,controlID)
    seed = double(Smodel.RandomControlSeed) + ...
        1009*double(Smodel.Generation) + controlID;
    stream = RandStream('mt19937ar','Seed',mod(seed,2^32-1));
    value = value(randperm(stream,numel(value)));
end

function mask = maskFromIndex(count,index)
    mask = false(count,1);
    mask(index) = true;
end

function scaled = norm01(value)
    value = value(:);
    if isempty(value)
        scaled = value;
    elseif max(value)-min(value) < 1e-12
        scaled = 0.5.*ones(size(value));
    else
        scaled = (value-min(value))./(max(value)-min(value));
    end
end

function reason = fallbackReason(trace)
    if trace.AttemptedMode == "indicator" && trace.Mode ~= "indicator"
        reason = "INDICATOR_MODEL_UNAVAILABLE";
    elseif trace.Mode == "indicator" && ~trace.OperationalIndicatorUsed
        reason = "INDICATOR_PREDICTION_FALLBACK";
    else
        reason = "NONE";
    end
end

function count = countExactDuplicates(candidates,archive)
    if isempty(archive)
        count = 0;
    else
        count = nnz(ismember(candidates,archive,'rows'));
    end
end

function count = countNearDuplicates(candidates,archive,lower,upper)
    if isempty(archive)
        count = 0;
        return;
    end
    scale = upper-lower;
    scale(scale <= 0) = 1;
    candidateScaled = (candidates-lower)./scale;
    archiveScaled = (archive-lower)./scale;
    distance = min(pdist2(candidateScaled,archiveScaled),[],2);
    count = nnz(distance <= 1e-10);
end

function trace = emptyTrace(mode)
    trace = struct('Candidates',zeros(0,0),'Mode',mode, ...
        'SelectedIndex',zeros(0,1),'SelectedK',0);
end
