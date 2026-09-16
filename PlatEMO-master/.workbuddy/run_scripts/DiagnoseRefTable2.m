function DiagnoseRefTable2()
%DiagnoseRefTable2 Test whether the reference table took the last snapshot with
%   FE <= 300 instead of the very last snapshot. Some runs overshoot the budget
%   (REMO ends at 303-310), so the two readings differ. The stored products keep
%   both the FE axis and the IGD+ trace, so both readings can be reconstructed
%   without recomputing anything.

    xlsFile = 'C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\IGDp10目标.xlsx';
    outRoot = 'C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_M10';
    C = readcell(xlsFile, 'Sheet', 'IGDp');
    colAlg  = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100', ...
               'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    runs = 1:20;

    sumA = 0; sumB = 0; n = 0;
    fprintf('%-45s %-6s %12s %12s %12s %9s %9s\n', ...
        'algorithm','prob','refMean','meanA_last','meanB_FE300','dA%','dB%');
    for a = 1:numel(colAlg)
        alg = colAlg{a};
        for r = 2:17
            prob = C{r, 1};
            txt  = C{r, 3 + a};
            if ~ischar(txt), continue; end
            tok = regexp(txt, '([\d.eE+-]+)\s*\(', 'tokens', 'once');
            if isempty(tok), continue; end
            refMean = str2double(tok{1});
            f = fullfile(outRoot, alg, sprintf('%s_IGDp_M10.mat', prob));
            if ~isfile(f), continue; end
            S = load(f);
            sel = ismember(S.runIds, runs);
            idxSel = find(sel);
            vA = nan(numel(idxSel), 1); vB = vA;
            for k = 1:numel(idxSel)
                gp = S.IGDpCell{idxSel(k)}; fe = S.FECell{idxSel(k)};
                vA(k) = gp(end);
                j = find(fe <= 300, 1, 'last');
                if isempty(j), j = 1; end
                vB(k) = gp(j);
            end
            mA = mean(vA); mB = mean(vB);
            dA = (mA - refMean) / refMean * 100;
            dB = (mB - refMean) / refMean * 100;
            sumA = sumA + abs(dA); sumB = sumB + abs(dB); n = n + 1;
            fprintf('%-45s %-6s %12.6g %12.6g %12.6g %9.3f %9.3f\n', ...
                alg, prob, refMean, mA, mB, dA, dB);
        end
    end
    fprintf('\ncells            : %d\n', n);
    fprintf('mean |dA| last   : %.4f %%\n', sumA / n);
    fprintf('mean |dB| FE<=300: %.4f %%\n', sumB / n);
    fprintf('DIAGNOSE2 DONE\n');
end
