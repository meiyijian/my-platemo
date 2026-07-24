classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont < REMO_new2_AdaMaO_SDEOnly_DualPBIContModeBase
% <2026> <multi/many> <real> <expensive>
% AdaMaO UniformMix with continuous dual-PBI relation supervision

    methods (Access = protected)
        function policy = candidatePolicy(~)
            policy = 'uniform_mix';
        end
    end
end
