function enc_test()
%ENC_TEST Probe how this MATLAB reads non-ASCII literals in .m files.
    outDir = 'D:\PlatEMO-master\tmp';
    if ~isfolder(outDir), mkdir(outDir); end
    outFile = fullfile(outDir,'enc_out.txt');
    s = 'D:\REMOandDREMO测试集\10目标\n30';
    fid = fopen(outFile,'w','n','UTF-8');
    fprintf(fid,'DefaultCharacterSet: %s\n',feature('DefaultCharacterSet'));
    fprintf(fid,'literal: %s\n',s);
    fprintf(fid,'codepoints: %s\n',mat2str(double(s)));
    fprintf(fid,'exists: %d\n',isfolder(s));
    fclose(fid);
end
