function AnalyzeLambdat050(outFile)
%AnalyzeLambdat050 Paired statistics for the lambdaT=0.50 vs 0.30 arms.
%   Both arms ran inside the same process pool with identical seeds, so every
%   run ID is a matched pair. Reports per-problem and pooled Wilcoxon
%   signed-rank tests on the final IGD, plus a Holm-corrected decision.

    variant = 'REMO_UniformMix_Pruned_Weighted_Lambdat050';
    control = 'REMO_UniformMix_Pruned_Weighted_Lambdat030';
    dataRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30';
    variantData = fullfile(dataRoot,variant);
    controlData = fullfile(variantData,'control_lambdat030');
    problems = {'DTLZ2','DTLZ4','DTLZ5','DTLZ7'};
    runIds = 21:30;
    M = 10; D = 30;

    fid = fopen(outFile,'w','n','UTF-8');
    assert(fid >= 0,'Cannot write the report.');
    fprintf(fid,'PAIRED IGD, lambdaT=0.50 (new) vs lambdaT=0.30 (control)\n');
    fprintf(fid,'M=%d D=%d N=100 maxFE=300, runIds %d..%d, same pool same seeds\n\n', ...
        M,D,runIds(1),runIds(end));
    fprintf(fid,'%-7s %3s %13s %12s %13s %12s %9s %11s %5s %5s\n', ...
        'Problem','n','mean050','sd050','mean030','sd030','delta','p','w050','w030');
    pooledA = []; pooledB = [];
    pv = zeros(numel(problems),1);
    stats = cell(numel(problems),1);
    for p = 1:numel(problems)
        A = zeros(numel(runIds),1); B = A;
        for k = 1:numel(runIds)
            A(k) = getIGD(fullfile(variantData,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                variant,problems{p},M,D,runIds(k))));
            B(k) = getIGD(fullfile(controlData,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                control,problems{p},M,D,runIds(k))));
        end
        pooledA = [pooledA;A]; pooledB = [pooledB;B]; %#ok<AGROW>
        pv(p) = signrank(A,B);
        d = 100*(mean(B)-mean(A))/mean(B);
        stats{p} = struct('A',A,'B',B,'p',pv(p),'delta',d, ...
            'w050',sum(A<B),'w030',sum(B<A));
        fprintf(fid,'%-7s %3d %13.6f %12.6f %13.6f %12.6f %+8.2f%% %11.4g %5d %5d\n', ...
            problems{p},numel(runIds),mean(A),std(A),mean(B),std(B),d,pv(p), ...
            sum(A<B),sum(B<A));
    end
    fprintf(fid,'\n-- Holm-corrected per-problem decisions (alpha=0.05) --\n');
    [ps,ord] = sort(pv);
    holm = ps; m = numel(ps);
    for i = 1:m
        if i > 1
            holm(i) = max(holm(i-1),ps(i)*(m-i+1));
        else
            holm(i) = ps(i)*m;
        end
        holm(i) = min(1,holm(i));
    end
    for i = 1:m
        idx = ord(i);
        if holm(i) < 0.05
            verdict = '050 better' ;
            if stats{idx}.delta < 0, verdict = '030 better'; end
        else
            verdict = 'no difference';
        end
        fprintf(fid,'%-7s p=%.4g  p_holm=%.4g  %s\n', ...
            problems{idx},pv(idx),holm(i),verdict);
    end
    pp = signrank(pooledA,pooledB);
    fprintf(fid,'\n-- Pooled over all %d matched pairs --\n',numel(pooledA));
    fprintf(fid,'mean050=%.6f sd=%.6f | mean030=%.6f sd=%.6f\n', ...
        mean(pooledA),std(pooledA),mean(pooledB),std(pooledB));
    fprintf(fid,'pooled delta=%+.2f%%  p=%.4g  w050=%d w030=%d\n', ...
        100*(mean(pooledB)-mean(pooledA))/mean(pooledB),pp, ...
        sum(pooledA<pooledB),sum(pooledB<pooledA));
    fprintf(fid,'\n-- Per-run detail (050, 030, diff) --\n');
    for p = 1:numel(problems)
        s = stats{p};
        fprintf(fid,'%s:\n',problems{p});
        for k = 1:numel(runIds)
            fprintf(fid,'  run %02d  %12.6f  %12.6f  %+10.6f\n', ...
                runIds(k),s.A(k),s.B(k),s.A(k)-s.B(k));
        end
    end
    fclose(fid);
end

function v = getIGD(file)
    assert(isfile(file),'Missing result file: %s',file);
    S = load(file,'metric');
    assert(isfield(S,'metric') && isfield(S.metric,'IGD'),'No IGD in %s',file);
    v = S.metric.IGD(end);
end
