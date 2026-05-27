function analyze_dualnet_results(varargin)
% analyze_dualnet_results - 分析双网络探针实验结果，生成CSV和图表。
%
% Usage:
%   analyze_dualnet_results                    % 分析 results/ 下所有 .mat
%   analyze_dualnet_results('fig', true)       % 同时生成图表

    p = inputParser;
    p.addParameter('results_dir', '');
    p.addParameter('fig', true);
    p.parse(varargin{:});
    opt = p.Results;

    this_dir = fileparts(mfilename('fullpath'));
    if isempty(opt.results_dir)
        opt.results_dir = fullfile(this_dir, 'results');
    end
    out_dir = fullfile(this_dir, 'output');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    % ================================================================
    % 加载所有结果文件
    % ================================================================
    files = dir(fullfile(opt.results_dir, 'dualnet_*.mat'));
    if isempty(files)
        error('No result files found in %s. Run run_dualnet_experiment first.', opt.results_dir);
    end
    fprintf('Found %d result files.\n', numel(files));

    % ================================================================
    % 汇总所有 run 的逐代数据
    % ================================================================
    all_gen_rows = {};   % 每代的汇总统计
    all_cand_rows = {};  % 每候选的详细数据

    for fi = 1:numel(files)
        fpath = fullfile(files(fi).folder, files(fi).name);
        fprintf('Loading %s ... ', files(fi).name);
        data = load(fpath);

        % 提取文件名中的问题信息
        fname = files(fi).name;
        tokens = regexp(fname, 'dualnet_(\w+)_M(\d+)_run(\d+)', 'tokens');
        if ~isempty(tokens)
            prob_name = tokens{1}{1};
            M_val = str2double(tokens{1}{2});
            run_id = str2double(tokens{1}{3});
        else
            prob_name = 'unknown';
            M_val = 0;
            run_id = fi;
        end

        % --- 处理逐代数据 ---
        if isfield(data, 'gen_data')
            for gi = 1:numel(data.gen_data)
                gd = data.gen_data{gi};
                row = {prob_name, M_val, run_id, gd.gen, gd.FE, ...
                       gd.N, gd.M, gd.p_err_F, gd.p_err_S, ...
                       numel(gd.S_easy), mat2str(gd.S_easy)};
                all_gen_rows{end+1} = row; %#ok<AGROW>
            end
        end

        % --- 处理逐候选数据 ---
        if isfield(data, 'probe_data')
            for pi = 1:numel(data.probe_data)
                pd = data.probe_data{pi};
                nC = pd.nCand;
                % 兼容旧数据：新字段缺失时 fallback
                has_real_obj = isfield(pd, 'has_real_obj') && pd.has_real_obj;
                if isfield(pd, 'true_quality_nn')
                    tq_nn_vec = pd.true_quality_nn;
                else
                    tq_nn_vec = nan(nC, 1);
                end
                % 消融 A：子空间真值（同源评估 S 网络）。
                % 新格式直接读字段；旧 .mat 用 CandObj_real + S_easy + PopObj 现算。
                if isfield(pd, 'true_quality_S')
                    tq_S_vec = pd.true_quality_S;
                elseif isfield(pd, 'CandObj_real') && isfield(pd, 'S_easy') && isfield(pd, 'PopObj')
                    Se = double(pd.S_easy(:)');
                    tq_S_vec = local_subspace_true_quality( ...
                        pd.CandObj_real(:, Se), pd.PopObj(:, Se));
                else
                    tq_S_vec = nan(nC, 1);
                end
                for ci = 1:nC
                    % 确定冲突类型
                    if pd.abstain(ci)
                        ctype = 'abstain';
                    elseif pd.subwin(ci)
                        ctype = 'subwin';
                    elseif pd.conflict(ci)
                        ctype = 'conflict';
                    else
                        ctype = 'agree';
                    end

                    cand_row = {prob_name, M_val, run_id, pd.gen, ci, ...
                        pd.mu_F(ci), pd.sigma2_F(ci), pd.tildeS_F(ci), ...
                        pd.mu_S(ci), pd.sigma2_S(ci), pd.tildeS_S(ci), ...
                        pd.w_F(ci), pd.base(ci), ...
                        sign(pd.mu_F(ci)), sign(pd.mu_S(ci)), ...
                        pd.true_quality(ci), ...
                        pd.dominated_by_pop(ci), pd.dominates_pop(ci), ...
                        pd.Catalog_cand_F(ci), pd.Catalog_cand_S(ci), ...
                        ctype, ...
                        tq_nn_vec(ci), double(has_real_obj), ...
                        tq_S_vec(ci)};
                    all_cand_rows{end+1} = cand_row; %#ok<AGROW>
                end
            end
        end
        fprintf('done (%d gen records, %d cand records)\n', ...
            numel(data.gen_data), numel(data.probe_data));
    end

    % ================================================================
    % CSV 1: 逐代汇总统计
    % ================================================================
    gen_headers = {'problem', 'M', 'run', 'gen', 'FE', 'N', 'M_total', ...
                   'p_err_F', 'p_err_S', 'k_easy', 'S_easy'};
    gen_csv = fullfile(out_dir, 'per_generation_summary.csv');
    write_csv(gen_csv, gen_headers, all_gen_rows);
    fprintf('Wrote: %s\n', gen_csv);

    % ================================================================
    % CSV 2: 逐候选详细数据
    % ================================================================
    cand_headers = {'problem', 'M', 'run', 'gen', 'cand_idx', ...
                    'mu_F', 'sigma2_F', 'tildeS_F', ...
                    'mu_S', 'sigma2_S', 'tildeS_S', ...
                    'w_F', 'base_score', ...
                    'sign_F', 'sign_S', ...
                    'true_quality', ...
                    'dominated_by_pop', 'dominates_pop', ...
                    'catalog_F', 'catalog_S', ...
                    'conflict_type', ...
                    'true_quality_nn', 'has_real_obj', ...
                    'true_quality_S'};
    cand_csv = fullfile(out_dir, 'per_candidate_detail.csv');
    write_csv(cand_csv, cand_headers, all_cand_rows);
    fprintf('Wrote: %s\n', cand_csv);

    % ================================================================
    % CSV 3: 跨问题汇总对比
    % ================================================================
    summary_csv = fullfile(out_dir, 'cross_problem_summary.csv');
    write_cross_problem_summary(summary_csv, all_cand_rows, all_gen_rows);
    fprintf('Wrote: %s\n', summary_csv);

    % ================================================================
    % CSV 4: 冲突分析汇总
    % ================================================================
    conflict_csv = fullfile(out_dir, 'conflict_analysis.csv');
    write_conflict_analysis(conflict_csv, all_cand_rows);
    fprintf('Wrote: %s\n', conflict_csv);

    % ================================================================
    % CSV 5: 子空间消融分析（消融 A）
    % S 网络在其原生子目标空间下的同源评估，破除评估口径不一致问题。
    % ================================================================
    subspace_csv = fullfile(out_dir, 'subspace_ablation.csv');
    write_subspace_ablation(subspace_csv, all_cand_rows);
    fprintf('Wrote: %s\n', subspace_csv);

    % ================================================================
    % 图表
    % ================================================================
    if opt.fig
        fig_dir = fullfile(out_dir, 'figures');
        if ~exist(fig_dir, 'dir')
            mkdir(fig_dir);
        end
        generate_figures(all_cand_rows, all_gen_rows, fig_dir);
        fprintf('Figures saved to: %s\n', fig_dir);
    end

    fprintf('Analysis complete.\n');
end


%% ========================================================================
%  CSV 输出函数
%  ========================================================================

function write_csv(fpath, headers, rows)
    fid = fopen(fpath, 'w');
    fprintf(fid, '%s\n', strjoin(headers, ','));
    for i = 1:numel(rows)
        row = rows{i};
        for j = 1:numel(row)
            val = row{j};
            if isnumeric(val)
                if isnan(val)
                    fprintf(fid, 'NaN');
                elseif islogical(val)
                    fprintf(fid, '%d', val);
                else
                    fprintf(fid, '%.6g', val);
                end
            elseif ischar(val)
                fprintf(fid, '%s', val);
            elseif islogical(val)
                fprintf(fid, '%d', val);
            end
            if j < numel(row)
                fprintf(fid, ',');
            end
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end


function write_cross_problem_summary(fpath, cand_rows, gen_rows)
% 按问题汇总关键指标
    fid = fopen(fpath, 'w');
    fprintf(fid, '%s\n', strjoin({...
        'problem', 'M', 'n_runs', 'n_generations', 'n_candidates', ...
        'agree_sign_mean', 'agree_sign_std', ...
        'conflict_rate_mean', 'conflict_rate_std', ...
        'abstain_rate_mean', 'abstain_rate_std', ...
        'subwin_rate_mean', 'subwin_rate_std', ...
        'w_F_mean', 'w_F_std', ...
        'acc_F_mean', 'acc_F_std', ...
        'acc_S_mean', 'acc_S_std', ...
        'acc_F_conflict_mean', 'acc_S_conflict_mean', ...
        'p_err_F_mean', 'p_err_S_mean', ...
        'sel_overlap_FS_mean', 'sel_only_F_mean', 'sel_only_S_mean', ...
        'acc_F_nn_mean', 'acc_S_nn_mean', 'label_agree_real_nn_mean', 'has_real_obj_pct' ...
    }, ','));

    % 按问题分组
    problems = {};
    for i = 1:numel(cand_rows)
        key = sprintf('%s_M%d', cand_rows{i}{1}, cand_rows{i}{2});
        if ~ismember(key, problems)
            problems{end+1} = key; %#ok<AGROW>
        end
    end

    for pi = 1:numel(problems)
        key = problems{pi};
        tokens = regexp(key, '(\w+)_M(\d+)', 'tokens');
        pname = tokens{1}{1};
        Mval = str2double(tokens{1}{2});

        % 收集该问题的所有候选数据
        p_mu_F = []; p_mu_S = []; p_w_F = []; p_base = [];
        p_true = []; p_conflict = []; p_abstain = []; p_subwin = [];
        p_cand_F = []; p_cand_S = [];
        p_tildeS_F = []; p_tildeS_S = [];
        p_true_nn = []; p_has_real = [];
        runs = [];
        gen_list = [];

        for ci = 1:numel(cand_rows)
            cr = cand_rows{ci};
            if ~strcmp(cr{1}, pname) || cr{2} ~= Mval
                continue;
            end
            ncol = numel(cr);
            p_mu_F(end+1) = cr{6}; %#ok<AGROW>
            p_mu_S(end+1) = cr{9}; %#ok<AGROW>
            p_w_F(end+1) = cr{12}; %#ok<AGROW>
            p_base(end+1) = cr{13}; %#ok<AGROW>
            p_true(end+1) = cr{16}; %#ok<AGROW>
            p_cand_F(end+1) = cr{19}; %#ok<AGROW>
            p_cand_S(end+1) = cr{20}; %#ok<AGROW>
            p_tildeS_F(end+1) = cr{8}; %#ok<AGROW>
            p_tildeS_S(end+1) = cr{11}; %#ok<AGROW>
            runs(end+1) = cr{3}; %#ok<AGROW>
            gen_list(end+1) = cr{4}; %#ok<AGROW>

            % NN baseline 字段（旧数据缺失则为 NaN/0）
            % 新格式 23 列：21=conflict_type, 22=true_quality_nn, 23=has_real_obj
            if ncol >= 22
                p_true_nn(end+1) = cr{22}; %#ok<AGROW>
            else
                p_true_nn(end+1) = NaN; %#ok<AGROW>
            end
            if ncol >= 23
                p_has_real(end+1) = cr{23}; %#ok<AGROW>
            else
                p_has_real(end+1) = 0; %#ok<AGROW>
            end

            % 安全获取冲突类型（兼容21列和22列）
            ct = get_ctype_safe(cr, ncol);
            is_confl = ~strcmp(ct, 'agree');
            p_conflict(end+1) = is_confl; %#ok<AGROW>
            p_abstain(end+1) = strcmp(ct, 'abstain'); %#ok<AGROW>
            p_subwin(end+1) = strcmp(ct, 'subwin'); %#ok<AGROW>
        end

        if isempty(p_mu_F)
            continue;
        end

        n_runs = numel(unique(runs));
        n_gens = numel(unique(gen_list));

        acc_F = mean(sign(p_mu_F) == p_true);
        acc_S = mean(sign(p_mu_S) == p_true);

        confl_mask = p_conflict > 0;
        if any(confl_mask)
            acc_F_c = mean(sign(p_mu_F(confl_mask)) == p_true(confl_mask));
            acc_S_c = mean(sign(p_mu_S(confl_mask)) == p_true(confl_mask));
        else
            acc_F_c = NaN; acc_S_c = NaN;
        end

        threshold = 3.9;
        sel_F = p_tildeS_F > threshold;
        sel_S = p_tildeS_S > threshold;

        % 收集p_err
        p_err_F_vals = []; p_err_S_vals = [];
        for gi = 1:numel(gen_rows)
            gr = gen_rows{gi};
            if strcmp(gr{1}, pname) && gr{2} == Mval
                p_err_F_vals(end+1) = gr{8}; %#ok<AGROW>
                p_err_S_vals(end+1) = gr{9}; %#ok<AGROW>
            end
        end

        % NN baseline 准确率（与 NN 假冒 ground truth 对比）
        nn_valid = ~isnan(p_true_nn);
        if any(nn_valid)
            acc_F_nn = mean(sign(p_mu_F(nn_valid)) == p_true_nn(nn_valid));
            acc_S_nn = mean(sign(p_mu_S(nn_valid)) == p_true_nn(nn_valid));
            label_agree_real_nn = mean(p_true(nn_valid) == p_true_nn(nn_valid));
        else
            acc_F_nn = NaN; acc_S_nn = NaN; label_agree_real_nn = NaN;
        end
        has_real_pct = mean(p_has_real) * 100;

        fprintf(fid, '%s,%d,%d,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f\n', ...
            pname, Mval, n_runs, n_gens, numel(p_mu_F), ...
            mean(sign(p_mu_F) == sign(p_mu_S)), std(sign(p_mu_F) == sign(p_mu_S)), ...
            mean(p_conflict), std(double(p_conflict)), ...
            mean(p_abstain), std(double(p_abstain)), ...
            mean(p_subwin), std(double(p_subwin)), ...
            mean(p_w_F), std(p_w_F), ...
            acc_F, 0, acc_S, 0, ...
            acc_F_c, acc_S_c, ...
            mean(p_err_F_vals), mean(p_err_S_vals), ...
            mean(sel_F & sel_S), mean(sel_F & ~sel_S), mean(sel_S & ~sel_F), ...
            acc_F_nn, acc_S_nn, label_agree_real_nn, has_real_pct);
    end
    fclose(fid);
end


function write_conflict_analysis(fpath, cand_rows)
% 冲突场景详细分析
    fid = fopen(fpath, 'w');
    fprintf(fid, '%s\n', strjoin({...
        'problem', 'M', 'conflict_type', 'count', 'pct', ...
        'mean_w_F', 'mean_mu_F', 'mean_mu_S', ...
        'acc_F', 'acc_S', 'acc_winner', ...
        'mean_true_quality', 'pct_dominated' ...
    }, ','));

    % 按问题分组
    problems = {};
    for i = 1:numel(cand_rows)
        key = sprintf('%s_M%d', cand_rows{i}{1}, cand_rows{i}{2});
        if ~ismember(key, problems)
            problems{end+1} = key; %#ok<AGROW>
        end
    end

    conflict_types = {'agree', 'conflict', 'abstain', 'subwin'};

    for pi = 1:numel(problems)
        key = problems{pi};
        tokens = regexp(key, '(\w+)_M(\d+)', 'tokens');
        pname = tokens{1}{1};
        Mval = str2double(tokens{1}{2});

        % 收集该问题数据
        mu_F_all = []; mu_S_all = []; w_F_all = [];
        true_all = []; ctype_all = {};
        dom_all = [];

        for ci = 1:numel(cand_rows)
            cr = cand_rows{ci};
            if strcmp(cr{1}, pname) && cr{2} == Mval
                mu_F_all(end+1) = cr{6}; %#ok<AGROW>
                mu_S_all(end+1) = cr{9}; %#ok<AGROW>
                w_F_all(end+1) = cr{12}; %#ok<AGROW>
                true_all(end+1) = cr{16}; %#ok<AGROW>
                ctype_all{end+1} = get_ctype_safe(cr, numel(cr)); %#ok<AGROW>
                dom_all(end+1) = cr{17}; %#ok<AGROW>
            end
        end

        if isempty(mu_F_all)
            continue;
        end

        n_total = numel(mu_F_all);

        for ti = 1:numel(conflict_types)
            ct = conflict_types{ti};
            mask = strcmp(ctype_all, ct);
            n_ct = sum(mask);
            if n_ct == 0
                fprintf(fid, '%s,%d,%s,0,0,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n', ...
                    pname, Mval, ct);
                continue;
            end

            pct = n_ct / n_total * 100;
            mwf = mean(w_F_all(mask));
            mmf = mean(mu_F_all(mask));
            mms = mean(mu_S_all(mask));

            acc_F = mean(sign(mu_F_all(mask)) == true_all(mask));
            acc_S = mean(sign(mu_S_all(mask)) == true_all(mask));
            if acc_F > acc_S
                winner = 'F';
            elseif acc_S > acc_F
                winner = 'S';
            else
                winner = 'tie';
            end

            mtq = mean(true_all(mask));
            pd  = mean(dom_all(mask)) * 100;

            fprintf(fid, '%s,%d,%s,%d,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%.4f,%.1f\n', ...
                pname, Mval, ct, n_ct, pct, mwf, mmf, mms, acc_F, acc_S, winner, mtq, pd);
        end
    end
    fclose(fid);
end


%% ========================================================================
%  图表生成
%  ========================================================================

function generate_figures(cand_rows, gen_rows, fig_dir)
    fprintf('Generating figures...\n');

    % 按问题分组
    problems = {};
    for i = 1:numel(cand_rows)
        key = sprintf('%s_M%d', cand_rows{i}{1}, cand_rows{i}{2});
        if ~ismember(key, problems)
            problems{end+1} = key; %#ok<AGROW>
        end
    end

    for pi = 1:numel(problems)
        key = problems{pi};
        tokens = regexp(key, '(\w+)_M(\d+)', 'tokens');
        pname = tokens{1}{1};
        Mval = str2double(tokens{1}{2});

        % 收集数据
        mu_F = []; mu_S = []; w_F = []; base = [];
        true_q = []; gen_list = []; ctype = {};
        tildeS_F = []; tildeS_S = [];

        for ci = 1:numel(cand_rows)
            cr = cand_rows{ci};
            if strcmp(cr{1}, pname) && cr{2} == Mval
                mu_F(end+1) = cr{6}; %#ok<AGROW>
                mu_S(end+1) = cr{9}; %#ok<AGROW>
                w_F(end+1) = cr{12}; %#ok<AGROW>
                base(end+1) = cr{13}; %#ok<AGROW>
                true_q(end+1) = cr{16}; %#ok<AGROW>
                gen_list(end+1) = cr{4}; %#ok<AGROW>
                ctype{end+1} = get_ctype_safe(cr, numel(cr)); %#ok<AGROW>
                tildeS_F(end+1) = cr{8}; %#ok<AGROW>
                tildeS_S(end+1) = cr{11}; %#ok<AGROW>
            end
        end

        if isempty(mu_F)
            continue;
        end

        ugens = unique(gen_list);

        % --- Figure 1: mu_F vs mu_S 散点图 ---
        fig1 = figure('Visible', 'off', 'Position', [100 100 800 700]);
        hold on;
        agree_mask = strcmp(ctype, 'agree');
        confl_mask = strcmp(ctype, 'conflict');
        abst_mask  = strcmp(ctype, 'abstain');
        subw_mask  = strcmp(ctype, 'subwin');

        scatter(mu_F(agree_mask), mu_S(agree_mask), 20, [0.3 0.7 0.3], 'filled', 'MarkerFaceAlpha', 0.4);
        scatter(mu_F(confl_mask), mu_S(confl_mask), 30, [0.9 0.3 0.3], 'filled', 'MarkerFaceAlpha', 0.6);
        scatter(mu_F(abst_mask), mu_S(abst_mask), 30, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha', 0.6);
        scatter(mu_F(subw_mask), mu_S(subw_mask), 30, [0.3 0.3 0.9], 'filled', 'MarkerFaceAlpha', 0.6);

        xlim_vals = [min(mu_F)-0.1, max(mu_F)+0.1];
        ylim_vals = [min(mu_S)-0.1, max(mu_S)+0.1];
        plot(xlim_vals, [0 0], 'k--', 'LineWidth', 0.5);
        plot([0 0], ylim_vals, 'k--', 'LineWidth', 0.5);
        plot(xlim_vals, xlim_vals, 'k:', 'LineWidth', 0.5);

        xlabel('\mu_F (Full-objective network)');
        ylabel('\mu_S (Sub-objective network)');
        title(sprintf('%s M=%d: \\mu_F vs \\mu_S', pname, Mval));
        legend({'Agree', 'Conflict', 'Abstain', 'SubWin'}, 'Location', 'best');
        grid on;
        hold off;
        saveas(fig1, fullfile(fig_dir, sprintf('%s_M%d_mu_scatter.png', pname, Mval)));
        close(fig1);

        % --- Figure 2: 指标随代数变化 ---
        acc_F_per_gen = zeros(size(ugens));
        acc_S_per_gen = zeros(size(ugens));
        conflict_per_gen = zeros(size(ugens));
        w_F_per_gen = zeros(size(ugens));
        agree_per_gen = zeros(size(ugens));

        for gi = 1:numel(ugens)
            gmask = gen_list == ugens(gi);
            acc_F_per_gen(gi) = mean(sign(mu_F(gmask)) == true_q(gmask));
            acc_S_per_gen(gi) = mean(sign(mu_S(gmask)) == true_q(gmask));
            conflict_per_gen(gi) = mean(~strcmp(ctype(gmask), 'agree'));
            w_F_per_gen(gi) = mean(w_F(gmask));
            agree_per_gen(gi) = mean(sign(mu_F(gmask)) == sign(mu_S(gmask)));
        end

        fig2 = figure('Visible', 'off', 'Position', [100 100 1200 800]);

        subplot(2,2,1);
        plot(ugens, acc_F_per_gen, 'b-o', 'LineWidth', 1.5); hold on;
        plot(ugens, acc_S_per_gen, 'r-s', 'LineWidth', 1.5);
        xlabel('Generation'); ylabel('Accuracy');
        title('Prediction Accuracy (sign vs true quality)');
        legend('Full net', 'Sub net', 'Location', 'best');
        grid on;

        subplot(2,2,2);
        plot(ugens, conflict_per_gen, 'r-o', 'LineWidth', 1.5);
        xlabel('Generation'); ylabel('Conflict Rate');
        title('Model Conflict Rate');
        grid on;

        subplot(2,2,3);
        plot(ugens, w_F_per_gen, 'b-o', 'LineWidth', 1.5); hold on;
        plot(ugens, 1-w_F_per_gen, 'r-s', 'LineWidth', 1.5);
        xlabel('Generation'); ylabel('Mean Weight');
        title('Fusion Weight w_F and w_S');
        legend('w_F', 'w_S', 'Location', 'best');
        grid on;

        subplot(2,2,4);
        plot(ugens, agree_per_gen, 'g-o', 'LineWidth', 1.5);
        xlabel('Generation'); ylabel('Agreement Rate');
        title('Sign Agreement Rate');
        grid on;

        sgtitle(sprintf('%s M=%d: Dual Network Metrics Over Generations', pname, Mval));
        saveas(fig2, fullfile(fig_dir, sprintf('%s_M%d_metrics_over_gens.png', pname, Mval)));
        close(fig2);

        % --- Figure 3: 权重分布直方图 ---
        fig3 = figure('Visible', 'off', 'Position', [100 100 800 400]);
        subplot(1,2,1);
        histogram(w_F, 30, 'FaceColor', [0.3 0.5 0.8]);
        xlabel('w_F'); ylabel('Count');
        title('Distribution of w_F (Full net weight)');
        xline(0.5, 'r--', 'LineWidth', 1.5);
        grid on;

        subplot(1,2,2);
        scatter(w_F, true_q, 15, [0.3 0.5 0.8], 'filled', 'MarkerFaceAlpha', 0.3);
        xlabel('w_F'); ylabel('True Quality');
        title('w_F vs True Quality');
        grid on;

        sgtitle(sprintf('%s M=%d: Weight Analysis', pname, Mval));
        saveas(fig3, fullfile(fig_dir, sprintf('%s_M%d_weight_analysis.png', pname, Mval)));
        close(fig3);

        % --- Figure 4: 冲突场景下两模型准确率对比 ---
        fig4 = figure('Visible', 'off', 'Position', [100 100 600 500]);
        confl_mask_all = ~strcmp(ctype, 'agree');
        if any(confl_mask_all)
            acc_F_confl = mean(sign(mu_F(confl_mask_all)) == true_q(confl_mask_all));
            acc_S_confl = mean(sign(mu_S(confl_mask_all)) == true_q(confl_mask_all));
            bar_data = [acc_F_confl, acc_S_confl];
            b = bar(bar_data);
            b.FaceColor = 'flat';
            b.CData(1,:) = [0.3 0.5 0.8];
            b.CData(2,:) = [0.9 0.3 0.3];
            set(gca, 'XTickLabel', {'Full net (F)', 'Sub net (S)'});
            ylabel('Accuracy');
            title(sprintf('%s M=%d: Accuracy in Conflict Scenarios', pname, Mval));
            grid on;
        end
        saveas(fig4, fullfile(fig_dir, sprintf('%s_M%d_conflict_accuracy.png', pname, Mval)));
        close(fig4);

        % --- Figure 5: 选择一致性分析 ---
        fig5 = figure('Visible', 'off', 'Position', [100 100 800 400]);
        threshold = 3.9;
        sel_F = tildeS_F > threshold;
        sel_S = tildeS_S > threshold;
        sel_fused = base > threshold;

        subplot(1,2,1);
        venn_data = [sum(sel_F & sel_S), sum(sel_F & ~sel_S), sum(sel_S & ~sel_F)];
        bar(venn_data);
        set(gca, 'XTickLabel', {'Both', 'F only', 'S only'});
        ylabel('Count');
        title('Selection Overlap');
        grid on;

        subplot(1,2,2);
        % 各策略选择的候选的真实质量
        if any(sel_F)
            q_F = mean(true_q(sel_F));
        else
            q_F = 0;
        end
        if any(sel_S)
            q_S = mean(true_q(sel_S));
        else
            q_S = 0;
        end
        if any(sel_fused)
            q_fused = mean(true_q(sel_fused));
        else
            q_fused = 0;
        end
        bar([q_F, q_S, q_fused]);
        set(gca, 'XTickLabel', {'Full only', 'Sub only', 'Fused'});
        ylabel('Mean True Quality');
        title('Selected Candidate Quality');
        grid on;

        sgtitle(sprintf('%s M=%d: Selection Analysis', pname, Mval));
        saveas(fig5, fullfile(fig_dir, sprintf('%s_M%d_selection_analysis.png', pname, Mval)));
        close(fig5);

        fprintf('  Generated 5 figures for %s M=%d\n', pname, Mval);
    end

    % --- Figure 6: 跨问题对比汇总图 ---
    if numel(problems) > 1
        fig6 = figure('Visible', 'off', 'Position', [100 100 1200 600]);
        acc_F_arr = zeros(numel(problems), 1);
        acc_S_arr = zeros(numel(problems), 1);
        confl_arr = zeros(numel(problems), 1);
        labels = cell(numel(problems), 1);

        for pi = 1:numel(problems)
            key = problems{pi};
            tokens = regexp(key, '(\w+)_M(\d+)', 'tokens');
            pname = tokens{1}{1};
            Mval = str2double(tokens{1}{2});
            labels{pi} = sprintf('%s\nM=%d', pname, Mval);

            mu_F_p = []; mu_S_p = []; true_p = []; ctype_p = {};
            for ci = 1:numel(cand_rows)
                cr = cand_rows{ci};
                if strcmp(cr{1}, pname) && cr{2} == Mval
                    mu_F_p(end+1) = cr{6}; %#ok<AGROW>
                    mu_S_p(end+1) = cr{9}; %#ok<AGROW>
                    true_p(end+1) = cr{16}; %#ok<AGROW>
                    ctype_p{end+1} = get_ctype_safe(cr, numel(cr)); %#ok<AGROW>
                end
            end
            acc_F_arr(pi) = mean(sign(mu_F_p) == true_p);
            acc_S_arr(pi) = mean(sign(mu_S_p) == true_p);
            confl_arr(pi) = mean(~strcmp(ctype_p, 'agree'));
        end

        subplot(1,2,1);
        bar([acc_F_arr, acc_S_arr]);
        set(gca, 'XTickLabel', labels);
        ylabel('Accuracy');
        title('Prediction Accuracy by Problem');
        legend('Full net', 'Sub net', 'Location', 'best');
        grid on;

        subplot(1,2,2);
        bar(confl_arr);
        set(gca, 'XTickLabel', labels);
        ylabel('Conflict Rate');
        title('Conflict Rate by Problem');
        grid on;

        sgtitle('Cross-Problem Dual Network Comparison');
        saveas(fig6, fullfile(fig_dir, 'cross_problem_comparison.png'));
        close(fig6);
    end

    fprintf('All figures generated.\n');
end


function ct = get_ctype_safe(cr, ncol)
% get_ctype_safe - 安全获取冲突类型字符串。
% conflict_type 在 cand_row 中是第 21 个字段（无论是旧 21 列格式
% 还是新 23 列格式，conflict_type 都在 21）。
    if ncol >= 21
        val = cr{21};
        if ischar(val) || isstring(val)
            ct = char(val);
        elseif islogical(val) || isnumeric(val)
            if val == 0
                ct = 'agree';
            else
                ct = 'conflict';
            end
        else
            ct = 'agree';
        end
    elseif ncol >= 15
        % 极老格式：用 sign_F(14) 和 sign_S(15) 推断
        sf = cr{14};
        ss = cr{15};
        if isnumeric(sf) && isnumeric(ss)
            if (sf * ss) < 0
                ct = 'conflict';
            else
                ct = 'agree';
            end
        else
            ct = 'agree';
        end
    else
        ct = 'agree';
    end
end


%% ========================================================================
%  消融 A：子空间真值评估
%  ========================================================================

function write_subspace_ablation(fpath, cand_rows)
% write_subspace_ablation - 把 S 网络放回它训练的子空间评估，对照全空间评估。
%
% 输出列（每行对应一个 (problem, M) 组合）：
%   acc_F_full / acc_S_full : 在全 M 目标 Pareto 真值下的准确率（旧口径）
%   acc_F_sub  / acc_S_sub  : 在 S_easy 子空间 Pareto 真值下的准确率（同源）
%   delta_S_sub_vs_full     : acc_S_sub - acc_S_full，S 网络受益多少
%   delta_F_vs_S_full       : acc_F_full - acc_S_full，旧口径下 F 比 S 强多少
%   delta_S_vs_F_sub        : acc_S_sub - acc_F_sub，公平比较时 S 是否反超
%   label_agree_full_sub    : 全空间标签 vs 子空间标签一致率（两任务有多近）
%   acc_S_sub_{agree,conflict,subwin} : 按冲突类型切片的子空间准确率

    fid = fopen(fpath, 'w');
    fprintf(fid, '%s\n', strjoin({...
        'problem', 'M', 'n_candidates', 'n_valid', ...
        'acc_F_full', 'acc_F_sub', ...
        'acc_S_full', 'acc_S_sub', ...
        'delta_S_sub_vs_full', ...
        'delta_F_vs_S_full', 'delta_S_vs_F_sub', ...
        'label_agree_full_sub', ...
        'acc_S_sub_agree', 'acc_S_sub_conflict', 'acc_S_sub_subwin' ...
    }, ','));

    % 按 (problem, M) 分组
    problems = {};
    for i = 1:numel(cand_rows)
        key = sprintf('%s_M%d', cand_rows{i}{1}, cand_rows{i}{2});
        if ~ismember(key, problems)
            problems{end+1} = key; %#ok<AGROW>
        end
    end

    for pi = 1:numel(problems)
        key = problems{pi};
        tokens = regexp(key, '(\w+)_M(\d+)', 'tokens');
        pname = tokens{1}{1};
        Mval = str2double(tokens{1}{2});

        mu_F = []; mu_S = []; tq_full = []; tq_sub = [];
        has_real = []; ctype = {};

        for ci = 1:numel(cand_rows)
            cr = cand_rows{ci};
            if ~strcmp(cr{1}, pname) || cr{2} ~= Mval
                continue;
            end
            ncol = numel(cr);
            if ncol < 24
                continue;  % 旧格式无子空间真值
            end
            mu_F(end+1) = cr{6}; %#ok<AGROW>
            mu_S(end+1) = cr{9}; %#ok<AGROW>
            tq_full(end+1) = cr{16}; %#ok<AGROW>
            tq_sub(end+1) = cr{24}; %#ok<AGROW>
            if ncol >= 23
                has_real(end+1) = cr{23}; %#ok<AGROW>
            else
                has_real(end+1) = 0; %#ok<AGROW>
            end
            ctype{end+1} = get_ctype_safe(cr, ncol); %#ok<AGROW>
        end

        if isempty(mu_F)
            continue;
        end

        % 只保留有真值且子空间真值非 NaN 的样本
        valid = (has_real > 0) & ~isnan(tq_sub);
        if ~any(valid)
            fprintf(fid, '%s,%d,%d,0,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n', ...
                pname, Mval, numel(mu_F));
            continue;
        end

        muF = mu_F(valid);
        muS = mu_S(valid);
        tF  = tq_full(valid);
        tS  = tq_sub(valid);
        ct_v = ctype(valid);

        acc_F_full = mean(sign(muF) == tF);
        acc_F_sub  = mean(sign(muF) == tS);
        acc_S_full = mean(sign(muS) == tF);
        acc_S_sub  = mean(sign(muS) == tS);

        delta_S_sub_full = acc_S_sub - acc_S_full;
        delta_F_S_full   = acc_F_full - acc_S_full;
        delta_S_F_sub    = acc_S_sub - acc_F_sub;
        label_agree      = mean(tF == tS);

        % 按冲突类型切片
        conf_mask = strcmp(ct_v, 'conflict');
        subw_mask = strcmp(ct_v, 'subwin');
        agr_mask  = strcmp(ct_v, 'agree');
        if any(agr_mask)
            acc_S_sub_agree = mean(sign(muS(agr_mask)) == tS(agr_mask));
        else
            acc_S_sub_agree = NaN;
        end
        if any(conf_mask)
            acc_S_sub_conflict = mean(sign(muS(conf_mask)) == tS(conf_mask));
        else
            acc_S_sub_conflict = NaN;
        end
        if any(subw_mask)
            acc_S_sub_subwin = mean(sign(muS(subw_mask)) == tS(subw_mask));
        else
            acc_S_sub_subwin = NaN;
        end

        fprintf(fid, '%s,%d,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
            pname, Mval, numel(mu_F), sum(valid), ...
            acc_F_full, acc_F_sub, acc_S_full, acc_S_sub, ...
            delta_S_sub_full, delta_F_S_full, delta_S_F_sub, label_agree, ...
            acc_S_sub_agree, acc_S_sub_conflict, acc_S_sub_subwin);
    end
    fclose(fid);
end


function tq = local_subspace_true_quality(CandObj, PopObj)
% local_subspace_true_quality - 在给定的（已投影到子空间的）目标值上计算
% 候选解 vs 种群的 Pareto 支配真值。
% 返回 nCand×1 列向量：-1=被种群支配；+1=支配或互不支配。
    nCand = size(CandObj, 1);
    dominated = false(nCand, 1);
    dominates = false(nCand, 1);
    for i = 1:nCand
        diff = PopObj - CandObj(i, :);
        % ci 支配 pj: all(ci<=pj) && any(ci<pj)  →  all(diff>=0) && any(diff>0)
        dominates(i) = any(all(diff >= 0, 2) & any(diff > 0, 2));
        % pj 支配 ci: all(pj<=ci) && any(pj<ci)  →  all(diff<=0) && any(diff<0)
        dominated(i) = any(all(diff <= 0, 2) & any(diff < 0, 2));
    end
    tq = ones(nCand, 1);
    tq(dominated & ~dominates) = -1;
end
