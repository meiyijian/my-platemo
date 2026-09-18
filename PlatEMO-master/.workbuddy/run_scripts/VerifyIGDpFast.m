function VerifyIGDpFast()
%VerifyIGDpFast Prove that IGDpFast reproduces the stock metric and measure the
%   speed-up. Uses one small-reference problem and the pathological DTLZ7 case.
    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));

    raw = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    alg = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    cases = {20, 'DTLZ7', 30; 20, 'WFG1', 30; 10, 'DTLZ1', 30};

    for c = 1:size(cases, 1)
        M = cases{c,1}; prob = cases{c,2}; D = cases{c,3};
        if M == 10
            dir_ = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030';
            nm = 'REMO_UniformMix_Pruned_Weighted_Lambdat030';
        else
            dir_ = raw; nm = alg;
        end
        f = fullfile(dir_, sprintf('%s_%s_M%d_D%d_1.mat', nm, prob, M, D));
        if ~isfile(f), fprintf('%s (missing)\n', f); continue; end
        S = load(f);
        pro = feval(prob, 'M', M, 'D', D, 'N', 100, 'maxFE', 300);
        fprintf('--- M=%d %s : reference %d points, population %d front\n', ...
            M, prob, size(pro.optimum, 1), numel(S.result{end,2}.best));

        t = tic; v1 = IGDp(S.result{end,2}, pro.optimum); t1 = toc(t);
        t = tic; v2 = IGDpFast(S.result{end,2}, pro.optimum); t2 = toc(t);
        fprintf('    stock  IGDp = %.12g   (%.2f s)\n', v1, t1);
        fprintf('    fast   IGDp = %.12g   (%.2f s)   speed-up x%.1f   relDiff=%.3g\n', ...
            v2, t2, t1/t2, abs(v1-v2)/abs(v1));
    end
    fprintf('VERIFY IGDpFast DONE\n');
end
