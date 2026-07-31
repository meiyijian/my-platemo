classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted < REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase
% <2026> <multi/many> <real> <expensive>
% UniformMix with agreement-weighted relation-network training

    methods (Access = protected)
        function mode = relationPairMode(~,varargin)
            mode = 'weighted';
        end
    end
end
