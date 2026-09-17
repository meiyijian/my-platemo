function CompareIGDpMerge()
%CompareIGDpMerge Compare the IGD+ already stored in the raw run files with the
%   values recomputed yesterday, and map the coverage of the existing field.
%   Read-only.

    rawRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    outBase = 'C:\Users\lsx\Desktop\AdaMao实验表';
    algs = {'REMO_UniformMix_Pruned_Weighted_Lambdat030','REMO','PIEA', ...
            'CSEA','PCSAEA_N100','KRVEA_100','MCEAD'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    Ms = [10 15 20];

    fprintf('==== coverage of metric.IGDp in the raw files ====\n');
    fprintf('%-6s %-45s %8s %8s %8s\n', 'M', 'algorithm', 'total', 'hasIGDp', 'hasHV');
    for mi = 1:numel(Ms)
        M = Ms(mi);
        for a = 1:numel(algs)
            alg = algs{a};
            if M == 10
                rawDir = fullfile(rawRoot, '10目标', 'n30', alg);
            else
                rawDir = fullfile(rawRoot, sprintf('%d目标', M), alg);
            end
            if ~isfolder(rawDir), fprintf('%-6d %-45s (no folder)\n', M, alg); continue; end
            files = dir(fullfile(rawDir, sprintf('%s_*_M%d_D*_*.mat', alg, M)));
            nIGDp = 0; nHV = 0;
            for i = 1:numel(files)
                try
                    w = whos('-file', fullfile(rawDir, files(i).name), '-regexp', '^metric$');
                    if isempty(w), continue; end
                    S = load(fullfile(rawDir, files(i).name), 'metric');
                    if isfield(S.metric, 'IGDp'), nIGDp = nIGDp + 1; end
                    if isfield(S.metric, 'HV'),   nHV   = nHV   + 1; end
                catch
                end
            end
            fprintf('%-6d %-45s %8d %8d %8d\n', M, alg, numel(files), nIGDp, nHV);
        end
    end

    fprintf('\n==== value check: stored IGDp vs recomputed, DTLZ1/DTLZ2/DTLZ7 ====\n');
    for mi = [1 3]
        M = Ms(mi);
        for pi = [1 2 7]
            prob = problems{pi};
            fprintf('\n-- M=%d %s --\n', M, prob);
            for a = 1:numel(algs)
                alg = algs{a};
                if M == 10
                    rawDir = fullfile(rawRoot, '10目标', 'n30', alg);
                else
                    rawDir = fullfile(rawRoot, sprintf('%d目标', M), alg);
                end
                prod = fullfile(outBase, sprintf('IGDplus_M%d', M), alg, ...
                    sprintf('%s_IGDp_M%d.mat', prob, M));
                if ~isfile(prod), continue; end
                P = load(prod);
                % run 1 of the raw file
                d = dir(fullfile(rawDir, sprintf('%s_%s_M%d_D*_1.mat', alg, prob, M)));
                if isempty(d), fprintf('  %-45s (raw run1 missing)\n', alg); continue; end
                S = load(fullfile(rawDir, d(1).name), 'metric');
                if ~isfield(S.metric, 'IGDp')
                    fprintf('  %-45s raw: <none>   prod end=%.6g\n', alg, P.IGDpCell{1}(end));
                    continue;
                end
                rv = S.metric.IGDp(:)'; pv = P.IGDpCell{1}(:)' ;
                if numel(rv) ~= numel(pv)
                    fprintf('  %-45s LENGTH %d vs %d\n', alg, numel(rv), numel(pv));
                    continue;
                end
                fprintf('  %-45s raw end=%.8g  prod end=%.8g  maxAbsDiff=%.3g\n', ...
                    alg, rv(end), pv(end), max(abs(rv - pv)));
            end
        end
    end
    fprintf('\nCOMPARE DONE\n');
end
