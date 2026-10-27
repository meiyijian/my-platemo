% Reconstruct missing PIEA IGD+ traces from saved populations without evaluation.
% Run from this file's directory with MATLAB R2023a and the local PlatEMO tree.
platRoot = fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), ...
    'PlatEMO-master','PlatEMO');
addpath(genpath(platRoot));
assert(contains(which('SOLUTION'),platRoot),'Wrong SOLUTION path');
assert(contains(which('IGDp'),platRoot),'Wrong IGDp path');
sourceRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\FE500\PIEA';
outputFile = fullfile(fileparts(mfilename('fullpath')),'piea_recomputed_igdp.mat');
problems = {'DTLZ1','DTLZ6','WFG2','WFG7','WFG3'};
entries = struct('filename',{},'source_sha256',{},'fe',{},'igdp',{}, ...
    'reference_size',{},'FE_before',{},'FE_after',{});
checks = struct('problem',{},'stock_max_error',{},'stored_max_error',{});
for p = 1:numel(problems)
    prob = problems{p};
    if ismember(prob,{'WFG2','WFG3'}), dim = 31; else, dim = 30; end
    problem = feval(prob,'M',10,'D',dim,'N',100,'maxFE',500);
    assert(problem.FE == 0,'Problem constructor evaluated objectives');
    optimum = problem.optimum;
    stockError = 0; storedError = 0; recomputed = 0;
    for runId = 1:20
        filename = sprintf('PIEA_%s_M10_D%d_%d.mat',prob,dim,runId);
        path = fullfile(sourceRoot,filename);
        data = load(path,'result','metric');
        fe = cell2mat(data.result(:,1));
        hasStored = isfield(data.metric,'IGDp') && numel(data.metric.IGDp)==numel(fe);
        % Cross-check a complete stored trajectory as well as all missing traces.
        if hasStored && runId ~= 20, continue; end
        gp = zeros(size(fe));
        for k = 1:numel(fe)
            gp(k) = blockIGDp(data.result{k,2},optimum);
        end
        if hasStored
            storedError = max(storedError,max(abs(gp-data.metric.IGDp(:))));
        else
            recomputed = recomputed + 1;
            entries(end+1) = struct('filename',filename,'source_sha256',fileSHA(path), ...
                'fe',fe,'igdp',gp,'reference_size',size(optimum,1), ...
                'FE_before',0,'FE_after',problem.FE); %#ok<SAGROW>
        end
        if runId == 20
            for k = [1,numel(fe)]
                stockError = max(stockError,abs(gp(k)-IGDp(data.result{k,2},optimum)));
            end
        end
        assert(problem.FE==0,'Metric reconstruction incremented FE');
    end
    assert(stockError<1e-11 && storedError<1e-11,'IGD+ implementation mismatch');
    checks(end+1) = struct('problem',prob,'stock_max_error',stockError, ...
        'stored_max_error',storedError); %#ok<SAGROW>
    fprintf('%s: %d reconstructed files, reference=%d, stock error=%.3g, stored error=%.3g\n', ...
        prob,recomputed,size(optimum,1),stockError,storedError);
end
save(outputFile,'entries','checks','-v7');
fprintf('Saved %d missing trajectories; no objective evaluations; raw files unchanged.\n',numel(entries));

function score = blockIGDp(population,optimum)
    objectives = double(population.best.objs);
    delta = zeros(size(optimum,1),1);
    for first = 1:20000:size(optimum,1)
        ids = first:min(first+19999,size(optimum,1));
        squared = zeros(numel(ids),size(objectives,1));
        for j = 1:size(optimum,2)
            squared = squared + max(objectives(:,j).'-optimum(ids,j),0).^2;
        end
        delta(ids) = min(sqrt(squared),[],2);
    end
    score = mean(delta);
end

function hash = fileSHA(path)
    handle = fopen(path,'rb');
    guard = onCleanup(@() fclose(handle));
    bytes = fread(handle,inf,'*uint8');
    digest = java.security.MessageDigest.getInstance('SHA-256');
    digest.update(bytes);
    hash = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
