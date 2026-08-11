function tests = test_REMO_new2_AdaMaO_UniformMixOriginalStandalone
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile = mfilename('fullpath');
    testsDir = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    rehash;
    testCase.TestData.AlgorithmDir = algorithmDir;
end

function testEntryResolvesOnlyToStandaloneDirectory(testCase)
    name = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original';
    expected = fullfile(testCase.TestData.AlgorithmDir,[name,'.m']);
    verifyTrue(testCase,isfile(expected));
    verifyEqual(testCase,which(name),expected);

    legacy = fullfile(fileparts(testCase.TestData.AlgorithmDir),[name,'.m']);
    verifyFalse(testCase,isfile(legacy));
end

function testGuiParameterContractContainsOnlySevenActiveParameters(testCase)
    source = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m'));
    names = {'gmax','pMix','rGood','qKeep','lambda0','nMin','nMax'};
    defaults = {'3000','0.50','0.25','0.80','0.35','4','6'};
    for i = 1:numel(names)
        verifyTrue(testCase,contains(source,[names{i},' --- ',defaults{i}]));
    end
    verifyTrue(testCase,contains(source, ...
        'Algorithm.ParameterSet(3000,0.50,0.25,0.80,0.35,4,6)'));
    forbidden = {'w_min','tau_err','use_indicator','debug', ...
        'RelationModeBase','GetRelationPairs_confidence', ...
        'GetRelationPairs_curriculum','RuntimeDiagnostics'};
    for i = 1:numel(forbidden)
        verifyFalse(testCase,contains(source,forbidden{i}), ...
            sprintf('Removed token remains in entry: %s',forbidden{i}));
    end
end

function testStandaloneDependencyBoundary(testCase)
    root = testCase.TestData.AlgorithmDir;
    files = [dir(fullfile(root,'*.m')); ...
             dir(fullfile(root,'private','*.m'))];
    source = '';
    for i = 1:numel(files)
        source = [source,newline,fileread(fullfile(files(i).folder, ...
            files(i).name))]; %#ok<AGROW>
    end
    forbidden = {'RelationModeBase','GetRelationPairs_confidence', ...
        'GetRelationPairs_curriculum','DataProcess_confidence', ...
        'w_min','tau_err','use_indicator','prev_p_err', ...
        'RuntimeDiagnostics','KeepMostConfident'};
    for i = 1:numel(forbidden)
        verifyFalse(testCase,contains(source,forbidden{i}), ...
            sprintf('Forbidden dependency remains: %s',forbidden{i}));
    end
    verifyTrue(testCase,isfile(fullfile(root,'private','AdaMaOSelection.m')));
    verifyTrue(testCase,isfile(fullfile(root,'private','HybridPBI_Classification.m')));
    verifyTrue(testCase,isfile(fullfile(root,'private','IndicatorSelectorSDEOnly.m')));
end

function testUniformMixResolverUsesConfiguredProbability(testCase)
    [below,pBelow] = ResolveUniformMixMode(true,0.49,0.50);
    [boundary,pBoundary] = ResolveUniformMixMode(true,0.50,0.50);
    [zero,pZero] = ResolveUniformMixMode(true,0.99,0.00);
    [one,pOne] = ResolveUniformMixMode(true,0.00,1.00);
    [fallback,pFallback] = ResolveUniformMixMode(false,0.00,1.00);

    verifyEqual(testCase,below,'indicator');
    verifyEqual(testCase,boundary,'explore');
    verifyEqual(testCase,zero,'explore');
    verifyEqual(testCase,one,'indicator');
    verifyEqual(testCase,fallback,'explore');
    verifyEqual(testCase,[pBelow,pBoundary,pZero,pOne,pFallback], ...
        [0.50,0.50,0.00,1.00,1.00],'AbsTol',1e-12);
end

function testInvalidUniformMixProbabilityIsRejected(testCase)
    verifyError(testCase,@() ResolveUniformMixMode(true,0.2,-0.01), ...
        'AdaMaO:InvalidCandidateMixProbability');
    verifyError(testCase,@() ResolveUniformMixMode(true,0.2,1.01), ...
        'AdaMaO:InvalidCandidateMixProbability');
end

function testMainRejectsInvalidParameterConfiguration(testCase)
    algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Original( ...
        'parameter',{1,0.50,0.51,0.80,0.35,2,1}, ...
        'save',0,'outputFcn',@silentOutput,'run',1);
    problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',32,'maxRuntime',inf);
    verifyError(testCase,@() algorithm.Solve(problem), ...
        'AdaMaO:InvalidParameter');
end

function testHybridPbiUsesConfiguredPositiveGroupRatio(testCase)
    root = testCase.TestData.AlgorithmDir;
    hybridFile = fullfile(root,'private','HybridPBI_Classification.m');
    source = fileread(hybridFile);
    verifyTrue(testCase,contains(source, ...
        "rGood = get_option(varargin, 'rGood', 0.25)"));
    verifyTrue(testCase,contains(source,'good_num = ceil(N * rGood);'));
    verifyTrue(testCase,contains(source, ...
        "AdaMaO:InvalidPositiveGroupRatio"));
end

function testShortRunAcceptsSevenParameters(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Original( ...
        'parameter',{1,0.50,0.25,0.80,0.35,1,1}, ...
        'save',0,'outputFcn',@silentOutput,'run',1);
    problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',35,'maxRuntime',inf);
    rng(9001,'twister');
    algorithm.Solve(problem);

    verifyEqual(testCase,problem.FE,35);
    verifyNotEmpty(testCase,algorithm.result);
end

function silentOutput(varargin)
end
