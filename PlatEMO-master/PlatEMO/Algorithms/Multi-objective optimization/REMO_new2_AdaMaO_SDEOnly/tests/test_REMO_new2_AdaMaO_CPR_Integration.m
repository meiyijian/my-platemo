function tests = test_REMO_new2_AdaMaO_CPR_Integration
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

function testFourFactorialEntriesAreDiscoverableAndMapped(testCase)
    names = { ...
        'REMO_new2_AdaMaO_CPR_F00'; ...
        'REMO_new2_AdaMaO_CPR_F10'; ...
        'REMO_new2_AdaMaO_CPR_F01'; ...
        'REMO_new2_AdaMaO_CPR_F11'};
    expectedBits = [0 0; 1 0; 0 1; 1 1];

    for i = 1:numel(names)
        expectedFile = fullfile(testCase.TestData.AlgorithmDir, ...
            [names{i},'.m']);
        verifyEqual(testCase,which(names{i}),expectedFile);
        Algorithm = feval(names{i},'save',0,'outputFcn', ...
            @silentOutput,'run',19);
        verifyEqual(testCase,Algorithm.describeFactorialVariant(), ...
            expectedBits(i,:));
    end
end

function testLegacySourceMatchesPreTruncationHybridScore(testCase)
    [Population,Vglobal] = makeSourcePopulation(3);
    ratio = 0.37;
    k     = 4;
    theta = 5;

    [score,Ref,detail] = ComputeSDEFactorialScoreSource( ...
        Population,0,Vglobal,ratio,k,theta,7,3);
    expected = legacyHybridScore(Population.objs,Ref.objs,ratio,theta);

    verifyEqual(testCase,score,expected,'AbsTol',1e-12);
    verifySize(testCase,score,[length(Population) 1]);
    verifyEqual(testCase,detail.sourceBit,0);
    verifyTrue(testCase,all(isfinite(score)));
end

function testContinuousSourceUsesBothViewsAndDoesNotAdvanceRng(testCase)
    [Population,Vglobal] = makeSourcePopulation(3);
    k     = 4;
    theta = 5;

    rng(31415,'twister');
    stateBefore = rng;
    [globalScore,globalRef,globalDetail] = ...
        ComputeSDEFactorialScoreSource( ...
        Population,1,Vglobal,0,k,theta,9,2);
    [localScore,localRef,localDetail] = ...
        ComputeSDEFactorialScoreSource( ...
        Population,1,Vglobal,1,k,theta,9,2);
    stateAfter = rng;

    [expectedGlobal,expectedGlobalDetail] = ...
        ComputeSDEFactorialContinuousScore( ...
        Population.objs,globalRef.objs,Vglobal,0,theta);
    [expectedLocal,expectedLocalDetail] = ...
        ComputeSDEFactorialContinuousScore( ...
        Population.objs,localRef.objs,Vglobal,1,theta);

    verifyEqual(testCase,stateAfter,stateBefore);
    verifyEqual(testCase,globalScore,expectedGlobal,'AbsTol',1e-12);
    verifyEqual(testCase,localScore,expectedLocal,'AbsTol',1e-12);
    verifyEqual(testCase,globalScore,expectedGlobalDetail.globalScore, ...
        'AbsTol',0);
    verifyEqual(testCase,localScore,expectedLocalDetail.localScore, ...
        'AbsTol',0);
    verifyEqual(testCase,globalDetail.sourceBit,1);
    verifyEqual(testCase,localDetail.sourceBit,1);
    verifyEqual(testCase,globalRef.decs,localRef.decs,'AbsTol',0);
    verifyGreaterThanOrEqual(testCase,[globalScore;localScore], ...
        zeros(2*length(Population),1));
    verifyLessThanOrEqual(testCase,[globalScore;localScore], ...
        ones(2*length(Population),1));
end

function testLegacyHighDimensionalSourceIsReproducibleAndRngIsolated(testCase)
    N = 60;
    M = 5;
    t = linspace(0.02,0.98,N)';
    PopDec = [t,1-t,mod((1:N)',7)./7];
    PopObj = [t,1-t,0.2+0.7*t.^2, ...
        0.3+0.5*(1-t).^2,0.4+0.1*sin(2*pi*t)];
    Population = SOLUTION(PopDec,PopObj,zeros(N,1));
    Vglobal = UniformPoint(N,M,'ILD');

    rng(8181,'twister');
    stateBefore = rng;
    [scoreA,refA,detailA] = ComputeSDEFactorialScoreSource( ...
        Population,0,Vglobal,0.4,8,5,21,4);
    stateAfter = rng;
    rng(9191,'twister');
    [scoreB,refB,detailB] = ComputeSDEFactorialScoreSource( ...
        Population,0,Vglobal,0.4,8,5,21,4);

    verifyEqual(testCase,stateAfter,stateBefore);
    verifyEqual(testCase,scoreB,scoreA,'AbsTol',0);
    verifyEqual(testCase,refB.decs,refA.decs,'AbsTol',0);
    verifyEqual(testCase,detailB.globalDirections, ...
        detailA.globalDirections,'AbsTol',0);
    verifyTrue(testCase,all(isfinite(scoreA)));
    verifyEqual(testCase,size(detailA.globalDirections,2),M);
end

function testHardSoftTrainingDiffersOnlyInTargetsAndHasNoLeakage(testCase)
    [Input,score] = relationFixture(10,3);

    rng(2718,'twister');
    stateBefore = rng;
    [hardModel,hardError,hardMeta] = TrainSDEFactorialRelation( ...
        Input,score,0,12,4);
    stateAfterHard = rng;
    [softModel,softError,softMeta] = TrainSDEFactorialRelation( ...
        Input,score,1,12,4);
    stateAfterSoft = rng;

    verifyEqual(testCase,stateAfterHard,stateBefore);
    verifyEqual(testCase,stateAfterSoft,stateBefore);
    verifyEqual(testCase,hardMeta.relationBit,0);
    verifyEqual(testCase,softMeta.relationBit,1);
    verifyEqual(testCase,hardMeta.trainIdx,softMeta.trainIdx);
    verifyEqual(testCase,hardMeta.valIdx,softMeta.valIdx);
    verifyEqual(testCase,hardMeta.trainPairIndex, ...
        softMeta.trainPairIndex);
    verifyEqual(testCase,hardMeta.validationPairIndex, ...
        softMeta.validationPairIndex);
    verifyEqual(testCase,hardMeta.fullPairIndex,softMeta.fullPairIndex);
    verifyEqual(testCase,hardMeta.trainPairInput, ...
        softMeta.trainPairInput,'AbsTol',0);
    verifyEqual(testCase,hardMeta.fullPairInput, ...
        softMeta.fullPairInput,'AbsTol',0);
    verifyFalse(testCase,isequal(hardMeta.trainTargets, ...
        softMeta.trainTargets));
    verifyFalse(testCase,isequal(hardMeta.fullTargets, ...
        softMeta.fullTargets));

    verifyNotEmpty(testCase,hardMeta.valIdx);
    verifyFalse(testCase,any(ismember(hardMeta.trainPairIndex(:), ...
        hardMeta.valIdx)));
    verifyTrue(testCase,all(ismember( ...
        hardMeta.validationPairIndex(:,1),hardMeta.valIdx)));
    verifyTrue(testCase,all(ismember( ...
        hardMeta.validationPairIndex(:,2),hardMeta.trainIdx)));
    verifyFalse(testCase,any(hardMeta.validationPairIndex(:,1) == ...
        hardMeta.validationPairIndex(:,2)));

    expectedFullPairs = allDirectedPairs(size(Input,1));
    verifyEqual(testCase,sortrows(hardMeta.fullPairIndex), ...
        sortrows(expectedFullPairs));
    verifyEqual(testCase,size(hardMeta.fullPairIndex,1), ...
        size(Input,1)*(size(Input,1)-1));
    verifyEqual(testCase,hardMeta.fullPairInput, ...
        [Input(hardMeta.fullPairIndex(:,1),:) ...
         Input(hardMeta.fullPairIndex(:,2),:)],'AbsTol',0);

    [expectedHardInput,expectedHardTargets,expectedHardIndex] = ...
        BuildSDEFactorialRelationData(Input,score,0);
    [expectedSoftInput,expectedSoftTargets,expectedSoftIndex] = ...
        BuildSDEFactorialRelationData(Input,score,1);
    verifyEqual(testCase,hardMeta.fullPairIndex,expectedHardIndex);
    verifyEqual(testCase,softMeta.fullPairIndex,expectedSoftIndex);
    verifyEqual(testCase,hardMeta.fullPairInput,expectedHardInput, ...
        'AbsTol',0);
    verifyEqual(testCase,softMeta.fullPairInput,expectedSoftInput, ...
        'AbsTol',0);
    verifyEqual(testCase,hardMeta.fullTargets,expectedHardTargets, ...
        'AbsTol',0);
    verifyEqual(testCase,softMeta.fullTargets,expectedSoftTargets, ...
        'AbsTol',0);

    expectedHidden = [9 6 3];
    verifyEqual(testCase,hardMeta.hiddenSizes,expectedHidden);
    verifyEqual(testCase,softMeta.hiddenSizes,expectedHidden);
    verifyEqual(testCase,networkLayerSizes(hardModel.net), ...
        [expectedHidden 2]);
    verifyEqual(testCase,networkLayerSizes(softModel.net), ...
        [expectedHidden 2]);
    verifyEmpty(testCase,hardModel.net.inputs{1}.processFcns);
    verifyEmpty(testCase,softModel.net.inputs{1}.processFcns);
    verifyEmpty(testCase,hardModel.net.outputs{end}.processFcns);
    verifyEmpty(testCase,softModel.net.outputs{end}.processFcns);
    verifyTrue(testCase,isfield(hardModel,'mp_struct'));
    verifyTrue(testCase,isfield(softModel,'mp_struct'));

    verifySize(testCase,hardMeta.validationPredictions, ...
        [size(hardMeta.validationPairIndex,1) 1]);
    verifySize(testCase,softMeta.validationPredictions, ...
        [size(softMeta.validationPairIndex,1) 1]);
    verifySize(testCase,hardMeta.validationTruth, ...
        [size(hardMeta.validationPairIndex,1) 1]);
    verifySize(testCase,softMeta.validationTruth, ...
        [size(softMeta.validationPairIndex,1) 1]);
    expectedHardError = mean((hardMeta.validationPredictions >= 0.5) ~= ...
        (hardMeta.validationTruth >= 0.5));
    expectedSoftError = mean((softMeta.validationPredictions >= 0.5) ~= ...
        (softMeta.validationTruth >= 0.5));
    verifyEqual(testCase,hardError,expectedHardError,'AbsTol',0);
    verifyEqual(testCase,softError,expectedSoftError,'AbsTol',0);
    verifyGreaterThanOrEqual(testCase,[hardError softError],[0 0]);
    verifyLessThanOrEqual(testCase,[hardError softError],[1 1]);
end

function testReciprocalPredictionAndCandidatePopulationMean(testCase)
    [Input,score] = relationFixture(8,3);
    [model,~,~] = TrainSDEFactorialRelation(Input,score,1,5,6);
    left  = Input(1:3,:)+0.015;
    right = Input(4:6,:)-0.010;

    [pForward,ambiguityForward] = ...
        PredictSDEFactorialPreference(model,left,right);
    [pReverse,ambiguityReverse] = ...
        PredictSDEFactorialPreference(model,right,left);
    [pSelf,ambiguitySelf] = ...
        PredictSDEFactorialPreference(model,Input(1,:),Input(1,:));

    verifyEqual(testCase,pForward+pReverse,ones(3,1), ...
        'AbsTol',1e-12);
    verifyEqual(testCase,ambiguityReverse,ambiguityForward, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,ambiguityForward, ...
        1-abs(2*pForward-1),'AbsTol',0);
    verifyEqual(testCase,pSelf,0.5,'AbsTol',1e-12);
    verifyEqual(testCase,ambiguitySelf,1,'AbsTol',1e-12);

    Candidates = Input(1:3,:)+0.025;
    Anchors    = Input(4:8,:);
    [ind,scores,uncertainty] = ScoreSDEFactorialCandidates( ...
        model,Candidates,Anchors);
    expectedScores = zeros(size(Candidates,1),1);
    expectedUncertainty = zeros(size(Candidates,1),1);
    for i = 1:size(Candidates,1)
        query = repmat(Candidates(i,:),size(Anchors,1),1);
        [pairPreference,pairAmbiguity] = ...
            PredictSDEFactorialPreference(model,query,Anchors);
        expectedScores(i) = mean(pairPreference);
        expectedUncertainty(i) = mean(pairAmbiguity);
    end
    [~,expectedOrder] = sort(expectedScores,'descend');

    verifyEqual(testCase,scores,expectedScores,'AbsTol',1e-12);
    verifyEqual(testCase,uncertainty,expectedUncertainty, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,ind,expectedOrder);
end

function testCandidateScoringBatchesNetworkInference(testCase)
    networkCalls = 0;

    D = 100;
    model = deterministicRelationModel(D);
    model.net = @countingRelationOutput;
    Candidates = reshape(mod(1:120*D,101),120,D)./101;
    Anchors = reshape(mod(1:100*D,97),100,D)./97;

    [order,scores,uncertainty] = ScoreSDEFactorialCandidates( ...
        model,Candidates,Anchors);
    batchedCalls = networkCalls;

    expectedScores = zeros(size(Candidates,1),1);
    expectedUncertainty = zeros(size(Candidates,1),1);
    for i = 1:size(Candidates,1)
        query = repmat(Candidates(i,:),size(Anchors,1),1);
        [preference,ambiguity] = PredictSDEFactorialPreference( ...
            model,query,Anchors);
        expectedScores(i) = mean(preference);
        expectedUncertainty(i) = mean(ambiguity);
    end
    [~,expectedOrder] = sort(expectedScores,'descend');

    verifyEqual(testCase,order,expectedOrder);
    verifyEqual(testCase,scores,expectedScores,'AbsTol',1e-12);
    verifyEqual(testCase,uncertainty,expectedUncertainty,'AbsTol',1e-12);
    verifyLessThan(testCase,batchedCalls,10, ...
        'Candidate scoring must batch pair inference, not call per candidate.');

    function output = countingRelationOutput(X)
        networkCalls = networkCalls + 1;
        output = deterministicRelationOutput(X,D);
    end
end

function testRelationTrainingRestoresRngWhenItRejectsInput(testCase)
    [Input,score] = relationFixture(8,3);
    score(4) = NaN;
    rng(97531,'twister');
    stateBefore = rng;
    caught = [];

    try
        TrainSDEFactorialRelation(Input,score,1,3,7);
    catch err
        caught = err;
    end

    verifyNotEmpty(testCase,caught);
    verifyEqual(testCase,caught.identifier, ...
        'AdaMaO:InvalidRelationScore');
    verifyEqual(testCase,rng,stateBefore);
end

function testRelationTrainingAcceptsExtremeFiniteIds(testCase)
    [Input,score] = relationFixture(6,2);
    rng(86420,'twister');
    stateBefore = rng;

    [model,pError] = TrainSDEFactorialRelation( ...
        Input,score,1,realmax,realmax);

    verifyEqual(testCase,rng,stateBefore);
    verifyTrue(testCase,isfinite(pError));
    verifyEqual(testCase,model.kind,'pairwise');
end

function testLockedU0FilesKeepTheirBaselineGitBlobs(testCase)
    files = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix.m'; ...
        'REMO_new2_AdaMaO_SDEOnly_ModeBase.m'; ...
        fullfile('private','HybridPBI_Classification.m'); ...
        fullfile('private','AdaMaOSelection.m')};
    expected = { ...
        '523deb264424909d84334bdeacf81377352eca8a'; ...
        '411a828ae68111e4ede67709386832624d4c38a4'; ...
        '342658c826e2f1f96937f1d300896b14331d2e2d'; ...
        'b2483d050e91586356871d56e4bbb6ca4cc0aabd'};

    prefixCommand = sprintf('git -C "%s" rev-parse --show-prefix', ...
        testCase.TestData.AlgorithmDir);
    [prefixStatus,repoPrefix] = system(prefixCommand);
    verifyEqual(testCase,prefixStatus,0);
    repoPrefix = strtrim(repoPrefix);

    for i = 1:numel(files)
        file = fullfile(testCase.TestData.AlgorithmDir,files{i});
        repoPath = [repoPrefix,strrep(files{i},'\','/')];
        command = sprintf(['git -C "%s" hash-object --path="%s" ', ...
            '"%s"'],testCase.TestData.AlgorithmDir,repoPath,file);
        [status,blob] = system(command);
        verifyEqual(testCase,status,0);
        verifyEqual(testCase,strtrim(blob),expected{i}, ...
            sprintf('U0 changed: %s',files{i}));
    end
end

function testFourVariantsCompleteOnePostInitializationUpdate(testCase)
    names = { ...
        'REMO_new2_AdaMaO_CPR_F00'; ...
        'REMO_new2_AdaMaO_CPR_F10'; ...
        'REMO_new2_AdaMaO_CPR_F01'; ...
        'REMO_new2_AdaMaO_CPR_F11'};
    expectedBits = [0 0; 1 0; 0 1; 1 1];

    for i = 1:numel(names)
        [Algorithm,Problem,initialFE] = makeSmokeRun( ...
            names{i},3,3,41+i);
        rng(700+i,'twister');
        Algorithm.Solve(Problem);

        verifyGreaterThan(testCase,Problem.FE,initialFE);
        verifyEqual(testCase,Algorithm.metric.cprBits, ...
            expectedBits(i,:));
        verifyGreaterThanOrEqual(testCase, ...
            Algorithm.metric.cprTrace.sourceCalls,1);
        verifyGreaterThanOrEqual(testCase, ...
            Algorithm.metric.cprTrace.relationCalls,1);
        verifyNotEmpty(testCase,Algorithm.result);
    end
end

function testF11CompletesManyObjectiveSmoke(testCase)
    [Algorithm,Problem,initialFE] = makeSmokeRun( ...
        'REMO_new2_AdaMaO_CPR_F11',5,5,81);
    rng(8080,'twister');
    Algorithm.Solve(Problem);

    verifyGreaterThan(testCase,Problem.M,3);
    verifyGreaterThan(testCase,Problem.FE,initialFE);
    verifyEqual(testCase,Algorithm.metric.cprBits,[1 1]);
    verifyGreaterThanOrEqual(testCase, ...
        Algorithm.metric.cprTrace.sourceCalls,1);
    verifyGreaterThanOrEqual(testCase, ...
        Algorithm.metric.cprTrace.relationCalls,1);
end

function [Population,Vglobal] = makeSourcePopulation(M)
    N = 12;
    t = linspace(0.04,0.96,N)';
    PopDec = [t,mod((1:N)',5)/5,1-t/2];
    PopObj = zeros(N,M);
    for j = 1:M
        PopObj(:,j) = 0.4*j + (1+t).^(1+0.15*j) + ...
            0.08*cos((j+1)*pi*t);
    end
    Population = SOLUTION(PopDec,PopObj,zeros(N,1));
    Vglobal = UniformPoint(N,M,'ILD');
end

function [Input,score] = relationFixture(N,D)
    rows = (1:N)';
    Input = zeros(N,D);
    for j = 1:D
        Input(:,j) = mod(rows*(j+2),N+3)/(N+3) + 0.01*j*rows;
    end
    score = linspace(0.07,0.93,N)';
end

function expected = legacyHybridScore(PopObj,RefObj,ratio,theta)
    N = size(PopObj,1);
    M = size(PopObj,2);
    V = UniformPoint(N,M,'ILD');
    V = V ./ vecnorm(V,2,2);
    Zmin = min(PopObj,[],1);
    cosine = 1-pdist2(PopObj,V,'cosine');
    [~,refIndex] = max(cosine,[],2);
    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        w = V(refIndex(i),:);
        d1(i) = (PopObj(i,:)-Zmin)*w'/norm(w);
        projection = Zmin+d1(i)*w;
        d2(i) = norm(PopObj(i,:)-projection);
    end
    scoreV = 1./(1+d1+theta*d2);
    labelDynamic = legacyDynamicLabels(PopObj,RefObj);
    expected = (1-ratio)*scoreV + ratio*double(labelDynamic);
end

function labels = legacyDynamicLabels(PopObj,RefObj)
    lower = -20;
    upper = 20;
    rate  = 0;
    labels = true(size(PopObj,1),1);
    while rate > 0.7 || rate < 0.3
        delta = (lower+upper)/2;
        if abs(lower-upper) < 1e-1
            break;
        end
        [labels,rate] = legacySplit(PopObj,RefObj,delta);
        if rate > 0.7
            lower = delta;
        elseif rate < 0.3
            upper = delta;
        end
    end
end

function [labels,rate] = legacySplit(PopObj,RefObj,delta)
    N = size(PopObj,1);
    labels = true(N,1);
    [~,refIndex] = max(1-pdist2(PopObj,RefObj,'cosine'),[],2);
    ideal = min(PopObj,[],1);
    for i = 1:size(RefObj,1)
        memberIndex = find(refIndex == i);
        subPopulation = PopObj(memberIndex,:);
        bound = RefObj(i,:);
        direction = bound-ideal;
        unitDirection = direction./sqrt(sum(direction.^2,2));
        normDirection = sqrt(sum(unitDirection.^2,2));
        displacement = subPopulation-repmat( ...
            ideal,size(subPopulation,1),1);
        normPoint = sqrt(sum(displacement.^2,2));
        normReference = sqrt(sum((bound-ideal).^2,2));
        cosinePoint = sum(displacement.*repmat( ...
            unitDirection,size(subPopulation,1),1),2) ./ ...
            normDirection ./ normPoint - 1e-6;
        pbi = normPoint.*cosinePoint + ...
            delta*normPoint.*sqrt(1-cosinePoint.^2);
        pbi = pbi./normReference;
        labels(memberIndex(pbi > 1)) = false;
    end
    rate = mean(labels);
end

function pairs = allDirectedPairs(N)
    [left,right] = find(~eye(N));
    pairs = [left,right];
end

function sizes = networkLayerSizes(net)
    sizes = cellfun(@(layer) layer.size,net.layers);
    sizes = sizes(:)';
end

function model = deterministicRelationModel(D)
    fitInput = [zeros(2*D,1),ones(2*D,1)];
    [~,model.mp_struct] = mapminmax(fitInput);
    model.net = @(X) deterministicRelationOutput(X,D);
    model.kind = 'pairwise';
end

function output = deterministicRelationOutput(X,D)
    preference = 1./(1+exp(-(X(1,:)-X(D+1,:))));
    output = [preference;1-preference];
end

function [Algorithm,Problem,initialFE] = makeSmokeRun(name,M,D,runId)
    initialFE = 11*D-1;
    parameters = {[],1,[],[],[],[],[],[]};
    Algorithm = feval(name,'parameter',parameters,'save',0, ...
        'outputFcn',@silentOutput,'run',runId);
    Problem = DTLZ2('N',20,'M',M,'D',D,'maxFE',initialFE+4);
end

function silentOutput(varargin)
end
