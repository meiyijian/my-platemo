function plot_line_over_gens()
% plot_line_over_gens - 图1：一致性随 checkpoint 进度变化的折线图（带误差带）

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    fig_dir = fullfile(this_dir, 'figures');
    if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

    problems = {{'DTLZ2', 3}, {'DTLZ2', 5}, {'MaF1', 5}, {'MaF3', 8}};
    checkpoints = [0.04, 0.20, 0.40, 0.60, 0.80];
    n_ckpt = numel(checkpoints);

    fig = figure('Position', [100, 100, 1200, 800]);
    for pi = 1:numel(problems)
        prob_name = problems{pi}{1};
        M_val = problems{pi}{2};

        files = dir(fullfile(results_dir, sprintf('probe_%s_M%d_run*.mat', prob_name, M_val)));
        if isempty(files)
            warning('No data for %s M=%d', prob_name, M_val);
            continue;
        end

        % 按 (ckpt_idx, run) 收集 L1/L2/L3
        L1 = nan(numel(files), n_ckpt);
        L2 = nan(numel(files), n_ckpt);
        L3 = nan(numel(files), n_ckpt);

        for fi = 1:numel(files)
            S = load(fullfile(results_dir, files(fi).name));
            for k = 1:numel(S.probe_data)
                rec = S.probe_data{k};
                ci = rec.checkpoint_idx;
                if isnan(L1(fi, ci)) || rec.gen > 0
                    % 一个 ckpt 一次值（取第一次命中），如果命中多次就用最新
                    L1(fi, ci) = rec.agree_L1;
                    L2(fi, ci) = rec.agree_L2;
                    L3(fi, ci) = rec.agree_L3;
                end
            end
        end

        subplot(2, 2, pi); hold on;
        plot_band(checkpoints, L1, [0.20, 0.40, 0.80], 'L1 PBI');
        plot_band(checkpoints, L2, [0.85, 0.40, 0.20], 'L2 mu-sign');
        plot_band(checkpoints, L3, [0.30, 0.70, 0.30], 'L3 pair-pred');
        xlabel('Progress (FE / maxFE)');
        ylabel('Agreement ratio');
        title(sprintf('%s (M=%d)', prob_name, M_val));
        ylim([0, 1]); xlim([0, 1]); grid on;
        legend('Location', 'southoutside', 'Orientation', 'horizontal');
    end

    sgtitle('REMO\_DiRel: full-net vs sub-net agreement over training progress');
    saveas(fig, fullfile(fig_dir, 'fig1_line_over_progress.png'));
    savefig(fig, fullfile(fig_dir, 'fig1_line_over_progress.fig'));
    fprintf('Saved fig1 to %s\n', fig_dir);
end


function plot_band(x, Y, rgb, name)
    mu = mean(Y, 1, 'omitnan');
    sd = std(Y, 0, 1, 'omitnan');
    valid = ~isnan(mu);
    x = x(valid); mu = mu(valid); sd = sd(valid);
    fill([x, fliplr(x)], [mu+sd, fliplr(mu-sd)], rgb, ...
         'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(x, mu, 'Color', rgb, 'LineWidth', 1.6, 'Marker', 'o', ...
         'MarkerFaceColor', rgb, 'DisplayName', name);
end
