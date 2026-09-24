function RunNBGGPParallel(workers, seg)
%RunNBGGPParallel Drive the shipped NBGGP formal protocol from a process pool.
%   The shipped runner (run_NoBatchDistGoodGroupPrecision) walks its 160 jobs
%   serially in one MATLAB session, which needs about 9.4 h at the measured
%   212-223 s per run. This wrapper leaves that runner completely untouched and
%   simply calls it once per (problem, M, run-block) subset from a pool, so the
%   wall time drops to roughly the longest subset.
%
%   Safety: every job file is written through a temporary file and committed
%   with movefile, and each call writes its own manifest, so subsets cannot
%   corrupt each other. Jobs that already exist are validated and skipped.
%
%   RunNBGGPParallel(WORKERS)       WORKERS pool workers (default 12)
%   RunNBGGPParallel(WORKERS, SEG)  SEG = runs per subset (default 10)
%
%   The equivalence gate must already be PASS (run verify_NBGGP first).

    if nargin < 1 || isempty(workers), workers = 12; end
    if nargin < 2 || isempty(seg), seg = 10; end

    expDir = ['D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\' ...
        'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_GoodGroupPrecision'];
    addpath(expDir);
    assert(isfile(fullfile(expDir,'equivalence_passed.txt')), ...
        'Run verify_NBGGP first: %s',expDir);

    runs = 1:20;
    blocks = {};
    for b = 1:seg:numel(runs)
        blocks{end+1} = runs(b:min(b+seg-1,numel(runs))); %#ok<AGROW>
    end
    problems = {'DTLZ2','DTLZ4','DTLZ7','DTLZ5'};
    objectiveCounts = [10 20];

    subsets = {};
    for p = 1:numel(problems)
        for m = objectiveCounts
            for b = 1:numel(blocks)
                subsets{end+1} = struct('Problems',problems{p}, ...
                    'M',m,'Runs',blocks{b}); %#ok<AGROW>
            end
        end
    end
    fprintf('NBGGP parallel: %d subsets, %d runs per subset, %d workers\n', ...
        numel(subsets),seg,workers);

    c = parcluster('Processes');
    if workers > c.NumWorkers
        fprintf('Raising the pool cap from %d to %d (profile untouched).\n', ...
            c.NumWorkers,workers);
        c.NumWorkers = workers;
    end
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool(c,workers); end
    fprintf('pool ready: %d workers\n',pool.NumWorkers);

    fut = parallel.FevalFuture.empty;
    for i = 1:numel(subsets)
        s = subsets{i};
        fut(i) = parfeval(pool,@run_NoBatchDistGoodGroupPrecision,1, ... %#ok<AGROW>
            'formal','Problems',s.Problems,'Ms',s.M,'Runs',s.Runs);
    end

    started = tic;
    for i = 1:numel(subsets)
        idx = fetchNext(fut);
        s = subsets{idx};
        fprintf('[%2d/%2d] %-6s M%02d runs %-12s done | %.1f min elapsed\n', ...
            i,numel(subsets),s.Problems,s.M,mat2str(s.Runs),toc(started)/60);
    end
    fprintf('ALL SUBSETS DONE in %.1f min\n',toc(started)/60);
end
