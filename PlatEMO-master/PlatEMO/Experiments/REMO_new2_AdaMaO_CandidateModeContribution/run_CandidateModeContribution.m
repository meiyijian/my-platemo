function manifest = run_CandidateModeContribution(stage,profile,options)
%RUN_CANDIDATEMODECONTRIBUTION Execute one gated CMC stage.

    arguments
        stage {mustBeTextScalar}
        profile {mustBeTextScalar}
        options.Problems = strings(0,1)
        options.Ms double = []
        options.Runs double = []
        options.Arms = strings(0,1)
        options.ResultRoot {mustBeTextScalar} = ""
        options.RunAnalysis (1,1) logical = false
    end
    setup = CMCSetupPaths();
    protocol = CMCProtocol(stage,profile);
    resultRoot = string(options.ResultRoot);
    if strlength(resultRoot) == 0
        resultRoot = string(setup.DefaultResultRoot);
    end
    upstream = CMCRequirePreviousGate(protocol,resultRoot);
    arms = CMCResolveArms(protocol,resultRoot,options.Arms);
    jobs = CMCExpandJobs(protocol,arms);
    jobs = filterJobs(jobs,options.Problems,options.Ms,options.Runs);
    if isempty(jobs)
        error('CMC:NoJobsSelected','The requested filters selected no jobs.');
    end
    preflight(jobs);
    CMCWarmupLearningToolboxes();
    paths = CMCStagePaths(protocol,resultRoot);
    ensureFolders(paths);
    if protocol.Stage == "stage0"
        CMCVerifySourceTwin(protocol.Profile,resultRoot);
    end

    manifest = emptyManifest(height(jobs));
    manifest.Stage(:) = protocol.Stage;
    manifest.Profile(:) = protocol.Profile;
    manifest.ProtocolHash(:) = protocol.ProtocolHash;
    manifest.UpstreamDecisionHash(:) = upstream.DecisionHash;
    manifestPath = uniqueManifestPath(paths,protocol);
    priorRng = rng;
    cleanup = onCleanup(@()rng(priorRng));
    fprintf('CMC %s/%s: %d jobs, %d arm(s), output=%s\n', ...
        protocol.Stage,protocol.Profile,height(jobs),height(arms),paths.StageRoot);
    for jobIndex = 1:height(jobs)
        job = jobs(jobIndex,:);
        resultFile = CMCResultPath(paths,job);
        manifest.JobID(jobIndex) = job.JobID;
        manifest.PairedKey(jobIndex) = job.PairedKey;
        manifest.Arm(jobIndex) = job.Arm;
        manifest.ResultFile(jobIndex) = string(resultFile);
        if isfile(resultFile)
            [valid,report] = CMCValidateRunFile( ...
                resultFile,protocol,job,upstream.DecisionHash);
            if valid
                manifest.Status(jobIndex) = "skipped";
                manifest.IGD(jobIndex) = report.IGD;
                manifest.IGDp(jobIndex) = report.IGDp;
                manifest.Runtime(jobIndex) = report.Runtime;
                CMCWriteTableAtomic(manifest,manifestPath);
                continue;
            else
                archived = quarantineInvalidResult( ...
                    paths,resultFile,job);
                manifest.Status(jobIndex) = "invalidated-rerun";
                manifest.Message(jobIndex) = report.Detail+ ...
                    "; archived="+string(archived);
                CMCWriteTableAtomic(manifest,manifestPath);
            end
        end
        folder = fileparts(resultFile);
        if ~isfolder(folder)
            mkdir(folder);
        end
        fprintf('[%d/%d] %s ... ',jobIndex,height(jobs),job.JobID);
        try
            [Problem,Algorithm] = constructJob(protocol,job);
            rng(job.SearchSeed,'twister');
            timer = tic;
            Algorithm.Solve(Problem);
            runtime = toc(timer);
            finalSolutions = Algorithm.result{end,2};
            if isempty(finalSolutions)
                error('CMC:MissingFinalPopulation','Algorithm returned no population.');
            end
            IGD = Problem.CalMetric('IGD',finalSolutions);
            IGDp = Problem.CalMetric('IGDp',finalSolutions);
            [anytimeIGDpAUC,anytimeTrace] = computeAnytimeIGDpAUC( ...
                Problem,Algorithm.result,IGDp);
            finalPopulation = struct('Dec',finalSolutions.decs, ...
                'Obj',finalSolutions.objs,'Con',finalSolutions.cons);
            [activityRows,snapshotRows,referenceRows] = auditTables(Algorithm);
            metadata = makeMetadata(protocol,job,Problem,Algorithm, ...
                runtime,upstream);
            temporaryFile = [resultFile,'.tmp.',char(java.util.UUID.randomUUID),'.mat'];
            save(temporaryFile,'metadata','finalPopulation','IGD','IGDp', ...
                'anytimeIGDpAUC','anytimeTrace','runtime','activityRows', ...
                'snapshotRows','referenceRows','-v7.3');
            [valid,report] = CMCValidateRunFile( ...
                temporaryFile,protocol,job,upstream.DecisionHash);
            if ~valid
                delete(temporaryFile);
                error('CMC:InvalidNewResult','New result failed validation: %s.', ...
                    report.Detail);
            end
            movefile(temporaryFile,resultFile,'f');
            manifest.Status(jobIndex) = "completed";
            manifest.IGD(jobIndex) = IGD;
            manifest.IGDp(jobIndex) = IGDp;
            manifest.Runtime(jobIndex) = runtime;
            fprintf('IGD+=%.4e, %.2fs\n',IGDp,runtime);
        catch exception
            manifest.Status(jobIndex) = "failed";
            manifest.Message(jobIndex) = string(exception.message);
            fprintf('FAILED: %s\n',exception.message);
        end
        CMCWriteTableAtomic(manifest,manifestPath);
    end
    save(strrep(manifestPath,'.csv','.mat'),'manifest','protocol','arms','jobs');
    if options.RunAnalysis
        analyze_CandidateModeContribution(protocol.Stage,protocol.Profile, ...
            'ResultRoot',resultRoot);
    end
end

function archived = quarantineInvalidResult(paths,resultFile,job)
    folder = fullfile(paths.StageRoot,'invalidated_raw',char(job.Arm), ...
        char(job.Problem),sprintf('M%d',job.M));
    if ~isfolder(folder)
        mkdir(folder);
    end
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    archived = fullfile(folder,sprintf('run_%03d_%s_%s.mat', ...
        job.Run,stamp,char(java.util.UUID.randomUUID)));
    [moved,message] = movefile(resultFile,archived,'f');
    if ~moved
        error('CMC:InvalidResultQuarantineFailed', ...
            'Cannot preserve invalid result before rerun: %s.',message);
    end
end

function jobs = filterJobs(jobs,problems,Ms,runs)
    keep = true(height(jobs),1);
    if ~isempty(problems)
        keep = keep & ismember(jobs.Problem,string(problems));
    end
    if ~isempty(Ms)
        keep = keep & ismember(jobs.M,Ms);
    end
    if ~isempty(runs)
        keep = keep & ismember(jobs.Run,runs);
    end
    jobs = jobs(keep,:);
end

function preflight(jobs)
    names = unique([jobs.Problem;jobs.AlgorithmClass]);
    missing = names(arrayfun(@(x)isempty(which(char(x))),names));
    if ~isempty(missing)
        error('CMC:MissingClass','Missing classes: %s.', ...
            strjoin(cellstr(missing),', '));
    end
end

function ensureFolders(paths)
    values = {paths.RawRoot,paths.AnalysisRoot,paths.ManifestRoot,paths.LogRoot};
    for index = 1:numel(values)
        if ~isfolder(values{index})
            mkdir(values{index});
        end
    end
end

function [Problem,Algorithm] = constructJob(protocol,job)
    problemConstructor = str2func(char(job.Problem));
    Problem = problemConstructor('N',protocol.N,'M',job.M, ...
        'D',job.ActualD,'maxFE',protocol.MaxFE);
    algorithmConstructor = str2func(char(job.AlgorithmClass));
    p = protocol.Parameters;
    common = {p.gmax,p.pMix,p.rGood,p.qKeep,p.lambda0,p.nMin,p.nMax, ...
        p.nHarm,p.wConFlag};
    if job.AlgorithmClass == "REMO_new2_AdaMaO_HCV"
        parameters = common;
    else
        parameters = [common,{job.ArmID,protocol.StageNumber, ...
            job.RandomControlSeed,protocol.ReferenceSizes, ...
            protocol.Checkpoints,protocol.RandomReplicates}];
    end
    Algorithm = algorithmConstructor('parameter',parameters, ...
        'run',job.RoutingSeed,'save',protocol.EndpointSaveCount, ...
        'outputFcn',@silentOutput);
end

function [value,trace] = computeAnytimeIGDpAUC(Problem,result,finalIGDp)
    validRows = find(~cellfun(@isempty,result(:,1)));
    fe = cell2mat(result(validRows,1));
    metric = NaN(numel(validRows),1);
    for index = 1:numel(validRows)
        metric(index) = Problem.CalMetric('IGDp',result{validRows(index),2});
    end
    [fe,uniqueIndex] = unique(fe,'stable');
    metric = metric(uniqueIndex);
    if isempty(fe)
        fe = Problem.maxFE;
        metric = finalIGDp;
    else
        [fe,order] = sort(fe(:));
        metric = metric(order);
        [fe,uniqueIndex] = unique(fe,'stable');
        metric = metric(uniqueIndex);
        if fe(end) < Problem.maxFE
            fe(end+1,1) = Problem.maxFE;
            metric(end+1,1) = finalIGDp;
        else
            metric(end) = finalIGDp;
        end
    end
    feRatio = min(1,max(0,fe(:)./Problem.maxFE));
    trace = table(fe(:),feRatio,metric(:), ...
        'VariableNames',{'FE','FERatio','IGDp'});
    value = CMCTraceAUC(trace);
end

function [activity,snapshots,references] = auditTables(Algorithm)
    activity = CMCActivitySchema();
    snapshots = CMCSnapshotSchema();
    references = CMCReferenceSchema();
    if isfield(Algorithm.metric,'cmcActivity')
        activity = Algorithm.metric.cmcActivity;
    end
    if isfield(Algorithm.metric,'cmcSnapshots')
        snapshots = Algorithm.metric.cmcSnapshots;
    end
    if isfield(Algorithm.metric,'cmcReference')
        references = Algorithm.metric.cmcReference;
    end
end

function metadata = makeMetadata(protocol,job,Problem,Algorithm,runtime,upstream)
    metadata = struct( ...
        'SchemaVersion',protocol.SchemaVersion, ...
        'ProtocolVersion',char(protocol.ProtocolVersion), ...
        'ProtocolHash',char(protocol.ProtocolHash), ...
        'Stage',char(protocol.Stage),'Profile',char(protocol.Profile), ...
        'Problem',char(job.Problem),'Family',char(job.Family), ...
        'M',Problem.M,'RequestedD',job.RequestedD,'ActualD',Problem.D, ...
        'N',Problem.N,'MaxFE',protocol.MaxFE,'CompletedFE',Problem.FE, ...
        'Run',job.Run,'SearchSeed',job.SearchSeed, ...
        'RoutingSeed',job.RoutingSeed, ...
        'RandomControlSeed',job.RandomControlSeed, ...
        'Arm',char(job.Arm),'ArmID',job.ArmID, ...
        'AlgorithmClass',class(Algorithm),'JobID',char(job.JobID), ...
        'PairedKey',char(job.PairedKey),'Runtime',runtime, ...
        'UpstreamDecisionHash',char(upstream.DecisionHash), ...
        'EndpointSaveCount',protocol.EndpointSaveCount, ...
        'AnytimeIGDpDefinition',char(protocol.AnytimeIGDpDefinition), ...
        'CompletedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
        'MATLABVersion',char(protocol.ExecutionEnvironment.MATLABVersion), ...
        'Computer',char(protocol.ExecutionEnvironment.Computer), ...
        'HostName',char(protocol.ExecutionEnvironment.HostName));
end

function value = emptyManifest(count)
    names = {'Stage','Profile','ProtocolHash','UpstreamDecisionHash', ...
        'JobID','PairedKey','Arm','Status','ResultFile','Message', ...
        'IGD','IGDp','Runtime'};
    types = {'string','string','string','string','string','string', ...
        'string','string','string','string', ...
        'double','double','double'};
    value = table('Size',[count,numel(names)],'VariableTypes',types, ...
        'VariableNames',names);
    value.IGD(:) = NaN;
    value.IGDp(:) = NaN;
    value.Runtime(:) = NaN;
end

function pathValue = uniqueManifestPath(paths,protocol)
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    pathValue = fullfile(paths.ManifestRoot,sprintf( ...
        'CMC_%s_%s_%s_pid%d.csv',protocol.Stage,protocol.Profile, ...
        stamp,feature('getpid')));
end

function silentOutput(varargin)
end
