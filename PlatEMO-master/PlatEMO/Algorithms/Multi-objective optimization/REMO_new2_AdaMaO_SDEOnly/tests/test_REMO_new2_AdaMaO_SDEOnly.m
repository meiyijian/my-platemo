function tests = test_REMO_new2_AdaMaO_SDEOnly
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile     = mfilename('fullpath');
    testsDir     = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot  = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    testCase.TestData.AlgorithmDir = algorithmDir;
end

function testClassAndSelectorAreDiscoverable(testCase)
    mainFile = fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly.m');
    selectorFile = fullfile(testCase.TestData.AlgorithmDir, ...
        'IndicatorSelectorSDEOnly.m');
    verifyEqual(testCase,which('REMO_new2_AdaMaO_SDEOnly'),mainFile);
    verifyEqual(testCase,which('IndicatorSelectorSDEOnly'),selectorFile);
end

function testSelectorIsFixedSDEAndDoesNotAdvanceRng(testCase)
    t = linspace(0.02,0.98,24)';
    PopObj = [t,1-t,0.35+0.15*sin(2*pi*t)];
    Population = SOLUTION(zeros(24,2),PopObj,zeros(24,1));

    rng(19,'twister');
    stateBefore = rng;
    [fitnessA,LpA] = IndicatorSelectorSDEOnly(Population,1);
    stateAfter = rng;

    rng(91,'twister');
    [fitnessB,LpB] = IndicatorSelectorSDEOnly(Population,1);
    expected = calFitness_SDE(PopObj,LpA);

    verifyEqual(testCase,stateAfter,stateBefore);
    verifyEqual(testCase,LpA,LpB,'AbsTol',1e-12);
    verifyEqual(testCase,fitnessA,fitnessB,'AbsTol',1e-12);
    verifyEqual(testCase,fitnessA,expected,'AbsTol',1e-12);
end

function testMainSourceContainsNoRouletteMachinery(testCase)
    mainSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly.m'));
    selectorSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'IndicatorSelectorSDEOnly.m'));

    forbiddenMain = {'tau_indicator','Choose_record','Win_record', ...
        'UpdateInformation','IndicatorFeedbackScore','indicator_flag', ...
        'calFitness_epsilon','calFitness_MD'};
    for i = 1:numel(forbiddenMain)
        verifyFalse(testCase,contains(mainSource,forbiddenMain{i}), ...
            sprintf('Unexpected roulette token: %s',forbiddenMain{i}));
    end
    verifyEmpty(testCase,regexp(selectorSource,'\<rand\s*\(','once'));
    verifyTrue(testCase,contains(selectorSource,'calFitness_SDE'));
end
