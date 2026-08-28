function adjustedP = GGPHolmAdjust(rawP)
%GGPHOLMADJUST Apply Holm's step-down correction to a vector of p-values.
%   NaN entries remain NaN and are excluded from the correction family.

    validateattributes(rawP, {'numeric'}, {'real'}, mfilename, 'rawP');
    originalSize = size(rawP);
    rawP = rawP(:);
    adjustedP = NaN(size(rawP));
    valid = isfinite(rawP);
    if any(rawP(valid) < 0 | rawP(valid) > 1)
        error("GGP:InvalidPValue", "Finite p-values must lie in [0,1].");
    end

    validP = rawP(valid);
    numberOfTests = numel(validP);
    if numberOfTests > 0
        [sortedP, order] = sort(validP);
        multipliers = (numberOfTests:-1:1).';
        adjustedSorted = cummax(sortedP.*multipliers);
        adjustedSorted = min(adjustedSorted, 1);
        restored = zeros(numberOfTests, 1);
        restored(order) = adjustedSorted;
        adjustedP(valid) = restored;
    end
    adjustedP = reshape(adjustedP, originalSize);
end
