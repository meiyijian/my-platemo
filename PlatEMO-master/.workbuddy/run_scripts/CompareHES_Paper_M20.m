function CompareHES_Paper_M20()
%CompareHES_Paper_M20  HES_EA_N100 vs the paper's 7 algorithms, M=20, IGD+.
%
%   Reads IGDp(end) for run 1..20 of every DTLZ1-7 / WFG1-9 problem for eight
%   algorithms: the six baselines (REMO, PIEA, CSEA, PCSAEA_N100, KRVEA_100,
%   MCEAD), the new HES_EA_N100, and the anchor PACDIS
%   (= REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist, last column).
%   Computes mean +/- std, and for every baseline a Wilcoxon rank-sum test
%   against PACDIS (p < 0.05): '+' = significantly better (lower IGD+),
%   '-' = significantly worse, '=' = no detected difference.
%
%   Emits JSON consumed by build_compare_hes_paper.py (same schema and xlsx
%   layout as the paper's ablation tables: Problem|N|M|D|FE + algorithm
%   columns, anchor last with no sign, +/-/= count row, per-row minimum in
%   blue).

    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    d20      = fullfile(testRoot,'20目标');
    logDir   = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    if ~isfolder(logDir), mkdir(logDir); end

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    runs = 1:20;
    M = 20;
    arms = { ...
        'REMO',        'REMO',        0; ...
        'PIEA',        'PIEA',        0; ...
        'CSEA',        'CSEA',        0; ...
        'PCSAEA_N100', 'PCSAEA_N100', 0; ...
        'KRVEA_100',   'KRVEA_100',   0; ...
        'MCEAD',       'MCEAD',       0; ...
        'HES_EA_N100', 'HES_EA_N100', 0; ...
        'PACDIS',      'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist', 1};
    labels = arms(:,1)';
    nA = numel(labels);
    nP = numel(problems);
    anchorIdx = find(cell2mat(arms(:,3)),1);

    Ds = nan(1,nP);
    means = nan(nP,nA);
    stds  = nan(nP,nA);
    missing = {};
    for p = 1:nP
        for a = 1:nA
            vals = nan(1,numel(runs));
            Drow = 30;
            for ri = 1:numel(runs)
                f = '';
                for dd = [30 31]
                    cand = fullfile(d20,arms{a,2},sprintf('%s_%s_M%d_D%d_%d.mat', ...
                        arms{a,2},problems{p},M,dd,runs(ri)));
                    if isfile(cand), f = cand; Drow = dd; break; end
                end
                if isempty(f)
                    missing{end+1} = sprintf('%s %s run%d',arms{a,1},problems{p},runs(ri)); %#ok<AGROW>
                    continue;
                end
                S = load(f);
                v = S.metric.IGDp(:);
                vals(ri) = v(end);
            end
            Ds(p) = Drow;
            means(p,a) = mean(vals,'omitnan');
            stds(p,a)  = std(vals,0,'omitnan');
        end
    end
    if ~isempty(missing)
        error('CompareHES_Paper_M20:Missing','%d missing files, first: %s', ...
            numel(missing),missing{1});
    end

    % significance of every baseline vs the PACDIS anchor
    signs = cell(1,nA); signs{anchorIdx} = '';
    for a = 1:nA
        if a == anchorIdx, continue; end
        pv = nan(1,nP);
        for p = 1:nP
            A = arrayfun(@(r)runVal(arms{a,2},problems{p},M,r,d20), runs);
            B = arrayfun(@(r)runVal(arms{anchorIdx,2},problems{p},M,r,d20), runs);
            pv(p) = ranksum(A,B);
        end
        signs{a} = sigText(pv, means(:,a), means(:,anchorIdx));
    end

    % counts (nA-1 columns, anchor excluded)
    cntTxt = cell(1,nA-1);
    k = 0;
    for a = 1:nA
        if a == anchorIdx, continue; end
        k = k + 1;
        plus  = sum(signs{a} == '+');
        minus = sum(signs{a} == '-');
        eq    = sum(signs{a} == '=');
        cntTxt{k} = sprintf('%d/%d/%d',plus,minus,eq);
    end

    % per-row minimum mean column (1-based)
    [~,best] = min(means,[],2);
    best = best(:)';

    % cell text
    cellsT = cell(nP,nA);
    for p = 1:nP
        for a = 1:nA
            if a == anchorIdx
                cellsT{p,a} = sprintf('%.4e (%.2e)',means(p,a),stds(p,a));
            else
                cellsT{p,a} = sprintf('%.4e (%.2e)%s',means(p,a),stds(p,a),signs{a}(p));
            end
        end
    end

    % order the display columns: baselines + HES first, PACDIS last
    order = [setdiff(1:nA,anchorIdx), anchorIdx];

    T = struct();
    T.anchor = labels{anchorIdx};
    T.labels = labels(order);
    T.counts = cntTxt;
    T.cells  = arrayfun(@(p)strjoin(cellsT(p,order),'|'),1:nP,'UniformOutput',false);
    T.best   = arrayfun(@(p)find(order==best(p)),1:nP);
    payload = struct();
    payload.M = M;
    payload.problems = {problems{:}};
    payload.Ds = Ds(:)';
    payload.tables = T;

    outJson = fullfile(logDir,'compare_hes_paper_M20.json');
    fid = fopen(outJson,'w');
    fprintf(fid,'%s',jsonencode(payload));
    fclose(fid);
    fprintf('wrote %s\n',outJson);

    % text preview (anchor = PACDIS last column)
    fprintf('\n=== M=%d  anchor = %s ===\n',M,T.anchor);
    fprintf('%-7s','Problem');
    for a = order, fprintf(' %-27s',labels{a}); end
    fprintf('\n');
    for p = 1:nP
        fprintf('%-7s',problems{p});
        for a = order
            if a == anchorIdx
                fprintf(' %-27s',sprintf('%.4e (%.2e)',means(p,a),stds(p,a)));
            else
                fprintf(' %-27s',sprintf('%.4e (%.2e)%s',means(p,a),stds(p,a),signs{a}(p)));
            end
        end
        fprintf('\n');
    end
    fprintf('%-7s','+/-/=');
    for a = 1:nA-1, fprintf(' %-27s',cntTxt{a}); end
    fprintf('\n');
end

% ------------------------------------------------------------------------
function v = runVal(alg,prob,M,run,d20)
    for dd = [30 31]
        f = fullfile(d20,alg,sprintf('%s_%s_M%d_D%d_%d.mat',alg,prob,M,dd,run));
        if isfile(f), break; end
    end
    S = load(f);
    t = S.metric.IGDp(:);
    v = t(end);
end

function s = sigText(pv, mA, mB)
    s = repmat('=',size(pv));
    for i = 1:numel(pv)
        if pv(i) < 0.05
            if mA(i) < mB(i), s(i) = '+'; else, s(i) = '-'; end
        end
    end
end
