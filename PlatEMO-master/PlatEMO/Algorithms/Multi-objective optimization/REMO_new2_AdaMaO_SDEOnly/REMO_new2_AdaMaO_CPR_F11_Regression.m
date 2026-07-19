classdef REMO_new2_AdaMaO_CPR_F11_Regression < REMO_new2_AdaMaO_CPR_F11
% <multi/many> <real> <expensive> F11 scalar-regression micro-ablation.

    methods (Access = protected)
        function kind = surrogateKind(~)
            kind = 'regression';
        end
    end
end
