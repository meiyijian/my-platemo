function [d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy)
%DifficultyProfiler - Lightweight objective difficulty ranking.
%
% The original DiRel implementation used leave-one-out/K-fold Kriging NRMSE
% per objective per generation. That was the first large runtime bottleneck.
% This version keeps the idea of online difficulty ranking but measures it
% with cheap population statistics:
%   model difficulty = 0.5 * objective-span score + 0.5 * stagnation score
%   conflict difficulty = 1 - Spearman conflict degree
%   d = alpha * model difficulty + (1-alpha) * conflict difficulty
% Smaller d means an easier objective.

    PopObj = Population.objs;
    [~, M] = size(PopObj);
    win_K  = size(H.d_score, 2);

    bestNow = min(PopObj, [], 1)';
    spanRaw = (max(PopObj, [], 1) - min(PopObj, [], 1))';
    spanScore = minmaxNorm(log1p(max(spanRaw, 0)));

    if ~isfield(H, 'best') || numel(H.best) ~= M || all(isnan(H.best))
        improveScore = ones(M, 1);
    else
        baseImprove  = max(abs(H.best), 1e-12);
        relImprove   = max((H.best - bestNow) ./ baseImprove, 0);
        improveScore = 1 - minmaxNorm(relImprove);
    end
    H.best = bestNow;

    modelDifficulty   = 0.5 .* spanScore + 0.5 .* improveScore;
    confRaw           = ConflictDegree(PopObj);
    confN             = minmaxNorm(confRaw);
    conflictDifficulty = 1 - confN;
    d_now             = alpha .* modelDifficulty + (1-alpha) .* conflictDifficulty;

    col = mod(gen-1, win_K) + 1;
    H.model(:, col)   = modelDifficulty;
    H.improve(:, col) = improveScore;
    H.conf(:, col)    = confN;
    H.d_score(:, col) = d_now;

    d_score = meanNoNan(H.d_score, 2);
    [~, ord] = sort(d_score, 'ascend');
    S_cand   = ord(1:min(k_easy, numel(ord)));
    S_easy   = RefineEasySubset(S_cand, PopObj, d_score, k_easy);
end

function y = minmaxNorm(x)
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end

function y = meanNoNan(X, dim)
    mask = ~isnan(X);
    cnt  = sum(mask, dim);
    X(~mask) = 0;
    y = sum(X, dim) ./ max(cnt, 1);
end
