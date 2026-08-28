function analyze_lkc_candidate_probe(varargin)
% analyze_lkc_candidate_probe - Export LKC candidate probe CSVs and figures.
%
% Usage:
%   analyze_lkc_candidate_probe
%   analyze_lkc_candidate_probe('fig', true)
%   analyze_lkc_candidate_probe('results_dir', 'path/to/results')

    p = inputParser;
    p.addParameter('results_dir', '');
    p.addParameter('output_dir', '');
    p.addParameter('fig', true);
    p.addParameter('detail', true);  % false = skip the ~1.8GB per_candidate_detail.csv rewrite (summaries/figures only)
    p.parse(varargin{:});
    opt = p.Results;

    this_dir = fileparts(mfilename('fullpath'));
    if isempty(opt.results_dir)
        opt.results_dir = fullfile(this_dir, 'results');
    end
    if isempty(opt.output_dir)
        opt.output_dir = fullfile(this_dir, 'output');
    end
    if ~exist(opt.output_dir, 'dir')
        mkdir(opt.output_dir);
    end

    files = dir(fullfile(opt.results_dir, 'lkc_candidate_*.mat'));
    if isempty(files)
        error('No lkc_candidate_*.mat files found in %s. Run run_lkc_candidate_probe first.', opt.results_dir);
    end

    candHeaders = {'problem', 'M', 'D', 'run', 'gen', 'FE', 'cand_idx', ...
        'score', 'selected_by_arbitrator', 'evaluated_by_algorithm', ...
        'mu_F', 'sigma2_F', 'confidence_F', 'pred_F', ...
        'true_quality_full', 'true_relation_full', 'full_correct_full', ...
        'dominated_by_pop_full', 'dominates_pop_full', ...
        'mu_S', 'sigma2_S', 'confidence_S', 'pred_S', ...
        'sub_triggered', 'full_uncertain', 'disagreement', 'sub_tiebreak_positive', ...
        'true_quality_agg', 'true_relation_agg', ...
        'sub_correct_agg', 'sub_correct_full', 'full_correct_agg', ...
        'dominated_by_pop_agg', 'dominates_pop_agg', ...
        'group_count', 'easy_raw_count', 'easy_group_count', 'has_real_obj'};
    genHeaders = {'problem', 'M', 'D', 'run', 'gen', 'FE', 'N', ...
        'n_candidate_pool', 'n_evaluated_from_pool', 'used_fallback', ...
        'p_err_F', 'p_err_S', 'group_count', 'easy_raw_count', 'easy_group_count', ...
        'mean_group_reliability', ...
        'full_acc_full', 'sub_acc_full', 'full_acc_agg', 'sub_acc_agg', ...
        'sub_acc_agg_triggered', 'sub_usage_rate', 'full_uncertain_rate', ...
        'highF_rate', 'highS_rate', 'disagreement_rate', ...
        'selected_rate', 'evaluated_rate', 'full_acc_agg_triggered'};
    runHeaders = {'problem', 'M', 'D', 'run', 'n_generations', 'n_candidates', ...
        'full_acc_full', 'sub_acc_full', 'full_acc_agg', 'sub_acc_agg', ...
        'sub_acc_agg_triggered', 'sub_usage_rate', 'full_uncertain_rate', ...
        'highF_rate', 'highS_rate', 'disagreement_rate', ...
        'selected_rate', 'evaluated_rate', ...
        'p_err_F_mean', 'p_err_S_mean', ...
        'label_agree_full_agg', 'has_real_obj_pct', 'full_acc_agg_triggered'};

    candCsv = fullfile(opt.output_dir, 'per_candidate_detail.csv');
    genCsv  = fullfile(opt.output_dir, 'per_generation_summary.csv');
    runCsv  = fullfile(opt.output_dir, 'per_run_summary.csv');

    % Open CSV files and write headers (streaming mode)
    fidCand = -1;
    if opt.detail
        fidCand = openForWrite(candCsv);  fprintf(fidCand, '%s\n', strjoin(candHeaders, ','));
    else
        fprintf('detail=false: skipping per_candidate_detail.csv rewrite (existing file left untouched).\n');
    end
    fidGen  = openForWrite(genCsv);   fprintf(fidGen,  '%s\n', strjoin(genHeaders,  ','));

    allRunRows = {};
    scatterByKey = containers.Map('KeyType', 'char', 'ValueType', 'any');

    fprintf('Found %d LKC candidate probe files.\n', numel(files));
    for fi = 1:numel(files)
        fpath = fullfile(files(fi).folder, files(fi).name);
        meta = parseFileName(files(fi).name, fi);
        fprintf('Loading %s ... ', files(fi).name);
        data = load(fpath);

        D_val = getLoadedField(data, 'D_val', NaN);
        if isfield(data, 'probe_data') && ~isempty(data.probe_data)
            firstRec = data.probe_data{1};
            if isfield(firstRec, 'D')
                D_val = firstRec.D;
            end
        end
        meta.D = D_val;

        % Stream candidate rows directly to CSV
        cfgKey = sprintf('%s_M%d_D%d', meta.problem, meta.M, meta.D);
        fullTrigByGen = containers.Map('KeyType', 'double', 'ValueType', 'double');
        fileCandRows = {};
        if isfield(data, 'probe_data')
            for pi = 1:numel(data.probe_data)
                rec = data.probe_data{pi};
                if isfield(rec, 'gen') && isfield(rec, 'stat_full_acc_agg_triggered')
                    fullTrigByGen(double(rec.gen)) = rec.stat_full_acc_agg_triggered;
                end
                scatterByKey = accumulateScatter(scatterByKey, cfgKey, rec);
                newRows = appendCandidateRows({}, meta, rec);
                if fidCand > 0
                    for ri = 1:numel(newRows)
                        write_csv_row(fidCand, newRows{ri});
                    end
                end
                fileCandRows = [fileCandRows, newRows]; %#ok<AGROW>
            end
        end

        % Stream generation rows directly to CSV
        fileGenRows = {};
        if isfield(data, 'gen_data')
            for gi = 1:numel(data.gen_data)
                gd = data.gen_data{gi};
                if ~isfield(gd, 'fullAccAggTriggered')
                    gv = getField(gd, 'gen', NaN);
                    if ~isnan(gv) && isKey(fullTrigByGen, double(gv))
                        gd.fullAccAggTriggered = fullTrigByGen(double(gv));
                    end
                end
                row = makeGenRow(meta, gd);
                write_csv_row(fidGen, row);
                fileGenRows{end+1} = row; %#ok<AGROW>
            end
        end

        allRunRows{end+1} = makeRunSummaryRow(meta, fileCandRows, fileGenRows); %#ok<AGROW>
        nCandThis = numel(fileCandRows);
        nGenThis = numel(fileGenRows);
        clear data fileCandRows fileGenRows;  % free per-file memory immediately
        fprintf('done (%d candidate rows, %d generation rows)\n', nCandThis, nGenThis);
    end

    if fidCand > 0
        fclose(fidCand);
        fprintf('Wrote %s (streamed)\n', candCsv);
    end
    fclose(fidGen);
    fprintf('Wrote %s (streamed)\n', genCsv);

    % allRunRows is small (200 entries), safe to write with write_csv
    write_csv(runCsv, runHeaders, allRunRows);
    fprintf('Wrote %s\n', runCsv);

    crossRows = makeCrossProblemRows(allRunRows);
    crossHeaders = {'problem', 'M', 'D', 'n_runs', 'n_candidates', ...
        'full_acc_full_mean', 'full_acc_full_std', ...
        'full_acc_agg_mean', 'full_acc_agg_std', ...
        'sub_acc_agg_mean', 'sub_acc_agg_std', ...
        'sub_acc_agg_triggered_mean', 'sub_acc_agg_triggered_std', ...
        'sub_usage_rate_mean', 'sub_usage_rate_std', ...
        'full_uncertain_rate_mean', 'disagreement_rate_mean', ...
        'p_err_F_mean', 'p_err_S_mean', ...
        'full_acc_agg_triggered_mean', 'full_acc_agg_triggered_std'};
    crossCsv = fullfile(opt.output_dir, 'cross_problem_summary.csv');
    write_csv(crossCsv, crossHeaders, crossRows);
    fprintf('Wrote %s\n', crossCsv);

    dictCsv = fullfile(opt.output_dir, 'metric_dictionary_zh.csv');
    write_metric_dictionary_zh(dictCsv);
    fprintf('Wrote %s\n', dictCsv);

    if opt.fig
        figDir = fullfile(opt.output_dir, 'figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        % Scatter samples were collected in-memory during streaming (no re-scan of the
        % multi-GB candidate CSV); time-series still reads the small generation CSV.
        generate_figures_from_csv(scatterByKey, genCsv, allRunRows, figDir);
        fprintf('Figures saved to %s\n', figDir);
    end

    fprintf('LKC candidate probe analysis complete.\n');
end


function rows = appendCandidateRows(rows, meta, rec)
    n = rec.nCand;
    for i = 1:n
        rows{end+1} = {meta.problem, meta.M, meta.D, meta.run, rec.gen, rec.FE, i, ...
            valueAt(rec.scores, i), ...
            boolAt(rec.selectedMask, i), boolAt(rec.evaluatedMask, i), ...
            valueAt(rec.mu_F, i), valueAt(rec.sigma2_F, i), valueAt(rec.confidence_F, i), valueAt(rec.pred_F, i), ...
            valueAt(rec.trueQualityFull, i), valueAt(rec.trueRelationFull, i), boolAt(rec.correctF_full, i), ...
            boolAt(rec.dominatedByPopFull, i), boolAt(rec.dominatesPopFull, i), ...
            valueAt(rec.mu_S, i), valueAt(rec.sigma2_S, i), valueAt(rec.confidence_S, i), valueAt(rec.pred_S, i), ...
            boolAt(rec.subTriggered, i), boolAt(rec.fullUncertain, i), boolAt(rec.disagreement, i), ...
            boolAt(rec.subTieBreakDominated, i), ...
            valueAt(rec.trueQualityAgg, i), valueAt(rec.trueRelationAgg, i), ...
            boolAt(rec.correctS_agg, i), boolAt(rec.correctS_full, i), boolAt(rec.correctF_agg, i), ...
            boolAt(rec.dominatedByPopAgg, i), boolAt(rec.dominatesPopAgg, i), ...
            getField(rec, 'groupCount', NaN), getField(rec, 'easyRawCount', NaN), ...
            getField(rec, 'easyGroupCount', NaN), double(getField(rec, 'hasRealObj', false))}; %#ok<AGROW>
    end
end


function row = makeGenRow(meta, gd)
    row = {meta.problem, meta.M, meta.D, meta.run, ...
        getField(gd, 'gen', NaN), getField(gd, 'FE', NaN), getField(gd, 'N', NaN), ...
        getField(gd, 'nCandidatePool', NaN), getField(gd, 'nEvaluatedFromPool', NaN), ...
        double(getField(gd, 'usedFallback', false)), ...
        getField(gd, 'p_err_F', NaN), getField(gd, 'p_err_S', NaN), ...
        getField(gd, 'groupCount', NaN), getField(gd, 'easyRawCount', NaN), ...
        getField(gd, 'easyGroupCount', NaN), getField(gd, 'meanGroupReliability', NaN), ...
        getField(gd, 'fullAccFull', NaN), getField(gd, 'subAccFull', NaN), ...
        getField(gd, 'fullAccAgg', NaN), getField(gd, 'subAccAgg', NaN), ...
        getField(gd, 'subAccAggTriggered', NaN), getField(gd, 'subUsageRate', NaN), ...
        getField(gd, 'fullUncertainRate', getField(gd, 'fullUncertainRatio', NaN)), ...
        getField(gd, 'highFRate', NaN), getField(gd, 'highSRate', NaN), ...
        getField(gd, 'disagreementRate', getField(gd, 'disagreementRatio', NaN)), ...
        getField(gd, 'selectedRate', NaN), getField(gd, 'evaluatedRate', NaN), ...
        getField(gd, 'fullAccAggTriggered', NaN)};
end


function row = makeRunSummaryRow(meta, candRows, genRows)
    nCand = numel(candRows);
    nGen = numel(genRows);

    fullCorrect = col(candRows, 17);
    subCorrectFull = col(candRows, 31);
    fullCorrectAgg = col(candRows, 32);
    subCorrectAgg = col(candRows, 30);
    subTriggered = col(candRows, 24);
    fullUncertain = col(candRows, 25);
    disagreement = col(candRows, 26);
    selected = col(candRows, 9);
    evaluated = col(candRows, 10);
    trueFull = col(candRows, 15);
    trueAgg = col(candRows, 28);
    hasReal = col(candRows, 38);

    subAggTriggered = NaN;
    if any(subTriggered > 0)
        subAggTriggered = mean(subCorrectAgg(subTriggered > 0));
    end

    % Full network accuracy on the SAME triggered candidates (aggregate truth),
    % to compare head-to-head with subAggTriggered in the region where net_S steps in.
    fullAggTriggered = NaN;
    if any(subTriggered > 0)
        fullAggTriggered = mean(fullCorrectAgg(subTriggered > 0));
    end

    pErrF = col(genRows, 11);
    pErrS = col(genRows, 12);
    highFRun = meanMaybe(col(genRows, 24));
    highSRun = meanMaybe(col(genRows, 25));

    row = {meta.problem, meta.M, meta.D, meta.run, nGen, nCand, ...
        meanMaybe(fullCorrect), meanMaybe(subCorrectFull), ...
        meanMaybe(fullCorrectAgg), meanMaybe(subCorrectAgg), ...
        subAggTriggered, meanMaybe(subTriggered), meanMaybe(fullUncertain), ...
        highFRun, highSRun, meanMaybe(disagreement), ...
        meanMaybe(selected), meanMaybe(evaluated), ...
        meanMaybe(pErrF), meanMaybe(pErrS), ...
        meanMaybe(double(trueFull == trueAgg)), meanMaybe(hasReal) * 100, ...
        fullAggTriggered};
end


function rows = makeCrossProblemRows(runRows)
    keys = {};
    for i = 1:numel(runRows)
        key = sprintf('%s_M%d_D%d', runRows{i}{1}, runRows{i}{2}, runRows{i}{3});
        if ~ismember(key, keys)
            keys{end+1} = key; %#ok<AGROW>
        end
    end

    rows = {};
    for k = 1:numel(keys)
        key = keys{k};
        parts = regexp(key, '(\w+)_M(\d+)_D(\d+)', 'tokens');
        pname = parts{1}{1};
        Mval = str2double(parts{1}{2});
        Dval = str2double(parts{1}{3});

        maskRows = {};
        for i = 1:numel(runRows)
            if strcmp(runRows{i}{1}, pname) && runRows{i}{2} == Mval && runRows{i}{3} == Dval
                maskRows{end+1} = runRows{i}; %#ok<AGROW>
            end
        end

        nRuns = numel(maskRows);
        nCand = sum(col(maskRows, 6));
        fullAcc = col(maskRows, 7);
        subAgg = col(maskRows, 10);
        subAggTrig = col(maskRows, 11);
        subUsage = col(maskRows, 12);
        fullUncertain = col(maskRows, 13);
        disagree = col(maskRows, 16);
        pErrF = col(maskRows, 19);
        pErrS = col(maskRows, 20);
        fullAggTrig = col(maskRows, 23);

        fullAgg = col(maskRows, 9);  % full_acc_agg

        rows{end+1} = {pname, Mval, Dval, nRuns, nCand, ...
            meanMaybe(fullAcc), stdMaybe(fullAcc), ...
            meanMaybe(fullAgg), stdMaybe(fullAgg), ...
            meanMaybe(subAgg), stdMaybe(subAgg), ...
            meanMaybe(subAggTrig), stdMaybe(subAggTrig), ...
            meanMaybe(subUsage), stdMaybe(subUsage), ...
            meanMaybe(fullUncertain), meanMaybe(disagree), ...
            meanMaybe(pErrF), meanMaybe(pErrS), ...
            meanMaybe(fullAggTrig), stdMaybe(fullAggTrig)}; %#ok<AGROW>
    end
end


function generate_figures_from_csv(scatterByKey, genCsv, runRows, figDir)
    % Memory-friendly figure generation:
    % - Time-series: read gen CSV (~10K rows, manageable)
    % - Scatter plot: use the in-memory (mu_F, mu_S, trig, fcorr) sample collected
    %   while streaming the .mat files (avoids re-scanning the multi-GB candidate CSV)
    % - Bar charts: use runRows (already in memory, ~200 rows)

    keys = {};
    for i = 1:numel(runRows)
        key = sprintf('%s_M%d_D%d', runRows{i}{1}, runRows{i}{2}, runRows{i}{3});
        if ~ismember(key, keys)
            keys{end+1} = key; %#ok<AGROW>
        end
    end

    % Read gen CSV once (small: ~10K rows)
    genRows = read_csv_rows(genCsv);

    for ki = 1:numel(keys)
        parts = regexp(keys{ki}, '(\w+)_M(\d+)_D(\d+)', 'tokens');
        pname = parts{1}{1};
        Mval = str2double(parts{1}{2});
        Dval = str2double(parts{1}{3});

        g = filterRows(genRows, pname, Mval, Dval);
        if isempty(g)
            continue;
        end

        % --- Figure 1: accuracy & usage over generations ---
        fig1 = figure('Visible', 'off', 'Position', [100 100 1100 760]);
        subplot(2,1,1);
        plot(col(g, 5), col(g, 17), 'b-o', 'LineWidth', 1.2); hold on;
        plot(col(g, 5), col(g, 20), 'r-s', 'LineWidth', 1.2);
        plot(col(g, 5), col(g, 21), 'm-^', 'LineWidth', 1.2);
        plot(col(g, 5), col(g, 29), '--d', 'Color', [0 0.5 0], 'LineWidth', 1.2);
        ylim([0 1]);
        xlabel('Generation');
        ylabel('Accuracy');
        title(sprintf('%s M=%d: Full vs LKC sub-network accuracy', pname, Mval));
        legend({'Full net on full truth', 'Sub net on aggregate truth', ...
            'Sub net on aggregate truth when triggered', ...
            'Full net on aggregate truth when triggered'}, 'Location', 'best');
        grid on;

        subplot(2,1,2);
        plot(col(g, 5), col(g, 22), 'k-o', 'LineWidth', 1.2); hold on;
        plot(col(g, 5), col(g, 23), 'c-s', 'LineWidth', 1.2);
        plot(col(g, 5), col(g, 26), 'Color', [0.85 0.3 0.1], 'Marker', '^', 'LineWidth', 1.2);
        ylim([0 1]);
        xlabel('Generation');
        ylabel('Rate');
        title('Sub-network usage and disagreement');
        legend({'Sub triggered ratio', 'Full uncertain ratio', 'Disagreement ratio'}, 'Location', 'best');
        grid on;
        saveas(fig1, fullfile(figDir, sprintf('%s_M%d_D%d_accuracy_usage.png', pname, Mval, Dval)));
        close(fig1);

        % --- Figure 2: mu scatter (from in-memory sample, up to 50K points) ---
        sckey = sprintf('%s_M%d_D%d', pname, Mval, Dval);
        if isKey(scatterByKey, sckey)
            s = scatterByKey(sckey);
        else
            s = struct('muF', [], 'muS', [], 'trig', [], 'fcorr', []);
        end
        if ~isempty(s.muF)
            muF = s.muF;
            muS = s.muS;
            trig = s.trig > 0;
            fullCorrect = s.fcorr > 0;
            fig2 = figure('Visible', 'off', 'Position', [100 100 780 680]);
            hold on;
            scatter(muF(~trig & fullCorrect), muS(~trig & fullCorrect), 22, [0.25 0.55 0.85], 'filled');
            scatter(muF(~trig & ~fullCorrect), muS(~trig & ~fullCorrect), 28, [0.75 0.75 0.75], 'filled');
            scatter(muF(trig & fullCorrect), muS(trig & fullCorrect), 34, [0.15 0.7 0.25], 'filled');
            scatter(muF(trig & ~fullCorrect), muS(trig & ~fullCorrect), 40, [0.9 0.25 0.2], 'filled');
            plot([min(muF) max(muF)], [0 0], 'k--');
            plot([0 0], [min(muS) max(muS)], 'k--');
            xlabel('\mu_F');
            ylabel('\mu_S');
            title(sprintf('%s M=%d: candidate predictions', pname, Mval));
            legend({'No sub, F correct', 'No sub, F wrong', ...
                'Sub triggered, F correct', 'Sub triggered, F wrong'}, 'Location', 'best');
            grid on;
            hold off;
            saveas(fig2, fullfile(figDir, sprintf('%s_M%d_D%d_mu_scatter.png', pname, Mval, Dval)));
            close(fig2);
        end

        % --- Figure 3: run-level summary bar ---
        r = filterRows(runRows, pname, Mval, Dval);
        fig3 = figure('Visible', 'off', 'Position', [100 100 900 520]);
        barData = [meanMaybe(col(r, 7)), meanMaybe(col(r, 10)), ...
                   meanMaybe(col(r, 11)), meanMaybe(col(r, 12))];
        bar(barData);
        set(gca, 'XTickLabel', {'Full acc', 'Sub acc', 'Sub acc trig', 'Sub usage'});
        ylim([0 1]);
        ylabel('Mean value');
        title(sprintf('%s M=%d: run-level summary', pname, Mval));
        grid on;
        saveas(fig3, fullfile(figDir, sprintf('%s_M%d_D%d_summary_bar.png', pname, Mval, Dval)));
        close(fig3);
    end

    % --- Figure 4: cross-problem comparison ---
    if numel(keys) > 1
        labels = cell(numel(keys), 1);
        fullAccFull = zeros(numel(keys), 1);
        fullAccAgg = zeros(numel(keys), 1);
        subAcc = zeros(numel(keys), 1);
        subUse = zeros(numel(keys), 1);
        for ki = 1:numel(keys)
            parts = regexp(keys{ki}, '(\w+)_M(\d+)_D(\d+)', 'tokens');
            pname = parts{1}{1};
            Mval = str2double(parts{1}{2});
            Dval = str2double(parts{1}{3});
            labels{ki} = sprintf('%s M%d', pname, Mval);
            r = filterRows(runRows, pname, Mval, Dval);
            fullAccFull(ki) = meanMaybe(col(r, 7));
            fullAccAgg(ki) = meanMaybe(col(r, 9));
            subAcc(ki) = meanMaybe(col(r, 10));
            subUse(ki) = meanMaybe(col(r, 12));
        end

        fig4 = figure('Visible', 'off', 'Position', [100 100 1200 520]);
        bar([fullAccFull, fullAccAgg, subAcc, subUse]);
        set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 45);
        ylabel('Mean value');
        title('Cross-problem LKC candidate probe summary');
        legend({'Full acc on full truth', 'Full acc on aggregate truth', ...
                'Sub acc on aggregate truth', 'Sub usage'}, 'Location', 'best');
        grid on;
        saveas(fig4, fullfile(figDir, 'cross_problem_summary.png'));
        close(fig4);
    end
end


function scatterByKey = accumulateScatter(scatterByKey, cfgKey, rec)
    % Collect a capped (mu_F, mu_S, sub_triggered, full_correct_full) sample per
    % problem/M/D for the mu-scatter figure, reusing the per-candidate arrays already
    % loaded from the .mat (so the figure stage never re-scans the multi-GB candidate CSV).
    cap = 50000;
    if ~isfield(rec, 'mu_F') || ~isfield(rec, 'nCand') || rec.nCand <= 0
        return;
    end
    if ~isKey(scatterByKey, cfgKey)
        scatterByKey(cfgKey) = struct('muF', [], 'muS', [], 'trig', [], 'fcorr', []);
    end
    s = scatterByKey(cfgKey);
    if numel(s.muF) >= cap
        return;
    end
    take = min(cap - numel(s.muF), rec.nCand);
    s.muF   = [s.muF;   double(rec.mu_F(1:take))];
    s.muS   = [s.muS;   double(rec.mu_S(1:take))];
    s.trig  = [s.trig;  double(rec.subTriggered(1:take))];
    s.fcorr = [s.fcorr; double(rec.correctF_full(1:take))];
    scatterByKey(cfgKey) = s;
end


function rows = read_csv_rows(csvPath)
    % Read all rows from a CSV file into cell-of-cells (skip header)
    rows = {};
    fid = fopen(csvPath, 'r');
    if fid < 0, return; end
    fgetl(fid);  % skip header
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), break; end
        vals = parse_csv_line(line);
        if ~isempty(vals)
            rows{end+1} = vals; %#ok<AGROW>
        end
    end
    fclose(fid);
end


function vals = parse_csv_line(line)
    % Simple CSV parser: split by comma, strip quotes, convert numbers
    parts = strsplit(line, ',');
    vals = cell(1, numel(parts));
    for i = 1:numel(parts)
        s = strtrim(parts{i});
        if isempty(s) || strcmp(s, 'NaN')
            vals{i} = NaN;
        elseif s(1) == '"' && s(end) == '"'
            vals{i} = s(2:end-1);
        else
            num = str2double(s);
            if ~isnan(num)
                vals{i} = num;
            else
                vals{i} = s;
            end
        end
    end
end


function rows = filterRows(rowsIn, pname, Mval, Dval)
    rows = {};
    for i = 1:numel(rowsIn)
        if strcmp(rowsIn{i}{1}, pname) && rowsIn{i}{2} == Mval && rowsIn{i}{3} == Dval
            rows{end+1} = rowsIn{i}; %#ok<AGROW>
        end
    end
end


function write_csv(fpath, headers, rows)
    fid = fopen(fpath, 'w');
    if fid < 0
        error('Cannot open %s for writing.', fpath);
    end
    fprintf(fid, '%s\n', strjoin(headers, ','));
    for i = 1:numel(rows)
        write_csv_row(fid, rows{i});
    end
    fclose(fid);
end


function write_csv_row(fid, row)
    for j = 1:numel(row)
        write_csv_value(fid, row{j});
        if j < numel(row)
            fprintf(fid, ',');
        end
    end
    fprintf(fid, '\n');
end


function write_csv_value(fid, val)
    if isnumeric(val)
        if isempty(val) || (isscalar(val) && isnan(val))
            fprintf(fid, 'NaN');
        elseif isscalar(val)
            fprintf(fid, '%.10g', val);
        else
            fprintf(fid, '"%s"', mat2str(val));
        end
    elseif islogical(val)
        fprintf(fid, '%d', val);
    elseif isstring(val)
        fprintf(fid, '"%s"', char(val));
    elseif ischar(val)
        fprintf(fid, '"%s"', strrep(val, '"', '""'));
    else
        fprintf(fid, '""');
    end
end


function write_metric_dictionary_zh(fpath)
    rows = metric_dictionary_rows();
    fid = fopen(fpath, 'w', 'n', 'UTF-8');
    if fid < 0
        error('Cannot open %s for writing.', fpath);
    end
    fwrite(fid, [239 187 191], 'uint8');
    headers = {'csv文件', '字段名', '中文名称', '含义', '取值或计算口径', '建议用途'};
    fprintf(fid, '%s\n', strjoin(headers, ','));
    for i = 1:size(rows, 1)
        for j = 1:size(rows, 2)
            write_csv_value(fid, rows{i, j});
            if j < size(rows, 2)
                fprintf(fid, ',');
            end
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end


function rows = metric_dictionary_rows()
    rows = {
        'per_candidate_detail.csv','problem','测试问题','测试函数名称。','例如 DTLZ2、WFG4。','区分不同 benchmark。';
        'per_candidate_detail.csv','M','目标数','优化问题的目标维度。','PlatEMO 的 M。','按目标数分组分析。';
        'per_candidate_detail.csv','D','决策变量数','优化问题的决策变量维度。','PlatEMO 的 D。','确认实验配置。';
        'per_candidate_detail.csv','run','独立运行编号','第几次独立重复实验。','从 1 开始。','统计多次运行均值和方差。';
        'per_candidate_detail.csv','gen','代数','算法主循环中的代数。','从 1 开始。','观察指标随代数变化。';
        'per_candidate_detail.csv','FE','当前真实评估次数','记录该代探针发生时的真实评估次数。','来自 Problem.FE。','定位昂贵评估预算阶段。';
        'per_candidate_detail.csv','cand_idx','候选记录编号','该代内第几个被仲裁器评分的候选记录。','包含内层 GA 多轮候选，可能有重复决策向量。','逐候选追踪。';
        'per_candidate_detail.csv','score','LKC 仲裁得分','最终 LKC 仲裁公式得到的候选分数。','越大越可能被选中。','分析选择偏好。';
        'per_candidate_detail.csv','selected_by_arbitrator','仲裁器是否选中','该候选是否通过最终阈值或 Top-4 规则。','1=选中，0=未选中。','判断模型推荐结果。';
        'per_candidate_detail.csv','evaluated_by_algorithm','是否进入真实评估','选中后经过边界裁剪、去重、去已评估、预算截断后是否真实评估。','1=进入 Problem.Evaluation。','区分模型推荐和实际评估。';
        'per_candidate_detail.csv','mu_F','全网络预测均值','全目标网络集成对候选的关系评分均值。','正值偏好候选好，负值偏好候选差。','分析全网络判断方向。';
        'per_candidate_detail.csv','sigma2_F','全网络预测方差','全目标网络集成预测方差。','越小表示集成越一致。','衡量全网络不确定性。';
        'per_candidate_detail.csv','confidence_F','全网络置信度','abs(mu_F)/(sqrt(sigma2_F)+1e-6)。','越大表示方向强且方差小。','筛选高置信判断。';
        'per_candidate_detail.csv','pred_F','全网络预测标签','sign(mu_F)。','1=预测候选不差或有利，-1=预测候选差，0=中性。','计算全网络准确率。';
        'per_candidate_detail.csv','true_quality_full','全目标二分类真值','用 Problem.CalObj 旁路计算候选真实目标，并与当前种群做 Pareto 比较。','候选被种群严格支配且不支配任何种群解为 -1，否则为 1。','全网络主要准确率真值。';
        'per_candidate_detail.csv','true_relation_full','全目标三态关系真值','候选与当前种群的 Pareto 关系。','1=候选支配至少一个种群解且不被支配，-1=候选被支配且不支配任何解，0=互不支配或混合。','更细地看支配关系。';
        'per_candidate_detail.csv','full_correct_full','全网络全目标准确','pred_F 是否等于 true_quality_full。','1=正确，0=错误。','全网络支配判断准确率核心列。';
        'per_candidate_detail.csv','dominated_by_pop_full','全目标下被种群支配','候选是否被当前种群至少一个解严格支配。','1=是，0=否。','分析坏候选比例。';
        'per_candidate_detail.csv','dominates_pop_full','全目标下支配种群','候选是否严格支配当前种群至少一个解。','1=是，0=否。','分析潜在优质候选。';
        'per_candidate_detail.csv','mu_S','子网络预测均值','LKC 易聚合目标子网络集成评分均值。','正值偏好候选好，负值偏好候选差。','分析子网络判断方向。';
        'per_candidate_detail.csv','sigma2_S','子网络预测方差','子网络集成预测方差。','越小表示集成越一致。','衡量子网络不确定性。';
        'per_candidate_detail.csv','confidence_S','子网络置信度','abs(mu_S)/(sqrt(sigma2_S)+1e-6)。','越大表示方向强且方差小。','判断子网络是否可信。';
        'per_candidate_detail.csv','pred_S','子网络预测标签','sign(mu_S)。','1=预测候选在易聚合空间较好，-1=较差，0=中性。','计算子网络准确率。';
        'per_candidate_detail.csv','sub_triggered','子网络是否参与仲裁','LKC 仲裁中全网络不确定且子网络高置信时为真。','1=子网络实际参与加分，0=未参与。','子网络评估占比核心列。';
        'per_candidate_detail.csv','full_uncertain','全网络是否不确定','全网络未达到高置信条件。','1=不确定，0=高置信。','解释子网络为何触发。';
        'per_candidate_detail.csv','disagreement','全子网络是否冲突','子网络高置信且 sign(mu_F) 与 sign(mu_S) 相反。','1=冲突，0=不冲突。','分析风险候选。';
        'per_candidate_detail.csv','sub_tiebreak_positive','子网络是否给正向补充','子网络触发且 tanh(mu_S)>0。','1=子网络对候选给正向 tie-break，0=否。','判断子网络帮助程度。';
        'per_candidate_detail.csv','true_quality_agg','LKC聚合空间二分类真值','把候选和种群投影到 LKC 易聚合目标空间后做 Pareto 比较。','被支配且不支配任何解为 -1，否则为 1。','子网络主准确率真值。';
        'per_candidate_detail.csv','true_relation_agg','LKC聚合空间三态真值','易聚合目标空间中的候选与种群 Pareto 关系。','1=支配，-1=被支配，0=互不支配或混合。','分析子空间关系。';
        'per_candidate_detail.csv','sub_correct_agg','子网络聚合空间准确','pred_S 是否等于 true_quality_agg。','1=正确，0=错误。','子网络准确率核心列，推荐优先看。';
        'per_candidate_detail.csv','sub_correct_full','子网络全目标准确','pred_S 是否等于 true_quality_full。','1=正确，0=错误。','只作对照，不是子网络主评价口径。';
        'per_candidate_detail.csv','full_correct_agg','全网络聚合空间准确','pred_F 是否等于 true_quality_agg。','1=正确，0=错误。','比较全网络和子网络在子空间任务上的差异。';
        'per_candidate_detail.csv','dominated_by_pop_agg','聚合空间下被种群支配','候选在 LKC 易聚合空间是否被当前种群支配。','1=是，0=否。','分析子空间坏候选。';
        'per_candidate_detail.csv','dominates_pop_agg','聚合空间下支配种群','候选在 LKC 易聚合空间是否支配当前种群至少一个解。','1=是，0=否。','分析子空间潜在好候选。';
        'per_candidate_detail.csv','group_count','LKC目标组数量','当前代 LKC 分出的目标组数量。','整数。','观察结构分组复杂度。';
        'per_candidate_detail.csv','easy_raw_count','易组覆盖原始目标数','被选中易目标组覆盖的原始目标数量。','整数。','判断子网络实际覆盖多少原始目标。';
        'per_candidate_detail.csv','easy_group_count','易目标组数量','被选中用于子网络的 LKC 目标组数量。','整数。','判断子网络聚合空间维度。';
        'per_candidate_detail.csv','has_real_obj','是否使用真实旁路目标','是否成功用 Problem.CalObj 计算候选真实目标。','1=真实旁路成功，0=退回最近邻估计。','确认准确率真值可靠性。';

        'per_generation_summary.csv','n_candidate_pool','候选记录数','该代仲裁器实际评分过的候选记录数。','包含内层 GA 多轮评分过程。','判断探针样本量。';
        'per_generation_summary.csv','n_evaluated_from_pool','真实评估候选数','该代最终进入真实评估的候选数。','经过去重和预算截断。','衡量实际评估规模。';
        'per_generation_summary.csv','used_fallback','是否使用后备GA','代理模型或候选为空时是否走 fallback。','1=使用，0=未使用。','排查异常代。';
        'per_generation_summary.csv','p_err_F','全网络测试错误率','TrainDualScaleNet 记录的全网络测试集分类错误率。','越低越好。','判断训练质量。';
        'per_generation_summary.csv','p_err_S','子网络测试错误率','TrainDualScaleNet 记录的子网络测试集分类错误率。','越低越好。','判断子网络训练质量。';
        'per_generation_summary.csv','mean_group_reliability','平均组可靠性','当前 LKC 目标组可靠性的平均值。','越高表示组内结构越一致。','判断分组质量。';
        'per_generation_summary.csv','full_acc_full','全网络全目标准确率','该代所有候选 full_correct_full 的平均值。','0 到 1。','全网络准确率核心指标。';
        'per_generation_summary.csv','sub_acc_full','子网络全目标准确率','该代所有候选 sub_correct_full 的平均值。','0 到 1。','对照口径。';
        'per_generation_summary.csv','full_acc_agg','全网络聚合空间准确率','该代所有候选 full_correct_agg 的平均值。','0 到 1。','比较全网络在子空间任务表现。';
        'per_generation_summary.csv','sub_acc_agg','子网络聚合空间准确率','该代所有候选 sub_correct_agg 的平均值。','0 到 1。','子网络主准确率。';
        'per_generation_summary.csv','sub_acc_agg_triggered','触发时子网络准确率','只统计 sub_triggered=1 候选的 sub_correct_agg 平均值。','无触发时为 NaN。','判断子网络真正参与时是否可靠。';
        'per_generation_summary.csv','full_acc_agg_triggered','触发时全网络聚合准确率','只统计 sub_triggered=1 候选的 full_correct_agg 平均值。','无触发时为 NaN。','与 sub_acc_agg_triggered 同口径对比，判断触发区子网络是否真比全网络强。';
        'per_generation_summary.csv','sub_usage_rate','子网络使用占比','该代 sub_triggered 的平均值。','0 到 1。','子网络评估占比核心指标。';
        'per_generation_summary.csv','full_uncertain_rate','全网络不确定比例','该代 full_uncertain 的平均值。','0 到 1。','解释子网络触发空间。';
        'per_generation_summary.csv','highF_rate','全网络高置信比例','该代全网络高置信候选比例。','约等于 1-full_uncertain_rate。','判断全网络主导程度。';
        'per_generation_summary.csv','highS_rate','子网络高置信比例','该代子网络高置信候选比例。','0 到 1。','判断子网络可用性。';
        'per_generation_summary.csv','disagreement_rate','冲突比例','该代 disagreement 的平均值。','0 到 1。','判断全子网络矛盾程度。';
        'per_generation_summary.csv','selected_rate','仲裁选中比例','该代 selected_by_arbitrator 的平均值。','0 到 1。','判断筛选强度。';
        'per_generation_summary.csv','evaluated_rate','真实评估比例','该代 evaluated_by_algorithm 的平均值。','0 到 1。','判断候选池中实际评估占比。';

        'per_run_summary.csv','n_generations','总代数','该 run 记录到的代数。','整数。','确认实验长度。';
        'per_run_summary.csv','n_candidates','候选记录总数','该 run 所有代的候选记录数。','整数。','确认统计样本量。';
        'per_run_summary.csv','full_acc_full','全网络全目标平均准确率','该 run 所有候选 full_correct_full 平均值。','0 到 1。','报告全网络准确率。';
        'per_run_summary.csv','sub_acc_agg','子网络聚合空间平均准确率','该 run 所有候选 sub_correct_agg 平均值。','0 到 1。','报告子网络主准确率。';
        'per_run_summary.csv','sub_acc_agg_triggered','触发时子网络平均准确率','该 run 中 sub_triggered=1 候选的 sub_correct_agg 平均值。','无触发时为 NaN。','报告子网络参与时质量。';
        'per_run_summary.csv','full_acc_agg_triggered','触发时全网络平均聚合准确率','该 run 中 sub_triggered=1 候选的 full_correct_agg 平均值。','无触发时为 NaN。','与 sub_acc_agg_triggered 直接对比，回答"全网络放弃时子网络是否更好"。';
        'per_run_summary.csv','sub_usage_rate','子网络平均使用占比','该 run 所有候选 sub_triggered 平均值。','0 到 1。','报告子网络评估占比。';
        'per_run_summary.csv','label_agree_full_agg','全目标与聚合空间标签一致率','true_quality_full 与 true_quality_agg 的一致比例。','0 到 1。','判断子空间任务与全目标任务接近程度。';
        'per_run_summary.csv','has_real_obj_pct','真实旁路目标成功比例','has_real_obj 的百分比。','0 到 100。','确认真值质量。';

        'cross_problem_summary.csv','n_runs','独立运行数','该问题配置下汇总的 run 数。','整数。','确认统计重复数。';
        'cross_problem_summary.csv','n_candidates','候选记录总数','该问题配置下所有 run 的候选记录数。','整数。','确认样本量。';
        'cross_problem_summary.csv','full_acc_full_mean','全网络准确率均值','各 run 的 full_acc_full 均值。','0 到 1。','跨问题比较全网络。';
        'cross_problem_summary.csv','full_acc_full_std','全网络准确率标准差','各 run 的 full_acc_full 标准差。','越小越稳定。','评估稳定性。';
        'cross_problem_summary.csv','full_acc_agg_mean','全网络聚合空间准确率均值','各 run 的 full_acc_agg 均值。','0 到 1。','同任务公平对比：全网络在聚合空间的表现。';
        'cross_problem_summary.csv','full_acc_agg_std','全网络聚合空间准确率标准差','各 run 的 full_acc_agg 标准差。','越小越稳定。','评估稳定性。';
        'cross_problem_summary.csv','sub_acc_agg_mean','子网络准确率均值','各 run 的 sub_acc_agg 均值。','0 到 1。','跨问题比较子网络。';
        'cross_problem_summary.csv','sub_acc_agg_std','子网络准确率标准差','各 run 的 sub_acc_agg 标准差。','越小越稳定。','评估稳定性。';
        'cross_problem_summary.csv','sub_acc_agg_triggered_mean','触发时子网络准确率均值','各 run 的 sub_acc_agg_triggered 均值。','0 到 1 或 NaN。','判断子网络实际参与时质量。';
        'cross_problem_summary.csv','sub_usage_rate_mean','子网络使用占比均值','各 run 的 sub_usage_rate 均值。','0 到 1。','判断子网络整体参与度。';
        'cross_problem_summary.csv','full_uncertain_rate_mean','全网络不确定比例均值','各 run 的 full_uncertain_rate 均值。','0 到 1。','判断全网络留给子网络的空间。';
        'cross_problem_summary.csv','disagreement_rate_mean','冲突比例均值','各 run 的 disagreement_rate 均值。','0 到 1。','判断全子网络冲突程度。';
        'cross_problem_summary.csv','p_err_F_mean','全网络训练错误率均值','各代或各 run 的 p_err_F 平均。','越低越好。','辅助解释准确率。';
        'cross_problem_summary.csv','p_err_S_mean','子网络训练错误率均值','各代或各 run 的 p_err_S 平均。','越低越好。','辅助解释子网络质量。';
        'cross_problem_summary.csv','full_acc_agg_triggered_mean','触发时全网络准确率均值','各 run 的 full_acc_agg_triggered 均值。','0 到 1 或 NaN。','与 sub_acc_agg_triggered_mean 对比，跨问题判断触发区谁更强。';
        'cross_problem_summary.csv','full_acc_agg_triggered_std','触发时全网络准确率标准差','各 run 的 full_acc_agg_triggered 标准差。','越小越稳定。','评估稳定性。';
    };
end


function meta = parseFileName(fname, idx)
    tok = regexp(fname, 'lkc_candidate_(\w+)_M(\d+)_run(\d+)', 'tokens');
    if isempty(tok)
        meta.problem = 'unknown';
        meta.M = NaN;
        meta.run = idx;
    else
        meta.problem = tok{1}{1};
        meta.M = str2double(tok{1}{2});
        meta.run = str2double(tok{1}{3});
    end
    meta.D = NaN;
end


function v = getLoadedField(S, name, defaultValue)
    if isfield(S, name)
        v = S.(name);
    else
        v = defaultValue;
    end
end


function value = getField(S, name, defaultValue)
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        value = S.(name);
    else
        value = defaultValue;
    end
end


function fid = openForWrite(fpath)
    % Open a file for writing; give a clear error if it is locked (e.g. open in Excel).
    fid = fopen(fpath, 'w');
    if fid == -1
        error('analyze_lkc_candidate_probe:fileLocked', ...
            ['Cannot open file for writing:\n  %s\n' ...
             'It may be open in another program (e.g. Excel). ' ...
             'Close the file and run again.'], fpath);
    end
end


function v = valueAt(x, idx)
    if isempty(x) || idx > numel(x)
        v = NaN;
    else
        v = x(idx);
    end
end


function v = boolAt(x, idx)
    if isempty(x) || idx > numel(x)
        v = 0;
    else
        v = double(x(idx));
    end
end


function v = col(rows, idx)
    v = [];
    for i = 1:numel(rows)
        if numel(rows{i}) >= idx
            x = rows{i}{idx};
            if isnumeric(x) || islogical(x)
                v(end+1) = double(x); %#ok<AGROW>
            end
        end
    end
end


function m = meanMaybe(x)
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = mean(x);
    end
end


function s = stdMaybe(x)
    x = x(isfinite(x));
    if numel(x) <= 1
        s = NaN;
    else
        s = std(x);
    end
end
