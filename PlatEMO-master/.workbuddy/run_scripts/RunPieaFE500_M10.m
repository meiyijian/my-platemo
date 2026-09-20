function RunPieaFE500_M10(mode, workers)
%RunPieaFE500_M10  PIEA sweep at N=100, maxFE=500, M=10.
%
%   RunPieaFE500_M10('run',WORKERS)    16 problems x 20 runs
%   RunPieaFE500_M10('smoke',WORKERS)  one problem, one run
%
%   Protocol
%     problems  DTLZ1..7 + WFG1..9   (16 problems, DTLZ first)
%     M = 10, N = 100, maxFE = 500
%     D         DTLZ1 = M+4 = 14, WFG1 = M+4 = 14, all others = M+9 = 19
%     runs      1..20, SaveCount 30 snapshots
%     algorithm PIEA at its published defaults eta=5, R_max=20, tau=20
%     seed      20260912 + M*100000 + 1000*problemPosition + runId,
%               applied with rng(seed,'twister') before the problem exists
%     metrics   runtime, IGD and IGDp of every snapshot
%
%   Results  C:\Users\lsx\Desktop\REMOnandDREMO测试集\10目标\默认n\FE500\PIEA
%            -> PIEA_<Problem>_M10_D<D>_<run>.mat  (fields result, metric, metadata)
%
%   NOTE ON PATH SHADOWING
%     Shape_Estimate, NDSort_SDR and UpdateInformation all exist as top-level
%     files in several algorithm folders. PIEA needs its own copies, so the
%     PIEA folder is forced to the front of the path and the resolution is
%     asserted in every worker before a run starts.

    if nargin < 1 || isempty(mode),    mode    = 'run'; end
    if nargin < 2 || isempty(workers), workers = 5;   end

    cfg.platRoot  = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.algName   = 'PIEA';
    cfg.algDir    = fullfile(cfg.platRoot,'Algorithms','Multi-objective optimization','PIEA');
    cfg.scriptDir = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts';
    cfg.testRoot  = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    cfg.outDir    = fullfile(cfg.testRoot,'10目标','默认n','FE500',cfg.algName);
    cfg.logDir    = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    cfg.problems  = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                     'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    % D = M+4 for DTLZ1/WFG1, M+9 for every other problem (M = 10).
    cfg.Dreq      = [14 19 19 19 19 19 19, 14 19 19 19 19 19 19 19 19];
    cfg.M         = 10;
    cfg.N         = 100;
    cfg.maxFE     = 500;
    cfg.saveN     = 30;
    cfg.runs      = 1:20;
    cfg.seedBase  = 20260912 + cfg.M*100000;
    cfg.onlyProbs = {};

    if ~isfolder(cfg.outDir), mkdir(cfg.outDir); end
    if ~isfolder(cfg.logDir), mkdir(cfg.logDir); end

    switch lower(mode)
        case 'run'
            RunSweep(cfg,workers);
        case 'smoke'
            cfg.onlyProbs = {'DTLZ1'};
            cfg.runs      = 1;
            RunSweep(cfg,1);
        otherwise
            error('RunPieaFE500_M10:Mode','Unknown mode %s',mode);
    end
end

% ------------------------------------------------------------------------
function RunSweep(cfg, workers)
    addpath(genpath(cfg.platRoot));
    addpath(cfg.algDir,'-begin');
    addpath(cfg.algDir);
    addpath(cfg.scriptDir);
    AssertResolution(cfg);

    jobs = struct('probIdx',{},'prob',{},'run',{},'seed',{},'Dreq',{});
    for p = 1:numel(cfg.problems)
        if ~isempty(cfg.onlyProbs) && ~ismember(cfg.problems{p},cfg.onlyProbs)
            continue;                     % the index p stays the global one
        end
        for r = cfg.runs
            j.probIdx = p;
            j.prob    = cfg.problems{p};
            j.run     = r;
            j.seed    = cfg.seedBase + 1000*p + r;
            j.Dreq    = cfg.Dreq(p);
            jobs(end+1) = j;              %#ok<AGROW>
        end
    end

    if workers >= 2
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('Processes',workers);
        elseif pool.NumWorkers ~= workers
            delete(pool); pool = parpool('Processes',workers);
        end
        pctRunOnAll(sprintf(['addpath(genpath(''%s''));' ...
            'addpath(''%s'',''-begin'');addpath(''%s'');addpath(''%s'');' ...
            'maxNumCompThreads(1);'], cfg.platRoot, cfg.algDir, cfg.algDir, cfg.scriptDir));
    end

    stamp   = char(datetime('now','Format','yyyyMMdd_HHmmss'));
    logFile = fullfile(cfg.logDir,sprintf('PIEA_M10_FE500_%s.log',stamp));
    fid     = fopen(logFile,'a');
    fprintf(fid,'# PIEA M=%d N=%d maxFE=%d D=(M+4 for DTLZ1/WFG1 else M+9) runs=%s\n', ...
        cfg.M,cfg.N,cfg.maxFE,mat2str(cfg.runs));
    fprintf(fid,'# seedBase=%d formula=seedBase+1000*problemPosition+runId workers=%d jobs=%d\n', ...
        cfg.seedBase,workers,numel(jobs));
    fprintf(fid,'# outDir=%s\n',cfg.outDir);

    t0      = tic;
    nJobs   = numel(jobs);
    status  = zeros(nJobs,1);
    runtime = nan(nJobs,1);
    if workers >= 2
        parfor k = 1:nJobs
            [status(k),runtime(k)] = RunOneJob(cfg,jobs(k));
        end
    else
        for k = 1:nJobs
            [status(k),runtime(k)] = RunOneJob(cfg,jobs(k));
        end
    end
    elapsed = toc(t0);

    fprintf(fid,'# done in %.1f s (%.1f min) ; ok=%d skipped=%d failed=%d\n', ...
        elapsed,elapsed/60,sum(status==1),sum(status==2),sum(status==-1));
    fprintf(fid,'# sum of job runtimes %.1f min\n',nansum(runtime)/60);
    fclose(fid);

    fprintf('=== PIEA M=%d FE=%d : %d jobs, ok=%d skipped=%d failed=%d | %.1f min\n', ...
        cfg.M,cfg.maxFE,nJobs,sum(status==1),sum(status==2),sum(status==-1),elapsed/60);
    if sum(status==-1) > 0
        error('RunPieaFE500_M10:Failed','%d job(s) failed. See %s',sum(status==-1),logFile);
    end
end

% ------------------------------------------------------------------------
function AssertResolution(cfg)
%AssertResolution Fail fast if a foreign helper shadows the PIEA one.
    names = {'PIEA','Shape_Estimate','NDSort_SDR','UpdateInformation'};
    for i = 1:numel(names)
        f = which(names{i});
        assert(~isempty(f),'Missing %s.',names{i});
        assert(strcmpi(fileparts(f),cfg.algDir), ...
            'Helper %s resolves to %s instead of %s.',names{i},fileparts(f),cfg.algDir);
    end
end

% ------------------------------------------------------------------------
function [status,rt] = RunOneJob(cfg,job)
%RunOneJob  status: 1 written, 2 already present, -1 failed.
    status = -1; rt = 0;
    try
        addpath(genpath(cfg.platRoot));
        addpath(cfg.algDir,'-begin');
        addpath(cfg.algDir);
        maxNumCompThreads(1);
        AssertResolution(cfg);

        rng(job.seed,'twister');
        P = feval(job.prob,'N',cfg.N,'M',cfg.M,'D',job.Dreq,'maxFE',cfg.maxFE);
        assert(P.D == job.Dreq,'%s reports D=%d, requested %d.',job.prob,P.D,job.Dreq);

        outFile = fullfile(cfg.outDir,sprintf('%s_%s_M%d_D%d_%d.mat', ...
            cfg.algName,job.prob,cfg.M,P.D,job.run));
        if exist(outFile,'file') == 2, status = 2; return; end

        Alg = feval(cfg.algName,'save',cfg.saveN,'run',job.run,'outputFcn',@(~,~)[]);
        t = tic;
        Alg.Solve(P);
        rt = toc(t);
        assert(P.FE == cfg.maxFE && Alg.result{end,1} == P.FE,'Incomplete run.');

        Alg.CalMetric('IGD');
        Alg.CalMetric('IGDp');
        assert(all(isfinite(Alg.metric.IGD)) && all(isfinite(Alg.metric.IGDp)), ...
            'Non-finite metric.');

        metadata = struct('algorithm',cfg.algName,'problem',job.prob, ...
            'runId',job.run,'seed',job.seed,'M',cfg.M,'N',cfg.N,'D',P.D, ...
            'maxFE',cfg.maxFE,'save',cfg.saveN,'runtimeSeconds',rt, ...
            'metricSet','IGD,IGDp', ...
            'threads',maxNumCompThreads,'matlabVersion',version, ...
            'rngBeforeSolve',rng, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        result = Alg.result;  %#ok<NASGU>
        metric = Alg.metric;  %#ok<NASGU>
        tmp = [outFile '.tmp'];
        save(tmp,'result','metric','metadata');
        if exist(outFile,'file') == 2
            delete(tmp);
            error('Result appeared during the run; not overwriting.');
        end
        movefile(tmp,outFile,'f');
        status = 1;
    catch err
        msg = err.message;
        if strlength(string(msg)) > 200, msg = char(extractBefore(string(msg),200)); end
        fprintf(2,'FAIL %s run%02d: %s\n',job.prob,job.run,msg);
        status = -1;
    end
end
