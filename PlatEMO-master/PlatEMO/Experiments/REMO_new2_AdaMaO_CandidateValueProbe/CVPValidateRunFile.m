function [isValid, report] = CVPValidateRunFile(filePath, profile)
%CVPVALIDATERUNFILE Post-write validation of one probe result file.
%   [ISVALID, REPORT] = CVPVALIDATERUNFILE(FILEPATH, PROFILE) checks that a
%   result file is complete and internally consistent. Invalid existing
%   files are never overwritten by the runner, so this gate is what stops a
%   half-written or stale file from silently entering the analysis.

    report = struct("Detail", "", "NumberOfGenerations", 0, ...
        "NumberOfOracleRows", 0);
    isValid = false;

    if ~isfile(filePath)
        report.Detail = "file does not exist";
        return;
    end

    try
        stored = load(filePath, "metadata", "generations", "summary", ...
            "IGD", "IGDp", "validation");
    catch errorInfo
        report.Detail = "load failed: " + string(errorInfo.message);
        return;
    end

    requiredVariables = ["metadata", "generations", "summary", "IGD", ...
        "IGDp", "validation"];
    missing = requiredVariables(~isfield(stored, requiredVariables));
    if ~isempty(missing)
        report.Detail = "missing variables: " + strjoin(missing, ", ");
        return;
    end

    metadata = stored.metadata;
    requiredMetadata = ["SchemaVersion", "Profile", "Problem", "M", ...
        "ActualD", "MaxFE", "CompletedFE", "Arm", "ArmID", "Run", "Seed", ...
        "PairedKey", "NMax", "OracleEvery", "OraclePoolLimit"];
    missingMetadata = requiredMetadata(~isfield(metadata, requiredMetadata));
    if ~isempty(missingMetadata)
        report.Detail = "missing metadata: " + strjoin(missingMetadata, ", ");
        return;
    end

    if string(metadata.Profile) ~= string(profile)
        report.Detail = sprintf("profile mismatch: file=%s expected=%s", ...
            metadata.Profile, profile);
        return;
    end

    generations = stored.generations;
    if ~isstruct(generations) || isempty(generations)
        report.Detail = "generations is empty";
        return;
    end
    report.NumberOfGenerations = numel(generations);

    if metadata.CompletedFE > metadata.MaxFE
        report.Detail = sprintf("FE overrun: completed=%d max=%d", ...
            metadata.CompletedFE, metadata.MaxFE);
        return;
    end

    survivalRates = [generations.SurvivalRate];
    finite = survivalRates(isfinite(survivalRates));
    if ~isempty(finite) && (any(finite < 0) || any(finite > 1))
        report.Detail = "survival rate outside [0,1]";
        return;
    end

    hitRates = [generations.OracleHitRate];
    finiteHits = hitRates(isfinite(hitRates));
    if ~isempty(finiteHits) && (any(finiteHits < 0) || any(finiteHits > 1))
        report.Detail = "oracle hit rate outside [0,1]";
        return;
    end
    report.NumberOfOracleRows = nnz([generations.OracleValid]);

    if ~isscalar(stored.IGD) || ~isnumeric(stored.IGD)
        report.Detail = "IGD is not a numeric scalar";
        return;
    end
    if ~isfinite(stored.IGD)
        report.Detail = "IGD is not finite";
        return;
    end

    isValid = true;
    report.Detail = sprintf("ok: %d generations, %d oracle rows", ...
        report.NumberOfGenerations, report.NumberOfOracleRows);
end
