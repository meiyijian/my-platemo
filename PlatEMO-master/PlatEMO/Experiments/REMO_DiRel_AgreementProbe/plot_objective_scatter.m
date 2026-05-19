function plot_objective_scatter()
% plot_objective_scatter - 图3：目标空间散点图（DTLZ2 M=3 散点 + MaF3 M=8 平行坐标）

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    fig_dir = fullfile(this_dir, 'figures');
    if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

    last_ckpt = 5;

    fig = figure('Position', [100, 100, 1300, 550]);

    % --- 左：DTLZ2 M=3，3D 散点 ---
    rec = load_one(results_dir, 'DTLZ2', 3, 1, last_ckpt);
    subplot(1, 2, 1);
    if ~isempty(rec)
        plot_scatter3(rec);
    else
        title('DTLZ2 M=3 run=1: missing');
    end

    % --- 右：MaF3 M=8，平行坐标 ---
    rec = load_one(results_dir, 'MaF3', 8, 1, last_ckpt);
    subplot(1, 2, 2);
    if ~isempty(rec)
        plot_parallel(rec);
    else
        title('MaF3 M=8 run=1: missing');
    end

    sgtitle('Two-network agreement vs conflict in objective space');
    saveas(fig, fullfile(fig_dir, 'fig3_objective_scatter.png'));
    savefig(fig, fullfile(fig_dir, 'fig3_objective_scatter.fig'));
    fprintf('Saved fig3 to %s\n', fig_dir);
end


function rec = load_one(results_dir, prob_name, M_val, run_id, ckpt_idx)
    fp = fullfile(results_dir, sprintf('probe_%s_M%d_run%d.mat', prob_name, M_val, run_id));
    rec = [];
    if ~exist(fp, 'file'); return; end
    S = load(fp);
    for k = 1:numel(S.probe_data)
        if S.probe_data{k}.checkpoint_idx == ckpt_idx
            rec = S.probe_data{k};
            rec.problem_name = S.problem_name;
            rec.M_val = S.M_val;
            return;
        end
    end
end


function [g, names, colors] = grouping(rec)
% 4 类：F+S+, F-S-, F+S-, F-S+ (按 PBI 标签是否 == 1)
    f = (rec.label_F == 1);
    s = (rec.label_S == 1);
    g = zeros(numel(f), 1);
    g( f &  s) = 1;
    g(~f & ~s) = 2;
    g( f & ~s) = 3;
    g(~f &  s) = 4;
    names = {'F+ S+ (both +1)', 'F- S- (both non+1)', 'F+ S- (full only)', 'F- S+ (sub only)'};
    colors = [0.20, 0.40, 0.80;
              0.70, 0.70, 0.70;
              0.85, 0.40, 0.20;
              0.30, 0.70, 0.30];
end


function plot_scatter3(rec)
    Obj = rec.PopObj;
    [g, names, C] = grouping(rec);
    hold on;
    for cls = 1:4
        mask = (g == cls);
        if any(mask)
            scatter3(Obj(mask, 1), Obj(mask, 2), Obj(mask, 3), 60, C(cls, :), ...
                'filled', 'MarkerEdgeColor', 'k', 'DisplayName', names{cls});
        end
    end
    xlabel('f_1'); ylabel('f_2'); zlabel('f_3');
    title(sprintf('%s M=%d, gen=%d (L1=%.2f)', rec.problem_name, rec.M_val, rec.gen, rec.agree_L1));
    view(45, 25); grid on;
    legend('Location', 'eastoutside');
end


function plot_parallel(rec)
    Obj = rec.PopObj;
    M = size(Obj, 2);
    Obj_min = min(Obj, [], 1);
    Obj_rng = max(Obj, [], 1) - Obj_min;
    Obj_n = (Obj - Obj_min) ./ max(Obj_rng, 1e-12);
    [g, names, C] = grouping(rec);
    hold on;
    handles = gobjects(4, 1);
    for cls = 1:4
        mask = (g == cls);
        rows = find(mask);
        for i = 1:numel(rows)
            h = plot(1:M, Obj_n(rows(i), :), 'Color', [C(cls, :), 0.5], 'LineWidth', 1);
            if i == 1; handles(cls) = h; end
        end
    end
    xlabel('Objective index'); ylabel('Normalized value');
    title(sprintf('%s M=%d, gen=%d (L1=%.2f)', rec.problem_name, rec.M_val, rec.gen, rec.agree_L1));
    xticks(1:M); ylim([0, 1.05]); grid on;
    valid = isgraphics(handles);
    legend(handles(valid), names(valid), 'Location', 'eastoutside');
end
