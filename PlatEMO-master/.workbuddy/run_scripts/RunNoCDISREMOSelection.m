function RunNoCDISREMOSelection(mode, M, workers, outOverride)
%RunNoCDISREMOSelection  Sweep driver for REMO_NoCDIS_REMOSelection.
%
%   RunNoCDISREMOSelection('run',  M, WORKERS)   run the optimisation jobs
%   RunNoCDISREMOSelection('check',M)            coverage report, nothing runs
%   RunNoCDISREMOSelection('smoke',M)            one cheap problem, one run, serial
%   RunNoCDISREMOSelection('post', M)            serial IGDp pass for DTLZ7/M=20
%   RunNoCDISREMOSelection('probe',M, WORKERS)   open the pool, run a small batch,
%                                                report per-job time and free RAM
%
%   ARM: REMO_NoCDIS_REMOSelection, params {gmax,rGood,nMax} = {3000,0.25,6}.
%        Full CDIS is replaced by the byte-identical local REMO candidate module.
%
%   Protocol is the frozen NoBatchDist ablation protocol (mirrors
%   RunNBD_Ablation.m so this arm is drop-in comparable with
%   REMO_noBatchDict_noCDIS / REMO_noBatchDict_noPAQC / the Full NoBatchDist):
%     problems  DTLZ1..7 + WFG1..9, requested D = 30 (WFG2/3 -> 31), N = 100,
%               maxFE = 300, save = 30 snapshots
%     runs      1..20
%     seed      20260912 + M*100000 + 1000*problemIndex + run, applied with
%               rng(seed,'twister') BEFORE the problem is constructed
%     threads   1 per worker (maxNumCompThreads(1))
%
%   Results  C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\<AlgName>
%            C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\<AlgName>
%   Logs     .workbuddy\nocdis_remosel_logs   (data folder stays MAT-only)
%
%   Idempotent: a job whose output file already exists is skipped.

    if nargin < 1 || isempty(mode),    mode    = 'run'; end
    if nargin < 2 || isempty(M),       M       = 10; end
    if nargin < 3 || isempty(workers), workers = 12; end
    if nargin < 4,                     outOverride = ''; end

    cfg = Config(M, outOverride);
    switch lower(mode)
        case 'run',   RunOptimisation(cfg, workers);
        case 'check', CheckCoverage(cfg);
        case 'smoke', cfg.onlyProbs = {'WFG9'};
                      cfg.runs      = 1;
                      RunOptimisation(cfg, 1);
        case 'probe', cfg.onlyProbs = cfg.problems(1:min(12,numel(cfg.problems)));
                      cfg.runs      = 1;
                      ProbeRun(cfg, workers);
        case 'post',  PostDtlz7IGDp(cfg);
        otherwise,    error('RunNoCDISREMOSelection:Mode','Unknown mode %s', mode);
    end
end

% ------------------------------------------------------------------------
function cfg = Config(M, outOverride)
    if nargin < 2, outOverride = ''; end
    cfg.testRoot  = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    cfg.platRoot  = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    cfg.scriptDir = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts';
    cfg.logDir    = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\nocdis_remosel_logs';
    cfg.problems  = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                     'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    cfg.M         = M;
    cfg.Dreq      = 30;
    cfg.N         = 100;
    cfg.maxFE     = 300;
    cfg.saveN     = 30;
    cfg.runs      = 1:20;
    cfg.onlyProbs = {};
    cfg.algName   = 'REMO_NoCDIS_REMOSelection';
    cfg.params    = {3000,0.25,6};         % gmax, rGood, nMax
    cfg.seedBase  = 20260912 + M*100000;
    if M == 10
        cfg.outDir = fullfile(cfg.testRoot, '10目标', 'n30', cfg.algName);
    else
        cfg.outDir = fullfile(cfg.testRoot, sprintf('%d目标', M), cfg.algName);
    end
    if ~isempty(outOverride), cfg.outDir = fullfile(outOverride, cfg.algName); end
    if ~isfolder(cfg.outDir), mkdir(cfg.outDir); end
    if ~isfolder(cfg.logDir), mkdir(cfg.logDir); end
end

% ------------------------------------------------------------------------
function jobs = BuildJobs(cfg)
    jobs = struct('probIdx',{},'prob',{},'run',{},'seed',{},'file',{});
    for p = 1:numel(cfg.problems)
        if ~isempty(cfg.onlyProbs) && ~ismember(cfg.problems{p},cfg.onlyProbs)
            continue;
        end
        for r = cfg.runs
            j.probIdx = p;
            j.prob    = cfg.problems{p};
            j.run     = r;
            j.seed    = cfg.seedBase + 1000*p + r;
            j.file    = '';                                 % filled after D known
            jobs(end+1) = j;                                %#ok<AGROW>
        end
    end
end

% ------------------------------------------------------------------------
function CheckCoverage(cfg)
    fprintf('=== coverage: %s M=%d\n', cfg.algName, cfg.M);
    tot = 0; have = 0; miss = {};
    for p = 1:numel(cfg.problems)
        for r = cfg.runs
            tot = tot + 1;
            nm = sprintf('%s_%s_M%d_D*_%d.mat', cfg.algName, cfg.problems{p}, cfg.M, r);
            d  = dir(fullfile(cfg.outDir, nm));
            if isempty(d), miss{end+1} = sprintf('%s_r%d', cfg.problems{p}, r); %#ok<AGROW>
            else,          have = have + 1; end
        end
    end
    fprintf('dir   : %s\n', cfg.outDir);
    fprintf('total : %d\n', tot);
    fprintf('have  : %d\n', have);
    fprintf('missing: %d\n', numel(miss));
    if ~isempty(miss) && numel(miss) <= 40
        fprintf('  %s\n', strjoin(miss, ', '));
    end
end

% ------------------------------------------------------------------------
function RunOptimisation(cfg, workers)
    addpath(genpath(cfg.platRoot));
    addpath(cfg.scriptDir);
    jobs = BuildJobs(cfg);

    if workers >= 2
        pool = OpenPool(workers);
        pctRunOnAll(['addpath(genpath(''' cfg.platRoot '''));' ...
                     'addpath(''' cfg.scriptDir ''');' ...
                     'maxNumCompThreads(1);']);
        fprintf('pool: %d workers\n', pool.NumWorkers);
    end

    stamp = datestr(now,'yyyymmdd_HHMMSS');                 %#ok<DATST>
    logFile = fullfile(cfg.logDir, sprintf('%s_M%d_%s.log', cfg.algName, cfg.M, stamp));
    fid = fopen(logFile,'a');
    fprintf(fid,'# %s M=%d params=%s runs=%s seedBase=%d workers=%d\n', ...
        cfg.algName, cfg.M, mat2str(cell2mat(cfg.params)), mat2str(cfg.runs), cfg.seedBase, workers);
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
            [st,rt,msg] = RunOneJob(cfg, jobs(k));
            status(k) = st; runtime(k) = rt;
            if st == -1
                fprintf(2,'FAIL %s %s run%d: %s\n', cfg.algName, jobs(k).prob, jobs(k).run, msg);
            end
            fprintf(fid,'[%d/%d] %s r%d rc=%d t=%.1fs\n', k, numel(jobs), jobs(k).prob, jobs(k).run, st, rt);
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
function pool = OpenPool(workers)
%OpenPool  Honour the request even when the stored profile caps NumWorkers lower.
%   The override is session-only: saveProfile is never called, so the user's
%   stored cluster configuration is left untouched.
    c = parcluster('Processes');
    if workers > c.NumWorkers
        c.NumWorkers = workers;
    end
    pool = gcp('nocreate');
    if isempty(pool) || pool.NumWorkers ~= workers
        if ~isempty(pool), delete(pool); end
        pool = parpool(c, workers);
    end
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
function ProbeRun(cfg, workers)
%ProbeRun  Small batch under the real pool: measures per-job time and free RAM
%   so the ETA and the worker count are decided from measurements, not guesses.
%   The batch IS the first jobs of the real protocol (DTLZ1..DTLZ7 + WFG1..WFG5,
%   run 1) and is written to the real output folder, so nothing is wasted: the
%   main sweep will skip these files.
    addpath(genpath(cfg.platRoot));
    addpath(cfg.scriptDir);
    jobs = BuildJobs(cfg);

    fprintf('probe: %d real jobs, %d workers, output -> %s\n', numel(jobs), workers, cfg.outDir);
    t_pool = tic;
    pool = OpenPool(workers);
    fprintf('pool up in %.1f s, NumWorkers=%d\n', toc(t_pool), pool.NumWorkers);
    pctRunOnAll(['addpath(genpath(''' cfg.platRoot '''));' ...
                 'addpath(''' cfg.scriptDir ''');' ...
                 'maxNumCompThreads(1);']);
    ShowMem();

    rt  = nan(numel(jobs),1);
    st  = zeros(numel(jobs),1);
    t0  = tic;
    parfor k = 1:numel(jobs)
        [st(k),rt(k),~] = RunOneJob(cfg, jobs(k));
    end
    el = toc(t0);

    ShowMem();
    fprintf('probe done: ok=%d skipped=%d fail=%d, wall %.1f s\n', ...
        sum(st==1), sum(st==2), sum(st==-1), el);
    fprintf('per-job (s): %s\n', mat2str(round(rt(st==1))'));
    fprintf('mean %.1f s/job ; effective throughput %.2f job/h\n', ...
        mean(rt(st==1)), 3600*sum(st==1)/el);
end

% ------------------------------------------------------------------------
function ShowMem()
    try
        [~,s] = system('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"');
        freeGB = str2double(strtrim(s))/1048576;
        fprintf('free RAM after pool: %.1f GB\n', freeGB);
    catch
        fprintf('free RAM: (probe failed)\n');
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
