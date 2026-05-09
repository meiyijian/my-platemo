function Next = SiameseAssistedSelection(Problem,Ref,Input,wmax,Smodel)
% Surrogate-assisted selection using Siamese-inspired network
% Uses trained network to guide genetic algorithm for new solution generation
% Incorporates information entropy for uncertainty estimation
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
% Incorporates information entropy for uncertainty estimation
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

    scores = zeros(Next_num,1);
    selectscores = zeros(Next_num,1);

    % For each candidate solution, compare with known good and bad solutions
    for i = 1:Next_num
        Xi = Next(i,:);

        % Create pairs with C1 solutions
        Xi_rep_C1 = repmat(Xi, C1_num, 1);
        [C1_Xi_pred, C1_Xi_prob] = SiameseModelPredict(Smodel.net, C1_data, Xi_rep_C1);
        [Xi_C1_pred, Xi_C1_prob] = SiameseModelPredict(Smodel.net, Xi_rep_C1, C1_data);

        % Create pairs with C2 solutions
        Xi_rep_C2 = repmat(Xi, C2_num, 1);
        [C2_Xi_pred, C2_Xi_prob] = SiameseModelPredict(Smodel.net, C2_data, Xi_rep_C2);
        [Xi_C2_pred, Xi_C2_prob] = SiameseModelPredict(Smodel.net, Xi_rep_C2, C2_data);

        % Initialize scores
        C_SCORE = zeros(1,2);  % [performance, uncertainty]

        %% Calculate performance score
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

        %% Calculate uncertainty score using information entropy
        % Entropy H(X) = -sum(P(x) * log2(P(x)))
        % Higher entropy means higher uncertainty

        % Average probability distributions for each comparison type
        avg_prob_C1Xi = mean(C1_Xi_prob, 1);
        avg_prob_XiC1 = mean(Xi_C1_prob, 1);
        avg_prob_C2Xi = mean(C2_Xi_prob, 1);
        avg_prob_XiC2 = mean(Xi_C2_prob, 1);

        % Calculate entropy for each comparison type
        % Add small epsilon to avoid log(0)
        epsilon = 1e-10;

        entropy_C1Xi = -sum(avg_prob_C1Xi .* log2(avg_prob_C1Xi + epsilon));
        entropy_XiC1 = -sum(avg_prob_XiC1 .* log2(avg_prob_XiC1 + epsilon));
        entropy_C2Xi = -sum(avg_prob_C2Xi .* log2(avg_prob_C2Xi + epsilon));
        entropy_XiC2 = -sum(avg_prob_XiC2 .* log2(avg_prob_XiC2 + epsilon));

        % Total uncertainty (average entropy)
        C_SCORE(2) = (entropy_C1Xi + entropy_XiC1 + entropy_C2Xi + entropy_XiC2) / 4;

        %% Calculate final scores
        % Pure performance score
        scores(i) = C_SCORE(1);

        % Combined score: performance - uncertainty
        % Prioritize solutions with high performance and low uncertainty
        selectscores(i) = alpha * C_SCORE(1) - beta * C_SCORE(2);
    end

    % Sort by combined score descending
    [~,ind] = sort(selectscores,'descend');
end
