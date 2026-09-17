function [info, cleanup] = LTGGPSetupPaths()
    here = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(here));
    old = path; cleanup = onCleanup(@() path(old));
    addpath(genpath(fullfile(root,'Algorithms')));
    addpath(genpath(fullfile(root,'Problems')));
    addpath(genpath(fullfile(root,'Utilities')));
    addpath(genpath(fullfile(root,'Metrics')));
    addpath(root);
    addpath(fullfile(fileparts(here),'REMO_new2_AdaMaO_UniformMix_LabelValidation'));
    addpath(here, fullfile(here,'algorithms'));
    info = struct('ExperimentDirectory',here,'PlatEMODirectory',root, ...
        'EquivalenceEvidence',fullfile(here,'equivalence_passed.txt'));
end
