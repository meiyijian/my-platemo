function TimingIGDpHV()
%TimingIGDpHV Read-only timing probe: IGD+ (all snapshots) and HV (final only).
    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    base = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030';
    names = {'REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ1_M10_D30_1.mat', ...
             'REMO_UniformMix_Pruned_Weighted_Lambdat030_WFG1_M10_D30_1.mat', ...
             'REMO_UniformMix_Pruned_Weighted_Lambdat030_WFG9_M10_D30_1.mat'};
    for k = 1:numel(names)
        f = fullfile(base, names{k});
        fprintf('\n===== %s\n', names{k});
        t = tic; S = load(f); fprintf('load          : %8.2f s\n', toc(t));
        md = S.metadata;
        fprintf('problem=%s M=%d D=%d N=%d maxFE=%d save=%d\n', md.problem, md.M, md.D, md.N, md.maxFE, md.save);
        t = tic;
        pro = feval(md.problem, 'N', md.N, 'M', md.M, 'D', md.D, 'maxFE', md.maxFE);
        fprintf('build problem : %8.2f s  (optimum %s)\n', toc(t), mat2str(size(pro.optimum)));

        r = S.result; n = size(r, 1);
        fprintf('snapshots     : %d (first FE=%g, last FE=%g)\n', n, r{1,1}, r{end,1});

        t = tic; v = zeros(n, 1);
        for i = 1:n
            v(i) = pro.CalMetric('IGDp', r{i,2});
        end
        el = toc(t);
        fprintf('IGDp all %2d snaps : %8.2f s  (%.4f s/snap)\n', n, el, el/n);
        fprintf('   IGDp first=%.6g last=%.6g | IGD first=%.6g last=%.6g\n', ...
            v(1), v(end), S.metric.IGD(1), S.metric.IGD(end));

        rng(20260912, 'twister');
        t = tic; h = pro.CalMetric('HV', r{end,2}); el = toc(t);
        fprintf('HV final only  : %8.2f s  -> %.6g\n', el, h);
        rng(20260912, 'twister');
        t = tic; h1 = pro.CalMetric('HV', r{1,2}); el = toc(t);
        fprintf('HV first snap  : %8.2f s  -> %.6g\n', el, h1);
    end
    fprintf('\nTIMING DONE\n');
end
