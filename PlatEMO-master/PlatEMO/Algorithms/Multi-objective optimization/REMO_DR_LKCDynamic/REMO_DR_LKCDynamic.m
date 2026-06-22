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
            [k_red, tau_conf, k_ref, gmax, K_ens, nCells, scalarGap, lockGen] = ...
                Algorithm.ParameterSet(3, 0.3, 6, 1000, 3, 5, 0.05, 3);
            params = struct( ...
                'k_red', k_red, ...
                'tau_conf', tau_conf, ...
                'k_ref', k_ref, ...
                'gmax', gmax, ...
                'K_ens', K_ens, ...
                'nCells', nCells, ...
                'scalarGap', scalarGap, ...
                'lockGen', lockGen, ...
                'notTerminated', @(Population) Algorithm.NotTerminated(Population), ...
                'recordDiag', @(gen, Diag) Algorithm.recordDRDiag(gen, Diag));
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', 'REMO_DR_Common'));
            DR_RunMain('lkcdynamic', Algorithm, Problem, params);
        end
    end

    methods(Access = private)
        function recordDRDiag(Algorithm, gen, Diag)
            Algorithm.metric.drDiag{gen, 1} = Diag;
        end
    end
end
