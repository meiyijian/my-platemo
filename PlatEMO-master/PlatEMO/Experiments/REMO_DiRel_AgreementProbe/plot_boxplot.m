function plot_boxplot()
% plot_boxplot - 图2：末代（进度 80%）一致性箱线图

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    fig_dir = fullfile(this_dir, 'figures');
    if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

    problems = {{'DTLZ2', 3}, {'DTLZ2', 5}, {'MaF1', 5}, {'MaF3', 8}};
    last_ckpt = 5;     % 进度 80% 那一个 checkpoint
    levels = {'L1', 'L2', 'L3'};
    fld    = {'agree_L1', 'agree_L2', 'agree_L3'};

    vals = [];     % 数值
    grp_prob = {};  % 问题名
    grp_lvl = {};   % 层

    for pi = 1:numel(problems)
        prob_name = problems{pi}{1};
        M_val = problems{pi}{2};
        prob_label = sprintf('%s\\_M%d', prob_name, M_val);

        files = dir(fullfile(results_dir, sprintf('probe_%s_M%d_run*.mat', prob_name, M_val)));
        for fi = 1:numel(files)
            S = load(fullfile(results_dir, files(fi).name));
            rec = [];
            for k = 1:numel(S.probe_data)
                if S.probe_data{k}.checkpoint_idx == last_ckpt
                    rec = S.probe_data{k};
                end
            end
            if isempty(rec); continue; end
            for li = 1:3
                vals(end+1, 1) = rec.(fld{li}); %#ok<AGROW>
                grp_prob{end+1, 1} = prob_label; %#ok<AGROW>
                grp_lvl{end+1, 1} = levels{li}; %#ok<AGROW>
            end
        end
    end

    if isempty(vals)
        warning('No data found for boxplot.');
        return;
    end

    fig = figure('Position', [100, 100, 1100, 500]);
    % 用复合 group 让箱子按 problem 分组、层并排
    grp = strcat(grp_prob, '\_', grp_lvl);
    boxplot(vals, grp, 'LabelOrientation', 'inline');
    ylabel('Agreement ratio at final checkpoint (FE = 80% maxFE)');
    title('Per-problem per-level agreement distribution across 10 runs');
    ylim([0, 1]); grid on;

    saveas(fig, fullfile(fig_dir, 'fig2_boxplot_final.png'));
    savefig(fig, fullfile(fig_dir, 'fig2_boxplot_final.fig'));
    fprintf('Saved fig2 to %s\n', fig_dir);
end
