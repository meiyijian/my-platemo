classdef REMO_new2_AdaMaO_SDEOnly_UniformMix < REMO_new2_AdaMaO_SDEOnly_ModeBase
% <2026> <multi/many> <real> <expensive>
% AdaMaO SDE-only with a fixed indicator probability of 0.5

    methods (Access = protected)
        function policy = candidatePolicy(~)
            policy = 'uniform_mix';
        end
    end
end
