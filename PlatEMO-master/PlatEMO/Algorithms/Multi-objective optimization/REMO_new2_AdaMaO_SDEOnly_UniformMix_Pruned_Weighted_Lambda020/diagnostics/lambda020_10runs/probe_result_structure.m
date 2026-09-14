function probe_result_structure()
%probe_result_structure Report how the stored result cell is organised.
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    verifyFile = fullfile(root,'diagnostics','lambda020_10runs','verify0', ...
        'verify0_DTLZ2_run19.mat');
    controlFile = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30/' ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'], ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_DTLZ2_M10_D30_19.mat');
    logFile = fullfile(root,'diagnostics','lambda020_10runs','result_structure.txt');
    fid = fopen(logFile,'w','n','UTF-8');
    cleanup = onCleanup(@()fclose(fid));
    names = {'lambda0=0',verifyFile;'control',controlFile};
    for i = 1:2
        S = load(names{i,2},'result');
        fprintf(fid,'--- %s ---\n',names{i,1});
        fprintf(fid,'cell size: %s\n',mat2str(size(S.result)));
        for k = [1 2 3]
            p = S.result{k,2};
            fprintf(fid,'  snapshot %d: FE=%s class=%s size=%s\n', ...
                k,mat2str(S.result{k,1}),class(p),mat2str(size(p)));
            if iscell(p)
                fprintf(fid,'    cell{1} class=%s size=%s\n', ...
                    class(p{1}),mat2str(size(p{1})));
            else
                fprintf(fid,'    fields=%s\n', ...
                    strjoin(fieldnames(p),','));
            end
        end
    end
    fprintf('Log written: %s\n',logFile);
end
