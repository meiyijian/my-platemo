function [isValid, report] = DPCValidateReplayFile(filePath, expectedProfile)
%DPCValidateReplayFile - Validate one complementarity replay MAT file
%   TF = DPCValidateReplayFile(filePath) returns true when the replay file
%   satisfies the schema, conservation, and equivalence contracts.
%
%   [TF,REPORT] = DPCValidateReplayFile(...) also returns the validation
%   detail and row counts.
%
%   [...] = DPCValidateReplayFile(filePath,PROFILE) also requires the
%   expected experiment profile.
%
%   See also run_DualPBIComplementarity,
%   DPCComputeComplementarityMetrics

    if nargin < 2
        expectedProfile = "";
    end
    report = struct("Detail", "", "NumberOfRows", 0, ...
        "NumberOfSnapshots", 0);
    isValid = false;
    if ~isfile(filePath)
        report.Detail = "file does not exist";
        return;
    end

    try
        data = load(filePath, "metadata", "complementarityMetrics", ...
            "replayValidation");
    catch errorInfo
        report.Detail = "load failed: " + string(errorInfo.message);
        return;
    end
    requiredVariables = ["metadata", "complementarityMetrics", ...
        "replayValidation"];
    if ~all(isfield(data, requiredVariables))
        report.Detail = "required MAT variables are missing";
        return;
    end
    if ~isstruct(data.metadata) || ...
            ~istable(data.complementarityMetrics) || ...
            ~isstruct(data.replayValidation)
        report.Detail = "MAT variables have invalid types";
        return;
    end

    metadataFields = ["SchemaVersion", "Profile", "Problem", "M", ...
        "RequestedD", "ActualD", "Run", "Seed", "RGood", ...
        "MaxFE", "SourceFile", "TruthPolicy"];
    if ~all(isfield(data.metadata, metadataFields)) || ...
            data.metadata.SchemaVersion ~= 1
        report.Detail = "metadata schema is incomplete or unsupported";
        return;
    end
    if strlength(string(expectedProfile)) > 0 && ...
            string(data.metadata.Profile) ~= string(expectedProfile)
        report.Detail = "profile does not match the requested profile";
        return;
    end

    validationFields = ["EquivalencePass", "CompletedFEMatch", ...
        "FinalPopulationMatch", "IGDMatch", "IGDpMatch", ...
        "MaxPopulationAbsDiff", "IGDAbsDiff", "IGDpAbsDiff"];
    if ~all(isfield(data.replayValidation, validationFields))
        report.Detail = "replay validation fields are incomplete";
        return;
    end
    validationFlags = [data.replayValidation.EquivalencePass, ...
        data.replayValidation.CompletedFEMatch, ...
        data.replayValidation.FinalPopulationMatch, ...
        data.replayValidation.IGDMatch, data.replayValidation.IGDpMatch];
    if ~all(validationFlags)
        report.Detail = "replay equivalence is not PASS";
        return;
    end

    metrics = data.complementarityMetrics;
    requiredColumns = ["SchemaVersion", "Profile", "Problem", "M", ...
        "Run", "Seed", "SnapshotID", "Stage", "Truth", ...
        "Censored", "PopulationSize", "QuotaCount", ...
        "VSelectedCount", "ASelectedCount", "HybridSelectedCount", ...
        "BothCount", "VOnlyCount", "AOnlyCount", "NeitherCount", ...
        "HybridFromBoth", "HybridFromVOnly", "HybridFromAOnly", ...
        "HybridFromNeither", "JaccardVA", "AgreementVA"];
    if isempty(metrics) || ~all(ismember(requiredColumns, ...
            string(metrics.Properties.VariableNames)))
        report.Detail = "complementarity metric columns are incomplete";
        return;
    end
    metadataMatches = ...
        all(metrics.SchemaVersion == data.metadata.SchemaVersion) && ...
        all(metrics.Profile == string(data.metadata.Profile)) && ...
        all(metrics.Problem == string(data.metadata.Problem)) && ...
        all(metrics.M == data.metadata.M) && ...
        all(metrics.Run == data.metadata.Run) && ...
        all(metrics.Seed == data.metadata.Seed);
    if ~metadataMatches
        report.Detail = "metric metadata does not match MAT metadata";
        return;
    end

    partitionTotal = metrics.BothCount + metrics.VOnlyCount + ...
        metrics.AOnlyCount + metrics.NeitherCount;
    hybridTotal = metrics.HybridFromBoth + metrics.HybridFromVOnly + ...
        metrics.HybridFromAOnly + metrics.HybridFromNeither;
    if any(partitionTotal ~= metrics.PopulationSize) || ...
            any(hybridTotal ~= metrics.HybridSelectedCount)
        report.Detail = "set conservation failed";
        return;
    end
    if any(metrics.VSelectedCount ~= metrics.QuotaCount) || ...
            any(metrics.ASelectedCount ~= metrics.QuotaCount) || ...
            any(metrics.HybridSelectedCount ~= metrics.QuotaCount)
        report.Detail = "equal-quota view size is incorrect";
        return;
    end
    boundedNames = ["JaccardVA", "AgreementVA", "JaccardHV", ...
        "JaccardHA", "JaccardVLabelNative", "JaccardHLabelNative", ...
        "UniqueTPRateV", "UniqueTPRateA", "UniquePrecisionV", ...
        "UniquePrecisionA", "UniqueTPShare", "VPrecision", ...
        "APrecision", "HybridPrecision"];
    bounded = metrics{:, boundedNames};
    finiteBounded = bounded(isfinite(bounded));
    if any(finiteBounded < 0 | finiteBounded > 1)
        report.Detail = "a bounded metric is outside [0,1]";
        return;
    end

    [snapshotGroups, snapshotIDs] = findgroups(metrics.SnapshotID);
    rowsPerSnapshot = splitapply(@numel, metrics.SnapshotID, snapshotGroups);
    if any(rowsPerSnapshot ~= 6) || ...
            ~isequal(snapshotIDs, (1:numel(snapshotIDs)).')
        report.Detail = "snapshot rows are not six truths with consecutive IDs";
        return;
    end

    report.Detail = "PASS";
    report.NumberOfRows = height(metrics);
    report.NumberOfSnapshots = numel(snapshotIDs);
    isValid = true;
end

