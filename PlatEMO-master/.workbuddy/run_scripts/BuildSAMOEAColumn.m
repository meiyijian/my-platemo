function BuildSAMOEAColumn(M)
%BuildSAMOEAColumn Emit the formatted IGDp cell text of one extra baseline.
%   Conventions match the rest of the paper's main table exactly:
%     - mean and standard deviation over runs 1-20;
%     - cell text '%.4e (%.2e)' with 'e-0' folded to 'e-' and 'e+0' to 'e+';
%     - the +/-/= symbol comes from a Wilcoxon rank sum test of this baseline
%       against the LAST column of the table, which is the NoBatchDist anchor,
%       with the threshold 0.05; '+' means this baseline is better, '-' worse,
%       '=' not significantly different;
%     - the per-row minimum is reported so the spreadsheet builder can colour.
%   Writes one CSV next to the run scripts, never into the dataset folder.

    if nargin < 1 || isempty(M), M = 10; end
    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    if M == 10
        root = fullfile(testRoot,'10目标','n30');
    else
        root = fullfile(testRoot,sprintf('%d目标',M));
    end
    anchor = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    newAlg = 'SAMOEATL2M_N100';
    runs   = 1:20;
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    outBase = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\run_scripts';
    csvFile = fullfile(outBase,sprintf('samoea_column_M%d.csv',M));

    nP = numel(problems);
    txt = cell(nP,1); signs = cell(nP,1);
    meansNew = nan(nP,1); stdsNew = nan(nP,1);
    meansAnchor = nan(nP,1);
    for p = 1:nP
        prob = problems{p};
        [vn, rn] = readRuns(root,newAlg,prob,M);
        [va, ~ ] = readRuns(root,anchor,prob,M);
        vn = vn(ismember(rn,runs)); va = va(ismember(rn,runs));
        assert(numel(vn) == numel(runs), '%s %s has %d runs', newAlg, prob, numel(vn));
        assert(numel(va) == numel(runs), '%s %s has %d runs', anchor, prob, numel(va));
        meansNew(p)    = mean(vn);
        stdsNew(p)     = std(vn);
        meansAnchor(p) = mean(va);
        pv = ranksum(vn, va);          % MATLAB ranksum, same as the other columns
        if pv >= 0.05 || meansNew(p) == meansAnchor(p)
            s = '=';
        elseif meansNew(p) < meansAnchor(p)   % IGD+ is min-is-better
            s = '+';
        else
            s = '-';
        end
        signs{p} = s;
        t = sprintf('%.4e (%.2e)',meansNew(p),stdsNew(p));
        t = strrep(strrep(t,'e-0','e-'),'e+0','e+');
        txt{p} = t;
    end

    fid = fopen(csvFile,'w','n','UTF-8');
    assert(fid >= 0,'Cannot write %s',csvFile);
    fprintf(fid,'Problem,mean,std,symbol,txt\n');
    for p = 1:nP
        fprintf(fid,'%s,%.10e,%.10e,%s,%s\n',problems{p},meansNew(p),stdsNew(p), ...
            signs{p},txt{p});
    end
    fclose(fid);

    fprintf('\n=== M = %d, extra baseline %s, anchor %s (runs 1-20) ===\n',M,newAlg,anchor);
    fprintf('%-7s %-24s %-24s %s\n','Problem',newAlg,anchor,'sym');
    np = 0; nm = 0; ne = 0;
    for p = 1:nP
        fprintf('%-7s %-24s %-24s %s\n',problems{p},txt{p}, ...
            sprintf('%.4e',meansAnchor(p)),signs{p});
        switch signs{p}
            case '+', np = np + 1;
            case '-', nm = nm + 1;
            otherwise, ne = ne + 1;
        end
    end
    fprintf('+/-/= : %d/%d/%d\n',np,nm,ne);
    fprintf('wrote %s\n',csvFile);
end

function [v, rid] = readRuns(root, alg, prob, M)
%readRuns Final IGDp of every stored run of one algorithm and problem.
    d = dir(fullfile(root, alg, sprintf('%s_%s_M%d_D*_*.mat', alg, prob, M)));
    assert(~isempty(d), 'No files for %s %s', alg, prob);
    v = nan(numel(d),1); rid = nan(numel(d),1);
    for i = 1:numel(d)
        tok = regexp(d(i).name, sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$', M), 'tokens', 'once');
        rid(i) = str2double(tok{2});
        S = load(fullfile(root, alg, d(i).name), 'metric');
        assert(isfield(S.metric,'IGDp'), '%s %s missing IGDp: %s', alg, prob, d(i).name);
        v(i) = S.metric.IGDp(end);
    end
end
