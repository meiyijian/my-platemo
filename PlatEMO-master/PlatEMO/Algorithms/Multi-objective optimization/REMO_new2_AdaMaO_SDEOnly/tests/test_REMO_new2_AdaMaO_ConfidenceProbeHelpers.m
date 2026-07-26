function tests = test_REMO_new2_AdaMaO_ConfidenceProbeHelpers
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

function testSchemaDefinesFourNumericAuditsAndSeparateConfidences(testCase)
    probe = SDEConfidenceProbeSchema();

    verifyEqual(testCase,probe.version,1);
    verifyEqual(testCase,probe.maxPairsPerType,300);
    verifyEqual(testCase,sort(fieldnames(probe.columns)), ...
        sort({'solutionRows';'pbiPairRows';'networkPairRows'; ...
        'candidateRows'}));
    verifyTrue(testCase,ismember('PBIConfidence', ...
        probe.columns.solutionRows));
    verifyFalse(testCase,ismember('NetworkConfidence', ...
        probe.columns.solutionRows));
    verifyTrue(testCase,ismember('NetworkConfidence', ...
        probe.columns.networkPairRows));
    verifyFalse(testCase,ismember('PBIConfidence', ...
        probe.columns.networkPairRows));
    verifyEqual(testCase,probe.codes.pairType.goodGood,1);
    verifyEqual(testCase,probe.codes.pairType.restRest,2);
    verifyEqual(testCase,probe.codes.pairType.goodRest,3);
    verifyEqual(testCase,probe.codes.relation.leftBetter,1);
    verifyEqual(testCase,probe.codes.relation.incomparable,0);
    verifyEqual(testCase,probe.codes.relation.rightBetter,-1);

    rowFields = fieldnames(probe.columns);
    for i = 1:numel(rowFields)
        rows = probe.(rowFields{i});
        verifyTrue(testCase,isnumeric(rows));
        verifySize(testCase,rows, ...
            [0,numel(probe.columns.(rowFields{i}))]);
    end
end

function testPairAuditUsesGeometricConfidenceGoodFirstAndNoRng(testCase)
    probe     = SDEConfidenceProbeSchema();
    evalIDs   = [11;12;13;14];
    objectives = [0 3;1 2;2 1;3 0];
    constraints = zeros(4,0);
    catalog   = logical([0;1;0;1]);
    confidence = [0.04;0.25;0.64;1.00];
    sdeFitness = [1;4;3;2];

    rng(918273,'twister');
    before = rng;
    [solutionRows,pairRows] = BuildSDEConfidencePairAudit( ...
        1,14,evalIDs,objectives,constraints,catalog,confidence, ...
        sdeFitness,'RelationMode',probe.codes.relationMode.weighted, ...
        'CandidateMode',probe.codes.candidateMode.explore, ...
        'MaxPairsPerType',2);
    afterFirst = rng;
    [solutionRowsAgain,pairRowsAgain] = BuildSDEConfidencePairAudit( ...
        1,14,evalIDs,objectives,constraints,catalog,confidence, ...
        sdeFitness,'RelationMode',probe.codes.relationMode.weighted, ...
        'CandidateMode',probe.codes.candidateMode.explore, ...
        'MaxPairsPerType',2);
    afterSecond = rng;

    verifyEqual(testCase,afterFirst,before);
    verifyEqual(testCase,afterSecond,before);
    verifyEqual(testCase,solutionRowsAgain,solutionRows,'AbsTol',0);
    verifyEqual(testCase,pairRowsAgain,pairRows,'AbsTol',0);

    pType = column(probe,'pbiPairRows','PairType');
    left  = column(probe,'pbiPairRows','LeftEvalID');
    right = column(probe,'pbiPairRows','RightEvalID');
    pConf = column(probe,'pbiPairRows','PairConfidence');
    pred  = column(probe,'pbiPairRows','PredictedRelation');
    sde   = column(probe,'pbiPairRows','SDERelation');

    cross = pairRows(:,pType) == probe.codes.pairType.goodRest;
    verifyEqual(testCase,pairRows(cross,left),[12;14]);
    verifyEqual(testCase,pairRows(cross,right),[11;13]);
    verifyEqual(testCase,pairRows(cross,pred),ones(2,1));
    verifyEqual(testCase,pairRows(cross,pConf),[0.10;0.80], ...
        'AbsTol',1e-15);
    verifyEqual(testCase,pairRows(cross,sde),[1;-1]);
    verifyEqual(testCase,sum(pairRows(:,pType) == ...
        probe.codes.pairType.goodGood),1);
    verifyEqual(testCase,sum(pairRows(:,pType) == ...
        probe.codes.pairType.restRest),1);

    n = 30;
    manyObjectives = [(1:n)',(n:-1:1)'];
    manyConfidence = linspace(0.01,1,n)';
    [~,manyPairs] = BuildSDEConfidencePairAudit( ...
        2,44,(101:100+n)',manyObjectives,zeros(n,0),true(n,1), ...
        manyConfidence,(1:n)');
    verifyEqual(testCase,size(manyPairs,1),probe.maxPairsPerType);
    verifyEqual(testCase,manyPairs(1,pConf), ...
        sqrt(manyConfidence(1)*manyConfidence(2)),'AbsTol',1e-15);
    verifyEqual(testCase,manyPairs(end,pConf), ...
        sqrt(manyConfidence(end-1)*manyConfidence(end)), ...
        'AbsTol',1e-15);

    currentND = column(probe,'solutionRows','CurrentND');
    verifyEqual(testCase,solutionRows(:,currentND),ones(4,1));
end

function testTrueRelationIsFeasibilityFirstStrictPareto(testCase)
    leftObj = [ ...
        1 1; ...
        2 2; ...
        1 2; ...
        0 0; ...
        3 3; ...
        1 1];
    rightObj = [ ...
        2 2; ...
        1 1; ...
        2 1; ...
        5 5; ...
        0 0; ...
        1 1];
    leftCon  = [0;0;0;1;2;1];
    rightCon = [0;0;0;2;1;1];

    relation = SDEConfidenceTrueRelation( ...
        leftObj,rightObj,leftCon,rightCon);

    verifyEqual(testCase,relation,[1;-1;0;1;-1;0]);
    verifyEqual(testCase,SDEConfidenceTrueRelation( ...
        [1 1],[1+5e-13 1],[],[],1e-12),0);
end

function testCandidatePairPredictionIsCandidateFirstAndDeterministic(testCase)
    probe = SDEConfidenceProbeSchema();
    model = deterministicModel();

    rng(314159,'twister');
    before = rng;
    rows = PredictSDEConfidenceCandidatePairs( ...
        1,4,[301;302],[0.75;0.25],[201;202],[0.25;0.75], ...
        logical([1;0]),model);
    after = rng;

    verifyEqual(testCase,after,before);
    verifyEqual(testCase,rows(:,column(probe,'networkPairRows', ...
        'CandidateEvalID')),[301;301;302;302]);
    verifyEqual(testCase,rows(:,column(probe,'networkPairRows', ...
        'AnchorEvalID')),[201;202;201;202]);
    expectedProbability = [ ...
        0.60 0.20 0.20; ...
        0.45 0.20 0.35; ...
        0.45 0.20 0.35; ...
        0.30 0.20 0.50];
    actualProbability = rows(:,[ ...
        column(probe,'networkPairRows','ProbabilityLeftBetter'), ...
        column(probe,'networkPairRows','ProbabilitySame'), ...
        column(probe,'networkPairRows','ProbabilityRightBetter')]);
    verifyEqual(testCase,actualProbability,expectedProbability, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,rows(:,column(probe,'networkPairRows', ...
        'PredictedRelation')),[1;1;1;-1]);
    verifyEqual(testCase,rows(:,column(probe,'networkPairRows', ...
        'NetworkConfidence')),[0.60;0.45;0.45;0.50], ...
        'AbsTol',1e-14);
end

function testCandidateCompletionTruthDominanceAndMarginalIGD(testCase)
    probe = SDEConfidenceProbeSchema();
    networkRows = PredictSDEConfidenceCandidatePairs( ...
        1,4,[301;302],[0.75;0.25],[201;202],[0.25;0.75], ...
        logical([1;0]),deterministicModel());
    candidateObj = [0.5 0.5;3 3];
    anchorObj    = [0 2;2 0];

    [completedRows,candidateRows] = ...
        CompleteSDEConfidenceCandidateAudit( ...
        networkRows,[301;302],candidateObj,zeros(2,0), ...
        [201;202],anchorObj,zeros(2,0),[0.5 0.5],1, ...
        'RelationMode',probe.codes.relationMode.weighted, ...
        'CandidateMode',probe.codes.candidateMode.explore);

    pareto = column(probe,'networkPairRows','ParetoRelation');
    sde    = column(probe,'networkPairRows','SDERelation');
    verifyEqual(testCase,completedRows(:,pareto),[0;0;-1;-1]);
    verifyTrue(testCase,all(ismember(completedRows(:,sde),[-1 0 1])));

    dominates = column(probe,'candidateRows','DominatesAny');
    dominated = column(probe,'candidateRows','DominatedByAny');
    nondominated = column(probe,'candidateRows','IsNondominated');
    marginal = column(probe,'candidateRows','MarginalIGD');
    positive = column(probe,'candidateRows','MarginalIGDPositive');
    archiveND = column(probe,'candidateRows','ArchiveNDNext');
    netConfidence = column(probe,'candidateRows','NetworkConfidence');
    predictedBetterRate = column(probe,'candidateRows', ...
        'PredictedBetterRate');

    verifyEqual(testCase,candidateRows(:,dominates),[0;0]);
    verifyEqual(testCase,candidateRows(:,dominated),[0;1]);
    verifyEqual(testCase,candidateRows(:,nondominated),[1;0]);
    verifyEqual(testCase,candidateRows(:,marginal),[sqrt(2.5);0], ...
        'AbsTol',1e-14);
    verifyEqual(testCase,candidateRows(:,positive),[1;0]);
    verifyEqual(testCase,candidateRows(:,archiveND),[1;0]);
    verifyEqual(testCase,candidateRows(:,netConfidence),[0.525;0.475], ...
        'AbsTol',1e-14);
    verifyEqual(testCase,candidateRows(:,predictedBetterRate),[1;0.5], ...
        'AbsTol',1e-14);
end

function testHorizonUpdatesUseGenerationEvalIDAndPreserveCensoring(testCase)
    probe = SDEConfidenceProbeSchema();
    [probe.solutionRows,probe.pbiPairRows] = ...
        BuildSDEConfidencePairAudit( ...
        1,14,[11;12;13;14],[0 3;1 2;2 1;3 0],zeros(4,0), ...
        logical([0;1;0;1]),[0.04;0.25;0.64;1],[1;4;3;2], ...
        'MaxPairsPerType',2);
    probe.networkPairRows = PredictSDEConfidenceCandidatePairs( ...
        1,14,[301;302],[0.75;0.25],[201;202],[0.25;0.75], ...
        logical([1;0]),deterministicModel());
    [probe.networkPairRows,probe.candidateRows] = ...
        CompleteSDEConfidenceCandidateAudit( ...
        probe.networkPairRows,[301;302],[0.5 0.5;3 3],zeros(2,0), ...
        [201;202],[0 2;2 0],zeros(2,0),[0.5 0.5],1);

    probe = UpdateSDEConfidenceProbe( ...
        probe,1,[12;14;301],[11;12;13;14;301],false);

    solutionH1 = column(probe,'solutionRows','SurviveH1');
    candidateH1 = column(probe,'candidateRows','SurviveH1');
    candidateH3 = column(probe,'candidateRows','SurviveH3');
    verifyEqual(testCase,probe.solutionRows(:,solutionH1),[0;1;0;1]);
    verifyEqual(testCase,probe.candidateRows(:,candidateH1),[1;0]);
    verifyTrue(testCase,all(isnan( ...
        probe.candidateRows(:,candidateH3))));

    probe = UpdateSDEConfidenceProbe( ...
        probe,2,[14;301],[12;14;301],false);
    verifyTrue(testCase,all(isnan( ...
        probe.candidateRows(:,candidateH3))));

    lateRow = probe.candidateRows(1,:);
    lateRow(column(probe,'candidateRows','Generation')) = 3;
    lateRow(column(probe,'candidateRows','EvalID')) = 999;
    lateRow(column(probe,'candidateRows','SurviveH1')) = NaN;
    lateRow(column(probe,'candidateRows','SurviveH3')) = NaN;
    lateRow(column(probe,'candidateRows','ArchiveNDNext')) = NaN;
    lateRow(column(probe,'candidateRows','FinalND')) = NaN;
    probe.candidateRows = [probe.candidateRows;lateRow];

    probe = UpdateSDEConfidenceProbe( ...
        probe,3,[12;301;999],[12;301;999],true);

    finalND = column(probe,'candidateRows','FinalND');
    verifyEqual(testCase,probe.candidateRows(1:2,candidateH3),[1;0]);
    verifyTrue(testCase,isnan(probe.candidateRows(3,candidateH3)));
    verifyEqual(testCase,probe.candidateRows(3,candidateH1),1);
    verifyEqual(testCase,probe.candidateRows(:,finalND),[1;0;1]);

    leftH3 = column(probe,'pbiPairRows','LeftSurviveH3');
    rightH3 = column(probe,'pbiPairRows','RightSurviveH3');
    leftID = column(probe,'pbiPairRows','LeftEvalID');
    rightID = column(probe,'pbiPairRows','RightEvalID');
    verifyEqual(testCase,probe.pbiPairRows(:,leftH3), ...
        double(ismember(probe.pbiPairRows(:,leftID),[12;301;999])));
    verifyEqual(testCase,probe.pbiPairRows(:,rightH3), ...
        double(ismember(probe.pbiPairRows(:,rightID),[12;301;999])));
end

function model = deterministicModel()
    fitInput = [0 1;0 1];
    [~,model.mp_struct] = mapminmax(fitInput);
    model.net = @deterministicNetwork;
end

function output = deterministicNetwork(input)
    difference = input(1,:) - input(2,:);
    output = [ ...
        0.45 + 0.15*difference; ...
        0.20*ones(1,size(input,2)); ...
        0.35 - 0.15*difference];
end

function index = column(probe,rowName,columnName)
    index = find(strcmp(probe.columns.(rowName),columnName),1);
    assert(~isempty(index), ...
        'Test schema is missing column %s.%s.',rowName,columnName);
end
