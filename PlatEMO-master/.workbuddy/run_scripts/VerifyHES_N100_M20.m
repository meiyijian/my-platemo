function VerifyHES_N100_M20()
%VerifyHES_N100_M20  Full completeness check of the 320 stored MAT files.
%   Files: C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\HES_EA_N100
%   16 problems (DTLZ1-7, WFG1-9) x 20 runs, M=20, D=30 (WFG2/WFG3 -> D=31),
%   N=100, maxFE=300, SaveCount=30.
%   Required payload: result (30 x 2 cell) + metric with runtime, IGD AND IGDp.
%
%   Reports, per problem: the run-completeness string ('.' = valid), the IGD /
%   IGDp final means and the mean wall time, plus a global OK/BAD/IGDp-missing
%   tally.  Exits with an error if any file is missing or structurally bad, so
%   it can be used as the completion gate of the sweep.

    D   = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\HES_EA_N100';
    alg = 'HES_EA_N100';
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    expectedFE = 300;
    nOK = 0; nBad = 0; nNoIGDp = 0; badList = {};
    igdMean = nan(numel(probs),1); igdpMean = nan(numel(probs),1);
    wallMean = nan(numel(probs),1);
    for i = 1:numel(probs)
        line = ''; finals = []; finalsP = []; walls = [];
        for r = 1:20
            f = '';
            for dd = [30 31]
                cand = fullfile(D,sprintf('%s_%s_M20_D%d_%d.mat',alg,probs{i},dd,r));
                if isfile(cand), f = cand; break; end
            end
            if isempty(f)
                line = [line 'x']; nBad = nBad+1;                     %#ok<AGROW>
                badList{end+1} = sprintf('%s run %d MISSING',probs{i},r); %#ok<AGROW>
                continue;
            end
            try
                S = load(f);
                ok = isfield(S,'result') && isfield(S,'metric') && ...
                     ~isempty(S.result) && isfield(S.metric,'IGD') && ...
                     isfield(S.metric,'runtime');
                fe = cellfun(@(x)x,S.result(:,1));
                ok = ok && fe(end)==expectedFE && ...
                     numel(S.metric.IGD)==numel(fe) && all(isfinite(S.metric.IGD));
                hasP = isfield(S.metric,'IGDp') && ...
                       numel(S.metric.IGDp)==numel(fe) && all(isfinite(S.metric.IGDp));
                if ~hasP
                    nNoIGDp = nNoIGDp + 1;                            %#ok<AGROW>
                    badList{end+1} = sprintf('%s run %d NO/BAD IGDp',probs{i},r); %#ok<AGROW>
                end
                if ok
                    nOK = nOK+1; line = [line '.'];                   %#ok<AGROW>
                    finals(end+1)  = S.metric.IGD(end);              %#ok<AGROW>
                    if hasP, finalsP(end+1) = S.metric.IGDp(end); end %#ok<AGROW>
                    walls(end+1)   = S.metric.runtime(end);          %#ok<AGROW>
                else
                    nBad = nBad+1; line = [line 'X'];                %#ok<AGROW>
                    badList{end+1} = sprintf('%s run %d BAD',probs{i},r); %#ok<AGROW>
                end
                clear S
            catch err
                nBad = nBad+1; line = [line 'E'];                     %#ok<AGROW>
                badList{end+1} = sprintf('%s run %d ERROR %s',probs{i},r,err.message); %#ok<AGROW>
            end
        end
        if ~isempty(finals),  igdMean(i)  = mean(finals);  end
        if ~isempty(finalsP), igdpMean(i) = mean(finalsP); end
        walls = walls(isfinite(walls) & walls < 3600);   % drop standby-polluted runtimes
        if ~isempty(walls), wallMean(i) = mean(walls); end
        fprintf('%-6s %s  IGD %.4f | IGDp %.4f\n',probs{i},line,igdMean(i),igdpMean(i));
    end
    fprintf('=== OK=%d  BAD=%d  IGDp-missing=%d  (expected 320 / 0 / 0)\n', ...
        nOK,nBad,nNoIGDp);
    for k = 1:numel(badList), fprintf('  !! %s\n',badList{k}); end
    T = table(probs(:),igdMean,igdpMean,wallMean, ...
        'VariableNames',{'Problem','MeanFinalIGD','MeanFinalIGDp','MeanRuntime'});
    outDir = fileparts(mfilename('fullpath'));
    csv = fullfile(outDir,'summary_HES_EA_N100_M20.csv');
    writetable(T,csv);
    fprintf('Summary written: %s\n',csv);
    if nBad > 0 || nNoIGDp > 0
        error('VerifyHES_N100_M20:Incomplete', ...
            'Dataset incomplete: %d bad, %d missing IGDp.',nBad,nNoIGDp);
    end
    fprintf('=== ALL 320 FILES VALID (result + metric{runtime,IGD,IGDp}, final FE=%d)\n',expectedFE);
end
