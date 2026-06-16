% RUN_BASELINE_TEMPLATE
% Copy this file before editing experiment parameters.
% Example usage in MATLAB from PlatEMO root:
%   run('ResearchExecution/scripts/run_baseline_template.m')

clear; clc;

algorithms = {@REMO};
problems   = {@DTLZ2};
objectives = [5];
seeds      = 1:2;
maxFE      = 300;

for a = 1:numel(algorithms)
    for p = 1:numel(problems)
        for m = objectives
            for s = seeds
                rng(s);
                fprintf('Running %s on %s, M=%d, seed=%d\n', ...
                    func2str(algorithms{a}), func2str(problems{p}), m, s);
                platemo( ...
                    'algorithm', algorithms{a}, ...
                    'problem', problems{p}, ...
                    'M', m, ...
                    'maxFE', maxFE, ...
                    'save', 1);
            end
        end
    end
end
