classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Original < REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase
% <2026> <multi/many> <real> <expensive>
% UniformMix with original unweighted relation-network training

    methods (Access = protected)
        function mode = relationPairMode(~,varargin)
            mode = 'conservative';
        end
    end
end
