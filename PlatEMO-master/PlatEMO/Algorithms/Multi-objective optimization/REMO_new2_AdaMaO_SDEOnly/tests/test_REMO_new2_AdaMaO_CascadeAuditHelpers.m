function tests = test_REMO_new2_AdaMaO_CascadeAuditHelpers
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

function testSchemaDefinesExactVersionedNumericContract(testCase)
    audit = CascadeAuditSchema();

    expectedCandidateColumns = { ...
        'Run','Generation','FE','PostInitProgress','CandidateIndex', ...
        'CandidateMode','OperationalIndicatorUsed', ...
        'RelationScore','RelationPercentile','IndicatorScore', ...
        'IndicatorPercentile','PositiveDisagreement','CoarseKept', ...
        'BaselineSelected','ShadowFeasible','MarginalIGDp','Useful', ...
        'ReplacementGain','NearestSelectedDistance','OracleTopK', ...
        'IndicatorTopK','MaxPositiveDisagreement'};
    expectedGenerationColumns = { ...
        'Run','Generation','FE','PostInitProgress','CandidateMode', ...
        'OperationalIndicatorUsed', ...
        'CandidateCount','CoarseCount','BatchSize','ReferenceCount', ...
        'ShadowEvaluationCount','BaselineIGDp','RecallAtK','UsefulFNR', ...
        'SingleCoverageRegret','NormalizedBatchCoverageRegret', ...
        'RescueOpportunityRate','DisagreementEnrichment','CVKendall', ...
        'MaxDisagreementReplacementGain','MaxDisagreementSuccess', ...
        'OracleRejectedReplacementGain','ReplacementCapture', ...
        'BaselineBatchUtility','IndicatorTopKMeanUtility', ...
        'FullReferenceRankCorrelation','FullReferenceTopKOverlap', ...
        'AuditSeconds'};

    verifyEqual(testCase,audit.version,1);
    verifyEqual(testCase,audit.columns.candidateRows, ...
        expectedCandidateColumns);
    verifyEqual(testCase,audit.columns.generationRows, ...
        expectedGenerationColumns);
    verifyEqual(testCase,audit.codes.candidateMode.unknown,0);
    verifyEqual(testCase,audit.codes.candidateMode.explore,1);
    verifyEqual(testCase,audit.codes.candidateMode.indicator,2);
    verifySize(testCase,audit.candidateRows, ...
        [0,numel(expectedCandidateColumns)]);
    verifySize(testCase,audit.generationRows, ...
        [0,numel(expectedGenerationColumns)]);
    verifyEqual(testCase,audit.totalShadowEvaluations,0);
    verifyEqual(testCase,audit.totalAuditSeconds,0);
end

function testDescendingPercentileRanksAreTieAwareAndValidated(testCase)
    actual = RankPercentileDescending([9;7;7;1]);

    verifyEqual(testCase,actual,[1;0.5;0.5;0],'AbsTol',1e-14);
    verifyEqual(testCase,RankPercentileDescending(4),1);
    verifyEqual(testCase,RankPercentileDescending([4;4;4]), ...
        [0.5;0.5;0.5],'AbsTol',1e-14);
    verifyEmpty(testCase,RankPercentileDescending(zeros(0,1)));
    verifyError(testCase,@() RankPercentileDescending([1;NaN]), ...
        'AdaMaO:InvalidCascadeRankScores');
    verifyError(testCase,@() RankPercentileDescending([1;1i]), ...
        'AdaMaO:InvalidCascadeRankScores');
    verifyError(testCase,@() RankPercentileDescending([1;Inf]), ...
        'AdaMaO:InvalidCascadeRankScores');
    verifyError(testCase,@() RankPercentileDescending(ones(2,2)), ...
        'AdaMaO:InvalidCascadeRankScores');
end

function testMarginalIGDpUsesTheMinimizationDirectionExactly(testCase)
    archiveObj   = [0 2;2 0];
    candidateObj = [0.5 0.5;3 3];
    referenceObj = [0 0;1 1];

    [utility,baseline,used,baselineDistance,candidateDistance] = ...
        ComputeMarginalIGDp(archiveObj,candidateObj,referenceObj);

    verifyEqual(testCase,baseline,1.5,'AbsTol',1e-14);
    verifyEqual(testCase,utility, ...
        [1.5-(sqrt(0.5)+0)/2;0],'AbsTol',1e-14);
    verifyEqual(testCase,used,2);
    verifyEqual(testCase,baselineDistance,[2;1],'AbsTol',1e-14);
    verifyEqual(testCase,candidateDistance, ...
        [sqrt(0.5),sqrt(18);0,sqrt(8)],'AbsTol',1e-14);
end

function testMarginalIGDpRejectsInvalidOrDimensionMismatchedInputs(testCase)
    verifyError(testCase,@() ComputeMarginalIGDp( ...
        zeros(0,2),[1 1],[0 0]),'AdaMaO:InvalidCascadeIGDpInputs');
    verifyError(testCase,@() ComputeMarginalIGDp( ...
        [1 1],[1 1 1],[0 0]),'AdaMaO:InvalidCascadeIGDpInputs');
    verifyError(testCase,@() ComputeMarginalIGDp( ...
        [1 NaN],[1 1],[0 0]),'AdaMaO:InvalidCascadeIGDpInputs');
    verifyError(testCase,@() ComputeMarginalIGDp( ...
        [1 1],[1 1],zeros(0,2)),'AdaMaO:InvalidCascadeIGDpInputs');
end

function testMarginalIGDpHandlesEmptyAndChunkBoundaryCandidates(testCase)
    [emptyUtility,baseline,used,baselineDistance,emptyDistance] = ...
        ComputeMarginalIGDp([0 0],zeros(0,2),[0 0;1 1]);
    verifySize(testCase,emptyUtility,[0,1]);
    verifySize(testCase,emptyDistance,[2,0]);
    verifyEqual(testCase,baseline,0,'AbsTol',0);
    verifyEqual(testCase,used,2);
    verifyEqual(testCase,baselineDistance,[0;0],'AbsTol',0);

    candidates = repmat([0.5 0.5],257,1);
    [utility,~,~,~,distance] = ComputeMarginalIGDp( ...
        [2 2],candidates,[0 0]);
    verifySize(testCase,utility,[257,1]);
    verifySize(testCase,distance,[1,257]);
    verifyEqual(testCase,utility(1),utility(257),'AbsTol',0);
    verifyEqual(testCase,distance(1),distance(end),'AbsTol',0);
end

function testBatchCounterfactualUsesAFixedDisplacedSlotAndSignedGain(testCase)
    archiveObj   = [3 3];
    candidateObj = [0.5 0.5;2 2;1 1;0.25 0.25];
    referenceObj = [0 0];
    [marginal,~,~,baselineDistance,candidateDistance] = ...
        ComputeMarginalIGDp(archiveObj,candidateObj,referenceObj);
    selected = logical([1;1;0;0]);
    coarse   = logical([1;1;0;0]);
    indicatorScore = [0.1;0.9;0.8;0.7];

    result = ComputeCascadeBatchCounterfactual( ...
        baselineDistance,candidateDistance,selected,coarse, ...
        indicatorScore);

    verifyEqual(testCase,result.BatchSize,2);
    verifyEqual(testCase,result.DisplacedIndex,1);
    verifyEqual(testCase,result.BaselineBatchIGDp,sqrt(0.5), ...
        'AbsTol',1e-14);
    verifyEqual(testCase,result.BaselineBatchUtility, ...
        sqrt(18)-sqrt(0.5),'AbsTol',1e-14);
    verifyTrue(testCase,all(isnan(result.ReplacementGain(1:2))));
    verifyEqual(testCase,result.ReplacementGain(3:4), ...
        [-sqrt(0.5);sqrt(0.5)-sqrt(0.125)],'AbsTol',1e-14);
    verifyGreaterThan(testCase,marginal(3),0);
    verifyLessThan(testCase,result.ReplacementGain(3),0);
    verifyEqual(testCase,result.GreedyAllIndices,[4;1]);
    verifyEqual(testCase,result.GreedyCoarseIndices,[1;2]);
    verifyEqual(testCase,result.GreedyAllUtility, ...
        sqrt(18)-sqrt(0.125),'AbsTol',1e-14);
    verifyEqual(testCase,result.GreedyCoarseUtility, ...
        sqrt(18)-sqrt(0.5),'AbsTol',1e-14);
    verifyEqual(testCase,result.NormalizedBatchCoverageRegret,1/11, ...
        'AbsTol',1e-14);
    verifyTrue(testCase,result.HasBatchCoverageOpportunity);
    verifyEqual(testCase,result.OracleRejectedReplacementGain, ...
        sqrt(0.5)-sqrt(0.125),'AbsTol',1e-14);
    verifyTrue(testCase,result.HasReplacementOpportunity);
end

function testBatchCounterfactualMarksNoOpportunityExplicitly(testCase)
    result = ComputeCascadeBatchCounterfactual( ...
        0,zeros(1,3),logical([1;0;0]),logical([1;0;0]), ...
        [1;0.5;0.25]);

    verifyFalse(testCase,result.HasBatchCoverageOpportunity);
    verifyTrue(testCase,isnan(result.NormalizedBatchCoverageRegret));
    verifyFalse(testCase,result.HasReplacementOpportunity);
    verifyEqual(testCase,result.OracleRejectedReplacementGain,0, ...
        'AbsTol',0);
end

function testBatchToleranceAndPartialIndicators(testCase)
    result = ComputeCascadeBatchCounterfactual( ...
        1e12,[1,0.5],logical([1;0]),logical([1;0]),[0;1]);
    verifyEqual(testCase,result.BaselineBatchIGDp,1,'AbsTol',0);
    verifyEqual(testCase,result.OracleRejectedReplacementGain,0.5, ...
        'AbsTol',0);
    verifyTrue(testCase,result.HasReplacementOpportunity);

    verifyError(testCase,@() ComputeCascadeBatchCounterfactual( ...
        [1;1],ones(2,3),logical([1;1;0]),logical([1;1;0]), ...
        [1;NaN;0]),'AdaMaO:InvalidCascadeBatchInputs');
    verifyError(testCase,@() ComputeCascadeBatchCounterfactual( ...
        [1;1],ones(2,3),logical([1;0;1]),logical([1;1;0]), ...
        [1;0;0]),'AdaMaO:InvalidCascadeBatchInputs');
end

function testBatchCounterfactualBreaksDisplacedTiesByStableIndex(testCase)
    result = ComputeCascadeBatchCounterfactual( ...
        [2;2],[1 1 0;1 1 0],logical([1;1;0]), ...
        logical([1;1;0]),[0.2;0.2;1]);
    verifyEqual(testCase,result.DisplacedIndex,1);
end

function testShadowEvaluationPreservesOfficialFEAndGlobalRNG(testCase)
    stateBeforeTest = rng;
    testCase.addTeardown(@() rng(stateBeforeTest));
    Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',40, ...
        'maxRuntime',inf);
    Population = Problem.Initialization();
    referenceObj = Problem.GetOptimum(32);
    populationDec = Population.decs;
    candidateDec = min(populationDec(1:3,:) + 0.01,1);
    feBefore  = Problem.FE;
    rngBefore = rng;

    shadow = EvaluateCascadeShadow(Problem,candidateDec, ...
        Population.objs,Population.cons,referenceObj);

    verifyEqual(testCase,Problem.FE,feBefore);
    verifyEqual(testCase,rng,rngBefore);
    verifySize(testCase,shadow.CandidateObjectives,[3,3]);
    verifyEqual(testCase,size(shadow.CandidateConstraints,1),3);
    verifyEqual(testCase,shadow.FeasibleMask,true(3,1));
    verifyEqual(testCase,shadow.ReferenceCount,size(referenceObj,1));
    verifyEqual(testCase,shadow.ShadowEvaluationCount,3);
    verifySize(testCase,shadow.CandidateDistance, ...
        [size(referenceObj,1),3]);
    expectedFields = {'CandidateObjectives';'CandidateConstraints'; ...
        'FeasibleMask';'MarginalIGDp';'BaselineIGDp'; ...
        'BaselineDistance';'CandidateDistance';'ReferenceCount'; ...
        'ShadowEvaluationCount'};
    verifyEqual(testCase,sort(fieldnames(shadow)),sort(expectedFields));
    [marginal,baseline,used,baselineDistance,candidateDistance] = ...
        ComputeMarginalIGDp(Population.objs, ...
        shadow.CandidateObjectives,referenceObj);
    verifyEqual(testCase,shadow.MarginalIGDp,marginal,'AbsTol',0);
    verifyEqual(testCase,shadow.BaselineIGDp,baseline,'AbsTol',0);
    verifyEqual(testCase,shadow.ReferenceCount,used);
    verifyEqual(testCase,shadow.BaselineDistance,baselineDistance, ...
        'AbsTol',0);
    verifyEqual(testCase,shadow.CandidateDistance,candidateDistance, ...
        'AbsTol',0);
end

function testShadowEvaluationRejectsUnsupportedProblemsAndRuntimeCaps(testCase)
    unsupported = ZDT1('N',20,'D',3,'maxFE',40,'maxRuntime',inf);
    verifyError(testCase,@() EvaluateCascadeShadow(unsupported, ...
        zeros(1,3),[0 1],0,[0 1]), ...
        'AdaMaO:CascadeAuditUnsupportedProblem');

    capped = DTLZ2('N',20,'M',3,'D',3,'maxFE',40, ...
        'maxRuntime',1);
    verifyError(testCase,@() EvaluateCascadeShadow(capped, ...
        zeros(1,3),[1 1 1],0,[0 0 0]), ...
        'AdaMaO:CascadeAuditRuntimeCap');
end

function testCrossValidatedIndicatorReliabilityIsDeterministicAndRNGFree(testCase)
    stateBeforeTest = rng;
    testCase.addTeardown(@() rng(stateBeforeTest));
    x = linspace(-1,1,30)';
    decisions = [x,x.^2,cos(x)];
    fitness = x + 0.05*x.^2;
    rng(271828,'twister');
    before = rng;

    [tau1,oof1,fold1] = CrossValidateSDEIndicatorRanking( ...
        decisions,fitness,90210);
    afterFirst = rng;
    [tau2,oof2,fold2] = CrossValidateSDEIndicatorRanking( ...
        decisions,fitness,90210);
    afterSecond = rng;

    verifyEqual(testCase,afterFirst,before);
    verifyEqual(testCase,afterSecond,before);
    verifyEqual(testCase,tau1,tau2,'AbsTol',0);
    verifyEqual(testCase,oof1,oof2,'AbsTol',0);
    verifyEqual(testCase,fold1,fold2,'AbsTol',0);
    verifySize(testCase,oof1,[30,1]);
    verifySize(testCase,fold1,[30,1]);
    verifyTrue(testCase,all(isfinite(oof1)));
    verifyTrue(testCase,all(ismember(fold1,1:5)));
    verifyEqual(testCase,accumarray(fold1,1,[5,1]),6*ones(5,1));
    verifyTrue(testCase,isfinite(tau1));
    verifyGreaterThan(testCase,tau1,0.6);
    verifyTrue(testCase,isnan(CrossValidateSDEIndicatorRanking( ...
        decisions(1:9,:),fitness(1:9),1)));
    verifyTrue(testCase,isnan(CrossValidateSDEIndicatorRanking( ...
        decisions,ones(30,1),1)));
end

function testAuditRowsComputeExactBlindSpotAndRescueMetrics(testCase)
    [trace,shadow,counterfactual] = syntheticAuditFixture();
    schema = CascadeAuditSchema();

    [candidateRows,generationRow,primaryEligible] = ...
        BuildCascadeAuditRows(7,4,123,0.5, ...
        schema.codes.candidateMode.indicator,trace,shadow, ...
        counterfactual,0.4);

    verifyTrue(testCase,primaryEligible);
    verifySize(testCase,candidateRows, ...
        [6,numel(schema.columns.candidateRows)]);
    verifySize(testCase,generationRow, ...
        [1,numel(schema.columns.generationRows)]);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','RecallAtK')),0.5,'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','UsefulFNR')),0.4,'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','SingleCoverageRegret')),0.2, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','NormalizedBatchCoverageRegret')),0.25, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','RescueOpportunityRate')),0.5, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','DisagreementEnrichment')),1.5, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','CVKendall')),0.4,'AbsTol',0);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','MaxDisagreementReplacementGain')),0.2, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','MaxDisagreementSuccess')),1);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','OracleRejectedReplacementGain')),0.3, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','ReplacementCapture')),2/3, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','BaselineBatchUtility')),0.55, ...
        'AbsTol',1e-14);
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','IndicatorTopKMeanUtility')),0.65, ...
        'AbsTol',1e-14);

    relationPercentile = candidateRows(:,column(schema, ...
        'candidateRows','RelationPercentile'));
    indicatorPercentile = candidateRows(:,column(schema, ...
        'candidateRows','IndicatorPercentile'));
    positiveDisagreement = candidateRows(:,column(schema, ...
        'candidateRows','PositiveDisagreement'));
    maxDisagreement = candidateRows(:,column(schema, ...
        'candidateRows','MaxPositiveDisagreement'));
    nearestDistance = candidateRows(:,column(schema, ...
        'candidateRows','NearestSelectedDistance'));
    verifyEqual(testCase,relationPercentile, ...
        [1;0.8;0.6;0.4;0.2;0],'AbsTol',1e-14);
    verifyEqual(testCase,indicatorPercentile, ...
        [0.6;0.4;0.2;1;0.8;0],'AbsTol',1e-14);
    verifyEqual(testCase,positiveDisagreement, ...
        [-0.4;-0.4;-0.4;0.6;0.6;0],'AbsTol',1e-14);
    verifyEqual(testCase,maxDisagreement,[0;0;0;1;0;0]);
    verifyTrue(testCase,all(isnan(nearestDistance(1:3))));
    verifyEqual(testCase,nearestDistance(4:6), ...
        [0.5;0.1;sqrt(0.125)],'AbsTol',1e-14);
end

function testAuditRowsUseNaNForUndefinedDenominatorsAndEligibility(testCase)
    [trace,shadow,counterfactual] = syntheticAuditFixture();
    schema = CascadeAuditSchema();
    trace.IndicatorScore(:) = NaN;
    trace.OperationalIndicatorUsed = false;
    shadow.MarginalIGDp(:) = 0;
    counterfactual.ReplacementGain(:) = NaN;
    counterfactual.ReplacementGain(~trace.CoarseKept) = 0;
    counterfactual.NormalizedBatchCoverageRegret = NaN;
    counterfactual.HasBatchCoverageOpportunity = false;
    counterfactual.OracleRejectedReplacementGain = 0;
    counterfactual.HasReplacementOpportunity = false;

    [candidateRows,generationRow,indicatorEligible] = ...
        BuildCascadeAuditRows(1,1,20,0, ...
        schema.codes.candidateMode.indicator,trace,shadow, ...
        counterfactual,NaN);

    undefinedColumns = {'RecallAtK','UsefulFNR', ...
        'SingleCoverageRegret','DisagreementEnrichment', ...
        'MaxDisagreementReplacementGain','MaxDisagreementSuccess', ...
        'IndicatorTopKMeanUtility'};
    for i = 1:numel(undefinedColumns)
        verifyTrue(testCase,isnan(generationRow(column(schema, ...
            'generationRows',undefinedColumns{i}))));
    end
    verifyEqual(testCase,generationRow(column(schema, ...
        'generationRows','ReplacementCapture')),0);
    verifyTrue(testCase,all(isnan(candidateRows(:,column(schema, ...
        'candidateRows','IndicatorTopK')))));
    verifyFalse(testCase,indicatorEligible);

    trace.IndicatorScore = [4;3;2;6;5;1];
    trace.OperationalIndicatorUsed = true;
    [~,~,exploreEligible] = BuildCascadeAuditRows(1,1,20,0, ...
        schema.codes.candidateMode.explore,trace,shadow, ...
        counterfactual,NaN);
    [~,~,actualIndicatorEligible] = BuildCascadeAuditRows(1,1,20,0, ...
        schema.codes.candidateMode.indicator,trace,shadow, ...
        counterfactual,NaN);
    verifyFalse(testCase,exploreEligible);
    verifyTrue(testCase,actualIndicatorEligible);
end

function [trace,shadow,counterfactual] = syntheticAuditFixture()
    trace.CandidateDecisions = [ ...
        0.0 0.0; ...
        1.0 1.0; ...
        0.2 0.2; ...
        0.5 0.5; ...
        0.9 0.9; ...
        0.0 0.5];
    trace.Lower = [0 0];
    trace.Upper = [1 1];
    trace.RelationScore = [6;5;4;3;2;1];
    trace.IndicatorScore = [4;3;2;6;5;1];
    trace.CoarseKept = logical([1;1;1;0;0;0]);
    trace.SelectedMask = logical([1;1;0;0;0;0]);
    trace.OperationalIndicatorUsed = true;

    shadow.CandidateObjectives = zeros(6,2);
    shadow.CandidateConstraints = zeros(6,1);
    shadow.FeasibleMask = true(6,1);
    shadow.MarginalIGDp = [0.7;0.6;0.5;0.9;0.4;0];
    shadow.BaselineIGDp = 1;
    shadow.BaselineDistance = ones(2,1);
    shadow.CandidateDistance = zeros(2,6);
    shadow.ReferenceCount = 2;
    shadow.ShadowEvaluationCount = 6;

    counterfactual.BatchSize = 2;
    counterfactual.DisplacedIndex = 2;
    counterfactual.BaselineBatchIGDp = 0.45;
    counterfactual.BaselineBatchUtility = 0.55;
    counterfactual.ReplacementGain = [NaN;NaN;NaN;0.2;-0.1;0.3];
    counterfactual.GreedyAllIndices = [4;1];
    counterfactual.GreedyCoarseIndices = [1;2];
    counterfactual.GreedyAllUtility = 0.8;
    counterfactual.GreedyCoarseUtility = 0.6;
    counterfactual.NormalizedBatchCoverageRegret = 0.25;
    counterfactual.HasBatchCoverageOpportunity = true;
    counterfactual.OracleRejectedReplacementGain = 0.3;
    counterfactual.OracleRejectedIndex = 6;
    counterfactual.HasReplacementOpportunity = true;
end

function index = column(schema,tableName,columnName)
    index = find(strcmp(schema.columns.(tableName),columnName),1);
end
