function build_FE500_M20_table(runs)
%BUILD_FE500_M20_TABLE Stage-5 comparison table for the FE500 sweep.
%
%   build_FE500_M20_table()        -> runs 1..20
%   build_FE500_M20_table(1:10)    -> only the first ten runs
%
%   For every algorithm of fe500_m20_registry it reads the FINAL snapshot of
%   metric.IGD and of metric.IGDp from every stored run of every problem and
%   writes, next to this file:
%
%     FE500_M20_IGD.csv      mean,std,sign      (last-snapshot IGD)
%     FE500_M20_IGDp.csv     mean,std,sign      (last-snapshot IGD+)
%     FE500_M20_<metric>.md  a Markdown table ready to paste into a note
%
%   Convention (identical to every other table in this project):
%     value cell  sprintf('%.4e (%.2e)') with the exponents folded
%                 e+0 -> e+ and e-0 -> e-
%     symbol      MATLAB ranksum against the ANCHOR column, p < 0.05,
%                 direction taken from the means; IGD / IGD+ are min-is-better
%                 so '+' = significantly better than the anchor,
%                 '-' = significantly worse, '=' = no significant difference
%     anchor      PACDIS, placed last, carries no symbol
%
%   It prints the +/-/= tally per algorithm and the per-problem winner.
%   No xlsx is produced: the paper tables live on the workstation machine.

    if nargin < 1 || isempty(runs), runs = 1:20; end
    runs = round(double(runs(:)'));
    anchorKey = 'PACDIS';

    root = 'D:\REMOandDREMO测试集\20目标\FE500';
    envRoot = getenv('FE500_M20_OUTPUT_ROOT');
    if ~isempty(envRoot), root = envRoot; end

    reg = fe500_m20_registry();
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    nA = numel(reg); nP = numel(probs); nR = numel(runs);

    raw = nan(nP,nA,2);          % (:,:,1) = IGD, (:,:,2) = IGDp
    for a = 1:nA
        D = fullfile(root,reg(a).folder);
        for i = 1:nP
            v = nan(nR,2); c = 0;
            for r = runs
                f = '';
                for dd = [30 31]
                    cand = fullfile(D,sprintf('%s_%s_M20_D%d_%d.mat',reg(a).cls,probs{i},dd,r));
                    if isfile(cand), f = cand; break; end
                end
                if isempty(f), continue; end
                S = load(f,'metric');
                c = c + 1;
                v(c,1) = S.metric.IGD(end);
                if isfield(S.metric,'IGDp'), v(c,2) = S.metric.IGDp(end); end
            end
            if c > 0
                raw(i,a,1) = nanmean(v(1:c,1));
                raw(i,a,2) = nanmean(v(1:c,2));
            end
        end
    end

    aIdx = find(strcmp({reg.key},anchorKey),1);
    assert(~isempty(aIdx),'unknown anchor %s',anchorKey);

    for metric = 1:2
        if metric == 1, mname = 'IGD'; else, mname = 'IGDp'; end
        M = raw(:,:,metric);
        S_ = nan(nP,nA); T_ = nan(nP,nA); sg = repmat({''},nP,nA);
        for i = 1:nP
            aV = nan(nR,1); c = 0;
            % re-read the vectors for the rank-sum test (means are not enough)
            for a = 1:nA
                v = localRuns(root,reg(a),probs{i},runs,metric);
                if a == aIdx, aV = v; end
                S_(i,a) = std(v,'omitnan');
                T_(i,a) = mean(v,'omitnan');
            end
            for a = 1:nA
                if a == aIdx, continue; end
                v = localRuns(root,reg(a),probs{i},runs,metric);
                if numel(v) < 3 || numel(aV) < 3, sg{i,a} = ' '; continue; end
                p = ranksum(v,aV);
                if p >= 0.05 || mean(v)==mean(aV), s = '=';
                elseif mean(v) < mean(aV), s = '+';
                else, s = '-';
                end
                sg{i,a} = s;
            end
        end

        order = [setdiff(1:nA,aIdx), aIdx];      % anchor last
        hdr = 'Problem'; for a = order, hdr = [hdr '|' reg(a).key]; end %#ok<AGROW>
        bar = '---';     for a = order, bar = [bar '|---']; end %#ok<AGROW>
        lines = {hdr, bar};
        cnt = zeros(nA,3); win = zeros(nA,1);
        for i = 1:nP
            row = probs{i};
            best = min(T_(i,:));
            for a = order
                cellTxt = sprintf('%.4e (%.2e)',T_(i,a),S_(i,a));
                cellTxt = strrep(cellTxt,'e+0','e+'); cellTxt = strrep(cellTxt,'e-0','e-');
                if a ~= aIdx && ~isempty(sg{i,a}) && sg{i,a} ~= ' '
                    cellTxt = [cellTxt ' ' sg{i,a}]; %#ok<AGROW>
                    k = find('+-=' == sg{i,a});
                    cnt(a,k) = cnt(a,k) + 1;
                end
                if T_(i,a) == best, win(a) = win(a) + 1; end
                row = [row '|' cellTxt]; %#ok<AGROW>
            end
            lines{end+1} = row; %#ok<AGROW>
        end

        csv = fullfile(fileparts(mfilename('fullpath')),sprintf('FE500_M20_%s.csv',mname));
        fid = fopen(csv,'w');
        fprintf(fid,'Problem,%s\n',strjoin({reg(order).key},','));
        for i = 1:nP
            fprintf(fid,'%s',probs{i});
            for a = order
                fprintf(fid,',%.10g,%.10g,%s',T_(i,a),S_(i,a),sg{i,a});
            end
            fprintf(fid,'\n');
        end
        fclose(fid);

        md = fullfile(fileparts(mfilename('fullpath')),sprintf('FE500_M20_%s.md',mname));
        fid = fopen(md,'w');
        fprintf(fid,'# FE500 / M=20 / D=30 - final %s (runs %s)\n\n',mname,mat2str(runs));
        fprintf(fid,'anchor = %s (last column, no symbol); +/-/= from MATLAB ranksum p<0.05.\n\n',anchorKey);
        for k = 1:numel(lines), fprintf(fid,'%s\n',lines{k}); end
        fprintf(fid,'\n## tally vs %s\n\n| alg | + | - | = | rows won |\n|---|---|---|---|---|\n',anchorKey);
        for a = order
            if a == aIdx, continue; end
            fprintf(fid,'| %s | %d | %d | %d | %d |\n',reg(a).key,cnt(a,1),cnt(a,2),cnt(a,3),win(a));
        end
        fclose(fid);

        fprintf('\n===== final %s (runs %s), anchor %s =====\n',mname,mat2str(runs),anchorKey);
        for k = 1:numel(lines), fprintf('%s\n',lines{k}); end
        fprintf('\ntally vs %s (+ better / - worse / = ns):\n',anchorKey);
        for a = order
            if a == aIdx, continue; end
            fprintf('  %-7s %2d/%2d/%2d   rows won %d\n',reg(a).key,cnt(a,1),cnt(a,2),cnt(a,3),win(a));
        end
        fprintf('written: %s\nwritten: %s\n',csv,md);
    end
end

function v = localRuns(root,R,prob,runs,metric)
%localRuns Final-snapshot values of one metric for every stored run.
    v = nan(numel(runs),1); c = 0;
    for r = runs
        f = '';
        for dd = [30 31]
            cand = fullfile(root,R.folder,sprintf('%s_%s_M20_D%d_%d.mat',R.cls,prob,dd,r));
            if isfile(cand), f = cand; break; end
        end
        if isempty(f), continue; end
        S = load(f,'metric');
        c = c + 1;
        if metric == 1
            v(c) = S.metric.IGD(end);
        else
            if isfield(S.metric,'IGDp'), v(c) = S.metric.IGDp(end); end
        end
    end
    v = v(1:c);
end
