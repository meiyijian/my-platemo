function ProbeSeedOrder()
%ProbeSeedOrder  Which random-number wiring reproduces the stored NoBatchDist run?
%
%   Reference: 10目标\n30\..._NoBatchDist\..._WFG9_M10_D30_1.mat
%   IGD of the FIRST snapshot (FE = 100, i.e. the initial Latin design).
%   Each hypothesis runs maxFE = 106 only, so one attempt costs ~15 s; the
%   FE=100 snapshot is always stored at index 1 whatever the budget.

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    ALG   = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    PAR   = {3000,0.50,0.25,0.70,6};
    PROB  = 'WFG9';
    M     = 10; D = 30; N = 100;
    pIdx  = 16;
    runId = 1;
    base  = 21260912;
    target = 8.98422929;                       % stored IGD of snapshot 1

    cands = { ...
        'A rng(base+1000p+run) before construct', base + 1000*pIdx     + runId; ...
        'B rng after construct',                  base + 1000*pIdx     + runId; ...
        'C rng before and after construct',       base + 1000*pIdx     + runId; ...
        'D zero-based problem index',             base + 1000*(pIdx-1) + runId; ...
        'E base + run only',                      base + runId; ...
        'F base + 1000*pIdx + 10*run',            base + 1000*pIdx     + 10*runId};

    fprintf('target IGD(snapshot 1) = %.8f\n', target);
    for k = 1:size(cands,1)
        seed = cands{k,2};
        switch cands{k,1}(1)
            case 'A'
                rng(seed,'twister');
                P = feval(PROB,'M',M,'D',D,'maxFE',106,'N',N);
            case 'B'
                P = feval(PROB,'M',M,'D',D,'maxFE',106,'N',N);
                rng(seed,'twister');
            case 'C'
                rng(seed,'twister');
                P = feval(PROB,'M',M,'D',D,'maxFE',106,'N',N);
                rng(seed,'twister');
            otherwise
                rng(seed,'twister');
                P = feval(PROB,'M',M,'D',D,'maxFE',106,'N',N);
        end
        A = feval(ALG,'parameter',PAR,'save',30,'run',runId);
        A.Solve(P);
        igd = A.CalMetric('IGD');
        fprintf('%-42s seed=%d  IGD1=%.8f  diff=%+.3e\n', ...
            cands{k,1}, seed, igd(1), igd(1)-target);
    end
    fprintf('PROBE SEED DONE\n');
end
