function row = CVPFillTraceFields(row, trace, Problem)
%CVPFILLTRACEFIELDS Copy selection-trace diagnostics into a generation row.
%   Batch spread is reported on decision variables normalised by the
%   problem's box, so it is comparable across problems whose bounds differ
%   (WFG uses upper = 2:2:2D while DTLZ uses the unit box). It is a
%   sanity check that the dispersion term is active, NOT evidence that
%   dispersion helps: the explore acquisition adds 0.25*distance
%   explicitly, so a larger spread is close to tautological.

    if ~isstruct(trace) || ~isfield(trace, 'SelectedK')
        return;
    end

    row.Mode = string(getFieldOr(trace, 'Mode', ""));
    row.AttemptedMode = string(getFieldOr(trace, 'AttemptedMode', ""));
    row.PoolUniqueCount = getFieldOr(trace, 'AccumUniqueCount', NaN);
    row.PoolRawCount = getFieldOr(trace, 'AccumRawCount', NaN);
    row.LastRoundUniqueCount = getFieldOr(trace, 'LastRoundUniqueCount', NaN);
    row.RoundCount = getFieldOr(trace, 'RoundCount', NaN);
    row.RetainedCount = getFieldOr(trace, 'RetainedCount', NaN);
    row.SelectedK = getFieldOr(trace, 'SelectedK', NaN);
    row.PErr = getFieldOr(trace, 'PErr', NaN);
    row.LambdaT = getFieldOr(trace, 'LambdaT', NaN);
    row.IndicatorAvailable = logical(getFieldOr(trace, 'IndicatorAvailable', false));
    row.IndicatorOperational = logical(getFieldOr(trace, 'IndicatorOperational', false));
    row.FinalAggregationWeighted = ...
        logical(getFieldOr(trace, 'FinalAggregationWeighted', false));
    row.AggregationEligible = getFieldOr(trace, 'GenerationAggregationEligible', NaN);
    row.AggregationChanged = getFieldOr(trace, 'GenerationAggregationChanged', NaN);

    candidates = getFieldOr(trace, 'Candidates', zeros(0, 0));
    selected = getFieldOr(trace, 'SelectedIndex', zeros(0, 1));
    if ~isempty(candidates) && numel(selected) >= 2
        scale = Problem.upper - Problem.lower;
        scale(scale <= 0) = 1;
        scaled = (candidates(selected, :) - Problem.lower) ./ scale;
        distances = pdist(scaled);
        if ~isempty(distances)
            row.BatchSpreadNormalized = mean(distances);
        end
    end

    inLastRound = getFieldOr(trace, 'InLastRound', false(0, 1));
    if ~isempty(inLastRound) && ~isempty(selected)
        row.SelectedFromLastRound = nnz(inLastRound(selected)) / numel(selected);
    end
end

function value = getFieldOr(structure, name, fallback)
    if isfield(structure, name)
        value = structure.(name);
    else
        value = fallback;
    end
end
