classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Unweighted < REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont
% <2026> <multi/many> <real> <expensive>
% Continuous dual-PBI UniformMix with fixed unweighted relation pairs

    methods (Access = protected)
        function mode = relationPairMode(~,~,~,~,~)
            mode = 'conservative';
        end
    end
end
