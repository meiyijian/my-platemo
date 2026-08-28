function [pathInfo, pathCleanup] = CVPSetupPaths()
%CVPSETUPPATHS Put PlatEMO and the probe algorithms on the MATLAB path.
%   [PATHINFO, PATHCLEANUP] = CVPSETUPPATHS() returns path locations and an
%   onCleanup object that restores the caller's original path.
%
%   Shadowing note. The repository contains 30+ same-named copies of REMO
%   helper functions (RefSelect, GetOutput_PBI, DataProcess, ...) in sibling
%   algorithm folders, and addpath(genpath(...)) makes exactly one of them
%   win for the whole session. The probe therefore keeps its own frozen
%   copies inside algorithms/private/, which MATLAB resolves ahead of any
%   path entry when called from algorithms/. This function verifies that the
%   private copies are byte-identical to the shipped algorithm's versions so
%   the probe cannot silently drift from the algorithm it is measuring.

    experimentDirectory = fileparts(mfilename("fullpath"));
    experimentsDirectory = fileparts(experimentDirectory);
    platemoDirectory = fileparts(experimentsDirectory);
    repositoryDirectory = fileparts(platemoDirectory);
    algorithmDirectory = fullfile(platemoDirectory, ...
        "Algorithms", "Multi-objective optimization", ...
        "REMO_new2_AdaMaO_SDEOnly_UniformMix_Original");

    if ~isfolder(algorithmDirectory)
        error("CVP:MissingShippedAlgorithm", ...
            "The measured algorithm folder is missing: %s", algorithmDirectory);
    end

    originalPath = path();
    pathCleanup = onCleanup(@() path(originalPath));
    addpath(genpath(repositoryDirectory));
    rehash();

    requiredSymbols = ["CVP_CandidateProbe", "OperatorGA", "UniformPoint", ...
        "NDSort", "REMO_new2_AdaMaO_SDEOnly_UniformMix_Original"];
    for symbol = requiredSymbols
        if isempty(which(symbol))
            error("CVP:UnresolvedDependency", ...
                "Required MATLAB symbol is not on the path: %s", symbol);
        end
    end

    twins = [ ...
        "HybridPBI_Classification.m"; "GetOutput_PBI.m"; "RefSelect.m"; ...
        "GetRelationPairs.m"; "DataProcess.m"; "onehotconv.m"; ...
        "IndicatorSelectorSDEOnly.m"; "calFitness_SDE.m"; ...
        "Shape_Estimate.m"; "CreateSDECandidateModeStream.m"];
    privateDirectory = fullfile(experimentDirectory, "algorithms", "private");
    mismatches = strings(0, 1);
    for twin = twins'
        localFile = fullfile(privateDirectory, twin);
        shippedFile = fullfile(algorithmDirectory, "private", twin);
        if ~isfile(localFile) || ~isfile(shippedFile)
            mismatches(end+1, 1) = twin + " (missing)"; %#ok<AGROW>
        elseif ~isequal(fileread(localFile), fileread(shippedFile))
            mismatches(end+1, 1) = twin + " (content differs)"; %#ok<AGROW>
        end
    end
    resolveTwin = fullfile(privateDirectory, "ResolveUniformMixMode.m");
    shippedResolve = fullfile(algorithmDirectory, "ResolveUniformMixMode.m");
    if ~isfile(resolveTwin) || ~isfile(shippedResolve) || ...
            ~isequal(fileread(resolveTwin), fileread(shippedResolve))
        mismatches(end+1, 1) = "ResolveUniformMixMode.m"; %#ok<AGROW>
    end
    if ~isempty(mismatches)
        error("CVP:FrozenTwinMismatch", ...
            ["The probe's private copies no longer match the shipped " ...
            "algorithm. Re-copy before trusting any result. Offending " ...
            "files: %s"], strjoin(mismatches, ", "));
    end

    pathInfo = struct( ...
        "ExperimentDirectory", experimentDirectory, ...
        "RepositoryDirectory", repositoryDirectory, ...
        "PlatEMODirectory", platemoDirectory, ...
        "AlgorithmDirectory", algorithmDirectory, ...
        "TwinVerification", "PASS", ...
        "VerifiedTwinCount", numel(twins) + 1);
end
