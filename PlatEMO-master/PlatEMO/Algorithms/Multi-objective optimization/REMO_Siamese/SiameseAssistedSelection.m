function Next = SiameseAssistedSelection(Problem,Ref,Input,wmax,Smodel)
% Surrogate-assisted selection using Siamese-inspired network
% Uses trained network to guide genetic algorithm for new solution generation
% Incorporates information entropy for uncertainty estimation
% Optimized: batch prediction instead of per-sample prediction
%
% Problem  - Optimization problem definition
% Ref      - Reference solutions
% Input    - Current population decision variables
% wmax     - Maximum number of candidate solutions
% Smodel   - Trained surrogate model
% Next     - Selected promising solutions for real evaluation

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. All rights reserved.
%--------------------------------------------------------------------------

    % Generate initial offspring using genetic operators
    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;

    % alpha and beta weights for performance and uncertainty scores
    alpha = 1;  % Performance score weight
    beta = 1;   % Uncertainty score weight

    % Generate and evaluate candidates using surrogate model
    while i < wmax
        [sorted_index, ~, ~] = model_select_siamese(Smodel,Next,alpha,beta);
        Input = Next(sorted_index(1:length(Ref)),:);
        Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i     = i + size(Next,1);
    end

    % Final selection based on scores
    [~, selectscores, scores] = model_select_siamese(Smodel,Next,alpha,beta);
    if sum(scores>3.9) < 4
        [~,ind] = sort(selectscores,'descend');
        Next    = Next(ind(1:4),:);
    else
        Next = Next(scores>3.9,:);
    end
end

function [ind, selectscores, scores] = model_select_siamese(Smodel,Next,alpha,beta)
% Score candidate solutions using Siamese-inspired network with uncertainty
% Optimized: batch prediction for all pairs at once
%
% Smodel        - Trained model
% Next          - Candidate solutions to evaluate
% alpha         - Performance score weight
% beta          - Uncertainty score weight
% ind           - Sorted indices (descending by score)
% selectscores  - Combined scores (performance - uncertainty)
% scores        - Pure performance scores

    model_x = Smodel.X;
    C1_data = model_x(Smodel.Y == 1,:);
    C2_data = model_x(Smodel.Y ~= 1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    D = size(C1_data,2);

    scores = zeros(Next_num,1);
    selectscores = zeros(Next_num,1);

    % Build all pairs at once for batch prediction
    % 4 types: C1_Xi, Xi_C1, C2_Xi, Xi_C2
    nPair_per_solution = 2 * (C1_num + C2_num);
    all_testdata = zeros(nPair_per_solution * Next_num, 2 * D);

    for i = 1:Next_num
        base = (i - 1) * nPair_per_solution;
        Xi = Next(i,:);

        % C1_Xi: C1 in front, Xi behind
        Xi_rep_C1 = repmat(Xi, C1_num, 1);
        all_testdata(base + 1 : base + C1_num, :) = [C1_data, Xi_rep_C1];

        % Xi_C1: Xi in front, C1 behind
        all_testdata(base + C1_num + 1 : base + 2*C1_num, :) = [Xi_rep_C1, C1_data];

        % C2_Xi: C2 in front, Xi behind
        Xi_rep_C2 = repmat(Xi, C2_num, 1);
        all_testdata(base + 2*C1_num + 1 : base + 2*C1_num + C2_num, :) = [C2_data, Xi_rep_C2];

        % Xi_C2: Xi in front, C2 behind
        all_testdata(base + 2*C1_num + C2_num + 1 : base + 2*C1_num + 2*C2_num, :) = [Xi_rep_C2, C2_data];
    end

    % Batch predict (single call, normalization handled inside SiameseModelPredict)
    [all_pred, all_prob] = SiameseModelPredict(Smodel.net_struct, all_testdata(:,1:D), all_testdata(:,D+1:end));

    % Extract results for each candidate and calculate scores
    for i = 1:Next_num
        base = (i - 1) * nPair_per_solution;

        % Extract predictions for each pair type
        C1_Xi_pred = all_pred(base + 1 : base + C1_num);
        C1_Xi_prob = all_prob(base + 1 : base + C1_num, :);

        Xi_C1_pred = all_pred(base + C1_num + 1 : base + 2*C1_num);
        Xi_C1_prob = all_prob(base + C1_num + 1 : base + 2*C1_num, :);

        C2_Xi_pred = all_pred(base + 2*C1_num + 1 : base + 2*C1_num + C2_num);
        C2_Xi_prob = all_prob(base + 2*C1_num + 1 : base + 2*C1_num + C2_num, :);

        Xi_C2_pred = all_pred(base + 2*C1_num + C2_num + 1 : base + 2*C1_num + 2*C2_num);
        Xi_C2_prob = all_prob(base + 2*C1_num + C2_num + 1 : base + 2*C1_num + 2*C2_num, :);

        % Calculate performance score
        % C1_Xi: if pred=0 (similar) or pred=1 (C1优于Xi), Xi is good
        score_C1Xi = sum(C1_Xi_pred == 0) + sum(C1_Xi_pred == 1);
        % Xi_C1: if pred=0 (similar) or pred=-1 (Xi优于C1), Xi is good
        score_XiC1 = sum(Xi_C1_pred == 0) + sum(Xi_C1_pred == -1);
        % C2_Xi: if pred=0 (similar) or pred=-1 (C2优于Xi), Xi is good
        score_C2Xi = sum(C2_Xi_pred == 0) + sum(C2_Xi_pred == -1);
        % Xi_C2: if pred=0 (similar) or pred=1 (Xi优于C2), Xi is good
        score_XiC2 = sum(Xi_C2_pred == 0) + sum(Xi_C2_pred == 1);

        % Total performance score
        C_SCORE(1) = score_C1Xi + score_XiC1 + score_C2Xi + score_XiC2;

        % Calculate uncertainty score using information entropy
        epsilon = 1e-10;
        avg_prob_C1Xi = mean(C1_Xi_prob, 1);
        avg_prob_XiC1 = mean(Xi_C1_prob, 1);
        avg_prob_C2Xi = mean(C2_Xi_prob, 1);
        avg_prob_XiC2 = mean(Xi_C2_prob, 1);

        entropy_C1Xi = -sum(avg_prob_C1Xi .* log2(avg_prob_C1Xi + epsilon));
        entropy_XiC1 = -sum(avg_prob_XiC1 .* log2(avg_prob_XiC1 + epsilon));
        entropy_C2Xi = -sum(avg_prob_C2Xi .* log2(avg_prob_C2Xi + epsilon));
        entropy_XiC2 = -sum(avg_prob_XiC2 .* log2(avg_prob_XiC2 + epsilon));

        C_SCORE(2) = (entropy_C1Xi + entropy_XiC1 + entropy_C2Xi + entropy_XiC2) / 4;

        % Final scores
        scores(i) = C_SCORE(1);
        selectscores(i) = alpha * C_SCORE(1) - beta * C_SCORE(2);
    end

    % Sort by combined score descending
    [~,ind] = sort(selectscores,'descend');
end
