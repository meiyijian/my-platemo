function complementarityMetrics = DPCComputeComplementarityMetrics( ...
        snapshots, trajectory, evaluations, metadata)
%DPCComputeComplementarityMetrics - Score dual-view complementarity
%   T = DPCComputeComplementarityMetrics(SNAPSHOTS,TRAJECTORY,EVALUATIONS,META)
%   reconstructs future outcomes by stable EvalID and returns one row per
%   snapshot and truth definition.
%
%   See also DPCComputeSetComplementarity,
%   ReconstructFutureLabelOutcomes

    validateMetadata(metadata);
    if isempty(snapshots) || isempty(trajectory) || isempty(evaluations)
        error("DPC:EmptyAuditData", ...
            "Snapshots, trajectory, and evaluations cannot be empty.");
    end

    numberOfTruths = 6;
    rows = repmat(makeEmptyRow(), ...
        numel(snapshots)*numberOfTruths, 1);
    rowIndex = 0;
    registeredIDs = evaluations.EvalID(:);

    for snapshotIndex = 1:numel(snapshots)
        snapshot = snapshots(snapshotIndex);
        populationIDs = snapshot.PopulationEvalID(:);
        validateSnapshot(snapshot, populationIDs, registeredIDs);

        populationSize = numel(populationIDs);
        quotaCount = max(1, min(populationSize, ...
            ceil(populationSize*metadata.RGood)));
        [vSelected, vTieCount] = selectTopFraction( ...
            double(snapshot.ScoreV(:)), quotaCount);
        [aSelected, aTieCount] = selectTopFraction( ...
            double(snapshot.AnchorMargin(:)), quotaCount);
        [hybridFromScore, hybridTieCount] = selectTopFraction( ...
            double(snapshot.ScoreHybrid(:)), quotaCount);
        hSelected = logical(snapshot.CatalogCurrent(:));
        labelNative = logical(snapshot.LabelDyn(:));
        if ~isequal(hybridFromScore, hSelected)
            error("DPC:HybridCatalogMismatch", ...
                "Snapshot %d does not reproduce the Hybrid catalog.", ...
                snapshot.SnapshotID);
        end

        future = ReconstructFutureLabelOutcomes( ...
            snapshots, trajectory, evaluations, snapshotIndex);
        truths = makeTruths(future);
        for truthIndex = 1:numberOfTruths
            truth = truths(truthIndex);
            setMetrics = DPCComputeSetComplementarity( ...
                vSelected, aSelected, hSelected, labelNative, truth.Values);
            rowIndex = rowIndex + 1;
            row = makeEmptyRow();
            row.SchemaVersion = 1;
            row.Profile = string(metadata.Profile);
            row.Problem = string(metadata.Problem);
            row.M = metadata.M;
            row.RequestedD = metadata.RequestedD;
            row.ActualD = metadata.ActualD;
            row.Run = metadata.Run;
            row.Seed = metadata.Seed;
            row.SnapshotID = snapshot.SnapshotID;
            row.Generation = snapshot.Generation;
            row.FE = snapshot.FE;
            row.FERatio = snapshot.Ratio;
            row.Stage = GGPStageBin(snapshot.Ratio);
            row.Truth = truth.Name;
            row.TruthType = truth.Type;
            row.Horizon = truth.Horizon;
            row.QuotaCount = quotaCount;
            row.BoundaryTieCountV = vTieCount;
            row.BoundaryTieCountA = aTieCount;
            row.BoundaryTieCountHybrid = hybridTieCount;
            row = copyMetricFields(row, setMetrics);
            rows(rowIndex) = row;
        end
    end

    complementarityMetrics = struct2table(rows);
end

function validateMetadata(metadata)
    requiredFields = ["Profile", "Problem", "M", "RequestedD", ...
        "ActualD", "Run", "Seed", "RGood"];
    if ~isstruct(metadata) || ~all(isfield(metadata, requiredFields))
        error("DPC:InvalidMetadata", ...
            "Replay metadata does not contain all required fields.");
    end
    if ~isscalar(metadata.RGood) || ~isfinite(metadata.RGood) || ...
            metadata.RGood <= 0 || metadata.RGood > 0.5
        error("DPC:InvalidQuota", "RGood must be in (0,0.5].");
    end
end

function validateSnapshot(snapshot, populationIDs, registeredIDs)
    requiredFields = ["SnapshotID", "Generation", "FE", "Ratio", ...
        "PopulationEvalID", "ScoreV", "AnchorMargin", "ScoreHybrid", ...
        "CatalogCurrent", "LabelDyn"];
    if ~all(isfield(snapshot, requiredFields))
        error("DPC:InvalidSnapshot", ...
            "A snapshot is missing required complementarity fields.");
    end
    populationSize = numel(populationIDs);
    if numel(unique(populationIDs)) ~= populationSize || ...
            ~all(ismember(populationIDs, registeredIDs))
        error("DPC:InvalidEvaluationIdentity", ...
            "Snapshot %d contains invalid EvalIDs.", snapshot.SnapshotID);
    end
    fieldSizes = [numel(snapshot.ScoreV), ...
        numel(snapshot.AnchorMargin), numel(snapshot.ScoreHybrid), ...
        numel(snapshot.CatalogCurrent), numel(snapshot.LabelDyn)];
    if any(fieldSizes ~= populationSize)
        error("DPC:SnapshotSizeMismatch", ...
            "Snapshot %d view sizes do not match the population.", ...
            snapshot.SnapshotID);
    end
end

function [selected, boundaryTieCount] = selectTopFraction(score, count)
    score = score(:);
    if any(~isfinite(score))
        error("DPC:InvalidViewScore", ...
            "Complementarity scores must be finite.");
    end
    [~, order] = sortrows([-score, (1:numel(score)).']);
    selected = false(numel(score), 1);
    selected(order(1:count)) = true;
    threshold = score(order(count));
    boundaryTieCount = nnz(score == threshold);
end

function truths = makeTruths(future)
    truths = repmat(struct("Name", "", "Type", "", ...
        "Horizon", "", "Values", []), 6, 1);
    truths(1) = struct("Name", "population_h1", "Type", "retention", ...
        "Horizon", "H1", "Values", future.InPopulationH1);
    truths(2) = struct("Name", "population_h3", "Type", "retention", ...
        "Horizon", "H3", "Values", future.InPopulationH3);
    truths(3) = struct("Name", "population_final", ...
        "Type", "retention", "Horizon", "FINAL", ...
        "Values", future.InFinalPopulation);
    truths(4) = struct("Name", "front_h1", "Type", "nondominated", ...
        "Horizon", "H1", "Values", future.NondominatedInArchiveH1);
    truths(5) = struct("Name", "front_h3", "Type", "nondominated", ...
        "Horizon", "H3", "Values", future.NondominatedInArchiveH3);
    truths(6) = struct("Name", "front_final", ...
        "Type", "nondominated", "Horizon", "FINAL", ...
        "Values", future.NondominatedInFinalArchive);
end

function row = copyMetricFields(row, metrics)
    metricNames = fieldnames(metrics);
    for index = 1:numel(metricNames)
        name = metricNames{index};
        row.(name) = metrics.(name);
    end
end

function row = makeEmptyRow()
    setMetrics = DPCComputeSetComplementarity( ...
        false(1, 1), false(1, 1), false(1, 1), ...
        false(1, 1), NaN);
    row = struct( ...
        "SchemaVersion", NaN, ...
        "Profile", "", ...
        "Problem", "", ...
        "M", NaN, ...
        "RequestedD", NaN, ...
        "ActualD", NaN, ...
        "Run", NaN, ...
        "Seed", NaN, ...
        "SnapshotID", NaN, ...
        "Generation", NaN, ...
        "FE", NaN, ...
        "FERatio", NaN, ...
        "Stage", "", ...
        "Truth", "", ...
        "TruthType", "", ...
        "Horizon", "", ...
        "QuotaCount", NaN, ...
        "BoundaryTieCountV", NaN, ...
        "BoundaryTieCountA", NaN, ...
        "BoundaryTieCountHybrid", NaN);
    metricNames = fieldnames(setMetrics);
    for index = 1:numel(metricNames)
        row.(metricNames{index}) = setMetrics.(metricNames{index});
    end
end

