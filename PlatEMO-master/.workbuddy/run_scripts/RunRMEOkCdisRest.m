function summary = RunRMEOkCdisRest(action,workers)
%RunRMEOkCdisRest Run RMEO_k_CDIS on the remaining DTLZ and WFG problems.
%   RunRMEOkCdisRest('check')     audit the planned jobs, no optimization.
%   RunRMEOkCdisRest('run',W)     fill the experiment with W process workers.
%
%   Batch 1 already covered DTLZ1/2/5/7 and WFG1/3/6/8 at M=10 and M=20 with
%   18 runs each. This batch covers the remaining eight problems:
%     DTLZ ; DTLZ3, DTLZ4, DTLZ6
%     WFG  ; WFG2, WFG4, WFG5, WFG7, WFG9
%   Same protocol as batch 1: requested D=30 (WFG2 becomes D=31), N=100,
%   maxFE=300, save=30, runIds 1..18, seed 20260912 + M*1e5 + idx*1000 + runId
%   with idx following the project's canonical 16-problem order.
%   Jobs = 8 problems x 2 objective counts x 18 runs = 288.
%
%   Results go to the same folders as batch 1; nothing else is written there:
%     C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\RMEO_k_CDIS\
%     C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\RMEO_k_CDIS\

    if nargin < 1, action = 'check'; end
    if nargin < 2, workers = 6; end
    assert(ismember(action,{'run','check'}),'Use run or check.');
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});

    cfg = configuration();
    addpath(genpath(cfg.platform));
    addpath(cfg.algorithmFolder);
    assert(strcmpi(fileparts(which(cfg.algorithm)),cfg.algorithmFolder), ...
        'Unexpected algorithm resolution.');
    jobs = buildJobs(cfg);
    pending = arrayfun(@(j) ~isfile(j.file),jobs);
    fprintf('Algorithm : %s\n',cfg.algorithm);
    fprintf('Parameters: %s\n',mat2str(cell2mat(cfg.parameters)));
    fprintf('Problems  : %s\n',strjoin(cfg.problems,', '));
    fprintf('Budget    : M=10 and M=20, requested D=30, N=%d, maxFE=%d, save=%d\n', ...
        cfg.N,cfg.maxFE,cfg.save);
    fprintf('Run IDs   : %d..%d (18 per problem and objective count)\n', ...
        cfg.runIds(1),cfg.runIds(end));
    fprintf('Seed mode : %s\n',cfg.seedMode);
    fprintf('Workers   : %d\n',workers);
    fprintf('Planned %d jobs; present %d; to run %d.\n', ...
        numel(jobs),sum(~pending),sum(pending));
    for f = 1:numel(cfg.folders)
        fprintf('Data      : %s\n',cfg.folders{f});
    end
    if strcmp(action,'check')
        fprintf('CHECK PASSED. No optimization started.\n');
        summary = [];
        return;
    end
    jobs = jobs(pending);
    if isempty(jobs), fprintf('Nothing to run.\n'); summary = []; return; end
    for f = 1:numel(cfg.folders)
        if ~isfolder(cfg.folders{f}), mkdir(cfg.folders{f}); end
    end

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
            fprintf('[%d/%d] M%-2d %-6s run %02d FE=%d IGD=%.7g (%.0f s)\n', ...
                i,numel(jobs),s.M,s.problem,s.runId,s.FE,s.IGD,s.runtimeSeconds);
        else
            failures = failures + 1;
            fprintf(2,'[%d/%d] FAILED M%-2d %s run %02d: %s\n', ...
                i,numel(jobs),s.M,s.problem,s.runId,s.message);
        end
    end
    fprintf('Wall time %.1f min. Completed %d, failed %d.\n', ...
        toc(wall)/60,sum([summary.ok]),failures);
    if failures > 0
        error('RMEO_k_CDIS:RunsFailed','%d job(s) failed.',failures);
    end
end

function cfg = configuration()
%configuration Fixed scope of this batch.
    cfg.platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    optimization = fullfile(cfg.platform,'Algorithms','Multi-objective optimization');
    cfg.algorithm = 'RMEO_k_CDIS';
    cfg.algorithmFolder = fullfile(optimization,cfg.algorithm);
    cfg.parameters = {3000,0.50,0.70,6};
    cfg.problems = {'DTLZ3','DTLZ4','DTLZ6','WFG2','WFG4','WFG5','WFG7','WFG9'};
    % Canonical 16-problem ordering: DTLZ1..7 = 1..7, WFG1..9 = 8..16.
    cfg.problemIndex = [3,4,6,9,11,12,14,16];
    cfg.objectiveCounts = [10,20];
    cfg.runIds = 1:18;
    cfg.N = 100;
    cfg.requestedD = 30;
    cfg.maxFE = 300;
    cfg.save = 30;
    cfg.seedMode = 'paper';
    dataRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    cfg.folders = {fullfile(dataRoot,'10目标','n30',cfg.algorithm), ...
                   fullfile(dataRoot,'20目标',cfg.algorithm)};
end

function jobs = buildJobs(cfg)
%buildJobs One job per objective count, problem and run ID.
    jobs = struct([]);
    for m = 1:numel(cfg.objectiveCounts)
        M = cfg.objectiveCounts(m);
        folder = cfg.folders{m};
        for p = 1:numel(cfg.problems)
            problem = cfg.problems{p};
            pro = feval(problem,'N',cfg.N,'M',M,'D',cfg.requestedD, ...
                'maxFE',cfg.maxFE);
            assert(pro.M==M && pro.N==cfg.N && pro.maxFE==cfg.maxFE, ...
                'Problem specification mismatch for %s M=%d.',problem,M);
            assert(ismember(pro.D,[cfg.requestedD,cfg.requestedD+1]), ...
                'Unexpected actual D for %s M=%d.',problem,M);
            kEff = min(pro.N,max(6,ceil(1.5*pro.M)));
            for r = cfg.runIds
                if strcmp(cfg.seedMode,'legacy18')
                    seed = 20260912 + 1000*cfg.problemIndex(p) + r;
                else
                    seed = 20260912 + M*100000 + 1000*cfg.problemIndex(p) + r;
                end
                job = struct('algorithm',cfg.algorithm,'problem',problem, ...
                    'runId',r,'seed',seed,'M',M,'actualD',pro.D,'N',cfg.N, ...
                    'maxFE',cfg.maxFE,'save',cfg.save,'kEff',kEff, ...
                    'algFolder',cfg.algorithmFolder, ...
                    'parameters',{cfg.parameters}, ...
                    'file',fullfile(folder,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                    cfg.algorithm,problem,M,pro.D,r)));
                if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
            end
        end
    end
end

function status = runOne(job,platform)
%runOne Evaluate one problem instance and store the result atomically.
    status = struct('ok',false,'problem',job.problem,'runId',job.runId, ...
        'M',job.M,'IGD',NaN,'FE',0,'runtimeSeconds',NaN,'message','', ...
        'file',job.file);
    previousPath = path;
    cleanup = onCleanup(@()path(previousPath)); %#ok<NASGU>
    temporary = '';
    try
        addpath(genpath(platform));
        addpath(job.algFolder);
        assert(strcmpi(fileparts(which(job.algorithm)),job.algFolder), ...
            'Unexpected algorithm resolution.');
        assert(~isfile(job.file),'Refusing to overwrite an existing result.');
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',30,'maxFE',job.maxFE);
        assert(pro.D==job.actualD && pro.M==job.M,'Problem dimension mismatch.');
        alg = feval(job.algorithm,'parameter',job.parameters,'save',job.save, ...
            'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        metadata = struct('algorithm',job.algorithm,'problem',job.problem, ...
            'runId',job.runId,'seed',job.seed,'modeRunId',1, ...
            'parameters',{job.parameters},'N',job.N,'M',job.M, ...
            'D',job.actualD,'maxFE',job.maxFE,'save',job.save, ...
            'referenceSolutions',job.kEff,'threads',maxNumCompThreads, ...
            'matlabVersion',version, 'batch','rest_dtlz_wfg', ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
            'rngBeforeSolve',rng);
        started = tic;
        alg.Solve(pro);
        status.runtimeSeconds = toc(started);
        assert(pro.FE == job.maxFE,'Run ended at FE=%d instead of %d.', ...
            pro.FE,job.maxFE);
        result = alg.result;
        assert(~isempty(result) && result{end,1} == pro.FE,'Incomplete run.');
        alg.CalMetric('IGD');
        metric = alg.metric;
        assert(all(isfinite(metric.IGD)) && all(metric.IGD >= 0),'Invalid IGD.');
        metadata.runtimeSeconds = status.runtimeSeconds;
        metadata.actualFE = pro.FE;
        metadata.finalN = length(pro);
        metadata.finished = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
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
