function tests = test_REMO_new2_AdaMaO_SDEOnly_Policies
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

function testAlwaysExploreIgnoresAvailableModel(testCase)
    [mode,pInd,progress] = ResolveSDECandidateMode( ...
        'always_explore',true,150,100,200,0);

    verifyEqual(testCase,mode,'explore');
    verifyEqual(testCase,pInd,0,'AbsTol',1e-12);
    verifyEqual(testCase,progress,0.5,'AbsTol',1e-12);
end

function testAlwaysIndicatorUsesOnlyAvailableModel(testCase)
    [availableMode,pAvailable,progress] = ResolveSDECandidateMode( ...
        'always_indicator',true,150,100,200,0);
    [missingMode,pMissing] = ResolveSDECandidateMode( ...
        'always_indicator',false,150,100,200,0);

    verifyEqual(testCase,availableMode,'indicator');
    verifyEqual(testCase,missingMode,'explore');
    verifyEqual(testCase,pAvailable,1,'AbsTol',1e-12);
    verifyEqual(testCase,pMissing,1,'AbsTol',1e-12);
    verifyEqual(testCase,progress,0.5,'AbsTol',1e-12);
end

function testUniformMixUsesStrictHalfProbabilityBoundary(testCase)
    [belowMode,pBelow] = ResolveSDECandidateMode( ...
        'uniform_mix',true,150,100,200,0.49);
    [boundaryMode,pBoundary] = ResolveSDECandidateMode( ...
        'uniform_mix',true,150,100,200,0.50);

    verifyEqual(testCase,belowMode,'indicator');
    verifyEqual(testCase,boundaryMode,'explore');
    verifyEqual(testCase,pBelow,0.5,'AbsTol',1e-12);
    verifyEqual(testCase,pBoundary,0.5,'AbsTol',1e-12);
end

function testLinearScheduleStartsAtZeroAndEndsAtOne(testCase)
    [initialMode,pInitial,progressInitial] = ResolveSDECandidateMode( ...
        'linear_schedule',true,100,100,200,0);
    [middleMode,pMiddle,progressMiddle] = ResolveSDECandidateMode( ...
        'linear_schedule',true,150,100,200,0.49);
    [finalMode,pFinal,progressFinal] = ResolveSDECandidateMode( ...
        'linear_schedule',true,200,100,200,0.99);

    verifyEqual(testCase,initialMode,'explore');
    verifyEqual(testCase,middleMode,'indicator');
    verifyEqual(testCase,finalMode,'indicator');
    verifyEqual(testCase,[pInitial,pMiddle,pFinal],[0,0.5,1], ...
        'AbsTol',1e-12);
    verifyEqual(testCase,[progressInitial,progressMiddle,progressFinal], ...
        [0,0.5,1],'AbsTol',1e-12);
end

function testCorrectedProgressExcludesInitialEvaluations(testCase)
    [~,~,progressA] = ResolveSDECandidateMode( ...
        'linear_schedule',true,140,100,500,0);
    [~,~,progressB] = ResolveSDECandidateMode( ...
        'linear_schedule',true,220,200,400,0);

    verifyEqual(testCase,progressA,0.1,'AbsTol',1e-12);
    verifyEqual(testCase,progressB,0.1,'AbsTol',1e-12);
end

function testProgressIsClampedAndHandlesNoPostInitialBudget(testCase)
    [~,~,below] = ResolveSDECandidateMode( ...
        'linear_schedule',true,80,100,200,0);
    [~,~,above] = ResolveSDECandidateMode( ...
        'linear_schedule',true,250,100,200,0);
    [~,~,noBudget] = ResolveSDECandidateMode( ...
        'linear_schedule',true,100,100,100,0);

    verifyEqual(testCase,[below,above,noBudget],[0,1,1], ...
        'AbsTol',1e-12);
end

function testRandomPoliciesFallBackWhenModelIsUnavailable(testCase)
    policies = {'uniform_mix','linear_schedule'};
    for i = 1:numel(policies)
        mode = ResolveSDECandidateMode( ...
            policies{i},false,175,100,200,0);
        verifyEqual(testCase,mode,'explore');
    end
end

function testInvalidPolicyAndDrawAreRejected(testCase)
    verifyError(testCase,@() ResolveSDECandidateMode( ...
        'unknown',true,150,100,200,0), ...
        'AdaMaO:UnknownCandidatePolicy');
    verifyError(testCase,@() ResolveSDECandidateMode( ...
        'uniform_mix',true,150,100,200,1), ...
        'AdaMaO:InvalidCandidateModeDraw');
end

function testDedicatedModeStreamIsReproducibleAndIsolated(testCase)
    rng(31,'twister');
    globalBefore = rng;
    [streamA,seedA] = CreateSDECandidateModeStream(7);
    drawsA = rand(streamA,1,8);
    globalAfter = rng;

    [streamB,seedB] = CreateSDECandidateModeStream(7);
    drawsB = rand(streamB,1,8);
    [streamC,seedC] = CreateSDECandidateModeStream(8);
    drawsC = rand(streamC,1,8);

    verifyEqual(testCase,globalAfter,globalBefore);
    verifyEqual(testCase,seedA,seedB);
    verifyNotEqual(testCase,seedA,seedC);
    verifyEqual(testCase,drawsA,drawsB,'AbsTol',0);
    verifyFalse(testCase,isequal(drawsA,drawsC));
end

function testMissingRunUsesRunOneStream(testCase)
    [streamDefault,seedDefault] = CreateSDECandidateModeStream([]);
    [streamOne,seedOne] = CreateSDECandidateModeStream(1);

    verifyEqual(testCase,seedDefault,seedOne);
    verifyEqual(testCase,rand(streamDefault,1,4),rand(streamOne,1,4), ...
        'AbsTol',0);
end

function testFourAlgorithmEntriesAreDiscoverableAndMapped(testCase)
    names = { ...
        'REMO_new2_AdaMaO_SDEOnly_AlwaysExplore', ...
        'REMO_new2_AdaMaO_SDEOnly_AlwaysIndicator', ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix', ...
        'REMO_new2_AdaMaO_SDEOnly_LinearSchedule'};
    policies = {'always_explore','always_indicator', ...
        'uniform_mix','linear_schedule'};

    for i = 1:numel(names)
        expectedFile = fullfile(testCase.TestData.AlgorithmDir, ...
            [names{i},'.m']);
        verifyEqual(testCase,which(names{i}),expectedFile);
        source = fileread(expectedFile);
        verifyTrue(testCase,contains(source,policies{i}));
    end
end

function testSharedRuntimeContainsOnlyTheNewCandidateController(testCase)
    baseFile = fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_ModeBase.m');
    source = fileread(baseFile);

    initPattern = ['Population\s*=\s*Problem\.Evaluation[\s\S]*?', ...
        'InitFE\s*=\s*Problem\.FE'];
    verifyNotEmpty(testCase,regexp(source,initPattern,'once'));
    verifyTrue(testCase,contains(source, ...
        'ratio = Problem.FE / Problem.maxFE;'));
    verifyTrue(testCase,contains(source,'ResolveSDECandidateMode'));
    verifyTrue(testCase,contains(source,'rand(modeStream,1)'));
    verifyFalse(testCase,contains(source,"rng("));

    drawPosition = regexp(source,'u\s*=\s*rand\(modeStream,1\)','once');
    emptyPairExit = regexp(source,'if\s+isempty\(XXs\)','once');
    verifyLessThan(testCase,drawPosition,emptyPairExit, ...
        'The stochastic draw must be consumed before any generation exit.');
end
