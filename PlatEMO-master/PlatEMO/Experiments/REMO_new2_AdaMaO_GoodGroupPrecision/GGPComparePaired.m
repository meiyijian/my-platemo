function comparison = GGPComparePaired(valuesA, valuesB)
%GGPCOMPAREPAIRED Summarize a paired, higher-is-better comparison.
%   The effect sizes are paired win probability and matched-pairs rank
%   biserial correlation. Relative improvement is computed within each
%   valid pair before averaging.

    validateattributes(valuesA, {'numeric'}, {'vector', 'real'}, ...
        mfilename, 'valuesA');
    validateattributes(valuesB, {'numeric'}, {'vector', 'real'}, ...
        mfilename, 'valuesB');
    if numel(valuesA) ~= numel(valuesB)
        error("GGP:UnpairedInput", "valuesA and valuesB must have equal lengths.");
    end

    valuesA = valuesA(:);
    valuesB = valuesB(:);
    valid = isfinite(valuesA) & isfinite(valuesB);
    valuesA = valuesA(valid);
    valuesB = valuesB(valid);
    difference = valuesA - valuesB;
    numberOfPairs = numel(difference);

    comparison = struct( ...
        "NumberOfPairs", numberOfPairs, ...
        "MeanA", NaN, ...
        "MeanB", NaN, ...
        "MeanDelta", NaN, ...
        "MedianDelta", NaN, ...
        "MeanRelativeImprovementPct", NaN, ...
        "PValueRaw", NaN, ...
        "PairedWinProbability", NaN, ...
        "RankBiserial", NaN);
    if numberOfPairs == 0
        return;
    end

    comparison.MeanA = mean(valuesA);
    comparison.MeanB = mean(valuesB);
    comparison.MeanDelta = mean(difference);
    comparison.MedianDelta = median(difference);
    comparison.PairedWinProbability = ...
        (nnz(difference > 0) + 0.5*nnz(difference == 0))/numberOfPairs;

    relativeValid = abs(valuesB) > eps(max(1, max(abs(valuesB))));
    if any(relativeValid)
        relativeImprovement = difference(relativeValid)./abs(valuesB(relativeValid))*100;
        comparison.MeanRelativeImprovementPct = mean(relativeImprovement);
    end

    nonzero = difference ~= 0;
    if any(nonzero)
        absoluteRanks = tiedrank(abs(difference(nonzero)));
        signedDifference = difference(nonzero);
        positiveRank = sum(absoluteRanks(signedDifference > 0));
        negativeRank = sum(absoluteRanks(signedDifference < 0));
        comparison.RankBiserial = ...
            (positiveRank - negativeRank)/(positiveRank + negativeRank);
    else
        comparison.RankBiserial = 0;
    end

    if numberOfPairs >= 2
        if all(difference == 0)
            comparison.PValueRaw = 1;
        else
            comparison.PValueRaw = signrank(valuesA, valuesB);
        end
    end
end
