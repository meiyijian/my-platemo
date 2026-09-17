function CompareBackupVsNow()
%CompareBackupVsNow Compare the same run file before (backup) and after (live)
%   the IGDp merge, to prove that nothing but metric.IGDp changed.
    rel = fullfile('15目标','REMO_UniformMix_Pruned_Weighted_Lambdat030', ...
        'REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ1_M15_D30_1.mat');
    files = {fullfile('D:\REMOandDREMO测试集_backup_20260917', rel), ...
             fullfile('C:\Users\lsx\Desktop\REMOandDREMO测试集', rel)};
    names = {'BACKUP (before)', 'LIVE (after)'};
    for k = 1:2
        S = load(files{k});
        fprintf('=== %s ===\n', names{k});
        fprintf('  top vars    : %s\n', strjoin(fieldnames(S)', ', '));
        fprintf('  metric      : %s\n', strjoin(fieldnames(S.metric)', ', '));
        fprintf('  result size : %s\n', mat2str(size(S.result)));
        for j = 1:size(S.result, 2)
            v = S.result{1, j};
            if isa(v, 'SOLUTION')
                fprintf('  result{1,%d} : SOLUTION, numel=%d\n', j, numel(v));
            elseif isnumeric(v)
                fprintf('  result{1,%d} : %s %s\n', j, class(v), mat2str(size(v)));
            else
                fprintf('  result{1,%d} : %s\n', j, class(v));
            end
        end
        fprintf('  metric.IGD len=%d  IGD end=%.10g\n', numel(S.metric.IGD), S.metric.IGD(end));
        if isfield(S.metric, 'IGDp')
            fprintf('  metric.IGDp len=%d  IGDp end=%.10g\n', numel(S.metric.IGDp), S.metric.IGDp(end));
        else
            fprintf('  metric.IGDp : absent\n');
        end
        d = dir(files{k});
        fprintf('  bytes=%d   modified=%s\n', d.bytes, d.date);
    end
end
