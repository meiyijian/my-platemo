function summary = RunNSGAIIIEHVI_M10(mode,workers)
%RunNSGAIIIEHVI_M10 Run NSGAIII-EHVI on the paper's sixteen-problem M=10 list.
%   RunNSGAIIIEHVI_M10('smoke') evaluates one run of a five-problem probe set
%   (DTLZ1/DTLZ4/DTLZ7/WFG3/WFG9) and prints the wall time per run, which is
%   what the full batch is sized from.
%   RunNSGAIIIEHVI_M10('run') evaluates all sixteen problems, twenty runs
%   each, skipping any result file that already exists, so the call is
%   restartable and the smoke products are reused.
%   RunNSGAIIIEHVI_M10('check') only reports the state of the data folder.
%
%   Fixed scope, identical to the other M=10 batches of the paper:
%   M=10, D=30, N=100, maxFE=300, save=30, run numbers 1..20,
%   seed = 20260912 + M*100000 + problemPosition*1000 + runId.
%
%   Products land in the dataset folder of this algorithm as .mat files and
%   nothing else; manifests, records and failure reports go to the system
%   temporary directory.

    if nargin < 1, mode = 'run'; end
    if nargin < 2, workers = 5; end
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});

    algorithm = 'NSGAIIIEHVI';
    cfg = configuration();
    addpath(genpath(cfg.platform));
    addpath(cfg.root);
    addpath(fileparts(mfilename('fullpath')));
    assert(strcmpi(fileparts(which(algorithm)),cfg.root), ...
        'NSGAIIIEHVI does not resolve to %s.',cfg.root);
    if ~isfolder(cfg.scratch), mkdir(cfg.scratch); end
    if ~isfolder(cfg.dataFolder), mkdir(cfg.dataFolder); end

    if strcmpi(mode,'check')
        summary = reportState(cfg,algorithm);
        return;
    end

    if strcmpi(mode,'smoke')
        cfg.problems   = {'DTLZ1','DTLZ4','DTLZ7','WFG3','WFG9'};
        cfg.problemIndex = [1 4 7 11 16];
        cfg.indices    = 1:1;
    end

    manifest = sourceManifest(cfg);
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    manifestFile = fullfile(cfg.scratch,['sources_',stamp,'.json']);
    fid = fopen(manifestFile,'w','n','UTF-8');
    fprintf(fid,'%s',jsonencode(struct('sources',manifest, ...
        'algorithm',algorithm,'mode',mode,'created',stamp)));
    fclose(fid);

    jobs = buildJobs(cfg,algorithm,manifestFile);
    pending = true(size(jobs));
    for i = 1:numel(jobs)
        if isfile(jobs(i).file), pending(i) = false; end
    end
    fprintf('Algorithm : %s\n',algorithm);
    fprintf('Parameters: wmax=15 LB=-0.5 UB=1.2 nSample=10000 randp=0.3 (defaults)\n');
    fprintf('Scale     : M=%d D=%d N=%d maxFE=%d save=%d | run numbers %d..%d\n', ...
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
        pool = parpool('Processes',workers);
    end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
    fprintf('Using %d process workers.\n',pool.NumWorkers);

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
        rate = elapsed/i;
        if s.ok
            fprintf(['[%3d/%3d] %-7s run %02d IGD=%.10g | %.1f min elapsed, ' ...
                '%.2f min/run, eta %.1f min\n'],i,numel(jobs),s.problem,s.runId, ...
                s.IGD,elapsed/60,rate/60,(numel(jobs)-i)*rate/60);
        else
            failures = failures + 1;
            fprintf(2,'[%3d/%3d] FAILED %s run %02d: %s\n', ...
                i,numel(jobs),s.problem,s.runId,s.message);
        end
    end
    summary = statuses;
    fprintf('COMPLETE: %d run(s) finished in %.1f min.\n',numel(statuses),toc(started)/60);
    if failures > 0
        error('NSGAIIIEHVI:RunsFailed','%d job(s) failed. See %s.',failures,cfg.scratch);
    end
end

function cfg = configuration()
%configuration Fixed scope of this experiment.
    cfg.platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.root = fullfile(cfg.platform,'Algorithms','Multi-objective optimization','NSGAIII-EHVI');
    cfg.dataFolder = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30/' ...
        'NSGAIIIEHVI']);
    cfg.scratch = fullfile(tempdir,'nsgaiiiehvi_m10');
    cfg.problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
        'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    cfg.problemIndex = 1:16;
    cfg.indices = 1:20;
    cfg.parameters = [];      % algorithm defaults
    cfg.N = 100;
    cfg.M = 10;
    cfg.D = 30;
    cfg.maxFE = 300;
    cfg.save = 30;
end

function manifest = sourceManifest(cfg)
%sourceManifest SHA-256 of every file the run depends on.
%   The helpers that live in the algorithm folder are addressed through their
%   folder, not through WHICH: before ALGORITHM.Solve raises the algorithm
%   folder to the top of the path, WHICH('EnvironmentalSelection') and
%   WHICH('predictor') both resolve to a foreign copy, so WHICH would record
%   the wrong file and every job would then fail its own consistency check.
    own = {'NSGAIIIEHVI','EnvironmentalSelection','LastSelection', ...
        'SelectionMSE','CalEHVI','predictor'};
    shared = {'dacefit','regpoly0','corrgauss'};
    files = cell(0,1);
    for i = 1:numel(own)
        f = fullfile(cfg.root,[own{i},'.m']);
        assert(isfile(f),'Missing %s.',f);
        files{end+1,1} = f; %#ok<AGROW>
    end
    for i = 1:numel(shared)
        f = which(shared{i});
        assert(~isempty(f),'Missing helper %s.',shared{i});
        files{end+1,1} = f; %#ok<AGROW>
    end
    manifest = struct('path',files,'sha256',cell(numel(files),1));
    for i = 1:numel(files)
        manifest(i).sha256 = sha256File(files{i});
        fprintf('  source: %s  %s\n',manifest(i).sha256(1:12),files{i});
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

function jobs = buildJobs(cfg,algorithm,manifestFile)
%buildJobs One job per problem and run number.
    jobs = struct([]);
    for p = 1:numel(cfg.problems)
        problem = cfg.problems{p};
        pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
        assert(pro.M==cfg.M && pro.N==cfg.N && pro.D>=cfg.D, ...
            'Unexpected %s configuration.',problem);
        for r = cfg.indices
            seed = 20260912 + cfg.M*100000 + cfg.problemIndex(p)*1000 + r;
            job = struct('algorithm',algorithm,'algFolder',cfg.root, ...
                'problem',problem,'runId',r,'seed',seed, ...
                'platform',cfg.platform, ...
                'file',fullfile(cfg.dataFolder,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                algorithm,problem,cfg.M,pro.D,r)), ...
                'scratch',cfg.scratch,'manifestFile',manifestFile, ...
                'save',cfg.save,'N',cfg.N,'M',cfg.M,'D',pro.D,'maxFE',cfg.maxFE);
            if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
        end
    end
end

function status = runOne(job)
%runOne Evaluate one problem instance and store the result atomically.
    status = struct('ok',false,'problem',job.problem,'runId',job.runId, ...
        'IGD',NaN,'message','','file',job.file,'runtimeSeconds',NaN);
    previousPath = path;
    cleanup = onCleanup(@()path(previousPath)); %#ok<NASGU>
    temporary = '';
    try
        if ~isempty(job.platform), addpath(genpath(job.platform)); end
        addpath(job.algFolder,'-begin');
        assert(strcmpi(fileparts(which(job.algorithm)),job.algFolder), ...
            'Unexpected algorithm resolution.');
        assert(~isfile(job.file),'Refusing to overwrite an existing result.');
        manifest = jsondecode(fileread(job.manifestFile));
        sources = manifest.sources;
        for k = 1:numel(sources)
            assert(strcmp(sources(k).sha256,sha256File(sources(k).path)), ...
                'Source changed during the experiment: %s',sources(k).path);
        end
        dacefitAt = which('dacefit');
        predictorAt = which('predictor');
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        assert(pro.D==job.D);
        started = tic;
        progressFile = fullfile(job.scratch,sprintf('progress_%s_%02d.txt', ...
            job.problem,job.runId));
        if isfile(progressFile), delete(progressFile); end
        alg = feval(job.algorithm,'save',job.save,'run',1, ...
            'outputFcn',@(a,p) logProgress(progressFile,p,started));
        rng(job.seed,'twister');
        metadata = struct('algorithm',job.algorithm,'problem',job.problem, ...
            'runId',job.runId,'seed',job.seed,'N',job.N,'M',job.M,'D',job.D, ...
            'maxFE',job.maxFE,'save',job.save,'parameters','defaults', ...
            'dacefit',dacefitAt,'predictor',predictorAt, ...
            'threads',maxNumCompThreads,'matlabVersion',version, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        alg.Solve(pro);
        metadata.runtimeSeconds = toc(started);
        assert(~isempty(alg.result) && pro.FE == job.maxFE && ...
            alg.result{end,1} == pro.FE,'Incomplete run: FE=%d.',pro.FE);
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
            error('NSGAIIIEHVI:ResultAppeared','Result now exists; not overwriting.');
        end
        [ok,message] = movefile(temporary,job.file);
        assert(ok,'%s',message);
        temporary = '';
        status.ok = true; status.IGD = metric.IGD(end);
        status.runtimeSeconds = metadata.runtimeSeconds;
    catch err
        status.message = err.message;
        file = fullfile(job.scratch,sprintf('FAILED_%s_run%02d.txt', ...
            job.problem,job.runId));
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
%   Worker output does not reach the client, so progress goes to a file in the
%   scratch folder instead; the file is keyed by problem and run number.
    fid = fopen(file,'a');
    if fid >= 0
        fprintf(fid,'FE=%d t=%.1f\n',Problem.FE,toc(started));
        fclose(fid);
    end
end

function summary = reportState(cfg,algorithm)
%reportState Count the products already stored per problem and per run.
    summary = struct('problem',{},'runs',{},'missing',{});
    for p = 1:numel(cfg.problems)
        problem = cfg.problems{p};
        pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
        have = false(1,20);
        for r = 1:20
            f = fullfile(cfg.dataFolder,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                algorithm,problem,cfg.M,pro.D,r));
            have(r) = isfile(f);
        end
        entry = struct('problem',problem,'runs',sum(have), ...
            'missing',{sprintf('%d ',find(~have))});
        if isempty(summary), summary = entry; else, summary(end+1) = entry; end %#ok<AGROW>
        fprintf('%-7s stored %2d/20  missing: %s\n',problem,sum(have),entry.missing{1});
    end
    fprintf('total %d/320\n',sum([summary.runs]));
end
