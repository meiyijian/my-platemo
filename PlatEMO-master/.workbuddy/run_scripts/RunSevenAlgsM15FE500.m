function summary = RunSevenAlgsM15FE500(mode,workers,onlyAlg)
%RunSevenAlgsM15FE500 Seven baselines on the sixteen-problem M=15 list, maxFE=500.
%   RunSevenAlgsM15FE500('smoke',W)  one run of DTLZ2 for every algorithm
%   RunSevenAlgsM15FE500('run',W)    full 7 x 16 x 20 = 2240 runs
%   RunSevenAlgsM15FE500('check')    report what is already stored
%   The third argument restricts the work to one algorithm, which is how the
%   batch is started algorithm by algorithm.
%
%   Fixed scope, matching the rest of the paper's M=15 batches:
%   M=15, D=30, N=100, maxFE=500, save=30, run numbers 1..20,
%   seed = 20260912 + M*100000 + problemPosition*1000 + runId  (M=15 -> 21760912).
%   Files land in <testRoot>\15目标\FE500\<algorithm>\ as .mat, nothing else.
%   Every algorithm folder is raised to the top of the path before its own run,
%   because the PlatEMO helpers share file names across algorithm folders.

    if nargin < 1 || isempty(mode), mode = 'run'; end
    if nargin < 2 || isempty(workers), workers = 5; end
    if nargin < 3, onlyAlg = ''; end
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});

    cfg = configuration();
    if ~isempty(onlyAlg)
        keep = strcmpi(cfg.algorithms,onlyAlg);
        assert(any(keep),'Unknown algorithm: %s',onlyAlg);
        cfg.algorithms = cfg.algorithms(keep);
    end

    addpath(genpath(cfg.platform));
    addpath(fileparts(mfilename('fullpath')));
    if ~isfolder(cfg.scratch), mkdir(cfg.scratch); end
    for a = 1:numel(cfg.algorithms)
        d = fullfile(cfg.dataFolder,cfg.algorithms{a});
        if ~isfolder(d), mkdir(d); end
    end

    if strcmpi(mode,'check')
        summary = reportState(cfg);
        return;
    end
    if strcmpi(mode,'smoke')
        cfg.problems = {'DTLZ2'};
        cfg.problemIndex = 2;
        cfg.indices = 1;
    end

    manifest = sourceManifest(cfg);
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    manifestFile = fullfile(cfg.scratch,['sources_',stamp,'.json']);
    fid = fopen(manifestFile,'w','n','UTF-8');
    fprintf(fid,'%s',jsonencode(struct('sources',manifest,'mode',mode,'created',stamp)));
    fclose(fid);

    jobs = buildJobs(cfg,manifestFile);
    pending = true(size(jobs));
    for i = 1:numel(jobs)
        if isfile(jobs(i).file), pending(i) = false; end
    end
    fprintf('Mode      : %s\n',mode);
    fprintf('Algorithms: %s\n',strjoin(cfg.algorithms,', '));
    fprintf('Scale     : M=%d D=%d N=%d maxFE=%d save=%d | runs %d..%d\n', ...
        cfg.M,cfg.D,cfg.N,cfg.maxFE,cfg.save,cfg.indices(1),cfg.indices(end));
    fprintf('Dataset   : %s\n',cfg.dataFolder);
    fprintf('Planned runs: %d; already present: %d; to run: %d\n', ...
        numel(jobs),sum(~pending),sum(pending));
    jobs = jobs(pending);
    if isempty(jobs)
        fprintf('Nothing to run.\n');
        summary = struct([]);
        return;
    end

    pool = gcp('nocreate');
    if isempty(pool)
        % The 'Processes' profile caps NumWorkers at 6, which leaves half of the
        % twelve logical cores idle. Raise the cap on a session-local cluster
        % object only; the stored profile is not modified.
        c = parcluster('Processes');
        if workers > c.NumWorkers
            fprintf('Raising the pool cap from %d to %d workers (profile untouched).\n', ...
                c.NumWorkers,workers);
            c.NumWorkers = workers;
        end
        pool = parpool(c,workers);
    end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
    fprintf('Using %d process workers (NumThreads=%d).\n', ...
        pool.NumWorkers,pool.NumThreads);

    fut = parallel.FevalFuture.empty;
    for i = 1:numel(jobs)
        fut(i) = parfeval(pool,@runOne,1,jobs(i)); %#ok<AGROW>
    end
    cleanup = onCleanup(@()cancel(fut)); %#ok<NASGU>
    statuses = struct([]);
    failures = 0;
    started = tic;
    for i = 1:numel(jobs)
        [~,s] = fetchNext(fut);
        if isempty(statuses), statuses = s; else, statuses(end+1) = s; end %#ok<AGROW>
        elapsed = toc(started);
        rate = elapsed/i;
        if s.ok
            if mod(i,10) == 0 || i == numel(jobs) || i <= 20
                fprintf(['[%4d/%4d] %-7s run %02d FE=%d IGD=%.8g | %.1f min, ' ...
                    '%.1f s/run, eta %.1f min\n'],i,numel(jobs),s.problem,s.runId, ...
                    s.FE,s.IGD,elapsed/60,rate,(numel(jobs)-i)*rate/60);
            end
        else
            failures = failures + 1;
            fprintf(2,'[%4d/%4d] FAILED %s run %02d: %s\n', ...
                i,numel(jobs),s.problem,s.runId,s.message);
        end
    end
    summary = statuses;
    fprintf('COMPLETE: %d run(s) in %.1f min, %d failure(s).\n', ...
        numel(statuses),toc(started)/60,failures);
    if failures > 0
        error('M15FE500:RunsFailed','%d job(s) failed. See %s.',failures,cfg.scratch);
    end
end

function cfg = configuration()
%configuration Fixed scope of this experiment.
    cfg.platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    cfg.dataFolder = fullfile(cfg.testRoot,'15目标','FE500');
    cfg.scratch = fullfile(tempdir,'m15_fe500');
    % Submission order: cheapest baseline first, so finished algorithms can be
    % collected while the slow ones are still running. REMO needs ~1000 s per
    % run here and would otherwise block the queue for the whole first day.
    % The order does not affect any seed or result, only which job is handed to
    % a worker first.
    cfg.algorithms = {'SSDE','PCSAEA','SAMOEATL2M','CSEA', ...
        'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist','HES_EA','REMO'};
    cfg.problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
        'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    cfg.problemIndex = 1:16;
    % Ten runs per problem. The batches that were already completed at twenty
    % runs (SSDE 320/320 and PCSAEA 320/320 on 2026-09-21) are left untouched:
    % the runner skips any run whose file exists, so runs 1..10 of those two
    % algorithms are found and nothing is rewritten.
    cfg.indices = 1:10;
    cfg.N = 100;
    cfg.M = 15;
    cfg.D = 30;
    cfg.maxFE = 500;
    cfg.save = 30;
end

function manifest = sourceManifest(cfg)
%sourceManifest SHA-256 of the main class file of every algorithm.
    n = numel(cfg.algorithms);
    manifest = struct('algorithm',cfg.algorithms(:),'path',cell(n,1), ...
        'sha256',cell(n,1));
    for a = 1:n
        d = fileparts(which(cfg.algorithms{a}));
        assert(~isempty(d) && strncmpi(d,cfg.platform,numel(cfg.platform)), ...
            '%s does not resolve under the platform',cfg.algorithms{a});
        f = which(cfg.algorithms{a});
        manifest(a).path = f;
        manifest(a).sha256 = sha256File(f);
        fprintf('  source: %-52s %s\n',cfg.algorithms{a},f);
    end
end

function h = sha256File(file)
%sha256File Hex SHA-256 digest of one file, without external dependencies.
    fid = fopen(file,'r');
    assert(fid >= 0,'Cannot read %s.',file);
    bytes = fread(fid,Inf,'*uint8');
    fclose(fid);
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes);
    h = sprintf('%02x',typecast(md.digest(),'uint8'));
end

function jobs = buildJobs(cfg,manifestFile)
%buildJobs One job per algorithm, problem and run number.
    jobs = struct([]);
    for a = 1:numel(cfg.algorithms)
        alg = cfg.algorithms{a};
        algDir = fileparts(which(alg));
        for p = 1:numel(cfg.problems)
            problem = cfg.problems{p};
            pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
            assert(pro.M==cfg.M && pro.N==cfg.N && pro.D>=cfg.D, ...
                'Unexpected %s configuration.',problem);
            for r = cfg.indices
                seed = 20260912 + cfg.M*100000 + cfg.problemIndex(p)*1000 + r;
                job = struct('algorithm',alg,'algDir',algDir, ...
                    'problem',problem,'runId',r,'seed',seed, ...
                    'platform',cfg.platform, ...
                    'file',fullfile(cfg.dataFolder,alg,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                    alg,problem,cfg.M,pro.D,r)), ...
                    'scratch',cfg.scratch,'manifestFile',manifestFile, ...
                    'save',cfg.save,'N',cfg.N,'M',cfg.M,'D',pro.D,'maxFE',cfg.maxFE);
                if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
            end
        end
    end
end

function status = runOne(job)
%runOne Evaluate one problem instance and store the result atomically.
    status = struct('ok',false,'algorithm',job.algorithm,'problem',job.problem, ...
        'runId',job.runId,'IGD',NaN,'FE',0,'message','','file',job.file, ...
        'runtimeSeconds',NaN);
    previousPath = path;
    cleanup = onCleanup(@()path(previousPath)); %#ok<NASGU>
    temporary = '';
    try
        addpath(genpath(job.platform));
        addpath(job.algDir,'-begin');
        assert(strcmpi(fileparts(which(job.algorithm)),job.algDir), ...
            'Unexpected algorithm resolution for %s.',job.algorithm);
        assert(~isfile(job.file),'Refusing to overwrite an existing result.');
        manifest = jsondecode(fileread(job.manifestFile));
        k = find(strcmp({manifest.sources.algorithm},job.algorithm),1);
        assert(~isempty(k),'no manifest entry for %s',job.algorithm);
        assert(strcmp(manifest.sources(k).sha256, ...
            sha256File(manifest.sources(k).path)), ...
            'Source changed during the experiment: %s',manifest.sources(k).path);
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        assert(pro.D==job.D);
        started = tic;
        progressFile = fullfile(job.scratch,sprintf('p_%s_%s_%02d.txt', ...
            job.algorithm,job.problem,job.runId));
        if isfile(progressFile), delete(progressFile); end
        alg = feval(job.algorithm,'save',job.save,'run',1, ...
            'outputFcn',@(a,p) logProgress(progressFile,p,started));
        rng(job.seed,'twister');
        metadata = struct('algorithm',job.algorithm,'problem',job.problem, ...
            'runId',job.runId,'seed',job.seed,'N',job.N,'M',job.M,'D',job.D, ...
            'maxFE',job.maxFE,'save',job.save,'parameters','defaults', ...
            'threads',maxNumCompThreads,'matlabVersion',version, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        alg.Solve(pro);
        metadata.runtimeSeconds = toc(started);
        % Several of these baselines evaluate a whole batch and therefore
        % overshoot the budget (SSDE reaches FE 501-511, CSEA 511, PCSAEA 509).
        % The run is complete once the budget is met; the overshoot is recorded
        % in metadata.actualFE and has to be reported with the results.
        assert(~isempty(alg.result) && pro.FE >= job.maxFE, ...
            'Incomplete run: FE=%d of %d.',pro.FE,job.maxFE);
        result = alg.result; metric = alg.metric;
        metadata.actualFE = pro.FE;
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
            error('M15FE500:ResultAppeared','Result now exists; not overwriting.');
        end
        [ok,message] = movefile(temporary,job.file);
        assert(ok,'%s',message);
        temporary = '';
        status.ok = true; status.IGD = metric.IGD(end); status.FE = pro.FE;
        status.runtimeSeconds = metadata.runtimeSeconds;
    catch err
        status.message = err.message;
        file = fullfile(job.scratch,sprintf('FAILED_%s_%s_run%02d.txt', ...
            job.algorithm,job.problem,job.runId));
        fid = fopen(file,'w','n','UTF-8');
        if fid >= 0
            fprintf(fid,'%s',getReport(err,'extended','hyperlinks','off'));
            fclose(fid);
        end
        if ~isempty(temporary) && isfile(temporary)
            [ok,message] = movefile(temporary,[temporary,'.partial']);
            if ~ok, fprintf(2,'%s\n',message); end
        end
    end
end

function logProgress(file,Problem,started)
%logProgress Append one line per generation so the client can watch progress.
    fid = fopen(file,'a');
    if fid >= 0
        fprintf(fid,'FE=%d t=%.1f\n',Problem.FE,toc(started));
        fclose(fid);
    end
end

function summary = reportState(cfg)
%reportState Count the products already stored per algorithm.
    summary = struct('algorithm',{},'runs',{},'missing',{});
    for a = 1:numel(cfg.algorithms)
        alg = cfg.algorithms{a};
        have = false(numel(cfg.problems),numel(cfg.indices));
        for p = 1:numel(cfg.problems)
            problem = cfg.problems{p};
            pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
            for r = cfg.indices
                f = fullfile(cfg.dataFolder,alg,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                    alg,problem,cfg.M,pro.D,r));
                have(p,r) = isfile(f);
            end
        end
        fprintf('%-52s %3d/%d\n',alg,sum(have(:)),numel(have));
        entry = struct('algorithm',alg,'runs',sum(have(:)), ...
            'missing',{sprintf('%d ',find(~have(:))')});
        if isempty(summary), summary = entry; else, summary(end+1) = entry; end %#ok<AGROW>
    end
    fprintf('total %d/%d\n',sum([summary.runs]), ...
        numel(cfg.algorithms)*numel(cfg.problems)*numel(cfg.indices));
end
