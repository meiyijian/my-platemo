function DiagnoseDTLZ7(alg, M, D)
%DiagnoseDTLZ7 Isolate the DTLZ7 crash: inspect the stored population, the
%   reference set size, and run IGD+ on a single snapshot without a pool.

    if nargin < 1 || isempty(alg)
        alg = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    end
    if nargin < 2 || isempty(M), M = 20; end
    if nargin < 3 || isempty(D), D = 30; end

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    f = fullfile('C:\Users\lsx\Desktop\REMOandDREMO测试集', sprintf('%d目标', M), alg, ...
        sprintf('%s_DTLZ7_M%d_D%d_1.mat', alg, M, D));
    fprintf('file: %s\nexists: %d\n', f, isfile(f));
    S = load(f);
    fprintf('top vars: %s\n', strjoin(fieldnames(S)', ', '));
    fprintf('result size: %s\n', mat2str(size(S.result)));
    n = size(S.result, 1);
    for k = [1, n]
        pop = S.result{k,2};
        fprintf('snap %2d: FE=%g class=%s', k, S.result{k,1}, class(pop));
        if isa(pop, 'SOLUTION')
            o = pop.objs;
            fprintf(' objs=%s nan=%d inf=%d max=%g min=%g', ...
                mat2str(size(o)), sum(isnan(o(:))), sum(isinf(o(:))), max(o(:)), min(o(:)));
        end
        fprintf('\n');
    end

    fprintf('\nbuilding problem ...\n');
    t = tic;
    pro = feval('DTLZ7', 'M', M, 'D', D, 'N', 100, 'maxFE', 300);
    fprintf('  built in %.1f s, optimum = %s, PF = %s\n', ...
        toc(t), mat2str(size(pro.optimum)), mat2str(size(pro.PF)));

    fprintf('\nIGD+ on the last snapshot ...\n');
    t = tic;
    v = IGDp(S.result{end,2}, pro.optimum);
    fprintf('  IGDp = %.8g  (%.1f s)\n', v, toc(t));

    fprintf('\nloop over the first 3 snapshots ...\n');
    for k = 1:min(3, n)
        t = tic;
        v = IGDp(S.result{k,2}, pro.optimum);
        fprintf('  snap %2d IGDp = %.8g (%.1f s)\n', k, v, toc(t));
    end
    fprintf('DIAGNOSE DTLZ7 DONE\n');
end
