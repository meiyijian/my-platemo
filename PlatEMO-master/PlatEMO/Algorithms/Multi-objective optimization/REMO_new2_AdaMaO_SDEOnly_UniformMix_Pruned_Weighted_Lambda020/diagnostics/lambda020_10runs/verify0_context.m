function verdict = verify0_context()
%verify0_context Isolate why the lambda0=0 run differs from the stored control.
%   The selector-level equivalence already passes, and the lambda0=0 run reports
%   the same FE grid and no batch movement, so the residual difference must come
%   from somewhere else. This script separates two hypotheses:
%     H1 the stored control is not reproducible in a fresh client session,
%     H2 the lambda0=0 path genuinely differs from the baseline.
%   Four runs share one seed, one problem and one harness and differ only in the
%   algorithm and in where they execute:
%     J1 baseline pruned, client session (serial)
%     J2 baseline pruned, process worker
%     J3 Lambda020 with lambda0=0, process worker
%     J4 baseline pruned, process worker, repeated for worker self-consistency
%   Everything is compared with the stored control IGD of DTLZ2 run 19.

    baseline = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted';
    variant = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020';
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    platform = fileparts(fileparts(fileparts(root)));
    addpath(genpath(platform));
    addpath(root);
    outDir = fullfile(root,'diagnostics','lambda020_10runs','verify0_context');
    if ~isfolder(outDir), mkdir(outDir); end
    logFile = fullfile(outDir,'verify0_context.log');
    fid = fopen(logFile,'w','n','UTF-8');
    cleanup = onCleanup(@()fclose(fid));

    problem = 'DTLZ2'; M = 10; D = 30; N = 100; maxFE = 300;
    seed = 20260912 + M*100000 + 2*1000 + 19;
    controlFile = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30/' ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'],sprintf( ...
        '%s_%s_M%d_D%d_%d.mat',baseline,problem,M,D,19));
    control = load(controlFile,'metric');
    controlIGD = control.metric.IGD(end);
    fprintf(fid,'Control IGD (stored baseline, DTLZ2 run 19): %.12g\n',controlIGD);
    fprintf(fid,'Seed: %d; client threads: %d\n\n',seed,maxNumCompThreads);

    jobs = struct([]);
    baseFolder = fullfile(platform,'Algorithms','Multi-objective optimization',baseline);
    specs = {baseline,baseFolder,{3000,0.50,0.25,0.70,6},'J1_baseline_client'; ...
        baseline,baseFolder,{3000,0.50,0.25,0.70,6},'J2_baseline_worker'; ...
        variant,root,{3000,0.50,0.25,0.70,6,0},'J3_lambda0_worker'; ...
        baseline,baseFolder,{3000,0.50,0.25,0.70,6},'J4_baseline_worker_repeat'};
    for i = 1:size(specs,1)
        job = struct('algorithm',specs{i,1},'algFolder',specs{i,2}, ...
            'parameters',{specs{i,3}}, ...
            'label',specs{i,4},'problem',problem,'M',M,'D',D,'N',N, ...
            'maxFE',maxFE,'seed',seed,'root',root,'platform',platform, ...
            'file',fullfile(outDir,[specs{i,4},'.mat']));
        if isempty(jobs), jobs = job; else, jobs(end+1) = job; end %#ok<AGROW>
    end

    % J1 runs in this client session, before any pool is created.
    fprintf(fid,'--- J1 baseline, client session (serial) ---\n');
    results = struct([]);
    s = runOne(jobs(1));
    results = record(results,s,controlIGD,fid);

    fprintf(fid,'--- J2..J4 on process workers ---\n');
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes',3); end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
    workers = struct([]);
    for i = 2:numel(jobs)
        w = parfeval(pool,@runOne,1,jobs(i)); %#ok<AGROW>
        if isempty(workers), workers = w; else, workers(end+1) = w; end %#ok<AGROW>
    end
    for i = 1:numel(workers)
        [~,s] = fetchNext(workers);
        results = record(results,s,controlIGD,fid);
    end

    fprintf(fid,'\n--- summary ---\n');
    fprintf(fid,'%-26s %-22s %-18s %-12s %s\n','label','context','IGD','delta','matches control');
    for i = 1:numel(results)
        fprintf(fid,'%-26s %-22s %-18.12g %+-12.4g %d\n',results(i).label, ...
            results(i).context,results(i).IGD,results(i).IGD-controlIGD, ...
            results(i).IGD == controlIGD);
    end
    workerBase = results(strcmp({results.label},'J2_baseline_worker'));
    workerZero = results(strcmp({results.label},'J3_lambda0_worker'));
    clientBase = results(strcmp({results.label},'J1_baseline_client'));
    verdict = struct();
    verdict.controlIGD = controlIGD;
    verdict.results = rmfield(results,{'population','files'});
    verdict.baselineReproducesControlInClient = ...
        clientBase(1).IGD == controlIGD;
    verdict.baselineReproducesControlInWorker = ...
        workerBase(1).IGD == controlIGD;
    verdict.workersSelfConsistent = ...
        results(strcmp({results.label},'J2_baseline_worker')).IGD == ...
        results(strcmp({results.label},'J4_baseline_worker_repeat')).IGD;
    verdict.lambda0EqualsBaselineInWorker = ...
        workerZero(1).IGD == workerBase(1).IGD;
    fprintf(fid,'\nbaseline reproduces stored control, client : %d\n', ...
        verdict.baselineReproducesControlInClient);
    fprintf(fid,'baseline reproduces stored control, worker : %d\n', ...
        verdict.baselineReproducesControlInWorker);
    fprintf(fid,'worker runs self-consistent                : %d\n', ...
        verdict.workersSelfConsistent);
    fprintf(fid,'lambda0=0 equals baseline in the worker    : %d\n', ...
        verdict.lambda0EqualsBaselineInWorker);
    if verdict.lambda0EqualsBaselineInWorker
        verdict.verdict = 'PASS';
    else
        verdict.verdict = 'FAIL';
    end
    fprintf(fid,'VERDICT: %s\n',verdict.verdict);
    fid2 = fopen(fullfile(outDir,'verify0_context.json'),'w','n','UTF-8');
    fwrite(fid2,jsonencode(verdict,'PrettyPrint',true));
    fclose(fid2);
    fprintf('Log written: %s\n',logFile);
end

function results = record(results,s,controlIGD,fid)
%record Append one finished run to the result list and echo it to the log.
    s.controlIGD = controlIGD;
    fprintf(fid,'%-26s context=%-16s IGD=%.12g delta=%+.4g ok=%d\n', ...
        s.label,s.context,s.IGD,s.IGD-controlIGD,s.ok);
    if ~s.ok
        fprintf(fid,'   ERROR: %s\n',s.message);
    end
    if isempty(results), results = s; else, results(end+1) = s; end
end

function status = runOne(job)
%runOne One isolated run: identical harness in every context.
    status = struct('label',job.label,'algorithm',job.algorithm, ...
        'context','client','ok',false,'IGD',NaN,'message','', ...
        'threads',maxNumCompThreads,'file',job.file,'population',[], ...
        'files',{{}});
    try
        if ~isempty(job.platform), addpath(genpath(job.platform)); end
        addpath(job.algFolder);
        if numel(getCurrentTask()) > 0
            status.context = 'worker';
        end
        assert(strcmpi(fileparts(which(job.algorithm)),job.algFolder), ...
            'Unexpected algorithm resolution for %s.',job.algorithm);
        assert(~isfile(job.file),'Refusing to overwrite %s.',job.file);
        pro = feval(job.problem,'N',job.N,'M',job.M,'D',job.D,'maxFE',job.maxFE);
        alg = feval(job.algorithm,'parameter',job.parameters,'save',30, ...
            'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        metadata = struct('algorithm',job.algorithm,'problem',job.problem, ...
            'seed',job.seed,'parameters',{job.parameters},'label',job.label, ...
            'context',status.context,'threads',status.threads, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        alg.Solve(pro);
        result = alg.result; metric = alg.metric;
        save(job.file,'result','metric','metadata','-v7');
        alg.CalMetric('IGD');
        metric = alg.metric;
        save(job.file,'metric','-append');
        status.IGD = metric.IGD(end);
        status.population = result{end,2};
        status.files = {job.file};
        status.ok = true;
    catch err
        status.message = err.message;
    end
end
