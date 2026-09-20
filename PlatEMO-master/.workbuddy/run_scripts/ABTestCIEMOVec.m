function ABTestCIEMOVec()
%ABTestCIEMOVec  Numerical-equivalence check for the vectorised CI-EMO copy.
%   Runs CIEMO (original) and CIEMOV (vectorised private\GP_estimate.m) on the
%   same problem with the SAME seed and a shortened budget, then compares the
%   FE grid and the IGD trace element by element.  Also reports the speed-up.
%
%   Shortened budget on purpose: the point is to exercise the prediction code
%   path many times (each main iteration runs 20 NSGA-III generations), not to
%   finish a whole run.  40 initial + 70 infills = 70 main iterations.

    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    addpath(genpath(platform));
    maxNumCompThreads(1);
    warning('off','all');

    M = 20; D = 30; maxFE = 111; N = 100;
    seed = 22260912 + 1000*2 + 1;          % DTLZ2, run 1 - identical for both
    res  = cell(1,2);
    for k = 1:2
        if k == 1, cls = 'CIEMO'; else, cls = 'CIEMOV'; end
        rng(seed,'twister');
        P   = feval('DTLZ2','M',M,'D',D,'maxFE',maxFE,'N',N);
        Alg = feval(cls,'save',30,'run',1);
        t0  = tic; Alg.Solve(P); el = toc(t0);
        Alg.CalMetric('IGD');
        fe  = cellfun(@(x)x,Alg.result(:,1))';
        fprintf('%-8s  %7.1f s  FE %s\n', cls, el, mat2str(fe));
        fprintf('         IGD %s\n', mat2str(Alg.metric.IGD,10));
        res{k} = struct('cls',cls,'el',el,'fe',fe,'igd',Alg.metric.IGD(:)');
    end
    a = res{1}; b = res{2};
    fprintf('\nspeed-up = %.2fx   (%.1f s -> %.1f s)\n', a.el./b.el, a.el, b.el);
    if isequal(a.fe,b.fe)
        fprintf('FE grids identical (%d snapshots)\n', numel(a.fe));
        d   = abs(a.igd - b.igd);
        rel = d ./ max(abs(a.igd),eps);
        fprintf('maxAbsDiff = %.3e   maxRelDiff = %.3e\n', max(d), max(rel));
        fprintf('all |relDiff| < 1e-12 : %d\n', all(rel < 1e-12));
        fprintf('all |relDiff| < 1e-9  : %d\n', all(rel < 1e-9));
        if any(rel >= 1e-12)
            idx = find(rel >= 1e-12);
            fprintf('first divergence at snapshot %d (FE %d): rel %.3e\n', ...
                idx(1), a.fe(idx(1)), rel(idx(1)));
        end
    else
        fprintf('!! FE grids differ\n  orig %s\n  vec  %s\n', ...
            mat2str(a.fe), mat2str(b.fe));
    end
    fprintf('AB DONE\n');
end
