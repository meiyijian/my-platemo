function run_smoke_SGDA()
% run_smoke_SGDA - Smoke run on DTLZ2 with M=5 and a small FE budget.

    thisDir = fileparts(mfilename('fullpath'));
    platemoRoot = fullfile(thisDir, '..', '..', '..');
    addpath(genpath(platemoRoot));

    fprintf('Running REMO_DiRel_SGDA smoke test on DTLZ2 (M=5)...\n');
    platemo('algorithm', @REMO_DiRel_SGDA, ...
            'problem', @DTLZ2, ...
            'N', 20, 'M', 5, 'D', 7, ...
            'maxFE', 120, 'save', 0);
    fprintf('Smoke test finished.\n');
end
