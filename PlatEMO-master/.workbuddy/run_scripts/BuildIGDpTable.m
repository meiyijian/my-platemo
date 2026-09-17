function BuildIGDpTable(Mlist)
%BuildIGDpTable Build the IGD+ summary table of one or more objective counts,
%   in exactly the format of the 10-objective reference workbook.
%   Every rule below is taken from the PlatEMO Experiment module
%   (GUI/module_exp.m) so that the numbers reproduce the reference table:
%     - mean and standard deviation are computed over ALL available runs of the
%       algorithm, not over a common subset;
%     - the displayed text is sprintf('%%.4e (%%.2e)') with 'e-0' folded to
%       'e-' and 'e+0' to 'e+';
%     - the significance symbol comes from a Wilcoxon rank sum test of each
%       baseline against the last column, evaluated on the runs truncated to
%       the shortest sample among the algorithms, with the threshold 0.05;
%     - '+' means the baseline is significantly better than the last column,
%       '-' significantly worse, '=' no significant difference;
%     - the symbol is appended as ' ' + sign, and the last column carries none.
%   The per-row minimum is reported separately so that the spreadsheet builder
%   can colour it.
%   Output: one CSV per objective count holding the already formatted cell
%   texts, the best-algorithm map and the '+/-/=' counters.

    if nargin < 1 || isempty(Mlist), Mlist = [15 20]; end
    outBase  = 'C:\Users\lsx\Desktop\AdaMao实验表';
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    % Column order of the reference workbook, our algorithm last.
    cols   = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100', ...
              'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    labels = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100','PACDIS'};

    for mi = 1:numel(Mlist)
        M = Mlist(mi);
        outRoot = fullfile(outBase, sprintf('IGDplus_M%d', M));
        nA = numel(cols); nP = numel(problems);
        Ds = nan(1, nP);
        cellTxt = cell(nP, nA); bestAlg = cell(nP, 1);
        cnt = zeros(nA - 1, 3);          % columns: '+', '-', '='
        nRunsTab = nan(nP, nA);

        for p = 1:nP
            prob = problems{p};
            vals = cell(1, nA); means = nan(1, nA); stds = nan(1, nA);
            for a = 1:nA
                f = fullfile(outRoot, cols{a}, sprintf('%s_IGDp_M%d.mat', prob, M));
                assert(isfile(f), 'Missing product: %s', f);
                S = load(f);
                v = S.IGDpFinal(:)';
                v = v(~isnan(v));
                vals{a} = v; means(a) = mean(v); stds(a) = std(v);
                nRunsTab(p, a) = numel(v);
                if a == 1, Ds(p) = S.meta.D; end
            end
            minlen = min(cellfun(@numel, vals));
            signs = repmat(' ', 1, nA);
            for a = 1:nA-1
                pv = ranksum(vals{a}(1:minlen), vals{end}(1:minlen));
                if pv >= 0.05 || means(a) == means(end)
                    signs(a) = '=';
                elseif means(a) < means(end)   % IGD+ is a min-is-better metric
                    signs(a) = '+';
                else
                    signs(a) = '-';
                end
            end
            for a = 1:nA
                txt = sprintf('%.4e (%.2e)', means(a), stds(a));
                txt = strrep(strrep(txt, 'e-0', 'e-'), 'e+0', 'e+');
                if a < nA, txt = [txt, ' ', signs(a)]; end
                cellTxt{p, a} = txt;
            end
            [~, bi] = min(means);
            bestAlg{p} = labels{bi};
            for a = 1:nA-1
                switch signs(a)
                    case '+', cnt(a, 1) = cnt(a, 1) + 1;
                    case '-', cnt(a, 2) = cnt(a, 2) + 1;
                    otherwise, cnt(a, 3) = cnt(a, 3) + 1;
                end
            end
        end

        T = table(problems(:), repmat(M, nP, 1), Ds(:), ...
            'VariableNames', {'Problem', 'M', 'D'});
        for a = 1:nA
            T.(cols{a}) = cellTxt(:, a);
        end
        T.BestAlg = bestAlg;
        for a = 1:nA-1
            T.(sprintf('cnt_%s', labels{a})) = repmat( ...
                {sprintf('%d/%d/%d', cnt(a,1), cnt(a,2), cnt(a,3))}, nP, 1);
        end
        csvFile = fullfile(outBase, sprintf('IGDplus_M%d', M), sprintf('table_M%d.csv', M));
        writetable(T, csvFile, 'Encoding', 'UTF-8');

        fprintf('\n=== M = %d ===\n', M);
        fprintf('runs per algorithm : %s\n', mat2str(unique(nRunsTab(:))'));
        fprintf('paired sample size : %d\n', minlen);
        fprintf('%-7s', 'Problem');
        for a = 1:nA, fprintf(' %-26s', labels{a}); end
        fprintf('  %s\n', 'best');
        for p = 1:nP
            fprintf('%-7s', problems{p});
            for a = 1:nA, fprintf(' %-26s', cellTxt{p, a}); end
            fprintf('  %s\n', bestAlg{p});
        end
        fprintf('%-7s', '+/-/=');
        for a = 1:nA-1, fprintf(' %-26s', sprintf('%d/%d/%d', cnt(a,:))); end
        fprintf('\nwrote %s\n', csvFile);
    end
    fprintf('\nTABLE DATA DONE\n');
end
