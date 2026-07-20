classdef REMO_new2_AdaMaO_CPR_F11 < REMO_new2_AdaMaO_CPR_FactorBase
% <multi/many> <real> <expensive> Continuous score source with soft relations.

    methods (Access = protected)
        function [sourceBit,relationBit] = factorBits(~)
            sourceBit   = 1;
            relationBit = 1;
        end
    end
end
