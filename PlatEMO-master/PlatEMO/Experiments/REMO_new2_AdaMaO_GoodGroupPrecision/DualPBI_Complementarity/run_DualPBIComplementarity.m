function outputs = run_DualPBIComplementarity(profile, options)
%run_DualPBIComplementarity - Run all dual-PBI complementarity replays
%   OUTPUTS = run_DualPBIComplementarity(PROFILE) replays every selected
%   Good-Group Precision job, writes isolated raw results, analyzes all
%   valid results, and returns the single final integrity gate.
%
%   OUTPUTS = run_DualPBIComplementarity(...,Problems=NAMES) restricts
%   execution to the specified problem names.
%
%   OUTPUTS = run_DualPBIComplementarity(...,Ms=COUNTS) restricts the
%   objective counts.
%
%   OUTPUTS = run_DualPBIComplementarity(...,Runs=NUMBERS) restricts the
%   independent run numbers.
%
%   OUTPUTS = run_DualPBIComplementarity(...,ResultRoot=PATH) writes to an
%   alternate isolated result root.
%
%   OUTPUTS = run_DualPBIComplementarity(...,SourceResultRoot=PATH) reads
%   original Good-Group Precision runs from an alternate source root.
%
%   OUTPUTS = run_DualPBIComplementarity(...,RunAnalysis=TF) controls the
%   final analysis step. The default is true.
%
%   See also analyze_DualPBIComplementarity, DPCValidateReplayFile

    arguments
        profile (1,1) string {mustBeMember(profile, ...
            ["smoke", "pilot", "formal"])} = "formal"
        options.Problems string = strings(0, 1)
        options.Ms double = []
        options.Runs double = []
        options.ResultRoot (1,1) string = ""
        options.SourceResultRoot (1,1) string = ""
        options.RunAnalysis (1,1) logical = true
    end

    [pathInfo, pathCleanup] = DPCSetupPaths(); %#ok<ASGLU>
    resultRoot = resolvePathOption( ...
        options.ResultRoot, pathInfo.DefaultResultRoot);
    sourceResultRoot = resolvePathOption( ...
        options.SourceResultRoot, pathInfo.DefaultSourceResultRoot);
    ensureResultDirectories(resultRoot);
    [logPath, logCleanup] = startLog(resultRoot, profile); %#ok<ASGLU>

    config = GGPProtocol(profile, "original");
    jobs = filterJobs(config.Jobs, options);
    if isempty(jobs)
        error("DPC:NoJobsSelected", ...
            "The supplied filters selected no complementarity jobs.");
    end

    warmupLearningToolboxes();
    manifestRows = repmat(makeManifestRow(), numel(jobs), 1);
    manifestToken = sprintf("%s_pid%d", ...
        char(datetime("now", "Format", "yyyyMMdd_HHmmss_SSS")), ...
        feature("getpid"));
    manifestPath = fullfile(resultRoot, "manifests", ...
        sprintf("DPC_%s_manifest_%s.csv", profile, manifestToken));

    fprintf("Dual-PBI complementarity profile: %s (%d jobs)\n", ...
        profile, numel(jobs));
    fprintf("Result root: %s\n", resultRoot);
    fprintf("Log: %s\n", logPath);
    for jobIndex = 1:numel(jobs)
        job = jobs(jobIndex);
        outputFile = GGPResultPath(resultRoot, profile, job);
        sourceFile = GGPResultPath(sourceResultRoot, profile, job);
        entry = makeManifestRow();
        entry.Profile = profile;
        entry.Problem = job.Problem;
        entry.M = job.M;
        entry.Run = job.Run;
        entry.Seed = job.Seed;
        entry.SourceFile = string(sourceFile);
        entry.File = string(outputFile);

        if isfile(outputFile)
            [isValid, report] = DPCValidateReplayFile(outputFile, profile);
            if isValid
                entry.Status = "skipped";
                entry.Message = "valid existing replay";
            else
                entry.Status = "invalid-existing";
                entry.Message = report.Detail;
            end
        else
            try
                entry = runSingleReplay(job, config, profile, sourceFile, ...
                    outputFile, pathInfo, entry);
            catch errorInfo
                entry.Status = "failed";
                entry.Message = string(errorInfo.identifier) + ": " + ...
                    string(errorInfo.message);
            end
        end

        manifestRows(jobIndex) = entry;
        writeTableAtomic(struct2table(manifestRows(1:jobIndex)), ...
            manifestPath);
        fprintf("[%d/%d] %s M%d run%03d -> %s\n", ...
            jobIndex, numel(jobs), job.Problem, job.M, job.Run, ...
            entry.Status);
    end

    manifest = struct2table(manifestRows);
    outputs = struct("ManifestPath", string(manifestPath), ...
        "Manifest", manifest, "LogPath", string(logPath), ...
        "Analysis", [], "FinalGate", table());
    if options.RunAnalysis
        analysis = analyze_DualPBIComplementarity(profile, ...
            "ResultRoot", resultRoot, ...
            "SourceResultRoot", sourceResultRoot);
        outputs.Analysis = analysis;
        outputs.FinalGate = analysis.FinalGate;
        disp(outputs.FinalGate);
    end
end

function entry = runSingleReplay(job, config, profile, sourceFile, ...
        outputFile, pathInfo, entry)
    [sourceIsValid, sourceReport] = GGPValidateRunFile(sourceFile, profile);
    if ~sourceIsValid
        error("DPC:InvalidSourceResult", ...
            "Source result is invalid: %s (%s)", ...
            sourceFile, sourceReport.Detail);
    end
    source = load(sourceFile, "metadata", "finalPopulation", ...
        "IGD", "IGDp");

    savedRandomState = rng();
    randomCleanup = onCleanup(@() rng(savedRandomState));
    rng(job.Seed, "twister");
    problem = feval(char(job.Problem), ...
        'N', job.N, 'M', job.M, 'D', job.RequestedD, ...
        'maxFE', job.MaxFE, 'maxRuntime', inf);
    if problem.D ~= job.ExpectedActualD || ...
            problem.D ~= source.metadata.ActualD
        error("DPC:UnexpectedProblemDimension", ...
            ["%s M%d requested D=%d but instantiated D=%d; " ...
            "expected source D=%d."], job.Problem, job.M, ...
            job.RequestedD, problem.D, source.metadata.ActualD);
    end
    parameters = config.Parameters;
    algorithmParameters = {job.Gmax, parameters.pMix, parameters.rGood, ...
        parameters.qKeep, parameters.lambda0, parameters.nMin, ...
        parameters.nMax};
    algorithm = LVUniformMixAudit_Hybrid( ...
        'parameter', algorithmParameters, 'run', job.Run, 'save', 0, ...
        'outputFcn', @silentOutput);

    wallClock = tic();
    algorithm.Solve(problem);
    wallTime = toc(wallClock);
    if isempty(algorithm.result)
        error("DPC:MissingReplayResult", ...
            "The replay algorithm returned no final result.");
    end
    finalResult = algorithm.result{end, 2};
    replayPopulation = struct("Dec", finalResult.decs, ...
        "Obj", finalResult.objs);
    replayIGD = problem.CalMetric('IGD', finalResult);
    replayIGDp = problem.CalMetric('IGDp', finalResult);
    replayValidation = compareReplay(source, replayPopulation, ...
        replayIGD, replayIGDp, problem.FE);
    replayValidation.WallTime = wallTime;
    if ~replayValidation.EquivalencePass
        error("DPC:ReplayEquivalenceFailure", ...
            ["Replay differs from the source. PopulationDiff=%.3e, " ...
            "IGDDiff=%.3e, IGDpDiff=%.3e, FEMatch=%d."], ...
            replayValidation.MaxPopulationAbsDiff, ...
            replayValidation.IGDAbsDiff, replayValidation.IGDpAbsDiff, ...
            replayValidation.CompletedFEMatch);
    end

    auditData = algorithm.auditData;
    metadata = makeReplayMetadata(source.metadata, job, profile, ...
        sourceFile, pathInfo);
    complementarityMetrics = DPCComputeComplementarityMetrics( ...
        auditData.snapshots, auditData.trajectory, ...
        auditData.evaluations, metadata);

    outputDirectory = fileparts(outputFile);
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    temporaryFile = [tempname(outputDirectory), '.mat'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryFile));
    save(temporaryFile, "metadata", "complementarityMetrics", ...
        "replayValidation", "-v7.3");
    [isValid, report] = DPCValidateReplayFile(temporaryFile, profile);
    if ~isValid
        error("DPC:PostWriteValidationFailure", ...
            "Generated replay file failed validation: %s", report.Detail);
    end
    if isfile(outputFile)
        error("DPC:ConcurrentResultCollision", ...
            "A replay result appeared before atomic commit: %s", outputFile);
    end
    [moved, message] = movefile(temporaryFile, outputFile);
    if ~moved
        error("DPC:AtomicMoveFailure", ...
            "Could not commit %s: %s", outputFile, message);
    end

    entry.Status = "completed";
    entry.Message = sprintf( ...
        "snapshots=%d; popDiff=%.3e; IGDDiff=%.3e; wall=%.1fs", ...
        report.NumberOfSnapshots, replayValidation.MaxPopulationAbsDiff, ...
        replayValidation.IGDAbsDiff, wallTime);
end

function metadata = makeReplayMetadata(sourceMetadata, job, profile, ...
        sourceFile, pathInfo)
    metadata = struct( ...
        "SchemaVersion", 1, ...
        "Profile", profile, ...
        "Problem", job.Problem, ...
        "M", job.M, ...
        "RequestedD", job.RequestedD, ...
        "ActualD", sourceMetadata.ActualD, ...
        "N", sourceMetadata.ProblemN, ...
        "MaxFE", job.MaxFE, ...
        "Run", job.Run, ...
        "Seed", job.Seed, ...
        "RGood", sourceMetadata.RGood, ...
        "SourceFile", string(sourceFile), ...
        "SourceSchemaVersion", sourceMetadata.SchemaVersion, ...
        "SourceAlgorithmClass", string(sourceMetadata.AlgorithmClass), ...
        "ReplayAlgorithmClass", "LVUniformMixAudit_Hybrid", ...
        "TruthPolicy", "on-policy Hybrid trajectory", ...
        "EquivalenceEvidence", string(pathInfo.EquivalenceEvidence), ...
        "CreatedAt", string(datetime("now", ...
            "Format", "yyyy-MM-dd HH:mm:ss")));
end

function validation = compareReplay(source, replayPopulation, ...
        replayIGD, replayIGDp, completedFE)
    sourceRows = sortrows([source.finalPopulation.Obj, ...
        source.finalPopulation.Dec]);
    replayRows = sortrows([replayPopulation.Obj, replayPopulation.Dec]);
    if isequal(size(sourceRows), size(replayRows))
        maxPopulationAbsDiff = max(abs(sourceRows - replayRows), [], "all");
    else
        maxPopulationAbsDiff = inf;
    end
    tolerance = 1e-12;
    validation = struct( ...
        "Tolerance", tolerance, ...
        "CompletedFEMatch", completedFE == source.metadata.CompletedFE, ...
        "FinalPopulationMatch", maxPopulationAbsDiff <= tolerance, ...
        "IGDMatch", abs(replayIGD - source.IGD) <= tolerance, ...
        "IGDpMatch", abs(replayIGDp - source.IGDp) <= tolerance, ...
        "MaxPopulationAbsDiff", maxPopulationAbsDiff, ...
        "IGDAbsDiff", abs(replayIGD - source.IGD), ...
        "IGDpAbsDiff", abs(replayIGDp - source.IGDp), ...
        "SourceCompletedFE", source.metadata.CompletedFE, ...
        "ReplayCompletedFE", completedFE, ...
        "EquivalencePass", false);
    validation.EquivalencePass = validation.CompletedFEMatch && ...
        validation.FinalPopulationMatch && validation.IGDMatch && ...
        validation.IGDpMatch;
end

function jobs = filterJobs(jobs, options)
    if ~isempty(options.Problems)
        jobs = jobs(ismember([jobs.Problem], options.Problems));
    end
    if ~isempty(options.Ms)
        jobs = jobs(ismember([jobs.M], options.Ms));
    end
    if ~isempty(options.Runs)
        jobs = jobs(ismember([jobs.Run], options.Runs));
    end
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
        fitrsvm(inputs, outputs, 'KernelFunction', 'rbf', ...
            'KernelScale', 'auto', 'Standardize', true);
    catch errorInfo
        warning("DPC:SVMWarmupFailed", ...
            "SVM warm-up failed; the frozen fallback remains active: %s", ...
            errorInfo.message);
    end
end

function ensureResultDirectories(resultRoot)
    directories = [fullfile(resultRoot, "raw"), ...
        fullfile(resultRoot, "manifests"), ...
        fullfile(resultRoot, "analysis"), ...
        fullfile(resultRoot, "logs")];
    for directory = directories
        if ~isfolder(directory)
            mkdir(directory);
        end
    end
end

function [logPath, cleanup] = startLog(resultRoot, profile)
    token = char(datetime("now", "Format", "yyyyMMdd_HHmmss_SSS"));
    logPath = fullfile(resultRoot, "logs", ...
        sprintf("DPC_%s_%s.log", profile, token));
    diary(logPath);
    cleanup = onCleanup(@() diary("off"));
end

function value = resolvePathOption(value, defaultValue)
    if strlength(value) == 0
        value = string(defaultValue);
    end
    value = char(value);
end

function writeTableAtomic(dataTable, outputPath)
    outputDirectory = fileparts(outputPath);
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    temporaryPath = [tempname(outputDirectory), '.csv'];
    temporaryCleanup = onCleanup(@() deleteIfPresent(temporaryPath));
    writetable(dataTable, temporaryPath);
    [moved, message] = movefile(temporaryPath, outputPath, "f");
    if ~moved
        error("DPC:ManifestWriteFailure", ...
            "Could not write %s: %s", outputPath, message);
    end
end

function row = makeManifestRow()
    row = struct("Profile", "", "Problem", "", "M", NaN, ...
        "Run", NaN, "Seed", NaN, "SourceFile", "", "File", "", ...
        "Status", "pending", "Message", "");
end

function silentOutput(varargin)
end

function deleteIfPresent(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end
