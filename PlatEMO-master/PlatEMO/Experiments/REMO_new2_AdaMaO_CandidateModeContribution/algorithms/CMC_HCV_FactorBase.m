classdef CMC_HCV_FactorBase < CMC_HCV_Core
%CMC_HCV_FACTORBASE Fixed-K host for Stage 2/3 drop-one arms.
    methods (Access = protected)
        function value = isAudit(~)
            value = false;
        end
    end
end
