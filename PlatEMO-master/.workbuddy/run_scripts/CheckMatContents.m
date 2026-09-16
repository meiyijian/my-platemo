function CheckMatContents()
%CheckMatContents List the variables stored in one IGD+ result file.
    f = 'C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_M10\REMO_UniformMix_Pruned_Weighted_Lambdat030\DTLZ2_IGDp_M10.mat';
    w = whos('-file', f);
    fprintf('FILE: %s\n', f);
    for i = 1:numel(w)
        fprintf('  %-12s %-10s size=%s  bytes=%d\n', w(i).name, w(i).class, mat2str(w(i).size), w(i).bytes);
    end
    S = load(f);
    fprintf('\nrunIds        = %s\n', mat2str(S.runIds'));
    fprintf('IGDpCell      = %d runs, sizes: %s\n', numel(S.IGDpCell), mat2str(cellfun(@numel, S.IGDpCell)));
    fprintf('FECell        = %d runs, sizes: %s\n', numel(S.FECell), mat2str(cellfun(@numel, S.FECell)));
    fprintf('IGDpFinal     = %s\n', mat2str(S.IGDpFinal', 5));
    fprintf('IGDpCell{1}   = %s\n', mat2str(S.IGDpCell{1}, 5));
    fprintf('FECell{1}     = %s\n', mat2str(S.FECell{1}));
    disp(S.meta);
    fprintf('CHECK DONE\n');
end
