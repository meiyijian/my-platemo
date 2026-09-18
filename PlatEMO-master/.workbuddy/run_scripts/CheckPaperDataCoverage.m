function CheckPaperDataCoverage()
%CheckPaperDataCoverage Coverage of IGD and IGDp for the three objective counts
%   and the eight algorithms the paper table needs.
    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    algs = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    short = {'REMO','PIEA','MCEAD','CSEA','PC-SAEA','K-RVEA','NoBatchDist','Lambdat030'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    for M = [10 15 20]
        fprintf('\n==== M = %d ====\n', M);
        fprintf('%-12s %6s %8s %10s %8s %10s %8s\n', 'algorithm','total','hasIGD','hasIGDp','missP', 'runs', 'D');
        for a = 1:numel(algs)
            if M == 10
                d = fullfile(root, '10目标', 'n30', algs{a});
            else
                d = fullfile(root, sprintf('%d目标', M), algs{a});
            end
            if ~isfolder(d), fprintf('%-12s  (no folder)\n', short{a}); continue; end
            nT = 0; nI = 0; nP = 0; missP = {}; runset = []; Dset = [];
            for p = 1:numel(problems)
                fs = dir(fullfile(d, sprintf('%s_%s_M%d_D*_*.mat', algs{a}, problems{p}, M)));
                for i = 1:numel(fs)
                    tok = regexp(fs(i).name, sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$', M), 'tokens', 'once');
                    if isempty(tok), continue; end
                    nT = nT + 1;
                    Dset(end+1) = str2double(tok{1}); runset(end+1) = str2double(tok{2}); %#ok<AGROW>
                    S = load(fullfile(d, fs(i).name), 'metric');
                    if isfield(S.metric,'IGD'),  nI = nI + 1; end
                    if isfield(S.metric,'IGDp'), nP = nP + 1; else, missP{end+1} = problems{p}; end %#ok<AGROW>
                end
            end
            mu = unique(missP);
            fprintf('%-12s %6d %8d %10d %8d %10s %8s\n', short{a}, nT, nI, nP, nT-nP, ...
                sprintf('%d-%d', min(runset), max(runset)), ...
                strjoin(string(unique(Dset))', '/'));
            if ~isempty(mu)
                fprintf('               missing IGDp in: %s\n', strjoin(mu, ' '));
            end
        end
    end
    fprintf('\nCOVERAGE DONE\n');
end
