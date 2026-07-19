function manifest = run_CPR_experiment(profile,outputDir)
%RUN_CPR_EXPERIMENT Execute a reproducible CPR experiment profile.
%   MANIFEST = RUN_CPR_EXPERIMENT(PROFILE,OUTPUTDIR) executes the expanded
%   protocol without calling platemo. OUTPUTDIR is the experiment root;
%   results are written beneath FE300/FE500 and the profile name. Existing
%   completed run files are skipped.

    if nargin < 1 || isempty(profile)
        profile = 'screening';
    end
    protocol = CPRExperimentProtocol(profile);

    thisDir = fileparts(mfilename('fullpath'));
    platemoRoot = fileparts(fileparts(thisDir));
    addpath(genpath(platemoRoot));
    if nargin < 2 || isempty(outputDir)
        outputDir = fullfile(thisDir,'results');
    end
    if ~(ischar(outputDir) || (isstring(outputDir) && isscalar(outputDir)))
        error('AdaMaO:InvalidCPROutputDirectory', ...
            'outputDir must be a character vector or scalar string.');
    end
    outputDir = char(outputDir);

    preflightClasses(protocol);
    runRoot = fullfile(outputDir,protocol.resultBudgetFolder, ...
        protocol.resultProfileFolder);
    if ~isfolder(runRoot)
        mkdir(runRoot);
    end

    priorRng = rng;
    restoreRng = onCleanup(@()rng(priorRng));
    manifest = emptyManifest(height(protocol.jobs));
    fprintf('CPR %s: %d jobs, FE=%d, output=%s\n', ...
        protocol.profile,height(protocol.jobs),protocol.maxFE,runRoot);

    for jobIndex = 1:height(protocol.jobs)
        job = protocol.jobs(jobIndex,:);
        resultFolder = fullfile(runRoot,char(job.Problem), ...
            sprintf('M%d',job.M),char(job.Algorithm));
        resultFile = fullfile(resultFolder,sprintf('run_%03d.mat',job.Run));
        manifest.JobID(jobIndex) = job.JobID;
        manifest.ResultFile(jobIndex) = string(resultFile);

        if isfile(resultFile)
            [valid,message,metrics] = ValidateCPRResultFile(resultFile,protocol,job);
            if valid
                manifest.Status(jobIndex) = "skipped";
                manifest.IGD(jobIndex) = metrics.IGD;
                manifest.IGDp(jobIndex) = metrics.IGDp;
                manifest.Runtime(jobIndex) = metrics.runtime;
                fprintf('[%d/%d] SKIP %s\n',jobIndex,height(protocol.jobs),job.JobID);
            else
                manifest.Status(jobIndex) = "invalid-existing";
                manifest.Message(jobIndex) = string(message);
                fprintf('[%d/%d] BLOCK %s: %s\n', ...
                    jobIndex,height(protocol.jobs),job.JobID,message);
            end
            continue;
        end
        if ~isfolder(resultFolder)
            mkdir(resultFolder);
        end

        fprintf('[%d/%d] RUN  %s ... ',jobIndex,height(protocol.jobs),job.JobID);
        try
            problemConstructor = str2func(char(job.Problem));
            algorithmConstructor = str2func(char(job.AlgorithmClass));
            Problem = problemConstructor('M',job.M,'D',job.ActualD, ...
                'maxFE',protocol.maxFE);
            Algorithm = algorithmConstructor('save',0,'run',job.Run, ...
                'outputFcn',@silentOutput);

            runTimer = tic;
            rng(job.Seed,'twister');
            Algorithm.Solve(Problem);
            runtime = toc(runTimer);

            if isempty(Algorithm.result) || isempty(Algorithm.result{end,2})
                error('AdaMaO:MissingCPRFinalPopulation', ...
                    'The algorithm returned no final population.');
            end
            finalPopulation = Algorithm.result{end,2};
            IGD = Problem.CalMetric('IGD',finalPopulation);
            IGDp = Problem.CalMetric('IGDp',finalPopulation);
            metadata = makeMetadata(protocol,job,Problem,Algorithm,runtime);

            temporaryFile = [resultFile,'.tmp.mat'];
            save(temporaryFile,'finalPopulation','IGD','IGDp','runtime','metadata','-v7.3');
            movefile(temporaryFile,resultFile,'f');
            manifest.Status(jobIndex) = "completed";
            manifest.IGD(jobIndex) = IGD;
            manifest.IGDp(jobIndex) = IGDp;
            manifest.Runtime(jobIndex) = runtime;
            fprintf('IGD=%.4e, %.2fs\n',IGD,runtime);
        catch exception
            manifest.Status(jobIndex) = "failed";
            manifest.Message(jobIndex) = string(exception.message);
            fprintf('FAILED: %s\n',exception.message);
        end
    end

    writetable(manifest,fullfile(runRoot,'CPR_run_manifest.csv'));
    save(fullfile(runRoot,'CPR_run_manifest.mat'),'manifest','protocol');
end

function preflightClasses(protocol)
    missing = strings(0,1);
    names = [string(protocol.problems),string(protocol.algorithmClasses)];
    for name = names
        if isempty(which(char(name)))
            missing(end+1,1) = name; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        error('AdaMaO:MissingCPRClass', ...
            'Required problem or algorithm classes are unavailable: %s.', ...
            strjoin(cellstr(missing),', '));
    end
end

function manifest = emptyManifest(rowCount)
    manifest = table('Size',[rowCount,7], ...
        'VariableTypes',{'string','string','string','string','double','double','double'}, ...
        'VariableNames',{'JobID','Status','ResultFile','Message','IGD','IGDp','Runtime'});
    manifest.IGD(:) = nan;
    manifest.IGDp(:) = nan;
    manifest.Runtime(:) = nan;
end

function metadata = makeMetadata(protocol,job,Problem,Algorithm,runtime)
    metadata = struct();
    metadata.profile = protocol.profile;
    metadata.budgetFolder = protocol.resultBudgetFolder;
    metadata.problem = char(job.Problem);
    metadata.family = char(job.Family);
    metadata.M = Problem.M;
    metadata.requestedD = job.RequestedD;
    metadata.actualD = Problem.D;
    metadata.maxFE = protocol.maxFE;
    metadata.run = job.Run;
    metadata.seed = job.Seed;
    metadata.algorithmLabel = char(job.Algorithm);
    metadata.algorithmClass = class(Algorithm);
    metadata.jobID = char(job.JobID);
    metadata.pairedKey = sprintf('%s_M%d_run%03d_seed%d', ...
        job.Problem,job.M,job.Run,job.Seed);
    metadata.runtime = runtime;
    metadata.algorithmRuntime = Algorithm.metric.runtime;
    metadata.completedAt = datestr(now,30);
    metadata.matlabVersion = version;
    metadata.computer = computer;
end

function silentOutput(varargin)
% Deliberately empty: suppress PlatEMO generation output and figures.
end
