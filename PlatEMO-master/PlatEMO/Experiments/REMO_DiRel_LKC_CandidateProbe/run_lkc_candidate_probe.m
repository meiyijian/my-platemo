function run_lkc_candidate_probe(varargin)
% run_lkc_candidate_probe - Run REMO_DiRel_LKC candidate-level probe.
%
% Usage:
%   run_lkc_candidate_probe
%   run_lkc_candidate_probe('runs', 3, 'maxFE', 300)
%   run_lkc_candidate_probe('problems', {{@DTLZ2, 5, 10}}, 'runs', 1)

    p = inputParser;
    p.addParameter('runs', 3);
    p.addParameter('problems', { ...
        {@DTLZ2,  5, 10}, ...
        {@DTLZ3,  5, 10}, ...
        {@DTLZ2, 10, 19}, ...
        {@DTLZ3, 10, 19}  ...
    });
    p.addParameter('maxFE', 300);
    p.addParameter('overwrite', false);
    p.parse(varargin{:});
    opt = p.Results;

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end

    addpath(this_dir, '-begin');
    platemo_root = fileparts(fileparts(fileparts(this_dir)));
    addpath(genpath(platemo_root));

    lkc_dir = fullfile(platemo_root, 'Algorithms', ...
        'Multi-objective optimization', 'REMO_DiRel_LKC');
    if exist(lkc_dir, 'dir')
        addpath(lkc_dir, '-begin');
    end
    addpath(this_dir, '-begin');

    total = numel(opt.problems) * opt.runs;
    counter = 0;
    t_all = tic;

    for pi = 1:numel(opt.problems)
        spec = opt.problems{pi};
        ProbFcn = spec{1};
        M_val = spec{2};
        D_val = spec{3};
        prob_name = func2str(ProbFcn);

        for r = 1:opt.runs
            counter = counter + 1;
            out_file = fullfile(results_dir, ...
                sprintf('lkc_candidate_%s_M%d_run%d.mat', prob_name, M_val, r));

            if exist(out_file, 'file') && ~opt.overwrite
                fprintf('[%d/%d] SKIP exists: %s\n', counter, total, out_file);
                continue;
            end

            fprintf('[%d/%d] %s M=%d D=%d run=%d ... ', ...
                counter, total, prob_name, M_val, D_val, r);
            t0 = tic;
            try
                platemo( ...
                    'algorithm', {@REMO_DiRel_LKC_candidateProbe, ...
                        -1, 0.3, 0.6, 6, 1000, 3, 3, 5, 0.65, 0.05, out_file}, ...
                    'problem', ProbFcn, ...
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

    fprintf('All LKC candidate probes done in %.1f min.\n', toc(t_all) / 60);
end
