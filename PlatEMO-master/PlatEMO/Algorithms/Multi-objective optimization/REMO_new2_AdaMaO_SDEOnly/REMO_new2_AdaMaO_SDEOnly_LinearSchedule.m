classdef REMO_new2_AdaMaO_SDEOnly_LinearSchedule < REMO_new2_AdaMaO_SDEOnly_ModeBase
% <2026> <multi/many> <real> <expensive>
% AdaMaO SDE-only with P_ind equal to post-initialization progress

    methods (Access = protected)
        function policy = candidatePolicy(~)
            policy = 'linear_schedule';
        end
    end
end
