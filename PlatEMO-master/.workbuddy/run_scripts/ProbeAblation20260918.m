function ProbeAblation20260918()
%ProbeAblation20260918  Measure optimum sizes and IGD+/IGD cost per problem.
%   Read-only probe: builds each problem, reports the actual M/D and the
%   number of reference points, then times the stock IGDp.m and the
%   block-wise IGDpFast.m on a dummy 100-point population.

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    addpath('D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts');

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    for M = [10,20]
        fprintf('\n==== M = %d ====\n',M);
        fprintf('%-6s %4s %8s %12s %10s %10s %10s\n','prob','D','Nr','size(MB)','IGDp(s)','Fast(s)','IGD(s)');
        for p = 1:numel(problems)
            fh = str2func(problems{p});
            P  = fh('M',M,'D',30,'maxFE',300,'N',100);
            Nr = size(P.optimum,1);
            mb = Nr*P.M*8/1048576;
            % dummy population with .best.objs
            Pop = struct('best',struct('objs',rand(100,P.M)));
            t1 = nan; t2 = nan; t3 = nan;
            if Nr <= 20000
                s = tic; IGDp(Pop,P.optimum); t1 = toc(s);
            end
            s = tic; IGDpFast(Pop,P.optimum); t2 = toc(s);
            s = tic; IGD(Pop,P.optimum); t3 = toc(s);
            fprintf('%-6s %4d %8d %12.2f %10.3f %10.3f %10.3f\n', ...
                problems{p},P.D,Nr,mb,t1,t2,t3);
        end
    end
    fprintf('PROBE DONE\n');
end
