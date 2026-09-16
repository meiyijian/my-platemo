function DiagnoseRefTable()
%DiagnoseRefTable Compare the reference table against the computed IGD+ values.
%   Reads IGDp10目标.xlsx, parses every "mean (std) sign" cell, and compares it
%   with the same statistic recomputed from the stored .mat products over runs
%   1-20. Reports the relative difference of both the mean and the standard
%   deviation, which tells whether the reference table was built from the same
%   sample of runs.

    xlsFile = 'C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\IGDp10目标.xlsx';
    outRoot = 'C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_M10';
    C = readcell(xlsFile, 'Sheet', 'IGDp');
    colAlg  = {'REMO','PIEA','MCEAD','CSEA','PCSAEA_N100','KRVEA_100', ...
               'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    runs = 1:20;

    nBadMean = 0; nBadStd = 0; nCell = 0;
    fprintf('%-45s %-6s %13s %13s %8s %11s %11s %8s\n', ...
        'algorithm','prob','myMean','refMean','dMean%','myStd','refStd','dStd%');
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
            if ~isfile(f), fprintf('%-45s %-6s (product missing)\n', alg, prob); continue; end
            S = load(f);
            v = S.IGDpFinal(ismember(S.runIds, runs));
            myMean = mean(v); myStd = std(v);
            nCell = nCell + 1;
            dM = (myMean - refMean) / refMean * 100;
            dS = (myStd  - refStd ) / refStd  * 100;
            if abs(dM) > 0.05, nBadMean = nBadMean + 1; end
            if abs(dS) > 0.5,  nBadStd  = nBadStd  + 1; end
            fprintf('%-45s %-6s %13.6g %13.6g %8.3f %11.4g %11.4g %8.2f\n', ...
                alg, prob, myMean, refMean, dM, myStd, refStd, dS);
        end
    end
    fprintf('\ncells compared           : %d\n', nCell);
    fprintf('mean differs > 0.05%%    : %d\n', nBadMean);
    fprintf('std  differs > 0.5%%     : %d\n', nBadStd);
    fprintf('DIAGNOSE DONE\n');
end
