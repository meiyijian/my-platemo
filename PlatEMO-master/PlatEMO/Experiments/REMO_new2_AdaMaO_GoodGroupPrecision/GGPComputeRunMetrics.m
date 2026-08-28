function checkpointMetrics = GGPComputeRunMetrics(snapshots, trajectory, evaluations, metadata)
%GGPCOMPUTERUNMETRICS Score label views against stable-ID future outcomes.
%   CHECKPOINTMETRICS = GGPCOMPUTERUNMETRICS(SNAPSHOTS, TRAJECTORY,
%   EVALUATIONS, METADATA) produces one long-format row for every
%   snapshot-view-truth combination. H1 and H3 mean the next first and
%   third actual training checkpoints, not raw loop iterations.
%
%   Equal-quota views use Top-25% selection: score_v, anchor_margin, and
%   score_hybrid. The binary label_dyn is reported with its natural
%   positive-set size and is never tie-broken by population row number to
%   manufacture a Top-25% group.

    validateMetadata(metadata);
    if isempty(snapshots) || isempty(trajectory)
        error("GGP:EmptyAuditTrajectory", ...
            "The audit must contain at least one snapshot and one trajectory row.");
    end

    numberOfViews = 4;
    numberOfTruths = 6;
    numberOfRows = numel(snapshots)*numberOfViews*numberOfTruths;
    emptyRow = makeEmptyMetricRow();
    rows = repmat(emptyRow, numberOfRows, 1);
    rowIndex = 0;

    evaluationIDs = evaluations.EvalID(:);
    for snapshotIndex = 1:numel(snapshots)
        snapshot = snapshots(snapshotIndex);
        populationIDs = snapshot.PopulationEvalID(:);
        populationSize = numel(populationIDs);
        if numel(unique(populationIDs)) ~= populationSize || ...
                ~all(ismember(populationIDs, evaluationIDs))
            error("GGP:InvalidEvaluationIdentity", ...
                "Snapshot %d does not contain unique, registered EvalIDs.", snapshotIndex);
        end

        future = ReconstructFutureLabelOutcomes( ...
            snapshots, trajectory, evaluations, snapshotIndex);
        views = makeViews(snapshot, metadata.RGood);
        truths = makeTruths(future);
        stage = GGPStageBin(snapshot.Ratio);

        for viewIndex = 1:numel(views)
            view = views(viewIndex);
            for truthIndex = 1:numel(truths)
                truth = truths(truthIndex);
                metric = GGPBinaryMetrics(view.Selected, truth.Values, view.Score);
                rowIndex = rowIndex + 1;
                row = emptyRow;
                row.SchemaVersion = metadata.SchemaVersion;
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
                row.Stage = stage;
                row.View = view.Name;
                row.SelectionRule = view.SelectionRule;
                row.Truth = truth.Name;
                row.TruthType = truth.Type;
                row.Horizon = truth.Horizon;
                row.Censored = metric.Censored;
                row.PopulationSize = metric.PopulationSize;
                row.SelectedCount = metric.SelectedCount;
                row.SelectedRate = metric.SelectedCount/metric.PopulationSize;
                row.TruthPositiveCount = metric.TruthPositiveCount;
                row.TruePositiveCount = metric.TruePositiveCount;
                row.Precision = metric.Precision;
                row.Recall = metric.Recall;
                row.Chance = metric.Chance;
                row.Lift = metric.Lift;
                row.AUC = metric.AUC;
                if view.SelectionRule == "top25"
                    row.PrecisionAt25 = metric.Precision;
                else
                    row.NativePrecision = metric.Precision;
                end
                if truth.Type == "retention"
                    row.RetentionRate = metric.Precision;
                end
                rows(rowIndex) = row;
            end
        end
    end

    checkpointMetrics = struct2table(rows);
end

function views = makeViews(snapshot, rGood)
    scoreV = double(snapshot.ScoreV(:));
    anchorMargin = double(snapshot.AnchorMargin(:));
    scoreHybrid = double(snapshot.ScoreHybrid(:));
    labelDyn = logical(snapshot.LabelDyn(:));

    hybridTop = selectTopFraction(scoreHybrid, rGood);
    catalogCurrent = logical(snapshot.CatalogCurrent(:));
    if ~isequal(hybridTop, catalogCurrent)
        error("GGP:HybridCatalogMismatch", ...
            "Snapshot %d ScoreHybrid Top-25%% does not reproduce CatalogCurrent.", ...
            snapshot.SnapshotID);
    end

    views = repmat(struct("Name", "", "SelectionRule", "", ...
        "Score", [], "Selected", []), 4, 1);
    views(1) = struct("Name", "score_v", "SelectionRule", "top25", ...
        "Score", scoreV, "Selected", selectTopFraction(scoreV, rGood));
    views(2) = struct("Name", "anchor_margin", "SelectionRule", "top25", ...
        "Score", anchorMargin, "Selected", selectTopFraction(anchorMargin, rGood));
    views(3) = struct("Name", "score_hybrid", "SelectionRule", "top25", ...
        "Score", scoreHybrid, "Selected", catalogCurrent);
    views(4) = struct("Name", "label_dyn", "SelectionRule", "native", ...
        "Score", double(labelDyn), "Selected", labelDyn);
end

function truths = makeTruths(future)
    truths = repmat(struct("Name", "", "Type", "", "Horizon", "", ...
        "Values", []), 6, 1);
    truths(1) = struct("Name", "population_h1", "Type", "retention", ...
        "Horizon", "H1", "Values", future.InPopulationH1);
    truths(2) = struct("Name", "population_h3", "Type", "retention", ...
        "Horizon", "H3", "Values", future.InPopulationH3);
    truths(3) = struct("Name", "population_final", "Type", "retention", ...
        "Horizon", "FINAL", "Values", future.InFinalPopulation);
    truths(4) = struct("Name", "front_h1", "Type", "nondominated", ...
        "Horizon", "H1", "Values", future.NondominatedInArchiveH1);
    truths(5) = struct("Name", "front_h3", "Type", "nondominated", ...
        "Horizon", "H3", "Values", future.NondominatedInArchiveH3);
    truths(6) = struct("Name", "front_final", "Type", "nondominated", ...
        "Horizon", "FINAL", "Values", future.NondominatedInFinalArchive);
end

function selected = selectTopFraction(score, fraction)
    score = score(:);
    if any(~isfinite(score))
        error("GGP:InvalidViewScore", "View scores must be finite.");
    end
    populationSize = numel(score);
    selectedCount = max(1, min(populationSize, ceil(populationSize*fraction)));
    [~, order] = sortrows([-score, (1:populationSize).']);
    selected = false(populationSize, 1);
    selected(order(1:selectedCount)) = true;
end

function validateMetadata(metadata)
    requiredFields = ["SchemaVersion", "Profile", "Problem", "M", ...
        "RequestedD", "ActualD", "Run", "Seed", "RGood"];
    if ~all(isfield(metadata, requiredFields))
        missingFields = requiredFields(~isfield(metadata, requiredFields));
        error("GGP:MissingMetadata", ...
            "metadata is missing required fields: %s", strjoin(missingFields, ", "));
    end
    validateattributes(metadata.RGood, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>', 0, '<=', 0.5}, ...
        mfilename, 'metadata.RGood');
end

function row = makeEmptyMetricRow()
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
        "View", "", ...
        "SelectionRule", "", ...
        "Truth", "", ...
        "TruthType", "", ...
        "Horizon", "", ...
        "Censored", false, ...
        "PopulationSize", NaN, ...
        "SelectedCount", NaN, ...
        "SelectedRate", NaN, ...
        "TruthPositiveCount", NaN, ...
        "TruePositiveCount", NaN, ...
        "Precision", NaN, ...
        "PrecisionAt25", NaN, ...
        "NativePrecision", NaN, ...
        "Recall", NaN, ...
        "Chance", NaN, ...
        "Lift", NaN, ...
        "AUC", NaN, ...
        "RetentionRate", NaN);
end
