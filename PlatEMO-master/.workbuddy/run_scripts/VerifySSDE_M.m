function VerifySSDE_M(M)
%VerifySSDE_M  Completeness check of one SSDE dataset (M = 15 or 20).
%   VerifySSDE_M(20)   -> C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\SSDE
%   VerifySSDE_M(15)   -> C:\Users\lsx\Desktop\REMOandDREMO测试集\15目标\SSDE
%
%   Checks 16 problems x runs 1..20, and per file: result (n x 2 cell),
%   metric with runtime, IGD and IGDp of matching length, all finite, and a
%   final FE >= 300 (SSDE evaluates in batches and overshoots maxFE, so the
%   final FE is reported as a range instead of being compared to 300).
%   Errors if anything is missing or structurally broken.

    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    D    = fullfile(root,sprintf('%d目标',M),'SSDE');
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    runs = 1:20;
    nOK = 0; nBad = 0; nNoIGDp = 0; badList = {}; feMin = inf; feMax = 0;
    for i = 1:numel(probs)
        line = '';
        for r = runs
            f = '';
            for dd = [30 31]
                cand = fullfile(D,sprintf('SSDE_%s_M%d_D%d_%d.mat',probs{i},M,dd,r));
                if isfile(cand), f = cand; break; end
            end
            if isempty(f)
                line = [line 'x']; nBad = nBad+1;                          %#ok<AGROW>
                badList{end+1} = sprintf('%s run %d MISSING',probs{i},r);   %#ok<AGROW>
                continue;
            end
            try
                S  = load(f);
                fe = cellfun(@(x)x,S.result(:,1));
                ok = isfield(S,'result') && isfield(S,'metric') && ~isempty(S.result) && ...
                     isfield(S.metric,'IGD') && isfield(S.metric,'runtime') && ...
                     numel(S.metric.IGD)==numel(fe) && all(isfinite(S.metric.IGD)) && ...
                     fe(end) >= 300 && fe(1) == 100;
                hasP = isfield(S.metric,'IGDp') && ...
                       numel(S.metric.IGDp)==numel(fe) && all(isfinite(S.metric.IGDp));
                if ~hasP
                    nNoIGDp = nNoIGDp+1;                                   %#ok<AGROW>
                    badList{end+1} = sprintf('%s run %d NO/BAD IGDp',probs{i},r); %#ok<AGROW>
                end
                if ok
                    nOK = nOK+1; line = [line '.'];                        %#ok<AGROW>
                    feMin = min(feMin,fe(end)); feMax = max(feMax,fe(end));
                else
                    nBad = nBad+1; line = [line 'X'];                      %#ok<AGROW>
                    badList{end+1} = sprintf('%s run %d BAD (FE %g..%g, snaps %d)', ...
                        probs{i},r,fe(1),fe(end),numel(fe));               %#ok<AGROW>
                end
                clear S
            catch err
                nBad = nBad+1; line = [line 'E'];                          %#ok<AGROW>
                badList{end+1} = sprintf('%s run %d ERROR %s',probs{i},r,err.message); %#ok<AGROW>
            end
        end
        fprintf('%-6s %s\n',probs{i},line);
    end
    nfiles = numel(dir(fullfile(D,'*.mat')));
    fprintf('=== SSDE M=%d : OK=%d BAD=%d IGDp-missing=%d  (expect 320/0/0)\n', ...
        M,nOK,nBad,nNoIGDp);
    fprintf('    files in folder = %d (expect 320), final FE range %g..%g\n', nfiles,feMin,feMax);
    for k = 1:numel(badList), fprintf('  !! %s\n',badList{k}); end
    if nBad>0 || nNoIGDp>0 || nfiles~=320
        error('VerifySSDE_M:Incomplete','SSDE M=%d incomplete.',M);
    end
    fprintf('=== ALL 320 FILES VALID (result + metric{runtime,IGD,IGDp}, FE 100 -> >=300)\n');
end
