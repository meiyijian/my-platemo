function run_smoke_LKC()
% run_smoke_LKC - Small PlatEMO smoke run for REMO_LKC.

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    if exist('patternnet', 'file') ~= 2
        fprintf('run_smoke_LKC skipped: patternnet is unavailable.\n');
        return;
    end
    if exist('platemo', 'file') ~= 2
        root = fullfile(here, '..', '..', '..');
        addpath(genpath(root));
    end

    platemo('algorithm', @REMO_LKC, ...
            'problem', @DTLZ2, ...
            'M', 5, ...
            'D', 7, ...
            'maxFE', 100, ...
            'save', 0);
end
