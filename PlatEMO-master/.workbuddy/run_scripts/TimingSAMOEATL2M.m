function TimingSAMOEATL2M(maxFE,problem,M,D,algName)
%TimingSAMOEATL2M Time one run and log every generation the algorithm reports.
%   The original SAMOEATL2M fixes its own initial design at 11*D-1 points, so
%   maxFE must exceed that before the main loop runs at all. The _N100 variant
%   fixes it at 100 instead.
    if nargin < 1 || isempty(maxFE), maxFE = 400; end
    if nargin < 2 || isempty(problem), problem = 'DTLZ2'; end
    if nargin < 3 || isempty(M), M = 10; end
    if nargin < 4 || isempty(D), D = 30; end
    if nargin < 5 || isempty(algName), algName = 'SAMOEATL2M'; end

    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    root = fullfile(platform,'Algorithms','Multi-objective optimization','SAMOEA-TL2M');
    addpath(genpath(platform));
    addpath(root,'-begin');
    assert(strncmpi(fileparts(which(algName)),root,numel(root)), ...
        '%s does not resolve to %s.',algName,root);

    logFile = fullfile(tempdir,'samoea_timing.txt');
    if isfile(logFile), delete(logFile); end

    pro = feval(problem,'N',100,'M',M,'D',D,'maxFE',maxFE);
    fprintf('algorithm %s | problem %s : N=%d M=%d D=%d maxFE=%d | 11*D-1 = %d\n', ...
        algName,problem,pro.N,pro.M,pro.D,pro.maxFE,11*pro.D-1);
    t0 = tic;
    alg = feval(algName,'save',30,'run',1,'outputFcn',@(~,p) logOne(logFile,p,t0));
    rng(21260912,'twister');
    alg.Solve(pro);
    total = toc(t0);
    fprintf('DONE FE=%d of %d | result rows=%d | wall %.1f s\n', ...
        pro.FE,pro.maxFE,size(alg.result,1),total);
    if ~isempty(alg.result)
        fprintf('result FE column = %s\n',mat2str(cell2mat(alg.result(:,1))'));
    end
    if isfile(logFile)
        fprintf('--- generation log ---\n');
        fid = fopen(logFile,'r');
        while ~feof(fid)
            line = fgetl(fid);
            if ischar(line)
                fprintf('%s\n',line);
            end
        end
        fclose(fid);
    end
    alg.CalMetric('IGD');
    fprintf('IGD trajectory = %s\n',mat2str(alg.metric.IGD,8));
end

function logOne(file,Problem,started)
    fid = fopen(file,'a');
    if fid >= 0
        fprintf(fid,'FE=%d t=%.1f\n',Problem.FE,toc(started));
        fclose(fid);
    end
end
