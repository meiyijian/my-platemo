classdef REMO_new2_AdaMaO_CPR_F11_HardVote < REMO_new2_AdaMaO_CPR_F11
% <multi/many> <real> <expensive> F11 threshold-vote micro-ablation.

    methods (Access = protected)
        function mode = preferenceAggregation(~)
            mode = 'hard_vote';
        end
    end
end
