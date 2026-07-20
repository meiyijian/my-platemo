function tests = test_REMO_new2_AdaMaO_CPR_MicroAblations
% Tests for the two lightweight F11 comparison variants.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile     = mfilename('fullpath');
    testsDir     = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot  = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    rehash;
    testCase.TestData.AlgorithmDir = algorithmDir;
end

function testHardVoteUsesTheSameReciprocalPreferences(testCase)
    model = deterministicRelationModel(2);
    Candidates = [0.10 0.25; 0.50 0.45; 0.90 0.65];
    Anchors    = [0.10 0.25; 0.35 0.75; 0.80 0.20; 0.95 0.90];

    [expectedOrder,expectedScore,expectedUncertainty] = ...
        ScoreSDEFactorialCandidates( ...
            model,Candidates,Anchors,'expected');
    [hardOrder,hardScore,hardUncertainty] = ...
        ScoreSDEFactorialCandidates( ...
            model,Candidates,Anchors,'hard_vote');

    manualExpected = zeros(size(Candidates,1),1);
    manualHard = zeros(size(Candidates,1),1);
    manualUncertainty = zeros(size(Candidates,1),1);
    sawExactTie = false;
    for i = 1:size(Candidates,1)
        query = repmat(Candidates(i,:),size(Anchors,1),1);
        [p,ambiguity] = PredictSDEFactorialPreference( ...
            model,query,Anchors);
        votes = 0.5.*ones(size(p));
        votes(p > 0.5) = 1;
        votes(p < 0.5) = 0;
        manualExpected(i) = mean(p);
        manualHard(i) = mean(votes);
        manualUncertainty(i) = mean(ambiguity);
        sawExactTie = sawExactTie || any(p == 0.5);
    end
    [~,manualExpectedOrder] = sort(manualExpected,'descend');
    [~,manualHardOrder] = sort(manualHard,'descend');

    verifyTrue(testCase,sawExactTie, ...
        'The fixture must exercise the p == 0.5 half-vote rule.');
    verifyEqual(testCase,expectedScore,manualExpected,'AbsTol',1e-12);
    verifyEqual(testCase,hardScore,manualHard,'AbsTol',1e-12);
    verifyEqual(testCase,expectedUncertainty,manualUncertainty, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,hardUncertainty,manualUncertainty, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,expectedOrder,manualExpectedOrder);
    verifyEqual(testCase,hardOrder,manualHardOrder);
end

function testRegressionTrainingMatchesPairCapacityAndHasNoLeakage(testCase)
    [Input,score] = regressionFixture(10,3);

    rng(24680,'twister');
    stateBefore = rng;
    [~,~,relationMeta] = TrainSDEFactorialRelation( ...
        Input,score,1,17,5);
    stateAfterRelation = rng;
    [model,p_err,meta] = TrainSDEFactorialRegression( ...
        Input,score,17,5);
    stateAfterRegression = rng;

    verifyEqual(testCase,stateAfterRelation,stateBefore);
    verifyEqual(testCase,stateAfterRegression,stateBefore);
    verifyEqual(testCase,model.kind,'regression');
    verifyEqual(testCase,meta.hiddenSizes,[9 7 5]);
    verifyEqual(testCase,networkLayerSizes(model.net),[9 7 5 1]);
    verifyEqual(testCase,meta.parameterCount,relationMeta.parameterCount);
    verifyEmpty(testCase,model.net.inputs{1}.processFcns);
    verifyEmpty(testCase,model.net.outputs{end}.processFcns);
    verifyTrue(testCase,isfield(model,'mp_struct'));

    verifyNotEmpty(testCase,meta.valIdx);
    verifyEmpty(testCase,intersect(meta.trainIdx,meta.valIdx));
    verifyEqual(testCase,meta.trainInput,Input(meta.trainIdx,:), ...
        'AbsTol',0);
    verifyEqual(testCase,meta.trainTargets,score(meta.trainIdx), ...
        'AbsTol',0);
    verifyEqual(testCase,meta.fullIdx,(1:size(Input,1))');
    verifyEqual(testCase,meta.fullInput,Input,'AbsTol',0);
    verifyEqual(testCase,meta.fullTargets,score,'AbsTol',0);
    verifySize(testCase,meta.validationPredictions, ...
        [numel(meta.valIdx) 1]);
    verifyEqual(testCase,meta.validationTruth,score(meta.valIdx), ...
        'AbsTol',0);
    verifyGreaterThanOrEqual(testCase,p_err,0);
    verifyLessThanOrEqual(testCase,p_err,1);
end

function testRegressionTrainingRestoresRngWhenItRejectsInput(testCase)
    [Input,score] = regressionFixture(8,3);
    score(3) = NaN;
    rng(13579,'twister');
    stateBefore = rng;
    caught = [];

    try
        TrainSDEFactorialRegression(Input,score,4,2);
    catch err
        caught = err;
    end

    verifyNotEmpty(testCase,caught);
    verifyEqual(testCase,caught.identifier,'AdaMaO:InvalidRegressionScore');
    verifyEqual(testCase,rng,stateBefore);
end

function testRegressionTrainingAcceptsExtremeFiniteIds(testCase)
    [Input,score] = regressionFixture(6,2);
    rng(24601,'twister');
    stateBefore = rng;

    [model,pError] = TrainSDEFactorialRegression( ...
        Input,score,realmax,realmax);

    verifyEqual(testCase,rng,stateBefore);
    verifyTrue(testCase,isfinite(pError));
    verifyEqual(testCase,model.kind,'regression');
end

function testRegressionPredictionUsesEndpointScoresAndIsReciprocal(testCase)
    [Input,score] = regressionFixture(9,3);
    [model,~,~] = TrainSDEFactorialRegression(Input,score,23,7);
    left  = Input(1:3,:);
    right = Input(4:6,:);

    [pForward,ambiguityForward] = ...
        PredictSDEFactorialPreference(model,left,right);
    [pReverse,ambiguityReverse] = ...
        PredictSDEFactorialPreference(model,right,left);
    [pSelf,ambiguitySelf] = ...
        PredictSDEFactorialPreference(model,left,left);
    rLeft  = predictRegressionScore(model,left);
    rRight = predictRegressionScore(model,right);
    expected = (1+rLeft-rRight)./2;

    verifyEqual(testCase,pForward,expected,'AbsTol',1e-12);
    verifyEqual(testCase,pForward+pReverse,ones(size(pForward)), ...
        'AbsTol',1e-12);
    verifyEqual(testCase,pSelf,0.5.*ones(size(pSelf)), ...
        'AbsTol',1e-12);
    verifyEqual(testCase,ambiguityForward, ...
        1-abs(2*pForward-1),'AbsTol',1e-12);
    verifyEqual(testCase,ambiguityReverse,ambiguityForward, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,ambiguitySelf,ones(size(ambiguitySelf)), ...
        'AbsTol',1e-12);
end

function testRegressionCandidateScoreUsesAllAnchors(testCase)
    [Input,score] = regressionFixture(9,3);
    [model,~,~] = TrainSDEFactorialRegression(Input,score,29,3);
    Candidates = Input(1:3,:)+0.01;
    Anchors = Input(4:9,:);

    [ind,scores,uncertainty] = ScoreSDEFactorialCandidates( ...
        model,Candidates,Anchors,'expected');
    expectedScores = zeros(size(Candidates,1),1);
    expectedUncertainty = zeros(size(Candidates,1),1);
    for i = 1:size(Candidates,1)
        query = repmat(Candidates(i,:),size(Anchors,1),1);
        [p,ambiguity] = PredictSDEFactorialPreference( ...
            model,query,Anchors);
        expectedScores(i) = mean(p);
        expectedUncertainty(i) = mean(ambiguity);
    end
    [~,expectedOrder] = sort(expectedScores,'descend');

    verifyEqual(testCase,scores,expectedScores,'AbsTol',1e-12);
    verifyEqual(testCase,uncertainty,expectedUncertainty, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,ind,expectedOrder);
end

function testMicroAblationEntriesAreDiscoverableAndMapped(testCase)
    names = { ...
        'REMO_new2_AdaMaO_CPR_F11_HardVote'; ...
        'REMO_new2_AdaMaO_CPR_F11_Regression'};

    for i = 1:numel(names)
        expectedFile = fullfile(testCase.TestData.AlgorithmDir, ...
            [names{i},'.m']);
        verifyEqual(testCase,which(names{i}),expectedFile);
        Algorithm = feval(names{i},'save',0,'outputFcn', ...
            @silentOutput,'run',31+i);
        verifyEqual(testCase,Algorithm.describeFactorialVariant(),[1 1]);
    end
end

function testMicroAblationsCompleteOnePostInitializationUpdate(testCase)
    names = { ...
        'REMO_new2_AdaMaO_CPR_F11_HardVote'; ...
        'REMO_new2_AdaMaO_CPR_F11_Regression'};

    for i = 1:numel(names)
        [Algorithm,Problem,initialFE] = makeSmokeRun(names{i},51+i);
        rng(9100+i,'twister');
        Algorithm.Solve(Problem);

        verifyGreaterThan(testCase,Problem.FE,initialFE);
        verifyEqual(testCase,Algorithm.metric.cprBits,[1 1]);
        verifyGreaterThanOrEqual(testCase, ...
            Algorithm.metric.cprTrace.sourceCalls,1);
        verifyGreaterThanOrEqual(testCase, ...
            Algorithm.metric.cprTrace.relationCalls,1);
        verifyNotEmpty(testCase,Algorithm.result);
    end
end

function model = deterministicRelationModel(D)
    fitInput = [zeros(2*D,1),ones(2*D,1)];
    [~,model.mp_struct] = mapminmax(fitInput);
    model.net = @(X) deterministicRelationOutput(X,D);
end

function output = deterministicRelationOutput(X,D)
    preference = 1./(1+exp(-(X(1,:)-X(D+1,:))));
    output = [preference;1-preference];
end

function [Input,score] = regressionFixture(N,D)
    rows = (1:N)';
    Input = zeros(N,D);
    for j = 1:D
        Input(:,j) = mod(rows*(j+2),N+3)/(N+3) + 0.01*j*rows;
    end
    score = linspace(0.08,0.92,N)';
end

function values = predictRegressionScore(model,Input)
    normalizedInput = mapminmax('apply',Input',model.mp_struct);
    values = model.net(normalizedInput)';
    values = min(1,max(0,values(:)));
end

function sizes = networkLayerSizes(net)
    sizes = cellfun(@(layer) layer.size,net.layers);
    sizes = sizes(:)';
end

function [Algorithm,Problem,initialFE] = makeSmokeRun(name,runId)
    D = 3;
    initialFE = 11*D-1;
    parameters = {[],1,[],[],[],[],[],[]};
    Algorithm = feval(name,'parameter',parameters,'save',0, ...
        'outputFcn',@silentOutput,'run',runId);
    Problem = DTLZ2('N',20,'M',3,'D',D,'maxFE',initialFE+4);
end

function silentOutput(varargin)
end
