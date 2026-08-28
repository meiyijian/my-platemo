function report = analyze_CandidateValueProbe(profile, varargin)
%ANALYZE_CANDIDATEVALUEPROBE Aggregate the probe and write every CSV.
%   REPORT = ANALYZE_CANDIDATEVALUEPROBE(PROFILE) reads the per-run MAT files
%   produced by run_CandidateValueProbe and writes seven CSV tables into
%   results/<profile>/csv/ plus a console digest.
%
%   Tables
%     runs.csv            one row per (arm, problem, M, run): both metrics,
%                         final IGD, and every descriptive field
%     arm_summary.csv     one row per (arm, problem, M): mean, std, median
%     arm_overall.csv     one row per arm pooled across problems
%     stage_profile.csv   survival rate by FE quartile, per arm and problem;
%                         this is the table that exposes the archive-growth
%                         confound instead of hiding it
%     generations.csv     the full per-generation trace, for plots
%     contrasts.csv       paired Wilcoxon signed-rank contrasts vs V1 and V0
%                         with Holm correction, on both metrics
%     diagnostics.csv     integrity checks that must be read before the rest
%
%   Name-value options
%     ResultRoot  alternate result directory
%     Quiet       suppress the console digest (default false)

    if nargin < 1 || isempty(profile)
        profile = "formal";
    end
    profile = validatestring(string(profile), ["smoke", "pilot", "formal"]);

    [pathInfo, pathCleanup] = CVPSetupPaths(); %#ok<ASGLU>
    defaultResultRoot = fullfile(pathInfo.ExperimentDirectory, "results");

    parser = inputParser();
    parser.FunctionName = mfilename();
    addParameter(parser, "ResultRoot", defaultResultRoot, @(v) ...
        (isstring(v) && isscalar(v)) || ischar(v));
    addParameter(parser, "Quiet", false, @(v) islogical(v) && isscalar(v));
    parse(parser, varargin{:});
    resultRoot = char(string(parser.Results.ResultRoot));
    quiet = parser.Results.Quiet;

    config = CVPProtocol(profile);
    catalog = config.Arms;

    %% ---------------- load ----------------
    [runRows, generationRows, missing] = loadRuns(resultRoot, profile, config);
    if isempty(runRows)
        error("CVP:NoResults", ...
            ["No result files were found under %s for profile %s. " ...
            "Run run_CandidateValueProbe(""%s"") first."], ...
            resultRoot, profile, profile);
    end
    runTable = struct2table(runRows);
    generationTable = struct2table(generationRows);

    csvDirectory = fullfile(resultRoot, char(profile), "csv");
    if ~isfolder(csvDirectory)
        mkdir(csvDirectory);
    end

    %% ---------------- per-arm aggregates ----------------
    armSummary = summarizeByArm(runTable, catalog);
    armOverall = summarizeOverall(runTable, catalog);
    stageProfile = summarizeStages(runTable, catalog);

    %% ---------------- paired contrasts ----------------
    contrasts = buildContrasts(runTable, catalog);

    %% ---------------- diagnostics ----------------
    diagnostics = buildDiagnostics(runTable, generationTable, config, missing);

    %% ---------------- write ----------------
    writeCsv(runTable, fullfile(csvDirectory, "runs.csv"));
    writeCsv(armSummary, fullfile(csvDirectory, "arm_summary.csv"));
    writeCsv(armOverall, fullfile(csvDirectory, "arm_overall.csv"));
    writeCsv(stageProfile, fullfile(csvDirectory, "stage_profile.csv"));
    writeCsv(generationTable, fullfile(csvDirectory, "generations.csv"));
    writeCsv(contrasts, fullfile(csvDirectory, "contrasts.csv"));
    writeCsv(diagnostics, fullfile(csvDirectory, "diagnostics.csv"));

    report = struct( ...
        "Profile", profile, ...
        "Runs", runTable, ...
        "ArmSummary", armSummary, ...
        "ArmOverall", armOverall, ...
        "StageProfile", stageProfile, ...
        "Contrasts", contrasts, ...
        "Diagnostics", diagnostics, ...
        "Generations", generationTable, ...
        "MissingJobs", missing, ...
        "CsvDirectory", string(csvDirectory));

    if ~quiet
        printDigest(report, config);
    end
end

%% ============================ loading ============================
function [runRows, generationRows, missing] = loadRuns(resultRoot, profile, config)
    jobs = config.Jobs;
    runRows = repmat(emptyRunRow(), 0, 1);
    generationRows = repmat(emptyGenerationRow(), 0, 1);
    missing = strings(0, 1);

    for jobIndex = 1:numel(jobs)
        job = jobs(jobIndex);
        filePath = CVPResultPath(resultRoot, profile, job);
        if ~isfile(filePath)
            missing(end+1, 1) = string(filePath); %#ok<AGROW>
            continue;
        end
        [isValid, validationReport] = CVPValidateRunFile(filePath, profile);
        if ~isValid
            error("CVP:InvalidResultDuringAnalysis", ...
                "Refusing to analyse an invalid result: %s (%s)", ...
                filePath, validationReport.Detail);
        end
        stored = load(filePath, "metadata", "generations", "summary", "IGD", "IGDp");

        row = emptyRunRow();
        row.Arm = string(stored.metadata.Arm);
        row.ArmID = stored.metadata.ArmID;
        row.Problem = string(stored.metadata.Problem);
        row.Family = string(stored.metadata.Family);
        row.M = stored.metadata.M;
        row.ActualD = stored.metadata.ActualD;
        row.Run = stored.metadata.Run;
        row.Seed = stored.metadata.Seed;
        row.PairedKey = string(stored.metadata.PairedKey);
        row.MaxFE = stored.metadata.MaxFE;
        row.CompletedFE = stored.metadata.CompletedFE;
        row.IGD = stored.IGD;
        row.IGDp = stored.IGDp;
        summaryFields = fieldnames(stored.summary);
        for fieldIndex = 1:numel(summaryFields)
            row.(summaryFields{fieldIndex}) = stored.summary.(summaryFields{fieldIndex});
        end
        runRows(end+1, 1) = row; %#ok<AGROW>

        generations = stored.generations;
        for generationIndex = 1:numel(generations)
            generationRow = emptyGenerationRow();
            generationRow.Arm = row.Arm;
            generationRow.ArmID = row.ArmID;
            generationRow.Problem = row.Problem;
            generationRow.M = row.M;
            generationRow.Run = row.Run;
            generationRow.PairedKey = row.PairedKey;
            source = generations(generationIndex);
            sourceFields = fieldnames(source);
            for fieldIndex = 1:numel(sourceFields)
                name = sourceFields{fieldIndex};
                if isfield(generationRow, name)
                    generationRow.(name) = source.(name);
                end
            end
            generationRows(end+1, 1) = generationRow; %#ok<AGROW>
        end
    end
end

function row = emptyRunRow()
    row = struct( ...
        'Arm', "", 'ArmID', NaN, 'Problem', "", 'Family', "", 'M', NaN, ...
        'ActualD', NaN, 'Run', NaN, 'Seed', NaN, 'PairedKey', "", ...
        'MaxFE', NaN, 'CompletedFE', NaN, 'IGD', NaN, 'IGDp', NaN);
    template = CVPSummarizeRun(repmat(CVPEmptyGenerationRowsProxy(), 0, 1), 0.5);
    names = fieldnames(template);
    for index = 1:numel(names)
        row.(names{index}) = template.(names{index});
    end
end

function row = emptyGenerationRow()
    row = struct('Arm', "", 'ArmID', NaN, 'Problem', "", 'M', NaN, ...
        'Run', NaN, 'PairedKey', "");
    template = CVPEmptyGenerationRowsProxy();
    names = fieldnames(template);
    for index = 1:numel(names)
        row.(names{index}) = template.(names{index});
    end
end

function template = CVPEmptyGenerationRowsProxy()
% The generation-row schema lives in algorithms/private so the algorithm can
% see it. Analysis code cannot call into that private folder, so the schema
% is mirrored here through one shipped result-independent constructor.
    template = struct( ...
        'Generation', NaN, 'FEBefore', NaN, 'FEAfter', NaN, 'Ratio', NaN, ...
        'KEff', NaN, 'BatchSize', NaN, 'ArchiveSizeBefore', NaN, ...
        'ArchiveSizeAfter', NaN, 'PopulationSize', NaN, 'ArchiveOverN', NaN, ...
        'SurvivorCount', NaN, 'SurvivalRate', NaN, 'UsedFallback', false, ...
        'TruncatedBatch', false, 'Mode', "", 'AttemptedMode', "", ...
        'PoolUniqueCount', NaN, 'PoolRawCount', NaN, ...
        'LastRoundUniqueCount', NaN, 'RoundCount', NaN, 'RetainedCount', NaN, ...
        'SelectedK', NaN, 'PErr', NaN, 'LambdaT', NaN, ...
        'IndicatorAvailable', false, 'IndicatorOperational', false, ...
        'FinalAggregationWeighted', false, 'AggregationEligible', NaN, ...
        'AggregationChanged', NaN, 'BatchSpreadNormalized', NaN, ...
        'SelectedFromLastRound', NaN, 'OracleValid', false, ...
        'OracleHitCount', NaN, 'OracleHitRate', NaN, 'OracleAlgorithmK', NaN, ...
        'OracleK', NaN, 'OracleBaselineCoverage', NaN, ...
        'OracleAlgorithmCoverage', NaN, 'OracleOracleCoverage', NaN, ...
        'OracleAlgorithmGain', NaN, 'OracleOracleGain', NaN, ...
        'OracleGainRatio', NaN, 'OraclePoolConsidered', NaN, ...
        'OraclePoolTotal', NaN, 'OracleSubsampled', false);
end

%% ============================ aggregation ============================
function summary = summarizeByArm(runTable, catalog)
    metrics = ["SurvivalRateLate", "SurvivalRatePooled", "SurvivalRateAll", ...
        "OracleHitRate", "OracleGainRatio", "IGD", "BatchSizeMean", ...
        "PoolUniqueMean", "BatchSpreadMean"];
    keys = unique(runTable(:, {'Arm', 'Problem', 'M'}), 'rows');
    rows = cell(height(keys), 1);
    for index = 1:height(keys)
        mask = runTable.Arm == keys.Arm(index) & ...
            runTable.Problem == keys.Problem(index) & ...
            runTable.M == keys.M(index);
        block = runTable(mask, :);
        row = struct();
        row.Arm = keys.Arm(index);
        row.ArmID = block.ArmID(1);
        row.Problem = keys.Problem(index);
        row.M = keys.M(index);
        row.NumRuns = height(block);
        for metric = metrics
            values = block.(metric);
            values = values(isfinite(values));
            row.(metric + "_mean") = meanOrNaN(values);
            row.(metric + "_std") = stdOrNaN(values);
            row.(metric + "_median") = medianOrNaN(values);
        end
        row.IndicatorOperationalFraction = ...
            meanOrNaN(block.IndicatorOperationalFraction);
        row.ExploreModeFraction = meanOrNaN(block.ExploreModeFraction);
        row.IndicatorModeFraction = meanOrNaN(block.IndicatorModeFraction);
        rows{index} = row;
    end
    summary = sortrows(struct2table(vertcat(rows{:})), {'Problem', 'M', 'ArmID'});
    summary = attachArmMetadata(summary, catalog);
end

function overall = summarizeOverall(runTable, catalog)
    arms = unique(runTable.Arm);
    rows = cell(numel(arms), 1);
    for index = 1:numel(arms)
        block = runTable(runTable.Arm == arms(index), :);
        row = struct();
        row.Arm = arms(index);
        row.ArmID = block.ArmID(1);
        row.NumRuns = height(block);
        row.NumProblems = numel(unique(block.Problem));
        row.SurvivalRateLate_mean = meanOrNaN(block.SurvivalRateLate);
        row.SurvivalRateLate_std = stdOrNaN(block.SurvivalRateLate);
        row.SurvivalRatePooled_mean = meanOrNaN(block.SurvivalRatePooled);
        row.SurvivalRateAll_mean = meanOrNaN(block.SurvivalRateAll);
        row.SurvivalRateEarly_mean = meanOrNaN(block.SurvivalRateEarly);
        row.OracleHitRate_mean = meanOrNaN(block.OracleHitRate);
        row.OracleHitRate_std = stdOrNaN(block.OracleHitRate);
        row.OracleHitRateLate_mean = meanOrNaN(block.OracleHitRateLate);
        row.OracleGainRatio_mean = meanOrNaN(block.OracleGainRatio);
        row.IGD_mean = meanOrNaN(block.IGD);
        row.IGD_median = medianOrNaN(block.IGD);
        row.BatchSizeMean = meanOrNaN(block.BatchSizeMean);
        row.BatchSizeMin = minOrNaN(block.BatchSizeMin);
        row.BatchSizeMax = maxOrNaN(block.BatchSizeMax);
        row.PoolUniqueMean = meanOrNaN(block.PoolUniqueMean);
        row.LastRoundUniqueMean = meanOrNaN(block.LastRoundUniqueMean);
        row.BatchSpreadMean = meanOrNaN(block.BatchSpreadMean);
        row.SelectedFromLastRoundMean = meanOrNaN(block.SelectedFromLastRoundMean);
        row.IndicatorOperationalFraction = meanOrNaN(block.IndicatorOperationalFraction);
        row.AggregationChangedFraction = meanOrNaN(block.AggregationChangedFraction);
        row.GenerationCountMean = meanOrNaN(block.GenerationCount);
        rows{index} = row;
    end
    overall = sortrows(struct2table(vertcat(rows{:})), 'ArmID');
    overall = attachArmMetadata(overall, catalog);
end

function stages = summarizeStages(runTable, catalog)
    stageNames = ["SurvivalRateStage1", "SurvivalRateStage2", ...
        "SurvivalRateStage3", "SurvivalRateStage4"];
    keys = unique(runTable(:, {'Arm', 'Problem', 'M'}), 'rows');
    rows = cell(height(keys)*numel(stageNames), 1);
    cursor = 0;
    for index = 1:height(keys)
        mask = runTable.Arm == keys.Arm(index) & ...
            runTable.Problem == keys.Problem(index) & ...
            runTable.M == keys.M(index);
        block = runTable(mask, :);
        for stage = 1:numel(stageNames)
            cursor = cursor + 1;
            row = struct();
            row.Arm = keys.Arm(index);
            row.ArmID = block.ArmID(1);
            row.Problem = keys.Problem(index);
            row.M = keys.M(index);
            row.Stage = stage;
            row.FERangeStart = (stage-1)*0.25;
            row.FERangeEnd = stage*0.25;
            row.SurvivalRate_mean = meanOrNaN(block.(stageNames(stage)));
            row.SurvivalRate_std = stdOrNaN(block.(stageNames(stage)));
            row.NumRuns = height(block);
            rows{cursor} = row;
        end
    end
    stages = sortrows(struct2table(vertcat(rows{:})), ...
        {'Problem', 'M', 'ArmID', 'Stage'});
    stages = attachArmMetadata(stages, catalog);
end

function summary = attachArmMetadata(summary, catalog)
    [~, position] = ismember(summary.Arm, catalog.Arm);
    valid = position > 0;
    summary.IsolatedFactor = strings(height(summary), 1);
    summary.IsolatedFactor(valid) = catalog.IsolatedFactor(position(valid));
end

%% ============================ contrasts ============================
function contrasts = buildContrasts(runTable, catalog)
%BUILDCONTRASTS Paired Wilcoxon signed-rank tests against two references.
%   Every arm is compared with V1_POOL_ONLY (the pooling-controlled
%   reference) and with V0_REMO_RULE (the original selection rule). Pairing
%   is by PairedKey, which shares the seed across arms, so the tests are
%   paired on common random numbers.
%
%   Holm correction is applied WITHIN each (reference, metric) family, which
%   is the family of simultaneous decisions actually being made.

    metrics = ["SurvivalRateLate", "OracleHitRate", "OracleGainRatio", "IGD"];
    higherIsBetter = [true, true, true, false];
    references = ["V1_POOL_ONLY", "V0_REMO_RULE"];
    rows = cell(0, 1);

    for referenceIndex = 1:numel(references)
        reference = references(referenceIndex);
        if ~any(runTable.Arm == reference)
            continue;
        end
        for metricIndex = 1:numel(metrics)
            metric = metrics(metricIndex);
            candidateArms = setdiff(unique(runTable.Arm), reference);
            pending = cell(numel(candidateArms), 1);
            for armIndex = 1:numel(candidateArms)
                arm = candidateArms(armIndex);
                [treated, control, keys] = pairMetric( ...
                    runTable, arm, reference, metric);
                row = struct();
                row.Reference = reference;
                row.Arm = arm;
                [~, position] = ismember(arm, catalog.Arm);
                if position > 0
                    row.IsolatedFactor = catalog.IsolatedFactor(position);
                    row.ArmID = catalog.ArmID(position);
                else
                    row.IsolatedFactor = "";
                    row.ArmID = NaN;
                end
                row.Metric = metric;
                row.HigherIsBetter = higherIsBetter(metricIndex);
                row.NumPairs = numel(treated);
                row.PairedKeysUsed = numel(keys);
                row.TreatedMean = meanOrNaN(treated);
                row.ControlMean = meanOrNaN(control);
                row.MeanDifference = meanOrNaN(treated - control);
                row.MedianDifference = medianOrNaN(treated - control);
                row.WinCount = sum(treated > control);
                row.TieCount = sum(treated == control);
                row.LossCount = sum(treated < control);
                [row.PValue, row.TestName] = signedRankTest(treated, control);
                row.EffectSize = cliffsDelta(treated, control);
                pending{armIndex} = row;
            end
            pending = vertcat(pending{:});
            if isempty(pending)
                continue;
            end
            adjusted = holmAdjust([pending.PValue]);
            for armIndex = 1:numel(pending)
                pending(armIndex).PValueHolm = adjusted(armIndex);
                pending(armIndex).SignificantHolm05 = adjusted(armIndex) < 0.05;
            end
            rows{end+1, 1} = pending; %#ok<AGROW>
        end
    end

    if isempty(rows)
        contrasts = table();
        return;
    end
    contrasts = struct2table(vertcat(rows{:}));
    contrasts = sortrows(contrasts, {'Reference', 'Metric', 'ArmID'});
end

function [treated, control, keys] = pairMetric(runTable, arm, reference, metric)
    treatedBlock = runTable(runTable.Arm == arm, :);
    controlBlock = runTable(runTable.Arm == reference, :);
    keys = intersect(treatedBlock.PairedKey, controlBlock.PairedKey);
    treated = nan(numel(keys), 1);
    control = nan(numel(keys), 1);
    for index = 1:numel(keys)
        treatedValue = treatedBlock.(metric)(treatedBlock.PairedKey == keys(index));
        controlValue = controlBlock.(metric)(controlBlock.PairedKey == keys(index));
        if isscalar(treatedValue) && isscalar(controlValue)
            treated(index) = treatedValue;
            control(index) = controlValue;
        end
    end
    keep = isfinite(treated) & isfinite(control);
    treated = treated(keep);
    control = control(keep);
    keys = keys(keep);
end

function [pValue, testName] = signedRankTest(treated, control)
    pValue = NaN;
    testName = "none";
    if numel(treated) < 2
        return;
    end
    differences = treated - control;
    if all(differences == 0)
        pValue = 1;
        testName = "all-ties";
        return;
    end
    try
        pValue = signrank(treated, control);
        testName = "wilcoxon-signrank";
    catch
        try
            [~, pValue] = ttest(treated, control);
            testName = "paired-ttest-fallback";
        catch
            pValue = NaN;
            testName = "unavailable";
        end
    end
end

function delta = cliffsDelta(treated, control)
%CLIFFSDELTA Paired sign-based effect size in [-1,1], ties excluded.
    differences = treated - control;
    nonTies = differences(differences ~= 0);
    if isempty(nonTies)
        delta = 0;
        return;
    end
    delta = (sum(nonTies > 0) - sum(nonTies < 0)) / numel(nonTies);
end

function adjusted = holmAdjust(pValues)
    pValues = pValues(:);
    adjusted = nan(size(pValues));
    finiteMask = isfinite(pValues);
    finiteValues = pValues(finiteMask);
    if isempty(finiteValues)
        return;
    end
    [sorted, order] = sort(finiteValues);
    count = numel(sorted);
    scaled = sorted .* (count:-1:1)';
    running = cummax(min(scaled, 1));
    result = nan(count, 1);
    result(order) = running;
    adjusted(finiteMask) = result;
end

%% ============================ diagnostics ============================
function diagnostics = buildDiagnostics(runTable, generationTable, config, missing)
%BUILDDIAGNOSTICS Integrity checks to read BEFORE any conclusion.
    rows = cell(0, 1);

    rows{end+1, 1} = diagnosticRow("expected_jobs", ...
        numel(config.Jobs), "count", ...
        "Jobs in the frozen protocol for this profile.");
    rows{end+1, 1} = diagnosticRow("loaded_runs", height(runTable), "count", ...
        "Result files found and validated.");
    rows{end+1, 1} = diagnosticRow("missing_runs", numel(missing), "count", ...
        "Protocol jobs with no result file. Non-zero means the analysis is partial.");

    armCounts = groupcounts(runTable, 'Arm');
    balanced = numel(unique(armCounts.GroupCount)) == 1;
    rows{end+1, 1} = diagnosticRow("arms_balanced", double(balanced), "logical", ...
        "All arms have the same number of runs. Unbalanced arms invalidate pooled comparisons.");

    overrun = sum(runTable.CompletedFE > runTable.MaxFE);
    rows{end+1, 1} = diagnosticRow("fe_budget_overruns", overrun, "count", ...
        "Runs exceeding maxFE. Must be 0.");

    % Batch constancy must be judged on untruncated generations only. The last
    % generation is clipped to whatever FE remain in the budget, so its batch is
    % smaller by arithmetic rather than by the selection rule. Using the per-run
    % BatchSizeMin/Max would therefore report "not constant" on every complete
    % run and hide the real property being checked.
    if all(ismember({'Arm', 'TruncatedBatch', 'BatchSize'}, ...
            generationTable.Properties.VariableNames))
        untruncated = generationTable(~generationTable.TruncatedBatch & ...
            generationTable.Arm ~= "V0_REMO_RULE", :);
        if isempty(untruncated)
            constantBatch = NaN;
        else
            constantBatch = double(numel(unique(untruncated.BatchSize)) == 1);
        end
        rows{end+1, 1} = diagnosticRow("batch_constant_non_v0", ...
            constantBatch, "logical", ...
            "Batch size is constant for arms V1-V4 on untruncated generations. Confirms nMin never binds and batch is not a confound among them.");
        rows{end+1, 1} = diagnosticRow("batch_truncated_generations", ...
            sum(generationTable.TruncatedBatch), "count", ...
            "Generations whose batch was clipped by the remaining FE budget. Excluded from the constancy check above.");
    end

    v0Mask = runTable.Arm == "V0_REMO_RULE";
    if any(v0Mask)
        rows{end+1, 1} = diagnosticRow("v0_batch_mean", ...
            meanOrNaN(runTable.BatchSizeMean(v0Mask)), "value", ...
            "Mean batch size of the original REMO rule. Differs from 6 by design; treat V0 contrasts as confounded by batch size.");
    end

    indicatorArms = runTable.Arm == "V3_INDICATOR_ONLY";
    if any(indicatorArms)
        operational = meanOrNaN(runTable.IndicatorOperationalFraction(indicatorArms));
        rows{end+1, 1} = diagnosticRow("v3_indicator_operational_fraction", ...
            operational, "fraction", ...
            "Fraction of V3 generations where the SVR actually produced finite predictions. Below 1 means V3 partly degenerates to relation top-K.");
    end

    if ~isempty(generationTable)
        subsampled = meanOrNaN(double(generationTable.OracleSubsampled( ...
            generationTable.OracleValid)));
        rows{end+1, 1} = diagnosticRow("oracle_subsampled_fraction", ...
            subsampled, "fraction", ...
            "Fraction of oracle rows where the pool was subsampled. Read HitRate against oracle_pool_considered_mean.");
        rows{end+1, 1} = diagnosticRow("oracle_pool_considered_mean", ...
            meanOrNaN(generationTable.OraclePoolConsidered( ...
            generationTable.OracleValid)), "value", ...
            "Mean number of candidates the oracle searched.");
        rows{end+1, 1} = diagnosticRow("oracle_pool_total_mean", ...
            meanOrNaN(generationTable.OraclePoolTotal( ...
            generationTable.OracleValid)), "value", ...
            "Mean full pool size before subsampling.");
        rows{end+1, 1} = diagnosticRow("archive_over_n_max", ...
            maxOrNaN(generationTable.ArchiveOverN), "value", ...
            "Peak |Archive|/N. Small values are why early-generation survival is uninformative.");
        rows{end+1, 1} = diagnosticRow("aggregation_changed_fraction", ...
            meanOrNaN(runTable.AggregationChangedFraction), "fraction", ...
            "Fraction of inner-loop rounds where freezing the parent score to the simple mean would have altered the parent set. Bounds the cost of that freeze.");
        rows{end+1, 1} = diagnosticRow("fallback_generations_total", ...
            sum(runTable.FallbackGenerationCount), "count", ...
            "Generations where selection returned nothing and the GA fallback fired. Those generations are excluded from the oracle.");
        rows{end+1, 1} = diagnosticRow("truncated_generations_total", ...
            sum(runTable.TruncatedGenerationCount), "count", ...
            "Generations where the batch was clipped by the remaining FE budget.");
    end

    diagnostics = struct2table(vertcat(rows{:}));
end

function row = diagnosticRow(name, value, kind, note)
    row = struct('Check', string(name), 'Value', value, ...
        'Kind', string(kind), 'Note', string(note));
end

%% ============================ io + stats helpers ============================
function writeCsv(dataTable, filePath)
    if isempty(dataTable)
        return;
    end
    directory = fileparts(filePath);
    if ~isfolder(directory)
        mkdir(directory);
    end
    temporaryPath = [tempname(directory), '.csv'];
    writetable(dataTable, temporaryPath);
    [moved, message] = movefile(temporaryPath, filePath, "f");
    if ~moved
        if isfile(temporaryPath)
            delete(temporaryPath);
        end
        error("CVP:CsvWriteFailed", "Could not write %s: %s", filePath, message);
    end
end

function value = meanOrNaN(data)
    data = data(isfinite(data));
    if isempty(data), value = NaN; else, value = mean(data); end
end

function value = stdOrNaN(data)
    data = data(isfinite(data));
    if numel(data) < 2, value = NaN; else, value = std(data); end
end

function value = medianOrNaN(data)
    data = data(isfinite(data));
    if isempty(data), value = NaN; else, value = median(data); end
end

function value = minOrNaN(data)
    data = data(isfinite(data));
    if isempty(data), value = NaN; else, value = min(data); end
end

function value = maxOrNaN(data)
    data = data(isfinite(data));
    if isempty(data), value = NaN; else, value = max(data); end
end

%% ============================ digest ============================
function printDigest(report, config)
    fprintf("\n===== Candidate-value probe: %s =====\n", report.Profile);
    fprintf("CSV written to: %s\n", report.CsvDirectory);
    if ~isempty(report.MissingJobs)
        fprintf("\n[!] %d of %d protocol jobs are missing. Results are PARTIAL.\n", ...
            numel(report.MissingJobs), numel(config.Jobs));
    end

    fprintf("\n-- Arm overview (pooled across problems) --\n");
    overall = report.ArmOverall;
    fprintf("%-19s %6s %8s %8s %8s %8s %7s\n", ...
        "Arm", "runs", "CSR_late", "Hit", "GainRat", "IGD", "batch");
    for index = 1:height(overall)
        fprintf("%-19s %6d %8.4f %8.4f %8.4f %8.3e %7.2f\n", ...
            overall.Arm(index), overall.NumRuns(index), ...
            overall.SurvivalRateLate_mean(index), ...
            overall.OracleHitRate_mean(index), ...
            overall.OracleGainRatio_mean(index), ...
            overall.IGD_mean(index), overall.BatchSizeMean(index));
    end

    fprintf("\n-- Survival by FE quartile (exposes the archive-growth confound) --\n");
    stages = report.StageProfile;
    arms = unique(stages.Arm);
    fprintf("%-19s %9s %9s %9s %9s\n", "Arm", "Q1", "Q2", "Q3", "Q4");
    for index = 1:numel(arms)
        block = stages(stages.Arm == arms(index), :);
        values = nan(1, 4);
        for stage = 1:4
            values(stage) = meanOrNaN(block.SurvivalRate_mean(block.Stage == stage));
        end
        fprintf("%-19s %9.4f %9.4f %9.4f %9.4f\n", arms(index), values);
    end

    if ~isempty(report.Contrasts)
        fprintf("\n-- Paired contrasts vs V1_POOL_ONLY (Holm within metric) --\n");
        contrasts = report.Contrasts;
        mask = contrasts.Reference == "V1_POOL_ONLY";
        block = contrasts(mask, :);
        fprintf("%-19s %-18s %9s %8s %8s %6s\n", ...
            "Arm", "Metric", "meanDiff", "p", "pHolm", "W/T/L");
        for index = 1:height(block)
            fprintf("%-19s %-18s %9.4f %8.4f %8.4f %d/%d/%d\n", ...
                block.Arm(index), block.Metric(index), ...
                block.MeanDifference(index), block.PValue(index), ...
                block.PValueHolm(index), block.WinCount(index), ...
                block.TieCount(index), block.LossCount(index));
        end
    end

    fprintf("\n-- Diagnostics (read these first) --\n");
    diagnostics = report.Diagnostics;
    for index = 1:height(diagnostics)
        fprintf("  %-38s %12.4f  (%s)\n", diagnostics.Check(index), ...
            diagnostics.Value(index), diagnostics.Kind(index));
    end
    fprintf("\n");
end
