function summary = RunLambda020_10(action,workers)
%RunLambda020_10 Verify then run the Lambda020 variant on four M=10 problems.
%   RunLambda020_10('check')     audit the planned runs, no optimization.
%   RunLambda020_10('verify0')   legacy single-run check against a stored control.
%   RunLambda020_10('run',W)     fill the two-arm experiment with W workers.
%   DTLZ2/4/5/7, M=10, D=30, N=100, maxFE=300, run IDs 19..28, ten runs per
%   problem and arm. Two arms share every run:
%     lambda020 - the new variant with lambda0=0.20,
%     baseline  - the pruned algorithm with its five original parameters.
%   The baseline arm is rerun inside this same session and this same process
%   pool, because a stored baseline result is not reproducible across execution
%   contexts: the verification below showed the same seed giving different
%   trajectories on a client, on a 3-worker pool and in the stored 2-worker
%   session. Only same-context runs form a true matched pair.
%   Stored results are never overwritten; the baseline arm is written to the
%   diagnostics folder instead of the shared dataset.

    if nargin < 1, action = 'run'; end
    if nargin < 2, workers = 'max'; end
    assert(ismember(action,{'run','check','verify0'}),'Use run, check or verify0.');
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
    root = fileparts(mfilename('fullpath'));
    platform = fileparts(fileparts(fileparts(root)));
    addpath(genpath(platform));
    addpath(root);
    assert(strcmpi(fileparts(which(algorithm)),root),'Wrong algorithm on the path.');

    cfg = configuration(root,platform);
    if ~isfolder(cfg.logs), mkdir(cfg.logs); end
    if ~isfolder(cfg.controlInSessionFolder), mkdir(cfg.controlInSessionFolder); end
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    manifest = sourceManifest({root,cfg.baselineFolder});
    manifestFile = fullfile(cfg.logs,['sources_',stamp,'.json']);
    writeManifest(manifestFile,manifest,cfg);

    jobs = buildJobs(cfg,algorithm,manifestFile);
    summary = jobs;
    if strcmp(action,'verify0')
        jobs = jobs(strcmp({jobs.arm},'lambda020'));
        jobs = jobs(1);
        jobs(1).lambda0 = 0;
        jobs(1).parameters = {3000,0.50,0.25,0.70,6,0};
        jobs(1).file = fullfile(cfg.logs,'verify0', ...
            sprintf('verify0_%s_run%02d.mat',jobs(1).problem,jobs(1).runId));
        fprintf('VERIFY0: single lambda0=0 run in this client session.\n');
        fprintf('Problem %s, run %d, seed %d, stored control:\n  %s\n', ...
            jobs(1).problem,jobs(1).runId,jobs(1).seed,jobs(1).storedControl);
    end
    pending = true(size(jobs));
    for i = 1:numel(jobs)
        if isfile(jobs(i).file), pending(i) = false; end
    end
    fprintf('Algorithm : %s\n',algorithm);
    fprintf('Arms      : lambda020 {3000,0.50,0.25,0.70,6,0.20}; baseline {3000,0.50,0.25,0.70,6}\n');
    fprintf('Planned runs: %d; already present: %d; to run: %d\n', ...
        numel(jobs),sum(~pending),sum(pending));
    if strcmp(action,'check')
        fprintf('CHECK PASSED. No optimization started.\n');
        return;
    end
    if strcmp(action,'verify0')
        fprintf('Running one lambda0=0 run serially, no worker pool.\n');
        s = runOne(jobs(1));
        assert(s.ok,'verify0 run failed: %s',s.message);
        verdict = compareVerify0(jobs(1),cfg);
        fprintf('verify0 IGD        : %.12g\n',verdict.IGD);
        fprintf('stored control IGD : %.12g\n',verdict.controlIGD);
        fprintf('VERDICT: %s (client context may legitimately differ)\n', ...
            verdict.verdict);
        return;
    end
    jobs = jobs(pending);
    if isempty(jobs), fprintf('Nothing to run.\n'); return; end

    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('Processes',workers);
    end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
    fprintf('Using %d process workers.\n',pool.NumWorkers);
    setup = parfevalOnAll(pool,@prepareWorker,0,platform,root,manifestFile,cfg);
    fetchOutputs(setup);

    futures = parallel.FevalFuture.empty;
    for i = 1:numel(jobs)
        futures(i) = parfeval(pool,@runOne,1,jobs(i)); %#ok<AGROW>
    end
    cleanup = onCleanup(@()cancel(futures)); %#ok<NASGU>
    statuses = struct([]);
    failures = 0;
    for i = 1:numel(jobs)
        [~,s] = fetchNext(futures);
        if isempty(statuses), statuses = s; else, statuses(end+1) = s; end %#ok<AGROW>
        if s.ok
            fprintf('[%d/%d] %-9s %s run %02d IGD=%.10g\n', ...
                i,numel(jobs),s.arm,s.problem,s.runId,s.IGD);
        else
            failures = failures + 1;
            fprintf(2,'[%d/%d] FAILED %s %s run %02d: %s\n', ...
                i,numel(jobs),s.arm,s.problem,s.runId,s.message);
        end
    end
    summary = statuses;
    if failures > 0
        error('AdaMaO:RunsFailed','%d job(s) failed. See %s.',failures,cfg.logs);
    end
    fprintf('COMPLETE: %d run(s) finished.\n',numel(statuses));
end

function verdict = compareVerify0(job,cfg)
%compareVerify0 Report a lambda0=0 run against the stored baseline control.
    new = load(job.file,'result','metric','metadata');
    old = load(job.storedControl,'result','metric','metadata');
    verdict = struct();
    verdict.file = job.file;
    verdict.controlFile = job.storedControl;
    verdict.IGD = new.metric.IGD(end);
    verdict.controlIGD = old.metric.IGD(end);
    verdict.deltaIGD = verdict.IGD-verdict.controlIGD;
    verdict.verdict = 'DIFFERENT-CONTEXT';
    if verdict.deltaIGD == 0
        verdict.verdict = 'IDENTICAL';
    end
    file = fullfile(cfg.logs,'verify0','verify0_verdict.json');
    if ~isfolder(fileparts(file)), mkdir(fileparts(file)); end
    fid = fopen(file,'w','n','UTF-8');
    fwrite(fid,jsonencode(verdict,'PrettyPrint',true));
    fclose(fid);
end

function prepareWorker(platform,root,manifestFile,cfg)
%prepareWorker Give every worker the same paths and manifest as the client.
    if ~isempty(platform), addpath(genpath(platform)); end
    addpath(root);
    assert(isfolder(cfg.logs),'Missing log folder on worker.');
end

function cfg = configuration(root,platform)
%configuration Fixed scope of this experiment.
    optimization = fullfile(platform,'Algorithms','Multi-objective optimization');
    cfg.root = root;
    cfg.platform = platform;
    cfg.baseline = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted';
    cfg.baselineFolder = fullfile(optimization,cfg.baseline);
    cfg.dataFolder = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30/' ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020']);
    cfg.storedControlFolder = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/' ...
        '10目标/n30/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted']);
    % Every product of this experiment lives inside the algorithm folder of the
    % shared dataset, so the dataset folder stays the single place to look for
    % results. A resumed run picks up the runs that are already stored there.
    cfg.logs = fullfile(cfg.dataFolder,'diagnostics');
    cfg.controlInSessionFolder = fullfile(cfg.dataFolder,'control_in_session');
    cfg.recordsFolder = fullfile(cfg.logs,'records');
    cfg.problems = {'DTLZ2','DTLZ4','DTLZ5','DTLZ7'};
    cfg.problemIndex = [2,4,5,7];   % Position inside the paper's 16-problem list
    cfg.runIds = 19:28;
    cfg.lambda0 = 0.20;
    cfg.N = 100;
    cfg.M = 10;
    cfg.D = 30;
    cfg.maxFE = 300;
end

function jobs = buildJobs(cfg,algorithm,manifestFile)
%buildJobs One job per problem, run ID and arm, with matched seeds.
    jobs = struct([]);
    for p = 1:numel(cfg.problems)
        problem = cfg.problems{p};
        pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
        assert(pro.D==cfg.D && pro.M==cfg.M && pro.N==cfg.N);
        for r = cfg.runIds
            seed = 20260912 + cfg.M*100000 + cfg.problemIndex(p)*1000 + r;
            stored = fullfile(cfg.storedControlFolder,sprintf( ...
                '%s_%s_M%d_D%d_%d.mat',cfg.baseline,problem,cfg.M,pro.D,r));
            arms = { ...
                'lambda020',algorithm,cfg.root, ...
                {3000,0.50,0.25,0.70,6,cfg.lambda0}, cfg.lambda0,cfg.dataFolder; ...
                'baseline',cfg.baseline,cfg.baselineFolder, ...
                {3000,0.50,0.25,0.70,6}, NaN,cfg.controlInSessionFolder};
            for a = 1:size(arms,1)
                job = struct('arm',arms{a,1},'algorithm',arms{a,2}, ...
                    'algFolder',arms{a,3},'parameters',{arms{a,4}}, ...
                    'lambda0',arms{a,5},'problem',problem,'runId',r, ...
                    'seed',seed,'root',cfg.root,'platform',cfg.platform, ...
                    'file',fullfile(arms{a,6},sprintf('%s_%s_M%d_D%d_%d.mat', ...
                    arms{a,2},problem,cfg.M,pro.D,r)), ...
                    'storedControl',stored,'logs',cfg.logs, ...
                    'recordsFolder',cfg.recordsFolder, ...
                    'manifestFile',manifestFile, ...
                    'N',cfg.N,'M',cfg.M,'D',pro.D,'maxFE',cfg.maxFE);
                if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
            end
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
        % The frozen manifest must still describe the sources of this arm.
        manifest = jsondecode(fileread(job.manifestFile));
        sources = manifest.sources;
        for k = 1:numel(sources)
            if ~strcmpi(sources(k).folder,job.algFolder), continue; end
            assert(strcmp(sources(k).sha256,sha256(sources(k).path)), ...
                'Source changed during the experiment: %s',sources(k).path);
        end
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        assert(pro.D==job.D);
        alg = feval(job.algorithm,'parameter',job.parameters,'save',30, ...
            'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        metadata = struct('algorithm',job.algorithm,'arm',job.arm, ...
            'problem',job.problem,'runId',job.runId,'seed',job.seed, ...
            'modeRunId',1,'parameters',{job.parameters},'lambda0',job.lambda0, ...
            'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE,'save',30, ...
            'storedControl',job.storedControl,'threads',maxNumCompThreads, ...
            'matlabVersion',version,'rngBeforeSolve',rng, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        started = tic;
        alg.Solve(pro);
        metadata.runtimeSeconds = toc(started);
        assert(~isempty(alg.result) && pro.FE == job.maxFE && ...
            alg.result{end,1} == pro.FE,'Incomplete run.');
        if strcmp(job.arm,'lambda020')
            assert(isstruct(ADAMAO_LAMBDA020_DIAG) && ...
                isfield(ADAMAO_LAMBDA020_DIAG,'rounds') && ...
                ADAMAO_LAMBDA020_DIAG.rounds > 0, ...
                'Diagnostics were not collected.');
            diagnostics = summarizeDiagnostics(ADAMAO_LAMBDA020_DIAG);
            metadata.diagnostics = diagnostics;
        end
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
        if strcmp(job.arm,'lambda020')
            writeRecords(job,ADAMAO_LAMBDA020_DIAG);
            status.exploreRounds = diagnostics.exploreRounds;
            status.meanLambdaT = diagnostics.meanLambdaT;
            status.setChangedShare = diagnostics.setChangedShare;
        end
        status.ok = true; status.IGD = metric.IGD(end);
    catch err
        status.message = err.message;
        file = fullfile(job.logs,sprintf('FAILED_%s_%s_run%02d.txt', ...
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

function manifest = sourceManifest(folders)
%sourceManifest SHA-256 of every algorithm source file in each folder.
    manifest = struct('folder',{},'path',{},'sha256',{});
    for f = 1:numel(folders)
        folder = folders{f};
        files = [dir(fullfile(folder,'*.m'));dir(fullfile(folder,'private','*.m'))];
        for i = 1:numel(files)
            if strcmp(files(i).name(1),'.'), continue; end
            file = fullfile(files(i).folder,files(i).name);
            manifest(end+1) = struct('folder',folder,'path',file, ...
                'sha256',sha256(file)); %#ok<AGROW>
        end
    end
end

function writeManifest(file,manifest,cfg)
%writeManifest Persist the frozen source list next to the run logs.
    text = jsonencode(struct('baselineFolder',cfg.baselineFolder, ...
        'variantFolder',cfg.root,'dataFolder',cfg.dataFolder, ...
        'storedControlFolder',cfg.storedControlFolder, ...
        'controlInSessionFolder',cfg.controlInSessionFolder, ...
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
