function collect_mode_stat(varargin)
% collect_mode_stat - 汇总所有 .mat 统计文件为一张 CSV 表
%
% 读取 stat_data 目录下所有 <Problem>_M<M>_D<D>_run<runid>.mat，
% 计算两类模式的次数及占比，输出 mode_distribution.csv。
%
% 占比分母约定（与统计版算法口径一致）：
%   - 关系对模式占比分母 = total_gen（每代都确定了 relation_mode，含跳过轮）
%   - 候选解模式占比分母 = eval_gen = total_gen - skip_gen（跳过轮未选 candidate_mode）
%
% 用法（在 MATLAB 命令行）：
%   >> collect_mode_stat                     % 用默认目录，输出 mode_distribution.csv
%   >> collect_mode_stat('out_csv','xx.csv') % 指定输出文件名
%   >> collect_mode_stat('stat_dir','path')  % 指定 .mat 目录
%
% CSV 字段：
%   run_global            全局行号（1..N）
%   problem               问题名
%   M, D, N, maxFE        实验配置
%   final_FE              实际消耗的评估次数
%   total_gen             主循环代数（含跳过轮）
%   skip_gen              关系对为空被跳过的代数
%   eval_gen              实际完成候选模式选择的代数 = total_gen - skip_gen
%   rel_conservative_cnt  关系对-保守模式 选中次数
%   rel_curriculum_cnt    关系对-课程学习模式 选中次数
%   rel_weighted_cnt      关系对-加权模式 选中次数
%   rel_conservative_ratio / rel_curriculum_ratio / rel_weighted_ratio  (分母=total_gen)
%   cand_conservative_cnt 候选解-保守模式 选中次数
%   cand_explore_cnt      候选解-探索模式 选中次数
%   cand_indicator_cnt    候选解-指标模式 选中次数
%   cand_conservative_ratio / cand_explore_ratio / cand_indicator_ratio  (分母=eval_gen)

    %% ---- 解析参数 ----
    p = inputParser;
    addParameter(p,'stat_dir','');
    addParameter(p,'out_csv','');
    parse(p,varargin{:});
    stat_dir = p.Results.stat_dir;
    out_csv  = p.Results.out_csv;

    %% ---- 定位 .mat 目录 ----
    if isempty(stat_dir)
        stat_dir = getenv('ADAMAO_STAT_DIR');
    end
    if isempty(stat_dir)
        stat_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'stat_data');
    end
    if ~exist(stat_dir,'dir')
        error('统计目录不存在: %s\n请先运行 run_mode_stat。', stat_dir);
    end

    files = dir(fullfile(stat_dir,'*.mat'));
    if isempty(files)
        error('目录 %s 下没有 .mat 文件，请先运行 run_mode_stat。', stat_dir);
    end

    %% ---- 排序：按 problem, M, runid ----
    info = struct('name',{files.name}, 'path',{files.folder});
    names = {files.name};
    [~,order] = sort(names);
    files = files(order);

    %% ---- 逐文件汇总 ----
    n = numel(files);
    R = cell(n,1);
    for i = 1:n
        s = load(fullfile(files(i).folder, files(i).name));
        st = s.stat;

        total_gen = st.total_gen;
        skip_gen  = st.skip_gen;
        eval_gen  = total_gen - skip_gen;

        rc = st.rel_count;
        cc = st.cand_count;

        % 关系对模式占比（分母 = total_gen）
        if total_gen > 0
            rel_cons_r = rc.conservative / total_gen;
            rel_curr_r = rc.curriculum   / total_gen;
            rel_weig_r = rc.weighted     / total_gen;
        else
            rel_cons_r = 0; rel_curr_r = 0; rel_weig_r = 0;
        end

        % 候选解模式占比（分母 = eval_gen）
        if eval_gen > 0
            cand_cons_r = cc.conservative / eval_gen;
            cand_expl_r = cc.explore      / eval_gen;
            cand_indi_r = cc.indicator    / eval_gen;
        else
            cand_cons_r = 0; cand_expl_r = 0; cand_indi_r = 0;
        end

        final_FE = 0;
        if isfield(st,'final_FE'); final_FE = st.final_FE; end

        R{i} = { i, st.problem, st.M, st.D, st.N, st.maxFE, final_FE, ...
                 total_gen, skip_gen, eval_gen, ...
                 rc.conservative, rc.curriculum, rc.weighted, ...
                 rel_cons_r, rel_curr_r, rel_weig_r, ...
                 cc.conservative, cc.explore, cc.indicator, ...
                 cand_cons_r, cand_expl_r, cand_indi_r };
    end

    %% ---- 构造 table ----
    headers = {'run_global','problem','M','D','N','maxFE','final_FE', ...
               'total_gen','skip_gen','eval_gen', ...
               'rel_conservative_cnt','rel_curriculum_cnt','rel_weighted_cnt', ...
               'rel_conservative_ratio','rel_curriculum_ratio','rel_weighted_ratio', ...
               'cand_conservative_cnt','cand_explore_cnt','cand_indicator_cnt', ...
               'cand_conservative_ratio','cand_explore_ratio','cand_indicator_ratio'};
    T = cell2table(vertcat(R{:}), 'VariableNames', headers);

    %% ---- 输出 CSV ----
    if isempty(out_csv)
        out_csv = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'mode_distribution.csv');
    end
    writetable(T, out_csv);

    fprintf('========================================\n');
    fprintf(' 已汇总 %d 次运行\n', n);
    fprintf(' CSV 输出: %s\n', out_csv);
    fprintf('========================================\n');

    %% ---- 控制台打印分组均值速览 ----
    fprintf('\n=== 按 问题×M 分组的平均模式占比 ===\n');
    G = groupsummary(T, {'problem','M'}, 'mean', ...
        {'rel_conservative_ratio','rel_curriculum_ratio','rel_weighted_ratio', ...
         'cand_conservative_ratio','cand_explore_ratio','cand_indicator_ratio'});
    % 简化列名显示
    disp(G);
end
