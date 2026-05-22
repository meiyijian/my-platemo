function run_difficulty_experiment(varargin)
% run_difficulty_experiment - 跑目标难度分离度诊断实验。
%
% Usage:
%   run_difficulty_experiment                     % 跑全部问题 x 10 run
%   run_difficulty_experiment('runs', 2)          % 只跑 2 run
%   run_difficulty_experiment('maxFE', 200)       % 快速冒烟测试

    p = inputParser;
    p.addParameter('runs', 10);
    p.addParameter('problems', { ...
        {@DTLZ2, 3, 10}, ...
        {@DTLZ2, 5, 10}, ...
        {@DTLZ2, 8, 10}, ...
        {@DTLZ2, 10, 10}, ...
        {@DTLZ4, 3, 10}, ...
        {@DTLZ4, 5, 10}, ...
        {@DTLZ4, 8, 10}, ...
        {@DTLZ4, 10, 10}, ...
        {@MaF1, 3, 10}, ...
        {@MaF1, 5, 10}, ...
        {@MaF1, 8, 10}, ...
        {@MaF1, 10, 10}  ...
    });
    p.addParameter('maxFE', 300);
    p.parse(varargin{:});
    opt = p.Results;

    % 兼容单问题调用：{@DTLZ2,3,10} 会被解析为 1x3 cell，需要包一层
    if ~isempty(opt.problems) && ~iscell(opt.problems{1})
        opt.problems = {opt.problems};
    end

    this_dir    = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end
    addpath(this_dir);

    platemo_root = fileparts(fileparts(fileparts(this_dir)));
    addpath(genpath(platemo_root));

    total    = numel(opt.problems) * opt.runs;
    counter  = 0;
    t_all    = tic;

    for pi = 1:numel(opt.problems)
        prob_spec = opt.problems{pi};
        ProbFcn   = prob_spec{1};
        M_val     = prob_spec{2};
        D_val     = prob_spec{3};
        prob_name = func2str(ProbFcn);

        for r = 1:opt.runs
            counter  = counter + 1;
            out_file = fullfile(results_dir, ...
                sprintf('remo_%s_M%d_run%d.mat', prob_name, M_val, r));

            if exist(out_file, 'file')
                fprintf('[%d/%d] SKIP (exists): %s\n', counter, total, out_file);
                continue;
            end

            fprintf('[%d/%d] %s M=%d D=%d run=%d ... ', ...
                counter, total, prob_name, M_val, D_val, r);
            t0 = tic;
            try
                platemo( ...
                    'algorithm', {@REMO_probed, 6, 3000, out_file}, ...
                    'problem',   ProbFcn, ...
                    'M', M_val, 'D', D_val, ...
                    'maxFE', opt.maxFE, ...
                    'save', 0, ...
                    'run', r);
                fprintf('done (%.1fs)\n', toc(t0));
            catch ME
                fprintf('FAILED: %s\n', ME.message);
            end
        end
    end

    fprintf('All done in %.1f min.\n', toc(t_all)/60);
end
