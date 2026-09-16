% ProbeMatStruct.m -- read-only inspection of one result .mat
addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));

dirs = { ...
  'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030', ...
  'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'};

for k = 1:numel(dirs)
    d = dirs{k};
    fprintf('======== DIR %d: %s\n', k, d);
    fs = dir(fullfile(d, '*.mat'));
    if isempty(fs), fprintf('  (no mat)\n'); continue; end
    fprintf('  nFiles = %d\n', numel(fs));
    f = fullfile(d, fs(1).name);
    fprintf('  FILE: %s\n', fs(1).name);
    try
        w = whos('-file', f);
        for i = 1:numel(w)
            fprintf('    VAR %-12s class=%-14s size=%s\n', w(i).name, w(i).class, mat2str(w(i).size));
        end
    catch ME
        fprintf('    whos failed: %s\n', ME.message);
    end
    try
        S = load(f);
        fn = fieldnames(S);
        for i = 1:numel(fn)
            v = S.(fn{i});
            fprintf('    LOADED %-12s class=%s\n', fn{i}, class(v));
            if isa(v, 'Population') && ~isempty(v)
                fprintf('      numel=%d  objs=%s\n', numel(v), mat2str(size(v(1).objs)));
            end
            if isstruct(v) && numel(v) == 1
                fprintf('      struct fields: %s\n', strjoin(fieldnames(v)', ','));
            end
            if iscell(v) && ~isempty(v)
                fprintf('      cell size=%s  v{1} class=%s\n', mat2str(size(v)), class(v{1}));
                if isa(v{1}, 'Population')
                    fprintf('      v{1} numel=%d objs=%s\n', numel(v{1}), mat2str(size(v{1}(1).objs)));
                end
            end
        end
    catch ME
        fprintf('    load failed: %s\n', ME.message);
    end
end
fprintf('PROBE DONE\n');
