function [isValid, report] = GGPValidateRunFile(filePath, expectedProfile)
%GGPVALIDATERUNFILE Validate one atomic Good-group Precision result MAT.

    if nargin < 2
        expectedProfile = "";
    end
    report = struct("Detail", "", "NumberOfRows", 0, "NumberOfSnapshots", 0);
    isValid = false;

    if ~isfile(filePath)
        report.Detail = "file does not exist";
        return;
    end

    try
        data = load(filePath, "metadata", "checkpointMetrics", ...
            "finalPopulation", "IGD", "IGDp", "validation");
    catch errorInfo
        report.Detail = "load failed: " + string(errorInfo.message);
        return;
    end

    requiredVariables = ["metadata", "checkpointMetrics", "finalPopulation", ...
        "IGD", "IGDp", "validation"];
    if ~all(isfield(data, requiredVariables))
        report.Detail = "required MAT variables are missing";
        return;
    end
    if ~isstruct(data.metadata) || ~istable(data.checkpointMetrics)
        report.Detail = "metadata must be a struct and checkpointMetrics must be a table";
        return;
    end

    metadataFields = ["SchemaVersion", "Profile", "Problem", "M", ...
        "RequestedD", "ActualD", "ExpectedActualD", "Run", "Seed", ...
        "RGood", "MaxFE", "CompletedFE", "AlgorithmClass", ...
        "InstrumentationSource"];
    if ~all(isfield(data.metadata, metadataFields))
        report.Detail = "metadata fields are incomplete";
        return;
    end
    if data.metadata.SchemaVersion ~= 2
        report.Detail = "unsupported schema version";
        return;
    end
    if strlength(string(expectedProfile)) > 0 && ...
            string(data.metadata.Profile) ~= string(expectedProfile)
        report.Detail = "profile does not match the requested analysis profile";
        return;
    end
    if data.metadata.ActualD ~= data.metadata.ExpectedActualD
        report.Detail = "actual problem dimension does not match the protocol";
        return;
    end
    if data.metadata.CompletedFE ~= data.metadata.MaxFE
        report.Detail = "the run did not consume the complete FE budget";
        return;
    end
    if string(data.metadata.AlgorithmClass) ~= "LVUniformMixAudit_Hybrid"
        report.Detail = "unexpected algorithm class";
        return;
    end

    requiredColumns = ["SchemaVersion", "Profile", "Problem", "M", ...
        "RequestedD", "ActualD", "Run", "Seed", "SnapshotID", ...
        "Generation", "FE", "FERatio", "Stage", "View", ...
        "SelectionRule", "Truth", "TruthType", "Horizon", "Censored", ...
        "PopulationSize", "SelectedCount", "SelectedRate", ...
        "TruthPositiveCount", "TruePositiveCount", "Precision", ...
        "PrecisionAt25", "NativePrecision", "Recall", "Chance", ...
        "Lift", "AUC", "RetentionRate"];
    metrics = data.checkpointMetrics;
    if ~all(ismember(requiredColumns, string(metrics.Properties.VariableNames)))
        report.Detail = "checkpointMetrics columns are incomplete";
        return;
    end
    if isempty(metrics)
        report.Detail = "checkpointMetrics is empty";
        return;
    end

    scalarChecks = ...
        all(metrics.SchemaVersion == data.metadata.SchemaVersion) && ...
        all(metrics.Profile == string(data.metadata.Profile)) && ...
        all(metrics.Problem == string(data.metadata.Problem)) && ...
        all(metrics.M == data.metadata.M) && ...
        all(metrics.Run == data.metadata.Run) && ...
        all(metrics.Seed == data.metadata.Seed);
    if ~scalarChecks
        report.Detail = "checkpoint metadata does not match the MAT metadata";
        return;
    end

    if any(metrics.FERatio < 0 | metrics.FERatio > 1) || ...
            any(metrics.SelectedRate < 0 | metrics.SelectedRate > 1)
        report.Detail = "ratio columns contain out-of-range values";
        return;
    end
    boundedColumns = [metrics.Precision, metrics.PrecisionAt25, ...
        metrics.NativePrecision, metrics.Recall, metrics.Chance, metrics.AUC, ...
        metrics.RetentionRate];
    finiteBounded = boundedColumns(isfinite(boundedColumns));
    if any(finiteBounded < 0 | finiteBounded > 1)
        report.Detail = "probability metrics contain out-of-range values";
        return;
    end
    finiteLift = metrics.Lift(isfinite(metrics.Lift));
    if any(finiteLift < 0)
        report.Detail = "lift contains a negative value";
        return;
    end

    topRows = metrics.SelectionRule == "top25";
    expectedSelected = ceil(metrics.PopulationSize(topRows)*data.metadata.RGood);
    if any(metrics.SelectedCount(topRows) ~= expectedSelected)
        report.Detail = "a Top-25% row has the wrong selected-set size";
        return;
    end
    nativeRows = metrics.SelectionRule == "native";
    if any(~isnan(metrics.PrecisionAt25(nativeRows))) || ...
            any(~isnan(metrics.NativePrecision(topRows)))
        report.Detail = "fixed-quota and native precision fields were mixed";
        return;
    end

    [snapshotGroups, snapshotIDs] = findgroups(metrics.SnapshotID);
    rowsPerSnapshot = splitapply(@numel, metrics.SnapshotID, snapshotGroups);
    if any(rowsPerSnapshot ~= 24)
        report.Detail = "each snapshot must have 4 views x 6 truths = 24 rows";
        return;
    end
    expectedSnapshotIDs = (1:numel(snapshotIDs)).';
    if ~isequal(snapshotIDs, expectedSnapshotIDs)
        report.Detail = "snapshot IDs are not consecutive from 1";
        return;
    end

    if ~isstruct(data.finalPopulation) || ...
            ~all(isfield(data.finalPopulation, ["Dec", "Obj"]))
        report.Detail = "finalPopulation must contain Dec and Obj";
        return;
    end
    if ~isscalar(data.IGD) || ~isfinite(data.IGD) || data.IGD < 0 || ...
            ~isscalar(data.IGDp) || ~isfinite(data.IGDp) || data.IGDp < 0
        report.Detail = "final IGD or IGD+ is invalid";
        return;
    end

    report.Detail = "PASS";
    report.NumberOfRows = height(metrics);
    report.NumberOfSnapshots = numel(snapshotIDs);
    isValid = true;
end
