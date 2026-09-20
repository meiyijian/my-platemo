function ScanSSDESeed()
%ScanSSDESeed  Find the seed formula of the archived July-2026 SSDE M=20 batch.
%
%   The first stored snapshot of SSDE_DTLZ1_M20_D30_1.mat is at FE=100, i.e.
%   exactly the initial Latin-hypercube population, which is a pure function of
%   the RNG state.  So the IGD of the initial population identifies the seed
%   (and is ~50x cheaper to evaluate than a full run).
%
%   Phase 1 checks an explicit table of plausible formulas built from the file
%   timestamps (2026-07-12) and the project conventions.
%   Phase 2 (only if phase 1 fails) scans a bounded seed range.

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    maxNumCompThreads(1);
    warning('off','all');

    target = 203.6928774989165;        % stored SSDE_DTLZ1_M20_D30_1.mat snapshot 1 (FE=100)
    M = 20; D = 30; idx = 1; run = 1;

    % ---- self-check: does the cheap path reproduce the full run's IGD(1)? ---
    rng(20261913,'twister');
    P = feval('DTLZ1','M',M,'D',D,'maxFE',300,'N',100);
    Pop = P.Initialization();
    igdFast = MetricIGD(Pop.objs,P);
    fprintf('self-check  cheap-path IGD1 = %.10f\n', igdFast);
    rng(20261913,'twister');
    P2  = feval('DTLZ1','M',M,'D',D,'maxFE',300,'N',100);
    Alg = feval('SSDE','save',30,'run',1); Alg.Solve(P2); Alg.CalMetric('IGD');
    fprintf('self-check  full-run IGD1  = %.10f   match=%d\n\n', Alg.metric.IGD(1), ...
        abs(Alg.metric.IGD(1)-igdFast) < 1e-12);

    % ---- phase 1: explicit formula table ------------------------------------
    bases = [20260712, 20260711, 20260710, 20260912, 20260701, 20260101, 0];
    names = {'b+1000i+r','b+M1e5+1000i+r','b+M1e3+1000i+r','b+1000i+10r','b+100i+r','b+1e4i+r','b+r','1e4i+r','1000i+r'};
    seeds = zeros(0,3);   % [seed, baseIdx, formIdx]
    for bi = 1:numel(bases)
        b = bases(bi);
        cand = [ b + 1000*idx + run, ...
                 b + M*1e5 + 1000*idx + run, ...
                 b + M*1e3 + 1000*idx + run, ...
                 b + 1000*idx + 10*run, ...
                 b + 100*idx + run, ...
                 b + 1e4*idx + run, ...
                 b + run, ...
                 1e4*idx + run, ...
                 1000*idx + run ];
        for fi = 1:numel(cand)
            seeds(end+1,:) = [cand(fi), bi, fi];                        %#ok<AGROW>
        end
    end
    seeds = unique(seeds,'rows','stable');

    t0 = tic;
    hit = [];
    for k = 1:size(seeds,1)
        s = seeds(k,1);
        rng(s,'twister');
        Pc = feval('DTLZ1','M',M,'D',D,'maxFE',300,'N',100);
        v  = MetricIGD(Pc.Initialization().objs,Pc);
        if abs(v-target) < 1e-9
            hit = [hit; s, k];                                          %#ok<AGROW>
            fprintf('*** MATCH seed=%d  (base %s, form %s)  IGD1=%.10f\n', ...
                s, mat2str(bases(seeds(k,2))), names{seeds(k,3)}, v);
        end
    end
    el = toc(t0);
    fprintf('phase 1: %d candidates in %.1f s (%.3f s each)\n', size(seeds,1), el, el/size(seeds,1));
    if isempty(hit)
        fprintf('phase 1: NO match\n');
    end
    fprintf('SCAN DONE\n');
end

function v = MetricIGD(PopObj,Problem)
%MetricIGD  Same quantity PlatEMO's IGD metric reports for one population.
    Distance = min(pdist2(Problem.optimum,PopObj),[],2);
    v        = mean(Distance);
end
