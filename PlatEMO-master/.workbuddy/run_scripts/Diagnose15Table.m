function Diagnose15Table()
%Diagnose15Table Work out which run subset the existing 15-objective IGD table
%   was built from, by comparing its printed means against recomputed means over
%   candidate subsets. Read-only.
    xls = 'C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\lambdat030十五目标.xlsx';
    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\15目标';
    algCol = {'REMO','PIEA','MCEAD','CSEA','KRVEA_100','PCSAEA_N100', ...
              'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    C = readcell(xls, 'Sheet', 'IGD');
    fprintf('sheet size: %s\n', mat2str(size(C)));
    fprintf('header: %s\n', strjoin(cellfun(@(v) char(string(v)), C(1,:), 'UniformOutput', false), ' | '));

    % candidate run subsets
    cands = {1:18, 1:20, 1:30, 11:30, 1:16};
    fprintf('\n%-40s %-6s %12s %12s %12s %12s %12s %12s\n', 'algorithm','prob','refMean', ...
        'r1-18','r1-20','r1-30','r11-30','r1-16');
    for a = 1:numel(algCol)
        alg = algCol{a};
        dir_ = fullfile(root, alg);
        for p = 1:numel(problems)
            prob = problems{p};
            txt = C{p + 1, 5 + a};
            if ~ischar(txt), continue; end
            tok = regexp(txt, '([\d.eE+-]+)\s*\(', 'tokens', 'once');
            if isempty(tok), continue; end
            refMean = str2double(tok{1});

            d = dir(fullfile(dir_, sprintf('%s_%s_M15_D*_*.mat', alg, prob)));
            if isempty(d), fprintf('%-40s %-6s (no files)\n', alg, prob); continue; end
            vals = nan(numel(d), 1); rids = nan(numel(d), 1);
            for i = 1:numel(d)
                tok2 = regexp(d(i).name, '_M15_D(\d+)_(\d+)\.mat$', 'tokens', 'once');
                rids(i) = str2double(tok2{2});
                S = load(fullfile(dir_, d(i).name), 'metric');
                vals(i) = S.metric.IGD(end);
            end
            out = nan(1, numel(cands));
            for c = 1:numel(cands)
                sel = ismember(rids, cands{c});
                if any(sel), out(c) = mean(vals(sel)); end
            end
            fprintf('%-40s %-6s %12.6g %12.6g %12.6g %12.6g %12.6g %12.6g\n', ...
                alg, prob, refMean, out(1), out(2), out(3), out(4), out(5));
        end
    end
    fprintf('\nDIAGNOSE15 DONE\n');
end
