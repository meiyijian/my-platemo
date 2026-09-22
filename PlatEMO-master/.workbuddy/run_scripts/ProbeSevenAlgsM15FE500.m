function ProbeSevenAlgsM15FE500(workers)
%ProbeSevenAlgsM15FE500 One run of each target algorithm at M=15, D=30, maxFE=500.
%   Reports the first-snapshot FE (the cost of the initial design), the final
%   FE, the number of snapshots and the wall time, so the batch can be sized
%   and any algorithm whose initial design already exceeds the budget shows up
%   before the full run is started.
    if nargin < 1 || isempty(workers), workers = 5; end
    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    algRoot  = fullfile(platform,'Algorithms','Multi-objective optimization');
    algs = {'REMO','PCSAEA','CSEA','HES_EA','SSDE','SAMOEATL2M', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'};

    addpath(genpath(platform));
    pro0 = DTLZ2('N',100,'M',15,'D',30,'maxFE',500);
    fprintf('problem DTLZ2 : N=%d M=%d D=%d maxFE=%d\n',pro0.N,pro0.M,pro0.D,pro0.maxFE);
    for i = 1:numel(algs)
        f = which(algs{i});
        if isempty(f)
            fprintf('  %-52s NOT FOUND ON PATH\n',algs{i});
        else
            fprintf('  %-52s %s\n',algs{i},f);
        end
    end
    fprintf('\n');

    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes',workers); end
    fut = parallel.FevalFuture.empty;
    for i = 1:numel(algs)
        fut(i) = parfeval(pool,@runOne,1,algs{i},algRoot,platform); %#ok<AGROW>
    end
    t0 = tic;
    for i = 1:numel(algs)
        [~,s] = fetchNext(fut);
        if isempty(s.msg)
            fprintf('[%d/%d] %-52s initFE=%4d finalFE=%4d rows=%2d wall=%8.1f s\n', ...
                i,numel(algs),s.alg,s.initialFE,s.finalFE,s.rows,s.wall);
        else
            fprintf('[%d/%d] %-52s FAILED: %s\n',i,numel(algs),s.alg,s.msg);
        end
    end
    fprintf('\nprobe finished in %.1f min\n',toc(t0)/60);
end

function s = runOne(alg,algRoot,platform)
%runOne One DTLZ2 run of one algorithm, with its own folder raised to the top.
    s = struct('alg',alg,'initialFE',-1,'finalFE',-1,'rows',-1,'wall',NaN,'msg','');
    try
        addpath(genpath(platform));
        d = fileparts(which(alg));
        assert(~isempty(d) && strncmpi(d,algRoot,numel(algRoot)), ...
            'algorithm does not resolve under the platform: %s',alg);
        addpath(d,'-begin');
        pro = DTLZ2('N',100,'M',15,'D',30,'maxFE',500);
        a = feval(alg,'save',30,'run',1,'outputFcn',@(~,~)[]);
        rng(21260912,'twister');
        t0 = tic;
        a.Solve(pro);
        s.wall = toc(t0);
        s.finalFE = pro.FE;
        s.rows = size(a.result,1);
        if ~isempty(a.result), s.initialFE = a.result{1,1}; end
    catch err
        s.msg = err.message;
    end
end
