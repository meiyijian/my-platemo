function outputs = compare_LTGGP_vs_PWGGP(varargin)
%COMPARE_LTGGP_VSPWGGP Paired lambda_t = 0.30 vs 0.50 cross-arm comparison.
%   The LTGGP formal protocol shares problem indices and the seed formula
%   with PWGGP, so for every shared problem-M-run the two arms form an
%   exactly seed-matched pair. This script loads both experiments' formal
%   raw MATs, checks seed identity, and reports:
%     1) final IGD (lower is better)
%     2) MeanPrecision of the score_hybrid view against population_final,
%        front_final and population_h1 truths (higher is better)
%   Results are written to <LTGGP>/results/analysis/crossArm/.
%
%   Name-value options:
%     Problems - shared problems to compare (default: those with PWGGP
%                data among the LTGGP selection, i.e. DTLZ2 and DTLZ4)
%     PWGGPRoot- the PWGGP experiment directory (default: sibling folder)
%
%   Caveat printed with the table: the two arms ran in different sessions,
%   so cross-arm contrasts carry session context noise in addition to the
%   lambda_t effect; treat them as confirmatory, not as the primary claim.

    parser = inputParser();
    parser.FunctionName = mfilename();
    addParameter(parser, "Problems", ["DTLZ2", "DTLZ4"], @isTextCollection);
    addParameter(parser, "PWGGPRoot", "", @isTextScalar);
    parse(parser, varargin{:});
    problems = unique(string(parser.Results.Problems), "stable");

    [info, cleanup] = LTGGPSetupPaths(); %#ok<ASGLU>
    ltggpRoot = fullfile(info.ExperimentDirectory, "results");
    if strlength(string(parser.Results.PWGGPRoot)) == 0
        pwggpRoot = fullfile(fileparts(info.ExperimentDirectory), ...
            "REMO_new2_AdaMaO_PrunedWeighted_GoodGroupPrecision", "results");
    else
        pwggpRoot = char(string(parser.Results.PWGGPRoot));
    end

    rows = [];
    for problem = problems
        for objectiveCount = [10, 20]
            ltggpTable = loadRunTable(ltggpRoot, problem, objectiveCount, "LTGGPAudit");
            pwggpTable = loadRunTable(pwggpRoot, problem, objectiveCount, "PWGGPAudit");
            if isempty(ltggpTable) || isempty(pwggpTable)
                warning("LTGGP:MissingArmData", ...
                    "%s M%d: LTGGP has %d runs, PWGGP has %d runs; skipped.", ...
                    problem, objectiveCount, height(ltggpTable), height(pwggpTable));
                continue;
            end
            [~, iA, iB] = intersect(ltggpTable.Run, pwggpTable.Run, "stable");
            if ~isequal(ltggpTable.Seed(iA), pwggpTable.Seed(iB))
                error("LTGGP:SeedMismatch", ...
                    "%s M%d: paired runs do not share seeds across arms.", ...
                    problem, objectiveCount);
            end
            rows = [rows; buildRows(problem, objectiveCount, ...
                ltggpTable(iA,:), pwggpTable(iB,:))]; %#ok<AGROW>
        end
    end
    if isempty(rows)
        error("LTGGP:NoSharedData", "No problem-M configuration had data in both arms.");
    end

    comparisons = struct2table(rows);
    outDirectory = fullfile(ltggpRoot, "analysis", "crossArm");
    if ~isfolder(outDirectory), mkdir(outDirectory); end
    outPath = fullfile(outDirectory, "LTGGP_vs_PWGGP_Paired.csv");
    writeTableAtomic(comparisons, outPath);

    outputs = struct("Paths", struct("PairedComparisons", outPath), ...
        "Comparisons", comparisons);
    disp(comparisons);
    fprintf(['Cross-arm caveat: arms ran in different sessions; seed-matched ' ...
        'but not same-session. Confirmatory only.\nWrote %s\n'], outPath);
end

function runTable = loadRunTable(resultRoot, problem, objectiveCount, expectedClass)
    rawDirectory = fullfile(resultRoot, "raw", "formal", problem, ...
        sprintf("M%d", objectiveCount));
    files = dir(fullfile(rawDirectory, "run_*.mat"));
    rowCells = cell(1, numel(files));
    for fileIndex = 1:numel(files)
        filePath = fullfile(files(fileIndex).folder, files(fileIndex).name);
        data = load(filePath, "metadata", "checkpointMetrics", "IGD");
        if string(data.metadata.AlgorithmClass) ~= string(expectedClass)
            error("LTGGP:UnexpectedClass", ...
                "%s was produced by %s, expected %s.", ...
                filePath, data.metadata.AlgorithmClass, expectedClass);
        end
        rowCells{fileIndex} = struct( ...
            "Run", data.metadata.Run, ...
            "Seed", data.metadata.Seed, ...
            "IGD", data.IGD, ...
            "Metrics", {data.checkpointMetrics});
    end
    if isempty(rowCells)
        runTable = table();
    else
        runTable = sortrows(struct2table([rowCells{:}]), "Run");
    end
end

function newRows = buildRows(problem, objectiveCount, armA, armB)
%   armA = LTGGP (lambda 0.30), armB = PWGGP (lambda 0.50).
    rowCells = {};
    % --- IGD (lower is better) ---
    rowCells{end+1} = packRow(problem, objectiveCount, "IGD", ...
        "-", "-", armA.IGD, armB.IGD, false);

    % --- Precision views (higher is better) ---
    viewNames = ["score_hybrid", "score_v", "anchor_margin"];
    truthNames = ["population_final", "front_final", "population_h1"];
    for viewName = viewNames
        for truthName = truthNames
            valuesA = perRunViewPrecision(armA.Metrics, viewName, truthName);
            valuesB = perRunViewPrecision(armB.Metrics, viewName, truthName);
            if numel(valuesA) ~= height(armA) || numel(valuesB) ~= height(armB)
                error("LTGGP:ViewAggregationMismatch", ...
                    "Could not aggregate %s/%s for %s M%d.", ...
                    viewName, truthName, problem, objectiveCount);
            end
            rowCells{end+1} = packRow(problem, objectiveCount, ...
                "Precision", viewName, truthName, valuesA, valuesB, ...
                true);
        end
    end
    newRows = vertcat(rowCells{:});
end

function values = perRunViewPrecision(metrics, viewName, truthName)
%PERRUNVIEWPRECISION One mean precision per run for a view-truth pair.
%   METRICS is either one long checkpointMetrics table or a cell column of
%   per-run tables (as stored in the runTable Metrics variable). Rows are
%   aggregated within each run with equal weight per snapshot (matching
%   the LTGGP_PerRunStage convention); the output is ordered by ascending
%   Run to stay paired with the sorted runTable rows.
    if iscell(metrics)
        metrics = vertcat(metrics{:});
    end
    selected = metrics( ...
        string(metrics.View) == string(viewName) & ...
        string(metrics.Truth) == string(truthName), :);
    [groupIndex, runIDs] = findgroups(selected.Run);
    values = splitapply(@meanFinite, selected.Precision, groupIndex);
    if any(~isfinite(values))
        warning("LTGGP:CensoredPrecision", ...
            "%s/%s contains non-finite per-run precision (censored horizon).", ...
            viewName, truthName);
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

function row = packRow(problem, objectiveCount, metricName, ...
        viewName, truthName, valuesA, valuesB, higherIsBetter)
%PACKROW Paired statistics where the directional stats always mean
%   "A (lambda_t = 0.30) better than B (lambda_t = 0.50)", regardless of
%   the raw metric direction. MeanA/MeanB/MeanDelta stay on the raw scale.

    if higherIsBetter
        goodnessA = valuesA; goodnessB = valuesB;
    else
        goodnessA = -valuesA; goodnessB = -valuesB;
    end
    comparison = LTGGPComparePaired(goodnessA, goodnessB);

    finiteA = isfinite(valuesA); finiteB = isfinite(valuesB);
    finiteDelta = valuesA(isfinite(valuesA) & isfinite(valuesB)) - ...
        valuesB(isfinite(valuesA) & isfinite(valuesB));

    row = struct( ...
        "Problem", string(problem), ...
        "M", objectiveCount, ...
        "Metric", string(metricName), ...
        "View", string(viewName), ...
        "Truth", string(truthName), ...
        "ArmA", "lambda030", ...
        "ArmB", "lambda050", ...
        "HigherIsBetter", higherIsBetter, ...
        "ValidPairs", comparison.NumberOfPairs, ...
        "MeanA", mean(valuesA(finiteA)), ...
        "MeanB", mean(valuesB(finiteB)), ...
        "MeanDeltaAminusB", mean(finiteDelta), ...
        "MedianDeltaAminusB", median(finiteDelta), ...
        "MeanRelativeImprovementPct", comparison.MeanRelativeImprovementPct, ...
        "PairedWinProbability", comparison.PairedWinProbability, ...
        "RankBiserial", comparison.RankBiserial, ...
        "PValueRaw", comparison.PValueRaw);
end

function writeTableAtomic(dataTable, outputPath)
    outputDirectory = fileparts(outputPath);
    if ~isfolder(outputDirectory), mkdir(outputDirectory); end
    temporaryPath = [tempname(outputDirectory), '.csv'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryPath));
    writetable(dataTable, temporaryPath);
    [moved, message] = movefile(temporaryPath, outputPath, "f");
    if ~moved
        error("LTGGP:AnalysisWriteFailed", ...
            "Could not write %s: %s", outputPath, message);
    end
end

function deleteIfPresent(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end

function isValid = isTextCollection(value)
    isValid = (isstring(value) && isvector(value)) || ischar(value) || iscellstr(value);
end

function isValid = isTextScalar(value)
    isValid = (isstring(value) && isscalar(value)) || ischar(value);
end
