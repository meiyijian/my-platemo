% ProbeMatStruct2.m -- deeper look at result cell + metric
addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));

f = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030\REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ1_M10_D30_1.mat';
S = load(f);
r = S.result;
fprintf('result size = %s\n', mat2str(size(r)));
fprintf('r{1,1} class=%s size=%s\n', class(r{1,1}), mat2str(size(r{1,1})));
fprintf('r{1,2} class=%s size=%s\n', class(r{1,2}), mat2str(size(r{1,2})));
fprintf('r{end,1} = %s\n', mat2str(r{end,1}));
fprintf('r{end,2} class=%s\n', class(r{end,2}));
if isa(r{end,2}, 'Population')
    p = r{end,2};
    fprintf('  final Population numel=%d  objs=%s\n', numel(p), mat2str(size(p(1).objs)));
    fprintf('  objs range: min=%s max=%s\n', mat2str(min(p.objs), 4), mat2str(max(p.objs), 4));
end
if isa(r{1,2}, 'Population')
    p1 = r{1,2};
    fprintf('  first Population numel=%d objs=%s\n', numel(p1), mat2str(size(p1(1).objs)));
end

m = S.metric;
fprintf('metric.runtime = %s\n', mat2str(m.runtime));
fprintf('metric.IGD class=%s size=%s\n', class(m.IGD), mat2str(size(m.IGD)));
if iscell(m.IGD)
    fprintf('  IGD{1}=%s  IGD{end}=%s\n', mat2str(m.IGD{1}), mat2str(m.IGD{end}));
end

if isfield(S, 'metadata')
    md = S.metadata;
    disp(md);
    if isfield(md, 'parameters')
        disp(md.parameters);
    end
end

% how many snapshots and what are the FE points
fe = cellfun(@(v) v(1), r(:, 1));
fprintf('FE points (first 5): %s ... (last 5): %s\n', mat2str(fe(1:min(5, numel(fe)))), mat2str(fe(max(1, end-4):end)));
fprintf('n snapshots = %d\n', numel(fe));

% Problem / PF availability check
P = DTLZ1('M', 10, 'D', 30);
fprintf('DTLZ1 M=10: PF size = %s, objs range min=%s max=%s\n', mat2str(size(P.PF)), mat2str(min(P.PF), 4), mat2str(max(P.PF), 4));
fprintf('PROBE2 DONE\n');
