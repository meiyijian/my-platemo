function VerifyTrialWrite()
%VerifyTrialWrite Inspect one file that the merge pass has just touched, and
%   time a short second batch to measure the real throughput.
    f = ['C:\Users\lsx\Desktop\REMOandDREMO测试集\15目标\' ...
         'REMO_UniformMix_Pruned_Weighted_Lambdat030\' ...
         'REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ1_M15_D30_1.mat'];
    fprintf('file : %s\n', f);
    S = load(f);
    fprintf('vars   : %s\n', strjoin(fieldnames(S)', ', '));
    fprintf('metric : %s\n', strjoin(fieldnames(S.metric)', ', '));
    fprintf('nSnap=%d  IGD len=%d  IGDp len=%d\n', ...
        size(S.result, 1), numel(S.metric.IGD), numel(S.metric.IGDp));
    fprintf('IGD end=%.8g   IGDp end=%.8g\n', S.metric.IGD(end), S.metric.IGDp(end));
    fprintf('runtime=%.6g\n', S.metric.runtime);
    if isfield(S, 'metadata')
        fprintf('metadata preserved: yes (%s)\n', S.metadata.problem);
    else
        fprintf('metadata preserved: NO\n');
    end
    if isa(S.result{end,2}, 'SOLUTION')
        fprintf('result{end,2} still SOLUTION with %d solutions\n', numel(S.result{end,2}));
    else
        fprintf('result{end,2} class = %s\n', class(S.result{end,2}));
    end
end
