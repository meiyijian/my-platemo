classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum < REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase
% <2026> <multi/many> <real> <expensive>
% UniformMix with confidence-filtered relation-network training

    methods (Access = protected)
        function mode = relationPairMode(~,varargin)
            mode = 'curriculum';
        end
    end
end
