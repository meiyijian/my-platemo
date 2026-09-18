function BuildTable15Data()
%BuildTable15Data Extract IGD and IGDp of the fifteen-objective runs and emit the
%   formatted table texts, in the same conventions as the ten-objective table:
%     - eight algorithm columns, our NoBatchDist variant last;
%     - mean and STD over runs 1-20 (the subset the existing 15-objective table
%       was built from, verified point by point);
%     - cells formatted '%.4e (%.2e)' with 'e-0' folded to 'e-' and 'e+0' to 'e+';
%     - significance from a Wilcoxon rank sum test against the LAST column,
%       p < 0.05, '+' when the baseline is better, '-' when worse, '=' otherwise,
%       appended as ' ' plus sign; the last column carries no sign;
%     - the per-row minimum is reported so the spreadsheet builder can colour it.
%   One CSV per metric.

    outBase  = 'C:\Users\lsx\Desktop\AdaMao实验表';
    root     = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\15目标';
    M        = 15;
    runs     = 1:20;
    algs = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'};
    labels = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100', ...
              'Lambdat030','NoBatchDist'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    metrics = {'IGD','IGDp'};

    nA = numel(algs); nP = numel(problems);
    for mi = 1:numel(metrics)
        metric = metrics{mi};
        cellTxt = cell(nP, nA); bestAlg = cell(nP, 1);
        Ds = nan(nP, 1);
        cnt = zeros(nA - 1, 3);      % columns: '+', '-', '='
        meansAll = nan(nP, nA);
        for p = 1:nP
            prob = problems{p};
            vals = cell(1, nA); means = nan(1, nA); stds = nan(1, nA);
            for a = 1:nA
                d = dir(fullfile(root, algs{a}, sprintf('%s_%s_M%d_D*_*.mat', algs{a}, prob, M)));
                assert(~isempty(d), 'No files for %s %s', algs{a}, prob);
                v = nan(numel(d), 1); rid = nan(numel(d), 1);
                for i = 1:numel(d)
                    tok = regexp(d(i).name, sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$', M), 'tokens', 'once');
                    rid(i) = str2double(tok{2});
                    if a == 1 && i == 1, Ds(p) = str2double(tok{1}); end
                    S = load(fullfile(root, algs{a}, d(i).name), 'metric');
                    assert(isfield(S.metric, metric), '%s missing %s: %s', algs{a}, metric, d(i).name);
                    v(i) = S.metric.(metric)(end);
                end
                sel = ismember(rid, runs);
                vals{a} = v(sel);
                means(a) = mean(vals{a});
                stds(a)  = std(vals{a});
            end
            minlen = min(cellfun(@numel, vals));
            signs = repmat(' ', 1, nA);
            for a = 1:nA-1
                pv = ranksum(vals{a}(1:minlen), vals{end}(1:minlen));
                if pv >= 0.05 || means(a) == means(end)
                    signs(a) = '=';
                elseif means(a) < means(end)    % both metrics are min-is-better
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
            meansAll(p, :) = means;
            for a = 1:nA-1
                switch signs(a)
                    case '+', cnt(a, 1) = cnt(a, 1) + 1;
                    case '-', cnt(a, 2) = cnt(a, 2) + 1;
                    otherwise, cnt(a, 3) = cnt(a, 3) + 1;
                end
            end
        end

        T = table(problems(:), repmat(M, nP, 1), Ds, 'VariableNames', {'Problem','M','D'});
        for a = 1:nA, T.(algs{a}) = cellTxt(:, a); end
        T.BestAlg = bestAlg;
        for a = 1:nA-1
            T.(sprintf('cnt_%s', labels{a})) = repmat( ...
                {sprintf('%d/%d/%d', cnt(a,1), cnt(a,2), cnt(a,3))}, nP, 1);
        end
        csvFile = fullfile(outBase, 'lambdat030版本', sprintf('table15_%s.csv', metric));
        writetable(T, csvFile, 'Encoding', 'UTF-8');

        fprintf('\n=== 15 objective, %s (runs 1-20, last column = NoBatchDist) ===\n', metric);
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
    fprintf('\nTABLE 15 DATA DONE\n');
end
