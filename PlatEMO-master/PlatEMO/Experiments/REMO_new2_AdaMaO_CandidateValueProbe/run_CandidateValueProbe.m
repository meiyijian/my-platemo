function manifest = run_CandidateValueProbe(profile, varargin)
%RUN_CANDIDATEVALUEPROBE Run the resumable candidate-value probe.
%   MANIFEST = RUN_CANDIDATEVALUEPROBE(PROFILE) runs the "smoke", "pilot" or
%   "formal" protocol over the five candidate-selection arms and measures
%   two metrics: Candidate Survival Rate and oracle batch overlap.
%
%   The run is resumable and idempotent. Each job writes its own MAT file
%   through a temporary file plus post-write validation. Valid existing files
%   are skipped; invalid existing files abort the run and are NEVER
%   overwritten, so a corrupted file cannot be masked by a re-run.
%
%   Name-value filters for subset execution:
%     Problems   problem names, e.g. ["DTLZ2","WFG3"]
%     Ms         objective counts, e.g. [10 20]
%     Runs       run numbers
%     Arms       arm names, e.g. ["V1_POOL_ONLY","V4_FULL"]
%     ResultRoot alternate result directory (used by the tests)
%
%   Examples
%     run_CandidateValueProbe("smoke");
%     run_CandidateValueProbe("formal");
%     run_CandidateValueProbe("formal", "Problems", "WFG3", "Ms", 10);

    if nargin < 1 || isempty(profile)
        profile = "formal";
    end
    profile = validatestring(string(profile), ["smoke", "pilot", "formal"]);

    [pathInfo, pathCleanup] = CVPSetupPaths(); %#ok<ASGLU>
    defaultResultRoot = fullfile(pathInfo.ExperimentDirectory, "results");

    parser = inputParser();
    parser.FunctionName = mfilename();
    addParameter(parser, "Problems", strings(0, 1), @isTextCollection);
    addParameter(parser, "Ms", [], @(value) isnumeric(value) && isvector(value));
    addParameter(parser, "Runs", [], @(value) isnumeric(value) && isvector(value));
    addParameter(parser, "Arms", strings(0, 1), @isTextCollection);
    addParameter(parser, "ResultRoot", defaultResultRoot, @isTextScalar);
    parse(parser, varargin{:});

    config = CVPProtocol(profile);
    jobs = filterJobs(config.Jobs, parser.Results);
    if isempty(jobs)
        error("CVP:NoJobsSelected", "The supplied filters selected no protocol jobs.");
    end

    resultRoot = char(string(parser.Results.ResultRoot));
    warmupLearningToolboxes();

    manifestRows = repmat(makeManifestRow(), numel(jobs), 1);
    manifestTime = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    manifestToken = sprintf('%s_pid%d', manifestTime, feature('getpid'));
    manifestPath = fullfile(resultRoot, "manifests", ...
        sprintf("CVP_%s_manifest_%s.csv", profile, manifestToken));

    fprintf("Candidate-value probe profile: %s (%d jobs, %d arms)\n", ...
        profile, numel(jobs), height(config.Arms));
    for jobIndex = 1:numel(jobs)
        job = jobs(jobIndex);
        outputFile = CVPResultPath(resultRoot, profile, job);
        entry = makeManifestRow();
        entry.Profile = profile;
        entry.Arm = job.Arm;
        entry.ArmID = job.ArmID;
        entry.Problem = job.Problem;
        entry.M = job.M;
        entry.Run = job.Run;
        entry.Seed = job.Seed;
        entry.PairedKey = job.PairedKey;
        entry.File = string(outputFile);

        if isfile(outputFile)
            [isValid, report] = CVPValidateRunFile(outputFile, profile);
            if ~isValid
                entry.Status = "invalid-existing";
                entry.Message = report.Detail;
                manifestRows(jobIndex) = entry;
                writeManifest(manifestRows(1:jobIndex), manifestPath);
                error("CVP:InvalidExistingResult", ...
                    "Existing result is invalid and was not overwritten: %s (%s)", ...
                    outputFile, report.Detail);
            end
            entry.Status = "skipped";
            entry.Message = "valid existing result";
        else
            try
                entry = runSingleJob(job, config, profile, outputFile, entry);
            catch errorInfo
                entry.Status = "failed";
                entry.Message = string(errorInfo.identifier) + ": " + ...
                    string(errorInfo.message);
                manifestRows(jobIndex) = entry;
                writeManifest(manifestRows(1:jobIndex), manifestPath);
                rethrow(errorInfo);
            end
        end

        manifestRows(jobIndex) = entry;
        writeManifest(manifestRows(1:jobIndex), manifestPath);
        fprintf("[%d/%d] %-18s %-6s M%-2d run%03d -> %s\n", ...
            jobIndex, numel(jobs), job.Arm, job.Problem, job.M, job.Run, ...
            entry.Status);
    end

    manifest = struct2table(manifestRows);
    fprintf("Manifest: %s\n", manifestPath);
    fprintf("Next: analyze_CandidateValueProbe(""%s"")\n", profile);
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
    if ~isempty(filters.Arms)
        jobs = jobs(ismember([jobs.Arm], string(filters.Arms)));
    end
end

function entry = runSingleJob(job, config, profile, outputFile, entry)
    savedRandomState = rng();
    randomCleanup = onCleanup(@() rng(savedRandomState)); %#ok<NASGU>
    rng(job.Seed, "twister");

    problem = feval(char(job.Problem), ...
        'N', job.N, 'M', job.M, 'D', job.RequestedD, ...
        'maxFE', job.MaxFE, 'maxRuntime', inf);
    if ~isempty(job.ExpectedActualD) && problem.D ~= job.ExpectedActualD
        error("CVP:UnexpectedProblemDimension", ...
            "%s M%d requested D=%d but instantiated D=%d; expected D=%d.", ...
            job.Problem, job.M, job.RequestedD, problem.D, job.ExpectedActualD);
    end

    parameters = config.Parameters;
    algorithmParameters = {job.ArmID, job.Gmax, parameters.pMix, ...
        parameters.rGood, parameters.qKeep, parameters.lambda0, ...
        parameters.nMin, parameters.nMax, parameters.oracleEvery, ...
        parameters.oraclePoolLimit, parameters.oracleRefSize};
    algorithm = CVP_CandidateProbe( ...
        'parameter', algorithmParameters, ...
        'run', job.Run, ...
        'save', 0, ...
        'outputFcn', @silentOutput);

    wallClock = tic();
    algorithm.Solve(problem);
    wallTime = toc(wallClock);
    if isempty(algorithm.result)
        error("CVP:MissingFinalResult", "The algorithm returned no final result.");
    end

    finalResult = algorithm.result{end, 2};
    IGD = problem.CalMetric('IGD', finalResult);
    IGDp = problem.CalMetric('IGDp', finalResult);
    probeData = algorithm.probeData;
    generations = probeData.Generations;
    summary = CVPSummarizeRun(generations, config.LateStageStart);

    metadata = struct( ...
        "SchemaVersion", config.SchemaVersion, ...
        "Profile", profile, ...
        "Problem", job.Problem, ...
        "Family", job.Family, ...
        "M", job.M, ...
        "RequestedD", job.RequestedD, ...
        "ActualD", problem.D, ...
        "ProblemN", problem.N, ...
        "InitialPopulationN", probeData.PopulationN, ...
        "InitialFE", probeData.InitialFE, ...
        "MaxFE", job.MaxFE, ...
        "CompletedFE", probeData.CompletedFE, ...
        "Gmax", job.Gmax, ...
        "Arm", job.Arm, ...
        "ArmID", job.ArmID, ...
        "Pool", job.Pool, ...
        "Route", job.Route, ...
        "PMix", parameters.pMix, ...
        "RGood", parameters.rGood, ...
        "QKeep", parameters.qKeep, ...
        "Lambda0", parameters.lambda0, ...
        "NMin", parameters.nMin, ...
        "NMax", parameters.nMax, ...
        "OracleEvery", probeData.OracleEvery, ...
        "OraclePoolLimit", probeData.OraclePoolLimit, ...
        "OracleReferenceSize", probeData.OracleReferenceSize, ...
        "LateStageStart", config.LateStageStart, ...
        "Run", job.Run, ...
        "Seed", job.Seed, ...
        "PairedKey", job.PairedKey, ...
        "AlgorithmClass", string(class(algorithm)), ...
        "MeasuredAlgorithmClass", "REMO_new2_AdaMaO_SDEOnly_UniformMix_Original", ...
        "OracleBudgetPolicy", "off-budget Problem.CalObj; never returned to optimizer", ...
        "MATLABVersion", string(version()), ...
        "Computer", string(computer()), ...
        "CompletedAt", string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss")));

    validation = struct( ...
        "WallTime", wallTime, ...
        "AlgorithmRuntime", algorithm.metric.runtime, ...
        "ProbeRuntime", probeData.ProbeRuntime, ...
        "FEWithinBudget", probeData.CompletedFE <= job.MaxFE, ...
        "SurvivalTrackedByHandleIdentity", true);

    outputDirectory = fileparts(outputFile);
    if ~isfolder(outputDirectory)
        [created, message] = mkdir(outputDirectory);
        if ~created
            error("CVP:CreateOutputDirectoryFailed", ...
                "Could not create %s: %s", outputDirectory, message);
        end
    end
    temporaryFile = [tempname(outputDirectory), '.mat'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryFile)); %#ok<NASGU>
    save(temporaryFile, "metadata", "generations", "summary", ...
        "IGD", "IGDp", "validation", "-v7.3");

    [isValid, report] = CVPValidateRunFile(temporaryFile, profile);
    if ~isValid
        error("CVP:PostWriteValidationFailed", ...
            "Generated result failed validation: %s", report.Detail);
    end
    if isfile(outputFile)
        error("CVP:ConcurrentResultCollision", ...
            "Another process created the result before commit: %s", outputFile);
    end
    [moved, moveMessage] = movefile(temporaryFile, outputFile);
    if ~moved
        error("CVP:AtomicMoveFailed", ...
            "Could not commit %s: %s", outputFile, moveMessage);
    end

    entry.Status = "completed";
    entry.Message = sprintf( ...
        "IGD=%.6e; CSR_late=%.4f; Hit=%.4f; gens=%d", ...
        IGD, summary.SurvivalRateLate, summary.OracleHitRate, ...
        report.NumberOfGenerations);
end

function warmupLearningToolboxes()
%WARMUPLEARNINGTOOLBOXES Pay the toolbox JIT cost once, outside the timing.
    savedRandomState = rng();
    randomCleanup = onCleanup(@() rng(savedRandomState)); %#ok<NASGU>
    rng(12345, "twister");
    inputs = rand(20, 4);
    outputs = double(inputs(:, 1) > 0.5);
    network = patternnet(2);
    network.trainParam.showWindow = 0;
    train(network, inputs.', outputs.');
    try
        fitrsvm(inputs, outputs, 'KernelFunction', 'rbf', ...
            'KernelScale', 'auto', 'Standardize', true);
    catch errorInfo
        warning("CVP:SVMWarmupFailed", ...
            ["fitrsvm warm-up failed. The indicator branch will fall back " ...
            "to relation scores, which makes V3 and V4 partly degenerate: " ...
            "%s"], errorInfo.message);
    end
end

function writeManifest(manifestRows, manifestPath)
    manifestDirectory = fileparts(manifestPath);
    if ~isfolder(manifestDirectory)
        mkdir(manifestDirectory);
    end
    manifestTable = struct2table(manifestRows);
    temporaryPath = [tempname(manifestDirectory), '.csv'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryPath)); %#ok<NASGU>
    writetable(manifestTable, temporaryPath);
    [moved, message] = movefile(temporaryPath, manifestPath, "f");
    if ~moved
        error("CVP:ManifestWriteFailed", ...
            "Could not write manifest %s: %s", manifestPath, message);
    end
end

function entry = makeManifestRow()
    entry = struct( ...
        "Profile", "", "Arm", "", "ArmID", NaN, "Problem", "", ...
        "M", NaN, "Run", NaN, "Seed", NaN, "PairedKey", "", ...
        "File", "", "Status", "pending", "Message", "");
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
