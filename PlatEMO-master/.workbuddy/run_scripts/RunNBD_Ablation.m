function RunNBD_Ablation(mode, arm, M, workers, outOverride)
%RunNBD_Ablation  Sweep driver for the two NoBatchDist deletion arms.
%
%   RunNBD_Ablation('run',ARM,M,WORKERS)      run the optimisation jobs
%   RunNBD_Ablation('post',ARM,M,WORKERS)     add IGD+ to DTLZ7 / M=20 files
%   RunNBD_Ablation('smoke',ARM,M,WORKERS)    one problem, one run, serial
%   RunNBD_Ablation('run',ARM,M,WORKERS,OUTROOT)  redirect results (smoke test)
%
%   ARM     'noCDIS'  -> REMO_noBatchDict_noCDIS   (params gmax,rGood,qKeep,nMax)
%           'noPAQC'  -> REMO_noBatchDict_noPAQC   (params gmax,pMix,qKeep,nMax)
%           'full'    -> REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
%                        (protocol-reproduction check only)
%   M       10 or 20
%   WORKERS number of parpool workers (default 5)
%
%   Protocol (frozen, mirrors the audit document
%   papers/experiments/nobatchdist_version_audit/README.md):
%     problems  DTLZ1..7 + WFG1..9, requested D = 30, N = 100, maxFE = 300
%     runs      1..20   (same run-id set as the existing NoBatchDist data)
%     seed      20260912 + M*100000 + 1000*problemIndex + run, applied with
%               rng(seed,'twister') BEFORE the problem is constructed, so the
%               reference front, the initial design and the whole search are
%               reproducible and identical across arms.
%     threads   1 per worker (maxNumCompThreads(1))
%     save      30 snapshots; each file holds 'result' and 'metric'
%
%   Results  <TESTROOT>\10目标\n30\<AlgName>  or  <TESTROOT>\20目标\<AlgName>
%   Logs     .workbuddy\ablation_logs        (the data folder stays MAT-only)

    if nargin < 1 || isempty(mode),    mode    = 'run'; end
    if nargin < 2 || isempty(arm),     arm     = 'noCDIS'; end
    if nargin < 3 || isempty(M),       M       = 10; end
    if nargin < 4 || isempty(workers), workers = 5; end
    if nargin < 5,                     outOverride = ''; end

    cfg = NBDAblationConfig(arm, M, outOverride);
    switch lower(mode)
        case 'run',   RunOptimisation(cfg, workers);
        case 'smoke', cfg.onlyProbs = {'WFG9'};
                      cfg.runs      = 1;
                      RunOptimisation(cfg, min(workers,1));
        case 'post',  PostDtlz7IGDp(cfg);
        otherwise,    error('RunNBD_Ablation:Mode','Unknown mode %s', mode);
    end
end

% ------------------------------------------------------------------------
function cfg = NBDAblationConfig(arm, M, outOverride)
    if nargin < 3, outOverride = ''; end
    cfg.testRoot  = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    cfg.platRoot  = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.scriptDir = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts';
    cfg.logDir    = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    cfg.problems  = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                     'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    cfg.M         = M;
    cfg.Dreq      = 30;
    cfg.N         = 100;
    cfg.maxFE     = 300;
    cfg.saveN     = 30;
    cfg.runs      = 1:20;
    cfg.onlyProbs = {};        % smoke-test filter; problem indices stay global
    cfg.seedBase  = 20260912 + M*100000;
    switch arm
        case 'noCDIS'
            cfg.algName = 'REMO_noBatchDict_noCDIS';
            cfg.params  = {3000,0.25,0.70,6};
        case 'noPAQC'
            cfg.algName = 'REMO_noBatchDict_noPAQC';
            cfg.params  = {3000,0.50,0.70,6};
        case 'full'
            cfg.algName = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
            cfg.params  = {3000,0.50,0.25,0.70,6};
        otherwise
            error('RunNBD_Ablation:Arm','Unknown arm %s', arm);
    end
    if M == 10
        cfg.outDir = fullfile(cfg.testRoot, '10目标', 'n30', cfg.algName);
    else
        cfg.outDir = fullfile(cfg.testRoot, sprintf('%d目标', M), cfg.algName);
    end
    if ~isempty(outOverride)
        cfg.outDir = fullfile(outOverride, cfg.algName);
    end
    if ~isfolder(cfg.outDir), mkdir(cfg.outDir); end
    if ~isfolder(cfg.logDir), mkdir(cfg.logDir); end
end

% ------------------------------------------------------------------------
function RunOptimisation(cfg, workers)
    addpath(genpath(cfg.platRoot));
    addpath(cfg.scriptDir);

    % ---- build the job list -------------------------------------------
    jobs = struct('probIdx',{},'prob',{},'run',{},'seed',{});
    for p = 1:numel(cfg.problems)
        if ~isempty(cfg.onlyProbs) && ~ismember(cfg.problems{p},cfg.onlyProbs)
            continue;                       % the index p stays the global one
        end
        for r = cfg.runs
            j.probIdx = p;
            j.prob    = cfg.problems{p};
            j.run     = r;
            j.seed    = cfg.seedBase + 1000*p + r;
            jobs(end+1) = j;                             %#ok<AGROW>
        end
    end

    % ---- open the pool ------------------------------------------------
    if workers >= 2
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('Processes', workers);
        elseif pool.NumWorkers ~= workers
            delete(pool); pool = parpool('Processes', workers);
        end
        pctRunOnAll(['addpath(genpath(''' cfg.platRoot '''));' ...
                     'addpath(''' cfg.scriptDir ''');' ...
                     'maxNumCompThreads(1);']);
    end

    stamp = datestr(now,'yyyymmdd_HHMMSS');             %#ok<DATST>
    logFile = fullfile(cfg.logDir, sprintf('%s_M%d_%s.log', cfg.algName, cfg.M, stamp));
    fid = fopen(logFile,'a');
    fprintf(fid,'# %s M=%d params=%s runs=%s seedBase=%d workers=%d\n', ...
        cfg.algName, cfg.M, mat2str(cell2mat(cfg.params)), mat2str(cfg.runs), cfg.seedBase, workers);
    fprintf('# jobs=%d\n', numel(jobs));

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
    try
        rng(job.seed,'twister');
        P = feval(job.prob,'M',cfg.M,'D',cfg.Dreq,'maxFE',cfg.maxFE,'N',cfg.N);
        outFile = fullfile(cfg.outDir, sprintf('%s_%s_M%d_D%d_%d.mat', ...
            cfg.algName, job.prob, cfg.M, P.D, job.run));
        if exist(outFile,'file') == 2
            ok = 2; return;
        end

        Alg = feval(cfg.algName,'parameter',cfg.params, ...
                    'save',cfg.saveN,'run',job.run);
        Alg.Solve(P);
        Alg.CalMetric('IGD');
        % DTLZ7 / M=20 has 524288 reference points; the stock IGDp loop needs
        % several seconds per snapshot and destabilises the pool, so it is
        % filled in later by the serial 'post' stage.
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

% ------------------------------------------------------------------------
function PostDtlz7IGDp(cfg)
%PostDtlz7IGDp  Serial pass: stock IGDp is unusable for DTLZ7 at M=20, the
%   block-wise IGDpFast is mathematically identical and bounded in memory.
    addpath(genpath(cfg.platRoot));
    addpath(cfg.scriptDir);
    maxNumCompThreads(1);
    logFile = fullfile(cfg.logDir, sprintf('%s_M%d_post.log', cfg.algName, cfg.M));
    fid = fopen(logFile,'a');
    t0 = tic;
    for r = cfg.runs
        f = fullfile(cfg.outDir, sprintf('%s_DTLZ7_M%d_D30_%d.mat', cfg.algName, cfg.M, r));
        if exist(f,'file') ~= 2
            fprintf(fid,'missing %s\n', f); continue;
        end
        S = load(f);
        if isfield(S.metric,'IGDp') && numel(S.metric.IGDp) == numel(S.result(:,1))
            fprintf(fid,'skip run %d (IGDp present)\n', r); continue;
        end
        rng(cfg.seedBase + 1000*7 + r,'twister');
        P = feval('DTLZ7','M',cfg.M,'D',cfg.Dreq,'maxFE',cfg.maxFE,'N',cfg.N);
        vals = zeros(size(S.result,1),1);
        ts = tic;
        for i = 1:size(S.result,1)
            vals(i) = IGDpFast(S.result{i,2}, P.optimum);
        end
        metric = S.metric;
        metric.IGDp = vals(:)';
        result = S.result;                                       %#ok<NASGU>
        save(f,'result','metric');
        fprintf(fid,'run %d ok : %.1f s, IGDp(end)=%.6e\n', r, toc(ts), vals(end));
    end
    fprintf(fid,'# post pass done in %.1f s\n', toc(t0));
    fclose(fid);
    fprintf('=== post done for %s M=%d in %.1f min\n', cfg.algName, cfg.M, toc(t0)/60);
end
