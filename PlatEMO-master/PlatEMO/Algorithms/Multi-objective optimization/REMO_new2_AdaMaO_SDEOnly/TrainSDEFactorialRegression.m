function [model,p_err,meta] = TrainSDEFactorialRegression( ...
    Input,score,runId,generation)
%TrainSDEFactorialRegression Train the same-capacity scalar comparator.
%   This micro-ablation learns the continuous quality score directly. Its
%   predictions are converted back to reciprocal endpoint preferences so
%   the candidate-selection interface remains identical to F11.

    savedRng = rng;
    cleanupRng = onCleanup(@() rng(savedRng));
    validateRegressionInputs(Input,score);
    score = score(:);

    [trainIdx,valIdx] = SplitSDEFactorialSolutions( ...
        Input,runId,generation);
    decisionDimension = size(Input,2);
    hiddenSizes = matchedCapacityHiddenSizes(decisionDimension);

    validationModel = fitRegressionModel( ...
        Input(trainIdx,:),score(trainIdx),hiddenSizes, ...
        regressionSeed(runId,generation,1));
    validationPredictions = predictScore(validationModel,Input(valIdx,:));
    validationTruth = score(valIdx);
    if isempty(valIdx)
        p_err = 1;
    else
        anchorPrediction = predictScore(validationModel,Input(trainIdx,:));
        [queryGrid,anchorGrid] = ndgrid( ...
            (1:numel(valIdx))',(1:numel(trainIdx))');
        predictedDifference = validationPredictions(queryGrid(:)) - ...
            anchorPrediction(anchorGrid(:));
        trueDifference = score(valIdx(queryGrid(:))) - ...
            score(trainIdx(anchorGrid(:)));
        p_err = strictDifferenceError(predictedDifference,trueDifference);
    end

    fullIdx = (1:size(Input,1))';
    model = fitRegressionModel(Input,score,hiddenSizes, ...
        regressionSeed(runId,generation,2));

    meta.trainIdx = trainIdx;
    meta.valIdx = valIdx;
    meta.fullIdx = fullIdx;
    meta.trainInput = Input(trainIdx,:);
    meta.trainTargets = score(trainIdx);
    meta.fullInput = Input;
    meta.fullTargets = score;
    meta.hiddenSizes = hiddenSizes;
    meta.parameterCount = networkParameterCount( ...
        decisionDimension,hiddenSizes,1);
    meta.validationPredictions = validationPredictions;
    meta.validationTruth = validationTruth;
end

function hiddenSizes = matchedCapacityHiddenSizes(D)
% Match the exact parameter count of [3D,2D,D], 2D-input, 2-output CPR.
    hiddenSizes = [4*D-3,2*D+1,D+2];
end

function errorRate = strictDifferenceError(predictedDifference,trueDifference)
    strict = trueDifference ~= 0;
    if ~any(strict)
        errorRate = 1;
        return;
    end
    predictedDifference = predictedDifference(strict);
    trueDifference = trueDifference(strict);
    loss = double((predictedDifference > 0) ~= (trueDifference > 0));
    loss(predictedDifference == 0) = 0.5;
    errorRate = mean(loss);
end

function count = networkParameterCount(inputSize,hiddenSizes,outputSize)
    layerSizes = [hiddenSizes(:)',outputSize];
    previousSizes = [inputSize,hiddenSizes(:)'];
    count = sum(layerSizes.*(previousSizes+1));
end

function validateRegressionInputs(Input,score)
    if ~isnumeric(Input) || ~isreal(Input) || ~ismatrix(Input) || ...
            isempty(Input) || size(Input,2) == 0 || ...
            any(~isfinite(Input(:)))
        error('AdaMaO:InvalidRegressionInput', ...
            'Input must be a nonempty finite real matrix.');
    end
    if ~isnumeric(score) || ~isreal(score) || ~isvector(score) || ...
            numel(score) ~= size(Input,1) || any(~isfinite(score(:))) || ...
            any(score(:) < 0) || any(score(:) > 1)
        error('AdaMaO:InvalidRegressionScore', ...
            'score must contain one finite value in [0,1] per solution.');
    end
    if size(Input,1) < 2
        error('AdaMaO:InsufficientRegressionData', ...
            'At least two base solutions are required.');
    end
end

function model = fitRegressionModel(Input,Targets,hiddenSizes,seed)
    [normalizedInput,mpStruct] = mapminmax(Input');
    rng(seed,'twister');
    net = fitnet(hiddenSizes,'trainscg');
    net.performFcn = 'mse';
    net.divideFcn = 'dividetrain';
    net.inputs{1}.processFcns = {};
    net.outputs{end}.processFcns = {};
    net.trainParam.showWindow = 0;
    net.trainParam.showCommandLine = 0;
    net = train(net,normalizedInput,Targets');

    model.net = net;
    model.mp_struct = mpStruct;
    model.kind = 'regression';
end

function prediction = predictScore(model,Input)
    if isempty(Input)
        prediction = zeros(0,1);
        return;
    end
    normalizedInput = mapminmax('apply',Input',model.mp_struct);
    prediction = model.net(normalizedInput)';
    prediction = min(1,max(0,prediction(:)));
end

function seed = regressionSeed(runId,generation,phase)
    seed = MakeSDEFactorialSeed( ...
        runId,generation,phase,'regression');
end
