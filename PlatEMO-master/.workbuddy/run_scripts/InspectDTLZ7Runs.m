function InspectDTLZ7Runs(alg, M)
%InspectDTLZ7Runs Check every DTLZ7 run file for an abnormal population size or
%   snapshot count, which would explain why the concurrent pass dies there.
    if nargin < 1 || isempty(alg)
        alg = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    end
    if nargin < 2 || isempty(M), M = 20; end
    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));

    rawDir = fullfile('C:\Users\lsx\Desktop\REMOandDREMO测试集', sprintf('%d目标', M), alg);
    d = dir(fullfile(rawDir, sprintf('%s_DTLZ7_M%d_D*_*.mat', alg, M)));
    fprintf('%-5s %6s %6s %8s %8s %8s %10s\n', 'run', 'nSnap', 'nObj1', 'maxObj', 'nNDend', 'bytes', 'mem');
    tot = 0;
    for i = 1:numel(d)
        f = fullfile(rawDir, d(i).name);
        tok = regexp(d(i).name, sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$', M), 'tokens', 'once');
        run = str2double(tok{2});
        S = load(f);
        n = size(S.result, 1);
        o1 = S.result{1, 2}.objs;
        nd = numel(S.result{end, 2}.best);
        mx = 0;
        for k = 1:n
            v = S.result{k, 2}.objs;
            mx = max(mx, max(v(:)));
        end
        tot = tot + n;
        fprintf('%-5d %6d %6d %8.4g %8d %8d\n', run, n, size(o1,1), mx, nd, d(i).bytes);
    end
    fprintf('\nfiles = %d, total snapshots = %d\n', numel(d), tot);
    fprintf('If every DTLZ7 run has 30 snapshots and a ~300 population, the cost is\n');
    fprintf('about %d evaluations of IGD+ for this problem alone.\n', tot);
    fprintf('INSPECT DTLZ7 DONE\n');
end
