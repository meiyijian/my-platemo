function SmokeTestRMEOkCdis()
%SmokeTestRMEOkCdis End-to-end smoke test for RMEO_k_CDIS.
%   Checks (1) that the entry point and every private helper resolve to files
%   inside RMEO_k_CDIS, and (2) that the algorithm completes a small budget
%   with the evaluation budget exactly met. Nothing is written to any data
%   folder.

    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    folder = fullfile(platform,'Algorithms','Multi-objective optimization', ...
        'RMEO_k_CDIS');
    addpath(genpath(platform));
    addpath(folder);

    fprintf('entry resolved    : %s\n',which('RMEO_k_CDIS'));
    probe = ProbeCdisResolution();
    names = fieldnames(probe);
    ok = true;
    for i = 1:numel(names)
        fprintf('  %-32s -> %s\n',names{i},probe.(names{i}));
        if isempty(strfind(probe.(names{i}),'RMEO_k_CDIS')) %#ok<STREMP>
            ok = false;
        end
    end
    assert(ok,'At least one private helper did not resolve inside RMEO_k_CDIS.');

    cases = { 'DTLZ2',10,30,130,1
              'DTLZ7',10,30,130,2
              'DTLZ2',20,30,140,3 };
    for c = 1:size(cases,1)
        name = cases{c,1};
        M = cases{c,2};
        D = cases{c,3};
        maxFE = cases{c,4};
        runId = cases{c,5};
        pro = feval(name,'N',100,'M',M,'D',D,'maxFE',maxFE);
        kExpected = min(pro.N,max(6,ceil(1.5*pro.M)));
        alg = feval('RMEO_k_CDIS','parameter',{3000,0.50,0.70,6}, ...
            'save',30,'run',runId,'outputFcn',@(~,~)[]);
        rng(20260912 + M*100000 + 1*1000 + runId,'twister');
        t = tic;
        alg.Solve(pro);
        elapsed = toc(t);
        assert(pro.FE == maxFE,'Budget not exactly met: FE=%g',pro.FE);
        assert(alg.result{end,1} == maxFE,'Last snapshot FE mismatch.');
        alg.CalMetric('IGD');
        igd = alg.metric.IGD;
        assert(all(isfinite(igd)),'Non-finite IGD.');
        fprintf(['[%s M=%d D=%d maxFE=%d run=%d] k=%d FE=%d IGD=%.6g ' ...
            'time=%.1f s\n'],name,M,D,maxFE,runId,kExpected,pro.FE, ...
            igd(end),elapsed);
    end
    fprintf('SMOKE PASSED.\n');
end
