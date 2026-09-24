function BuildFE500IGDTable(runs,metric,M)
%BuildFE500IGDTable IGD/IGD+ table of the FE500 M=15 baselines, anchored on PACDIS.
%   Reads the last-snapshot value of the requested metric of every stored run,
%   computes mean/std over the requested run numbers and the +/-/= symbol of a
%   MATLAB ranksum test against the LAST column (the NoBatchDist variant, shown
%   as PACDIS). '+': the baseline is significantly better, '-': worse,
%   '=': no significant difference; the anchor column carries none.
%   REMO is deliberately absent: it has no data yet. Writes one CSV to the
%   run_scripts folder, never into the dataset folder.
    if nargin < 1 || isempty(runs), runs = 1:10; end
    if nargin < 2 || isempty(metric), metric = 'IGDp'; end
    if nargin < 3 || isempty(M), M = 15; end
    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    if M == 10
        base = fullfile(testRoot,'10目标','n30','FE500');
    else
        base = fullfile(testRoot,sprintf('%d目标',M),'FE500');
    end
    algs = {'REMO','SSDE','PCSAEA','SAMOEATL2M','CSEA','HES_EA', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'};
    labels = {'REMO','SSDE','PC-SAEA','SAMOEA-TL2M','CSEA','HES-EA','PACDIS'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    outCsv = fullfile('D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts', ...
        sprintf('fe500_m%d_%s_table.csv',M,lower(metric)));

    nA = numel(algs); nP = numel(problems);
    cellTxt = cell(nP,nA); bestAlg = cell(nP,1); Ds = nan(nP,1);
    cnt = zeros(nA-1,3); meansAll = nan(nP,nA);

    for p = 1:nP
        prob = problems{p};
        vals = cell(1,nA); means = nan(1,nA); stds = nan(1,nA);
        for a = 1:nA
            d = dir(fullfile(base,algs{a},sprintf('%s_%s_M%d_D*_*.mat',algs{a},prob,M)));
            if isempty(d)
                vals{a} = [];
                cellTxt{p,a} = '--';
                continue;
            end
            v = nan(numel(d),1); rid = nan(numel(d),1);
            for i = 1:numel(d)
                tok = regexp(d(i).name,sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$',M),'tokens','once');
                rid(i) = str2double(tok{2});
                if a==1 && i==1, Ds(p) = str2double(tok{1}); end
                S = load(fullfile(base,algs{a},d(i).name),'metric');
                assert(isfield(S.metric,metric),'%s %s missing %s: %s',algs{a},prob,metric,d(i).name);
                igd = S.metric.(metric)(:);
                v(i) = igd(end);
            end
            sel = ismember(rid,runs);
            vals{a} = v(sel);
            means(a) = mean(vals{a});
            stds(a)  = std(vals{a});
        end
        signs = repmat(' ',1,nA);
        for a = 1:nA-1
            if isempty(vals{a}) || isempty(vals{end})
                continue;
            end
            % Align on the shorter of this pair only. Taking a global minimum
            % would let one incomplete algorithm (e.g. REMO midway through its
            % top-up) shrink every other comparison as well.
            k = min(numel(vals{a}),numel(vals{end}));
            pv = ranksum(vals{a}(1:k),vals{end}(1:k));
            if pv >= 0.05 || means(a) == means(end)
                signs(a) = '=';
            elseif means(a) < means(end)      % IGD is min-is-better
                signs(a) = '+';
            else
                signs(a) = '-';
            end
        end
        for a = 1:nA
            if isempty(vals{a})
                continue;
            end
            txt = sprintf('%.4e (%.2e)',means(a),stds(a));
            txt = strrep(strrep(txt,'e-0','e-'),'e+0','e+');
            if a < nA, txt = [txt,' ',signs(a)]; end
            cellTxt{p,a} = txt;
        end
        [~,bi] = min(means,[],'omitnan');
        bestAlg{p} = labels{bi};
        meansAll(p,:) = means;
        for a = 1:nA-1
            switch signs(a)
                case '+', cnt(a,1) = cnt(a,1)+1;
                case '-', cnt(a,2) = cnt(a,2)+1;
                otherwise, cnt(a,3) = cnt(a,3)+1;
            end
        end
    end

    T = table(problems(:),repmat(M,nP,1),Ds(:),'VariableNames',{'Problem','M','D'});
    for a = 1:nA, T.(algs{a}) = cellTxt(:,a); end
    T.BestAlg = bestAlg;
    for a = 1:nA-1
        T.(sprintf('cnt_%s',labels{a})) = repmat( ...
            {sprintf('%d/%d/%d',cnt(a,1),cnt(a,2),cnt(a,3))},nP,1);
    end
    writetable(T,outCsv,'Encoding','UTF-8');

    fprintf('\n=== FE500 M=%d %s (runs %d-%d, anchor = PACDIS last column) ===\n',M,metric,runs(1),runs(end));
    fprintf('%-7s', 'Problem');
    for a = 1:nA, fprintf(' %-28s',labels{a}); end
    fprintf('  best\n');
    for p = 1:nP
        fprintf('%-7s',problems{p});
        for a = 1:nA, fprintf(' %-28s',cellTxt{p,a}); end
        fprintf('  %s\n',bestAlg{p});
    end
    fprintf('%-7s','+/-/=');
    for a = 1:nA-1, fprintf(' %-28s',sprintf('%d/%d/%d',cnt(a,:))); end
    fprintf('\nwrote %s\n',outCsv);
end
