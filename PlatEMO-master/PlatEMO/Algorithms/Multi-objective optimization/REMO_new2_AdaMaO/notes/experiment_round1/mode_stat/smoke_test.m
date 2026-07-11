% smoke_test - 最小冒烟测试：验证统计版算法端到端通畅
% 配置：DTLZ2, M=3, D=12, maxFE=150, N=100, 跑1次
% 预期：生成1个 .mat，里面含两类模式计数
platemo_root = 'D:/PlatEMO-master/PlatEMO-master/PlatEMO';
cd(platemo_root);
addpath(genpath(platemo_root));

stat_dir = 'D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO/notes/mode_stat/stat_data_smoke';
if ~exist(stat_dir,'dir'); mkdir(stat_dir); end
% 清空旧的冒烟数据
old = dir(fullfile(stat_dir,'*.mat'));
for i=1:numel(old); delete(fullfile(old(i).folder,old(i).name)); end
setenv('ADAMAO_STAT_DIR', stat_dir);

fprintf('冒烟测试: DTLZ2 M=3 D=12 maxFE=150 N=100 ...\n');
t0 = tic;
try
    [~,~,~] = platemo('algorithm',@REMO_new2_AdaMaO_Stat, ...
        'problem',@DTLZ2, 'M',3, 'D',12, 'maxFE',150, 'N',100, ...
        'run',1, 'outputFcn',@(~,~)[]);
    fprintf('运行完成 (%.1fs)\n', toc(t0));
catch err
    fprintf('运行失败: %s\n', err.message);
    fprintf('  栈:\n');
    for k=1:numel(err.stack); fprintf('    %s (line %d)\n', err.stack(k).name, err.stack(k).line); end
    return;
end

files = dir(fullfile(stat_dir,'*.mat'));
fprintf('生成 .mat 文件数: %d\n', numel(files));
if ~isempty(files)
    s = load(fullfile(files(1).folder, files(1).name));
    st = s.stat;
    fprintf('  problem   = %s\n', st.problem);
    fprintf('  M/D/N     = %d/%d/%d\n', st.M, st.D, st.N);
    fprintf('  total_gen = %d\n', st.total_gen);
    fprintf('  skip_gen  = %d\n', st.skip_gen);
    fprintf('  eval_gen  = %d\n', st.total_gen - st.skip_gen);
    fprintf('  --- 关系对模式 ---\n');
    fprintf('  conservative = %d\n', st.rel_count.conservative);
    fprintf('  curriculum   = %d\n', st.rel_count.curriculum);
    fprintf('  weighted     = %d\n', st.rel_count.weighted);
    fprintf('  --- 候选解模式 ---\n');
    fprintf('  conservative = %d\n', st.cand_count.conservative);
    fprintf('  explore      = %d\n', st.cand_count.explore);
    fprintf('  indicator    = %d\n', st.cand_count.indicator);
    fprintf('\n冒烟测试通过。\n');
else
    fprintf('警告：未生成 .mat 文件（检查 ADAMAO_STAT_DIR 环境变量）\n');
end
