classdef REMO_new2_AdaMaO_CPR_F01 < REMO_new2_AdaMaO_CPR_FactorBase
% <multi/many> <real> <expensive> Legacy score source with soft relations.

    methods (Access = protected)
        function [sourceBit,relationBit] = factorBits(~)
            sourceBit   = 0;
            relationBit = 1;
        end
    end
end
