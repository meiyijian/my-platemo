function CompareExtra_Paper(M, extraLabel)
%CompareExtra_Paper  One extra baseline vs the paper's 7 algorithms at one M.
%
%   CompareExtra_Paper(20,'SSDE')
%   CompareExtra_Paper(15,'SSDE')
%   CompareExtra_Paper(10,'SSDE')
%
%   Columns: the six paper baselines (REMO, PIEA, CSEA, PCSAEA_N100, KRVEA_100,
%   MCEAD), the extra algorithm, and PACDIS
%   (= REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist) last as the
%   anchor.  IGD+ taken from metric.IGDp(end), runs 1..20 (the paper's rule for
%   all three objective counts).  Each baseline carries a Wilcoxon rank-sum
%   verdict against PACDIS: '+' significantly better (lower IGD+),
%   '-' significantly worse, '=' no detected difference.
%   Writes <workbuddy>\ablation_logs\compare_<extraLabel>_M<M>.json for the xlsx
%   builder.

    if nargin < 1 || isempty(M),          M = 20; end
    if nargin < 2 || isempty(extraLabel), extraLabel = 'SSDE'; end

    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    logDir   = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    if ~isfolder(logDir), mkdir(logDir); end

    % folder layout differs at M=10 (nested n30)
    if M == 10
        sub = fullfile('10目标','n30');
    else
        sub = sprintf('%d目标',M);
    end
    dirOf = @(name) fullfile(testRoot,sub,name);

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    runs = 1:20;
    anchorName = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    arms = { ...
        'REMO',        'REMO',        0; ...
        'PIEA',        'PIEA',        0; ...
        'CSEA',        'CSEA',        0; ...
        'PCSAEA_N100', 'PCSAEA_N100', 0; ...
        'KRVEA_100',   'KRVEA_100',   0; ...
        'MCEAD',       'MCEAD',       0; ...
        extraLabel,    extraLabel,    0; ...
        'PACDIS',      anchorName,    1};
    labels = arms(:,1)';
    nA = numel(labels); nP = numel(problems);
    anchorIdx = find(cell2mat(arms(:,3)),1);

    % ---- read IGDp(end) for every cell, cache once -------------------------
    vals = nan(nP,nA,numel(runs));
    Ds   = nan(1,nP);
    for p = 1:nP
        for a = 1:nA
            d = dirOf(arms{a,2});
            for ri = 1:numel(runs)
                f = ''; Drow = NaN;
                for dd = [30 31]
                    cand = fullfile(d,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                        arms{a,2},problems{p},M,dd,runs(ri)));
                    if isfile(cand), f = cand; Drow = dd; break; end
                end
                if isempty(f)
                    error('CompareExtra_Paper:Missing','missing %s %s run%d (M=%d)', ...
                        arms{a,1},problems{p},runs(ri),M);
                end
                S = load(f,'metric');
                if ~isfield(S.metric,'IGDp')
                    error('CompareExtra_Paper:NoIGDp','%s has no IGDp',f);
                end
                v = S.metric.IGDp(:);
                vals(p,a,ri) = v(end);
                Ds(p) = Drow;
            end
        end
    end

    means = mean(vals,3);
    stds  = std(vals,0,3);

    % ---- rank-sum verdict of every baseline vs the anchor -----------------
    signs = cell(1,nA); signs{anchorIdx} = '';
    for a = 1:nA
        if a == anchorIdx, continue; end
        for p = 1:nP
            A = squeeze(vals(p,a,:)); B = squeeze(vals(p,anchorIdx,:));
            pv = ranksum(A,B);
            if pv < 0.05
                if means(p,a) < means(p,anchorIdx), signs{a}(p) = '+';
                else,                                signs{a}(p) = '-';
                end
            else
                signs{a}(p) = '=';
            end
        end
    end

    cntTxt = cell(1,nA-1); k = 0;
    for a = 1:nA
        if a == anchorIdx, continue; end
        k = k + 1;
        cntTxt{k} = sprintf('%d/%d/%d',sum(signs{a}=='+'),sum(signs{a}=='-'),sum(signs{a}=='='));
    end

    [~,best] = min(means,[],2); best = best(:)';
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
    order = [setdiff(1:nA,anchorIdx), anchorIdx];

    T = struct();
    T.anchor = labels{anchorIdx};
    T.labels = labels(order);
    T.counts = cntTxt;
    T.cells  = arrayfun(@(p)strjoin(cellsT(p,order),'|'),1:nP,'UniformOutput',false);
    T.best   = arrayfun(@(p)find(order==best(p)),1:nP);
    payload = struct('M',M,'problems',{problems},'Ds',Ds(:)', ...
        'extra',extraLabel,'tables',T);

    outJson = fullfile(logDir,sprintf('compare_%s_M%d.json',extraLabel,M));
    fid = fopen(outJson,'w'); fprintf(fid,'%s',jsonencode(payload)); fclose(fid);

    fprintf('wrote %s\n\n=== M=%d  extra=%s  anchor=%s ===\n',outJson,M,extraLabel,T.anchor);
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
