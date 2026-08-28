function CVPValidateParameters(arm, gmax, pMix, rGood, qKeep, lambda0, ...
    nMin, nMax, oracleEvery, oraclePoolLimit, oracleRefSize)
%CVPVALIDATEPARAMETERS Fail fast on malformed probe parameters.

    requirePositiveInteger(arm + 1, 'arm');
    if arm < 0 || arm > 4
        error("CVP:InvalidParameter", "arm must be an integer in 0..4.");
    end
    requirePositiveInteger(gmax, 'gmax');
    requireUnitInterval(pMix, 'pMix');
    if ~isnumeric(rGood) || ~isscalar(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error("CVP:InvalidParameter", "rGood must be in (0,0.5].");
    end
    requireUnitInterval(qKeep, 'qKeep');
    if ~isnumeric(lambda0) || ~isscalar(lambda0) || ~isfinite(lambda0) || lambda0 < 0
        error("CVP:InvalidParameter", "lambda0 must be nonnegative.");
    end
    requirePositiveInteger(nMin, 'nMin');
    requirePositiveInteger(nMax, 'nMax');
    if nMin > nMax
        error("CVP:InvalidParameter", "nMin must not exceed nMax.");
    end
    requirePositiveInteger(oracleEvery, 'oracleEvery');
    requirePositiveInteger(oraclePoolLimit, 'oraclePoolLimit');
    if oraclePoolLimit < nMax
        error("CVP:InvalidParameter", ...
            "oraclePoolLimit must be at least nMax.");
    end
    requirePositiveInteger(oracleRefSize, 'oracleRefSize');
end

function requirePositiveInteger(value, name)
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
            value < 1 || value ~= floor(value)
        error("CVP:InvalidParameter", "%s must be a positive integer.", name);
    end
end

function requireUnitInterval(value, name)
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
            value < 0 || value > 1
        error("CVP:InvalidParameter", "%s must be in [0,1].", name);
    end
end
