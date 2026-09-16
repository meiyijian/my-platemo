function DiagnoseRuns18()
%DiagnoseRuns18 Test the hypothesis that the reference table was built while the
%   six baselines still held only runs 1-18, before runs 19 and 20 were added on
%   September 16. Compares the mean and standard deviation of runs 1-18 against
%   the numbers printed in IGDp10目标.xlsx.

    xlsFile = 'C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\IGDp10目标.xlsx';
    outRoot = 'C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_M10';
    C = readcell(xlsFile, 'Sheet', 'IGDp');
    colAlg  = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100', ...
               'REMO_UniformMix_Pruned_Weighted_Lambdat030'};

    for nR = [18 20]
        runs = 1:nR;
        sumM = 0; sumS = 0; n = 0; nExact = 0;
        for a = 1:numel(colAlg)
            alg = colAlg{a};
            for r = 2:17
                prob = C{r, 1};
                txt  = C{r, 3 + a};
                if ~ischar(txt), continue; end
                tok = regexp(txt, '([\d.eE+-]+)\s*\(([\d.eE+-]+)\)', 'tokens', 'once');
                if isempty(tok), continue; end
                refMean = str2double(tok{1}); refStd = str2double(tok{2});
                f = fullfile(outRoot, alg, sprintf('%s_IGDp_M10.mat', prob));
                if ~isfile(f), continue; end
                S = load(f);
                sel = ismember(S.runIds, runs);
                if ~any(sel), continue; end
                v = S.IGDpFinal(sel);
                dM = abs(mean(v) - refMean) / refMean * 100;
                dS = abs(std(v)  - refStd ) / refStd  * 100;
                sumM = sumM + dM; sumS = sumS + dS; n = n + 1;
                if dM < 0.005 && dS < 0.5, nExact = nExact + 1; end
            end
        end
        fprintf('runs 1-%-2d : cells %3d | mean |dMean| %.4f %% | mean |dStd| %.4f %% | exact matches %d\n', ...
            nR, n, sumM/n, sumS/n, nExact);
    end

    % Detail for runs 1-18 on a few cells
    runs = 1:18;
    fprintf('\n%-10s %-6s %13s %13s %8s %11s %11s %8s\n', ...
        'algorithm','prob','myMean(1-18)','refMean','dMean%','myStd(1-18)','refStd','dStd%');
    for a = 1:6
        alg = colAlg{a};
        for r = 2:17
            prob = C{r, 1};
            txt  = C{r, 3 + a};
            tok = regexp(txt, '([\d.eE+-]+)\s*\(([\d.eE+-]+)\)', 'tokens', 'once');
            if isempty(tok), continue; end
            S = load(fullfile(outRoot, alg, sprintf('%s_IGDp_M10.mat', prob)));
            v = S.IGDpFinal(ismember(S.runIds, runs));
            fprintf('%-10s %-6s %13.6g %13.6g %8.3f %11.4g %11.4g %8.2f\n', ...
                alg, prob, mean(v), str2double(tok{1}), ...
                (mean(v)-str2double(tok{1}))/str2double(tok{1})*100, ...
                std(v), str2double(tok{2}), ...
                (std(v)-str2double(tok{2}))/str2double(tok{2})*100);
        end
    end
    fprintf('DIAGNOSE18 DONE\n');
end
