function MergeIGDpForDir(alg, M, workers, dtlz7FinalOnly, runsOverride)
%MergeIGDpForDir  Compute IGD+ for every run of one algorithm folder and merge
%   the trace into the raw .mat file's 'metric' struct.
%
%   MergeIGDpForDir(ALG,M,WORKERS)                      full 30-snapshot trace
%   MergeIGDpForDir(ALG,M,WORKERS,DTLZ7FINALONLY)       DTLZ7 at M=20: last snapshot only
%
%   The folder layout follows the rest of the dataset:
%     M == 10  ->  <TESTROOT>\10目标\n30\<ALG>
%     otherwise->  <TESTROOT>\<M>目标\<ALG>
%
%   Every run file is loaded, the IGD+ trace of all saved snapshots is computed
%   with IGDpFast (block-wise, numerically identical to the stock IGDp.m), the
%   field is merged with save(...,'metric','-append') and the written value is
%   re-read and compared.  A file that already carries a trace of the right
%   length is reused, so the pass is resume-safe.
%
%   DTLZ7 at M=20 is forced serial: its reference set holds 524288 points and
%   running that inside a pool has crashed MATLAB six times on this machine.
%   That problem is also ~180 s per run (the stored archive yields several
%   hundred non-dominated points, so the arithmetic triples).  Pass
%   DTLZ7FINALONLY = true to compute only the last snapshot of those files -
%   the ablation tables read metric.IGDp(end), and a later full-trace pass
%   overwrites the short one, so nothing is lost.

    if nargin < 1 || isempty(alg),     alg     = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'; end
    if nargin < 2 || isempty(M),       M       = 20; end
    if nargin < 3 || isempty(workers), workers = 1; end
    if nargin < 4 || isempty(dtlz7FinalOnly), dtlz7FinalOnly = false; end
    if nargin < 5 || isempty(runsOverride),   runsOverride   = [];    end

    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    logDir   = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    if M == 10
        rawDir = fullfile(testRoot,'10目标','n30',alg);
    else
        rawDir = fullfile(testRoot,sprintf('%d目标',M),alg);
    end
    assert(isfolder(rawDir),'Missing folder: %s',rawDir);
    if ~isfolder(logDir), mkdir(logDir); end

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    if isempty(runsOverride), runs = 1:20; else, runs = runsOverride; end

    addpath(genpath(platform));
    addpath('D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts');

    logFile = fullfile(logDir,sprintf('mergeIGDp_%s_M%d.log',alg,M));
    fid = fopen(logFile,'a');
    fprintf(fid,'# MergeIGDpForDir %s M=%d workers=%d dtlz7FinalOnly=%d start %s\n', ...
        alg,M,workers,dtlz7FinalOnly,char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

    if workers > 1
        pool = gcp('nocreate');
        if isempty(pool), pool = parpool('Processes',workers); end
        pctRunOnAll(['addpath(genpath(''' platform '''));' ...
                     'addpath(''D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts'');' ...
                     'maxNumCompThreads(1);']);
    end

    tAll = tic; nW = 0; nS = 0;
    for p = 1:numel(problems)
        prob = problems{p};
        files = cell(0,1); D = 0;
        for r = runs
            d = dir(fullfile(rawDir,sprintf('%s_%s_M%d_D*_%d.mat',alg,prob,M,r)));
            if numel(d) ~= 1
                fprintf(fid,'[%2d] %-6s run %d : %d matching files, skipped\n',p,prob,r,numel(d));
                continue;
            end
            files{end+1,1} = fullfile(rawDir,d(1).name);                    %#ok<AGROW>
            tok = regexp(d(1).name,sprintf('_M%d_D(\\d+)_%d\\.mat$',M,r),'tokens','once');
            D = str2double(tok{1});
        end
        if isempty(files)
            fprintf(fid,'[%2d] %-6s no file\n',p,prob); continue;
        end
        n = numel(files);
        gp = cell(n,1);
        % DTLZ7 keeps its 524288-point reference set off the workers whatever
        % the objective count is: it is the one problem that has crashed the
        % pool on this machine.
        isD7   = strcmp(prob,'DTLZ7');
        usePool = workers > 1 && ~isD7;
        if usePool
            parfor i = 1:n
                gp{i} = TraceOne(files{i},prob,M,D,dtlz7FinalOnly);
            end
        else
            for i = 1:n
                gp{i} = TraceOne(files{i},prob,M,D,dtlz7FinalOnly);
            end
        end
        for i = 1:n
            Sm = load(files{i},'metric');
            want = gp{i}(:);
            if isfield(Sm.metric,'IGDp') && isequal(Sm.metric.IGDp(:),want)
                nS = nS + 1; continue;
            end
            metric = Sm.metric; %#ok<NASGU>
            metric.IGDp = want;
            save(files{i},'metric','-append');
            V = load(files{i},'metric');
            assert(isequal(V.metric.IGDp(:),want),'IGDp mismatch after write: %s',files{i});
            nW = nW + 1;
        end
        fprintf(fid,'[%2d] %-6s D=%d runs=%d written=%d\n',p,prob,D,n,nW);
    end
    fprintf(fid,'# done : written %d, reused %d, %.1f min\n', ...
        nW,nS,toc(tAll)/60);
    fclose(fid);
    fprintf('MergeIGDpForDir %s M=%d : written %d, reused %d, %.1f min\n', ...
        alg,M,nW,nS,toc(tAll)/60);
end

% ------------------------------------------------------------------------
function gp = TraceOne(file,prob,M,D,finalOnly)
%TraceOne  IGD+ trace of one run; the stored trace is reused when valid.
    S = load(file);
    r = S.result;
    n = size(r,1);
    isD7 = strcmp(prob,'DTLZ7');
    if isfield(S.metric,'IGDp')
        cur = S.metric.IGDp(:)';
        if numel(cur) == n || (finalOnly && isD7 && numel(cur) == 1)
            gp = cur;
            return;
        end
    end
    maxNumCompThreads(1);
    P = feval(prob,'M',M,'D',D,'N',100,'maxFE',300);
    opt = P.optimum;
    if finalOnly && isD7
        gp = IGDpFast(r{end,2},opt);
        gp = gp(:)';
        return;
    end
    gp = nan(1,n);
    for k = 1:n
        gp(k) = IGDpFast(r{k,2},opt);
    end
end
