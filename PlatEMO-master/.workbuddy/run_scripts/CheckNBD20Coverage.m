function CheckNBD20Coverage()
%CheckNBD20Coverage Which (problem, run) of the 20-objective NoBatchDist set already
%   carry metric.IGDp, and how do those values behave? This decides whether the
%   DTLZ7 crash even matters.
    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    fprintf('%-8s %6s %8s %10s %10s %12s\n', 'prob', 'files', 'hasIGDp', 'IGD_end_mean', 'IGDp_end_mean', 'IGDp/IGD ratio');
    totFiles = 0; totWith = 0;
    for p = 1:numel(problems)
        prob = problems{p};
        d = dir(fullfile(root, sprintf('*_%s_M20_D*_*.mat', prob)));
        if isempty(d), fprintf('%-8s (none)\n', prob); continue; end
        nWith = 0; igd = []; igdp = [];
        for i = 1:numel(d)
            S = load(fullfile(root, d(i).name), 'metric');
            if isfield(S.metric, 'IGD'), igd(end+1) = S.metric.IGD(end); end %#ok<AGROW>
            if isfield(S.metric, 'IGDp')
                nWith = nWith + 1;
                igdp(end+1) = S.metric.IGDp(end); %#ok<AGROW>
            end
        end
        ratio = NaN;
        if ~isempty(igdp) && mean(igd) ~= 0, ratio = mean(igdp)/mean(igd); end
        fprintf('%-8s %6d %8d %10.5g %10.5g %12.4f\n', prob, numel(d), nWith, ...
            mean(igd), mean(igdp), ratio);
        totFiles = totFiles + numel(d); totWith = totWith + nWith;
    end
    fprintf('\ntotal files = %d, with IGDp = %d, missing = %d\n', totFiles, totWith, totFiles - totWith);
    fprintf('CHECK NBD20 DONE\n');
end
