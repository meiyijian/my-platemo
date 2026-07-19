function tests = test_REMO_new2_AdaMaO_CPR_Core
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    testFile     = mfilename('fullpath');
    testsDir     = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot  = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    rehash;
end

function testContinuousScoreRangeRatioEndpointsAndPBI(testCase)
    PopObj  = [0 0; 1 0; 0 1; 1 1];
    RefObj  = [1 1];
    Vglobal = [10 0; 0 4];

    [scoreGlobal,detailGlobal] = ComputeSDEFactorialContinuousScore( ...
        PopObj,RefObj,Vglobal,-2,5);
    [scoreLocal,detailLocal] = ComputeSDEFactorialContinuousScore( ...
        PopObj,RefObj,Vglobal,3,5);
    [scoreMixed,detailMixed] = ComputeSDEFactorialContinuousScore( ...
        PopObj,RefObj,Vglobal,0.25,5);

    verifyEqual(testCase,scoreGlobal,detailGlobal.globalScore,'AbsTol',0);
    verifyEqual(testCase,scoreLocal,detailLocal.localScore,'AbsTol',0);
    verifyEqual(testCase,scoreMixed, ...
        0.75*detailMixed.globalScore + 0.25*detailMixed.localScore, ...
        'AbsTol',1e-15);
    verifyEqual(testCase,detailGlobal.globalPBI,[0;1;1;6], ...
        'AbsTol',1e-12);
    verifyEqual(testCase,detailLocal.localPBI, ...
        [0;6/sqrt(2);6/sqrt(2);sqrt(2)],'AbsTol',1e-12);
    verifyTrue(testCase,all(isfinite(scoreMixed)));
    verifyGreaterThanOrEqual(testCase,scoreMixed,zeros(4,1));
    verifyLessThanOrEqual(testCase,scoreMixed,ones(4,1));
    verifyFalse(testCase,isequal(detailMixed.globalScore, ...
        detailMixed.localScore));
end

function testContinuousScoreIsScaleTranslationInvariant(testCase)
    PopObj  = [2 8 4; 3 5 6; 7 3 5; 9 9 2; 4 6 8];
    RefObj  = [3 5 6; 9 9 2; 4 6 8];
    Vglobal = [7 0 0; 0 3 0; 0 0 11; 2 5 1];
    scale   = [3 7 2];
    shift   = [11 -4 20];

    [scoreA,detailA] = ComputeSDEFactorialContinuousScore( ...
        PopObj,RefObj,Vglobal,0.4,3);
    [scoreB,detailB] = ComputeSDEFactorialContinuousScore( ...
        PopObj.*scale+shift,RefObj.*scale+shift,Vglobal,0.4,3);

    verifyEqual(testCase,scoreB,scoreA,'AbsTol',1e-12);
    verifyEqual(testCase,detailB.globalPBI,detailA.globalPBI, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,detailB.localPBI,detailA.localPBI, ...
        'AbsTol',1e-12);
end

function testContinuousScoreHandlesZeroSpanAndSingleSolution(testCase)
    PopObj  = [2 5 1; 2 7 1; 2 9 1];
    RefObj  = [2 5 1; 2 9 1];
    Vglobal = [1 1 1; 0 4 0];

    [score,detail] = ComputeSDEFactorialContinuousScore( ...
        PopObj,RefObj,Vglobal,0.5,5);
    [singleScore,singleDetail] = ComputeSDEFactorialContinuousScore( ...
        [3 3],zeros(0,2),[2 5],0.8,2);

    verifyTrue(testCase,all(isfinite(score)));
    verifyTrue(testCase,all(isfinite(detail.globalPBI)));
    verifyTrue(testCase,all(isfinite(detail.localPBI)));
    verifyEqual(testCase,singleScore,1,'AbsTol',0);
    verifyEqual(testCase,singleDetail.globalScore,1,'AbsTol',0);
    verifyEqual(testCase,singleDetail.localScore,1,'AbsTol',0);
end

function testContinuousScoreHandlesBadDynamicDirections(testCase)
    PopObj  = [0 0; 1 0; 0 1; 1 1];
    Vglobal = [1 0; 0 1];

    [~,repeated] = ComputeSDEFactorialContinuousScore( ...
        PopObj,[0 0; 1 1; 1 1],Vglobal,1,5);
    [~,single] = ComputeSDEFactorialContinuousScore( ...
        PopObj,[1 1],Vglobal,1,5);
    [scoreEmpty,emptyDetail] = ComputeSDEFactorialContinuousScore( ...
        PopObj,zeros(0,2),Vglobal,1,5);

    verifyEqual(testCase,repeated.localPBI,single.localPBI,'AbsTol',0);
    verifyEqual(testCase,repeated.localScore,single.localScore,'AbsTol',0);
    verifyEqual(testCase,emptyDetail.localPBI,emptyDetail.globalPBI, ...
        'AbsTol',0);
    verifyEqual(testCase,emptyDetail.localScore,emptyDetail.globalScore, ...
        'AbsTol',0);
    verifyEqual(testCase,scoreEmpty,emptyDetail.globalScore,'AbsTol',0);
end

function testContinuousScoreRejectsInvalidInputs(testCase)
    validPop = [0 0; 1 1];
    validRef = [1 1];
    validV   = [1 0; 0 1];

    verifyError(testCase,@() ComputeSDEFactorialContinuousScore( ...
        [0 NaN; 1 1],validRef,validV,0.5,5), ...
        'AdaMaO:InvalidContinuousScoreInput');
    verifyError(testCase,@() ComputeSDEFactorialContinuousScore( ...
        validPop,[1 1 1],validV,0.5,5), ...
        'AdaMaO:InvalidContinuousScoreDimensions');
    verifyError(testCase,@() ComputeSDEFactorialContinuousScore( ...
        validPop,validRef,[0 0; 0 0],0.5,5), ...
        'AdaMaO:InvalidGlobalDirections');
    verifyError(testCase,@() ComputeSDEFactorialContinuousScore( ...
        validPop,validRef,validV,Inf,5), ...
        'AdaMaO:InvalidContinuousScoreParameter');
    verifyError(testCase,@() ComputeSDEFactorialContinuousScore( ...
        validPop,validRef,validV,0.5,-1), ...
        'AdaMaO:InvalidContinuousScoreParameter');
end

function testRelationDataBuildsAllPairsWithMatchedLayouts(testCase)
    Input = [10 11; 20 21; 30 31; 40 41];
    score = [0.2; 0.8; 0.8; 0.4];
    expectedIndex = [ ...
        1 2; 2 1; 1 3; 3 1; 1 4; 4 1; ...
        2 3; 3 2; 2 4; 4 2; 3 4; 4 3];

    [hardInput,hardTargets,hardIndex] = ...
        BuildSDEFactorialRelationData(Input,score,0);
    [softInput,softTargets,softIndex] = ...
        BuildSDEFactorialRelationData(Input,score,1);

    verifySize(testCase,hardInput,[12 4]);
    verifySize(testCase,hardTargets,[12 2]);
    verifyEqual(testCase,hardIndex,expectedIndex);
    verifyEqual(testCase,softIndex,hardIndex);
    verifyEqual(testCase,softInput,hardInput);
    verifyEqual(testCase,hardInput, ...
        [Input(hardIndex(:,1),:) Input(hardIndex(:,2),:)]);
    verifyEqual(testCase,sum(hardTargets,2),ones(12,1),'AbsTol',0);
    verifyEqual(testCase,sum(softTargets,2),ones(12,1),'AbsTol',0);
end

function testRelationDataHardSoftFormulaTieAndReverseComplements(testCase)
    Input = (1:4)';
    score = [0.2; 0.8; 0.8; 0.4];
    [~,hardTargets,pairIndex] = ...
        BuildSDEFactorialRelationData(Input,score,0);
    [~,softTargets] = BuildSDEFactorialRelationData(Input,score,1);
    expectedSoft = (1 + score(pairIndex(:,1)) - ...
        score(pairIndex(:,2))) / 2;

    verifyEqual(testCase,softTargets(:,1),expectedSoft,'AbsTol',1e-15);
    verifyEqual(testCase,softTargets(:,2),1-expectedSoft,'AbsTol',1e-15);
    verifyEqual(testCase,hardTargets(7:8,:),repmat([0.5 0.5],2,1), ...
        'AbsTol',0);
    verifyEqual(testCase,hardTargets(1:2:end,1) + ...
        hardTargets(2:2:end,1),ones(6,1),'AbsTol',0);
    verifyEqual(testCase,softTargets(1:2:end,1) + ...
        softTargets(2:2:end,1),ones(6,1),'AbsTol',1e-15);
end

function testRelationDataUsesOriginalSubsetIndicesAndHandlesOneIndex(testCase)
    Input = reshape(1:15,5,3);
    score = [0.1; 0.2; 0.3; 0.4; 0.5];
    expectedIndex = [2 3; 3 2; 2 4; 4 2; 3 4; 4 3];

    [pairInput,targets,pairIndex] = ...
        BuildSDEFactorialRelationData(Input,score,1,[4 2 3]);
    [emptyInput,emptyTargets,emptyIndex] = ...
        BuildSDEFactorialRelationData(Input,score,0,5);
    [explicitEmptyInput,explicitEmptyTargets,explicitEmptyIndex] = ...
        BuildSDEFactorialRelationData(Input,score,0,[]);

    verifyEqual(testCase,pairIndex,expectedIndex);
    verifyEqual(testCase,pairInput, ...
        [Input(pairIndex(:,1),:) Input(pairIndex(:,2),:)]);
    verifySize(testCase,targets,[6 2]);
    verifySize(testCase,emptyInput,[0 6]);
    verifySize(testCase,emptyTargets,[0 2]);
    verifySize(testCase,emptyIndex,[0 2]);
    verifySize(testCase,explicitEmptyInput,[0 6]);
    verifySize(testCase,explicitEmptyTargets,[0 2]);
    verifySize(testCase,explicitEmptyIndex,[0 2]);
end

function testRelationDataRejectsInvalidInputs(testCase)
    Input = [1 2; 3 4; 5 6];
    score = [0.1; 0.5; 0.9];

    verifyError(testCase,@() BuildSDEFactorialRelationData( ...
        Input,[0.1; NaN; 0.9],0), ...
        'AdaMaO:InvalidRelationScore');
    verifyError(testCase,@() BuildSDEFactorialRelationData( ...
        Input,[0.1; 1.1; 0.9],0), ...
        'AdaMaO:InvalidRelationScore');
    verifyError(testCase,@() BuildSDEFactorialRelationData( ...
        Input,score,2), ...
        'AdaMaO:InvalidRelationBit');
    verifyError(testCase,@() BuildSDEFactorialRelationData( ...
        Input,score,0,[1 1]), ...
        'AdaMaO:InvalidRelationIndices');
    verifyError(testCase,@() BuildSDEFactorialRelationData( ...
        [1 NaN; 3 4; 5 6],score,0), ...
        'AdaMaO:InvalidRelationInput');
end

function testSymmetrizeIsReciprocalAndReportsAmbiguity(testCase)
    Qforward = [0.8 0.2; 0.4 0.6; 0.5 0.5];
    Qreverse = [0.3 0.7; 0.8 0.2; 0.5 0.5];

    [p,ambiguity,Qsym] = SymmetrizeSDEFactorialPreference( ...
        Qforward,Qreverse);
    [pSwap,ambiguitySwap,QsymSwap] = ...
        SymmetrizeSDEFactorialPreference(Qreverse,Qforward);

    verifyEqual(testCase,sum(Qsym,2),ones(3,1),'AbsTol',0);
    verifyEqual(testCase,p,Qsym(:,1),'AbsTol',0);
    verifyEqual(testCase,pSwap,1-p,'AbsTol',1e-15);
    verifyEqual(testCase,QsymSwap,Qsym(:,[2 1]),'AbsTol',1e-15);
    verifyEqual(testCase,ambiguity,1-abs(2*p-1),'AbsTol',0);
    verifyEqual(testCase,ambiguitySwap,ambiguity,'AbsTol',1e-15);

    [selfPreference,selfAmbiguity,selfSymmetric] = ...
        SymmetrizeSDEFactorialPreference([0.8 0.2],[0.8 0.2]);
    verifyEqual(testCase,selfPreference,0.5,'AbsTol',0);
    verifyEqual(testCase,selfAmbiguity,1,'AbsTol',0);
    verifyEqual(testCase,selfSymmetric,[0.5 0.5],'AbsTol',0);
end

function testSymmetrizeClampsAndFallsBackInvalidRows(testCase)
    Qforward = [NaN 1; -3 -2; -2 4; Inf 0; 0 0];
    Qreverse = zeros(5,2);

    [p,ambiguity,Qsym] = SymmetrizeSDEFactorialPreference( ...
        Qforward,Qreverse);

    verifyEqual(testCase,Qsym([1 2 4 5],:), ...
        repmat([0.5 0.5],4,1),'AbsTol',0);
    verifyEqual(testCase,Qsym(3,:),[0 1],'AbsTol',0);
    verifyEqual(testCase,p,[0.5;0.5;0;0.5;0.5],'AbsTol',0);
    verifyEqual(testCase,ambiguity,[1;1;0;1;1],'AbsTol',0);
    verifyTrue(testCase,all(isfinite(Qsym),'all'));
end

function testSymmetrizeRejectsMismatchedShapes(testCase)
    verifyError(testCase,@() SymmetrizeSDEFactorialPreference( ...
        ones(2,2),ones(3,2)), ...
        'AdaMaO:InvalidPreferenceDimensions');
    verifyError(testCase,@() SymmetrizeSDEFactorialPreference( ...
        ones(2,3),ones(2,3)), ...
        'AdaMaO:InvalidPreferenceDimensions');
end

function testSolutionSplitKeepsDuplicateRowsTogether(testCase)
    Input = [ ...
        1 10; 1 10; 2 20; 2 20; 3 30; 4 40; ...
        5 50; 5 50; 6 60; 7 70; 8 80; 8 80];

    [trainIdx,valIdx] = SplitSDEFactorialSolutions(Input,7,3);
    trainRows = unique(Input(trainIdx,:),'rows');
    valRows   = unique(Input(valIdx,:),'rows');

    verifyEmpty(testCase,intersect(trainRows,valRows,'rows'));
    verifyEqual(testCase,sort([trainIdx;valIdx]),(1:size(Input,1))');
    verifyEqual(testCase,size(trainRows,1),6);
    verifyEqual(testCase,size(valRows,1),2);
    verifySize(testCase,trainIdx,[numel(trainIdx) 1]);
    verifySize(testCase,valIdx,[numel(valIdx) 1]);
end

function testSolutionSplitIsReproducibleVariableAndRngIsolated(testCase)
    Input = [(1:40)' mod((1:40)',7)];
    rng(2468,'twister');
    globalBefore = rng;

    [trainA,valA] = SplitSDEFactorialSolutions(Input,11,5);
    globalAfterA = rng;
    [trainB,valB] = SplitSDEFactorialSolutions(Input,11,5);
    [~,valRun] = SplitSDEFactorialSolutions(Input,12,5);
    [~,valGeneration] = SplitSDEFactorialSolutions(Input,11,6);
    globalAfterAll = rng;

    verifyEqual(testCase,trainB,trainA);
    verifyEqual(testCase,valB,valA);
    verifyFalse(testCase,isequal(valRun,valA));
    verifyFalse(testCase,isequal(valGeneration,valA));
    verifyEqual(testCase,globalAfterA,globalBefore);
    verifyEqual(testCase,globalAfterAll,globalBefore);
end

function testSolutionSplitFallsBackForFewerThanFourGroups(testCase)
    Input = [1 1; 1 1; 2 2; 3 3];

    [trainIdx,valIdx] = SplitSDEFactorialSolutions(Input,2,9);

    verifyEqual(testCase,trainIdx,(1:4)');
    verifySize(testCase,valIdx,[0 1]);
end

function testSeedRecipesPreserveNormalRunsAndHandleExtremeIds(testCase)
    runId = 17;
    generation = 5;
    phase = 2;

    expectedRelation = mod(runId*104729 + generation*130363 + ...
        phase*15485863 + 32452843,2147483647);
    expectedRegression = mod(runId*179424673 + generation*15485863 + ...
        phase*32452843 + 49979687,2147483647);
    expectedSplit = mod(runId*1103515245 + generation*2654435761 + ...
        12345,4294967295);
    expectedLegacy = mod(runId*1103515245 + generation*2654435761 + ...
        2246822519,4294967295);

    verifyEqual(testCase,MakeSDEFactorialSeed( ...
        runId,generation,phase,'relation'),expectedRelation);
    verifyEqual(testCase,MakeSDEFactorialSeed( ...
        runId,generation,phase,'regression'),expectedRegression);
    verifyEqual(testCase,MakeSDEFactorialSeed( ...
        runId,generation,0,'split'),expectedSplit);
    verifyEqual(testCase,MakeSDEFactorialSeed( ...
        runId,generation,0,'legacy'),expectedLegacy);

    recipes = {'relation','regression','split','legacy'};
    for i = 1:numel(recipes)
        seed = MakeSDEFactorialSeed( ...
            realmax,realmax,realmax,recipes{i});
        verifyTrue(testCase,isnumeric(seed) && isreal(seed) && ...
            isscalar(seed) && isfinite(seed));
        verifyGreaterThanOrEqual(testCase,seed,0);
        verifyLessThan(testCase,seed,4294967295);
        verifyWarningFree(testCase,@() rng(seed,'twister'));
    end
end
