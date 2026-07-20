classdef REMO_new2_AdaMaO_CPR_F00 < REMO_new2_AdaMaO_CPR_FactorBase
% <multi/many> <real> <expensive> Legacy score source with hard relations.

    methods (Access = protected)
        function [sourceBit,relationBit] = factorBits(~)
            sourceBit   = 0;
            relationBit = 0;
        end
    end
end
