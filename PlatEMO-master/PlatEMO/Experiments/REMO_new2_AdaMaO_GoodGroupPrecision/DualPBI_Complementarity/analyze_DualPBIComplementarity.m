function outputs = analyze_DualPBIComplementarity(profile, options)
%analyze_DualPBIComplementarity - Analyze all valid replay results
%   OUTPUTS = analyze_DualPBIComplementarity(PROFILE) aggregates replay
%   snapshots within independent run-stage units, performs the preplanned
%   primary tests, writes tables and figures, and builds the final gate.
%
%   OUTPUTS = analyze_DualPBIComplementarity(...,ResultRoot=PATH) reads and
%   writes an alternate isolated result root.
%
%   OUTPUTS = analyze_DualPBIComplementarity(...,SourceResultRoot=PATH)
%   reads the original Good-Group Precision analysis from PATH.
%
%   See also run_DualPBIComplementarity, DPCBuildFinalGate

    arguments
        profile (1,1) string {mustBeMember(profile, ...
            ["smoke", "pilot", "formal"])} = "formal"
        options.ResultRoot (1,1) string = ""
        options.SourceResultRoot (1,1) string = ""
    end

    [pathInfo, pathCleanup] = DPCSetupPaths(); %#ok<ASGLU>
    resultRoot = resolvePathOption( ...
        options.ResultRoot, pathInfo.DefaultResultRoot);
    sourceResultRoot = resolvePathOption( ...
        options.SourceResultRoot, pathInfo.DefaultSourceResultRoot);
    tableDirectory = fullfile(resultRoot, "analysis", profile, "tables");
    figureDirectory = fullfile(resultRoot, "analysis", profile, "figures");
    if ~isfolder(tableDirectory)
        mkdir(tableDirectory);
    end
    if ~isfolder(figureDirectory)
        mkdir(figureDirectory);
    end

    [perRunStage, replay] = loadReplayResults(resultRoot, profile);
    sourcePerRunStagePath = fullfile(sourceResultRoot, "analysis", ...
        profile, "GGP_PerRunStage.csv");
    if ~isfile(sourcePerRunStagePath)
        error("DPC:MissingSourceAnalysis", ...
            "Source per-run-stage analysis is missing: %s", ...
            sourcePerRunStagePath);
    end
    sourcePerRunStage = readtable(sourcePerRunStagePath, ...
        "TextType", "string");
    fusionTests = DPCBuildStrictFusionTests(sourcePerRunStage);
    uniqueTests = DPCBuildUniqueContributionTests(perRunStage);
    decisions = buildDecisions(fusionTests, uniqueTests);

    config = GGPProtocol(profile);
    coverage = buildCoverage(config.Jobs, replay);
    protocolJobTable = struct2table(config.Jobs);
    protocolConfigurations = unique( ...
        protocolJobTable(:, ["Problem", "M"]), "rows");
    finalGate = DPCBuildFinalGate(coverage, replay, ...
        fusionTests, uniqueTests, decisions, ...
        numel(config.Jobs), height(protocolConfigurations));

    paths = struct( ...
        "PerRunStage", fullfile(tableDirectory, ...
            "GGP_ComplementarityPerRunStage.csv"), ...
        "FusionTests", fullfile(tableDirectory, ...
            "GGP_StrictFusionTests.csv"), ...
        "UniqueTests", fullfile(tableDirectory, ...
            "GGP_UniqueContributionTests.csv"), ...
        "Decisions", fullfile(tableDirectory, ...
            "GGP_ComplementarityDecision.csv"), ...
        "Replay", fullfile(tableDirectory, ...
            "GGP_ReplayEquivalence.csv"), ...
        "Coverage", fullfile(tableDirectory, ...
            "GGP_ComplementarityCoverage.csv"), ...
        "FinalGate", fullfile(tableDirectory, "GGP_FinalGate.csv"), ...
        "Summary", fullfile(resultRoot, "analysis", profile, ...
            "GGP_ResultSummary.md"));
    writeTableAtomic(perRunStage, paths.PerRunStage);
    writeTableAtomic(fusionTests, paths.FusionTests);
    writeTableAtomic(uniqueTests, paths.UniqueTests);
    writeTableAtomic(decisions, paths.Decisions);
    writeTableAtomic(replay, paths.Replay);
    writeTableAtomic(coverage, paths.Coverage);
    writeTableAtomic(finalGate, paths.FinalGate);
    figurePaths = makeFigures( ...
        fusionTests, uniqueTests, decisions, figureDirectory);
    writeSummary(paths.Summary, profile, finalGate, decisions, paths);

    outputs = struct( ...
        "Paths", paths, ...
        "FigurePaths", figurePaths, ...
        "PerRunStage", perRunStage, ...
        "FusionTests", fusionTests, ...
        "UniqueTests", uniqueTests, ...
        "Decisions", decisions, ...
        "ReplayEquivalence", replay, ...
        "Coverage", coverage, ...
        "FinalGate", finalGate);
end

function [perRunStage, replay] = loadReplayResults(resultRoot, profile)
    rawDirectory = fullfile(resultRoot, "raw", profile);
    rawFiles = dir(fullfile(rawDirectory, "**", "run_*.mat"));
    replayRows = repmat(makeReplayRow(), numel(rawFiles), 1);
    aggregateTables = cell(numel(rawFiles), 1);
    validTableCount = 0;
    for fileIndex = 1:numel(rawFiles)
        filePath = fullfile(rawFiles(fileIndex).folder, ...
            rawFiles(fileIndex).name);
        [isValid, report] = DPCValidateReplayFile(filePath, profile);
        replayRow = makeReplayRow();
        replayRow.File = string(filePath);
        replayRow.ValidFile = isValid;
        replayRow.ValidationDetail = report.Detail;
        if isValid
            data = load(filePath, "metadata", ...
                "complementarityMetrics", "replayValidation");
            replayRow = fillReplayRow(replayRow, data);
            validTableCount = validTableCount + 1;
            aggregateTables{validTableCount} = aggregateOneRun( ...
                data.complementarityMetrics);
        else
            replayRow.EquivalencePass = false;
        end
        replayRows(fileIndex) = replayRow;
    end

    replay = struct2table(replayRows);
    if isempty(rawFiles)
        replay = struct2table(makeReplayRow());
        replay = replay([], :);
    end
    if validTableCount == 0
        perRunStage = emptyPerRunStage();
    else
        perRunStage = vertcat(aggregateTables{1:validTableCount});
        perRunStage = sortrows(perRunStage, ...
            ["Problem", "M", "Run", "Stage", "Truth"]);
    end
end

function row = fillReplayRow(row, data)
    row.Profile = string(data.metadata.Profile);
    row.Problem = string(data.metadata.Problem);
    row.M = data.metadata.M;
    row.Run = data.metadata.Run;
    row.Seed = data.metadata.Seed;
    row.ValidFile = true;
    row.EquivalencePass = data.replayValidation.EquivalencePass;
    row.CompletedFEMatch = data.replayValidation.CompletedFEMatch;
    row.FinalPopulationMatch = ...
        data.replayValidation.FinalPopulationMatch;
    row.IGDMatch = data.replayValidation.IGDMatch;
    row.IGDpMatch = data.replayValidation.IGDpMatch;
    row.MaxPopulationAbsDiff = ...
        data.replayValidation.MaxPopulationAbsDiff;
    row.IGDAbsDiff = data.replayValidation.IGDAbsDiff;
    row.IGDpAbsDiff = data.replayValidation.IGDpAbsDiff;
    row.ValidationDetail = "PASS";
end

function perRun = aggregateOneRun(metrics)
    [groupIndex, problem, objectiveCount, runNumber, seed, stage, ...
        truth, truthType, horizon] = findgroups(metrics.Problem, metrics.M, ...
        metrics.Run, metrics.Seed, metrics.Stage, metrics.Truth, ...
        metrics.TruthType, metrics.Horizon);
    numberOfSnapshots = splitapply(@numel, metrics.SnapshotID, groupIndex);
    validTruthSnapshots = splitapply(@(x) nnz(~x), ...
        metrics.Censored, groupIndex);

    variableNames = ["JaccardVA", "AgreementVA", "JaccardHV", ...
        "JaccardHA", "JaccardVLabelNative", "JaccardHLabelNative", ...
        "VOnlyCount", "AOnlyCount", "TPVOnly", "TPAOnly", ...
        "UniqueTPRateV", "UniqueTPRateA", "UniquePrecisionV", ...
        "UniquePrecisionA", "UniqueTPShare", "HybridFromBoth", ...
        "HybridFromVOnly", "HybridFromAOnly", "HybridFromNeither", ...
        "HybridTPFromBoth", "HybridTPFromVOnly", ...
        "HybridTPFromAOnly", "HybridTPFromNeither", ...
        "LostTrueFromV", "LostTrueFromA", "VPrecision", ...
        "APrecision", "HybridPrecision"];
    meanValues = cell(1, numel(variableNames));
    for variableIndex = 1:numel(variableNames)
        meanValues{variableIndex} = splitapply(@meanFinite, ...
            metrics.(variableNames(variableIndex)), groupIndex);
    end

    perRun = table(problem, objectiveCount, runNumber, seed, stage, ...
        truth, truthType, horizon, numberOfSnapshots, validTruthSnapshots, ...
        'VariableNames', {'Problem','M','Run','Seed','Stage','Truth', ...
        'TruthType','Horizon','NumberOfSnapshots','ValidTruthSnapshots'});
    outputNames = "Mean" + variableNames;
    for variableIndex = 1:numel(outputNames)
        perRun.(outputNames(variableIndex)) = meanValues{variableIndex};
    end
end

function decisions = buildDecisions(fusionTests, uniqueTests)
    keys = ["Problem", "M", "Stage"];
    decisions = innerjoin(fusionTests, uniqueTests, "Keys", keys, ...
        "LeftVariables", [keys, "ValidPairs", ...
            "MeanDeltaHybridVsV", "MeanDeltaHybridVsA", ...
            "PValueFusionHolm", "FusionSupported"], ...
        "RightVariables", ["ValidRuns", "SuccessRunsV", ...
            "SuccessRunsA", "MeanUniqueTPRateV", ...
            "MeanUniqueTPRateA", "PValueUniqueHolm", ...
            "UniqueSupported"]);
    decisions.ComplementaritySupported = decisions.FusionSupported & ...
        decisions.UniqueSupported & decisions.MeanDeltaHybridVsV > 0 & ...
        decisions.MeanDeltaHybridVsA > 0 & ...
        decisions.MeanUniqueTPRateV > 0 & ...
        decisions.MeanUniqueTPRateA > 0;
    decisions.ScientificStatus = repmat("NOT_SUPPORTED", ...
        height(decisions), 1);
    decisions.ScientificStatus( ...
        decisions.ComplementaritySupported) = "SUPPORTED";
end

function coverage = buildCoverage(jobs, replay)
    jobTable = struct2table(jobs);
    configurations = unique(jobTable(:, ["Problem", "M"]), ...
        "rows", "stable");
    rows = repmat(struct("Problem", "", "M", NaN, ...
        "ExpectedRuns", NaN, "ObservedFiles", NaN, "ValidRuns", NaN, ...
        "MissingRuns", "", "Complete", false), ...
        height(configurations), 1);
    for index = 1:height(configurations)
        problem = configurations.Problem(index);
        objectiveCount = configurations.M(index);
        expected = sort(jobTable.Run(jobTable.Problem == problem & ...
            jobTable.M == objectiveCount)).';
        observedRows = replay(replay.Problem == problem & ...
            replay.M == objectiveCount, :);
        validRows = observedRows(observedRows.ValidFile & ...
            observedRows.EquivalencePass, :);
        validRuns = sort(validRows.Run).';
        missing = setdiff(expected, validRuns);
        rows(index) = struct("Problem", problem, "M", objectiveCount, ...
            "ExpectedRuns", numel(expected), ...
            "ObservedFiles", height(observedRows), ...
            "ValidRuns", numel(validRuns), ...
            "MissingRuns", strjoin(string(missing), ";"), ...
            "Complete", isempty(missing));
    end
    coverage = struct2table(rows);
end

function figurePaths = makeFigures(fusion, uniqueTests, decisions, directory)
    figurePaths = struct("PrimaryDelta", "", "UniqueRates", "");
    if isempty(fusion) || isempty(uniqueTests)
        return;
    end
    configurations = unique(fusion(:, ["Problem", "M"]), ...
        "rows", "stable");
    stages = unique(fusion.Stage, "stable");
    delta = mapCellMatrix(fusion, configurations, stages, ...
        "MeanDeltaVsRunwiseBest");
    supported = mapDecisionMatrix(decisions, configurations, stages);
    labels = configurations.Problem + "_M" + string(configurations.M);

    primaryPath = fullfile(directory, ...
        "DPC_01_primary_delta_vs_best.png");
    figureHandle = figure("Visible", "off", "Color", "w", ...
        "Position", [100, 100, 1100, 650]);
    figureCleanup = onCleanup(@() close(figureHandle));
    axesHandle = axes(figureHandle);
    imagesc(axesHandle, delta);
    colorLimit = max(abs(delta), [], "all", "omitnan");
    if isempty(colorLimit) || ~isfinite(colorLimit) || colorLimit == 0
        colorLimit = 1;
    end
    clim(axesHandle, [-colorLimit, colorLimit]);
    colormap(axesHandle, redWhiteBlueMap(256));
    colorbar(axesHandle);
    axesHandle.XTick = 1:numel(stages);
    axesHandle.XTickLabel = stages;
    axesHandle.YTick = 1:height(configurations);
    axesHandle.YTickLabel = labels;
    xlabel(axesHandle, "FE stage");
    ylabel(axesHandle, "Problem configuration");
    title(axesHandle, ...
        "Hybrid Precision@25% minus run-wise best single view");
    hold(axesHandle, "on");
    [supportRows, supportColumns] = find(supported);
    plot(axesHandle, supportColumns, supportRows, "kp", ...
        "MarkerFaceColor", "y", "MarkerSize", 10);
    exportgraphics(figureHandle, primaryPath, "Resolution", 300);
    figurePaths.PrimaryDelta = string(primaryPath);

    uniquePath = fullfile(directory, ...
        "DPC_02_unique_true_positive_run_rates.png");
    figureHandle2 = figure("Visible", "off", "Color", "w", ...
        "Position", [100, 100, 1400, 650]);
    figureCleanup2 = onCleanup(@() close(figureHandle2));
    layout = tiledlayout(figureHandle2, 1, 2, ...
        "TileSpacing", "compact", "Padding", "compact");
    vRates = mapCellMatrix(uniqueTests, configurations, stages, "SuccessRateV");
    aRates = mapCellMatrix(uniqueTests, configurations, stages, "SuccessRateA");
    drawRateHeatmap(nexttile(layout), vRates, stages, labels, ...
        "V-only true positives: fraction of runs");
    drawRateHeatmap(nexttile(layout), aRates, stages, labels, ...
        "Anchor-only true positives: fraction of runs");
    exportgraphics(figureHandle2, uniquePath, "Resolution", 300);
    figurePaths.UniqueRates = string(uniquePath);
end

function drawRateHeatmap(axesHandle, values, stages, labels, titleText)
    imagesc(axesHandle, values, [0, 1]);
    colormap(axesHandle, parula(256));
    colorbar(axesHandle);
    axesHandle.XTick = 1:numel(stages);
    axesHandle.XTickLabel = stages;
    axesHandle.YTick = 1:numel(labels);
    axesHandle.YTickLabel = labels;
    xlabel(axesHandle, "FE stage");
    title(axesHandle, titleText);
end

function values = mapCellMatrix(data, configurations, stages, variable)
    values = NaN(height(configurations), numel(stages));
    for configIndex = 1:height(configurations)
        for stageIndex = 1:numel(stages)
            member = data.Problem == configurations.Problem(configIndex) & ...
                data.M == configurations.M(configIndex) & ...
                data.Stage == stages(stageIndex);
            if nnz(member) == 1
                values(configIndex, stageIndex) = data.(variable)(member);
            end
        end
    end
end

function values = mapDecisionMatrix(data, configurations, stages)
    values = false(height(configurations), numel(stages));
    if isempty(data)
        return;
    end
    for configIndex = 1:height(configurations)
        for stageIndex = 1:numel(stages)
            member = data.Problem == configurations.Problem(configIndex) & ...
                data.M == configurations.M(configIndex) & ...
                data.Stage == stages(stageIndex);
            if nnz(member) == 1
                values(configIndex, stageIndex) = ...
                    data.ComplementaritySupported(member);
            end
        end
    end
end

function map = redWhiteBlueMap(numberOfColors)
    half = floor(numberOfColors/2);
    lower = [linspace(0, 1, half).', linspace(0.2, 1, half).', ...
        ones(half, 1)];
    upperCount = numberOfColors - half;
    upper = [ones(upperCount, 1), ...
        linspace(1, 0.2, upperCount).', ...
        linspace(1, 0, upperCount).'];
    map = [lower; upper];
end

function writeSummary(filePath, profile, gate, decisions, paths)
    supportedCount = 0;
    if ~isempty(decisions)
        supportedCount = nnz(decisions.ComplementaritySupported);
    end
    lines = [ ...
        "# Dual-PBI Complementarity Result Summary", ...
        "", ...
        "- Profile: " + profile, ...
        "- Final integrity gate: " + gate.Status, ...
        "- Complete replay runs: " + string(gate.ValidReplayRuns) + ...
            "/" + string(gate.ExpectedRuns), ...
        "- Primary cells supporting complementarity: " + ...
            string(supportedCount) + "/" + string(gate.DecisionCells), ...
        "", ...
        "The final gate measures completeness and replay equivalence, not " + ...
            "whether the scientific effect is favorable.", ...
        "", ...
        "The scientific evidence remains on-policy predictive association. " + ...
            "It is not a causal IGD/HV ablation.", ...
        "", ...
        "## Tables", ...
        "", ...
        "- " + string(paths.Decisions), ...
        "- " + string(paths.FusionTests), ...
        "- " + string(paths.UniqueTests), ...
        "- " + string(paths.FinalGate)];
    writeTextAtomic(lines, filePath);
end

function writeTableAtomic(dataTable, outputPath)
    temporaryPath = [tempname(fileparts(outputPath)), '.csv'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryPath));
    writetable(dataTable, temporaryPath);
    [moved, message] = movefile(temporaryPath, outputPath, "f");
    if ~moved
        error("DPC:AnalysisWriteFailure", ...
            "Could not write %s: %s", outputPath, message);
    end
end

function writeTextAtomic(lines, outputPath)
    temporaryPath = [tempname(fileparts(outputPath)), '.md'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryPath));
    fileID = fopen(temporaryPath, "w", "n", "UTF-8");
    if fileID < 0
        error("DPC:SummaryOpenFailure", ...
            "Could not open the temporary summary file.");
    end
    fileCleanup = onCleanup(@() fclose(fileID));
    fprintf(fileID, "%s\n", lines);
    clear fileCleanup;
    [moved, message] = movefile(temporaryPath, outputPath, "f");
    if ~moved
        error("DPC:SummaryWriteFailure", ...
            "Could not write %s: %s", outputPath, message);
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

function value = resolvePathOption(value, defaultValue)
    if strlength(value) == 0
        value = string(defaultValue);
    end
    value = char(value);
end

function row = makeReplayRow()
    row = struct("Profile", "", "Problem", "", "M", NaN, ...
        "Run", NaN, "Seed", NaN, "File", "", "ValidFile", false, ...
        "EquivalencePass", false, "CompletedFEMatch", false, ...
        "FinalPopulationMatch", false, "IGDMatch", false, ...
        "IGDpMatch", false, "MaxPopulationAbsDiff", NaN, ...
        "IGDAbsDiff", NaN, "IGDpAbsDiff", NaN, ...
        "ValidationDetail", "");
end

function data = emptyPerRunStage()
    data = table(string.empty(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), string.empty(0,1), string.empty(0,1), ...
        string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'Problem','M','Run','Seed','Stage','Truth', ...
        'TruthType','Horizon','NumberOfSnapshots','ValidTruthSnapshots'});
end

function deleteIfPresent(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end
