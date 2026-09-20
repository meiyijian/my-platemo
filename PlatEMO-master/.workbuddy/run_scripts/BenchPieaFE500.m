function BenchPieaFE500(workers)
%BenchPieaFE500 Parallel throughput check: 16 problems x 1 run on a process
%   pool, results written to a scratch folder (the dataset stays untouched).

    if nargin < 1, workers = 5; end

    platRoot = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    pieaDir  = fullfile(platRoot,'Algorithms','Multi-objective optimization','PIEA');
    scriptDir = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts';
    outDir   = fullfile(tempdir,'bench_piea_fe500');
    if ~isfolder(outDir), mkdir(outDir); end

    addpath(genpath(platRoot));
    addpath(pieaDir,'-begin');
    addpath(pieaDir);
    addpath(scriptDir);

    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    Dreq  = [14 19 19 19 19 19 19, 14 19 19 19 19 19 19 19 19];

    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('Processes',workers);
    end
    fprintf('Pool workers: %d\n',pool.NumWorkers);

    tAll = tic;
    futures = parallel.FevalFuture.empty;
    for p = 1:numel(probs)
        futures(p) = parfeval(pool,@OneJob,3,probs{p},Dreq(p), ...
            20260912+10*100000+p*1000+1,outDir,platRoot,pieaDir); %#ok<AGROW>
    end
    rt = nan(numel(probs),1); okFlag = false(numel(probs),1);
    for k = 1:numel(probs)
        [idx,okv,rtv,msg] = fetchNext(futures);
        okFlag(idx) = okv; rt(idx) = rtv;
        fprintf('  [%2d/%2d] %-6s D=%2d ok=%d %.1f s %s\n', ...
            k,numel(probs),probs{idx},Dreq(idx),okv,rtv,msg);
    end
    wall = toc(tAll);
    fprintf('\nWall for 16 jobs on %d workers : %.1f s (%.1f min)\n', ...
        pool.NumWorkers,wall,wall/60);
    fprintf('Sum of job runtimes          : %.1f s\n',nansum(rt));
    fprintf('Mean / min / max single run  : %.1f / %.1f / %.1f s\n', ...
        mean(rt),min(rt),max(rt));
    fprintf('Extrapolated 320 jobs        : %.1f min (waves %.1f)\n', ...
        wall/60*(ceil(320/pool.NumWorkers)/ceil(16/pool.NumWorkers)), ...
        ceil(320/pool.NumWorkers));
    fprintf('ok=%d fail=%d\n',sum(okFlag),sum(~okFlag));
end

function [ok,rt,msg] = OneJob(prob,Dreq,seed,outDir,platRoot,pieaDir)
    ok = false; rt = 0; msg = '';
    try
        addpath(genpath(platRoot));
        addpath(pieaDir,'-begin'); addpath(pieaDir);
        maxNumCompThreads(1);
        rng(seed,'twister');
        P = feval(prob,'N',100,'M',10,'D',Dreq,'maxFE',500);
        outFile = fullfile(outDir,sprintf('BENCH_%s_M10_D%d.mat',prob,P.D));
        Alg = feval('PIEA','save',30,'run',1,'outputFcn',@(~,~)[]);
        t = tic; Alg.Solve(P); rt = toc(t);
        Alg.CalMetric('IGD');
        result = Alg.result; metric = Alg.metric; %#ok<NASGU>
        save(outFile,'result','metric');
        ok = true;
    catch err
        msg = err.message;
        if strlength(string(msg)) > 120, msg = char(extractBefore(string(msg),120)); end
    end
end
