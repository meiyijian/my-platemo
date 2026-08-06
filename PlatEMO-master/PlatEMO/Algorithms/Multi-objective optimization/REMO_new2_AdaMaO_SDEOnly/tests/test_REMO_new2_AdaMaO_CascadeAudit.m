function tests = test_REMO_new2_AdaMaO_CascadeAudit
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

function testFrozenOperationalSourcesKeepTheirGitBlobs(testCase)
    files = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix.m'; ...
        'REMO_new2_AdaMaO_SDEOnly_ModeBase.m'; ...
        fullfile('private','HybridPBI_Classification.m'); ...
        fullfile('private','GetOutput_PBI.m'); ...
        fullfile('private','AdaMaOSelection.m'); ...
        fullfile('private','RefSelect.m'); ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m'};
    expected = { ...
        '523deb264424909d84334bdeacf81377352eca8a'; ...
        '411a828ae68111e4ede67709386832624d4c38a4'; ...
        '342658c826e2f1f96937f1d300896b14331d2e2d'; ...
        'de30b2e915908e6d205134168a0cf87894a97cb9'; ...
        'b2483d050e91586356871d56e4bbb6ca4cc0aabd'; ...
        '241e8940b34b1c1c8cdc092d1db3cecf9407bb86'; ...
        '15a22a6ada08b679e5a0810a4170518fcddcde95'; ...
        '02f1f019f0bf6f80c456d2c1fa4dae8763a3499f'};

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
            sprintf('Frozen operational file changed: %s',files{i}));
    end
end

function testAuditSelectorIsAReadOnlyOperationalCopy(testCase)
    selectorFile = fullfile(testCase.TestData.AlgorithmDir, ...
        'private','AdaMaOSelectionCascadeAudit.m');
    source = fileread(selectorFile);

    verifyEqual(testCase,numel(regexp(source, ...
        '\<OperatorGA\s*\(','match')),2);
    verifyEqual(testCase,numel(regexp(source, ...
        '\<switch\s+mode\>','match')),1);
    verifyEqual(testCase,numel(regexp(source, ...
        'function\s+\[Next,trace\]\s*=\s*AdaMaOSelectionCascadeAudit', ...
        'match')),1);
    forbidden = {'Problem.CalObj','Problem.CalCon','Problem.Evaluation', ...
        'rng(','rand('};
    for i = 1:numel(forbidden)
        verifyFalse(testCase,contains(source,forbidden{i}), ...
            sprintf('Selector trace contains forbidden token: %s', ...
            forbidden{i}));
    end
end

function testCascadeAuditProducesCompleteSmokeRows(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    [Algorithm,Problem] = makeAuditRun();

    rng(9001,'twister');
    Algorithm.Solve(Problem);

    verifyEqual(testCase,Problem.FE,35);
    verifyTrue(testCase,isfield(Algorithm.metric,'cascadeAudit'));
    audit = Algorithm.metric.cascadeAudit;
    schema = CascadeAuditSchema();
    verifyEqual(testCase,audit.version,schema.version);
    verifyEqual(testCase,audit.columns,schema.columns);
    verifyNotEmpty(testCase,audit.candidateRows);
    verifyNotEmpty(testCase,audit.generationRows);
    verifySize(testCase,audit.candidateRows, ...
        [size(audit.candidateRows,1), ...
        numel(schema.columns.candidateRows)]);
    verifySize(testCase,audit.generationRows, ...
        [size(audit.generationRows,1), ...
        numel(schema.columns.generationRows)]);

    relation = audit.candidateRows(:,column(schema, ...
        'candidateRows','RelationScore'));
    marginal = audit.candidateRows(:,column(schema, ...
        'candidateRows','MarginalIGDp'));
    replacement = audit.candidateRows(:,column(schema, ...
        'candidateRows','ReplacementGain'));
    verifyTrue(testCase,all(isfinite(relation)));
    verifyTrue(testCase,all(isfinite(marginal)));
    verifyTrue(testCase,any(isfinite(replacement)));

    mode = audit.generationRows(:,column(schema, ...
        'generationRows','CandidateMode'));
    operational = audit.generationRows(:,column(schema, ...
        'generationRows','OperationalIndicatorUsed'));
    verifyEqual(testCase,mode, ...
        repmat(schema.codes.candidateMode.indicator,size(mode)));
    verifyEqual(testCase,operational,ones(size(operational)));

    shadowPerGeneration = audit.generationRows(:,column(schema, ...
        'generationRows','ShadowEvaluationCount'));
    auditSeconds = audit.generationRows(:,column(schema, ...
        'generationRows','AuditSeconds'));
    verifyGreaterThan(testCase,audit.totalShadowEvaluations,0);
    verifyEqual(testCase,audit.totalShadowEvaluations, ...
        sum(shadowPerGeneration));
    verifyGreaterThanOrEqual(testCase,audit.totalAuditSeconds,0);
    verifyEqual(testCase,audit.totalAuditSeconds,sum(auditSeconds), ...
        'AbsTol',1e-12);

    candidateGeneration = audit.candidateRows(:,column(schema, ...
        'candidateRows','Generation'));
    selected = audit.candidateRows(:,column(schema, ...
        'candidateRows','BaselineSelected'));
    generationID = audit.generationRows(:,column(schema, ...
        'generationRows','Generation'));
    batchSize = audit.generationRows(:,column(schema, ...
        'generationRows','BatchSize'));
    for i = 1:numel(generationID)
        verifyEqual(testCase,sum(selected(candidateGeneration == ...
            generationID(i))),batchSize(i));
    end
    verifyLessThanOrEqual(testCase,sum(selected),Problem.FE-(11*Problem.D-1));
end

function testCascadeAuditMatchesOriginalTrajectoryFEAndRNGExactly(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    [warmAlgorithm,warmProblem] = makeWarmupRun();
    rng(19001,'twister');
    warmAlgorithm.Solve(warmProblem);

    [auditAlgorithm,auditProblem] = makeAuditRun();
    [baseAlgorithm,baseProblem] = makeOriginalRun();

    rng(9001,'twister');
    auditAlgorithm.Solve(auditProblem);
    auditRNG = rng;
    rng(9001,'twister');
    baseAlgorithm.Solve(baseProblem);
    baseRNG = rng;

    auditArchive = finalResultPopulation(auditAlgorithm);
    baseArchive = finalResultPopulation(baseAlgorithm);
    auditTrajectory = sortrows([auditArchive.decs, ...
        auditArchive.objs,auditArchive.cons]);
    baseTrajectory = sortrows([baseArchive.decs, ...
        baseArchive.objs,baseArchive.cons]);
    verifyEqual(testCase,auditTrajectory,baseTrajectory,'AbsTol',0);
    verifyEqual(testCase,auditProblem.FE,baseProblem.FE);
    verifyEqual(testCase,auditProblem.FE,35);
    verifyEqual(testCase,auditRNG,baseRNG);
end

function testAuditAlgorithmRejectsUnsupportedOrPerturbableProblems(testCase)
    parameters = auditParameters();
    Algorithm = REMO_new2_AdaMaO_SDEOnly_CascadeAudit( ...
        'parameter',parameters,'save',0,'outputFcn',@silentOutput, ...
        'run',1);
    unsupported = ZDT1('N',20,'D',3,'maxFE',35,'maxRuntime',inf);
    verifyError(testCase,@() Algorithm.Solve(unsupported), ...
        'AdaMaO:CascadeAuditUnsupportedProblem');

    Algorithm = REMO_new2_AdaMaO_SDEOnly_CascadeAudit( ...
        'parameter',parameters,'save',0,'outputFcn',@silentOutput, ...
        'run',1);
    capped = DTLZ2('N',20,'M',3,'D',3,'maxFE',35,'maxRuntime',1);
    verifyError(testCase,@() Algorithm.Solve(capped), ...
        'AdaMaO:CascadeAuditRuntimeCap');
end

function [Algorithm,Problem] = makeAuditRun()
    Algorithm = REMO_new2_AdaMaO_SDEOnly_CascadeAudit( ...
        'parameter',auditParameters(),'save',0, ...
        'outputFcn',@silentOutput,'run',1);
    Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',35, ...
        'maxRuntime',inf);
end

function [Algorithm,Problem] = makeOriginalRun()
    parameters = auditParameters();
    Algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Original( ...
        'parameter',parameters(1:10),'save',0, ...
        'outputFcn',@silentOutput,'run',1);
    Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',35);
end

function [Algorithm,Problem] = makeWarmupRun()
    parameters = auditParameters();
    Algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Original( ...
        'parameter',parameters(1:10),'save',0, ...
        'outputFcn',@silentOutput,'run',1);
    Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',33);
end

function parameters = auditParameters()
    parameters = {[],1,[],[],[],1,1,[],[],[],0,32,1};
end

function Population = finalResultPopulation(Algorithm)
    last = find(~cellfun(@isempty,Algorithm.result(:,2)),1,'last');
    Population = Algorithm.result{last,2};
end

function index = column(schema,tableName,columnName)
    index = find(strcmp(schema.columns.(tableName),columnName),1);
end

function silentOutput(varargin)
end
