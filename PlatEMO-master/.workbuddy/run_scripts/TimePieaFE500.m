function TimePieaFE500()
%TimePieaFE500 Wall-clock of one PIEA run per representative problem at
%   N=100, M=10, D as requested, maxFE=500.

    platRoot = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    pieaDir  = fullfile(platRoot,'Algorithms','Multi-objective optimization','PIEA');
    addpath(genpath(platRoot));
    addpath(pieaDir,'-begin');
    addpath(pieaDir);

    fprintf('== EXISTING 默认n PIEA FE RANGE ==\n');
    f = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\默认n\PIEA\PIEA_DTLZ1_M10_D14_1.mat';
    S = load(f);
    FEcol = cellfun(@(x) x(1),S.result(:,1));
    fprintf('result FE col: %s\n',mat2str(FEcol'));
    fprintf('result size  : %dx%d  class=%s\n',size(S.result,1),size(S.result,2),class(S.result));

    fprintf('\n== TIMING (serial, one run each) ==\n');
    cases = {'DTLZ1',14; 'WFG1',14; 'DTLZ3',19; 'WFG9',19};
    for i = 1:size(cases,1)
        p  = cases{i,1};
        Dr = cases{i,2};
        seed = 20260912 + 10*100000 + i*1000 + 1;
        rng(seed,'twister');
        pr = feval(p,'N',100,'M',10,'D',Dr,'maxFE',500);
        alg = feval('PIEA','save',30,'run',1,'outputFcn',@(~,~)[]);
        t = tic;
        alg.Solve(pr);
        el = toc(t);
        alg.CalMetric('IGD');
        fprintf('    %-6s Dreq=%2d D=%2d FE=%d rows=%d | %.1f s | IGD=%.6g\n', ...
            p,Dr,pr.D,pr.FE,size(alg.result,1),el,alg.metric.IGD(end));
    end
    fprintf('\nTIMING DONE\n');
end
