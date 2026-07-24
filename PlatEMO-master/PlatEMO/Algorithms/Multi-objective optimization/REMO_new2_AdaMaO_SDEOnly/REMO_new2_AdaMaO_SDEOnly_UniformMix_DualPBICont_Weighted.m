classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Weighted < REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont
% <2026> <multi/many> <real> <expensive>
% Continuous dual-PBI UniformMix with fixed agreement-weighted relation pairs

    methods (Access = protected)
        function mode = relationPairMode(~,~,~,~,~)
            mode = 'weighted';
        end
    end
end
