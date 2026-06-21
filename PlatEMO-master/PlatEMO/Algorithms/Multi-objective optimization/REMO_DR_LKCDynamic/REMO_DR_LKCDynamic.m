classdef REMO_DR_LKCDynamic < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_DiRel_LKC backbone with dynamic LKC objective reduction each generation.
%
% k_red    --- 3    --- number of reduced objective groups
% tau_conf --- 0.3  --- uncertainty threshold for arbitration
% k_ref    --- 6    --- number of reference solutions
% gmax     --- 1000 --- surrogate-screened candidate budget
% K_ens    --- 3    --- bagging ensemble size
% nCells   --- 5    --- cells used by LKC LMVT feature estimation
% scalarGap--- 0.05 --- scalar tie threshold for relation labels
% lockGen  --- 3    --- reserved for parameter compatibility

    methods
        function main(Algorithm, Problem)
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', 'REMO_DR_Common'));
            DR_RunMain('lkcdynamic', Algorithm, Problem);
        end
    end
end
