function RunDISK_M20(mode, workers, outOverride)
%RunDISK_M20  DTLZ/WFG sweep of DISK at M=20.
%
%   RunDISK_M20('run',WORKERS)          16 problems x 20 runs
%   RunDISK_M20('smoke',WORKERS)        one problem (WFG9), one run, serial
%   RunDISK_M20('check',WORKERS)        one problem (DTLZ2), one run, serial
%   RunDISK_M20('probe',WORKERS)        DTLZ2 and DTLZ4, one run each
%   RunDISK_M20('run',WORKERS,OUTROOT)  redirect results
%
%   Protocol (same as every other M=20 baseline in this project):
%     problems  DTLZ1..7 + WFG1..9, requested D = 30, N = 100, maxFE = 300
%     runs      1..20, SaveCount 30 snapshots
%     algorithm DISK (2024 TEVC, distribution-based Kriging-assisted EA).
%               No 'parameter' is passed, so ParameterSet falls back to the
%               class defaults {wmax=60, alpha=5}; passing the house
%               5-element vector would silently overwrite both.
%               DISK takes its population size from Problem.N and builds the
%               initial design with NI = Problem.N = 100 true evaluations.
%     seed      20260912 + M*100000 + 1000*problemIndex + run, applied with
%               rng(seed,'twister') BEFORE the problem is constructed
%               (M=20 -> SeedBase 22260912)
%     threads   1 per worker
%     metrics   runtime, IGD and IGDp traces of all 30 snapshots
%               (DTLZ7 at M=20 is filled in later by MergeIGDpForDir, its
%                524288-point reference set cannot be computed inside a pool)
%
%   Results  <TESTROOT>\20目标\DISK
%   Logs     .workbuddy\ablation_logs            (the data folder stays MAT-only)

    if nargin < 1 || isempty(mode),       mode    = 'run'; end
    if nargin < 2 || isempty(workers),    workers = 5; end
    if nargin < 3,                        outOverride = ''; end

    cfg.testRoot  = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    cfg.platRoot  = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.scriptDir = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts';
    cfg.logDir    = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    cfg.className = 'DISK';
    cfg.algName   = 'DISK';
    cfg.passParams = false;              % keep the published class defaults
    cfg.problems  = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                     'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    cfg.M         = 20;
    cfg.Dreq      = 30;
    cfg.N         = 100;
    cfg.maxFE     = 300;
    cfg.saveN     = 30;
    cfg.runs      = 1:20;
    cfg.onlyProbs = {};
    cfg.seedBase  = 20260912 + cfg.M*100000;
    cfg.outDir    = fullfile(cfg.testRoot,sprintf('%d目标',cfg.M),cfg.algName);
    if ~isempty(outOverride)
        cfg.outDir = fullfile(outOverride,cfg.algName);
    end
    if ~isfolder(cfg.outDir), mkdir(cfg.outDir); end
    if ~isfolder(cfg.logDir), mkdir(cfg.logDir); end

    switch lower(mode)
        case 'run',   RunSweep(cfg, workers);
        case 'smoke', cfg.onlyProbs = {'WFG9'};
                      cfg.runs      = 1;
                      RunSweep(cfg, min(workers,1));
        case 'check', cfg.onlyProbs = {'DTLZ2'};
                      cfg.runs      = 1;
                      RunSweep(cfg, min(workers,1));
        case 'probe', cfg.onlyProbs = {'DTLZ1','DTLZ2','DTLZ7','WFG3','WFG9'};
                      cfg.runs      = 1;
                      RunSweep(cfg, workers);
        otherwise,    error('RunDISK_M20:Mode','Unknown mode %s', mode);
    end
end

% ------------------------------------------------------------------------
function RunSweep(cfg, workers)
    addpath(genpath(cfg.platRoot));
    addpath(cfg.scriptDir);
    warning('off','stats:pdist2:ZeroPoints');   % HES_EA projects two random axes

    jobs = struct('probIdx',{},'prob',{},'run',{},'seed',{});
    for p = 1:numel(cfg.problems)
        if ~isempty(cfg.onlyProbs) && ~ismember(cfg.problems{p},cfg.onlyProbs)
            continue;                            % the index p stays the global one
        end
        for r = cfg.runs
            j.probIdx = p;
            j.prob    = cfg.problems{p};
            j.run     = r;
            j.seed    = cfg.seedBase + 1000*p + r;
            jobs(end+1) = j;                     %#ok<AGROW>
        end
    end

    if workers >= 2
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('Processes', workers);
        elseif pool.NumWorkers ~= workers
            delete(pool); pool = parpool('Processes', workers);
        end
        pctRunOnAll(['addpath(genpath(''' cfg.platRoot '''));' ...
                     'addpath(''' cfg.scriptDir ''');' ...
                     'maxNumCompThreads(1);' ...
                     'warning(''off'',''stats:pdist2:ZeroPoints'');']);
    end

    stamp = datestr(now,'yyyymmdd_HHMMSS');     %#ok<DATST>
    logFile = fullfile(cfg.logDir, sprintf('%s_M%d_%s.log', cfg.algName, cfg.M, stamp));
    fid = fopen(logFile,'a');
    fprintf(fid,'# %s M=%d params=class-default runs=%s seedBase=%d workers=%d\n', ...
        cfg.algName, cfg.M, mat2str(cfg.runs), cfg.seedBase, workers);
    fprintf(fid,'# jobs=%d\n', numel(jobs));

    t0 = tic;
    runtime = nan(numel(jobs),1);
    status  = zeros(numel(jobs),1);
    if workers >= 2
        parfor k = 1:numel(jobs)
            [status(k),runtime(k),~] = RunOneJob(cfg, jobs(k));
        end
    else
        for k = 1:numel(jobs)
            [status(k),runtime(k),msg] = RunOneJob(cfg, jobs(k));
            if status(k) == -1
                fprintf(2,'FAIL %s %s run%d: %s\n', cfg.algName, jobs(k).prob, jobs(k).run, msg);
            end
        end
    end
    elapsed = toc(t0);

    fprintf(fid,'# done in %.1f s ; ok=%d fail=%d ; sum runtime %.1f h\n', ...
        elapsed, sum(status==1), sum(status==-1), nansum(runtime)/3600);
    fprintf(fid,'# skip=%d (already present)\n', sum(status==2));
    fclose(fid);

    fprintf('=== %s M=%d : %d jobs, ok=%d skipped=%d failed=%d, elapsed %.1f h\n', ...
        cfg.algName, cfg.M, numel(jobs), sum(status==1), sum(status==2), ...
        sum(status==-1), elapsed/3600);
end

% ------------------------------------------------------------------------
function [ok,rt,msg] = RunOneJob(cfg, job)
%RunOneJob  Returns ok = 1 (written), 2 (already there), -1 (failed).
    ok  = -1;
    rt  = 0;
    msg = '';
    maxNumCompThreads(1);
    warning('off','stats:pdist2:ZeroPoints');
    try
        rng(job.seed,'twister');
        P = feval(job.prob,'M',cfg.M,'D',cfg.Dreq,'maxFE',cfg.maxFE,'N',cfg.N);
        outFile = fullfile(cfg.outDir, sprintf('%s_%s_M%d_D%d_%d.mat', ...
            cfg.algName, job.prob, cfg.M, P.D, job.run));
        if exist(outFile,'file') == 2
            ok = 2; return;
        end

        if cfg.passParams
            Alg = feval(cfg.className,'parameter',cfg.params, ...
                        'save',cfg.saveN,'run',job.run);
        else
            Alg = feval(cfg.className,'save',cfg.saveN,'run',job.run);
        end
        Alg.Solve(P);
        Alg.CalMetric('IGD');
        % DTLZ7 / M=20 holds 524288 reference points; the stock IGDp loop needs
        % seconds per snapshot and destabilises the pool, so it is filled in
        % later by MergeIGDpForDir.
        if ~(strcmp(job.prob,'DTLZ7') && cfg.M == 20)
            Alg.CalMetric('IGDp');
        end
        result = Alg.result;                                     %#ok<NASGU>
        metric = Alg.metric;                                     %#ok<NASGU>
        rt = metric.runtime;
        tmpFile = [outFile '.tmp'];
        save(tmpFile,'result','metric');
        movefile(tmpFile,outFile,'f');
        ok = 1;
    catch err
        msg = err.message;
        if strlength(string(msg)) > 200
            msg = char(extractBefore(string(msg),200));
        end
        ok = -1;
    end
end
