function PlotDiagnostics_DiRel(Diag, saveDir)
% PlotDiagnostics_DiRel - 输出基础诊断图
%
% 推荐画的图（按论文价值排序）：
%   1. difficulty trajectory：每个目标 D_total 随代变化
%   2. label composition：每代每 expert 的 +/0/- 比例
%   3. expert reliability：validation error / brier 随代变化
%   4. score decomposition：mean R / U / Nov / Disagree 随代变化
%   5. archive minObj：每个目标历史最优随代变化
%
% 输入：
%   Diag    - LogDiagnostics_DiRel 累积的结构体
%   saveDir - 存图目录（可空，仅显示不存）

    if nargin < 2, saveDir = ''; end
    if ~isempty(saveDir) && ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end

    gens = 1:size(Diag.difficulty, 2);
    M    = size(Diag.difficulty, 1);

    % --- 1. difficulty trajectory ---
    figure('Visible', 'on'); hold on;
    for j = 1:M
        plot(gens, Diag.difficulty(j, :), 'LineWidth', 1.5, ...
             'DisplayName', sprintf('Obj %d', j));
    end
    xlabel('Generation'); ylabel('D_{total}'); title('Objective difficulty trajectory');
    legend('Location', 'bestoutside'); grid on;
    saveIfDir(saveDir, 'difficulty_trajectory.png');

    % --- 2. label composition ---
    if isfield(Diag, 'labelHist')
        K = size(Diag.labelHist{1}, 1);
        figure('Visible', 'on');
        for k = 1:K
            subplot(K, 1, k); hold on;
            G = numel(Diag.labelHist);
            P = zeros(G, 3);
            for g = 1:G
                lh = Diag.labelHist{g}(k, :);
                total = max(sum(lh), 1);
                P(g, :) = lh / total;
            end
            area(gens(1:G), P);
            ylim([0 1]); title(sprintf('Expert %d (subset size variable)', k));
            ylabel('label %');
            legend({'+1', '0', '-1'}, 'Location', 'eastoutside');
        end
        xlabel('Generation');
        saveIfDir(saveDir, 'label_composition.png');
    end

    % --- 3. expert reliability ---
    if isfield(Diag, 'expertValErr')
        figure('Visible', 'on');
        subplot(2, 1, 1);
        plot(gens, Diag.expertValErr', 'LineWidth', 1.5);
        ylabel('Validation error'); title('Expert reliability'); grid on;
        legend(arrayfun(@(k) sprintf('E%d', k), ...
            1:size(Diag.expertValErr, 1), 'UniformOutput', false), ...
            'Location', 'eastoutside');
        subplot(2, 1, 2);
        plot(gens, Diag.expertBrier', 'LineWidth', 1.5);
        ylabel('Brier'); xlabel('Generation'); grid on;
        saveIfDir(saveDir, 'expert_reliability.png');
    end

    % --- 4. score decomposition ---
    if isfield(Diag, 'scoreStats')
        figure('Visible', 'on'); hold on;
        plot(gens, Diag.scoreStats(1, :), '-o', 'DisplayName', 'mean weightedR');
        plot(gens, Diag.scoreStats(2, :), '-s', 'DisplayName', 'mean U');
        plot(gens, Diag.scoreStats(3, :), '-^', 'DisplayName', 'mean Nov');
        plot(gens, Diag.scoreStats(4, :), '-d', 'DisplayName', 'mean Disagree');
        xlabel('Generation'); ylabel('Component value');
        title('Score decomposition'); grid on; legend('Location', 'best');
        saveIfDir(saveDir, 'score_decomposition.png');
    end

    % --- 5. archive minObj per objective ---
    if isfield(Diag, 'archiveMinObjs')
        figure('Visible', 'on'); hold on;
        for j = 1:M
            plot(gens, Diag.archiveMinObjs(j, :), 'LineWidth', 1.5, ...
                 'DisplayName', sprintf('Obj %d', j));
        end
        xlabel('Generation'); ylabel('Archive min'); title('Per-objective best');
        legend('Location', 'bestoutside'); grid on;
        saveIfDir(saveDir, 'archive_minObj.png');
    end
end

function saveIfDir(dir, fname)
    if ~isempty(dir)
        try
            saveas(gcf, fullfile(dir, fname));
        catch
        end
    end
end
