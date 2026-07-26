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

function testAllPairTypesUseExactEqualSpacingWithoutRng(testCase)
    probe = SDEConfidenceProbeSchema();
    nGood = 26;
    nRest = 26;
    n = nGood + nRest;
    evalIDs = (5001:5000+n)';
    objectives = [(1:n)',(n:-1:1)'];
    catalog = [true(nGood,1);false(nRest,1)];
    primeValues = primes(300);
    confidence = primeValues(1:n)'./primeValues(n);

    rng(271828,'twister');
    before = rng;
    [~,pairRows] = BuildSDEConfidencePairAudit( ...
        7,700,evalIDs,objectives,zeros(n,0),catalog,confidence, ...
        (n:-1:1)');
    after = rng;

    verifyEqual(testCase,after,before);
    pairTypeColumn = column(probe,'pbiPairRows','PairType');
    outputColumns = [ ...
        column(probe,'pbiPairRows','LeftEvalID'), ...
        column(probe,'pbiPairRows','RightEvalID'), ...
        column(probe,'pbiPairRows','PairConfidence')];
    pairTypes = [probe.codes.pairType.goodGood, ...
        probe.codes.pairType.restRest, ...
        probe.codes.pairType.goodRest];
    expectedFullCounts = [nchoosek(nGood,2),nchoosek(nRest,2), ...
        nGood*nRest];

    for i = 1:numel(pairTypes)
        expected = independentlySamplePairs( ...
            evalIDs,catalog,confidence,pairTypes(i), ...
            probe.maxPairsPerType);
        actual = pairRows(pairRows(:,pairTypeColumn) == pairTypes(i), ...
            outputColumns);

        verifyGreaterThan(testCase,expectedFullCounts(i), ...
            probe.maxPairsPerType);
        verifySize(testCase,actual,[probe.maxPairsPerType,3]);
        verifyEqual(testCase,actual(:,1:2),expected(:,1:2));
        verifyEqual(testCase,actual(:,3),expected(:,3),'AbsTol',0);
    end
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
    combinedFitness = calFitness_SDE([anchorObj;candidateObj],1);
    candidateID = completedRows(:,column(probe,'networkPairRows', ...
        'CandidateEvalID'));
    anchorID = completedRows(:,column(probe,'networkPairRows', ...
        'AnchorEvalID'));
    [~,candidateIndex] = ismember(candidateID,[301;302]);
    [~,anchorIndex] = ismember(anchorID,[201;202]);
    expectedSDE = strictScoreDirection( ...
        combinedFitness(2+candidateIndex), ...
        combinedFitness(anchorIndex),1e-12);
    verifyEqual(testCase,completedRows(:,sde),expectedSDE);

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

function testMarginalIGDRemovesOnlyDominatedCurrentNDPoints(testCase)
    probe = SDEConfidenceProbeSchema();
    candidateID = 501;
    anchorIDs = (401:404)';
    candidateObj = [1 2];
    anchorObj = [0 4;1 3;3 1;4 0];
    optimum = [1 2;1 3;1.5 1.5;3 1;0 4;4 0];
    networkRows = PredictSDEConfidenceCandidatePairs( ...
        2,20,candidateID,0.6,anchorIDs,[0.1;0.3;0.7;0.9], ...
        logical([1;1;0;0]),deterministicModel());

    [~,candidateRows] = CompleteSDEConfidenceCandidateAudit( ...
        networkRows,candidateID,candidateObj,zeros(1,0), ...
        anchorIDs,anchorObj,zeros(4,0),optimum,1);

    removed = all(candidateObj <= anchorObj,2) & ...
        any(candidateObj < anchorObj,2);
    verifyEqual(testCase,removed,logical([0;1;0;0]));
    baselineIGD = mean(min(pdist2(optimum,anchorObj),[],2));
    updatedObj = [anchorObj(~removed,:);candidateObj];
    expectedMarginal = baselineIGD - ...
        mean(min(pdist2(optimum,updatedObj),[],2));
    wrongNoRemoval = baselineIGD - mean(min( ...
        pdist2(optimum,[anchorObj;candidateObj]),[],2));
    verifyGreaterThan(testCase, ...
        abs(expectedMarginal-wrongNoRemoval),1e-12);

    marginalColumn = column(probe,'candidateRows','MarginalIGD');
    verifyEqual(testCase,candidateRows(:,marginalColumn), ...
        expectedMarginal,'AbsTol',1e-14);
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

    solutionH1 = column(probe,'solutionRows','SurviveH1');
    solutionH3 = column(probe,'solutionRows','SurviveH3');
    solutionFinal = column(probe,'solutionRows','FinalND');
    pbiLeftH1 = column(probe,'pbiPairRows','LeftSurviveH1');
    pbiRightH1 = column(probe,'pbiPairRows','RightSurviveH1');
    pbiLeftH3 = column(probe,'pbiPairRows','LeftSurviveH3');
    pbiRightH3 = column(probe,'pbiPairRows','RightSurviveH3');
    pbiLeftFinal = column(probe,'pbiPairRows','LeftFinalND');
    pbiRightFinal = column(probe,'pbiPairRows','RightFinalND');
    networkH1 = column(probe,'networkPairRows','CandidateSurviveH1');
    networkH3 = column(probe,'networkPairRows','CandidateSurviveH3');
    networkFinal = column(probe,'networkPairRows','CandidateFinalND');
    candidateH1 = column(probe,'candidateRows','SurviveH1');
    candidateH3 = column(probe,'candidateRows','SurviveH3');
    candidateArchiveND = column(probe,'candidateRows','ArchiveNDNext');
    candidateFinal = column(probe,'candidateRows','FinalND');

    verifyTrue(testCase,all(isnan(probe.solutionRows(:, ...
        [solutionH1,solutionH3,solutionFinal])),'all'));
    verifyTrue(testCase,all(isnan(probe.pbiPairRows(:, ...
        [pbiLeftH1,pbiRightH1,pbiLeftH3,pbiRightH3, ...
        pbiLeftFinal,pbiRightFinal])),'all'));
    verifyTrue(testCase,all(isnan(probe.networkPairRows(:, ...
        [networkH1,networkH3,networkFinal])),'all'));
    verifyTrue(testCase,all(isnan(probe.candidateRows(:, ...
        [candidateH1,candidateH3,candidateFinal])),'all'));
    verifyEqual(testCase,probe.candidateRows(:,candidateArchiveND),[1;0]);

    probe = UpdateSDEConfidenceProbe( ...
        probe,1,[12;14;301],[11;12;13;14;301],false);

    verifyEqual(testCase,probe.solutionRows(:,solutionH1),[0;1;0;1]);
    pbiLeftID = column(probe,'pbiPairRows','LeftEvalID');
    pbiRightID = column(probe,'pbiPairRows','RightEvalID');
    verifyEqual(testCase,probe.pbiPairRows(:,pbiLeftH1),double( ...
        ismember(probe.pbiPairRows(:,pbiLeftID),[12;14;301])));
    verifyEqual(testCase,probe.pbiPairRows(:,pbiRightH1),double( ...
        ismember(probe.pbiPairRows(:,pbiRightID),[12;14;301])));
    networkCandidateID = column(probe,'networkPairRows', ...
        'CandidateEvalID');
    verifyEqual(testCase,probe.networkPairRows(:,networkH1),double( ...
        ismember(probe.networkPairRows(:,networkCandidateID), ...
        [12;14;301])));
    verifyEqual(testCase,probe.candidateRows(:,candidateH1),[1;0]);
    verifyEqual(testCase,probe.candidateRows(:,candidateArchiveND),[1;0]);
    verifyTrue(testCase,all(isnan(probe.solutionRows(:, ...
        [solutionH3,solutionFinal])),'all'));
    verifyTrue(testCase,all(isnan(probe.pbiPairRows(:, ...
        [pbiLeftH3,pbiRightH3,pbiLeftFinal,pbiRightFinal])),'all'));
    verifyTrue(testCase,all(isnan(probe.networkPairRows(:, ...
        [networkH3,networkFinal])),'all'));
    verifyTrue(testCase,all(isnan(probe.candidateRows(:, ...
        [candidateH3,candidateFinal])),'all'));

    probe = UpdateSDEConfidenceProbe( ...
        probe,2,[14;301],[12;14;301],false);
    verifyTrue(testCase,all(isnan(probe.solutionRows(:,solutionH3)),'all'));
    verifyTrue(testCase,all(isnan(probe.pbiPairRows(:, ...
        [pbiLeftH3,pbiRightH3])),'all'));
    verifyTrue(testCase,all(isnan(probe.networkPairRows(:,networkH3)),'all'));
    verifyTrue(testCase,all(isnan(probe.candidateRows(:,candidateH3)),'all'));

    lateSolution = probe.solutionRows(1,:);
    lateSolution(column(probe,'solutionRows','Generation')) = 3;
    lateSolution(column(probe,'solutionRows','EvalID')) = 888;
    lateSolution([solutionH1,solutionH3,solutionFinal]) = NaN;
    probe.solutionRows = [probe.solutionRows;lateSolution];

    latePBI = probe.pbiPairRows(1,:);
    latePBI(column(probe,'pbiPairRows','Generation')) = 3;
    latePBI(pbiLeftID) = 888;
    latePBI(pbiRightID) = 999;
    latePBI([pbiLeftH1,pbiRightH1,pbiLeftH3,pbiRightH3, ...
        pbiLeftFinal,pbiRightFinal]) = NaN;
    probe.pbiPairRows = [probe.pbiPairRows;latePBI];

    lateNetwork = probe.networkPairRows(1,:);
    lateNetwork(column(probe,'networkPairRows','Generation')) = 3;
    lateNetwork(networkCandidateID) = 999;
    lateNetwork(column(probe,'networkPairRows','AnchorEvalID')) = 888;
    lateNetwork([networkH1,networkH3,networkFinal]) = NaN;
    probe.networkPairRows = [probe.networkPairRows;lateNetwork];

    lateRow = probe.candidateRows(1,:);
    lateRow(column(probe,'candidateRows','Generation')) = 3;
    lateRow(column(probe,'candidateRows','EvalID')) = 999;
    lateRow([candidateH1,candidateH3,candidateArchiveND, ...
        candidateFinal]) = NaN;
    probe.candidateRows = [probe.candidateRows;lateRow];

    probe = UpdateSDEConfidenceProbe( ...
        probe,3,[12;14;301;888;999],[12;301;999],true);

    solutionID = column(probe,'solutionRows','EvalID');
    verifyEqual(testCase,probe.solutionRows(1:4,solutionH3), ...
        double(ismember(probe.solutionRows(1:4,solutionID), ...
        [12;14;301;888;999])));
    verifyEqual(testCase,probe.solutionRows(:,solutionFinal), ...
        double(ismember(probe.solutionRows(:,solutionID),[12;301;999])));
    verifyEqual(testCase,probe.solutionRows(end,solutionH1),1);
    verifyTrue(testCase,isnan(probe.solutionRows(end,solutionH3)));

    verifyEqual(testCase,probe.pbiPairRows(1:end-1,pbiLeftH3), ...
        double(ismember(probe.pbiPairRows(1:end-1,pbiLeftID), ...
        [12;14;301;888;999])));
    verifyEqual(testCase,probe.pbiPairRows(1:end-1,pbiRightH3), ...
        double(ismember(probe.pbiPairRows(1:end-1,pbiRightID), ...
        [12;14;301;888;999])));
    verifyEqual(testCase,probe.pbiPairRows(:,pbiLeftFinal), ...
        double(ismember(probe.pbiPairRows(:,pbiLeftID),[12;301;999])));
    verifyEqual(testCase,probe.pbiPairRows(:,pbiRightFinal), ...
        double(ismember(probe.pbiPairRows(:,pbiRightID),[12;301;999])));
    verifyEqual(testCase,probe.pbiPairRows(end, ...
        [pbiLeftH1,pbiRightH1]),[1 1]);
    verifyTrue(testCase,all(isnan(probe.pbiPairRows(end, ...
        [pbiLeftH3,pbiRightH3]))));

    verifyEqual(testCase,probe.networkPairRows(1:end-1,networkH3), ...
        double(ismember(probe.networkPairRows(1:end-1, ...
        networkCandidateID),[12;14;301;888;999])));
    verifyEqual(testCase,probe.networkPairRows(:,networkFinal), ...
        double(ismember(probe.networkPairRows(:,networkCandidateID), ...
        [12;301;999])));
    verifyEqual(testCase,probe.networkPairRows(end,networkH1),1);
    verifyTrue(testCase,isnan(probe.networkPairRows(end,networkH3)));

    verifyEqual(testCase,probe.candidateRows(1:2,candidateH3),[1;0]);
    verifyTrue(testCase,isnan(probe.candidateRows(3,candidateH3)));
    verifyEqual(testCase,probe.candidateRows(3,candidateH1),1);
    verifyEqual(testCase,probe.candidateRows(:,candidateArchiveND), ...
        [1;0;1]);
    verifyEqual(testCase,probe.candidateRows(:,candidateFinal),[1;0;1]);
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

function sampled = independentlySamplePairs( ...
    evalIDs,catalog,confidence,targetType,maxRows)
    n = numel(evalIDs);
    allPairs = zeros(nchoosek(n,2),4);
    row = 0;
    for i = 1:n-1
        for j = i+1:n
            row = row + 1;
            left = i;
            right = j;
            if ~catalog(left) && catalog(right)
                left = j;
                right = i;
            end
            if catalog(left) && catalog(right)
                pairType = 1;
            elseif ~catalog(left) && ~catalog(right)
                pairType = 2;
            else
                pairType = 3;
            end
            allPairs(row,:) = [pairType,evalIDs(left),evalIDs(right), ...
                sqrt(confidence(left)*confidence(right))];
        end
    end
    subset = allPairs(allPairs(:,1) == targetType,:);
    subset = sortrows(subset,[4 2 3]);
    keep = round(linspace(1,size(subset,1),maxRows))';
    sampled = subset(keep,2:4);
end

function relation = strictScoreDirection(left,right,tolerance)
    relation = zeros(size(left));
    relation(left > right+tolerance) = 1;
    relation(right > left+tolerance) = -1;
end

function index = column(probe,rowName,columnName)
    index = find(strcmp(probe.columns.(rowName),columnName),1);
    assert(~isempty(index), ...
        'Test schema is missing column %s.%s.',rowName,columnName);
end
