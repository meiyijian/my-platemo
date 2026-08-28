function metrics = GGPBinaryMetrics(selected, truth, score)
%GGPBINARYMETRICS Compute selection and discrimination metrics.
%   METRICS = GGPBINARYMETRICS(SELECTED, TRUTH, SCORE) returns precision,
%   recall, truth prevalence (chance), precision lift, and tie-aware ROC
%   AUC. A truth vector containing NaN denotes a censored future horizon;
%   all rate metrics are then NaN. ROC AUC is NaN for a single-class truth.

    selected = selected(:);
    truth = truth(:);
    score = score(:);
    numberOfRows = numel(truth);

    if numel(selected) ~= numberOfRows || numel(score) ~= numberOfRows
        error("GGP:MetricSizeMismatch", ...
            "selected, truth, and score must have the same number of rows.");
    end
    if ~islogical(selected)
        if any(~ismember(selected, [0, 1]))
            error("GGP:InvalidSelection", "selected must be logical or contain only 0 and 1.");
        end
        selected = logical(selected);
    end
    if any(~isfinite(score))
        error("GGP:InvalidScore", "score must contain finite values.");
    end

    selectedCount = nnz(selected);
    metrics = struct( ...
        "Censored", false, ...
        "PopulationSize", numberOfRows, ...
        "SelectedCount", selectedCount, ...
        "TruthPositiveCount", NaN, ...
        "TruePositiveCount", NaN, ...
        "Precision", NaN, ...
        "Recall", NaN, ...
        "Chance", NaN, ...
        "Lift", NaN, ...
        "AUC", NaN);

    if any(isnan(truth))
        if ~all(isnan(truth))
            error("GGP:PartiallyCensoredTruth", ...
                "A censored truth vector must contain NaN in every row.");
        end
        metrics.Censored = true;
        return;
    end
    if any(~ismember(truth, [0, 1]))
        error("GGP:InvalidTruth", "truth must contain only 0 and 1, or be fully censored with NaN.");
    end
    truth = logical(truth);

    truthPositiveCount = nnz(truth);
    truePositiveCount = nnz(selected & truth);
    metrics.TruthPositiveCount = truthPositiveCount;
    metrics.TruePositiveCount = truePositiveCount;
    metrics.Chance = truthPositiveCount/numberOfRows;

    if selectedCount > 0
        metrics.Precision = truePositiveCount/selectedCount;
    end
    if truthPositiveCount > 0
        metrics.Recall = truePositiveCount/truthPositiveCount;
    end
    if metrics.Chance > 0 && isfinite(metrics.Precision)
        metrics.Lift = metrics.Precision/metrics.Chance;
    end

    negativeCount = numberOfRows - truthPositiveCount;
    if truthPositiveCount > 0 && negativeCount > 0
        positiveScores = score(truth);
        negativeScores = score(~truth);
        pairwiseDifference = positiveScores - negativeScores.';
        metrics.AUC = (nnz(pairwiseDifference > 0) + ...
            0.5*nnz(pairwiseDifference == 0))/numel(pairwiseDifference);
    end
end
