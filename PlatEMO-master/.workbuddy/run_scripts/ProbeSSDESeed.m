function ProbeSSDESeed()
%ProbeSSDESeed  Which seed formula did the archived SSDE M=20 runs use?
%   The first snapshot of SSDE_DTLZ1_M20_D30_1.mat is at FE=100, i.e. the
%   initial Latin-hypercube population, which is a pure function of the RNG
%   state and therefore of the seed.  Running SSDE with a candidate seed and
%   comparing that first IGD against the stored value is decisive: it either
%   matches to the last bit or it does not.

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    maxNumCompThreads(1);
    warning('off','all');

    target = 203.6928774989165;      % stored SSDE_DTLZ1_M20_D30_1.mat, snapshot 1 (FE=100)
    targetLast = 103.91018934757105; % same file, last snapshot (FE=307)

    cands = { ...
        'old18   ', 20260912 + 1000*1 + 1; ...   % 20260912 + probIdx*1000 + run
        'newM20  ', 22260912 + 1000*1 + 1; ...   % 20260912 + M*1e5 + probIdx*1000 + run
        'M10base ', 21260912 + 1000*1 + 1; ...
        'noProb  ', 20260912 + 1; ...
        'plainRun', 1; ...
        'baseOnly', 20260912; ...
        'old18r0 ', 20260912 + 1000*1 + 0};

    fprintf('target first-snapshot IGD = %.10f\n', target);
    fprintf('target last-snapshot  IGD = %.10f\n\n', targetLast);
    for k = 1:size(cands,1)
        name = cands{k,1}; seed = cands{k,2};
        rng(seed,'twister');
        P   = feval('DTLZ1','M',20,'D',30,'maxFE',300,'N',100);
        Alg = feval('SSDE','save',30,'run',1);
        Alg.Solve(P);
        Alg.CalMetric('IGD');
        igd = Alg.metric.IGD(:)';
        fe  = cellfun(@(x)x, Alg.result(:,1))';
        fprintf('%-9s seed=%-10d snaps=%2d FE1=%-4d IGD1=%.10f  d1=%+.3e   IGDlast=%.10f  %s\n', ...
            name, seed, numel(fe), fe(1), igd(1), igd(1)-target, igd(end), ...
            merge(abs(igd(1)-target) < 1e-9, '  <<< MATCH', ''));
    end
    fprintf('PROBE DONE\n');
end

function out = merge(cond,a,b)
    if cond, out = a; else, out = b; end
end
