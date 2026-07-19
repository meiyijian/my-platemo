classdef REMO_new2_AdaMaO_CPR_F10 < REMO_new2_AdaMaO_CPR_FactorBase
% <multi/many> <real> <expensive> Continuous score source with hard relations.

    methods (Access = protected)
        function [sourceBit,relationBit] = factorBits(~)
            sourceBit   = 1;
            relationBit = 0;
        end
    end
end
