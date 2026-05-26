function run_smoke_DiRelV2(varargin)
% run_smoke_DiRelV2 - Smoke test: 在小规模问题上跑 V2，并对比 REMO 与旧 REMO_DiRel
%
% 用法：
%   run_smoke_DiRelV2()                       % 默认配置
%   run_smoke_DiRelV2('seed', 1, 'M', 5)      % 自定义种子和目标数
%
% 默认配置：
%   problems = {DTLZ2, WFG4}, M = 5, FE = 300
%   algorithms = {REMO, REMO_DiRel, REMO_DiRelV2}
%   每个 problem×algorithm 跑 3 个 seed
%
% 输出：results/smoke_DiRelV2/<timestamp>/ 下保存
%   .mat 包含每次运行的 IGD / HV / 运行时间 / Diag
%   summary.csv

    p = inputParser;
    addParameter(p, 'seed',    1);
    addParameter(p, 'M',       5);
    addParameter(p, 'D',       []);
    addParameter(p, 'FE',      300);
    addParameter(p, 'problems', {'DTLZ2', 'WFG4'});
    addParameter(p, 'algorithms', {'REMO', 'REMO_DiRel', 'REMO_DiRelV2'});
    addParameter(p, 'nSeed',   3);
    parse(p, varargin{:});
    args = p.Results;

    if isempty(args.D)
        args.D = args.M + 9;  % 默认 DTLZ 风格
    end

    ts = datestr(now, 'yyyymmdd_HHMMSS');
    outDir = fullfile('results', 'smoke_DiRelV2', ts);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    log = {};
    log{end+1} = sprintf('Smoke test start at %s', datestr(now));
    log{end+1} = sprintf('M=%d D=%d FE=%d seeds=%d', args.M, args.D, args.FE, args.nSeed);
    fprintf('%s\n', log{end});

    summary = struct('algo', {}, 'problem', {}, 'seed', {}, 'IGD', {}, ...
        'HV', {}, 'time', {});

    for pi = 1:numel(args.problems)
        probName = args.problems{pi};
        for ai = 1:numel(args.algorithms)
            algName = args.algorithms{ai};
            for s = 1:args.nSeed
                seed = args.seed + s - 1;
                fprintf('[%s | %s | seed=%d] running...\n', algName, probName, seed);
                try
                    [igd, hv, t, Diag] = runOne(algName, probName, args.M, args.D, args.FE, seed);
                    fprintf('  IGD=%.4e HV=%.4e time=%.1fs\n', igd, hv, t);
                catch ME
                    fprintf('  ERROR: %s\n', ME.message);
                    igd = NaN; hv = NaN; t = NaN; Diag = struct();
                end
                summary(end+1) = struct('algo', algName, 'problem', probName, ...
                    'seed', seed, 'IGD', igd, 'HV', hv, 'time', t); %#ok<AGROW>
                fname = sprintf('%s_%s_seed%d.mat', algName, probName, seed);
                try
                    save(fullfile(outDir, fname), 'igd', 'hv', 't', 'Diag', '-v7');
                catch
                end
            end
        end
    end

    % Save summary CSV
    csvPath = fullfile(outDir, 'summary.csv');
    fid = fopen(csvPath, 'w');
    fprintf(fid, 'algo,problem,seed,IGD,HV,time\n');
    for i = 1:numel(summary)
        s = summary(i);
        fprintf(fid, '%s,%s,%d,%.6e,%.6e,%.3f\n', s.algo, s.problem, s.seed, ...
            s.IGD, s.HV, s.time);
    end
    fclose(fid);

    % Print median per (algo,problem)
    fprintf('\n=== Median IGD per (algo, problem) ===\n');
    [tab, algos, probs] = pivot(summary, 'IGD');
    fprintf('%-20s', 'algo \\ problem');
    for j = 1:numel(probs), fprintf('%-15s', probs{j}); end
    fprintf('\n');
    for i = 1:numel(algos)
        fprintf('%-20s', algos{i});
        for j = 1:numel(probs)
            fprintf('%-15.3e', tab(i, j));
        end
        fprintf('\n');
    end

    fprintf('\nResults saved to %s\n', outDir);
end

% =========================================================
function [igd, hv, t, Diag] = runOne(algName, probName, M, D, maxFE, seed)
    rng(seed, 'twister');
    tStart = tic;

    try
        ProblemClass = str2func(probName);
        Problem = ProblemClass('M', M, 'D', D, 'maxFE', maxFE);
    catch
        % Older PlatEMO API: positional
        Problem = ProblemClass('M', M, 'D', D);
        Problem.maxFE = maxFE;
    end

    AlgoClass = str2func(algName);
    Algorithm = AlgoClass('save', 0);

    Algorithm.Solve(Problem);

    t = toc(tStart);

    % Metrics: IGD requires reference PF
    try
        PF = Problem.GetOptimum(10000);
        igd = IGD(Algorithm.result{end}, PF);
    catch
        igd = NaN;
    end
    try
        hv = HV(Algorithm.result{end}, Problem.optimum);
    catch
        try
            hv = HV(Algorithm.result{end}, max(Algorithm.result{end}.objs, [], 1) * 1.1);
        catch
            hv = NaN;
        end
    end

    try
        Diag = Algorithm.metric.Diag;
    catch
        Diag = struct();
    end
end

function [tab, algos, probs] = pivot(summary, field)
    algos = unique({summary.algo}, 'stable');
    probs = unique({summary.problem}, 'stable');
    tab = nan(numel(algos), numel(probs));
    for i = 1:numel(algos)
        for j = 1:numel(probs)
            vals = [];
            for k = 1:numel(summary)
                if strcmp(summary(k).algo, algos{i}) && strcmp(summary(k).problem, probs{j})
                    vals(end+1) = summary(k).(field); %#ok<AGROW>
                end
            end
            if ~isempty(vals)
                tab(i, j) = median(vals, 'omitnan');
            end
        end
    end
end
