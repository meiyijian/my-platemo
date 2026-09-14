function RunOriginal_10(action)
%RunOriginal_10 Run the full Original criterion as a third arm of the comparison.
%   RunOriginal_10('check') audits the planned runs without optimizing.
%   RunOriginal_10('run')   fills the 40 planned runs.
%   DTLZ2/4/5/7, M=10, D=30, N=100, maxFE=300, run IDs 19..28 with the same
%   seeds as the Lambda020 and baseline arms, so all three arms are matched
%   triples inside one process-pool context.
%   The Original criterion is the full version: qKeep=0.80, lambda0=0.35 with
%   the p_err gate, nMin=4 completion and the second indicator filter. Its
%   parameter order is gmax,pMix,rGood,qKeep,lambda0,nMin,nMax.
%   Results are written to the diagnostics folder and never overwrite anything.

    if nargin < 1, action = 'run'; end
    assert(ismember(action,{'run','check'}),'Use run or check.');

    algorithm = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original';
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    platform = fileparts(fileparts(fileparts(root)));
    addpath(genpath(platform));
    assert(strcmpi(fileparts(which(algorithm)), ...
        fullfile(platform,'Algorithms','Multi-objective optimization',algorithm)), ...
        'The Original algorithm does not resolve to its own folder.');

    cfg = configuration(root,platform,algorithm);
    if ~isfolder(cfg.outFolder), mkdir(cfg.outFolder); end
    manifest = sourceManifest(cfg.algFolder);
    manifestFile = fullfile(cfg.logs,['sources_original_', ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')),'.json']);
    fid = fopen(manifestFile,'w','n','UTF-8');
    assert(fid >= 0,'Cannot write the source manifest.');
    fwrite(fid,jsonencode(struct('algorithmFolder',cfg.algFolder, ...
        'parameters',{cfg.parameters},'sources',manifest)));
    fclose(fid);

    jobs = buildJobs(cfg,manifestFile);
    pending = true(size(jobs));
    for i = 1:numel(jobs)
        if isfile(jobs(i).file), pending(i) = false; end
    end
    fprintf('Arm       : original %s\n',mat2str(cell2mat(cfg.parameters)));
    fprintf('Planned runs: %d; already present: %d; to run: %d\n', ...
        numel(jobs),sum(~pending),sum(pending));
    fprintf('Output    : %s\n',cfg.outFolder);
    if strcmp(action,'check')
        fprintf('CHECK PASSED. No optimization started.\n');
        return;
    end
    jobs = jobs(pending);
    if isempty(jobs), fprintf('Nothing to run.\n'); return; end

    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes',cfg.workers); end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
    fprintf('Using %d process workers.\n',pool.NumWorkers);
    setup = parfevalOnAll(pool,@prepareWorker,0,platform,cfg.algFolder);
    fetchOutputs(setup);

    futures = parallel.FevalFuture.empty;
    for i = 1:numel(jobs)
        futures(i) = parfeval(pool,@runOne,1,jobs(i)); %#ok<AGROW>
    end
    cleanup = onCleanup(@()cancel(futures)); %#ok<NASGU>
    failures = 0;
    for i = 1:numel(jobs)
        [~,s] = fetchNext(futures);
        if s.ok
            fprintf('[%d/%d] original %s run %02d IGD=%.10g\n', ...
                i,numel(jobs),s.problem,s.runId,s.IGD);
        else
            failures = failures + 1;
            fprintf(2,'[%d/%d] FAILED original %s run %02d: %s\n', ...
                i,numel(jobs),s.problem,s.runId,s.message);
        end
    end
    if failures > 0
        error('AdaMaO:OriginalRunsFailed','%d job(s) failed. See %s.', ...
            failures,cfg.logs);
    end
    fprintf('COMPLETE: %d original run(s) finished.\n',numel(jobs));
end

function prepareWorker(platform,algFolder)
%prepareWorker Give every worker the same paths as the client.
    addpath(genpath(platform));
    addpath(algFolder);
end

function cfg = configuration(root,platform,algorithm)
%configuration Fixed scope of the Original arm.
    cfg.root = root;
    cfg.platform = platform;
    cfg.algorithm = algorithm;
    cfg.algFolder = fullfile(platform,'Algorithms','Multi-objective optimization',algorithm);
    cfg.logs = fullfile(root,'diagnostics','lambda020_10runs');
    cfg.outFolder = fullfile(cfg.logs,'original_in_session');
    cfg.parameters = {3000,0.50,0.25,0.80,0.35,4,6};
    cfg.problems = {'DTLZ2','DTLZ4','DTLZ5','DTLZ7'};
    cfg.problemIndex = [2,4,5,7];
    cfg.runIds = 19:28;
    cfg.N = 100;
    cfg.M = 10;
    cfg.D = 30;
    cfg.maxFE = 300;
    cluster = parcluster('Processes');
    cfg.workers = min(cluster.NumWorkers, ...
        str2double(getenv('NUMBER_OF_PROCESSORS')));
end

function jobs = buildJobs(cfg,manifestFile)
%buildJobs One job per problem and run ID with matched seeds.
    jobs = struct([]);
    for p = 1:numel(cfg.problems)
        problem = cfg.problems{p};
        pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
        assert(pro.D==cfg.D && pro.M==cfg.M && pro.N==cfg.N);
        for r = cfg.runIds
            seed = 20260912 + cfg.M*100000 + cfg.problemIndex(p)*1000 + r;
            job = struct('algorithm',cfg.algorithm,'algFolder',cfg.algFolder, ...
                'parameters',{cfg.parameters},'problem',problem,'runId',r, ...
                'seed',seed,'platform',cfg.platform,'logs',cfg.logs, ...
                'manifestFile',manifestFile, ...
                'file',fullfile(cfg.outFolder,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                cfg.algorithm,problem,cfg.M,pro.D,r)), ...
                'N',cfg.N,'M',cfg.M,'D',pro.D,'maxFE',cfg.maxFE);
            if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
        end
    end
end

function status = runOne(job)
%runOne Evaluate one problem instance and store the result atomically.
    status = struct('ok',false,'problem',job.problem,'runId',job.runId, ...
        'IGD',NaN,'message','','file',job.file);
    previousPath = path;
    cleanup = onCleanup(@()path(previousPath)); %#ok<NASGU>
    temporary = '';
    try
        addpath(genpath(job.platform));
        addpath(job.algFolder);
        assert(strcmpi(fileparts(which(job.algorithm)),job.algFolder), ...
            'Unexpected algorithm resolution.');
        assert(~isfile(job.file),'Refusing to overwrite an existing result.');
        manifest = jsondecode(fileread(job.manifestFile));
        for k = 1:numel(manifest.sources)
            assert(strcmp(manifest.sources(k).sha256, ...
                sha256(manifest.sources(k).path)), ...
                'Source changed during the experiment: %s',manifest.sources(k).path);
        end
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        alg = feval(job.algorithm,'parameter',job.parameters,'save',30, ...
            'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        metadata = struct('algorithm',job.algorithm,'arm','original', ...
            'problem',job.problem,'runId',job.runId,'seed',job.seed, ...
            'modeRunId',1,'parameters',{job.parameters},'lambda0',0.35, ...
            'qKeep',0.80,'nMin',4,'N',job.N,'M',job.M,'D',job.D, ...
            'maxFE',job.maxFE,'save',30,'threads',maxNumCompThreads, ...
            'matlabVersion',version,'rngBeforeSolve',rng, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        started = tic;
        alg.Solve(pro);
        metadata.runtimeSeconds = toc(started);
        assert(~isempty(alg.result) && pro.FE == job.maxFE && ...
            alg.result{end,1} == pro.FE,'Incomplete run.');
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
        status.ok = true; status.IGD = metric.IGD(end);
    catch err
        status.message = err.message;
        file = fullfile(job.logs,sprintf('FAILED_original_%s_run%02d.txt', ...
            job.problem,job.runId));
        fid = fopen(file,'w','n','UTF-8');
        if fid >= 0
            fprintf(fid,'%s',getReport(err,'extended','hyperlinks','off'));
            fclose(fid);
        end
        if ~isempty(temporary) && isfile(temporary), delete(temporary); end
    end
end

function manifest = sourceManifest(folder)
%sourceManifest SHA-256 of every source file of the Original algorithm.
    files = [dir(fullfile(folder,'*.m'));dir(fullfile(folder,'private','*.m'))];
    manifest = struct('path',{},'sha256',{});
    for i = 1:numel(files)
        if strcmp(files(i).name(1),'.'), continue; end
        file = fullfile(files(i).folder,files(i).name);
        manifest(end+1) = struct('path',file,'sha256',sha256(file)); %#ok<AGROW>
    end
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
