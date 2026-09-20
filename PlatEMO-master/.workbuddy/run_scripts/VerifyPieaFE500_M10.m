function VerifyPieaFE500_M10()
%VerifyPieaFE500_M10 Integrity check of the PIEA FE500 M=10 batch.

    outDir = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\默认n\FE500\PIEA';
    probs  = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
              'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    Dexp   = [14 19 19 19 19 19 19, 14 19 19 19 19 19 19 19 19];
    seedBase = 20260912 + 10*100000;

    fprintf('== FILE COUNT ==\n');
    mats = dir(fullfile(outDir,'*.mat'));
    other = dir(outDir);
    other = other(~[other.isdir]);
    otherNames = {other.name};
    otherNames = otherNames(~endsWith(otherNames,'.mat'));
    fprintf('mat files : %d (expect 320)\n',numel(mats));
    fprintf('non-mat   : %s\n',strjoin(otherNames,', '));

    fprintf('\n== PER PROBLEM ==\n');
    nOk = 0; nBad = 0; badList = {};
    IGDmean = nan(1,numel(probs)); IGDpmean = nan(1,numel(probs));
    for p = 1:numel(probs)
        got = zeros(1,20);
        igd = nan(1,20); igdp = nan(1,20);
        problems = {};
        for r = 1:20
            f = fullfile(outDir,sprintf('PIEA_%s_M10_D%d_%d.mat',probs{p},Dexp(p),r));
            if ~isfile(f)
                problems{end+1} = sprintf('run%d missing',r); %#ok<AGROW>
                nBad = nBad + 1;
                continue;
            end
            S = load(f);
            okHere = true;
            if ~isfield(S,'metric') || ~all(isfield(S.metric,{'runtime','IGD','IGDp'}))
                problems{end+1} = sprintf('run%d metric fields',r); %#ok<AGROW>
                okHere = false;
            else
                if numel(S.metric.IGD) ~= 30 || ~all(isfinite(S.metric.IGD))
                    problems{end+1} = sprintf('run%d IGD len/nan',r); %#ok<AGROW> %#ok<AGROW>
                    okHere = false;
                end
                if numel(S.metric.IGDp) ~= 30 || ~all(isfinite(S.metric.IGDp))
                    problems{end+1} = sprintf('run%d IGDp len/nan',r); %#ok<AGROW>
                    okHere = false;
                end
                igd(r)  = S.metric.IGD(end);
                igdp(r) = S.metric.IGDp(end);
            end
            if ~isfield(S,'metadata')
                problems{end+1} = sprintf('run%d no metadata',r); %#ok<AGROW>
                okHere = false;
            else
                m = S.metadata;
                if m.seed ~= seedBase + 1000*p + r
                    problems{end+1} = sprintf('run%d seed %d',r,m.seed); %#ok<AGROW>
                    okHere = false;
                end
                if m.maxFE ~= 500 || m.D ~= Dexp(p) || m.N ~= 100 || m.M ~= 10
                    problems{end+1} = sprintf('run%d meta N/M/D/FE',r); %#ok<AGROW>
                    okHere = false;
                end
            end
            if ~isfield(S,'result') || S.result{end,1} ~= 500
                problems{end+1} = sprintf('run%d finalFE',r); %#ok<AGROW>
                okHere = false;
            end
            got(r) = 1;
            if okHere, nOk = nOk + 1; else, nBad = nBad + 1; end
        end
        IGDmean(p)  = mean(igd,'omitnan');
        IGDpmean(p) = mean(igdp,'omitnan');
        if isempty(problems)
            fprintf('  %-6s D=%2d run 1..20 ok (n=%d)\n',probs{p},Dexp(p),sum(got));
        else
            fprintf('  %-6s D=%2d PROBLEMS: %s\n',probs{p},Dexp(p),strjoin(problems,'; '));
            badList{end+1} = probs{p}; %#ok<AGROW>
        end
    end
    fprintf('\nOK=%d  BAD=%d  problems in: %s\n',nOk,nBad,strjoin(badList,','));

    fprintf('\n== MEAN FINAL METRICS (n=20) ==\n');
    for p = 1:numel(probs)
        fprintf('  %-6s D=%2d  IGD=%12.6g   IGDp=%12.6g\n', ...
            probs{p},Dexp(p),IGDmean(p),IGDpmean(p));
    end
    fprintf('\nVERIFY DONE\n');
end
