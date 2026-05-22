function analyze_existing_data()
% analyze_existing_data - 从已有的 REMO 测试集中分析目标难度分离度。
%
% 直接读取 C:\Users\lsx\Desktop\REMOandDREMO测试集 中的 .mat 文件，
% 对每个 run 的最终 Archive 进行 PBI 分类，计算 per-objective separation gap。
%
% 输出：
%   - figures/ 目录下 4 张图
%   - 命令行打印汇总表

    %% 配置
    data_root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';

    % 要分析的问题（从你数据集中有的选）
    problems  = {'DTLZ2', 'DTLZ4', 'WFG4'};

    % M 值和对应的目录结构
    M_configs = { ...
        struct('M', 3,  'D', 10, 'subdir', fullfile('3目标','n10')), ...
        struct('M', 5,  'D', 10, 'subdir', fullfile('5目标','n10')), ...
        struct('M', 8,  'D', 30, 'subdir', fullfile('8目标','n30')), ...
        struct('M', 10, 'D', 30, 'subdir', fullfile('10目标','n30')), ...
        struct('M', 15, 'D', 30, 'subdir', '15目标')  ...
    };

    max_runs = 30;  % 最多读取多少个 run

    % PlatEMO helper 函数路径
    remo_dir = fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), ...
        'Algorithms', 'Multi-objective optimization', 'REMO');
    if exist(remo_dir, 'dir')
        addpath(remo_dir);
    end

    this_dir    = fileparts(mfilename('fullpath'));
    addpath(this_dir);  % 让 MATLAB 找到 compute_obj_separation.m
    figures_dir = fullfile(this_dir, 'figures');
    if ~exist(figures_dir, 'dir')
        mkdir(figures_dir);
    end

    %% 加载数据
    % data.(problem).M_<M> = struct with fields: gap_all (nRuns x M), dom_all, etc.
    data = struct();

    for pi = 1:numel(problems)
        prob = problems{pi};
        for mi = 1:numel(M_configs)
            cfg = M_configs{mi};
            Mval = cfg.M;
            Dval = cfg.D;

            % 构造 REMO 子目录
            remo_subdir = fullfile(data_root, cfg.subdir, 'REMO');
            if ~exist(remo_subdir, 'dir')
                fprintf('  SKIP: %s not found\n', remo_subdir);
                continue;
            end

            gap_runs  = [];
            dom_runs  = [];
            n_loaded  = 0;

            for r = 1:max_runs
                fname = sprintf('REMO_%s_M%d_D%d_%d.mat', prob, Mval, Dval, r);
                fpath = fullfile(remo_subdir, fname);

                % WFG 问题在 M>=8 时有时用 D=31 而非 D=30
                if ~exist(fpath, 'file')
                    fname_alt = sprintf('REMO_%s_M%d_D%d_%d.mat', prob, Mval, Dval+1, r);
                    fpath = fullfile(remo_subdir, fname_alt);
                end
                if ~exist(fpath, 'file')
                    continue;
                end

                try
                    loaded = load(fpath);
                catch
                    continue;
                end

                % 提取最终 Population
                if ~isfield(loaded, 'result')
                    continue;
                end
                result = loaded.result;
                if isempty(result)
                    continue;
                end

                % result 是 cell array: {FE, Population}
                % 取最后一行
                Pop = result{end, 2};
                PopObj = Pop.objs;
                [N, M_check] = size(PopObj);

                if M_check ~= Mval
                    continue;
                end

                % PBI 分类
                try
                    k_ref = min(6, N);
                    Ref = RefSelect(Pop, k_ref);
                    Catalog = GetOutput_PBI(PopObj, Ref.objs);
                catch
                    continue;
                end

                % 计算分离度
                diag = compute_obj_separation(PopObj, Catalog, 1);

                n_loaded = n_loaded + 1;
                gap_runs(n_loaded, :) = diag.gap; %#ok<AGROW>
                dom_runs(n_loaded, :) = diag.dom_rate; %#ok<AGROW>
            end

            field = sprintf('M%d', Mval);
            data.(prob).(field).gap_all  = gap_runs;
            data.(prob).(field).dom_all  = dom_runs;
            data.(prob).(field).n_loaded = n_loaded;
            data.(prob).(field).M        = Mval;
            data.(prob).(field).D        = Dval;

            fprintf('  %s M=%d: %d runs loaded\n', prob, Mval, n_loaded);
        end
    end

    %% 汇总
    fprintf('\n=== Summary: Mean Separation Gap (Cohen''s d) ===\n');
    fprintf('%-8s', 'Problem');
    for mi = 1:numel(M_configs)
        fprintf('%8s', sprintf('M=%d', M_configs{mi}.M));
    end
    fprintf('\n');

    for pi = 1:numel(problems)
        prob = problems{pi};
        fprintf('%-8s', prob);
        for mi = 1:numel(M_configs)
            field = sprintf('M%d', M_configs{mi}.M);
            if isfield(data, prob) && isfield(data.(prob), field) ...
                    && data.(prob).(field).n_loaded > 0
                avg = mean(data.(prob).(field).gap_all(:));
                fprintf('%8.2f', avg);
            else
                fprintf('%8s', '-');
            end
        end
        fprintf('\n');
    end

    %% =====================================================================
    %  Figure 1: Heatmap — Per-objective gap, all M values
    %  =====================================================================
    fig1 = figure('Position', [50 50 1400 450], 'Visible', 'on');

    for pi = 1:numel(problems)
        subplot(1, numel(problems), pi);
        prob = problems{pi};

        nM    = numel(M_configs);
        maxM  = M_configs{end}.M;
        hm_data = NaN(nM, maxM);
        hm_text = cell(nM, maxM);

        for mi = 1:nM
            Mval  = M_configs{mi}.M;
            field = sprintf('M%d', Mval);
            if ~isfield(data, prob) || ~isfield(data.(prob), field)
                continue;
            end
            gap_all = data.(prob).(field).gap_all;
            if isempty(gap_all)
                continue;
            end
            avg_gap = mean(gap_all, 1);
            hm_data(mi, 1:Mval) = avg_gap;
            for m = 1:Mval
                hm_text{mi, m} = sprintf('%.2f', avg_gap(m));
            end
        end

        imagesc(hm_data);
        colormap(hot);
        cb = colorbar;
        cb.Label.String = "Cohen's d (separation gap)";

        for mi = 1:nM
            for m = 1:M_configs{mi}.M
                val = hm_data(mi, m);
                if ~isnan(val)
                    if val > (nanmax(hm_data(:)) + nanmin(hm_data(:))) / 2
                        txt_color = 'k';
                    else
                        txt_color = 'w';
                    end
                    text(m, mi, hm_text{mi, m}, ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 8, 'Color', txt_color);
                end
            end
        end

        M_labels = cellfun(@(c)sprintf('M=%d', c.M), M_configs, 'UniformOutput', false);
        set(gca, 'YTick', 1:nM, 'YTickLabel', M_labels);
        set(gca, 'XTick', 1:maxM);
        xlabel('Objective index');
        ylabel('Number of objectives');
        title(sprintf('%s: Separation Gap', prob), 'Interpreter', 'none');
    end

    saveas(fig1, fullfile(figures_dir, 'fig1_heatmap_gap.png'));
    savefig(fig1, fullfile(figures_dir, 'fig1_heatmap_gap.fig'));
    fprintf('Saved fig1_heatmap_gap.png\n');

    %% =====================================================================
    %  Figure 2: Boxplot — Gap distribution per M (all problems combined)
    %  =====================================================================
    fig2 = figure('Position', [50 50 900 500], 'Visible', 'on');

    nM = numel(M_configs);
    all_box_data = [];
    all_box_group = [];
    all_box_M = [];

    for mi = 1:nM
        Mval = M_configs{mi}.M;
        field = sprintf('M%d', Mval);
        for pi = 1:numel(problems)
            prob = problems{pi};
            if ~isfield(data, prob) || ~isfield(data.(prob), field)
                continue;
            end
            gap_all = data.(prob).(field).gap_all;
            if isempty(gap_all)
                continue;
            end
            % Flatten: all (run, objective) pairs
            gap_flat = gap_all(:);
            all_box_data  = [all_box_data; gap_flat]; %#ok<AGROW>
            all_box_group = [all_box_group; repmat(Mval, numel(gap_flat), 1)]; %#ok<AGROW>
        end
    end

    if ~isempty(all_box_data)
        box_labels = cellfun(@(c)sprintf('M=%d', c.M), M_configs, 'UniformOutput', false);
        boxplot(all_box_data, all_box_group, 'Labels', box_labels);
        xlabel('Number of objectives');
        ylabel("Cohen's d (separation gap)");
        title('Separation Gap Distribution Across All Problems', 'Interpreter', 'none');
        grid on;
    end

    saveas(fig2, fullfile(figures_dir, 'fig2_boxplot_gap_by_M.png'));
    savefig(fig2, fullfile(figures_dir, 'fig2_boxplot_gap_by_M.fig'));
    fprintf('Saved fig2_boxplot_gap_by_M.png\n');

    %% =====================================================================
    %  Figure 3: Bar chart — Per-objective gap for DTLZ2, selected M
    %  =====================================================================
    fig3 = figure('Position', [50 50 1200 400], 'Visible', 'on');
    target_prob = 'DTLZ2';

    selected_M = [3, 5, 8, 10, 15];
    colors = lines(numel(selected_M));
    legend_entries = {};

    hold on;
    maxM = 0;
    for mi = 1:numel(selected_M)
        Mval  = selected_M(mi);
        field = sprintf('M%d', Mval);
        if ~isfield(data, target_prob) || ~isfield(data.(target_prob), field)
            continue;
        end
        gap_all = data.(target_prob).(field).gap_all;
        if isempty(gap_all)
            continue;
        end
        avg_gap = mean(gap_all, 1);
        maxM = max(maxM, Mval);

        bar_offsets = (mi - (numel(selected_M)+1)/2) * 0.15;
        x_pos = (1:Mval) + bar_offsets;
        bar(x_pos, avg_gap, 0.12, 'FaceColor', colors(mi,:), ...
            'EdgeColor', 'none', 'FaceAlpha', 0.8);
        legend_entries{end+1} = sprintf('M=%d', Mval); %#ok<AGROW>
    end
    hold off;

    xlabel('Objective index');
    ylabel("Cohen's d (separation gap)");
    title(sprintf('%s: Per-Objective Separation Gap', target_prob), 'Interpreter', 'none');
    legend(legend_entries, 'Location', 'best');
    set(gca, 'XTick', 1:maxM);
    grid on;

    saveas(fig3, fullfile(figures_dir, 'fig3_bar_gap_DTLZ2.png'));
    savefig(fig3, fullfile(figures_dir, 'fig3_bar_gap_DTLZ2.fig'));
    fprintf('Saved fig3_bar_gap_DTLZ2.png\n');

    %% =====================================================================
    %  Figure 4: Gap CV vs M (unevenness across objectives)
    %  =====================================================================
    fig4 = figure('Position', [50 50 800 500], 'Visible', 'on');
    hold on;

    markers = {'o', 's', 'd', '^', 'v'};
    line_colors = lines(numel(problems));

    for pi = 1:numel(problems)
        prob = problems{pi};
        cv_vals = zeros(1, nM);

        for mi = 1:nM
            Mval  = M_configs{mi}.M;
            field = sprintf('M%d', Mval);
            if ~isfield(data, prob) || ~isfield(data.(prob), field)
                cv_vals(mi) = NaN;
                continue;
            end
            gap_all = data.(prob).(field).gap_all;
            if isempty(gap_all)
                cv_vals(mi) = NaN;
                continue;
            end
            % CV of gap across objectives, averaged over runs
            cv_per_run = std(gap_all, 0, 2) ./ (mean(gap_all, 2) + eps);
            cv_vals(mi) = mean(cv_per_run);
        end

        M_vals = cellfun(@(c) c.M, M_configs);
        plot(M_vals, cv_vals, ['-' markers{pi}], ...
            'Color', line_colors(pi,:), 'LineWidth', 1.5, ...
            'MarkerSize', 8, 'MarkerFaceColor', line_colors(pi,:), ...
            'DisplayName', prob);
    end

    hold off;
    xlabel('Number of objectives (M)');
    ylabel('Gap CV (coefficient of variation)');
    title('Objective Difficulty Unevenness vs M', 'Interpreter', 'none');
    legend('Location', 'best', 'Interpreter', 'none');
    grid on;
    M_vals = cellfun(@(c) c.M, M_configs);
    set(gca, 'XTick', M_vals);

    saveas(fig4, fullfile(figures_dir, 'fig4_gap_cv_vs_M.png'));
    savefig(fig4, fullfile(figures_dir, 'fig4_gap_cv_vs_M.fig'));
    fprintf('Saved fig4_gap_cv_vs_M.png\n');

    %% =====================================================================
    %  Figure 5: Dominance rate heatmap
    %  =====================================================================
    fig5 = figure('Position', [50 50 1400 450], 'Visible', 'on');

    for pi = 1:numel(problems)
        subplot(1, numel(problems), pi);
        prob = problems{pi};

        maxM  = M_configs{end}.M;
        hm_data = NaN(nM, maxM);
        hm_text = cell(nM, maxM);

        for mi = 1:nM
            Mval  = M_configs{mi}.M;
            field = sprintf('M%d', Mval);
            if ~isfield(data, prob) || ~isfield(data.(prob), field)
                continue;
            end
            dom_all = data.(prob).(field).dom_all;
            if isempty(dom_all)
                continue;
            end
            avg_dom = mean(dom_all, 1);
            hm_data(mi, 1:Mval) = avg_dom;
            for m = 1:Mval
                hm_text{mi, m} = sprintf('%.2f', avg_dom(m));
            end
        end

        imagesc(hm_data);
        colormap(parula);
        cb = colorbar;
        cb.Label.String = 'Dominance rate (good < bad)';

        for mi = 1:nM
            for m = 1:M_configs{mi}.M
                val = hm_data(mi, m);
                if ~isnan(val)
                    txt_color = 'k';
                    text(m, mi, hm_text{mi, m}, ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 8, 'Color', txt_color);
                end
            end
        end

        M_labels = cellfun(@(c)sprintf('M=%d', c.M), M_configs, 'UniformOutput', false);
        set(gca, 'YTick', 1:nM, 'YTickLabel', M_labels);
        set(gca, 'XTick', 1:maxM);
        xlabel('Objective index');
        ylabel('Number of objectives');
        title(sprintf('%s: Dominance Rate', prob), 'Interpreter', 'none');
    end

    saveas(fig5, fullfile(figures_dir, 'fig5_heatmap_dominance.png'));
    savefig(fig5, fullfile(figures_dir, 'fig5_heatmap_dominance.fig'));
    fprintf('Saved fig5_heatmap_dominance.png\n');

    fprintf('\nAll figures saved to: %s\n', figures_dir);
end
