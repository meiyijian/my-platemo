function verify_context2()
%verify_context2 Reproduce the stored DTLZ2 control inside a two-worker pool.
%   The stored baseline result of DTLZ2 run 19 was written on 2026-09-13 00:14
%   by a session whose pool had two workers. The same seed, same source and same
%   problem now give a different IGD on a client session and on a three-worker
%   pool. This script re-runs that exact case on a two-worker pool to test
%   whether the original context can be reproduced at all, and how consistent a
%   pool of that size is with itself.

    baseline = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted';
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    platform = fileparts(fileparts(fileparts(root)));
    addpath(genpath(platform));
    baselineFolder = fullfile(platform,'Algorithms','Multi-objective optimization',baseline);
    addpath(baselineFolder);
    outDir = fullfile(root,'diagnostics','lambda020_10runs','verify_context2');
    if ~isfolder(outDir), mkdir(outDir); end
    logFile = fullfile(outDir,'verify_context2.log');
    fid = fopen(logFile,'w','n','UTF-8');
    cleanup = onCleanup(@()fclose(fid));

    problem = 'DTLZ2'; M = 10; D = 30; N = 100; maxFE = 300;
    seed = 20260912 + M*100000 + 2*1000 + 19;
    controlFile = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30/' ...
        baseline],sprintf('%s_%s_M%d_D%d_%d.mat',baseline,problem,M,D,19));
    control = load(controlFile,'metric');
    controlIGD = control.metric.IGD(end);
    fprintf(fid,'Stored control IGD : %.12g\n',controlIGD);
    fprintf(fid,'Reference results  : client 1.0823481784157407 (6 threads)\n');
    fprintf(fid,'                     3-worker pool 1.123668809672717 (1 thread)\n');
    fprintf(fid,'Seed: %d\n\n',seed);

    pool = gcp('nocreate');
    if ~isempty(pool), delete(pool); end
    pool = parpool('Processes',2);
    fprintf(fid,'Pool workers: %d\n',pool.NumWorkers);
    jobs = struct([]);
    for i = 1:2
        job = struct('algorithm',baseline,'algFolder',baselineFolder, ...
            'parameters',{{3000,0.50,0.25,0.70,6}},'problem',problem, ...
            'M',M,'D',D,'N',N,'maxFE',maxFE,'seed',seed, ...
            'platform',platform,'label',sprintf('K%d_two_worker_pool',i), ...
            'file',fullfile(outDir,sprintf('K%d.mat',i)));
        if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
    end
    futures = parallel.FevalFuture.empty;
    for i = 1:numel(jobs)
        futures(i) = parfeval(pool,@runOne,1,jobs(i)); %#ok<AGROW>
    end
    results = struct([]);
    for i = 1:numel(jobs)
        [~,s] = fetchNext(futures);
        if isempty(results), results = s; else, results(end+1) = s; end %#ok<AGROW>
        fprintf(fid,'%-22s threads=%d IGD=%.12g deltaVsStored=%+.4g ok=%d\n', ...
            s.label,s.threads,s.IGD,s.IGD-controlIGD,s.ok);
        if ~s.ok, fprintf(fid,'   ERROR: %s\n',s.message); end
    end
    same = results(1).IGD == results(2).IGD;
    reproduces = results(1).IGD == controlIGD;
    fprintf(fid,'\ntwo-worker runs self-consistent     : %d\n',same);
    fprintf(fid,'two-worker pool reproduces stored   : %d\n',reproduces);
    if reproduces
        fprintf(fid,'VERDICT: the stored control is reproducible with the original pool size.\n');
    elseif same
        fprintf(fid,'VERDICT: a two-worker pool is self-consistent but does not reproduce\n');
        fprintf(fid,'the stored control, so pool size alone does not explain the difference.\n');
    else
        fprintf(fid,'VERDICT: two-worker runs disagree with each other; the pipeline is not\n');
        fprintf(fid,'deterministic even inside one pool configuration.\n');
    end
    verdict = struct('controlIGD',controlIGD,'results',rmfield(results,{'population'}), ...
        'selfConsistent',same,'reproducesStoredControl',reproduces, ...
        'poolWorkers',pool.NumWorkers);
    fid2 = fopen(fullfile(outDir,'verify_context2.json'),'w','n','UTF-8');
    fwrite(fid2,jsonencode(verdict,'PrettyPrint',true));
    fclose(fid2);
    fprintf('Log written: %s\n',logFile);
end

function status = runOne(job)
%runOne One isolated run inside the two-worker pool.
    status = struct('label',job.label,'algorithm',job.algorithm,'context','worker', ...
        'ok',false,'IGD',NaN,'message','','threads',maxNumCompThreads, ...
        'file',job.file,'population',[]);
    try
        addpath(genpath(job.platform));
        addpath(job.algFolder);
        assert(~isfile(job.file),'Refusing to overwrite %s.',job.file);
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        alg = feval(job.algorithm,'parameter',job.parameters,'save',30, ...
            'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        alg.Solve(pro);
        result = alg.result; metric = alg.metric;
        save(job.file,'result','metric','-v7');
        alg.CalMetric('IGD');
        metric = alg.metric;
        save(job.file,'metric','-append');
        status.IGD = metric.IGD(end);
        status.population = result{end,2};
        status.ok = true;
    catch err
        status.message = err.message;
    end
end
