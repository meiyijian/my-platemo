function CompareDTLZ7Cost()
%CompareDTLZ7Cost Why did DTLZ7 finish in 22 s during the seven-algorithm pass
%   but takes seconds per single IGD+ evaluation now? Compares the reference
%   set size, the front size, and the timing of one evaluation.

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    cases = { ...
        'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_DTLZ7_M20_D30_1.mat'; ...
        'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\MCEAD\MCEAD_DTLZ7_M20_D30_1.mat'; ...
        'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030\REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ7_M20_D30_1.mat'};

    fprintf('reference set for DTLZ7 M=20:\n');
    pro = DTLZ7('M', 20, 'D', 30, 'N', 100, 'maxFE', 300);
    fprintf('  optimum = %s (%d points)\n', mat2str(size(pro.optimum)), size(pro.optimum, 1));
    fprintf('\n');

    fprintf('%-52s %6s %6s %8s %10s %9s\n', 'file', 'nSnap', 'nND', 'objsSz', 'IGDpEnd', 'seconds');
    for c = 1:numel(cases)
        f = cases{c};
        [~, nm] = fileparts(f);
        if ~isfile(f), fprintf('%-52s (missing)\n', nm); continue; end
        S = load(f);
        n = size(S.result, 1);
        last = S.result{end, 2};
        nd = numel(last.best);
        t = tic;
        v = IGDp(last, pro.optimum);
        el = toc(t);
        fprintf('%-52s %6d %6d %8s %10.6g %9.2f\n', ...
            nm(1:min(52, numel(nm))), n, nd, mat2str(size(last.objs)), v, el);
    end
    fprintf('\nCOMPARE DTLZ7 COST DONE\n');
end
