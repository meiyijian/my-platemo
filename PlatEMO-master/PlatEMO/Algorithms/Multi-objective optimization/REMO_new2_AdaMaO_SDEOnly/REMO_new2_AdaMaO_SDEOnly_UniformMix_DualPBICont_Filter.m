classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Filter < REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont
% <2026> <multi/many> <real> <expensive>
% Continuous dual-PBI UniformMix with fixed agreement-filtered relation pairs

    methods (Access = protected)
        function mode = relationPairMode(~,~,~,~,~)
            mode = 'curriculum';
        end
    end
end
