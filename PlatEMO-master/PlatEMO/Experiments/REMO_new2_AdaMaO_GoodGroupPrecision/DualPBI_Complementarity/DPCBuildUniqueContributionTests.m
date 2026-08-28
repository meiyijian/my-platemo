function tests = DPCBuildUniqueContributionTests(perRunStage)
%DPCBuildUniqueContributionTests - Test bidirectional unique true positives
%   TESTS = DPCBuildUniqueContributionTests(T) tests whether V-only and
%   A-only future true positives each occur in more than half of paired
%   independent runs, then applies an intersection-union test and Holm
%   correction across all primary cells.
%
%   See also DPCBuildStrictFusionTests, GGPHolmAdjust

    arguments
        perRunStage table
    end

    if isempty(perRunStage)
        tests = struct2table(makeEmptyRow());
        tests = tests([], :);
        tests.PValueUniqueHolm = zeros(0, 1);
        tests.UniqueSupported = false(0, 1);
        return;
    end
    required = ["Problem", "M", "Run", "Seed", "Stage", "Truth", ...
        "MeanTPVOnly", "MeanTPAOnly", "MeanUniqueTPRateV", ...
        "MeanUniqueTPRateA", "MeanUniquePrecisionV", ...
        "MeanUniquePrecisionA"];
    requireColumns(perRunStage, required);
    primary = perRunStage(perRunStage.Truth == "population_final", :);
    configurations = unique(primary(:, ["Problem", "M"]), ...
        "rows", "stable");
    rows = repmat(makeEmptyRow(), 0, 1);

    for configIndex = 1:height(configurations)
        problem = configurations.Problem(configIndex);
        objectiveCount = configurations.M(configIndex);
        configRows = primary(primary.Problem == problem & ...
            primary.M == objectiveCount, :);
        stages = unique(configRows.Stage, "stable");
        for stage = stages.'
            stageRows = configRows(configRows.Stage == stage, :);
            rows(end + 1, 1) = testCell(stageRows, problem, ...
                objectiveCount, stage); %#ok<AGROW>
        end
    end

    tests = struct2table(rows);
    if isempty(tests)
        return;
    end
    tests.PValueUniqueHolm = GGPHolmAdjust(tests.PValueUniqueRaw);
    tests.UniqueSupported = tests.PValueUniqueHolm <= 0.05 & ...
        tests.SuccessRunsV > tests.ValidRuns/2 & ...
        tests.SuccessRunsA > tests.ValidRuns/2;
end

function row = testCell(stageRows, problem, objectiveCount, stage)
    if height(stageRows) ~= numel(unique(stageRows.Run))
        error("DPC:DuplicateRunStage", ...
            "Run-stage rows are not unique for %s M%d %s.", ...
            problem, objectiveCount, stage);
    end
    valid = isfinite(stageRows.MeanTPVOnly) & ...
        isfinite(stageRows.MeanTPAOnly);
    rows = stageRows(valid, :);
    numberOfRuns = height(rows);
    successRunsV = nnz(rows.MeanTPVOnly > 0);
    successRunsA = nnz(rows.MeanTPAOnly > 0);
    pValueV = exactMajorityPValue(successRunsV, numberOfRuns);
    pValueA = exactMajorityPValue(successRunsA, numberOfRuns);
    [rateV, ciV] = exactBinomialInterval(successRunsV, numberOfRuns);
    [rateA, ciA] = exactBinomialInterval(successRunsA, numberOfRuns);

    row = makeEmptyRow();
    row.Problem = problem;
    row.M = objectiveCount;
    row.Stage = stage;
    row.AvailableRuns = height(stageRows);
    row.ValidRuns = numberOfRuns;
    row.SuccessRunsV = successRunsV;
    row.SuccessRunsA = successRunsA;
    row.SuccessRateV = rateV;
    row.SuccessRateA = rateA;
    row.SuccessRateVCILower = ciV(1);
    row.SuccessRateVCIUpper = ciV(2);
    row.SuccessRateACILower = ciA(1);
    row.SuccessRateACIUpper = ciA(2);
    row.PValueVOnlyMajority = pValueV;
    row.PValueAOnlyMajority = pValueA;
    row.PValueUniqueRaw = max(pValueV, pValueA);
    row.MeanUniqueTPRateV = meanFinite(rows.MeanUniqueTPRateV);
    row.MeanUniqueTPRateA = meanFinite(rows.MeanUniqueTPRateA);
    row.MedianUniqueTPRateV = medianFinite(rows.MeanUniqueTPRateV);
    row.MedianUniqueTPRateA = medianFinite(rows.MeanUniqueTPRateA);
    row.MeanUniquePrecisionV = meanFinite(rows.MeanUniquePrecisionV);
    row.MeanUniquePrecisionA = meanFinite(rows.MeanUniquePrecisionA);
end

function value = exactMajorityPValue(successes, trials)
    if trials == 0
        value = NaN;
    elseif successes == 0
        value = 1;
    else
        value = binocdf(successes - 1, trials, 0.5, "upper");
    end
end

function [rate, interval] = exactBinomialInterval(successes, trials)
    if trials == 0
        rate = NaN;
        interval = [NaN, NaN];
    else
        [rate, interval] = binofit(successes, trials, 0.05);
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
        "ValidRuns", NaN, ...
        "SuccessRunsV", NaN, ...
        "SuccessRunsA", NaN, ...
        "SuccessRateV", NaN, ...
        "SuccessRateA", NaN, ...
        "SuccessRateVCILower", NaN, ...
        "SuccessRateVCIUpper", NaN, ...
        "SuccessRateACILower", NaN, ...
        "SuccessRateACIUpper", NaN, ...
        "PValueVOnlyMajority", NaN, ...
        "PValueAOnlyMajority", NaN, ...
        "PValueUniqueRaw", NaN, ...
        "MeanUniqueTPRateV", NaN, ...
        "MeanUniqueTPRateA", NaN, ...
        "MedianUniqueTPRateV", NaN, ...
        "MedianUniqueTPRateA", NaN, ...
        "MeanUniquePrecisionV", NaN, ...
        "MeanUniquePrecisionA", NaN);
end
