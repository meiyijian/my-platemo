classdef REMO_new2_AdaMaO_SDEOnly_AlwaysIndicator < REMO_new2_AdaMaO_SDEOnly_ModeBase
% <2026> <multi/many> <real> <expensive>
% AdaMaO SDE-only using indicator mode whenever its model is available

    methods (Access = protected)
        function policy = candidatePolicy(~)
            policy = 'always_indicator';
        end
    end
end
