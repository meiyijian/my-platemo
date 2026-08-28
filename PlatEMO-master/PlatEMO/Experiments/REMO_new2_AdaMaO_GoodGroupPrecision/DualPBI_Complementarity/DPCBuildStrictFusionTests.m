function tests = DPCBuildStrictFusionTests(perRunStage, options)
%DPCBuildStrictFusionTests - Test Hybrid against both single views
%   TESTS = DPCBuildStrictFusionTests(T) performs paired one-sided
%   Wilcoxon tests for population_final Precision@25% and combines the
%   component tests with an intersection-union test.
%
%   TESTS = DPCBuildStrictFusionTests(T,BootstrapSamples=N) specifies the
%   number of deterministic paired bootstrap samples.
%
%   TESTS = DPCBuildStrictFusionTests(T,...,BootstrapSeed=SEED) also
%   specifies the local bootstrap seed without changing the caller RNG.
%
%   See also DPCBuildUniqueContributionTests, GGPComparePaired,
%   GGPHolmAdjust

    arguments
        perRunStage table
        options.BootstrapSamples (1,1) double ...
            {mustBeInteger,mustBePositive} = 10000
        options.BootstrapSeed (1,1) double ...
            {mustBeInteger,mustBeNonnegative} = 20260819
    end

    required = ["Problem", "M", "Run", "Seed", "Stage", "View", ...
        "SelectionRule", "Truth", "MeanPrecision"];
    requireColumns(perRunStage, required);
    primary = perRunStage( ...
        perRunStage.SelectionRule == "top25" & ...
        perRunStage.Truth == "population_final", :);
    configurations = unique(primary(:, ["Problem", "M"]), ...
        "rows", "stable");
    rows = repmat(makeEmptyRow(), 0, 1);

    rowIndex = 0;
    for configIndex = 1:height(configurations)
        problem = configurations.Problem(configIndex);
        objectiveCount = configurations.M(configIndex);
        configRows = primary(primary.Problem == problem & ...
            primary.M == objectiveCount, :);
        stages = unique(configRows.Stage, "stable");
        for stage = stages.'
            rowIndex = rowIndex + 1;
            stageRows = configRows(configRows.Stage == stage, :);
            rows(end + 1, 1) = compareCell(stageRows, problem, ...
                objectiveCount, stage, options.BootstrapSamples, ...
                options.BootstrapSeed + rowIndex); %#ok<AGROW>
        end
    end

    if isempty(rows)
        tests = struct2table(makeEmptyRow());
        tests = tests([], :);
    else
        tests = struct2table(rows);
    end
    if isempty(tests)
        tests.PValueFusionHolm = zeros(0, 1);
        tests.FusionSupported = false(0, 1);
        return;
    end
    tests.PValueFusionHolm = GGPHolmAdjust(tests.PValueFusionRaw);
    tests.FusionSupported = tests.PValueFusionHolm <= 0.05 & ...
        tests.MeanDeltaHybridVsV > 0 & tests.MeanDeltaHybridVsA > 0;
end

function row = compareCell(stageRows, problem, objectiveCount, stage, ...
        bootstrapSamples, bootstrapSeed)
    hybridRows = stageRows(stageRows.View == "score_hybrid", :);
    vRows = stageRows(stageRows.View == "score_v", :);
    aRows = stageRows(stageRows.View == "anchor_margin", :);
    assertUniqueViewRuns(hybridRows, "score_hybrid");
    assertUniqueViewRuns(vRows, "score_v");
    assertUniqueViewRuns(aRows, "anchor_margin");

    commonRuns = intersect(intersect(hybridRows.Run, vRows.Run), aRows.Run);
    [foundH, indexH] = ismember(commonRuns, hybridRows.Run);
    [foundV, indexV] = ismember(commonRuns, vRows.Run);
    [foundA, indexA] = ismember(commonRuns, aRows.Run);
    if ~all(foundH & foundV & foundA)
        error("DPC:RunPairingFailure", ...
            "Three-view run pairing failed for %s M%d %s.", ...
            problem, objectiveCount, stage);
    end
    seedsH = hybridRows.Seed(indexH);
    seedsV = vRows.Seed(indexV);
    seedsA = aRows.Seed(indexA);
    if any(seedsH ~= seedsV | seedsH ~= seedsA)
        error("DPC:SeedPairingFailure", ...
            "Three-view seeds differ for %s M%d %s.", ...
            problem, objectiveCount, stage);
    end

    hybrid = hybridRows.MeanPrecision(indexH);
    vScore = vRows.MeanPrecision(indexV);
    anchor = aRows.MeanPrecision(indexA);
    valid = isfinite(hybrid) & isfinite(vScore) & isfinite(anchor);
    hybrid = hybrid(valid);
    vScore = vScore(valid);
    anchor = anchor(valid);

    comparisonV = GGPComparePaired(hybrid, vScore);
    comparisonA = GGPComparePaired(hybrid, anchor);
    pValueV = signrankRight(hybrid, vScore);
    pValueA = signrankRight(hybrid, anchor);
    deltaBest = hybrid - max(vScore, anchor);
    [ciLower, ciUpper] = bootstrapMeanCI( ...
        deltaBest, bootstrapSamples, bootstrapSeed);

    row = makeEmptyRow();
    row.Problem = problem;
    row.M = objectiveCount;
    row.Stage = stage;
    row.AvailableRuns = numel(commonRuns);
    row.ValidPairs = numel(hybrid);
    row.MeanHybrid = meanFinite(hybrid);
    row.MeanV = meanFinite(vScore);
    row.MeanA = meanFinite(anchor);
    row.MeanDeltaHybridVsV = comparisonV.MeanDelta;
    row.MedianDeltaHybridVsV = comparisonV.MedianDelta;
    row.MeanDeltaHybridVsA = comparisonA.MeanDelta;
    row.MedianDeltaHybridVsA = comparisonA.MedianDelta;
    row.PValueHybridVsV = pValueV;
    row.PValueHybridVsA = pValueA;
    row.PValueFusionRaw = max(pValueV, pValueA);
    row.WinProbabilityHybridVsV = comparisonV.PairedWinProbability;
    row.WinProbabilityHybridVsA = comparisonA.PairedWinProbability;
    row.RankBiserialHybridVsV = comparisonV.RankBiserial;
    row.RankBiserialHybridVsA = comparisonA.RankBiserial;
    row.MeanDeltaVsRunwiseBest = meanFinite(deltaBest);
    row.MedianDeltaVsRunwiseBest = medianFinite(deltaBest);
    row.MeanDeltaVsBestCILower = ciLower;
    row.MeanDeltaVsBestCIUpper = ciUpper;
end

function value = signrankRight(first, second)
    difference = first(:) - second(:);
    valid = isfinite(difference);
    first = first(valid);
    second = second(valid);
    difference = difference(valid);
    if numel(difference) < 2
        value = NaN;
    elseif all(difference == 0)
        value = 1;
    else
        value = signrank(first, second, "tail", "right");
    end
end

function [lower, upper] = bootstrapMeanCI(values, sampleCount, seed)
    values = values(isfinite(values));
    if isempty(values)
        lower = NaN;
        upper = NaN;
        return;
    end
    stream = RandStream("mt19937ar", "Seed", seed);
    indices = randi(stream, numel(values), ...
        numel(values), sampleCount);
    bootstrapMeans = mean(values(indices), 1);
    limits = prctile(bootstrapMeans, [2.5, 97.5]);
    lower = limits(1);
    upper = limits(2);
end

function assertUniqueViewRuns(rows, view)
    if height(rows) ~= numel(unique(rows.Run))
        error("DPC:DuplicateViewRun", ...
            "View %s contains duplicate run rows within one cell.", view);
    end
end

function requireColumns(data, required)
    if ~all(ismember(required, string(data.Properties.VariableNames)))
        missing = required(~ismember(required, ...
            string(data.Properties.VariableNames)));
        error("DPC:MissingColumns", ...
            "Input table is missing columns: %s", strjoin(missing, ", "));
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

function value = medianFinite(values)
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = median(values);
    end
end

function row = makeEmptyRow()
    row = struct( ...
        "Problem", "", ...
        "M", NaN, ...
        "Stage", "", ...
        "AvailableRuns", NaN, ...
        "ValidPairs", NaN, ...
        "MeanHybrid", NaN, ...
        "MeanV", NaN, ...
        "MeanA", NaN, ...
        "MeanDeltaHybridVsV", NaN, ...
        "MedianDeltaHybridVsV", NaN, ...
        "MeanDeltaHybridVsA", NaN, ...
        "MedianDeltaHybridVsA", NaN, ...
        "PValueHybridVsV", NaN, ...
        "PValueHybridVsA", NaN, ...
        "PValueFusionRaw", NaN, ...
        "WinProbabilityHybridVsV", NaN, ...
        "WinProbabilityHybridVsA", NaN, ...
        "RankBiserialHybridVsV", NaN, ...
        "RankBiserialHybridVsA", NaN, ...
        "MeanDeltaVsRunwiseBest", NaN, ...
        "MedianDeltaVsRunwiseBest", NaN, ...
        "MeanDeltaVsBestCILower", NaN, ...
        "MeanDeltaVsBestCIUpper", NaN);
end
