function ProbeHVDTLZ()
%ProbeHVDTLZ Check HV validity across the 16 problems at M=10 (read-only).
    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    base = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030';
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    fprintf('%-6s %12s %12s %12s %6s %8s %9s\n', ...
        'prob','HV','IGDp','IGD','nND','tHV(s)','tIGDp(s)');
    totalHV = 0; totalIGDp = 0;
    for k = 1:numel(probs)
        f = fullfile(base, sprintf('REMO_UniformMix_Pruned_Weighted_Lambdat030_%s_M10_D30_1.mat', probs{k}));
        if ~isfile(f), fprintf('%-6s (missing)\n', probs{k}); continue; end
        S = load(f);
        md = S.metadata;
        pro = feval(md.problem, 'N', md.N, 'M', md.M, 'D', md.D, 'maxFE', md.maxFE);
        pop = S.result{end,2};
        allObj = pop.objs;
        bObj   = pop.best.objs;
        nND    = size(bObj, 1);
        rng(20260912, 'twister');
        t = tic; h = pro.CalMetric('HV', pop); thv = toc(t);
        t = tic; g = pro.CalMetric('IGDp', pop); tg = toc(t);
        igd = S.metric.IGD(end);
        totalHV = totalHV + thv; totalIGDp = totalIGDp + tg;
        fprintf('%-6s %12.4g %12.4g %12.4g %6d %8.2f %9.3f\n', ...
            probs{k}, h, g, igd, nND, thv, tg);
        fprintf('        objs min=%10.4g  max=%10.4g | optimum nadir=%10.4g\n', ...
            min(allObj(:)), max(allObj(:)), max(max(pro.optimum, [], 1)));
    end
    fprintf('\nTotal HV time 16 runs   : %.1f s (%.2f s/run)\n', totalHV, totalHV/16);
    fprintf('Total IGDp time 16 runs : %.1f s (%.3f s/run)\n', totalIGDp, totalIGDp/16);
    fprintf('PROBE HV DONE\n');
end
