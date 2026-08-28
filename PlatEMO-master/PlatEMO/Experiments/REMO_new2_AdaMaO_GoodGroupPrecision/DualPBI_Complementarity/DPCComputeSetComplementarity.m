function metrics = DPCComputeSetComplementarity(vSelected, aSelected, ...
        hSelected, labelNative, truth)
%DPCComputeSetComplementarity - Decompose dual-view selections and truth
%   METRICS = DPCComputeSetComplementarity(V,A,H,LABEL,TRUTH) computes
%   overlap, unique contribution, Hybrid provenance, and true-positive
%   metrics for equal-length selection and truth vectors.
%
%   See also DPCComputeComplementarityMetrics, GGPBinaryMetrics

    vectors = {vSelected, aSelected, hSelected, labelNative};
    names = ["V", "A", "H", "LabelNative"];
    for index = 1:numel(vectors)
        vectors{index} = validateSelection(vectors{index}, names(index));
    end
    vSelected = vectors{1};
    aSelected = vectors{2};
    hSelected = vectors{3};
    labelNative = vectors{4};
    truth = truth(:);

    numberOfRows = numel(vSelected);
    selectionSizes = cellfun(@numel, vectors);
    if any(selectionSizes ~= numberOfRows) || numel(truth) ~= numberOfRows
        error("DPC:SelectionSizeMismatch", ...
            "All selections and truth must have the same number of rows.");
    end
    if numberOfRows == 0
        error("DPC:EmptySelection", "Selection vectors cannot be empty.");
    end

    both = vSelected & aSelected;
    vOnly = vSelected & ~aSelected;
    aOnly = aSelected & ~vSelected;
    neither = ~vSelected & ~aSelected;
    unionVA = vSelected | aSelected;

    hybridBoth = hSelected & both;
    hybridVOnly = hSelected & vOnly;
    hybridAOnly = hSelected & aOnly;
    hybridNeither = hSelected & neither;

    metrics = makeEmptyMetrics();
    metrics.Censored = false;
    metrics.PopulationSize = numberOfRows;
    metrics.VSelectedCount = nnz(vSelected);
    metrics.ASelectedCount = nnz(aSelected);
    metrics.HybridSelectedCount = nnz(hSelected);
    metrics.LabelNativeCount = nnz(labelNative);
    metrics.BothCount = nnz(both);
    metrics.VOnlyCount = nnz(vOnly);
    metrics.AOnlyCount = nnz(aOnly);
    metrics.NeitherCount = nnz(neither);
    metrics.JaccardVA = safeRatio(nnz(both), nnz(unionVA));
    metrics.AgreementVA = (nnz(both) + nnz(neither))/numberOfRows;
    metrics.JaccardHV = jaccardIndex(hSelected, vSelected);
    metrics.JaccardHA = jaccardIndex(hSelected, aSelected);
    metrics.JaccardVLabelNative = jaccardIndex(vSelected, labelNative);
    metrics.JaccardHLabelNative = jaccardIndex(hSelected, labelNative);
    metrics.HybridFromBoth = nnz(hybridBoth);
    metrics.HybridFromVOnly = nnz(hybridVOnly);
    metrics.HybridFromAOnly = nnz(hybridAOnly);
    metrics.HybridFromNeither = nnz(hybridNeither);

    if metrics.BothCount + metrics.VOnlyCount + ...
            metrics.AOnlyCount + metrics.NeitherCount ~= numberOfRows
        error("DPC:SetConservationFailure", ...
            "The V/A partition does not conserve the population size.");
    end
    if metrics.HybridFromBoth + metrics.HybridFromVOnly + ...
            metrics.HybridFromAOnly + metrics.HybridFromNeither ~= ...
            metrics.HybridSelectedCount
        error("DPC:HybridConservationFailure", ...
            "The Hybrid provenance partition is not conservative.");
    end

    if any(isnan(truth))
        if ~all(isnan(truth))
            error("DPC:PartiallyCensoredTruth", ...
                "A censored truth vector must contain only NaN values.");
        end
        metrics.Censored = true;
        return;
    end
    if any(~ismember(truth, [0, 1]))
        error("DPC:InvalidTruth", ...
            "Truth must contain only 0 and 1, or be fully censored.");
    end
    truth = logical(truth);

    truthPositiveCount = nnz(truth);
    truePositiveUnion = nnz(truth & unionVA);
    metrics.TruthPositiveCount = truthPositiveCount;
    metrics.TPBoth = nnz(truth & both);
    metrics.TPVOnly = nnz(truth & vOnly);
    metrics.TPAOnly = nnz(truth & aOnly);
    metrics.UniqueTPRateV = safeRatio(metrics.TPVOnly, truthPositiveCount);
    metrics.UniqueTPRateA = safeRatio(metrics.TPAOnly, truthPositiveCount);
    metrics.UniquePrecisionV = safeRatio(metrics.TPVOnly, metrics.VOnlyCount);
    metrics.UniquePrecisionA = safeRatio(metrics.TPAOnly, metrics.AOnlyCount);
    metrics.UniqueTPShare = safeRatio( ...
        metrics.TPVOnly + metrics.TPAOnly, truePositiveUnion);
    metrics.VTruePositive = nnz(truth & vSelected);
    metrics.ATruePositive = nnz(truth & aSelected);
    metrics.HybridTP = nnz(truth & hSelected);
    metrics.VPrecision = safeRatio( ...
        metrics.VTruePositive, metrics.VSelectedCount);
    metrics.APrecision = safeRatio( ...
        metrics.ATruePositive, metrics.ASelectedCount);
    metrics.HybridPrecision = safeRatio( ...
        metrics.HybridTP, metrics.HybridSelectedCount);
    metrics.HybridTPFromBoth = nnz(truth & hybridBoth);
    metrics.HybridTPFromVOnly = nnz(truth & hybridVOnly);
    metrics.HybridTPFromAOnly = nnz(truth & hybridAOnly);
    metrics.HybridTPFromNeither = nnz(truth & hybridNeither);
    metrics.LostTrueFromV = nnz(truth & vSelected & ~hSelected);
    metrics.LostTrueFromA = nnz(truth & aSelected & ~hSelected);
end

function selection = validateSelection(selection, name)
    selection = selection(:);
    if ~islogical(selection)
        if ~isnumeric(selection) || any(~ismember(selection, [0, 1]))
            error("DPC:InvalidSelection", ...
                "%s must be logical or contain only 0 and 1.", name);
        end
        selection = logical(selection);
    end
end

function value = jaccardIndex(first, second)
    value = safeRatio(nnz(first & second), nnz(first | second));
end

function value = safeRatio(numerator, denominator)
    if denominator == 0
        value = NaN;
    else
        value = numerator/denominator;
    end
end

function metrics = makeEmptyMetrics()
    metrics = struct( ...
        "Censored", false, ...
        "PopulationSize", NaN, ...
        "VSelectedCount", NaN, ...
        "ASelectedCount", NaN, ...
        "HybridSelectedCount", NaN, ...
        "LabelNativeCount", NaN, ...
        "BothCount", NaN, ...
        "VOnlyCount", NaN, ...
        "AOnlyCount", NaN, ...
        "NeitherCount", NaN, ...
        "JaccardVA", NaN, ...
        "AgreementVA", NaN, ...
        "JaccardHV", NaN, ...
        "JaccardHA", NaN, ...
        "JaccardVLabelNative", NaN, ...
        "JaccardHLabelNative", NaN, ...
        "HybridFromBoth", NaN, ...
        "HybridFromVOnly", NaN, ...
        "HybridFromAOnly", NaN, ...
        "HybridFromNeither", NaN, ...
        "TruthPositiveCount", NaN, ...
        "TPBoth", NaN, ...
        "TPVOnly", NaN, ...
        "TPAOnly", NaN, ...
        "UniqueTPRateV", NaN, ...
        "UniqueTPRateA", NaN, ...
        "UniquePrecisionV", NaN, ...
        "UniquePrecisionA", NaN, ...
        "UniqueTPShare", NaN, ...
        "VTruePositive", NaN, ...
        "ATruePositive", NaN, ...
        "HybridTP", NaN, ...
        "VPrecision", NaN, ...
        "APrecision", NaN, ...
        "HybridPrecision", NaN, ...
        "HybridTPFromBoth", NaN, ...
        "HybridTPFromVOnly", NaN, ...
        "HybridTPFromAOnly", NaN, ...
        "HybridTPFromNeither", NaN, ...
        "LostTrueFromV", NaN, ...
        "LostTrueFromA", NaN);
end

