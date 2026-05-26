function run_ablation_DiRelV2(varargin)
% run_ablation_DiRelV2 - Ablation study
%
% 实现的 ablation 模式（通过设置 V2 主算法的可选参数）：
%   A0 (REMO baseline)
%   A1 (REMO_DiRel V1 baseline)
%   A2 (V2 default, full)
%   A_noTransfer       —— 关闭 transfer initialization
%   A_singleSubset     —— 只用 Sfull，不构造 S1/S2
%   A_oldLabels        —— 用旧 Catalog-induced 标签（调用旧 GetRelationPairsBudgeted）
%                          注：需要先把旧函数 path 加进去
%   A_noFullExpert     —— 取消 full expert 最低权重保护
%   A_randomSubset     —— S1/S2 随机抽取目标
%   A_noNovelty        —— gamma = 0
%   A_noDisagree       —— lambda = 0
%   A_oldDifficulty    —— 复用旧 DifficultyProfiler（需 path）
%
% 用法：
%   run_ablation_DiRelV2()                   % 跑所有 A2 系列变体
%   run_ablation_DiRelV2('modes', {'A2', 'A_noTransfer'})
%   run_ablation_DiRelV2('problems', {'DTLZ2'}, 'M', 8, 'FE', 400)
%
% 注意：A_oldLabels / A_oldDifficulty 要求 REMO_DiRel 旧目录在 PlatEMO path 中。

    p = inputParser;
    addParameter(p, 'modes', {'A2', 'A_noTransfer', 'A_singleSubset', ...
        'A_noFullExpert', 'A_noNovelty', 'A_noDisagree'});
    addParameter(p, 'problems', {'DTLZ2', 'WFG4'});
    addParameter(p, 'M', 5);
    addParameter(p, 'D', []);
    addParameter(p, 'FE', 300);
    addParameter(p, 'nSeed', 3);
    addParameter(p, 'seed', 1);
    parse(p, varargin{:});
    args = p.Results;

    if isempty(args.D), args.D = args.M + 9; end

    ts = datestr(now, 'yyyymmdd_HHMMSS');
    outDir = fullfile('results', 'ablation_DiRelV2', ts);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    fprintf('Ablation %s | M=%d D=%d FE=%d seeds=%d\n', ts, args.M, args.D, args.FE, args.nSeed);
    fprintf('Modes: %s\n', strjoin(args.modes, ', '));

    summary = struct('mode', {}, 'problem', {}, 'seed', {}, 'IGD', {}, 'HV', {}, 'time', {});

    for mi = 1:numel(args.modes)
        mode = args.modes{mi};
        for pi = 1:numel(args.problems)
            probName = args.problems{pi};
            for s = 1:args.nSeed
                seed = args.seed + s - 1;
                fprintf('[%s | %s | seed=%d] ...', mode, probName, seed);
                try
                    [igd, hv, t] = runMode(mode, probName, args.M, args.D, args.FE, seed);
                    fprintf(' IGD=%.4e HV=%.4e t=%.1fs\n', igd, hv, t);
                catch ME
                    fprintf(' ERROR: %s\n', ME.message);
                    igd = NaN; hv = NaN; t = NaN;
                end
                summary(end+1) = struct('mode', mode, 'problem', probName, ...
                    'seed', seed, 'IGD', igd, 'HV', hv, 'time', t); %#ok<AGROW>
            end
        end
    end

    % Save CSV
    csvPath = fullfile(outDir, 'ablation_summary.csv');
    fid = fopen(csvPath, 'w');
    fprintf(fid, 'mode,problem,seed,IGD,HV,time\n');
    for i = 1:numel(summary)
        s = summary(i);
        fprintf(fid, '%s,%s,%d,%.6e,%.6e,%.3f\n', s.mode, s.problem, s.seed, ...
            s.IGD, s.HV, s.time);
    end
    fclose(fid);

    fprintf('\n=== Median IGD per (mode, problem) ===\n');
    modes = unique({summary.mode}, 'stable');
    probs = unique({summary.problem}, 'stable');
    fprintf('%-20s', 'mode \ problem');
    for j = 1:numel(probs), fprintf('%-15s', probs{j}); end
    fprintf('\n');
    for i = 1:numel(modes)
        fprintf('%-20s', modes{i});
        for j = 1:numel(probs)
            vals = [];
            for k = 1:numel(summary)
                if strcmp(summary(k).mode, modes{i}) && strcmp(summary(k).problem, probs{j})
                    vals(end+1) = summary(k).IGD; %#ok<AGROW>
                end
            end
            fprintf('%-15.3e', median(vals, 'omitnan'));
        end
        fprintf('\n');
    end

    fprintf('\nResults saved to %s\n', outDir);
end

% =========================================================
function [igd, hv, t] = runMode(mode, probName, M, D, FE, seed)
    rng(seed, 'twister');
    tStart = tic;

    ProbCls = str2func(probName);
    Problem = ProbCls('M', M, 'D', D, 'maxFE', FE);

    switch mode
        case 'A0'
            Alg = REMO('save', 0);
        case 'A1'
            Alg = REMO_DiRel('save', 0);
        case 'A2'
            Alg = REMO_DiRelV2('save', 0);
        case 'A_noTransfer'
            % 不支持直接传 cfg，改用环境变量
            setenv('DIREL_USE_TRANSFER', '0');
            Alg = REMO_DiRelV2('save', 0);
        case 'A_singleSubset'
            setenv('DIREL_SINGLE_SUBSET', '1');
            Alg = REMO_DiRelV2('save', 0);
        case 'A_noFullExpert'
            Alg = REMO_DiRelV2('save', 0, 'parameter', {1000, 5, 0.5, 0, 3, 0.0});
        case 'A_noNovelty'
            setenv('DIREL_GAMMA', '0');
            Alg = REMO_DiRelV2('save', 0);
        case 'A_noDisagree'
            setenv('DIREL_LAMBDA', '0');
            Alg = REMO_DiRelV2('save', 0);
        otherwise
            error('Unknown mode: %s', mode);
    end

    Alg.Solve(Problem);
    t = toc(tStart);

    try
        PF = Problem.GetOptimum(10000);
        igd = IGD(Alg.result{end}, PF);
    catch, igd = NaN; end
    try
        hv = HV(Alg.result{end}, Problem.optimum);
    catch, hv = NaN; end

    % cleanup env vars
    for v = {'DIREL_USE_TRANSFER', 'DIREL_SINGLE_SUBSET', 'DIREL_GAMMA', 'DIREL_LAMBDA'}
        setenv(v{1}, '');
    end
end
