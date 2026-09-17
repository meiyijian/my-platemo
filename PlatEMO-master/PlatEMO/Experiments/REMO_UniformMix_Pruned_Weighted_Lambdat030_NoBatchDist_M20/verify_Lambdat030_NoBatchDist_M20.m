function verify_Lambdat030_NoBatchDist_M20()
%Full integrity check of the 320 stored MAT files (no result analysis).
%   Files: D:\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
%   16 problems (DTLZ1-7, WFG1-9) x 20 runs, M=20, D=30 (WFG2/WFG3 -> D=31),
%   N=100, maxFE=300, SaveCount=30.
    D   = 'D:\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    alg = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    expectedFE = 300;
    nOK = 0; nBad = 0; badList = {};
    igdMean = nan(numel(probs),1); wallMean = nan(numel(probs),1);
    for i = 1:numel(probs)
        line = ''; finals = []; walls = [];
        for r = 1:20
            f = '';
            for dd = [30 31]
                cand = fullfile(D,sprintf('%s_%s_M20_D%d_%d.mat',alg,probs{i},dd,r));
                if isfile(cand), f = cand; break; end
            end
            if isempty(f)
                line = [line 'x']; nBad = nBad+1; badList{end+1} = sprintf('%s run %d MISSING',probs{i},r); %#ok<AGROW>
                continue;
            end
            try
                S = load(f);
                ok = isfield(S,'result') && isfield(S,'metric') && ...
                     ~isempty(S.result) && isfield(S.metric,'IGD') && isfield(S.metric,'runtime');
                fe = cellfun(@(x)x,S.result(:,1));
                ok = ok && fe(end)==expectedFE && numel(S.metric.IGD)==numel(fe) && ...
                     all(isfinite(S.metric.IGD));
                if ok
                    nOK = nOK+1; line = [line '.']; finals(end+1) = S.metric.IGD(end); %#ok<AGROW>
                    walls(end+1) = S.metric.runtime(end); %#ok<AGROW>
                else
                    nBad = nBad+1; line = [line 'X']; badList{end+1} = sprintf('%s run %d BAD',probs{i},r); %#ok<AGROW>
                end
                clear S
            catch err
                nBad = nBad+1; line = [line 'E'];
                badList{end+1} = sprintf('%s run %d ERROR %s',probs{i},r,err.message); %#ok<AGROW>
            end
        end
        if ~isempty(finals), igdMean(i) = mean(finals); end
        walls = walls(isfinite(walls) & walls < 3600);   % drop standby-polluted runtimes
        if ~isempty(walls), wallMean(i) = mean(walls); end
        fprintf('%-6s %s  final IGD mean %s\n',probs{i},line, ...
            ternary(isnan(igdMean(i)),'   n/a',sprintf('%.4f',igdMean(i))));
    end
    fprintf('=== OK=%d  BAD=%d  TOTAL=%d\n',nOK,nBad,nOK+nBad);
    for k = 1:numel(badList), fprintf('  !! %s\n',badList{k}); end
    if nBad==0
        fprintf('=== ALL 320 FILES VALID (result + metric, final FE=%d)\n',expectedFE);
    end
    T = table(probs(:),igdMean,wallMean,'VariableNames',{'Problem','MeanFinalIGD','MeanRuntime'});
    outDir = fileparts(mfilename('fullpath'));
    writetable(T,fullfile(outDir,'summary_Lambdat030_NoBatchDist_M20.csv'));
    fprintf('Summary written: %s\n',fullfile(outDir,'summary_Lambdat030_NoBatchDist_M20.csv'));
end

function out = ternary(cond,a,b)
    if cond, out = a; else, out = b; end
end
