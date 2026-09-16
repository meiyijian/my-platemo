function AnalyzeLambdat050VsREMO(outFile)
%AnalyzeLambdat050VsREMO Parallel comparison of two lambda variants vs REMO.
%   Question: does lambdaT=0.50 separate from REMO more strongly than 0.30?
%   Both variants have runIds 21..30 from one shared pool. REMO is stored
%   history from another session, so the tests against REMO are unpaired
%   (Mann-Whitney rank-sum) and use the same runId range so that the random
%   seeds stay aligned in range.
%   Caveat reported in the output: REMO overshoots its budget (last FE 303..305
%   against a strict 300 for both variants), so REMO is very slightly favoured.

    variant = 'REMO_UniformMix_Pruned_Weighted_Lambdat050';
    control = 'REMO_UniformMix_Pruned_Weighted_Lambdat030';
    dataRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30';
    variantData = fullfile(dataRoot,variant);
    controlData = fullfile(variantData,'control_lambdat030');
    remoData = fullfile(dataRoot,'REMO');
    problems = {'DTLZ2','DTLZ4','DTLZ5','DTLZ7'};
    runIds = 21:30;
    M = 10; D = 30;

    fid = fopen(outFile,'w','n','UTF-8');
    assert(fid >= 0,'Cannot write the report.');
    fprintf(fid,'VARIANT vs REMO, M=%d D=%d N=100 maxFE=300, runIds %d..%d\n', ...
        M,D,runIds(1),runIds(end));
    fprintf(fid,'Unpaired Mann-Whitney rank-sum (REMO is stored history).\n');
    fprintf(fid,'delta = 100*(meanREMO-meanVAR)/meanREMO; positive means the variant beats REMO.\n\n');

    fprintf(fid,'%-7s %13s %12s %13s %8s %10s %13s %8s %10s\n', ...
        'Problem','REMO mean','REMO sd','050 mean','d050','p050', ...
        '030 mean','d030','p030');
    p050 = zeros(numel(problems),1); p030 = p050;
    d050 = p050; d030 = p050;
    n050win = zeros(numel(problems),1); n030win = n050win;
    for p = 1:numel(problems)
        R = readArm(remoData,'REMO',problems{p},M,D,runIds);
        A = readArm(variantData,variant,problems{p},M,D,runIds);
        B = readArm(controlData,control,problems{p},M,D,runIds);
        p050(p) = ranksum(R,A);
        p030(p) = ranksum(R,B);
        d050(p) = 100*(mean(R)-mean(A))/mean(R);
        d030(p) = 100*(mean(R)-mean(B))/mean(R);
        n050win(p) = sum(A < R);
        n030win(p) = sum(B < R);
        fprintf(fid,'%-7s %13.6f %12.6f %13.6f %+7.2f%% %10.4g %13.6f %+7.2f%% %10.4g\n', ...
            problems{p},mean(R),std(R),mean(A),d050(p),p050(p),mean(B),d030(p),p030(p));
    end
    fprintf(fid,'\n-- runId-aligned win counts (variant IGD < REMO IGD, out of %d) --\n',numel(runIds));
    for p = 1:numel(problems)
        fprintf(fid,'%-7s 050 %2d/%-2d   030 %2d/%-2d\n',problems{p}, ...
            n050win(p),numel(runIds),n030win(p),numel(runIds));
    end

    fprintf(fid,'\n-- Holm-corrected decisions over all %d tests (alpha=0.05) --\n',2*numel(problems));
    problemsCol = problems(:);
    allp = [p050;p030]; labels = [strcat(problemsCol,'|050');strcat(problemsCol,'|030')];
    assert(numel(labels) == numel(allp),'Label and p-value vectors are misaligned.');
    [ps,ord] = sort(allp); m = numel(ps); holm = ps;
    for i = 1:m
        if i > 1, holm(i) = max(holm(i-1),ps(i)*(m-i+1)); else, holm(i) = ps(i)*m; end
        holm(i) = min(1,holm(i));
    end
    for i = 1:m
        idx = ord(i);
        if holm(i) < 0.05
            if idx <= numel(problems)
                if d050(idx) > 0, verdict = 'variant better'; else, verdict = 'REMO better'; end
            else
                if d030(idx-numel(problems)) > 0, verdict = 'variant better'; else, verdict = 'REMO better'; end
            end
        else
            verdict = 'no difference';
        end
        fprintf(fid,'%-10s p=%.4g  p_holm=%.4g  %s\n',labels{idx},allp(idx),holm(i),verdict);
    end
    fprintf(fid,'\nSignificant tests (raw p<0.05): 050 vs REMO %d/%d; 030 vs REMO %d/%d\n', ...
        sum(p050<0.05),numel(problems),sum(p030<0.05),numel(problems));
    fprintf(fid,'Mean |delta|: 050 %+.2f%%; 030 %+.2f%%\n',mean(d050),mean(d030));

    fprintf(fid,'\n-- Sensitivity: REMO uses all 30 stored runs, variants stay n=10 --\n');
    fprintf(fid,'%-7s %8s %8s %8s\n','Problem','d050','p050','d030','p030');
    for p = 1:numel(problems)
        R = readArm(remoData,'REMO',problems{p},M,D,1:30);
        A = readArm(variantData,variant,problems{p},M,D,runIds);
        B = readArm(controlData,control,problems{p},M,D,runIds);
        fprintf(fid,'%-7s %+7.2f%% %8.4g %+7.2f%% %8.4g\n',problems{p}, ...
            100*(mean(R)-mean(A))/mean(R),ranksum(R,A), ...
            100*(mean(R)-mean(B))/mean(R),ranksum(R,B));
    end

    fprintf(fid,'\n-- REMO budget overshoot --\n');
    fe = zeros(numel(problems),numel(runIds));
    for p = 1:numel(problems)
        for k = 1:numel(runIds)
            S = load(fullfile(remoData,sprintf('REMO_%s_M%d_D%d_%d.mat', ...
                problems{p},M,D,runIds(k))),'result');
            fe(p,k) = S.result{end,1};
        end
    end
    fprintf(fid,'REMO last FE: min=%g mean=%.2f max=%g (variants are exactly 300).\n', ...
        min(fe(:)),mean(fe(:)),max(fe(:)));
    fclose(fid);
end

function v = readArm(folder,name,problem,M,D,runIds)
%readArm Final-snapshot IGD of one arm over the requested run IDs.
    v = zeros(numel(runIds),1);
    for k = 1:numel(runIds)
        file = fullfile(folder,sprintf('%s_%s_M%d_D%d_%d.mat',name,problem,M,D,runIds(k)));
        assert(isfile(file),'Missing result file: %s',file);
        S = load(file,'metric');
        v(k) = S.metric.IGD(end);
    end
end
