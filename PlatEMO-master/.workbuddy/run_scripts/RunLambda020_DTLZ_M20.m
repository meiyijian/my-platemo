function summary = RunLambda020_DTLZ_M20(workers)
%RunLambda020_DTLZ_M20 Run the lambda020 arm on the full DTLZ series at M=20.
%   RunLambda020_DTLZ_M20(W) evaluates DTLZ1..DTLZ7 with M=20, D=30, N=100
%   and maxFE=300, using run IDs 1..18, that is eighteen runs per problem,
%   spread over W process workers.
%   Only the variant arm is executed, with the parameter vector
%   {3000,0.50,0.25,0.70,6,0.20} for the algorithm
%   REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020.
%   Seeds follow the eighteen-run batch already stored under the 20-objective
%   dataset, that is 20260912 + problemIndex*1000 + runId, with no term for
%   the number of objectives. The run IDs therefore line up with the stored
%   batch and the same seeds are reused.
%   Result files land in the shared dataset folder as .mat files. Every
%   other product, such as the source manifest, the per-round records and
%   the failure reports, goes to the system temporary directory, so the
%   dataset folder ends up holding result files and nothing else.
%   Existing result files are never overwritten: a run whose file is
%   already stored is skipped, which makes the runner restartable.

    if nargin < 1, workers = 6; end
    if (ischar(workers) || isstring(workers)) && strcmpi(workers,'max')
        localCluster = parcluster('Processes');
        logicalCPUs = str2double(getenv('NUMBER_OF_PROCESSORS'));
        assert(isfinite(logicalCPUs) && logicalCPUs >= 1,'Cannot read CPU limit.');
        workers = min(localCluster.NumWorkers,logicalCPUs);
        fprintf('Maximum local concurrency: %d (profile=%d, logical CPUs=%d).\n', ...
            workers,localCluster.NumWorkers,logicalCPUs);
    end
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});

    algorithm = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020';
    cfg = configuration();
    addpath(genpath(cfg.platform));
    addpath(cfg.root);
    scriptFolder = fileparts(mfilename('fullpath'));
    addpath(scriptFolder);
    assert(strcmpi(fileparts(which(algorithm)),cfg.root),'Wrong algorithm on the path.');
    if ~isfolder(cfg.scratch), mkdir(cfg.scratch); end
    if ~isfolder(cfg.recordsFolder), mkdir(cfg.recordsFolder); end
    if ~isfolder(cfg.dataFolder), mkdir(cfg.dataFolder); end

    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    manifest = sourceManifest(cfg.root);
    manifestFile = fullfile(cfg.scratch,['sources_',stamp,'.json']);
    writeManifest(manifestFile,manifest,cfg);

    jobs = buildJobs(cfg,algorithm,manifestFile);
    summary = jobs;
    pending = true(size(jobs));
    for i = 1:numel(jobs)
        if isfile(jobs(i).file), pending(i) = false; end
    end
    fprintf('Algorithm : %s\n',algorithm);
    fprintf('Arm       : lambda020 {3000,0.50,0.25,0.70,6,0.20}\n');
    fprintf('Problems  : %s | M=%d D=%d N=%d maxFE=%d save=%d\n', ...
        strjoin(cfg.problems,', '),cfg.M,cfg.D,cfg.N,cfg.maxFE,cfg.save);
    fprintf('RunIds    : %d..%d\n',cfg.runIds(1),cfg.runIds(end));
    fprintf('Dataset   : %s\n',cfg.dataFolder);
    fprintf('Scratch   : %s\n',cfg.scratch);
    fprintf('Planned runs: %d; already present: %d; to run: %d\n', ...
        numel(jobs),sum(~pending),sum(pending));
    jobs = jobs(pending);
    if isempty(jobs)
        fprintf('Nothing to run.\n');
        return;
    end

    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('Processes',workers);
    end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
    fprintf('Using %d process workers.\n',pool.NumWorkers);
    setup = parfevalOnAll(pool,@prepareWorker,0,cfg.platform,cfg.root,scriptFolder);
    fetchOutputs(setup);

    futures = parallel.FevalFuture.empty;
    for i = 1:numel(jobs)
        futures(i) = parfeval(pool,@runOne,1,jobs(i)); %#ok<AGROW>
    end
    cleanup = onCleanup(@()cancel(futures)); %#ok<NASGU>
    statuses = struct([]);
    failures = 0;
    started = tic;
    for i = 1:numel(jobs)
        [~,s] = fetchNext(futures);
        if isempty(statuses), statuses = s; else, statuses(end+1) = s; end %#ok<AGROW>
        elapsed = toc(started);
        if s.ok
            fprintf('[%d/%d] %-9s %s run %02d IGD=%.10g | elapsed %.1f min\n', ...
                i,numel(jobs),s.arm,s.problem,s.runId,s.IGD,elapsed/60);
        else
            failures = failures + 1;
            fprintf(2,'[%d/%d] FAILED %s %s run %02d: %s\n', ...
                i,numel(jobs),s.arm,s.problem,s.runId,s.message);
        end
    end
    summary = statuses;
    fprintf('COMPLETE: %d run(s) finished in %.1f min.\n', ...
        numel(statuses),toc(started)/60);
    if failures > 0
        error('AdaMaO:RunsFailed','%d job(s) failed. See %s.',failures,cfg.scratch);
    end
end

function prepareWorker(platform,root,scriptFolder)
%prepareWorker Give every worker the same paths as the client.
    if ~isempty(platform), addpath(genpath(platform)); end
    addpath(root);
    if ~isempty(scriptFolder), addpath(scriptFolder); end
end

function cfg = configuration()
%configuration Fixed scope of this experiment.
    cfg.platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.root = fullfile(cfg.platform,'Algorithms','Multi-objective optimization', ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020');
    cfg.dataFolder = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/20目标/' ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020']);
    cfg.scratch = fullfile(tempdir,'lambda020_m20_runs');
    cfg.recordsFolder = fullfile(cfg.scratch,'records');
    cfg.problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7'};
    cfg.problemIndex = 1:7;
    cfg.runIds = 1:18;
    cfg.seedBase = 20260912;
    cfg.lambda0 = 0.20;
    cfg.parameters = {3000,0.50,0.25,0.70,6,0.20};
    cfg.N = 100;
    cfg.M = 20;
    cfg.D = 30;
    cfg.maxFE = 300;
    cfg.save = 18;
end

function jobs = buildJobs(cfg,algorithm,manifestFile)
%buildJobs One job per problem and run ID of the single variant arm.
    jobs = struct([]);
    for p = 1:numel(cfg.problems)
        problem = cfg.problems{p};
        pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
        assert(pro.D==cfg.D && pro.M==cfg.M && pro.N==cfg.N);
        for r = cfg.runIds
            seed = cfg.seedBase + cfg.problemIndex(p)*1000 + r;
            job = struct('arm','lambda020','algorithm',algorithm, ...
                'algFolder',cfg.root,'parameters',{cfg.parameters}, ...
                'lambda0',cfg.lambda0,'problem',problem,'runId',r, ...
                'seed',seed,'root',cfg.root,'platform',cfg.platform, ...
                'file',fullfile(cfg.dataFolder,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                algorithm,problem,cfg.M,pro.D,r)), ...
                'scratch',cfg.scratch,'recordsFolder',cfg.recordsFolder, ...
                'manifestFile',manifestFile,'save',cfg.save, ...
                'N',cfg.N,'M',cfg.M,'D',pro.D,'maxFE',cfg.maxFE);
            if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
        end
    end
end

function status = runOne(job)
%runOne Evaluate one problem instance and store the result atomically.
    status = struct('ok',false,'arm',job.arm,'problem',job.problem, ...
        'runId',job.runId,'lambda0',job.lambda0,'IGD',NaN,'message','', ...
        'file',job.file,'exploreRounds',0,'meanLambdaT',NaN, ...
        'setChangedShare',NaN);
    previousPath = path;
    cleanup = onCleanup(@()path(previousPath)); %#ok<NASGU>
    global ADAMAO_LAMBDA020_DIAG %#ok<GVMIS>
    ADAMAO_LAMBDA020_DIAG = struct('enabled',false);
    temporary = '';
    try
        if ~isempty(job.platform), addpath(genpath(job.platform)); end
        addpath(job.algFolder);
        assert(strcmpi(fileparts(which(job.algorithm)),job.algFolder), ...
            'Unexpected algorithm resolution.');
        assert(~isfile(job.file),'Refusing to overwrite an existing result.');
        manifest = jsondecode(fileread(job.manifestFile));
        sources = manifest.sources;
        for k = 1:numel(sources)
            assert(strcmp(sources(k).sha256,sha256(sources(k).path)), ...
                'Source changed during the experiment: %s',sources(k).path);
        end
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        assert(pro.D==job.D);
        alg = feval(job.algorithm,'parameter',job.parameters,'save',job.save, ...
            'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        metadata = struct('algorithm',job.algorithm,'arm',job.arm, ...
            'problem',job.problem,'runId',job.runId,'seed',job.seed, ...
            'modeRunId',1,'parameters',{job.parameters},'lambda0',job.lambda0, ...
            'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE,'save',job.save, ...
            'threads',maxNumCompThreads,'matlabVersion',version, ...
            'rngBeforeSolve',rng, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        started = tic;
        alg.Solve(pro);
        metadata.runtimeSeconds = toc(started);
        assert(~isempty(alg.result) && pro.FE == job.maxFE && ...
            alg.result{end,1} == pro.FE,'Incomplete run.');
        assert(isstruct(ADAMAO_LAMBDA020_DIAG) && ...
            isfield(ADAMAO_LAMBDA020_DIAG,'rounds') && ...
            ADAMAO_LAMBDA020_DIAG.rounds > 0, ...
            'Diagnostics were not collected.');
        diagnostics = summarizeDiagnostics(ADAMAO_LAMBDA020_DIAG);
        metadata.diagnostics = diagnostics;
        result = alg.result; metric = alg.metric;
        metadata.actualFE = pro.FE;
        metadata.finalN = pro.N;
        metadata.finished = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
        folder = fileparts(job.file);
        if ~isfolder(folder), mkdir(folder); end
        temporary = [tempname(folder),'.mat'];
        save(temporary,'result','metric','metadata','-v7');
        alg.CalMetric('IGD');
        metric = alg.metric;
        assert(all(isfinite(metric.IGD)) && all(metric.IGD >= 0),'Invalid IGD.');
        save(temporary,'metric','-append');
        if isfile(job.file)
            error('AdaMaO:ResultAppeared','Result now exists; not overwriting.');
        end
        [ok,message] = movefile(temporary,job.file);
        assert(ok,'%s',message);
        temporary = '';
        writeRecords(job,ADAMAO_LAMBDA020_DIAG);
        status.exploreRounds = diagnostics.exploreRounds;
        status.meanLambdaT = diagnostics.meanLambdaT;
        status.setChangedShare = diagnostics.setChangedShare;
        status.ok = true; status.IGD = metric.IGD(end);
        status.runtimeSeconds = metadata.runtimeSeconds;
    catch err
        status.message = err.message;
        file = fullfile(job.scratch,sprintf('FAILED_%s_%s_run%02d.txt', ...
            job.arm,job.problem,job.runId));
        fid = fopen(file,'w','n','UTF-8');
        if fid >= 0
            fprintf(fid,'%s',getReport(err,'extended','hyperlinks','off'));
            fclose(fid);
        end
        if ~isempty(temporary) && isfile(temporary), delete(temporary); end
    end
end

function diagnostics = summarizeDiagnostics(DIAG)
%summarizeDiagnostics Compact per-run summary of the exploration records.
    records = DIAG.records;
    n = numel(records);
    diagnostics = struct('lambda0',DIAG.lambda0,'rounds',DIAG.rounds, ...
        'exploreRounds',n,'indicatorRounds',DIAG.rounds-n, ...
        'meanLambdaT',NaN,'minLambdaT',NaN,'maxLambdaT',NaN, ...
        'meanRetained',NaN,'meanTarget',NaN,'meanReward',NaN,'maxReward',NaN, ...
        'firstChangedShare',NaN,'setChangedShare',NaN, ...
        'orderChangedShare',NaN,'meanOverlap',NaN,'meanAbsRankShift',NaN, ...
        'skippedRounds',0);
    if n == 0, return; end
    lambdaT = zeros(n,1);
    retained = zeros(n,1);
    target = zeros(n,1);
    reward = zeros(n,1);
    overlap = zeros(n,1);
    rankShift = zeros(n,1);
    firstChanged = false(n,1);
    setChanged = false(n,1);
    orderChanged = false(n,1);
    for i = 1:n
        rec = records{i};
        lambdaT(i) = rec.lambdaT;
        retained(i) = rec.nRetained;
        target(i) = rec.target;
        reward(i) = rec.meanReward;
        overlap(i) = rec.overlap;
        rankShift(i) = rec.meanAbsRankShift;
        firstChanged(i) = rec.firstChanged;
        setChanged(i) = rec.setChanged;
        orderChanged(i) = rec.orderChanged;
    end
    diagnostics.meanLambdaT = mean(lambdaT);
    diagnostics.minLambdaT = min(lambdaT);
    diagnostics.maxLambdaT = max(lambdaT);
    diagnostics.meanRetained = mean(retained);
    diagnostics.meanTarget = mean(target);
    diagnostics.meanReward = mean(reward(isfinite(reward)));
    diagnostics.maxReward = max(reward(isfinite(reward)));
    diagnostics.firstChangedShare = mean(firstChanged);
    diagnostics.setChangedShare = mean(setChanged);
    diagnostics.orderChangedShare = mean(orderChanged);
    diagnostics.meanOverlap = mean(overlap(isfinite(overlap)));
    diagnostics.meanAbsRankShift = mean(rankShift(isfinite(rankShift)));
    diagnostics.skippedRounds = sum(arrayfun(@(i) ...
        ~isempty(records{i}.skipped),1:n));
end

function writeRecords(job,DIAG)
%writeRecords Store the per-round exploration records of one run as CSV.
    records = DIAG.records;
    n = numel(records);
    if n == 0, return; end
    if ~isfolder(job.recordsFolder), mkdir(job.recordsFolder); end
    FE = zeros(n,1); nCand = zeros(n,1); nRet = zeros(n,1);
    target = zeros(n,1); lambdaT = zeros(n,1); reward = zeros(n,1);
    overlap = zeros(n,1); rankShift = zeros(n,1);
    firstChanged = false(n,1); setChanged = false(n,1); orderChanged = false(n,1);
    for i = 1:n
        rec = records{i};
        FE(i) = rec.FE;
        nCand(i) = rec.nCandidates;
        nRet(i) = rec.nRetained;
        target(i) = rec.target;
        lambdaT(i) = rec.lambdaT;
        reward(i) = rec.meanReward;
        overlap(i) = rec.overlap;
        rankShift(i) = rec.meanAbsRankShift;
        firstChanged(i) = rec.firstChanged;
        setChanged(i) = rec.setChanged;
        orderChanged(i) = rec.orderChanged;
    end
    T = table((1:n)',FE,nCand,nRet,target,lambdaT,reward,overlap, ...
        rankShift,firstChanged,setChanged,orderChanged, ...
        'VariableNames',{'round','FEbefore','nCandidates','nRetained','target', ...
        'lambdaT','meanReward','overlap','meanAbsRankShift','firstChanged', ...
        'setChanged','orderChanged'});
    writetable(T,fullfile(job.recordsFolder,sprintf( ...
        '%s_%s_run%02d_records.csv',job.algorithm,job.problem,job.runId)), ...
        'Encoding','UTF-8');
end

function manifest = sourceManifest(folder)
%sourceManifest SHA-256 of every algorithm source file in one folder.
    manifest = struct('folder',{},'path',{},'sha256',{});
    files = [dir(fullfile(folder,'*.m'));dir(fullfile(folder,'private','*.m'))];
    for i = 1:numel(files)
        if strcmp(files(i).name(1),'.'), continue; end
        file = fullfile(files(i).folder,files(i).name);
        manifest(end+1) = struct('folder',folder,'path',file, ...
            'sha256',sha256(file)); %#ok<AGROW>
    end
end

function writeManifest(file,manifest,cfg)
%writeManifest Persist the frozen source list next to the run logs.
    text = jsonencode(struct('variantFolder',cfg.root, ...
        'dataFolder',cfg.dataFolder,'scratch',cfg.scratch, ...
        'seedBase',cfg.seedBase,'runIds',cfg.runIds, ...
        'sources',manifest));
    fid = fopen(file,'w','n','UTF-8');
    assert(fid >= 0,'Cannot write the source manifest.');
    fwrite(fid,text);
    fclose(fid);
end

function h = sha256(file)
%sha256 Lower-case hexadecimal SHA-256 of a file.
    fid = fopen(file,'r');
    assert(fid >= 0,'Cannot read %s.',file);
    bytes = fread(fid,Inf,'*uint8');
    fclose(fid);
    md = java.security.MessageDigest.getInstance('SHA-256');
    digest = md.digest(bytes);
    h = lower(reshape(dec2hex(typecast(digest,'uint8'),2)',1,[]));
end
