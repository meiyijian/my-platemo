function run_probe_experiment(varargin)
% run_probe_experiment - 跑 REMO_DiRel_probed 的一致性实验。
%
% Usage:
%   run_probe_experiment                    % 跑全部 4 问题 x 10 run
%   run_probe_experiment('runs', 3)         % 只跑 3 run，快速冒烟测试
%   run_probe_experiment('problems', {{@DTLZ2, 3, 10}})  % 只跑指定问题

    p = inputParser;
    p.addParameter('runs', 10);
    p.addParameter('problems', { ...
        {@DTLZ2, 3, 10}, ...
        {@DTLZ2, 5, 10}, ...
        {@MaF1,  5, 10}, ...
        {@MaF3,  8, 10}  ...
    });
    p.addParameter('maxFE', 300);
    p.parse(varargin{:});
    opt = p.Results;

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end
    addpath(this_dir);

    % 把 PlatEMO 根目录加到 path（必要时）
    platemo_root = fileparts(fileparts(fileparts(this_dir)));   % .../PlatEMO
    addpath(genpath(platemo_root));

    total = numel(opt.problems) * opt.runs;
    counter = 0;
    t_all = tic;

    for pi = 1:numel(opt.problems)
        prob_spec = opt.problems{pi};
        ProbFcn = prob_spec{1};
        M_val = prob_spec{2};
        D_val = prob_spec{3};
        prob_name = func2str(ProbFcn);

        for r = 1:opt.runs
            counter = counter + 1;
            out_file = fullfile(results_dir, sprintf('probe_%s_M%d_run%d.mat', prob_name, M_val, r));

            if exist(out_file, 'file')
                fprintf('[%d/%d] SKIP (exists): %s\n', counter, total, out_file);
                continue;
            end

            fprintf('[%d/%d] %s M=%d D=%d run=%d ... ', counter, total, prob_name, M_val, D_val, r);
            t0 = tic;
            try
                platemo( ...
                    'algorithm', {@REMO_DiRel_probed, -1, 0.3, 0.6, 6, 1000, 3, 3, out_file}, ...
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
