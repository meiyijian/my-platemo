function run_dualnet_experiment(varargin)
% run_dualnet_experiment - 跑双网络对比探针实验。
%
% Usage:
%   run_dualnet_experiment                     % 跑全部问题 x 5 run
%   run_dualnet_experiment('runs', 2)          % 只跑 2 run
%   run_dualnet_experiment('maxFE', 200)       % 快速冒烟测试

    p = inputParser;
    p.addParameter('runs', 10);
    p.addParameter('problems', { ...
        {@DTLZ2,  5, 10}, ...
        {@DTLZ3,  5, 10}, ...
        {@DTLZ2, 10, 19}, ...
        {@DTLZ3, 10, 19}, ...
        {@DTLZ2, 15, 24}, ...
        {@DTLZ3, 15, 24}  ...
    });
    p.addParameter('maxFE', 500);
    p.parse(varargin{:});
    opt = p.Results;

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end
    addpath(this_dir);

    platemo_root = fileparts(fileparts(fileparts(this_dir)));
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
            out_file = fullfile(results_dir, ...
                sprintf('dualnet_%s_M%d_run%d.mat', prob_name, M_val, r));

            if exist(out_file, 'file')
                fprintf('[%d/%d] SKIP (exists): %s\n', counter, total, out_file);
                continue;
            end

            fprintf('[%d/%d] %s M=%d D=%d run=%d ... ', counter, total, prob_name, M_val, D_val, r);
            t0 = tic;
            try
                platemo( ...
                    'algorithm', {@REMO_DiRel_dualProbe, -1, 0.3, 0.6, 6, 1000, 3, 3, out_file}, ...
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
