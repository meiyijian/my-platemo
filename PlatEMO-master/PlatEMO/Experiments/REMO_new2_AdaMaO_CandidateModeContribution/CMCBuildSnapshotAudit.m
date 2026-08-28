function [snapshotRows,referenceRow] = CMCBuildSnapshotAudit( ...
    Problem,Archive,trace,snapshotID,generation,referenceSizes, ...
    randomReplicates,randomControlSeed,thresholds)
%CMCBUILDSNAPSHOTAUDIT Evaluate all policies on one frozen candidate state.
%   CalObj/CalCon are called once for the full pool and do not consume FE.

    callerRng = rng;
    restoreRng = onCleanup(@()rng(callerRng));
    feBefore = Problem.FE;
    candidates = Problem.CalDec(trace.Candidates);
    candidateObj = Problem.CalObj(candidates);
    candidateCon = Problem.CalCon(candidates);
    if Problem.FE ~= feBefore
        error('CMC:ShadowChangedFE','Same-state shadow evaluation changed FE.');
    end

    archiveObj = Archive.objs;
    archiveCon = Archive.cons;
    archiveFeasible = feasibleRows(archiveCon,size(archiveObj,1));
    candidateFeasible = feasibleRows(candidateCon,size(candidateObj,1));
    if ~any(archiveFeasible)
        error('CMC:NoFeasibleArchive','Shadow audit requires a feasible archive.');
    end
    referenceAll = Problem.GetOptimum(max(referenceSizes));
    if isempty(referenceAll) || size(referenceAll,2) ~= Problem.M
        error('CMC:MissingReferenceSet','Problem optimum is unavailable.');
    end

    requested = min(referenceSizes(:)',size(referenceAll,1));
    requested = unique(requested,'stable');
    while numel(requested) < 3
        requested(end+1) = size(referenceAll,1); %#ok<AGROW>
    end
    requested = requested(1:3);
    referenceSets = nestedReferences(referenceAll,requested);
    low = distanceState(archiveObj(archiveFeasible,:),candidateObj, ...
        candidateFeasible,referenceSets{1});
    lowSelection = greedyBatch(low,trace.Policy.K);
    lowUtility = low.MarginalUtility;
    high = distanceState(archiveObj(archiveFeasible,:),candidateObj, ...
        candidateFeasible,referenceSets{2});
    highSelection = greedyBatch(high,trace.Policy.K);
    highUtility = high.MarginalUtility;
    [spearman,jaccard] = stability(lowUtility,highUtility, ...
        lowSelection,highSelection);
    stable = spearman >= thresholds.ReferenceSpearman && ...
        jaccard >= thresholds.ReferenceJaccard;
    escalated = ~stable;
    comparisonLowSize = requested(1);
    comparisonHighSize = requested(2);
    if escalated
        clear low lowUtility
        finalTruth = distanceState(archiveObj(archiveFeasible,:), ...
            candidateObj,candidateFeasible, ...
            referenceSets{3});
        finalSelection = greedyBatch(finalTruth,trace.Policy.K);
        [spearman,jaccard] = stability(highUtility, ...
            finalTruth.MarginalUtility,highSelection,finalSelection);
        stable = spearman >= thresholds.ReferenceSpearman && ...
            jaccard >= thresholds.ReferenceJaccard;
        comparisonLowSize = requested(2);
        comparisonHighSize = requested(3);
        clear high highUtility
        truth = finalTruth;
        oracleIndex = finalSelection;
    else
        clear low lowUtility
        truth = high;
        oracleIndex = highSelection;
    end
    oracleGain = batchGain(truth,oracleIndex);
    if stable
        referenceStatus = "PASS";
    else
        referenceStatus = "INSUFFICIENT_REFERENCE_STABILITY";
    end
    referenceRow = CMCReferenceSchema();
    referenceRow(1,:) = {snapshotID,generation,feBefore, ...
        comparisonLowSize,comparisonHighSize,spearman,jaccard, ...
        escalated,truth.ReferenceSize,stable,referenceStatus};

    randomCache = matchedRandomDistributions(truth,trace,oracleGain, ...
        randomReplicates,randomControlSeed,generation);
    policyNames = ["FINAL_MATCHED","ACCUM_MATCHED","EXP_NO_Q", ...
        "EXP_NO_C","EXP_NO_D","EXP_SIMPLE_FULL","EXP_FULL", ...
        "IND_RELATION_ONLY","IND_FULL","SHUFFLED_D","SHUFFLED_F", ...
        "EXP_NO_PERR_GATE","ORACLE_GREEDY","RANDOM_MATCHED"];
    factors = ["P","P","Q","C","D","E_FINAL","FULL","F","F", ...
        "D_SIGNAL","F_SIGNAL","P_ERR_GATE","ORACLE","RANDOM"];
    snapshotRows = CMCSnapshotSchema();
    for index = 1:numel(policyNames)
        rule = policyNames(index);
        random = randomCache.(char(randomKey(rule,trace.Mode)));
        randomEfficiency = random.Efficiency;
        randomGain = random.Gain;
        randomMean = mean(randomEfficiency,'omitnan');
        randomP95 = prctile(randomEfficiency,95);
        if rule == "ORACLE_GREEDY"
            selected = oracleIndex;
            gain = oracleGain;
            selectedHash = indexHash(selected);
        elseif rule == "RANDOM_MATCHED"
            selected = zeros(0,1);
            gain = mean(randomGain,'omitnan');
            selectedHash = "MULTIPLE_RANDOM_BATCHES";
        else
            selected = find(trace.Policy.(char(rule)));
            gain = batchGain(truth,selected);
            selectedHash = indexHash(selected);
        end
        if oracleGain <= thresholds.UtilityTolerance*max(1,truth.BaselineIGDp)
            efficiency = NaN;
            utilityStatus = "INSUFFICIENT_UTILITY_VARIATION";
        else
            efficiency = gain/oracleGain;
            utilityStatus = referenceStatus;
        end
        if rule == "RANDOM_MATCHED"
            efficiency = randomMean;
        end
        if isfinite(efficiency) && any(isfinite(randomEfficiency))
            randomPercentile = mean( ...
                randomEfficiency(isfinite(randomEfficiency)) <= efficiency);
        else
            randomPercentile = NaN;
        end
        recall = numel(intersect(selected,oracleIndex))/max(1,numel(oracleIndex));
        ndRate = selectedNondominatedRate(candidateObj,candidateFeasible,selected);
        row = {snapshotID,generation,feBefore,feBefore/Problem.maxFE,rule, ...
            factors(index),trace.Policy.K,poolDefinition(rule), ...
            retainedDefinition(rule),selectedHash,truth.BaselineIGDp, ...
            truth.BaselineIGDp-gain,gain,oracleGain,efficiency, ...
            randomMean,randomP95,randomPercentile,recall,ndRate, ...
            size(candidates,1),false,truth.ReferenceSize, ...
            truth.ReferenceHash,utilityStatus};
        snapshotRows = [snapshotRows;row]; %#ok<AGROW>
    end
    if Problem.FE ~= feBefore || ~isequal(rng,callerRng)
        error('CMC:ShadowStateDrift','Shadow audit changed FE or global RNG.');
    end
end

function state = distanceState(archiveObj,candidateObj,candidateFeasible,reference)
    referenceCount = size(reference,1);
    baseline = inf(referenceCount,1);
    for row = 1:size(archiveObj,1)
        delta = max(archiveObj(row,:)-reference,0);
        baseline = min(baseline,sqrt(sum(delta.^2,2)));
    end
    count = size(candidateObj,1);
    distance = inf(referenceCount,count);
    for first = 1:256:count
        last = min(first+255,count);
        blockIndex = first:last;
        feasibleIndex = blockIndex(candidateFeasible(blockIndex));
        if isempty(feasibleIndex)
            continue;
        end
        squared = zeros(referenceCount,numel(feasibleIndex));
        for objective = 1:size(candidateObj,2)
            shifted = max(candidateObj(feasibleIndex,objective)'- ...
                reference(:,objective),0);
            squared = squared + shifted.^2;
        end
        distance(:,feasibleIndex) = sqrt(squared);
    end
    marginal = mean(max(baseline-distance,0),1)';
    marginal(~candidateFeasible) = 0;
    state = struct('BaselineDistance',baseline, ...
        'CandidateDistance',distance,'MarginalUtility',marginal, ...
        'BaselineIGDp',mean(baseline),'ReferenceSize',referenceCount, ...
        'ReferenceHash',CMCTextHash(sprintf('%.12g,',reference(:))));
end

function selected = greedyBatch(state,K)
    selected = zeros(0,1);
    available = true(size(state.CandidateDistance,2),1);
    current = state.BaselineDistance;
    for slot = 1:min(K,nnz(available))
        index = find(available);
        after = min(current,state.CandidateDistance(:,index));
        gain = mean(current-after,1);
        [~,best] = max(gain);
        chosen = index(best);
        selected(end+1,1) = chosen; %#ok<AGROW>
        available(chosen) = false;
        current = min(current,state.CandidateDistance(:,chosen));
    end
end

function value = batchGain(state,index)
    index = index(:);
    if isempty(index)
        value = 0;
    else
        after = min(state.BaselineDistance, ...
            min(state.CandidateDistance(:,index),[],2));
        value = max(0,mean(state.BaselineDistance-after));
    end
end

function [efficiency,gain] = randomDistribution( ...
        state,eligibleMask,K,oracleGain,repetitions,seed,generation,controlID)
    index = find(eligibleMask);
    if numel(index) < K
        index = (1:size(state.CandidateDistance,2))';
    end
    stream = RandStream('mt19937ar','Seed', ...
        mod(double(seed)+7919*generation+104729*controlID,2^32-1));
    gain = NaN(repetitions,1);
    for repetition = 1:repetitions
        order = randperm(stream,numel(index),min(K,numel(index)));
        gain(repetition) = batchGain(state,index(order));
    end
    if oracleGain <= 0
        efficiency = NaN(size(gain));
    else
        efficiency = gain./oracleGain;
    end
end

function cache = matchedRandomDistributions( ...
        truth,trace,oracleGain,repetitions,seed,generation)
    count = size(trace.Candidates,1);
    masks = struct( ...
        'ALL',true(count,1), ...
        'LAST',ismember(trace.Candidates,trace.LastCandidates,'rows'), ...
        'EXP',logical(trace.Policy.ExploreRetained(:)), ...
        'IND',logical(trace.Policy.RelationCoarse(:)));
    names = string(fieldnames(masks));
    cache = struct();
    for index = 1:numel(names)
        name = names(index);
        [efficiency,gain] = randomDistribution(truth, ...
            masks.(char(name)),trace.Policy.K,oracleGain,repetitions, ...
            seed,generation,index);
        cache.(char(name)) = struct( ...
            'Efficiency',efficiency,'Gain',gain);
    end
end

function key = randomKey(rule,mode)
    if rule == "FINAL_MATCHED"
        key = "LAST";
    elseif rule == "ACCUM_MATCHED" || rule == "ORACLE_GREEDY"
        key = "ALL";
    elseif startsWith(rule,"IND_") || rule == "SHUFFLED_F"
        key = "IND";
    elseif rule == "RANDOM_MATCHED"
        if string(mode) == "indicator"
            key = "IND";
        else
            key = "EXP";
        end
    else
        key = "EXP";
    end
end

function references = nestedReferences(allReference,counts)
    highIndex = spacedIndex(size(allReference,1),counts(3));
    middlePosition = spacedIndex(numel(highIndex),counts(2));
    middleIndex = highIndex(middlePosition);
    lowPosition = spacedIndex(numel(middleIndex),counts(1));
    lowIndex = middleIndex(lowPosition);
    references = {allReference(lowIndex,:),allReference(middleIndex,:), ...
        allReference(highIndex,:)};
end

function index = spacedIndex(total,count)
    count = min(count,total);
    index = unique(round(linspace(1,total,count)),'stable');
end

function [rho,jaccard] = stability(lowUtility,highUtility,lowTop,highTop)
    rho = corr(lowUtility,highUtility,'Type','Spearman','Rows','complete');
    if ~isfinite(rho) && max(lowUtility)-min(lowUtility) <= 1e-14 && ...
            max(highUtility)-min(highUtility) <= 1e-14
        rho = 1;
    end
    jaccard = numel(intersect(lowTop,highTop))/max(1,numel(union(lowTop,highTop)));
end

function feasible = feasibleRows(constraints,count)
    if isempty(constraints)
        feasible = true(count,1);
    else
        feasible = all(constraints <= 0,2);
    end
end

function value = selectedNondominatedRate(objectives,feasible,selected)
    if isempty(selected)
        value = NaN;
        return;
    end
    valid = selected(feasible(selected));
    if isempty(valid)
        value = 0;
        return;
    end
    front = NDSort(objectives(valid,:),1);
    value = nnz(front == 1)/numel(selected);
end

function value = indexHash(index)
    value = CMCTextHash(join(string(sort(index(:))),","));
end

function value = poolDefinition(rule)
    if rule == "FINAL_MATCHED"
        value = "FINAL_UNIQUE_POOL";
    else
        value = "TRAJECTORY_UNIQUE_POOL";
    end
end

function value = retainedDefinition(rule)
    if contains(rule,"IND")
        value = "RELATION_TOP30";
    elseif rule == "RANDOM_MATCHED"
        value = "MODE_MATCHED_ELIGIBLE_SET";
    else
        value = "EXPLORE_QKEEP_OR_ALL";
    end
end
