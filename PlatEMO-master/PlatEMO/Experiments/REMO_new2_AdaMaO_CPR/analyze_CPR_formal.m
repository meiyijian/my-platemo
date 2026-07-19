function analysis = analyze_CPR_formal(resultDir)
%ANALYZE_CPR_FORMAL Analyze complete paired FE=500 formal CPR results.
%   ANALYSIS = ANALYZE_CPR_FORMAL(RESULTDIR) performs problem-wise paired
%   signed-rank tests against U0 and the seed-level 2-by-2 interaction.
%   M=10 and M=20 are separate multiplicity families. Inferential fields
%   remain NaN unless all 30 planned run/seed pairs are present.

    if nargin < 1 || isempty(resultDir)
        thisDir = fileparts(mfilename('fullpath'));
        resultDir = fullfile(thisDir,'results','FE500','formal');
    end
    if ~(ischar(resultDir) || (isstring(resultDir) && isscalar(resultDir)))
        error('AdaMaO:InvalidCPRResultDirectory', ...
            'resultDir must be a character vector or scalar string.');
    end
    resultDir = char(resultDir);
    if ~isfolder(resultDir)
        error('AdaMaO:MissingCPRResultDirectory', ...
            'Result directory does not exist: %s.',resultDir);
    end
    if isempty(which('signrank'))
        error('AdaMaO:MissingSignrank', ...
            'The formal CPR analysis requires MATLAB signrank.');
    end

    protocol = CPRExperimentProtocol('formal');
    records = loadFormalRecords(resultDir,protocol);
    records = records(records.Profile == "formal" & records.MaxFE == 500,:);
    plannedProblems = string(protocol.problems);
    plannedAlgorithms = string(protocol.algorithmLabels);
    records = records(ismember(records.Problem,plannedProblems) & ...
        ismember(records.M,protocol.objectives) & ...
        ismember(records.Algorithm,plannedAlgorithms),:);
    if isempty(records)
        error('AdaMaO:NoCPRFormalResults', ...
            'No planned profile=formal, FE=500 results were found in %s.',resultDir);
    end
    assertUniqueFormalRecords(records);

    stream = RandStream('mt19937ar','Seed',protocol.analysis.bootstrapSeed + 1);
    alternatives = string(protocol.algorithmLabels(2:end));
    pairwise = buildPairwise(records,protocol,alternatives,stream);
    pairwise = applyHolmWithinM(pairwise,protocol);
    interaction = buildInteractions(records,protocol,stream);
    completeness = buildCompleteness(pairwise,interaction,protocol);

    analysis = struct();
    analysis.pairwise = pairwise;
    analysis.interaction = interaction;
    analysis.completeness = completeness;
    analysis.settings = struct( ...
        'expectedPairs',protocol.runs, ...
        'bootstrapSamples',protocol.analysis.bootstrapSamples, ...
        'bootstrapSeed',protocol.analysis.bootstrapSeed + 1, ...
        'holmFamily','all planned problem-by-algorithm comparisons within each M');
    analysis.resultDir = resultDir;
    analysis.completedRunCount = height(records);

    writetable(pairwise,fullfile(resultDir,'CPR_formal_pairwise.csv'));
    writetable(interaction,fullfile(resultDir,'CPR_formal_interaction.csv'));
    writetable(completeness,fullfile(resultDir,'CPR_formal_completeness.csv'));
    save(fullfile(resultDir,'CPR_formal_analysis.mat'),'analysis');
end

function records = loadFormalRecords(resultDir,protocol)
    files = dir(fullfile(resultDir,'**','run_*.mat'));
    records = table(strings(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        'VariableNames',{'Profile','Problem','M','Run','Seed','Algorithm', ...
        'MaxFE','IGD','IGDp'});
    for index = 1:numel(files)
        filePath = fullfile(files(index).folder,files(index).name);
        try
            loaded = load(filePath,'metadata','IGD','IGDp');
        catch exception
            warning('AdaMaO:SkippedMalformedCPRResult', ...
                'Skipping unreadable result %s: %s.',filePath,exception.message);
            continue;
        end
        if ~isfield(loaded,'metadata') || ~isstruct(loaded.metadata) || ...
                ~isscalar(loaded.metadata)
            warning('AdaMaO:SkippedMalformedCPRResult', ...
                'Skipping result without scalar metadata: %s.',filePath);
            continue;
        end
        required = {'profile','problem','M','run','seed','algorithmLabel','maxFE'};
        if ~all(isfield(loaded.metadata,required))
            warning('AdaMaO:SkippedMalformedCPRResult', ...
                'Skipping result with incomplete metadata: %s.',filePath);
            continue;
        end
        if ~isTextScalarFormal(loaded.metadata.profile) || ...
                ~strcmp(char(loaded.metadata.profile),'formal')
            continue;
        end
        [expected,validMetadata] = expectedFormalJob(loaded.metadata,protocol);
        if ~validMetadata
            continue;
        end
        row = {"formal",expected.Problem,expected.M,expected.Run, ...
            expected.Seed,expected.Algorithm,protocol.maxFE,metricOrNaN(loaded,'IGD'), ...
            metricOrNaN(loaded,'IGDp')};
        records(end+1,:) = row; %#ok<AGROW>
    end
end

function [job,valid] = expectedFormalJob(metadata,protocol)
    job = protocol.jobs([],:);
    valid = isTextScalarFormal(metadata.problem) && ...
        isTextScalarFormal(metadata.algorithmLabel) && ...
        isFiniteScalarFormal(metadata.M) && isFiniteScalarFormal(metadata.run) && ...
        isFiniteScalarFormal(metadata.seed) && isFiniteScalarFormal(metadata.maxFE);
    if ~valid || double(metadata.maxFE) ~= protocol.maxFE
        return;
    end
    rows = protocol.jobs.Problem == string(metadata.problem) & ...
        protocol.jobs.M == double(metadata.M) & ...
        protocol.jobs.Run == double(metadata.run) & ...
        protocol.jobs.Seed == double(metadata.seed) & ...
        protocol.jobs.Algorithm == string(metadata.algorithmLabel);
    if sum(rows) ~= 1
        valid = false;
        return;
    end
    job = protocol.jobs(rows,:);
    if isfield(metadata,'requestedD')
        valid = isFiniteScalarFormal(metadata.requestedD) && ...
            double(metadata.requestedD) == job.RequestedD;
    end
    if valid && isfield(metadata,'actualD')
        valid = isFiniteScalarFormal(metadata.actualD) && ...
            double(metadata.actualD) == job.ActualD;
    end
    if valid && isfield(metadata,'algorithmClass')
        valid = isTextScalarFormal(metadata.algorithmClass) && ...
            strcmp(char(metadata.algorithmClass),char(job.AlgorithmClass));
    end
end

function valid = isTextScalarFormal(value)
    valid = ischar(value) || (isstring(value) && isscalar(value));
end

function valid = isFiniteScalarFormal(value)
    valid = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end

function value = scalarOrNaN(value)
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        value = nan;
    else
        value = double(value);
    end
end

function value = metricOrNaN(loaded,fieldName)
    if ~isfield(loaded,fieldName)
        value = nan;
    else
        value = scalarOrNaN(loaded.(fieldName));
    end
end

function assertUniqueFormalRecords(records)
    keys = records.Problem + "|M" + string(records.M) + "|R" + ...
        string(records.Run) + "|S" + string(records.Seed) + "|" + records.Algorithm;
    if numel(unique(keys)) ~= numel(keys)
        error('AdaMaO:DuplicateCPRFormalResult', ...
            'Duplicate formal result keys were found; archive duplicate run files.');
    end
end

function pairwise = buildPairwise(records,protocol,alternatives,stream)
    pairwise = emptyPairwiseTable();
    for M = protocol.objectives
        for problemIndex = 1:numel(protocol.problems)
            problem = string(protocol.problems{problemIndex});
            family = familyOf(problem);
            expected = expectedPairs(protocol,problem,M);
            problemRows = records(records.Problem == problem & records.M == M,:);
            for algorithm = alternatives
                igd = pairedSamples(problemRows,expected,algorithm,'IGD');
                igdp = pairedSamples(problemRows,expected,algorithm,'IGDp');
                igdStats = completeStatistics(igd,protocol.runs,stream, ...
                    protocol.analysis.bootstrapSamples);
                igdpStats = completeStatistics(igdp,protocol.runs,stream, ...
                    protocol.analysis.bootstrapSamples);
                row = {family,problem,M,algorithm,protocol.runs, ...
                    igd.count,igdStats.complete,igdStats.mean,igdStats.ratio, ...
                    igdStats.lower,igdStats.upper,igdStats.p,nan, ...
                    igdp.count,igdpStats.complete,igdpStats.mean,igdpStats.ratio, ...
                    igdpStats.lower,igdpStats.upper,igdpStats.p,nan};
                pairwise(end+1,:) = row; %#ok<AGROW>
            end
        end
    end
end

function tableOut = emptyPairwiseTable()
    tableOut = table(strings(0,1),strings(0,1),zeros(0,1),strings(0,1), ...
        zeros(0,1),zeros(0,1),false(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        false(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1), ...
        'VariableNames',{'Family','Problem','M','Algorithm','ExpectedPairs', ...
        'PairCountIGD','CompleteIGD','IGDMeanLogRatio','IGDGeoMeanRatio', ...
        'IGDCILower','IGDCIUpper','IGDRawP','IGDAdjustedP', ...
        'PairCountIGDp','CompleteIGDp','IGDpMeanLogRatio','IGDpGeoMeanRatio', ...
        'IGDpCILower','IGDpCIUpper','IGDpRawP','IGDpAdjustedP'});
end

function expected = expectedPairs(protocol,problem,M)
    rows = protocol.jobs.Problem == problem & protocol.jobs.M == M & ...
        protocol.jobs.Algorithm == "U0";
    expected = protocol.jobs(rows,{'Run','Seed'});
    expected = sortrows(expected,{'Run','Seed'});
end

function samples = pairedSamples(problemRows,expected,algorithm,metricName)
    baseline = problemRows(problemRows.Algorithm == "U0",:);
    alternative = problemRows(problemRows.Algorithm == algorithm,:);
    values = zeros(0,1);
    for index = 1:height(expected)
        baseMatch = baseline.Run == expected.Run(index) & ...
            baseline.Seed == expected.Seed(index);
        altMatch = alternative.Run == expected.Run(index) & ...
            alternative.Seed == expected.Seed(index);
        if sum(baseMatch) ~= 1 || sum(altMatch) ~= 1
            continue;
        end
        baseValue = baseline.(metricName)(baseMatch);
        altValue = alternative.(metricName)(altMatch);
        if isfinite(baseValue) && isfinite(altValue) && ...
                baseValue > 0 && altValue > 0
            values(end+1,1) = log(altValue/baseValue); %#ok<AGROW>
        end
    end
    samples = struct('values',values,'count',numel(values));
end

function stats = completeStatistics(samples,expectedCount,stream,bootstrapSamples)
    stats = struct('complete',samples.count == expectedCount, ...
        'mean',nan,'ratio',nan,'lower',nan,'upper',nan,'p',nan);
    if ~stats.complete
        return;
    end
    stats.mean = mean(samples.values);
    stats.ratio = exp(stats.mean);
    [stats.lower,stats.upper] = bootstrapMeanRatio(samples.values,stream,bootstrapSamples);
    stats.p = signedRankP(samples.values);
end

function p = signedRankP(values)
    if all(values == 0)
        p = 1;
    else
        p = signrank(values,0);
    end
end

function [lower,upper] = bootstrapMeanRatio(values,stream,sampleCount)
    indices = randi(stream,numel(values),numel(values),sampleCount);
    means = mean(values(indices),1);
    bounds = quantile(means,[0.025,0.975]);
    lower = exp(bounds(1));
    upper = exp(bounds(2));
end

function pairwise = applyHolmWithinM(pairwise,protocol)
    for M = protocol.objectives
        rows = pairwise.M == M;
        pairwise.IGDAdjustedP(rows) = holmAdjusted( ...
            pairwise.IGDRawP(rows),sum(rows));
        pairwise.IGDpAdjustedP(rows) = holmAdjusted( ...
            pairwise.IGDpRawP(rows),sum(rows));
    end
end

function adjusted = holmAdjusted(raw,totalHypotheses)
    adjusted = nan(size(raw));
    finiteIndices = find(isfinite(raw));
    if isempty(finiteIndices)
        return;
    end
    [sorted,order] = sort(raw(finiteIndices));
    ranks = (1:numel(sorted))';
    scaled = (totalHypotheses-ranks+1).*sorted;
    scaled = min(1,cummax(scaled));
    adjusted(finiteIndices(order)) = scaled;
end

function interaction = buildInteractions(records,protocol,stream)
    interaction = emptyInteractionTable();
    for M = protocol.objectives
        for problemIndex = 1:numel(protocol.problems)
            problem = string(protocol.problems{problemIndex});
            family = familyOf(problem);
            expected = expectedPairs(protocol,problem,M);
            problemRows = records(records.Problem == problem & records.M == M,:);
            igd = interactionSamples(problemRows,expected,'IGD');
            igdp = interactionSamples(problemRows,expected,'IGDp');
            igdStats = completeInteractionStatistics(igd,protocol.runs,stream, ...
                protocol.analysis.bootstrapSamples);
            igdpStats = completeInteractionStatistics(igdp,protocol.runs,stream, ...
                protocol.analysis.bootstrapSamples);
            row = {family,problem,M,protocol.runs, ...
                igd.count,igdStats.complete,igdStats.mean,igdStats.lower, ...
                igdStats.upper,igdStats.p,igdp.count,igdpStats.complete, ...
                igdpStats.mean,igdpStats.lower,igdpStats.upper,igdpStats.p};
            interaction(end+1,:) = row; %#ok<AGROW>
        end
    end
end

function tableOut = emptyInteractionTable()
    tableOut = table(strings(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),false(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),false(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        'VariableNames',{'Family','Problem','M','ExpectedPairs', ...
        'PairCountIGD','CompleteIGD','IGDMeanInteraction','IGDCILower', ...
        'IGDCIUpper','IGDRawP','PairCountIGDp','CompleteIGDp', ...
        'IGDpMeanInteraction','IGDpCILower','IGDpCIUpper','IGDpRawP'});
end

function samples = interactionSamples(problemRows,expected,metricName)
    values = zeros(0,1);
    labels = ["F00","F10","F01","F11"];
    for index = 1:height(expected)
        logValues = nan(1,4);
        for algorithmIndex = 1:4
            match = problemRows.Algorithm == labels(algorithmIndex) & ...
                problemRows.Run == expected.Run(index) & ...
                problemRows.Seed == expected.Seed(index);
            if sum(match) == 1
                value = problemRows.(metricName)(match);
                if isfinite(value) && value > 0
                    logValues(algorithmIndex) = log(value);
                end
            end
        end
        if all(isfinite(logValues))
            values(end+1,1) = (logValues(4)-logValues(2))- ...
                (logValues(3)-logValues(1)); %#ok<AGROW>
        end
    end
    samples = struct('values',values,'count',numel(values));
end

function stats = completeInteractionStatistics(samples,expectedCount,stream,bootstrapSamples)
    stats = struct('complete',samples.count == expectedCount, ...
        'mean',nan,'lower',nan,'upper',nan,'p',nan);
    if ~stats.complete
        return;
    end
    stats.mean = mean(samples.values);
    [lowerRatio,upperRatio] = bootstrapMeanRatio(samples.values,stream,bootstrapSamples);
    stats.lower = log(lowerRatio);
    stats.upper = log(upperRatio);
    stats.p = signedRankP(samples.values);
end

function completeness = buildCompleteness(pairwise,interaction,protocol)
    completeness = table(zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        false(0,1),false(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        false(0,1),false(0,1), ...
        'VariableNames',{'M','PlannedComparisons','CompleteIGDComparisons', ...
        'CompleteIGDpComparisons','FullIGDMatrix','FullIGDpMatrix', ...
        'PlannedInteractions','CompleteIGDInteractions','CompleteIGDpInteractions', ...
        'FullIGDInteractionMatrix','FullIGDpInteractionMatrix'});
    for M = protocol.objectives
        comparisonRows = pairwise.M == M;
        interactionRows = interaction.M == M;
        plannedComparisons = sum(comparisonRows);
        completeIGD = sum(pairwise.CompleteIGD(comparisonRows));
        completeIGDp = sum(pairwise.CompleteIGDp(comparisonRows));
        plannedInteractions = sum(interactionRows);
        completeInteractionIGD = sum(interaction.CompleteIGD(interactionRows));
        completeInteractionIGDp = sum(interaction.CompleteIGDp(interactionRows));
        row = {M,plannedComparisons,completeIGD,completeIGDp, ...
            completeIGD == plannedComparisons,completeIGDp == plannedComparisons, ...
            plannedInteractions,completeInteractionIGD,completeInteractionIGDp, ...
            completeInteractionIGD == plannedInteractions, ...
            completeInteractionIGDp == plannedInteractions};
        completeness(end+1,:) = row; %#ok<AGROW>
    end
end

function family = familyOf(problem)
    if startsWith(problem,"DTLZ")
        family = "DTLZ";
    else
        family = "WFG";
    end
end
