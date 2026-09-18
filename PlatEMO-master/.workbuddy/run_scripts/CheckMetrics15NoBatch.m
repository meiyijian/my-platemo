function CheckMetrics15NoBatch()
%CheckMetrics15NoBatch Which metric fields do the new NoBatchDist files hold?
    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    dirs = { ...
        'C:\Users\lsx\Desktop\REMOandDREMO测试集\15目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist', ...
        'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'};
    probs = {'DTLZ1','DTLZ7','WFG1','WFG9'};
    for k = 1:numel(dirs)
        d = dirs{k};
        fprintf('==== %s\n', d);
        if ~isfolder(d), fprintf('  missing\n'); continue; end
        for p = 1:numel(probs)
            fs = dir(fullfile(d, sprintf('*_%s_M*_D*_1.mat', probs{p})));
            if isempty(fs), fprintf('  %-6s (no file)\n', probs{p}); continue; end
            S = load(fullfile(d, fs(1).name));
            mf = fieldnames(S.metric);
            fprintf('  %-6s metric = [%s]', probs{p}, strjoin(mf', ', '));
            if isfield(S.metric,'IGD'),  fprintf('  IGD len=%d', numel(S.metric.IGD)); end
            if isfield(S.metric,'IGDp'), fprintf('  IGDp len=%d', numel(S.metric.IGDp)); end
            fprintf('  vars=[%s]\n', strjoin(fieldnames(S)', ', '));
        end
    end
    fprintf('CHECK DONE\n');
end
