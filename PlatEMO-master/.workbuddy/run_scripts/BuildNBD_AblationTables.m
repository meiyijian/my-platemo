function BuildNBD_AblationTables(M)
%BuildNBD_AblationTables  Extract the IGD+ ablation table for one objective count
%   and emit the raw cell texts as JSON.
%
%   BuildNBD_AblationTables(M)  with M = 10 or 20.
%
%   Four arms, runs 1-20, IGD+ of the last snapshot:
%     REMO (k=k_eff)   the RMEO reference at the same reference-solution count
%     full             REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
%     w/o CDIS         REMO_noBatchDict_noCDIS
%     w/o PAQC         REMO_noBatchDict_noPAQC
%
%   Two tables are produced, differing only in which arm anchors the signs:
%     table 1  anchor = REMO (k=k_eff)
%     table 2  anchor = full
%   Sign convention (same as the existing ablation tables): two-sided Wilcoxon
%   rank-sum test at alpha = 0.05; '+' the row arm is significantly better
%   (smaller IGD+) than the anchor, '-' significantly worse, '=' otherwise.
%   The anchor arm itself carries no sign.
%
%   Cell text: '%.4e (%.2e)' with 'e-0' folded to 'e-' and 'e+0' to 'e+'.
%   JSON target: .workbuddy\ablation_logs\nobatchdict_tables_M<M>.json

    if nargin < 1 || isempty(M), M = 10; end
    assert(ismember(M,[10,20]),'M must be 10 or 20.');

    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    outDir   = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    if ~isfolder(outDir), mkdir(outDir); end

    if M == 10
        sub = fullfile('10目标','n30');
    else
        sub = sprintf('%d目标',M);
    end
    kEff = min(100,max(6,ceil(1.5*M)));
    arms = { ...
        sprintf('REMO (k=%d)',kEff), fullfile(testRoot,sub,'REMO_k15'); ...
        'full',                     fullfile(testRoot,sub,'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'); ...
        'w/o CDIS',                 fullfile(testRoot,sub,'REMO_noBatchDict_noCDIS'); ...
        'w/o PAQC',                 fullfile(testRoot,sub,'REMO_noBatchDict_noPAQC')};
    if M == 20
        arms{1,2} = fullfile(testRoot,sub,'REMO_k');
    end

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    runs = 1:20;
    labels = arms(:,1)';
    nA = size(arms,1); nP = numel(problems);

    t0 = tic;
    vals  = cell(nP,nA);
    means = nan(nP,nA);
    stds  = nan(nP,nA);
    Ds    = nan(nP,1);
    for p = 1:nP
        prob = problems{p};
        for a = 1:nA
            d = dir(fullfile(arms{a,2},sprintf('*_%s_M%d_D*_*.mat',prob,M)));
            v = nan(numel(runs),1); rid = nan(numel(runs),1);
            for i = 1:numel(d)
                tok = regexp(d(i).name,sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$',M),'tokens','once');
                if isempty(tok), continue; end
                r = str2double(tok{2});
                if ~ismember(r,runs), continue; end
                S = load(fullfile(arms{a,2},d(i).name),'metric');
                assert(isfield(S.metric,'IGDp'),'%s %s run %d has no IGDp',labels{a},prob,r);
                v(r) = S.metric.IGDp(end);
                rid(r) = r;
                if a == 1, Ds(p) = str2double(tok{1}); end
            end
            assert(all(isfinite(v)),'%s %s : %d runs found, expected %d', ...
                labels{a},prob,sum(isfinite(v)),numel(runs));
            vals{p,a} = v(:);
            means(p,a) = mean(v);
            stds(p,a)  = std(v);
        end
    end

    tables = repmat(struct('anchor','','labels',{{}},'counts',{{}}, ...
        'cells',{{}},'best',[]),1,2);
    for t = 1:2
        if t == 1, anchorIdx = 1; else, anchorIdx = 2; end
        order = [setdiff(1:nA,anchorIdx,'stable') anchorIdx];  % anchor last
        cellsT = cell(nP,nA);
        counts = zeros(nA-1,3);
        best   = zeros(nP,1);
        for p = 1:nP
            vA = vals{p,anchorIdx};
            for pos = 1:nA
                a = order(pos);
                txt = sprintf('%.4e (%.2e)',means(p,a),stds(p,a));
                txt = strrep(strrep(txt,'e-0','e-'),'e+0','e+');
                if a ~= anchorIdx
                    pv = ranksum(vals{p,a},vA);
                    if pv >= 0.05
                        s = '=';
                    elseif means(p,a) < means(p,anchorIdx)
                        s = '+';
                    else
                        s = '-';
                    end
                    txt = [txt ' ' s];                            %#ok<AGROW>
                    switch s
                        case '+', counts(pos,1) = counts(pos,1) + 1;
                        case '-', counts(pos,2) = counts(pos,2) + 1;
                        otherwise, counts(pos,3) = counts(pos,3) + 1;
                    end
                end
                cellsT{p,pos} = txt;
            end
            [~,bi] = min(means(p,order));      % index inside the displayed order
            best(p) = bi;
        end
        cntTxt = arrayfun(@(i)sprintf('%d/%d/%d',counts(i,1),counts(i,2),counts(i,3)), ...
            1:size(counts,1),'UniformOutput',false);
        T = struct();
        T.anchor = labels{anchorIdx};
        T.labels = labels(order);
        T.counts = cntTxt;
        % jsonencode flattens a 2-D cell array column-major, so the row of
        % cells is joined into one string per problem with a '|' separator.
        % No cell text ever contains '|'.
        T.cells  = arrayfun(@(p)strjoin(cellsT(p,:),'|'),1:nP,'UniformOutput',false);
        T.best   = best(:)';
        tables(t) = T;
    end

    for t = 1:2
        nA = numel(tables(t).labels);
        rowCells = cellfun(@(s)strsplit(s,'|'),tables(t).cells,'UniformOutput',false);
        fprintf('\n=== M=%d  anchor = %s ===\n',M,tables(t).anchor);
        fprintf('%-7s','Problem');
        for pos = 1:nA, fprintf(' %-27s',tables(t).labels{pos}); end
        fprintf('\n');
        for p = 1:nP
            fprintf('%-7s',problems{p});
            for pos = 1:nA, fprintf(' %-27s',rowCells{p}{pos}); end
            fprintf('\n');
        end
        fprintf('%-7s','+/-/=');
        for pos = 1:nA-1, fprintf(' %-27s',tables(t).counts{pos}); end
        fprintf('\n');
    end

    payload = struct();
    payload.M          = M;
    payload.N          = 100;
    payload.FE         = 300;
    payload.metric     = 'IGDp';
    payload.runs       = mat2str(runs);
    payload.problems   = problems;
    payload.Ds         = Ds(:)';
    payload.tables     = tables;
    payload.sourceDirs = arms(:,2)';
    jsonFile = fullfile(outDir,sprintf('nobatchdict_tables_M%d.json',M));
    fid = fopen(jsonFile,'w');
    fwrite(fid,jsonencode(payload,PrettyPrint=true),'char');
    fclose(fid);
    fprintf('\nwrote %s  (%.1f s)\n',jsonFile,toc(t0));
end
