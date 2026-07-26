function manifest = run_ConfidenceProbe_experiment(profile,outputDir)
%RUN_CONFIDENCEPROBE_EXPERIMENT Run one approved confidence-probe profile.
%   Existing valid files are skipped. Existing invalid files are blocked
%   and never overwritten, so interrupted experiments are safely resumable.

    if nargin < 1 || isempty(profile)
        profile = 'smoke';
    end
    protocol = ConfidenceProbeProtocol(profile);

    thisDir = fileparts(mfilename('fullpath'));
    platemoRoot = fileparts(fileparts(thisDir));
    addpath(genpath(platemoRoot));
    if nargin < 2 || isempty(outputDir)
        outputDir = fullfile(thisDir,'results');
    end
    if ~(ischar(outputDir) || ...
            (isstring(outputDir) && isscalar(outputDir)))
        error('AdaMaO:InvalidConfidenceProbeOutputDirectory', ...
            'outputDir must be a character vector or scalar string.');
    end
    outputDir = char(outputDir);

    preflight(protocol);
    runRoot = fullfile(outputDir,protocol.profile);
    if ~isfolder(runRoot)
        mkdir(runRoot);
    end

    priorRng = rng;
    restoreRng = onCleanup(@()rng(priorRng));
    manifest = emptyManifest(height(protocol.jobs));
    fprintf('Confidence probe %s: %d job(s), output=%s\n', ...
        protocol.profile,height(protocol.jobs),runRoot);

    for jobIndex = 1:height(protocol.jobs)
        job = protocol.jobs(jobIndex,:);
        resultFolder = fullfile(runRoot,char(job.Problem), ...
            sprintf('M%d',job.M));
        resultFile = fullfile(resultFolder, ...
            sprintf('run_%03d.mat',job.Run));
        manifest.JobID(jobIndex) = job.JobID;
        manifest.ResultFile(jobIndex) = string(resultFile);

        if isfile(resultFile)
            [valid,message,metrics] = ...
                ValidateConfidenceProbeResultFile( ...
                resultFile,protocol,job);
            if valid
                manifest.Status(jobIndex) = "skipped";
                manifest.IGD(jobIndex) = metrics.IGD;
                manifest.IGDp(jobIndex) = metrics.IGDp;
                manifest.Runtime(jobIndex) = metrics.runtime;
                fprintf('[%d/%d] SKIP  %s\n', ...
                    jobIndex,height(protocol.jobs),job.JobID);
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

        fprintf('[%d/%d] RUN   %s ... ', ...
            jobIndex,height(protocol.jobs),job.JobID);
        temporaryFile = [resultFile,'.tmp.mat'];
        try
            problemConstructor = str2func(char(job.Problem));
            algorithmConstructor = str2func(char(job.AlgorithmClass));
            Problem = problemConstructor( ...
                'N',job.N,'M',job.M,'D',job.ActualD, ...
                'maxFE',job.MaxFE);
            parameters = {[],job.Gmax,[],[],[],[],[],[],[],[]};
            Algorithm = algorithmConstructor( ...
                'parameter',parameters,'save',0,'run',job.Run, ...
                'outputFcn',@silentOutput);

            runTimer = tic;
            rng(job.Seed,'twister');
            Algorithm.Solve(Problem);
            runtime = toc(runTimer);

            finalPopulation = lastPopulation(Algorithm);
            if isempty(finalPopulation)
                error('AdaMaO:MissingConfidenceProbeFinalPopulation', ...
                    'The algorithm returned no final Archive.');
            end
            if ~isfield(Algorithm.metric,'confidenceProbe')
                error('AdaMaO:MissingConfidenceProbeMetric', ...
                    'The algorithm did not return confidenceProbe data.');
            end
            confidenceProbe = Algorithm.metric.confidenceProbe;
            IGD = Problem.CalMetric('IGD',finalPopulation);
            IGDp = Problem.CalMetric('IGDp',finalPopulation);
            metadata = makeMetadata( ...
                protocol,job,Problem,Algorithm,confidenceProbe,runtime);

            save(temporaryFile,'metadata','confidenceProbe', ...
                'finalPopulation','IGD','IGDp','runtime','-v7.3');
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

    writetable(manifest,fullfile(runRoot, ...
        'ConfidenceProbe_run_manifest.csv'));
    save(fullfile(runRoot,'ConfidenceProbe_run_manifest.mat'), ...
        'manifest','protocol');
end

function preflight(protocol)
    names = [string(protocol.problems),string(protocol.algorithmClass)];
    missing = strings(0,1);
    for name = names
        if isempty(which(char(name)))
            missing(end+1,1) = name; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        error('AdaMaO:MissingConfidenceProbeClass', ...
            'Required class(es) unavailable: %s.', ...
            strjoin(cellstr(missing),', '));
    end
end

function population = lastPopulation(Algorithm)
    population = [];
    if isempty(Algorithm.result)
        return;
    end
    index = find(~cellfun(@isempty,Algorithm.result(:,2)),1,'last');
    if ~isempty(index)
        population = Algorithm.result{index,2};
    end
end

function manifest = emptyManifest(rowCount)
    manifest = table('Size',[rowCount,7], ...
        'VariableTypes',{'string','string','string','string', ...
        'double','double','double'}, ...
        'VariableNames',{'JobID','Status','ResultFile','Message', ...
        'IGD','IGDp','Runtime'});
    manifest.IGD(:) = nan;
    manifest.IGDp(:) = nan;
    manifest.Runtime(:) = nan;
end

function metadata = makeMetadata( ...
    protocol,job,Problem,Algorithm,confidenceProbe,runtime)
    metadata = struct();
    metadata.schemaVersion = protocol.schemaVersion;
    metadata.profile = protocol.profile;
    metadata.problem = char(job.Problem);
    metadata.family = char(job.Family);
    metadata.M = Problem.M;
    metadata.requestedD = job.RequestedD;
    metadata.actualD = Problem.D;
    metadata.N = Problem.N;
    metadata.initialFE = observedInitialFE(confidenceProbe);
    metadata.maxFE = job.MaxFE;
    metadata.completedFE = Problem.FE;
    metadata.gmax = job.Gmax;
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

function initialFE = observedInitialFE(probe)
    names = fieldnames(probe.columns);
    values = zeros(0,1);
    for i = 1:numel(names)
        name = names{i};
        feColumn = find(strcmp(probe.columns.(name),'FE'),1);
        values = [values;probe.(name)(:,feColumn)]; %#ok<AGROW>
    end
    if isempty(values)
        error('AdaMaO:MissingConfidenceProbeInitialFE', ...
            'The confidence probe contains no FE observations.');
    end
    initialFE = min(values);
end

function silentOutput(varargin)
% Intentionally empty: suppress figures and generation text.
end
