function TestIGDpPIEA()
%TestIGDpPIEA Cost of CalMetric('IGDp') on top of CalMetric('IGD') for one
%   run per representative problem in the FE500 setting.

    platRoot = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    pieaDir  = fullfile(platRoot,'Algorithms','Multi-objective optimization','PIEA');
    addpath(genpath(platRoot));
    addpath(pieaDir,'-begin');
    addpath(pieaDir);

    cases = {'DTLZ1',14; 'DTLZ7',19; 'WFG1',14; 'WFG9',19};
    for i = 1:size(cases,1)
        p  = cases{i,1};
        Dr = cases{i,2};
        rng(20260912+10*100000+i*1000+1,'twister');
        P = feval(p,'N',100,'M',10,'D',Dr,'maxFE',500);
        Alg = feval('PIEA','save',30,'run',1,'outputFcn',@(~,~)[]);
        t0 = tic; Alg.Solve(P); tSolve = toc(t0);
        t1 = tic; Alg.CalMetric('IGD');  tIGD  = toc(t1);
        t2 = tic; Alg.CalMetric('IGDp'); tIGDp = toc(t2);
        fprintf('    %-6s D=%2d | solve %.1f s | IGD %.2f s | IGDp %.2f s | IGD=%.6g IGDp=%.6g\n', ...
            p,Dr,tSolve,tIGD,tIGDp,Alg.metric.IGD(end),Alg.metric.IGDp(end));
    end
    fprintf('IGDP TEST DONE\n');
end
