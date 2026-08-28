function [simpleScore, weightedScore, ambiguity] = CVPRelationScores(Smodel, candidates)
%CVPRELATIONSCORES Relation-network candidate scores, both aggregations.
%   [SIMPLE, WEIGHTED, AMBIGUITY] = CVPRELATIONSCORES(SMODEL, CANDIDATES)
%   reproduces the frozen model_select scoring of AdaMaOSelection with ONE
%   forward pass and returns both aggregation variants:
%
%     SIMPLE    - unweighted mean over each pair group (conservative /
%                 indicator path of the shipped code)
%     WEIGHTED  - softmax-sharpness weighted mean (explore path)
%     AMBIGUITY - 1 - mean(max softmax probability) over all pairs of the
%                 candidate. This is prediction ambiguity, NOT epistemic
%                 uncertainty and NOT a calibrated confidence.
%
%   Returning both from one forward pass keeps the arms comparable without
%   paying for a second network evaluation.

    modelX = Smodel.X;
    positive = modelX(Smodel.Y == 1, :);
    negative = modelX(Smodel.Y ~= 1, :);
    nPositive = size(positive, 1);
    nNegative = size(negative, 1);
    nCandidates = size(candidates, 1);

    simpleScore = zeros(nCandidates, 1);
    weightedScore = zeros(nCandidates, 1);
    ambiguity = ones(nCandidates, 1);
    if nPositive == 0 || nNegative == 0 || nCandidates == 0
        return;
    end

    pairsPerCandidate = 2 * (nPositive + nNegative);
    testData = zeros(pairsPerCandidate * nCandidates, 2 * size(positive, 2));
    for candidate = 1:nCandidates
        offset = (candidate - 1) * pairsPerCandidate;
        xi = repmat(candidates(candidate, :), nPositive, 1);
        testData(offset + (1:nPositive), :) = [positive, xi];
        testData(offset + nPositive + (1:nPositive), :) = [xi, positive];
        xi = repmat(candidates(candidate, :), nNegative, 1);
        testData(offset + 2*nPositive + (1:nNegative), :) = [negative, xi];
        testData(offset + 2*nPositive + nNegative + (1:nNegative), :) = [xi, negative];
    end

    normalized = mapminmax('apply', testData', Smodel.mp_struct)';
    prediction = Smodel.net(normalized')';
    confidence = max(prediction, [], 2);

    for candidate = 1:nCandidates
        offset = (candidate - 1) * pairsPerCandidate;
        groups = { ...
            offset + (1:nPositive), ...
            offset + nPositive + (1:nPositive), ...
            offset + 2*nPositive + (1:nNegative), ...
            offset + 2*nPositive + nNegative + (1:nNegative)};
        simpleParts = cellfun(@(idx) mean(prediction(idx, :), 1), ...
            groups, 'UniformOutput', false);
        weightedParts = cellfun(@(idx) weightedMean( ...
            prediction(idx, :), confidence(idx)), groups, 'UniformOutput', false);
        simpleScore(candidate) = evidenceScore(simpleParts);
        weightedScore(candidate) = evidenceScore(weightedParts);
        ambiguity(candidate) = 1 - mean(confidence([groups{:}]));
    end
end

function score = evidenceScore(parts)
% Frozen C_SCORE bookkeeping of AdaMaOSelection.model_select.
    a = parts{1};   % [C1, Xi]
    b = parts{2};   % [Xi, C1]
    c = parts{3};   % [C2, Xi]
    d = parts{4};   % [Xi, C2]
    positive = a(2) + a(3) + b(2) + b(1) + c(3) + d(1);
    negative = a(1) + b(3) + c(2) + c(1) + d(2) + d(3);
    score = positive - negative;
end

function value = weightedMean(x, w)
    w = w(:);
    value = sum(x .* w, 1) ./ (sum(w) + eps);
end
