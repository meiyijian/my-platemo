function compare_first_snapshot()
%compare_first_snapshot Locate the first snapshot where two runs already differ.
%   If the initial design snapshot differs, the two runs diverged before any
%   candidate selection happened. If it matches and a later snapshot differs,
%   the divergence starts inside the optimization loop and the batch size of the
%   first differing snapshot tells which decision round introduced it.

    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    verifyFile = fullfile(root,'diagnostics','lambda020_10runs','verify0', ...
        'verify0_DTLZ2_run19.mat');
    controlFile = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30/' ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'], ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_DTLZ2_M10_D30_19.mat');
    logFile = fullfile(root,'diagnostics','lambda020_10runs','first_snapshot_check.txt');
    fid = fopen(logFile,'w','n','UTF-8');
    cleanup = onCleanup(@()fclose(fid));

    V = load(verifyFile,'result','metadata');
    C = load(controlFile,'result','metadata');
    nv = size(V.result,1);
    nc = size(C.result,1);
    fprintf(fid,'lambda0=0 snapshots: %d; control snapshots: %d\n',nv,nc);
    feV = cell2mat(V.result(:,1));
    feC = cell2mat(C.result(:,1));
    fprintf(fid,'lambda0=0 FE grid : %s\n',mat2str(feV'));
    fprintf(fid,'control   FE grid : %s\n\n',mat2str(feC'));

    fprintf(fid,'RNG state before Solve identical: %d\n', ...
        isequal(V.metadata.rngBeforeSolve,C.metadata.rngBeforeSolve));
    fprintf(fid,'MATLAB version identical        : %d\n\n', ...
        strcmp(V.metadata.matlabVersion,C.metadata.matlabVersion));

    n = min(nv,nc);
    firstDiff = 0;
    fprintf(fid,'%-4s %-6s %-6s %-24s %-24s %s\n', ...
        'k','FE_this','FE_ctl','popEqual','objsEqual','maxAbsDecDiff');
    for k = 1:n
        pv = V.result{k,2};
        pc = C.result{k,2};
        if numel(pv) ~= numel(pc)
            fprintf(fid,'%-4d %-6d %-6d population size differs (%d vs %d)\n', ...
                k,V.result{k,1},C.result{k,1},numel(pv),numel(pc));
            if firstDiff == 0, firstDiff = k; end
            continue;
        end
        decEqual = isequal(pv.decs,pc.decs);
        objEqual = isequal(pv.objs,pc.objs);
        maxDiff = max(abs(pv.decs(:)-pc.decs(:)));
        if ~decEqual && firstDiff == 0, firstDiff = k; end
        fprintf(fid,'%-4d %-6d %-6d %-24d %-24d %.3g\n', ...
            k,V.result{k,1},C.result{k,1},decEqual,objEqual,maxDiff);
    end
    if firstDiff == 0
        fprintf(fid,'\nAll %d snapshots agree.\n',n);
    elseif firstDiff == 1
        fprintf(fid,'\nFirst divergence at snapshot 1: the initial design already differs,\n');
        fprintf(fid,'so the loop logic cannot be the cause.\n');
    else
        fprintf(fid,'\nFirst divergence at snapshot %d (FE %d -> %d).\n', ...
            firstDiff,V.result{firstDiff-1,1},V.result{firstDiff,1});
    end
    fprintf('Log written: %s\n',logFile);
end
