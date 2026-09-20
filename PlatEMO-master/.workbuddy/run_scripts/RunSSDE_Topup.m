function RunSSDE_Topup(M, workers, mode)
%RunSSDE_Topup  Add runs 19 and 20 of SSDE for one objective count.
%
%   RunSSDE_Topup(20,5)          top up 20目标\SSDE  (runs 19:20)
%   RunSSDE_Topup(15,5)          top up 15目标\SSDE  (runs 19:20)
%   RunSSDE_Topup(20,1,'check')  one problem (DTLZ1), run 19 only
%
%   Why only runs 19:20: the archived 288 files per objective count (16
%   problems x runs 1..18) came from an unrecorded 2026-07-12 batch whose seed
%   formula could not be recovered (63 candidate formulas were tested against
%   the first snapshot's IGD, which is a pure function of the seed - no match).
%   Runs 1..18 are kept as they are; runs 19 and 20 use the project's
%   documented scheme so at least the additions are reproducible.
%
%   Protocol (identical to the archived files):
%     problems  DTLZ1..7 + WFG1..9, requested D = 30 (WFG2/3 round up to 31 at
%               M=20 and stay 30 at M=15 - that is WFG2/3's own Setting rule)
%     N = 100, maxFE = 300, SaveCount = 30, threads = 1
%     seed      20260912 + M*100000 + 1000*problemIndex + run
%               (M=20 -> 22260912, M=15 -> 21760912)
%     metrics   runtime + IGD only, exactly like the archived files; IGD+ is
%               added afterwards by MergeIGDpForDir
%
%   Results  <TESTROOT>\<M>目标\SSDE
%   Logs     .workbuddy\ablation_logs            (the data folder stays MAT-only)

    if nargin < 1 || isempty(M),       M       = 20; end
    if nargin < 2 || isempty(workers), workers = 5;  end
    if nargin < 3 || isempty(mode),    mode    = 'run'; end

    cfg.testRoot  = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    cfg.platRoot  = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.scriptDir = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts';
    cfg.logDir    = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    cfg.className = 'SSDE';
    cfg.algName   = 'SSDE';
    cfg.M         = M;
    cfg.Dreq      = 30;
    cfg.N         = 100;
    cfg.maxFE     = 300;
    cfg.saveN     = 30;
    cfg.runs      = 19:20;
    cfg.onlyProbs = {};
    cfg.seedBase  = 20260912 + M*100000;
    cfg.outDir    = fullfile(cfg.testRoot,sprintf('%d目标',M),cfg.algName);

    if strcmpi(mode,'check')
        cfg.onlyProbs = {'DTLZ1'};
        cfg.runs      = 19;
    end
    if ~isfolder(cfg.outDir), mkdir(cfg.outDir); end
    if ~isfolder(cfg.logDir), mkdir(cfg.logDir); end

    RunSweep(cfg, max(1,min(workers,5)));
end

% ------------------------------------------------------------------------
function RunSweep(cfg, workers)
    addpath(genpath(cfg.platRoot));
    addpath(cfg.scriptDir);

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    jobs = struct('probIdx',{},'prob',{},'run',{},'seed',{});
    for p = 1:numel(problems)
        if ~isempty(cfg.onlyProbs) && ~ismember(problems{p},cfg.onlyProbs)
            continue;                       % keep the global problem index
        end
        for r = cfg.runs
            j.probIdx = p; j.prob = problems{p}; j.run = r;
            j.seed    = cfg.seedBase + 1000*p + r;
            jobs(end+1) = j;                                             %#ok<AGROW>
        end
    end

    if workers >= 2
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('Processes',workers);
        elseif pool.NumWorkers ~= workers
            delete(pool); pool = parpool('Processes',workers);
        end
        pctRunOnAll(['addpath(genpath(''' cfg.platRoot '''));' ...
                     'addpath(''' cfg.scriptDir '''); maxNumCompThreads(1);']);
    end

    stamp = datestr(now,'yyyymmdd_HHMMSS');                              %#ok<DATST>
    logFile = fullfile(cfg.logDir, sprintf('SSDE_M%d_topup_%s.log',cfg.M,stamp));
    fid = fopen(logFile,'a');
    fprintf(fid,'# SSDE M=%d top-up runs=%s seedBase=%d workers=%d jobs=%d\n', ...
        cfg.M,mat2str(cfg.runs),cfg.seedBase,workers,numel(jobs));

    t0 = tic; rt = nan(numel(jobs),1); st = zeros(numel(jobs),1);
    if workers >= 2
        parfor k = 1:numel(jobs)
            [st(k),rt(k)] = RunOneJob(cfg,jobs(k));
        end
    else
        for k = 1:numel(jobs)
            [st(k),rt(k)] = RunOneJob(cfg,jobs(k));
        end
    end
    el = toc(t0);

    fprintf(fid,'# done %.1f s ; written=%d skipped=%d failed=%d ; sum runtime %.2f h\n', ...
        el,sum(st==1),sum(st==2),sum(st==-1),nansum(rt)/3600);
    fclose(fid);
    fprintf('=== SSDE M=%d : %d jobs, written=%d skipped=%d failed=%d, %.1f s\n', ...
        cfg.M,numel(jobs),sum(st==1),sum(st==2),sum(st==-1),el);
end

% ------------------------------------------------------------------------
function [ok,rt] = RunOneJob(cfg, job)
%RunOneJob  ok = 1 written, 2 already present, -1 failed.
    ok = -1; rt = 0;
    maxNumCompThreads(1);
    try
        rng(job.seed,'twister');
        P  = feval(job.prob,'M',cfg.M,'D',cfg.Dreq,'maxFE',cfg.maxFE,'N',cfg.N);
        outFile = fullfile(cfg.outDir, sprintf('%s_%s_M%d_D%d_%d.mat', ...
            cfg.algName,job.prob,cfg.M,P.D,job.run));
        if exist(outFile,'file') == 2
            ok = 2; return;
        end
        Alg = feval(cfg.className,'save',cfg.saveN,'run',job.run);
        Alg.Solve(P);
        Alg.CalMetric('IGD');
        result = Alg.result;                                             %#ok<NASGU>
        metric = Alg.metric;                                             %#ok<NASGU>
        rt = metric.runtime;
        tmp = [outFile '.tmp'];
        save(tmp,'result','metric');
        movefile(tmp,outFile,'f');
        ok = 1;
    catch err
        fprintf(2,'FAIL %s run%d: %s\n',job.prob,job.run,err.message);
        ok = -1;
    end
end
