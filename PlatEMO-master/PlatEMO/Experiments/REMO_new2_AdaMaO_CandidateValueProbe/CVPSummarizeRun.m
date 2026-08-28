function summary = CVPSummarizeRun(generations, lateStageStart)
%CVPSUMMARIZERUN Collapse one run's generation rows into scalar metrics.
%   SUMMARY = CVPSUMMARIZERUN(GENERATIONS, LATESTAGESTART) reports the two
%   primary metrics plus the descriptive fields needed to interpret them.
%
%   Candidate Survival Rate is reported THREE ways on purpose:
%
%     SurvivalRateAll   mean over every generation. Reported for
%                       completeness, but confounded: |Archive| grows from N
%                       to at most 3N over the run, so early generations
%                       have almost no competition and survival is close to
%                       1 for every arm regardless of the selector.
%     SurvivalRateLate  mean over generations with FE/maxFE >= LATESTAGESTART.
%                       This is the PRIMARY survival figure, because the
%                       archive-to-N pressure is comparable across arms
%                       there.
%     SurvivalRateByStage mean within each quartile of the FE budget, so the
%                       confound can be shown rather than argued about.
%
%   The oracle metrics are averaged over generations where the diagnostic
%   actually ran and returned a valid record.

    if nargin < 2 || isempty(lateStageStart)
        lateStageStart = 0.50;
    end

    summary = struct();
    if isempty(generations)
        summary = emptySummary();
        return;
    end

    ratio = [generations.Ratio];
    survival = [generations.SurvivalRate];
    lateMask = ratio >= lateStageStart;

    summary.GenerationCount = numel(generations);
    summary.SurvivalRateAll = safeMean(survival);
    summary.SurvivalRateLate = safeMean(survival(lateMask));
    summary.SurvivalRateEarly = safeMean(survival(~lateMask));
    summary.SurvivorTotal = safeSum([generations.SurvivorCount]);
    summary.EvaluatedTotal = safeSum([generations.BatchSize]);
    if summary.EvaluatedTotal > 0
        summary.SurvivalRatePooled = summary.SurvivorTotal / summary.EvaluatedTotal;
    else
        summary.SurvivalRatePooled = NaN;
    end

    edges = [0, 0.25, 0.50, 0.75, 1.01];
    stageMeans = nan(1, 4);
    for stage = 1:4
        mask = ratio >= edges(stage) & ratio < edges(stage+1);
        stageMeans(stage) = safeMean(survival(mask));
    end
    summary.SurvivalRateStage1 = stageMeans(1);
    summary.SurvivalRateStage2 = stageMeans(2);
    summary.SurvivalRateStage3 = stageMeans(3);
    summary.SurvivalRateStage4 = stageMeans(4);

    validOracle = [generations.OracleValid];
    summary.OracleRowCount = nnz(validOracle);
    summary.OracleHitRate = safeMean([generations(validOracle).OracleHitRate]);
    summary.OracleHitRateLate = safeMean( ...
        [generations(validOracle & lateMask).OracleHitRate]);
    summary.OracleGainRatio = safeMean([generations(validOracle).OracleGainRatio]);
    summary.OracleGainRatioLate = safeMean( ...
        [generations(validOracle & lateMask).OracleGainRatio]);
    summary.OracleAlgorithmGain = safeMean( ...
        [generations(validOracle).OracleAlgorithmGain]);
    summary.OracleOracleGain = safeMean([generations(validOracle).OracleOracleGain]);
    summary.OraclePoolConsidered = safeMean( ...
        [generations(validOracle).OraclePoolConsidered]);
    summary.OracleSubsampledFraction = safeMean( ...
        double([generations(validOracle).OracleSubsampled]));

    summary.BatchSizeMean = safeMean([generations.BatchSize]);
    summary.BatchSizeMin = safeMin([generations.BatchSize]);
    summary.BatchSizeMax = safeMax([generations.BatchSize]);
    summary.PoolUniqueMean = safeMean([generations.PoolUniqueCount]);
    summary.PoolRawMean = safeMean([generations.PoolRawCount]);
    summary.LastRoundUniqueMean = safeMean([generations.LastRoundUniqueCount]);
    summary.RetainedCountMean = safeMean([generations.RetainedCount]);
    summary.BatchSpreadMean = safeMean([generations.BatchSpreadNormalized]);
    summary.SelectedFromLastRoundMean = safeMean( ...
        [generations.SelectedFromLastRound]);
    summary.PErrMean = safeMean([generations.PErr]);
    summary.LambdaTMean = safeMean([generations.LambdaT]);
    summary.IndicatorAvailableFraction = safeMean( ...
        double([generations.IndicatorAvailable]));
    summary.IndicatorOperationalFraction = safeMean( ...
        double([generations.IndicatorOperational]));
    summary.ExploreModeFraction = safeMean(double( ...
        [generations.Mode] == "explore"));
    summary.IndicatorModeFraction = safeMean(double( ...
        [generations.Mode] == "indicator"));
    summary.FallbackGenerationCount = safeSum(double([generations.UsedFallback]));
    summary.TruncatedGenerationCount = safeSum(double([generations.TruncatedBatch]));
    summary.AggregationEligibleTotal = safeSum([generations.AggregationEligible]);
    summary.AggregationChangedTotal = safeSum([generations.AggregationChanged]);
    if summary.AggregationEligibleTotal > 0
        summary.AggregationChangedFraction = ...
            summary.AggregationChangedTotal / summary.AggregationEligibleTotal;
    else
        summary.AggregationChangedFraction = NaN;
    end
end

function summary = emptySummary()
    summary = struct( ...
        'GenerationCount', 0, 'SurvivalRateAll', NaN, ...
        'SurvivalRateLate', NaN, 'SurvivalRateEarly', NaN, ...
        'SurvivorTotal', 0, 'EvaluatedTotal', 0, 'SurvivalRatePooled', NaN, ...
        'SurvivalRateStage1', NaN, 'SurvivalRateStage2', NaN, ...
        'SurvivalRateStage3', NaN, 'SurvivalRateStage4', NaN, ...
        'OracleRowCount', 0, 'OracleHitRate', NaN, 'OracleHitRateLate', NaN, ...
        'OracleGainRatio', NaN, 'OracleGainRatioLate', NaN, ...
        'OracleAlgorithmGain', NaN, 'OracleOracleGain', NaN, ...
        'OraclePoolConsidered', NaN, 'OracleSubsampledFraction', NaN, ...
        'BatchSizeMean', NaN, 'BatchSizeMin', NaN, 'BatchSizeMax', NaN, ...
        'PoolUniqueMean', NaN, 'PoolRawMean', NaN, ...
        'LastRoundUniqueMean', NaN, 'RetainedCountMean', NaN, ...
        'BatchSpreadMean', NaN, 'SelectedFromLastRoundMean', NaN, ...
        'PErrMean', NaN, 'LambdaTMean', NaN, ...
        'IndicatorAvailableFraction', NaN, 'IndicatorOperationalFraction', NaN, ...
        'ExploreModeFraction', NaN, 'IndicatorModeFraction', NaN, ...
        'FallbackGenerationCount', 0, 'TruncatedGenerationCount', 0, ...
        'AggregationEligibleTotal', 0, 'AggregationChangedTotal', 0, ...
        'AggregationChangedFraction', NaN);
end

function value = safeMean(data)
    data = data(isfinite(data));
    if isempty(data)
        value = NaN;
    else
        value = mean(data);
    end
end

function value = safeSum(data)
    data = data(isfinite(data));
    if isempty(data)
        value = 0;
    else
        value = sum(data);
    end
end

function value = safeMin(data)
    data = data(isfinite(data));
    if isempty(data)
        value = NaN;
    else
        value = min(data);
    end
end

function value = safeMax(data)
    data = data(isfinite(data));
    if isempty(data)
        value = NaN;
    else
        value = max(data);
    end
end
