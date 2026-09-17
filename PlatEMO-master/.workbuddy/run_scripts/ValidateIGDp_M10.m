function ValidateIGDp_M10()
%ValidateIGDp_M10 Completeness and fairness check of the computed IGD+ files.
%   Reports, per algorithm and problem, the number of runs, the spread of the
%   snapshot counts, the FE reached by the last snapshot and the mean final
%   IGD+. A mismatched final FE would make a plain comparison of the final
%   values unfair, so it is checked explicitly. Finally one file per algorithm
%   is re-read from the raw dataset to confirm that the stored IGD and the
%   recomputed IGD+ agree in magnitude.

    outRoot  = 'C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_M10';
    algs = {'REMO_UniformMix_Pruned_Weighted_Lambdat030', ...
            'REMO','PIEA','CSEA','PCSAEA_N100','KRVEA_100','MCEAD'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    meanTab = nan(numel(algs), numel(problems));
    feMin = nan(numel(algs), numel(problems));
    feMax = nan(numel(algs), numel(problems));
    snMin = nan(numel(algs), numel(problems));
    snMax = nan(numel(algs), numel(problems));
    fprintf('%-45s %-6s %5s %9s %9s %7s %7s\n', ...
        'algorithm','prob','runs','FEmin','FEmax','snapMin','snapMax');
    nBadFE = 0; nMiss = 0;
    for a = 1:numel(algs)
        for p = 1:numel(problems)
            f = fullfile(outRoot, algs{a}, sprintf('%s_IGDp_M10.mat', problems{p}));
            if ~isfile(f), nMiss = nMiss + 1; continue; end
            S = load(f);
            feEnd = cellfun(@(v) v(end), S.FECell);
            sn    = cellfun(@numel, S.FECell);
            meanTab(a,p) = mean(S.IGDpFinal);
            feMin(a,p) = min(feEnd); feMax(a,p) = max(feEnd);
            snMin(a,p) = min(sn);    snMax(a,p) = max(sn);
            if min(feEnd) < 300, nBadFE = nBadFE + 1; end
            fprintf('%-45s %-6s %5d %9.0f %9.0f %7d %7d\n', ...
                algs{a}, problems{p}, numel(feEnd), min(feEnd), max(feEnd), min(sn), max(sn));
        end
    end
    fprintf('\nfiles missing        : %d of %d\n', nMiss, numel(algs)*numel(problems));
    fprintf('problems with FE<300 : %d of %d\n', nBadFE, numel(algs)*numel(problems));

    % Re-read one raw run per algorithm and compare stored IGD vs recomputed IGD+.
    rawRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30';
    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    fprintf('\n%-45s %-6s %14s %14s\n', 'algorithm','prob','stored IGD(end)','IGDp(end)');
    for a = 1:numel(algs)
        f = fullfile(outRoot, algs{a}, 'DTLZ2_IGDp_M10.mat');
        S = load(f);
        raw = fullfile(rawRoot, algs{a}, sprintf('%s_DTLZ2_M10_D30_1.mat', algs{a}));
        if ~isfile(raw), fprintf('%-45s %-6s (raw run 1 missing)\n', algs{a}, 'DTLZ2'); continue; end
        R = load(raw);
        fprintf('%-45s %-6s %14.6g %14.6g\n', ...
            algs{a}, 'DTLZ2', R.metric.IGD(end), S.IGDpCell{1}(end));
    end
    fprintf('VALIDATE DONE\n');
end
