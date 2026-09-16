function SummaryIGDp_Runs20()
%SummaryIGDp_Runs20 Matched-run summary of the computed IGD+ values.
%   The six baselines store thirty runs while PACDIS stores twenty, so a mean
%   over all stored runs would compare unequal samples. This summary restricts
%   every algorithm to runs 1-20, which is the convention of the convergence
%   figure of the paper, and reports the final IGD+ (at FE=300) per problem.

    outRoot  = 'C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_M10';
    algs = {'REMO_UniformMix_Pruned_Weighted_Lambdat030', ...
            'REMO','PIEA','CSEA','PCSAEA_N100','KRVEA_100','MCEAD'};
    labels = {'PACDIS','REMO','PIEA','CSEA','PC-SAEA','K-RVEA','MCEA/D'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    runs = 1:20;

    meanTab = nan(numel(algs), numel(problems));
    medTab  = meanTab; stdTab = meanTab; nTab = zeros(size(meanTab));
    rows = {};
    for a = 1:numel(algs)
        for p = 1:numel(problems)
            f = fullfile(outRoot, algs{a}, sprintf('%s_IGDp_M10.mat', problems{p}));
            if ~isfile(f), continue; end
            S = load(f);
            sel = ismember(S.runIds, runs);
            v = S.IGDpFinal(sel);
            meanTab(a,p) = mean(v); medTab(a,p) = median(v); stdTab(a,p) = std(v);
            nTab(a,p) = numel(v);
            rows{end+1} = table({algs{a}}, {problems{p}}, numel(v), mean(v), ...
                median(v), std(v), min(v), max(v), 'VariableNames', ...
                {'algorithm','problem','nRuns','mean','median','std','min','max'}); %#ok<AGROW>
        end
    end
    T = vertcat(rows{:});
    writetable(T, fullfile(outRoot, 'summary_stats_runs1-20_IGDp_M10.csv'), 'Encoding', 'UTF-8');

    fprintf('\nFinal IGD+ at FE=300, runs 1-20 (nRuns = %s)\n', mat2str(unique(nTab)'));
    fprintf('%-8s', ''); fprintf('%9s', problems{:}); fprintf('\n');
    for a = 1:numel(algs)
        fprintf('%-8s', labels{a});
        fprintf('%9.4g', meanTab(a,:)); fprintf('\n');
    end

    % Wilcoxon rank-sum of ours against each baseline, per problem.
    fprintf('\nMann-Whitney U p-values (PACDIS vs baseline, runs 1-20)\n');
    fprintf('%-8s', ''); fprintf('%9s', problems{:}); fprintf('\n');
    for a = 2:numel(algs)
        pv = nan(1, numel(problems));
        for p = 1:numel(problems)
            fa = fullfile(outRoot, algs{1}, sprintf('%s_IGDp_M10.mat', problems{p}));
            fb = fullfile(outRoot, algs{a}, sprintf('%s_IGDp_M10.mat', problems{p}));
            if ~isfile(fa) || ~isfile(fb), continue; end
            A = load(fa); B = load(fb);
            va = A.IGDpFinal(ismember(A.runIds, runs));
            vb = B.IGDpFinal(ismember(B.runIds, runs));
            pv(p) = ranksum(va, vb);
        end
        fprintf('%-8s', labels{a});
        fprintf('%9.2g', pv); fprintf('\n');
    end
    fprintf('SUMMARY DONE\n');
end
