function Next = SurrogateAssistedSelection(Problem, Archive, Input, wmax, Smodel, Elite)
% SurrogateAssistedSelection - Surrogate-assisted selection with Dual-Space Regularization
%
% This function implements the core innovation of DSR_REMO: Dual-Space Regularization.
% It combines neural network prediction with spatial prior weighting to select
% promising candidates.
%
% Dual-Space Regularization Logic:
% 1. Extract Spatial Prior: Find SDR non-dominated solutions (golden solutions)
%    from Archive, compute mean vector mu and covariance matrix K_mat
% 2. Neural Network Scoring: Pair candidates with Elite solutions, get S_model
% 3. Spatial Weighting: Compute Mahalanobis distance and position weight W_pos
% 4. Joint Scoring: S_final = S_model * W_pos (penalize overconfident predictions)
%
% Input:
%   Problem - Problem object
%   Archive - SOLUTION array, all evaluated solutions (for spatial prior)
%   Input   - N x D matrix, current population decisions
%   wmax    - Maximum number of surrogate evaluations
%   Smodel  - Struct containing trained model and related data
%   Elite   - SOLUTION array, elite solutions for pairing
%
% Output:
%   Next - Selected candidate solutions for real evaluation (top 5)
%
% Copyright (c) 2025 BIMK Group.

    if isempty(Elite) || length(Elite) < 1
        Next = [];
        return;
    end
    
    [mu, K_mat_inv] = ExtractSpatialPrior(Archive);
    
    N = size(Input, 1);
    Next = OperatorGA(Problem, Input, {1, 15, 1, 5});
    i = 0;
    while i < wmax
        [sorted_index, ~, ~] = model_select(Smodel, Next, Elite, mu, K_mat_inv);
        Input = Next(sorted_index(1:min(N, size(Next, 1))), :);
        Next = OperatorGA(Problem, Input, {1, 15, 1, 5});
        i = i + size(Next, 1);
    end
    
    [~, scores, ~] = model_select(Smodel, Next, Elite, mu, K_mat_inv);
    
    [~, ind] = sort(scores, 'descend');
    Next = Next(ind(1:min(5, size(Next, 1))), :);
end

function [mu, K_mat_inv] = ExtractSpatialPrior(Archive)
% ExtractSpatialPrior - Compute spatial prior from SDR non-dominated solutions
%
% Output:
%   mu       - D x 1 vector, mean of golden solutions
%   K_mat_inv - D x D matrix, inverse of covariance matrix

    PopObj = Archive.objs;
    PopDec = Archive.decs;
    N = size(PopObj, 1);
    D = size(PopDec, 2);
    
    [dominate, ~, ~] = CalSDR(PopObj);
    
    dominated = any(dominate, 1);
    goldenIdx = ~dominated;
    
    X_gold = PopDec(goldenIdx, :);
    
    nGold = size(X_gold, 1);
    if nGold < 2
        mu = mean(PopDec, 1);
        K_mat = cov(PopDec) + 1e-6 * eye(D);
    else
        mu = mean(X_gold, 1);
        K_mat = cov(X_gold) + 1e-6 * eye(D);
    end
    
    K_mat_inv = inv(K_mat);
end

function [ind, S_final, S_model] = model_select(Smodel, Next, Elite, mu, K_mat_inv)
% model_select - Dual-space scoring combining neural network and spatial prior

    Elite_decs = Elite.decs;
    nElite = size(Elite_decs, 1);
    Next_num = size(Next, 1);
    D = size(Next, 2);
    
    S_model = zeros(Next_num, 1);
    
    all_testdata = zeros(2 * nElite * Next_num, 2 * D);
    for i = 1 : size(Next, 1)
        original = (i - 1) * 2 * nElite;
        Xi = repmat(Next(i, :), nElite, 1);
        all_testdata(original + 1 : original + nElite, :) = [Elite_decs, Xi];
        all_testdata(original + nElite + 1 : original + 2 * nElite, :) = [Xi, Elite_decs];
    end
    
    TestIn_nor = mapminmax('apply', all_testdata', Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';
    
    raw_scores = zeros(Next_num, 1);
    for i = 1 : size(Next, 1)
        C_SCORE = zeros(1, 2);
        original = (i - 1) * 2 * nElite;
        
        pre_EliteXi = sum(pre_out(original + 1 : original + nElite, :), 1) ./ nElite;
        C_SCORE(1) = C_SCORE(1) + pre_EliteXi(2) + pre_EliteXi(3);
        C_SCORE(2) = C_SCORE(2) + pre_EliteXi(1);
        
        pre_XiElite = sum(pre_out(original + nElite + 1 : original + 2 * nElite, :), 1) ./ nElite;
        C_SCORE(1) = C_SCORE(1) + pre_XiElite(2) + pre_XiElite(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiElite(3);
        
        raw_scores(i) = C_SCORE(1) - C_SCORE(2);
    end
    
    minScore = min(raw_scores);
    maxScore = max(raw_scores);
    if maxScore - minScore > 1e-10
        S_model = (raw_scores - minScore) / (maxScore - minScore);
    else
        S_model = ones(Next_num, 1) * 0.5;
    end
    
    W_pos = zeros(Next_num, 1);
    for i = 1 : Next_num
        x = Next(i, :);
        diff = x - mu;
        D_M2 = diff * K_mat_inv * diff';
        W_pos(i) = exp(-D_M2 / 2);
    end
    
    S_final = S_model .* W_pos;
    
    [~, ind] = sort(S_final, 'descend');
end
