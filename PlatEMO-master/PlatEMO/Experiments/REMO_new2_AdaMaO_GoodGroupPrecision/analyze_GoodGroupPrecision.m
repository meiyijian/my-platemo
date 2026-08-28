function outputs = analyze_GoodGroupPrecision(profile, varargin)
%ANALYZE_GOODGROUPPRECISION Analyze completed per-run GGP result files.
%   OUTPUTS = ANALYZE_GOODGROUPPRECISION(PROFILE) aggregates checkpoints
%   within each run and FE stage before any statistical comparison. It
%   reports paired Wilcoxon tests, paired effect sizes, relative
%   improvement, and Holm-adjusted p-values.
%
%   Name-value option:
%     ResultRoot - alternate result directory used by the runner

%   The equal-quota primary comparison contains score_v, anchor_margin,
%   and score_hybrid. Binary label_dyn results remain in a separate native
%   summary because its selected-set size is not fixed at 25%.

    if nargin < 1 || isempty(profile)
        profile = "formal";
    end
    profile = validatestring(string(profile), ["smoke", "pilot", "formal"]);
    [pathInfo, pathCleanup] = GGPSetupPaths(); %#ok<ASGLU>

    parser = inputParser();
    parser.FunctionName = mfilename();
    addParameter(parser, "ResultRoot", ...
        fullfile(pathInfo.ExperimentDirectory, "results"), @isTextScalar);
    parse(parser, varargin{:});
    resultRoot = char(string(parser.Results.ResultRoot));

    rawDirectory = fullfile(resultRoot, "raw", profile);
    rawFiles = dir(fullfile(rawDirectory, "**", "run_*.mat"));
    if isempty(rawFiles)
        error("GGP:NoRawFiles", "No per-run MAT files were found in %s.", rawDirectory);
    end

    metricTables = cell(numel(rawFiles), 1);
    runRows = repmat(makeRunRow(), numel(rawFiles), 1);
    for fileIndex = 1:numel(rawFiles)
        filePath = fullfile(rawFiles(fileIndex).folder, rawFiles(fileIndex).name);
        [isValid, report] = GGPValidateRunFile(filePath, profile);
        if ~isValid
            error("GGP:InvalidRawFile", "Invalid raw file %s: %s", filePath, report.Detail);
        end
        data = load(filePath, "metadata", "checkpointMetrics", "IGD", "IGDp");
        metricTables{fileIndex} = data.checkpointMetrics;
        runRows(fileIndex) = struct( ...
            "Problem", string(data.metadata.Problem), ...
            "M", data.metadata.M, ...
            "Run", data.metadata.Run, ...
            "Seed", data.metadata.Seed, ...
            "IGD", data.IGD, ...
            "IGDp", data.IGDp, ...
            "File", string(filePath));
    end

    runTable = struct2table(runRows);
    assertUniqueRuns(runTable);
    checkpointMetrics = vertcat(metricTables{:});
    perRunStage = aggregatePerRunStage(checkpointMetrics);
    pairedComparisons = buildPairedComparisons(perRunStage);
    coverage = buildCoverage(profile, runTable);
    nativeLabelSummary = perRunStage(perRunStage.SelectionRule == "native", :);

    analysisDirectory = fullfile(resultRoot, "analysis", profile);
    if ~isfolder(analysisDirectory)
        mkdir(analysisDirectory);
    end
    outputPaths = struct( ...
        "CheckpointMetrics", fullfile(analysisDirectory, "GGP_CheckpointMetrics.csv"), ...
        "PerRunStage", fullfile(analysisDirectory, "GGP_PerRunStage.csv"), ...
        "PairedComparisons", fullfile(analysisDirectory, "GGP_PairedComparisons.csv"), ...
        "NativeLabelSummary", fullfile(analysisDirectory, "GGP_LabelDynNative.csv"), ...
        "Coverage", fullfile(analysisDirectory, "GGP_Coverage.csv"));

    writeTableAtomic(checkpointMetrics, outputPaths.CheckpointMetrics);
    writeTableAtomic(perRunStage, outputPaths.PerRunStage);
    writeTableAtomic(pairedComparisons, outputPaths.PairedComparisons);
    writeTableAtomic(nativeLabelSummary, outputPaths.NativeLabelSummary);
    writeTableAtomic(coverage, outputPaths.Coverage);

    outputs = struct( ...
        "Paths", outputPaths, ...
        "CheckpointMetrics", checkpointMetrics, ...
        "PerRunStage", perRunStage, ...
        "PairedComparisons", pairedComparisons, ...
        "NativeLabelSummary", nativeLabelSummary, ...
        "Coverage", coverage);

    fprintf("Analyzed %d valid runs. Results: %s\n", height(runTable), analysisDirectory);
    if any(~coverage.Complete)
        warning("GGP:IncompleteCoverage", ...
            "The selected profile is incomplete. See %s.", outputPaths.Coverage);
    end
end

function perRunStage = aggregatePerRunStage(metrics)
    [groupIndex, problem, objectiveCount, runNumber, seed, stage, view, ...
        selectionRule, truth, truthType, horizon] = findgroups( ...
        metrics.Problem, metrics.M, metrics.Run, metrics.Seed, metrics.Stage, ...
        metrics.View, metrics.SelectionRule, metrics.Truth, metrics.TruthType, ...
        metrics.Horizon);

    numberOfCheckpoints = splitapply(@numel, metrics.SnapshotID, groupIndex);
    validPrecisionCheckpoints = splitapply(@(values) nnz(isfinite(values)), ...
        metrics.Precision, groupIndex);
    meanPrecision = splitapply(@meanFinite, metrics.Precision, groupIndex);
    meanRecall = splitapply(@meanFinite, metrics.Recall, groupIndex);
    meanChance = splitapply(@meanFinite, metrics.Chance, groupIndex);
    meanLift = splitapply(@meanFinite, metrics.Lift, groupIndex);
    meanAUC = splitapply(@meanFinite, metrics.AUC, groupIndex);
    meanRetentionRate = splitapply(@meanFinite, metrics.RetentionRate, groupIndex);
    meanSelectedRate = splitapply(@meanFinite, metrics.SelectedRate, groupIndex);

    perRunStage = table(problem, objectiveCount, runNumber, seed, stage, view, ...
        selectionRule, truth, truthType, horizon, numberOfCheckpoints, ...
        validPrecisionCheckpoints, meanSelectedRate, meanPrecision, meanRecall, ...
        meanChance, meanLift, meanAUC, meanRetentionRate, ...
        'VariableNames', {'Problem', 'M', 'Run', 'Seed', 'Stage', 'View', ...
        'SelectionRule', 'Truth', 'TruthType', 'Horizon', ...
        'NumberOfCheckpoints', 'ValidPrecisionCheckpoints', ...
        'MeanSelectedRate', 'MeanPrecision', 'MeanRecall', 'MeanChance', ...
        'MeanLift', 'MeanAUC', 'MeanRetentionRate'});
end

function comparisons = buildPairedComparisons(perRunStage)
    primary = perRunStage(perRunStage.SelectionRule == "top25", :);
    configurations = unique(primary(:, ["Problem", "M"]), "rows");
    viewPairs = [ ...
        "score_hybrid", "score_v"; ...
        "score_hybrid", "anchor_margin"; ...
        "score_v", "anchor_margin"];
    metricNames = ["Precision", "AUC", "Lift"];
    metricVariables = ["MeanPrecision", "MeanAUC", "MeanLift"];
    rows = repmat(makeComparisonRow(), 0, 1);

    for configIndex = 1:height(configurations)
        problem = configurations.Problem(configIndex);
        objectiveCount = configurations.M(configIndex);
        configRows = primary(primary.Problem == problem & ...
            primary.M == objectiveCount, :);
        stages = unique(configRows.Stage, "stable");
        truths = unique(configRows.Truth, "stable");

        for stage = stages.'
            for truth = truths.'
                groupRows = configRows(configRows.Stage == stage & ...
                    configRows.Truth == truth, :);
                for metricIndex = 1:numel(metricNames)
                    metricName = metricNames(metricIndex);
                    metricVariable = metricVariables(metricIndex);
                    for pairIndex = 1:size(viewPairs, 1)
                        viewA = viewPairs(pairIndex, 1);
                        viewB = viewPairs(pairIndex, 2);
                        row = compareViews(groupRows, metricVariable, metricName, ...
                            problem, objectiveCount, stage, truth, viewA, viewB);
                        rows(end + 1, 1) = row; %#ok<AGROW>
                    end
                end
            end
        end
    end

    comparisons = struct2table(rows);
    if isempty(comparisons)
        return;
    end
    familyIndex = findgroups(comparisons.Problem, comparisons.M, ...
        comparisons.Truth, comparisons.Metric);
    comparisons.PValueHolm = NaN(height(comparisons), 1);
    for family = 1:max(familyIndex)
        members = familyIndex == family;
        comparisons.PValueHolm(members) = ...
            GGPHolmAdjust(comparisons.PValueRaw(members));
    end
    comparisons.RejectHolm05 = comparisons.PValueHolm <= 0.05;
end

function row = compareViews(groupRows, metricVariable, metricName, ...
        problem, objectiveCount, stage, truth, viewA, viewB)
    rowsA = groupRows(groupRows.View == viewA, :);
    rowsB = groupRows(groupRows.View == viewB, :);
    [pairedRuns, indexA, indexB] = intersect(rowsA.Run, rowsB.Run, "stable");
    if any(rowsA.Seed(indexA) ~= rowsB.Seed(indexB))
        error("GGP:SeedPairingFailure", ...
            "Paired views do not share seeds for %s M%d %s %s.", ...
            problem, objectiveCount, stage, truth);
    end

    comparison = GGPComparePaired( ...
        rowsA.(metricVariable)(indexA), rowsB.(metricVariable)(indexB));
    row = makeComparisonRow();
    row.Problem = problem;
    row.M = objectiveCount;
    row.Stage = stage;
    row.Truth = truth;
    row.Metric = metricName;
    row.ViewA = viewA;
    row.ViewB = viewB;
    row.AvailablePairedRuns = numel(pairedRuns);
    row.ValidPairs = comparison.NumberOfPairs;
    row.MeanA = comparison.MeanA;
    row.MeanB = comparison.MeanB;
    row.MeanDelta = comparison.MeanDelta;
    row.MedianDelta = comparison.MedianDelta;
    row.MeanRelativeImprovementPct = comparison.MeanRelativeImprovementPct;
    row.PValueRaw = comparison.PValueRaw;
    row.PairedWinProbability = comparison.PairedWinProbability;
    row.RankBiserial = comparison.RankBiserial;
end

function coverage = buildCoverage(profile, runTable)
    config = GGPProtocol(profile);
    jobs = config.Jobs;
    protocolJobs = struct2table(jobs);
    protocolConfigurations = unique(protocolJobs(:, ["Problem", "M"]), "rows");
    rows = repmat(struct("Problem", "", "M", NaN, "ExpectedRuns", NaN, ...
        "ObservedRuns", NaN, "MissingRuns", "", "Complete", false), ...
        height(protocolConfigurations), 1);

    for configIndex = 1:height(protocolConfigurations)
        problem = protocolConfigurations.Problem(configIndex);
        objectiveCount = protocolConfigurations.M(configIndex);
        expected = sort([jobs([jobs.Problem] == problem & [jobs.M] == objectiveCount).Run]);
        observed = sort(runTable.Run(runTable.Problem == problem & ...
            runTable.M == objectiveCount)).';
        missing = setdiff(expected, observed);
        rows(configIndex) = struct( ...
            "Problem", problem, ...
            "M", objectiveCount, ...
            "ExpectedRuns", numel(expected), ...
            "ObservedRuns", numel(observed), ...
            "MissingRuns", strjoin(string(missing), ";"), ...
            "Complete", isempty(missing));
    end
    coverage = struct2table(rows);
end

function assertUniqueRuns(runTable)
    [~, uniqueRows] = unique(runTable(:, ["Problem", "M", "Run"]), "rows", "stable");
    if numel(uniqueRows) ~= height(runTable)
        error("GGP:DuplicateRun", ...
            "Multiple raw files claim the same problem-M-run identity.");
    end
end

function value = meanFinite(values)
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = mean(values);
    end
end

function writeTableAtomic(dataTable, outputPath)
    outputDirectory = fileparts(outputPath);
    temporaryPath = [tempname(outputDirectory), '.csv'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryPath));
    writetable(dataTable, temporaryPath);
    [moved, message] = movefile(temporaryPath, outputPath, "f");
    if ~moved
        error("GGP:AnalysisWriteFailed", ...
            "Could not write %s: %s", outputPath, message);
    end
end

function row = makeRunRow()
    row = struct("Problem", "", "M", NaN, "Run", NaN, "Seed", NaN, ...
        "IGD", NaN, "IGDp", NaN, "File", "");
end

function row = makeComparisonRow()
    row = struct( ...
        "Problem", "", ...
        "M", NaN, ...
        "Stage", "", ...
        "Truth", "", ...
        "Metric", "", ...
        "ViewA", "", ...
        "ViewB", "", ...
        "AvailablePairedRuns", NaN, ...
        "ValidPairs", NaN, ...
        "MeanA", NaN, ...
        "MeanB", NaN, ...
        "MeanDelta", NaN, ...
        "MedianDelta", NaN, ...
        "MeanRelativeImprovementPct", NaN, ...
        "PValueRaw", NaN, ...
        "PairedWinProbability", NaN, ...
        "RankBiserial", NaN);
end

function deleteIfPresent(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end

function isValid = isTextScalar(value)
    isValid = (isstring(value) && isscalar(value)) || ischar(value);
end
