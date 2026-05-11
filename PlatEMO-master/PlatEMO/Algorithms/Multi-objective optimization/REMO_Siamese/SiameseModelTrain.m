function [net_struct,trainInfo] = SiameseModelTrain(TrainIn1,TrainIn2,TrainOut,xDim)
% Train Siamese-inspired network for relation learning
% Uses improved MLP with ReLU, Dropout, and BatchNorm
%
% TrainIn1  - First branch training inputs (N x D)
% TrainIn2  - Second branch training inputs (N x D)
% TrainOut  - Training labels (0=similar, 1=C1优于C2, -1=C2优于C1)
% xDim      - Input dimension (number of decision variables)
% net_struct - Trained network structure
% trainInfo  - Training information

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. All rights reserved.
%--------------------------------------------------------------------------

    % Convert labels to one-hot encoding
    TrainOut_onehot = onehotconv(TrainOut,1);

    % Normalize inputs separately for each branch
    [TrainIn1_nor, norm_struct1] = mapminmax(TrainIn1');
    TrainIn1_nor = TrainIn1_nor';
    [TrainIn2_nor, norm_struct2] = mapminmax(TrainIn2');
    TrainIn2_nor = TrainIn2_nor';

    % Combine inputs for Siamese-style processing
    % The network learns to compare two solutions by processing them together
    TrainIn_combined = [TrainIn1_nor, TrainIn2_nor];
    combinedDim = size(TrainIn_combined, 2);

    % Define improved network architecture
    % Using ReLU, BatchNorm, and Dropout for better training
    layers = [
        featureInputLayer(combinedDim, 'Normalization', 'none')

        % First hidden block
        fullyConnectedLayer(ceil(combinedDim*1.5))
        batchNormalizationLayer
        reluLayer
        dropoutLayer(0.3)

        % Second hidden block
        fullyConnectedLayer(combinedDim)
        batchNormalizationLayer
        reluLayer
        dropoutLayer(0.2)

        % Third hidden block
        fullyConnectedLayer(ceil(combinedDim/2))
        reluLayer
        dropoutLayer(0.1)

        % Output layer
        fullyConnectedLayer(3)
        softmaxLayer
        classificationLayer
    ];

    % Training options
    miniBatchSize = min(32, floor(size(TrainOut,1)/2));
    if miniBatchSize < 1
        miniBatchSize = 1;
    end

    options = trainingOptions('adam', ...
        'MaxEpochs', 80, ...
        'MiniBatchSize', miniBatchSize, ...
        'InitialLearnRate', 0.001, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropPeriod', 25, ...
        'LearnRateDropFactor', 0.5, ...
        'L2Regularization', 0.0001, ...
        'Shuffle', 'every-epoch', ...
        'ValidationFrequency', 10, ...
        'ValidationPatience', 10, ...
        'Verbose', false, ...
        'Plots', 'none');

    % Convert labels to categorical
    TrainOut_cat = categorical(TrainOut, [-1 0 1], {'negative', 'zero', 'positive'});

    % Train network
    try
        trainedNet = trainNetwork(TrainIn_combined, TrainOut_cat, layers, options);
    catch ME
        % Fallback to simpler network if training fails
        warning('Training failed with error: %s. Using fallback network.', ME.message);
        layers_simple = [
            featureInputLayer(combinedDim, 'Normalization', 'none')
            fullyConnectedLayer(ceil(combinedDim*1.2))
            reluLayer
            fullyConnectedLayer(ceil(combinedDim*0.6))
            reluLayer
            fullyConnectedLayer(3)
            softmaxLayer
            classificationLayer
        ];
        options_simple = trainingOptions('adam', ...
            'MaxEpochs', 100, ...
            'MiniBatchSize', miniBatchSize, ...
            'InitialLearnRate', 0.005, ...
            'Verbose', false, ...
            'Plots', 'none');
        trainedNet = trainNetwork(TrainIn_combined, TrainOut_cat, layers_simple, options_simple);
    end

    % Store normalization parameters and network
    net_struct.net = trainedNet;
    net_struct.norm_struct1 = norm_struct1;
    net_struct.norm_struct2 = norm_struct2;
    net_struct.xDim = xDim;

    % Training info
    trainInfo.norm_struct1 = norm_struct1;
    trainInfo.norm_struct2 = norm_struct2;
end
