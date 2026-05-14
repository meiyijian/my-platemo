<<<<<<< HEAD
function [Predictions, Probabilities] = SiameseModelPredict(net_struct, TestIn1, TestIn2, use_normalized)
% Predict relations using trained Siamese-inspired network
% Returns both predictions and probability distributions for uncertainty estimation
% Optimized: supports pre-normalized input to avoid redundant normalization
%
% net_struct      - Trained network structure containing net and normalization params
% TestIn1         - First branch test inputs (N x D) OR combined input if use_normalized=true
% TestIn2         - Second branch test inputs (N x D) OR empty if use_normalized=true
% use_normalized  - (optional) if true, TestIn1 is already normalized combined input
% Predictions     - Predicted labels (0=similar, 1=C1优于C2, -1=C2优于C1)
% Probabilities   - Probability distribution for each sample
=======
function [Predictions, Probabilities] = SiameseModelPredict(net_struct,TestIn1,TestIn2)
% Predict relations using trained Siamese-inspired network
% Returns both predictions and probability distributions for uncertainty estimation
%
% net_struct    - Trained network structure containing net and normalization params
% TestIn1       - First branch test inputs (N x D)
% TestIn2       - Second branch test inputs (N x D)
% Predictions   - Predicted labels (0=similar, 1=C1优于C2, -1=C2优于C1)
% Probabilities - Probability distribution [P(negative), P(zero), P(positive)] for each sample
>>>>>>> d67d282237e7075aca3ea67bbc42efa2cc9e344c

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. All rights reserved.
%--------------------------------------------------------------------------

<<<<<<< HEAD
    % Extract network
    net = net_struct.net;

    if nargin >= 4 && use_normalized
        % TestIn1 is already normalized combined input [TestIn1_nor, TestIn2_nor]
        TestIn_combined = TestIn1;
    else
        % Normalize test inputs using training normalization parameters
        norm_struct1 = net_struct.norm_struct1;
        norm_struct2 = net_struct.norm_struct2;

        TestIn1_nor = mapminmax('apply', TestIn1', norm_struct1)';
        TestIn2_nor = mapminmax('apply', TestIn2', norm_struct2)';

        % Combine inputs (same format as training)
        TestIn_combined = [TestIn1_nor, TestIn2_nor];
    end

    % Predict using trained network (batch prediction)
    [predictedLabels, scores] = classify(net, TestIn_combined);

    % Convert categorical predictions back to numeric labels
    Predictions = zeros(size(TestIn_combined,1), 1);
=======
    % Extract network and normalization parameters
    net = net_struct.net;
    norm_struct1 = net_struct.norm_struct1;
    norm_struct2 = net_struct.norm_struct2;

    % Normalize test inputs using training normalization parameters
    TestIn1_nor = mapminmax('apply', TestIn1', norm_struct1)';
    TestIn2_nor = mapminmax('apply', TestIn2', norm_struct2)';

    % Combine inputs (same format as training)
    TestIn_combined = [TestIn1_nor, TestIn2_nor];

    % Predict using trained network
    [predictedLabels, scores] = classify(net, TestIn_combined);

    % Convert categorical predictions back to numeric labels
    Predictions = zeros(size(TestIn1,1), 1);
>>>>>>> d67d282237e7075aca3ea67bbc42efa2cc9e344c
    Predictions(predictedLabels == 'positive') = 1;
    Predictions(predictedLabels == 'negative') = -1;
    % 'zero' maps to 0 (already initialized)

    % Return probability distribution for uncertainty estimation
<<<<<<< HEAD
=======
    % scores contains [P(negative), P(zero), P(positive)]
>>>>>>> d67d282237e7075aca3ea67bbc42efa2cc9e344c
    Probabilities = scores;
end
