function tab = collect_results_DiRelV2(resultsDir, varargin)
% collect_results_DiRelV2 - Aggregate smoke/ablation .csv into a table
%
% 用法：
%   tab = collect_results_DiRelV2('results/smoke_DiRelV2')      % 最近一次
%   tab = collect_results_DiRelV2('results/ablation_DiRelV2/20260526_120000')
%   tab = collect_results_DiRelV2(..., 'metric', 'IGD')
%
% 输出：
%   tab : MATLAB table 或 struct array，行是 (algo/mode, problem) 中位数 / std

    p = inputParser;
    addParameter(p, 'metric', 'IGD');
    parse(p, varargin{:});
    metric = p.Results.metric;

    if ~exist(resultsDir, 'dir')
        error('Directory not found: %s', resultsDir);
    end

    % Find summary.csv recursively
    csvs = dir(fullfile(resultsDir, '**', '*.csv'));
    if isempty(csvs)
        error('No .csv found in %s', resultsDir);
    end

    rows = {};
    for i = 1:numel(csvs)
        fpath = fullfile(csvs(i).folder, csvs(i).name);
        rows{end+1} = readtable(fpath); %#ok<AGROW>
    end
    all = vertcat(rows{:});

    % Pick the key column: 'algo' or 'mode'
    if any(strcmp(all.Properties.VariableNames, 'algo'))
        keyCol = 'algo';
    elseif any(strcmp(all.Properties.VariableNames, 'mode'))
        keyCol = 'mode';
    else
        error('No algo/mode column');
    end

    keys = unique(all.(keyCol), 'stable');
    probs = unique(all.problem, 'stable');

    % Build output table
    tab = struct();
    tab.key = keys;
    tab.problems = probs;
    tab.median = nan(numel(keys), numel(probs));
    tab.std    = nan(numel(keys), numel(probs));
    tab.wins   = nan(numel(keys), numel(probs));

    for i = 1:numel(keys)
        for j = 1:numel(probs)
            mask = strcmp(all.(keyCol), keys{i}) & strcmp(all.problem, probs{j});
            vals = all.(metric)(mask);
            if ~isempty(vals)
                tab.median(i, j) = median(vals, 'omitnan');
                tab.std(i, j)    = std(vals, 'omitnan');
            end
        end
    end

    % Print
    fprintf('\n=== %s median ===\n', metric);
    fprintf('%-20s', [keyCol ' \ problem']);
    for j = 1:numel(probs), fprintf('%-15s', probs{j}); end
    fprintf('\n');
    for i = 1:numel(keys)
        fprintf('%-20s', keys{i});
        for j = 1:numel(probs)
            fprintf('%-15.3e', tab.median(i, j));
        end
        fprintf('\n');
    end
end
