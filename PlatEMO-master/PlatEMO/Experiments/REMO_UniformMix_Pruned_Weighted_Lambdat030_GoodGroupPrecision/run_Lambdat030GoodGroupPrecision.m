function manifest = run_Lambdat030GoodGroupPrecision(profile, varargin)
%RUN_LAMBDAT030GOODGROUPPRECISION Run the resumable Lambdat030 Good-group
%   Precision experiment.
%   MANIFEST = RUN_LAMBDAT030GOODGROUPPRECISION(PROFILE) runs the "smoke",
%   "pilot", or "formal" protocol. Formal results use the selected three
%   problems (DTLZ2, DTLZ4, DTLZ5; see SELECTED_PROBLEMS.md), M=10/20,
%   requested D=30, maxFE=500, and 25 explicitly enumerated independent
%   seeds per problem-objective configuration. Problem indices and seeds
%   match PWGGPStableSeed so every run pairs with the existing lambda_t=0.50
%   PWGGP results for the shared problems.
%
%   Name-value filters support safe subset execution:
%     Problems  - problem names, for example ["DTLZ2", "DTLZ4"]
%     Ms        - objective counts
%     Runs      - run numbers
%     ResultRoot- alternate result directory, mainly for tests
%
%   Each completed run is written to its own MAT file through a temporary
%   file and post-write validation. Valid existing files are skipped;
%   invalid existing files are never overwritten.

    if nargin < 1 || isempty(profile)
        profile = "formal";
    end
    profile = validatestring(string(profile), ["smoke", "pilot", "formal"]);

    [pathInfo, pathCleanup] = LTGGPSetupPaths(); %#ok<ASGLU>
    defaultResultRoot = fullfile(pathInfo.ExperimentDirectory, "results");

    parser = inputParser();
    parser.FunctionName = mfilename();
    addParameter(parser, "Problems", strings(0, 1), @isTextCollection);
    addParameter(parser, "Ms", [], @(value) isnumeric(value) && isvector(value));
    addParameter(parser, "Runs", [], @(value) isnumeric(value) && isvector(value));
    addParameter(parser, "ResultRoot", defaultResultRoot, @isTextScalar);
    parse(parser, varargin{:});

    if string(profile) == "formal"
        assert(~isempty(parser.Results.Problems) && numel(unique(string(parser.Results.Problems))) <= 3, ...
            'LTGGP:SelectionRequired', 'Specify the selected problems (max three); full-suite execution is disabled.');
    end
    config = LTGGPProtocol(profile);
    assert(isfile(pathInfo.EquivalenceEvidence), 'LTGGP:MissingGate', 'Run verify_LTGGP first.');
    assert(strtrim(string(fileread(pathInfo.EquivalenceEvidence))) == "PASS", 'Lambdat030 equivalence failed');
    jobs = filterJobs(config.Jobs, parser.Results);
    if isempty(jobs)
        error("LTGGP:NoJobsSelected", "The supplied filters selected no protocol jobs.");
    end

    resultRoot = char(string(parser.Results.ResultRoot));
    warmupLearningToolboxes();
    manifestRows = repmat(makeManifestRow(), numel(jobs), 1);
    manifestTime = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    manifestToken = sprintf('%s_pid%d', manifestTime, feature('getpid'));
    manifestPath = fullfile(resultRoot, "manifests", ...
        sprintf("LTGGP_%s_manifest_%s.csv", profile, manifestToken));

    fprintf("Lambdat030 Good-group Precision profile: %s (%d jobs)\n", profile, numel(jobs));
    for jobIndex = 1:numel(jobs)
        job = jobs(jobIndex);
        outputFile = LTGGPResultPath(resultRoot, profile, job);
        entry = makeManifestRow();
        entry.Profile = profile;
        entry.Problem = job.Problem;
        entry.M = job.M;
        entry.Run = job.Run;
        entry.Seed = job.Seed;
        entry.PairedKey = job.PairedKey;
        entry.File = string(outputFile);

        if isfile(outputFile)
            [isValid, report] = LTGGPValidateRunFile(outputFile, profile);
            if ~isValid
                entry.Status = "invalid-existing";
                entry.Message = report.Detail;
                manifestRows(jobIndex) = entry;
                writeManifest(manifestRows(1:jobIndex), manifestPath);
                error("LTGGP:InvalidExistingResult", ...
                    "Existing result is invalid and was not overwritten: %s (%s)", ...
                    outputFile, report.Detail);
            end
            entry.Status = "skipped";
            entry.Message = "valid existing result";
        else
            try
                entry = runSingleJob(job, config, profile, outputFile, pathInfo, entry);
            catch errorInfo
                entry.Status = "failed";
                entry.Message = string(errorInfo.identifier) + ": " + string(errorInfo.message);
                manifestRows(jobIndex) = entry;
                writeManifest(manifestRows(1:jobIndex), manifestPath);
                rethrow(errorInfo);
            end
        end

        manifestRows(jobIndex) = entry;
        writeManifest(manifestRows(1:jobIndex), manifestPath);
        fprintf("[%d/%d] %s M%d run%03d -> %s\n", ...
            jobIndex, numel(jobs), job.Problem, job.M, job.Run, entry.Status);
    end

    manifest = struct2table(manifestRows);
    fprintf("Manifest: %s\n", manifestPath);
end

function jobs = filterJobs(jobs, filters)
    if ~isempty(filters.Problems)
        jobs = jobs(ismember([jobs.Problem], string(filters.Problems)));
    end
    if ~isempty(filters.Ms)
        jobs = jobs(ismember([jobs.M], filters.Ms));
    end
    if ~isempty(filters.Runs)
        jobs = jobs(ismember([jobs.Run], filters.Runs));
    end
end

function entry = runSingleJob(job, config, profile, outputFile, pathInfo, entry)
    savedRandomState = rng();
    randomCleanup = onCleanup(@() rng(savedRandomState));
    rng(job.Seed, "twister");

    problem = feval(char(job.Problem), ...
        'N', job.N, ...
        'M', job.M, ...
        'D', job.RequestedD, ...
        'maxFE', job.MaxFE, ...
        'maxRuntime', inf);
    if problem.D ~= job.ExpectedActualD
        error("LTGGP:UnexpectedProblemDimension", ...
            "%s M%d requested D=%d but instantiated D=%d; expected D=%d.", ...
            job.Problem, job.M, job.RequestedD, problem.D, job.ExpectedActualD);
    end

    parameters = config.Parameters;
    algorithmParameters = {job.Gmax, parameters.pMix, parameters.rGood, ...
        parameters.qKeep, parameters.nMax};
    algorithm = LTGGPAudit( ...
        'parameter', algorithmParameters, ...
        'run', job.Run, ...
        'save', 0, ...
        'outputFcn', @silentOutput);

    wallClock = tic();
    algorithm.Solve(problem);
    wallTime = toc(wallClock);
    if isempty(algorithm.result)
        error("LTGGP:MissingFinalResult", "The algorithm returned no final result.");
    end

    finalResult = algorithm.result{end, 2};
    IGD = problem.CalMetric('IGD', finalResult);
    IGDp = problem.CalMetric('IGDp', finalResult);
    auditData = algorithm.auditData;

    metadata = struct( ...
        "SchemaVersion", config.SchemaVersion, ...
        "Profile", profile, ...
        "Problem", job.Problem, ...
        "Family", job.Family, ...
        "M", job.M, ...
        "RequestedD", job.RequestedD, ...
        "ActualD", problem.D, ...
        "ExpectedActualD", job.ExpectedActualD, ...
        "ProblemN", auditData.populationN, ...
        "InitialFE", auditData.initialFE, ...
        "MaxFE", job.MaxFE, ...
        "CompletedFE", auditData.completedFE, ...
        "Gmax", job.Gmax, ...
        "PMix", parameters.pMix, ...
        "LambdaT", 0.30, ...
        "RGood", parameters.rGood, ...
        "QKeep", parameters.qKeep, ...
        "NMax", parameters.nMax, ...
        "Run", job.Run, ...
        "Seed", job.Seed, ...
        "PairedKey", job.PairedKey, ...
        "AlgorithmClass", string(class(algorithm)), ...
        "FrozenAlgorithmClass", "REMO_UniformMix_Pruned_Weighted_Lambdat030", ...
        "InstrumentationSource", "stable-EvalID LabelValidation audit", ...
        "EquivalenceEvidence", string(pathInfo.EquivalenceEvidence), ...
        "TruthPolicy", "on-policy Lambdat030 trajectory", ...
        "MATLABVersion", string(version()), ...
        "Computer", string(computer()), ...
        "CompletedAt", string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss")));

    checkpointMetrics = LTGGPComputeRunMetrics( ...
        auditData.snapshots, auditData.trajectory, auditData.evaluations, metadata);
    finalPopulation = struct("Dec", finalResult.decs, "Obj", finalResult.objs);
    validation = struct( ...
        "WallTime", wallTime, ...
        "AlgorithmRuntime", algorithm.metric.runtime, ...
        "AuditRuntime", auditData.auditRuntime, ...
        "StableEvaluationIDs", true, ...
        "SearchEquivalenceGate", "PASS", ...
        "OnPolicyOutcome", true);

    outputDirectory = fileparts(outputFile);
    if ~isfolder(outputDirectory)
        [created, message] = mkdir(outputDirectory);
        if ~created
            error("LTGGP:CreateOutputDirectoryFailed", ...
                "Could not create %s: %s", outputDirectory, message);
        end
    end
    temporaryFile = [tempname(outputDirectory), '.mat'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryFile));
    save(temporaryFile, "metadata", "checkpointMetrics", "finalPopulation", ...
        "IGD", "IGDp", "validation", "auditData", "-v7.3");

    [isValid, report] = LTGGPValidateRunFile(temporaryFile, profile);
    if ~isValid
        error("LTGGP:PostWriteValidationFailed", ...
            "Generated result failed validation: %s", report.Detail);
    end
    if isfile(outputFile)
        error("LTGGP:ConcurrentResultCollision", ...
            "Another process created the result before commit: %s", outputFile);
    end
    [moved, moveMessage] = movefile(temporaryFile, outputFile);
    if ~moved
        error("LTGGP:AtomicMoveFailed", ...
            "Could not commit %s: %s", outputFile, moveMessage);
    end

    entry.Status = "completed";
    entry.Message = sprintf("IGD=%.6e; IGD+=%.6e; checkpoints=%d", ...
        IGD, IGDp, report.NumberOfSnapshots);
end

function warmupLearningToolboxes()
    savedRandomState = rng();
    randomCleanup = onCleanup(@() rng(savedRandomState));
    rng(12345, "twister");
    inputs = rand(20, 4);
    outputs = double(inputs(:, 1) > 0.5);
    network = patternnet(2);
    network.trainParam.showWindow = 0;
    train(network, inputs.', outputs.');
    try
        fitrsvm(inputs, outputs, ...
            'KernelFunction', 'rbf', ...
            'KernelScale', 'auto', ...
            'Standardize', true);
    catch errorInfo
        warning("LTGGP:SVMWarmupFailed", ...
            "SVM warm-up failed; the audited algorithm will use its frozen fallback: %s", ...
            errorInfo.message);
    end
end

function writeManifest(manifestRows, manifestPath)
    manifestDirectory = fileparts(manifestPath);
    if ~isfolder(manifestDirectory)
        mkdir(manifestDirectory);
    end
    manifestTable = struct2table(manifestRows);
    temporaryPath = [tempname(manifestDirectory), '.csv'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryPath));
    writetable(manifestTable, temporaryPath);
    [moved, message] = movefile(temporaryPath, manifestPath, "f");
    if ~moved
        error("LTGGP:ManifestWriteFailed", ...
            "Could not write manifest %s: %s", manifestPath, message);
    end
end

function entry = makeManifestRow()
    entry = struct( ...
        "Profile", "", ...
        "Problem", "", ...
        "M", NaN, ...
        "Run", NaN, ...
        "Seed", NaN, ...
        "PairedKey", "", ...
        "File", "", ...
        "Status", "pending", ...
        "Message", "");
end

function silentOutput(varargin)
end

function deleteIfPresent(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end

function isValid = isTextCollection(value)
    isValid = isstring(value) || ischar(value) || iscellstr(value);
end

function isValid = isTextScalar(value)
    isValid = (isstring(value) && isscalar(value)) || ischar(value);
end
