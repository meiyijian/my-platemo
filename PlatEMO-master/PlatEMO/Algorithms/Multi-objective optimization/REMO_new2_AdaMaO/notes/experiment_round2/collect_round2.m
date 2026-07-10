function collect_round2(varargin)
% collect_round2 - 汇总第二轮实验，生成两份 CSV
%
% 1. mode_distribution_r2.csv — 模式占比汇总（每次运行一行，同第一轮格式）
% 2. diagnostics_r2.csv       — 逐代诊断量（每行一代，新增）
%
% diagnostics_r2.csv 字段：
%   run_global, problem, M, run_id, gen,
%   p_err, prev_p_err, coverage, degeneracy, mean_conf,
%   relation_mode, candidate_mode
%
% 用法：
%   >> collect_round2                           % 默认读 experiment_round2/stat_data
%   >> collect_round2('stat_dir','path')        % 指定 .mat 目录

    p = inputParser;
    addParameter(p,'stat_dir','');
    parse(p,varargin{:});
    stat_dir = p.Results.stat_dir;
    if isempty(stat_dir)
        stat_dir = fullfile(fileparts(mfilename('fullpath')),'stat_data');
    end
    if ~exist(stat_dir,'dir')
        error('统计目录不存在: %s\n请先运行 run_round2。', stat_dir);
    end

    files = dir(fullfile(stat_dir,'*.mat'));
    if isempty(files)
        error('目录 %s 下没有 .mat 文件，请先运行 run_round2。', stat_dir);
    end

    %% ---- 排序 ----
    names = {files.name};
    [~,order] = sort(names);
    files = files(order);
    n = numel(files);

    %% ---- 模式分布表头 ----
    mode_headers = {'run_global','problem','M','D','N','maxFE','final_FE', ...
        'total_gen','skip_gen','eval_gen', ...
        'rel_conservative_cnt','rel_curriculum_cnt','rel_weighted_cnt', ...
        'rel_conservative_ratio','rel_curriculum_ratio','rel_weighted_ratio', ...
        'cand_conservative_cnt','cand_explore_cnt','cand_indicator_cnt', ...
        'cand_conservative_ratio','cand_explore_ratio','cand_indicator_ratio'};
    mode_R = cell(n,1);

    %% ---- 诊断量表头 ----
    diag_headers = {'run_global','problem','M','run_id','gen', ...
        'p_err','prev_p_err','coverage','degeneracy','mean_conf', ...
        'relation_mode','candidate_mode'};
    diag_R = {};

    %% ---- 逐文件汇总 ----
    for i = 1:n
        s = load(fullfile(files(i).folder, files(i).name));
        st = s.stat;

        % --- 模式分布 ---
        tg = st.total_gen;  sg = st.skip_gen;  eg = tg - sg;
        rc = st.rel_count;  cc = st.cand_count;
        if tg > 0
            rcr = rc.conservative/tg;  rcur = rc.curriculum/tg;  rwr = rc.weighted/tg;
        else; rcr=0; rcur=0; rwr=0; end
        if eg > 0
            ccr = cc.conservative/eg;  cer = cc.explore/eg;  cir = cc.indicator/eg;
        else; ccr=0; cer=0; cir=0; end
        ffe = 0;  if isfield(st,'final_FE'); ffe = st.final_FE; end
        mode_R{i} = {i, st.problem, st.M, st.D, st.N, st.maxFE, ffe, tg, sg, eg, ...
            rc.conservative, rc.curriculum, rc.weighted, rcr, rcur, rwr, ...
            cc.conservative, cc.explore, cc.indicator, ccr, cer, cir};

        % --- 逐代诊断量 ---
        if isfield(st,'diag_trace') && ~isempty(st.diag_trace)
            dt = st.diag_trace;        % Nx6: [gen,p_err,prev_p_err,coverage,degeneracy,mean_conf]
            rt = st.rel_trace;          % 1xN cell
            ct = st.cand_trace;         % 1xN cell
            ng = size(dt,1);
            run_id = 0;
            if isfield(st,'runid'); run_id = st.runid; end
            for g = 1:ng
                rmode = '';  if g <= numel(rt); rmode = rt{g}; end
                cmode = '';  if g <= numel(ct); cmode = ct{g}; end
                diag_R{end+1} = {i, st.problem, st.M, run_id, dt(g,1), ...
                    dt(g,2), dt(g,3), dt(g,4), dt(g,5), dt(g,6), rmode, cmode};
            end
        end
    end

    %% ---- 写 CSV ----
    out_dir = fileparts(stat_dir);
    mode_csv = fullfile(out_dir,'mode_distribution_r2.csv');
    diag_csv = fullfile(out_dir,'diagnostics_r2.csv');

    Tm = cell2table(vertcat(mode_R{:}), 'VariableNames', mode_headers);
    writetable(Tm, mode_csv);

    Td = cell2table(vertcat(diag_R{:}), 'VariableNames', diag_headers);
    writetable(Td, diag_csv);

    fprintf('========================================\n');
    fprintf(' 第二轮汇总完成\n');
    fprintf('========================================\n');
    fprintf(' 模式分布: %s  (%d 运行)\n', mode_csv, n);
    fprintf(' 逐代诊断: %s  (%d 行)\n', diag_csv, height(Td));
    fprintf('========================================\n');

    %% ---- 速览：DTLZ4/7 M=20 的 degeneracy 均值（验证阈值假设）----
    fprintf('\n=== 关键验证：DTLZ4/7 M=20 的 degeneracy（应 <0.45 才解释 explore）===\n');
    try
        Dd = Td(strcmp(Td.problem,'DTLZ4') & Td.M==20, :);
        Dd7 = Td(strcmp(Td.problem,'DTLZ7') & Td.M==20, :);
        fprintf(' DTLZ4 M20: degeneracy 均=%.3f min=%.3f max=%.3f (阈值0.45)\n', ...
            mean(Dd.degeneracy,'omitnan'), min(Dd.degeneracy), max(Dd.degeneracy));
        fprintf(' DTLZ7 M20: degeneracy 均=%.3f min=%.3f max=%.3f (阈值0.45)\n', ...
            mean(Dd7.degeneracy,'omitnan'), min(Dd7.degeneracy), max(Dd7.degeneracy));
        fprintf('   -> 若均<0.45，证实"degeneracy阈值未满足"是explore而非indicator的根因\n');
    catch
    end

    %% ---- curriculum 触发时 p_err 验证 ----
    fprintf('\n=== curriculum 触发时 p_err（应>0.35）===\n');
    try
        Cc = Td(strcmp(Td.relation_mode,'curriculum'),:);
        fprintf(' curriculum 代数: %d, p_err 均=%.3f (NaN=跳过轮未算)\n', ...
            height(Cc), mean(Cc.p_err,'omitnan'));
    catch
    end
end
