function [model,p_err,meta] = TrainSDEFactorialRelation( ...
    Input,score,relationBit,runId,generation)
%TrainSDEFactorialRelation Train one hard or soft reciprocal relation model.
%   Validation solutions are held out before relation pairs are formed.  A
%   validation-only model is trained on pairs of training solutions, after
%   which a fresh production model is trained on every ordered base pair.

    savedRng = rng;
    cleanupRng = onCleanup(@() restoreRng(savedRng));
    validateRelationInputs(Input,score,relationBit);
    score = score(:);

    [trainIdx,valIdx] = SplitSDEFactorialSolutions( ...
        Input,runId,generation);
    [trainPairInput,trainTargets,trainPairIndex] = ...
        BuildSDEFactorialRelationData( ...
        Input,score,relationBit,trainIdx);
    if isempty(trainPairInput)
        error('AdaMaO:InsufficientRelationData', ...
            'At least two distinct training solutions are required.');
    end

    xDim = size(trainPairInput,2);
    hiddenSizes = [ceil(xDim*1.5),xDim,ceil(xDim/2)];
    validationSeed = relationSeed(runId,generation,1);
    validationModel = fitRelationModel( ...
        trainPairInput,trainTargets,hiddenSizes,validationSeed);

    validationPairIndex = crossPairIndex(valIdx,trainIdx);
    validationTargets = relationTargets( ...
        score,validationPairIndex,relationBit);
    validationTruth = validationTargets(:,1);
    if isempty(validationPairIndex)
        validationPredictions = zeros(0,1);
        p_err = 1;
        validationBrier = NaN;
        validationNLL = NaN;
    else
        validationPredictions = PredictSDEFactorialPreference( ...
            validationModel,Input(validationPairIndex(:,1),:), ...
            Input(validationPairIndex(:,2),:));
        p_err = strictRankingError(validationPredictions,validationTruth);
        validationBrier = mean((validationPredictions-validationTruth).^2);
        boundedPrediction = min(1-eps,max(eps,validationPredictions));
        validationNLL = -mean(validationTruth.*log(boundedPrediction) + ...
            (1-validationTruth).*log(1-boundedPrediction));
    end

    [fullPairInput,fullTargets,fullPairIndex] = ...
        BuildSDEFactorialRelationData(Input,score,relationBit);
    fullSeed = relationSeed(runId,generation,2);
    model = fitRelationModel( ...
        fullPairInput,fullTargets,hiddenSizes,fullSeed);

    meta.relationBit          = relationBit;
    meta.trainIdx             = trainIdx;
    meta.valIdx               = valIdx;
    meta.trainPairIndex       = trainPairIndex;
    meta.validationPairIndex  = validationPairIndex;
    meta.fullPairIndex        = fullPairIndex;
    meta.trainPairInput       = trainPairInput;
    meta.fullPairInput        = fullPairInput;
    meta.trainTargets         = trainTargets;
    meta.fullTargets          = fullTargets;
    meta.hiddenSizes          = hiddenSizes;
    meta.parameterCount       = networkParameterCount(xDim,hiddenSizes,2);
    meta.validationPredictions = validationPredictions;
    meta.validationTruth       = validationTruth;
    meta.validationBrier       = validationBrier;
    meta.validationNLL         = validationNLL;
end

function errorRate = strictRankingError(prediction,truth)
    strict = truth ~= 0.5;
    if ~any(strict)
        errorRate = 1;
        return;
    end
    prediction = prediction(strict);
    truth = truth(strict);
    loss = double((prediction > 0.5) ~= (truth > 0.5));
    loss(prediction == 0.5) = 0.5;
    errorRate = mean(loss);
end

function count = networkParameterCount(inputSize,hiddenSizes,outputSize)
    layerSizes = [hiddenSizes(:)',outputSize];
    previousSizes = [inputSize,hiddenSizes(:)'];
    count = sum(layerSizes.*(previousSizes+1));
end

function validateRelationInputs(Input,score,relationBit)
    if ~isnumeric(Input) || ~isreal(Input) || ~ismatrix(Input) || ...
            isempty(Input) || ...
            size(Input,2) == 0 || any(~isfinite(Input(:)))
        error('AdaMaO:InvalidRelationInput', ...
            'Input must be a nonempty finite numeric matrix.');
    end
    if ~isnumeric(score) || ~isreal(score) || ~isvector(score) || ...
            numel(score) ~= size(Input,1) || any(~isfinite(score(:))) || ...
            any(score(:) < 0) || any(score(:) > 1)
        error('AdaMaO:InvalidRelationScore', ...
            'score must contain one finite value in [0,1] per solution.');
    end
    if ~isscalar(relationBit) || ~isnumeric(relationBit) || ...
            ~isreal(relationBit) || ...
            ~isfinite(relationBit) || ~ismember(relationBit,[0 1])
        error('AdaMaO:InvalidRelationBit', ...
            'relationBit must be either zero or one.');
    end
    if size(Input,1) < 2
        error('AdaMaO:InsufficientRelationData', ...
            'At least two base solutions are required.');
    end
end

function model = fitRelationModel(PairInput,Targets,hiddenSizes,seed)
    [normalizedInput,mpStruct] = mapminmax(PairInput');
    rng(seed,'twister');
    net = patternnet(hiddenSizes);
    net.performFcn = 'crossentropy';
    net.divideFcn = 'dividetrain';
    net.inputs{1}.processFcns = {};
    net.outputs{end}.processFcns = {};
    net.trainParam.showWindow = 0;
    net.trainParam.showCommandLine = 0;
    net = train(net,normalizedInput,Targets');

    model.net = net;
    model.mp_struct = mpStruct;
    model.kind = 'pairwise';
end

function PairIndex = crossPairIndex(queryIdx,anchorIdx)
    if isempty(queryIdx) || isempty(anchorIdx)
        PairIndex = zeros(0,2);
        return;
    end
    [queryGrid,anchorGrid] = ndgrid(queryIdx(:),anchorIdx(:));
    PairIndex = [queryGrid(:),anchorGrid(:)];
end

function Targets = relationTargets(score,PairIndex,relationBit)
    if isempty(PairIndex)
        Targets = zeros(0,2);
        return;
    end
    difference = score(PairIndex(:,1))-score(PairIndex(:,2));
    if relationBit == 0
        preference = 0.5.*ones(size(difference));
        preference(difference > 0) = 1;
        preference(difference < 0) = 0;
    else
        preference = (1+score(PairIndex(:,1))- ...
            score(PairIndex(:,2)))./2;
    end
    Targets = [preference,1-preference];
end

function seed = relationSeed(runId,generation,phase)
    seed = MakeSDEFactorialSeed( ...
        runId,generation,phase,'relation');
end

function restoreRng(state)
    rng(state);
end
