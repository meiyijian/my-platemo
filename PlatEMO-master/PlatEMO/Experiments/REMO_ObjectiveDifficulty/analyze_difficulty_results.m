function analyze_difficulty_results()
% analyze_difficulty_results - 分析目标难度实验结果，生成 4 张图。
%
% Figure 1: Per-Objective Separation Gap 热力图
% Figure 2: Gap 随代数变化的折线图
% Figure 3: Per-Objective Dominance Rate 柱状图
% Figure 4: Gap CV（不均匀度）随 M 变化的折线图

    this_dir    = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    figures_dir = fullfile(this_dir, 'figures');
    if ~exist(figures_dir, 'dir')
        mkdir(figures_dir);
    end

    %% Load all .mat files
    files = dir(fullfile(results_dir, 'remo_*.mat'));
    if isempty(files)
        error('No result files found in %s. Run run_difficulty_experiment first.', results_dir);
    end

    % Organize: data.(problem).(M) = cell array of runs
    data = struct();
    problem_set = {};
    M_set = [];

    for fi = 1:numel(files)
        fname = files(fi).name;
        tokens = regexp(fname, '^remo_(\w+)_M(\d+)_run(\d+)\.mat$', 'tokens');
        if isempty(tokens)
            continue;
        end
        prob = tokens{1}{1};
        Mval = str2double(tokens{1}{2});
        % run = str2double(tokens{1}{3});  % not needed for aggregation

        loaded = load(fullfile(results_dir, fname));
        if ~isfield(loaded, 'gen_data')
            fprintf('WARNING: %s has no gen_data, skipping.\n', fname);
            continue;
        end

        field = sprintf('M%d', Mval);
        if ~isfield(data, prob) || ~isfield(data.(prob), field)
            data.(prob).(field) = {};
        end
        data.(prob).(field){end+1} = loaded.gen_data;

        if ~ismember(prob, problem_set)
            problem_set{end+1} = prob; %#ok<AGROW>
        end
        if ~ismember(Mval, M_set)
            M_set(end+1) = Mval; %#ok<AGROW>
        end
    end

    M_set = sort(M_set);
    nProb = numel(problem_set);
    nM    = numel(M_set);

    fprintf('Loaded data: %d problems, %d M values\n', nProb, nM);
    for pi = 1:nProb
        for mi = 1:nM
            field = sprintf('M%d', M_set(mi));
            if isfield(data, problem_set{pi}) && isfield(data.(problem_set{pi}), field)
                fprintf('  %s M=%d: %d runs\n', problem_set{pi}, M_set(mi), ...
                    numel(data.(problem_set{pi}).(field)));
            end
        end
    end

    %% =====================================================================
    %  Figure 1: Heatmap — Final-generation gap per objective
    %  =====================================================================
    fig1 = figure('Position', [50 50 1200 400], 'Visible', 'on');

    for pi = 1:nProb
        subplot(1, nProb, pi);
        prob = problem_set{pi};

        % Build heatmap matrix: rows = M values, cols = objectives
        maxM   = max(M_set);
        hm_data = NaN(nM, maxM);
        hm_text = cell(nM, maxM);

        for mi = 1:nM
            Mval  = M_set(mi);
            field = sprintf('M%d', Mval);
            if ~isfield(data.(prob), field)
                continue;
            end
            runs = data.(prob).(field);
            nRuns = numel(runs);

            % Collect last-generation gap for each run
            gap_last = zeros(nRuns, Mval);
            for ri = 1:nRuns
                gd = runs{ri};
                if isempty(gd)
                    continue;
                end
                gap_last(ri, :) = gd{end}.gap;
            end

            avg_gap = mean(gap_last, 1);
            hm_data(mi, 1:Mval) = avg_gap;
            for m = 1:Mval
                hm_text{mi, m} = sprintf('%.2f', avg_gap(m));
            end
        end

        imagesc(hm_data);
        colormap(hot);
        cb = colorbar;
        cb.Label.String = "Cohen's d (separation gap)";

        % Add text annotations
        for mi = 1:nM
            for m = 1:M_set(mi)
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

        set(gca, 'YTick', 1:nM, 'YTickLabel', arrayfun(@(x)sprintf('M=%d',x), M_set, 'Uni', 0));
        set(gca, 'XTick', 1:maxM);
        xlabel('Objective index');
        ylabel('Number of objectives');
        title(sprintf('%s: Separation Gap', prob), 'Interpreter', 'none');
        set(gca, 'TickLabelInterpreter', 'none');
    end

    saveas(fig1, fullfile(figures_dir, 'fig1_heatmap_gap.png'));
    savefig(fig1, fullfile(figures_dir, 'fig1_heatmap_gap.fig'));
    fprintf('Saved fig1_heatmap_gap.png\n');

    %% =====================================================================
    %  Figure 2: Line plot — Gap per objective over generations
    %  =====================================================================
    % Pick one problem (DTLZ2) and show gap evolution for each M
    target_prob = 'DTLZ2';
    if ~ismember(target_prob, problem_set)
        target_prob = problem_set{1};
    end

    fig2 = figure('Position', [50 50 1400 800], 'Visible', 'on');
    nSub = nM;

    for mi = 1:nM
        subplot(2, ceil(nSub/2), mi);
        Mval  = M_set(mi);
        field = sprintf('M%d', Mval);
        if ~isfield(data.(target_prob), field)
            continue;
        end
        runs  = data.(target_prob).(field);
        nRuns = numel(runs);

        % Collect gap over generations: nRuns x nGens x Mval
        nGens = numel(runs{1});
        gap_over_gens = zeros(nRuns, nGens, Mval);
        for ri = 1:nRuns
            gd = runs{ri};
            for g = 1:numel(gd)
                gap_over_gens(ri, g, :) = gd{g}.gap;
            end
        end

        avg_gap = squeeze(mean(gap_over_gens, 1));  % nGens x Mval
        gen_idx = 1:size(avg_gap, 1);

        colors = lines(Mval);
        hold on;
        for m = 1:Mval
            plot(gen_idx, avg_gap(:, m), '-', 'Color', colors(m,:), ...
                'LineWidth', 1.2, 'DisplayName', sprintf('Obj %d', m));
        end
        hold off;

        xlabel('Generation');
        ylabel("Cohen's d");
        title(sprintf('%s M=%d', target_prob, Mval), 'Interpreter', 'none');
        legend('Location', 'best', 'FontSize', 7);
        grid on;
    end

    sgtitle(sprintf('Per-Objective Separation Gap Evolution (%s)', target_prob), ...
        'Interpreter', 'none');
    saveas(fig2, fullfile(figures_dir, 'fig2_gap_evolution.png'));
    savefig(fig2, fullfile(figures_dir, 'fig2_gap_evolution.fig'));
    fprintf('Saved fig2_gap_evolution.png\n');

    %% =====================================================================
    %  Figure 3: Bar chart — Final dominance rate per objective
    %  =====================================================================
    fig3 = figure('Position', [50 50 1200 800], 'Visible', 'on');

    for pi = 1:nProb
        subplot(1, nProb, pi);
        prob = problem_set{pi};

        legend_entries = {};
        bar_data = [];
        bar_idx  = [];

        for mi = 1:nM
            Mval  = M_set(mi);
            field = sprintf('M%d', Mval);
            if ~isfield(data.(prob), field)
                continue;
            end
            runs = data.(prob).(field);
            nRuns = numel(runs);

            dom_last = zeros(nRuns, Mval);
            for ri = 1:nRuns
                gd = runs{ri};
                dom_last(ri, :) = gd{end}.dom_rate;
            end

            avg_dom = mean(dom_last, 1);
            bar_data = [bar_data; avg_dom]; %#ok<AGROW>
            bar_idx  = [bar_idx; Mval]; %#ok<AGROW>
            legend_entries{end+1} = sprintf('M=%d', Mval); %#ok<AGROW>
        end

        if isempty(bar_data)
            continue;
        end

        b = bar(bar_data');
        colormap(lines(nM));
        xlabel('Objective index');
        ylabel('Dominance rate (good < bad)');
        title(sprintf('%s: Per-Obj Dominance', prob), 'Interpreter', 'none');
        legend(legend_entries, 'Location', 'best', 'FontSize', 7);
        grid on;
        set(gca, 'XTick', 1:max(M_set));
    end

    sgtitle('Per-Objective Dominance Rate (Final Generation)', 'Interpreter', 'none');
    saveas(fig3, fullfile(figures_dir, 'fig3_dominance_rate.png'));
    savefig(fig3, fullfile(figures_dir, 'fig3_dominance_rate.fig'));
    fprintf('Saved fig3_dominance_rate.png\n');

    %% =====================================================================
    %  Figure 4: Gap CV (unevenness) vs M
    %  =====================================================================
    fig4 = figure('Position', [50 50 800 500], 'Visible', 'on');
    hold on;

    markers = {'o', 's', 'd', '^', 'v', 'p'};
    colors  = lines(nProb);

    for pi = 1:nProb
        prob = problem_set{pi};
        cv_vals = zeros(1, nM);

        for mi = 1:nM
            Mval  = M_set(mi);
            field = sprintf('M%d', Mval);
            if ~isfield(data.(prob), field)
                cv_vals(mi) = NaN;
                continue;
            end
            runs = data.(prob).(field);
            nRuns = numel(runs);

            cv_last = zeros(1, nRuns);
            for ri = 1:nRuns
                gd = runs{ri};
                cv_last(ri) = gd{end}.gap_cv;
            end
            cv_vals(mi) = mean(cv_last, 'omitnan');
        end

        plot(M_set, cv_vals, ['-' markers{pi}], ...
            'Color', colors(pi,:), 'LineWidth', 1.5, ...
            'MarkerSize', 8, 'MarkerFaceColor', colors(pi,:), ...
            'DisplayName', prob);
    end

    hold off;
    xlabel('Number of objectives (M)');
    ylabel('Gap CV (coefficient of variation)');
    title('Objective Difficulty Unevenness vs M', 'Interpreter', 'none');
    legend('Location', 'best', 'Interpreter', 'none');
    grid on;
    set(gca, 'XTick', M_set);

    saveas(fig4, fullfile(figures_dir, 'fig4_gap_cv_vs_M.png'));
    savefig(fig4, fullfile(figures_dir, 'fig4_gap_cv_vs_M.fig'));
    fprintf('Saved fig4_gap_cv_vs_M.png\n');

    %% Summary table
    fprintf('\n=== Summary: Mean Gap CV (last generation) ===\n');
    fprintf('%-10s', 'Problem');
    for mi = 1:nM
        fprintf('%8s', sprintf('M=%d', M_set(mi)));
    end
    fprintf('\n');

    for pi = 1:nProb
        prob = problem_set{pi};
        fprintf('%-10s', prob);
        for mi = 1:nM
            Mval  = M_set(mi);
            field = sprintf('M%d', Mval);
            if ~isfield(data.(prob), field)
                fprintf('%8s', '-');
                continue;
            end
            runs = data.(prob).(field);
            nRuns = numel(runs);
            cv_last = zeros(1, nRuns);
            for ri = 1:nRuns
                gd = runs{ri};
                cv_last(ri) = gd{end}.gap_cv;
            end
            fprintf('%8.3f', mean(cv_last, 'omitnan'));
        end
        fprintf('\n');
    end
    fprintf('\n');
end
