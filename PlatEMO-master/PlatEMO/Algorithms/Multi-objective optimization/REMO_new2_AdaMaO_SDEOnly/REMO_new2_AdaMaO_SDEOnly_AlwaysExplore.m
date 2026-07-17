classdef REMO_new2_AdaMaO_SDEOnly_AlwaysExplore < REMO_new2_AdaMaO_SDEOnly_ModeBase
% <2026> <multi/many> <real> <expensive>
% AdaMaO SDE-only with candidate selection always in explore mode

    methods (Access = protected)
        function policy = candidatePolicy(~)
            policy = 'always_explore';
        end
    end
end
