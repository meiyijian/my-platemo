function ProbePieaFE500()
%ProbePieaFE500 Path resolution, existing-file schema and D behaviour check.

    platRoot = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    pieaDir  = fullfile(platRoot,'Algorithms','Multi-objective optimization','PIEA');
    addpath(genpath(platRoot));
    addpath(pieaDir,'-begin');
    addpath(pieaDir);

    fprintf('== PATH RESOLUTION ==\n');
    fprintf('PIEA dir            : %s\n',pieaDir);
    fprintf('which PIEA          : %s\n',which('PIEA'));
    fprintf('which Shape_Estimate: %s\n',which('Shape_Estimate'));
    fprintf('which NDSort_SDR    : %s\n',which('NDSort_SDR'));
    fprintf('which UpdateInf     : %s\n',which('UpdateInformation'));

    fprintf('\n== EXISTING MAT SCHEMA ==\n');
    files = {'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\FE500\PIEA\PIEA_DTLZ1_M10_D30_1.mat', ...
             'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\默认n\PIEA\PIEA_DTLZ1_M10_D14_1.mat'};
    for i = 1:numel(files)
        fprintf('--- %s\n',files{i});
        if ~isfile(files{i})
            fprintf('    MISSING\n'); continue;
        end
        S = load(files{i});
        fprintf('    fields : %s\n',strjoin(fieldnames(S)',', '));
        if isfield(S,'metric')
            fprintf('    metric : %s\n',strjoin(fieldnames(S.metric)',', '));
            fprintf('    IGD    : %.10g\n',S.metric.IGD(end));
            if isfield(S.metric,'runtime'), fprintf('    runtime: %.1f s\n',S.metric.runtime(end)); end
        end
        if isfield(S,'metadata')
            m = S.metadata;
            if isfield(m,'seed'),           fprintf('    seed   : %d\n',m.seed);            end
            if isfield(m,'N'),              fprintf('    N      : %d\n',m.N);               end
            if isfield(m,'M'),              fprintf('    M      : %d\n',m.M);               end
            if isfield(m,'D'),              fprintf('    D      : %d\n',m.D);               end
            if isfield(m,'maxFE'),          fprintf('    maxFE  : %d\n',m.maxFE);           end
            if isfield(m,'parameters'),     fprintf('    params : %s\n',mat2str(m.parameters)); end
            if isfield(m,'runtimeSeconds'), fprintf('    rtSec  : %.1f\n',m.runtimeSeconds); end
        end
        if isfield(S,'result'), fprintf('    result : %dx%d\n',size(S.result,1),size(S.result,2)); end
    end

    fprintf('\n== PROBLEM D BEHAVIOUR (M=10) ==\n');
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    Dreq = [14 19 19 19 19 19 19, 14 19 19 19 19 19 19 19 19];
    for p = 1:numel(probs)
        pr = feval(probs{p},'N',100,'M',10,'D',Dreq(p),'maxFE',500);
        fprintf('    %-6s req D=%2d -> D=%2d  N=%d M=%d\n', ...
            probs{p},Dreq(p),pr.D,pr.N,pr.M);
    end
    fprintf('\nPROBE DONE\n');
end
