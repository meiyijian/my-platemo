function summary = RunLambdat050Compare(action,workers)
%RunLambdat050Compare Paired lambdaT=0.50 vs lambdaT=0.30 comparison.
%   RunLambdat050Compare('check')      audit the planned runs, no optimization.
%   RunLambdat050Compare('run',W)      fill the experiment with W workers.
%
%   Scope: DTLZ2, DTLZ4, DTLZ5, DTLZ7; M=10, D=30, N=100, maxFE=300;
%   run IDs 21..30 (ten runs per problem and arm). Both arms execute inside
%   the same process pool with identical seeds, so every run ID forms a true
%   matched pair: the only difference between the arms is the reward weight.
%     arm lambdat050 - REMO_UniformMix_Pruned_Weighted_Lambdat050 (new)
%     arm lambdat030 - REMO_UniformMix_Pruned_Weighted_Lambdat030 (control)
%   Nothing is written except one .mat per run.

    if nargin < 1, action = 'check'; end
    if nargin < 2, workers = 6; end
    assert(ismember(action,{'run','check'}),'Use run or check.');
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});

    cfg = configuration();
    addpath(genpath(cfg.platform));
    addpath(cfg.variantFolder);
    addpath(cfg.controlFolder);
    jobs = buildJobs(cfg);
    pending = arrayfun(@(j) ~isfile(j.file),jobs);
    fprintf('Problems  : %s\n',strjoin(cfg.problems,', '));
    fprintf('Budget    : M=%d D=%d N=%d maxFE=%d runIds=%d..%d\n', ...
        cfg.M,cfg.D,cfg.N,cfg.maxFE,cfg.runIds(1),cfg.runIds(end));
    fprintf('Arms      : lambdat050 lambdaT=0.50; lambdat030 lambdaT=0.30\n');
    fprintf('Planned %d runs; present %d; to run %d.\n', ...
        numel(jobs),sum(~pending),sum(pending));
    if strcmp(action,'check')
        fprintf('CHECK PASSED. No optimization started.\n');
        return;
    end
    jobs = jobs(pending);
    if isempty(jobs), fprintf('Nothing to run.\n'); summary = []; return; end

    if ~isfolder(cfg.variantData), mkdir(cfg.variantData); end
    if ~isfolder(cfg.controlData), mkdir(cfg.controlData); end

    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('Processes',workers);
    end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
    fprintf('Using %d process workers.\n',pool.NumWorkers);

    futures = parallel.FevalFuture.empty;
    for i = 1:numel(jobs)
        futures(i) = parfeval(pool,@runOne,1,jobs(i),cfg.platform); %#ok<AGROW>
    end
    cleanup = onCleanup(@()cancel(futures)); %#ok<NASGU>
    summary = struct([]);
    failures = 0;
    wall = tic;
    for i = 1:numel(jobs)
        [~,s] = fetchNext(futures);
        if isempty(summary), summary = s; else, summary(end+1) = s; end %#ok<AGROW>
        if s.ok
            fprintf('[%d/%d] %-10s %-6s run %02d IGD=%.10g (%.0f s)\n', ...
                i,numel(jobs),s.arm,s.problem,s.runId,s.IGD,s.runtimeSeconds);
        else
            failures = failures + 1;
            fprintf(2,'[%d/%d] FAILED %s %s run %02d: %s\n', ...
                i,numel(jobs),s.arm,s.problem,s.runId,s.message);
        end
    end
    fprintf('Wall time %.1f min. Completed %d, failed %d.\n', ...
        toc(wall)/60,sum([summary.ok]),failures);
    if failures > 0
        error('AdaMaO:RunsFailed','%d job(s) failed.',failures);
    end
end

function cfg = configuration()
%configuration Fixed scope of this comparison.
    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    optimization = fullfile(platform,'Algorithms','Multi-objective optimization');
    cfg.platform = platform;
    cfg.variant = 'REMO_UniformMix_Pruned_Weighted_Lambdat050';
    cfg.control = 'REMO_UniformMix_Pruned_Weighted_Lambdat030';
    cfg.variantFolder = fullfile(optimization,cfg.variant);
    cfg.controlFolder = fullfile(optimization,cfg.control);
    dataRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30';
    cfg.variantData = fullfile(dataRoot,cfg.variant);
    cfg.controlData = fullfile(cfg.variantData,'control_lambdat030');
    cfg.problems = {'DTLZ2','DTLZ4','DTLZ5','DTLZ7'};
    cfg.problemIndex = [2,4,5,7];
    cfg.runIds = 21:30;
    cfg.N = 100;
    cfg.M = 10;
    cfg.D = 30;
    cfg.maxFE = 300;
    cfg.parameters = {3000,0.50,0.25,0.70,6};
end

function jobs = buildJobs(cfg)
%buildJobs One job per problem, run ID and arm, with matched seeds.
    jobs = struct([]);
    for p = 1:numel(cfg.problems)
        problem = cfg.problems{p};
        pro = feval(problem,'N',cfg.N,'M',cfg.M,'D',cfg.D,'maxFE',cfg.maxFE);
        assert(pro.D==cfg.D && pro.M==cfg.M,'Problem specification mismatch.');
        for r = cfg.runIds
            seed = 20260912 + cfg.M*100000 + cfg.problemIndex(p)*1000 + r;
            arms = { ...
                'lambdat050',cfg.variant,cfg.variantFolder,0.50,cfg.variantData; ...
                'lambdat030',cfg.control,cfg.controlFolder,0.30,cfg.controlData};
            for a = 1:size(arms,1)
                job = struct('arm',arms{a,1},'algorithm',arms{a,2}, ...
                    'algFolder',arms{a,3},'lambdaT',arms{a,4}, ...
                    'problem',problem,'runId',r,'seed',seed, ...
                    'N',cfg.N,'M',cfg.M,'D',pro.D,'maxFE',cfg.maxFE, ...
                    'parameters',{cfg.parameters}, ...
                    'file',fullfile(arms{a,5},sprintf('%s_%s_M%d_D%d_%d.mat', ...
                    arms{a,2},problem,cfg.M,pro.D,r)));
                if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
            end
        end
    end
end

function status = runOne(job,platform)
%runOne Evaluate one problem instance and store the result atomically.
    status = struct('ok',false,'arm',job.arm,'problem',job.problem, ...
        'runId',job.runId,'IGD',NaN,'FE',0,'runtimeSeconds',NaN, ...
        'message','','file',job.file);
    previousPath = path;
    cleanup = onCleanup(@()path(previousPath)); %#ok<NASGU>
    temporary = '';
    try
        addpath(genpath(platform));
        % The arm folder is prepended so that the arm resolves its own helper
        % functions first; the variant keeps them isolated in private/.
        addpath(job.algFolder);
        assert(strcmpi(fileparts(which(job.algorithm)),job.algFolder), ...
            'Unexpected algorithm resolution.');
        assert(~isfile(job.file),'Refusing to overwrite an existing result.');
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        assert(pro.D==job.D,'Problem dimension mismatch.');
        alg = feval(job.algorithm,'parameter',job.parameters,'save',30, ...
            'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        started = tic;
        alg.Solve(pro);
        status.runtimeSeconds = toc(started);
        assert(~isempty(alg.result) && pro.FE == job.maxFE && ...
            alg.result{end,1} == pro.FE,'Incomplete run.');
        alg.CalMetric('IGD');
        metric = alg.metric;
        assert(all(isfinite(metric.IGD)) && all(metric.IGD >= 0),'Invalid IGD.');
        result = alg.result;
        metadata = struct('algorithm',job.algorithm,'arm',job.arm, ...
            'lambdaT',job.lambdaT,'problem',job.problem,'runId',job.runId, ...
            'seed',job.seed,'parameters',{job.parameters},'N',job.N, ...
            'M',job.M,'D',job.D,'maxFE',job.maxFE,'save',30, ...
            'actualFE',pro.FE,'threads',maxNumCompThreads, ...
            'matlabVersion',version);
        folder = fileparts(job.file);
        if ~isfolder(folder), mkdir(folder); end
        temporary = [tempname(folder),'.mat'];
        save(temporary,'result','metric','metadata','-v7');
        [ok,message] = movefile(temporary,job.file);
        assert(ok,'%s',message);
        temporary = '';
        status.ok = true;
        status.IGD = metric.IGD(end);
        status.FE = pro.FE;
    catch err
        status.message = err.message;
        if ~isempty(temporary) && isfile(temporary), delete(temporary); end
    end
end
