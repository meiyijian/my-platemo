function tests = test_REMO_new2_AdaMaO_ConfidenceProbe
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

function testFrozenUniformMixFilesKeepTheirGitBlobs(testCase)
    files = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix.m'; ...
        'REMO_new2_AdaMaO_SDEOnly_ModeBase.m'; ...
        fullfile('private','HybridPBI_Classification.m'); ...
        fullfile('private','GetOutput_PBI.m'); ...
        fullfile('private','AdaMaOSelection.m'); ...
        fullfile('private','RefSelect.m')};
    expected = { ...
        '523deb264424909d84334bdeacf81377352eca8a'; ...
        '411a828ae68111e4ede67709386832624d4c38a4'; ...
        '342658c826e2f1f96937f1d300896b14331d2e2d'; ...
        'de30b2e915908e6d205134168a0cf87894a97cb9'; ...
        'b2483d050e91586356871d56e4bbb6ca4cc0aabd'; ...
        '241e8940b34b1c1c8cdc092d1db3cecf9407bb86'};

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
            sprintf('Frozen UniformMix file changed: %s',files{i}));
    end
end

function testProbeProducesCompleteSmokeAudit(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    [Algorithm,Problem] = makeSmokeRun( ...
        'REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe');

    rng(9001,'twister');
    Algorithm.Solve(Problem);

    verifyEqual(testCase,Problem.FE,36);
    verifyNotEmpty(testCase,Algorithm.result);
    finalArchive = finalResultPopulation(Algorithm);
    verifyEqual(testCase,numel(finalArchive),36);
    verifyTrue(testCase,all(arrayfun(@(solution) ...
        ~isempty(solution.add),finalArchive)));
    evalIDs = finalArchive.adds;
    verifyEqual(testCase,sort(evalIDs(:)),(1:36)');
    verifyEqual(testCase,numel(unique(evalIDs)),36);
    verifyTrue(testCase,all(evalIDs > 0 & evalIDs == floor(evalIDs)));

    verifyTrue(testCase,isfield(Algorithm.metric,'confidenceProbe'));
    probe = Algorithm.metric.confidenceProbe;
    schema = SDEConfidenceProbeSchema();
    verifyEqual(testCase,probe.version,schema.version);
    verifyEqual(testCase,probe.columns,schema.columns);
    tableNames = fieldnames(schema.columns);
    for i = 1:numel(tableNames)
        name = tableNames{i};
        verifyNotEmpty(testCase,probe.(name), ...
            sprintf('Probe table is empty: %s',name));
        verifyEqual(testCase,size(probe.(name),2), ...
            numel(schema.columns.(name)));
    end

    relationColumn = column(schema,'solutionRows','RelationMode');
    candidateColumn = column(schema,'solutionRows','CandidateMode');
    verifyEqual(testCase,unique(probe.solutionRows(:,relationColumn)), ...
        schema.codes.relationMode.curriculum);
    verifyTrue(testCase,all(ismember( ...
        probe.solutionRows(:,candidateColumn), ...
        [schema.codes.candidateMode.explore, ...
        schema.codes.candidateMode.indicator])));
end

function testProbeMatchesUniformMixTrajectoryExactly(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    [warmAlgorithm,warmProblem] = makeWarmupRun();
    rng(19001,'twister');
    warmAlgorithm.Solve(warmProblem);

    [probeAlgorithm,probeProblem] = makeMultiGenerationRun( ...
        'REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe');
    [baseAlgorithm,baseProblem] = makeMultiGenerationRun( ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix');

    rng(9001,'twister');
    probeAlgorithm.Solve(probeProblem);
    probeRNG = rng;
    rng(9001,'twister');
    baseAlgorithm.Solve(baseProblem);
    baseRNG = rng;

    probeArchive = finalResultPopulation(probeAlgorithm);
    baseArchive = finalResultPopulation(baseAlgorithm);
    probeTrajectory = sortrows([probeArchive.decs,probeArchive.objs]);
    baseTrajectory = sortrows([baseArchive.decs,baseArchive.objs]);
    verifyEqual(testCase,probeTrajectory,baseTrajectory,'AbsTol',0);
    verifyEqual(testCase,probeProblem.FE,baseProblem.FE);
    verifyEqual(testCase,probeProblem.FE,35);
    verifyEqual(testCase,probeRNG,baseRNG);

    probe = probeAlgorithm.metric.confidenceProbe;
    schema = SDEConfidenceProbeSchema();
    tableNames = fieldnames(schema.columns);
    for i = 1:numel(tableNames)
        name = tableNames{i};
        generation = probe.(name)(:,column(schema,name,'Generation'));
        verifyGreaterThanOrEqual(testCase,max(generation),3);
    end

    h3Columns = { ...
        'solutionRows',{'SurviveH3'}; ...
        'pbiPairRows',{'LeftSurviveH3','RightSurviveH3'}; ...
        'networkPairRows',{'CandidateSurviveH3'}; ...
        'candidateRows',{'SurviveH3'}};
    for i = 1:size(h3Columns,1)
        name = h3Columns{i,1};
        rows = probe.(name);
        generation = rows(:,column(schema,name,'Generation'));
        verifyObservedBinaryColumns( ...
            testCase,rows,generation == 1,schema,name,h3Columns{i,2});
    end

    finalColumns = { ...
        'solutionRows',{'FinalND'}; ...
        'pbiPairRows',{'LeftFinalND','RightFinalND'}; ...
        'networkPairRows',{'CandidateFinalND'}; ...
        'candidateRows',{'FinalND'}};
    for i = 1:size(finalColumns,1)
        name = finalColumns{i,1};
        rows = probe.(name);
        verifyObservedBinaryColumns( ...
            testCase,rows,true(size(rows,1),1), ...
            schema,name,finalColumns{i,2});
    end
end

function testProbeSourceKeepsSingleOperationalCalls(testCase)
    sourceFile = fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe.m');
    source = fileread(sourceFile);

    verifyEqual(testCase,numel(regexp(source, ...
        'HybridPBI_Classification\s*\(','match')),1);
    verifyEqual(testCase,numel(regexp(source, ...
        'Problem\.Evaluation\s*\(','match')),2);
    verifyEqual(testCase,numel(regexp(source,'rand\s*\(','match')),1);
    verifyTrue(testCase,contains(source,"policy = 'uniform_mix'"));

    localFunctions = {'RuntimeDiagnostics','NormalizeObjectives', ...
        'GetRelationPairs_curriculum','KeepMostConfident', ...
        'TrainRelationModel'};
    for i = 1:numel(localFunctions)
        pattern = ['function[\s\S]*?\<',localFunctions{i},'\>'];
        verifyNotEmpty(testCase,regexp(source,pattern,'once'));
    end
end

function [Algorithm,Problem] = makeSmokeRun(name)
    parameters = {[],1,[],[],[],[],[],[],[],[]};
    Algorithm = feval(name,'parameter',parameters,'save',0, ...
        'outputFcn',@silentOutput,'run',1);
    Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',36);
end

function [Algorithm,Problem] = makeMultiGenerationRun(name)
    parameters = {[],1,[],[],[],1,1,[],[],[]};
    Algorithm = feval(name,'parameter',parameters,'save',0, ...
        'outputFcn',@silentOutput,'run',1);
    Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',35);
end

function [Algorithm,Problem] = makeWarmupRun()
    parameters = {[],1,[],[],[],1,1,[],[],[]};
    Algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix( ...
        'parameter',parameters,'save',0, ...
        'outputFcn',@silentOutput,'run',1);
    Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',33);
end

function Population = finalResultPopulation(Algorithm)
    last = find(~cellfun(@isempty,Algorithm.result(:,2)),1,'last');
    Population = Algorithm.result{last,2};
end

function verifyObservedBinaryColumns( ...
    testCase,rows,rowMask,schema,tableName,columnNames)
    verifyTrue(testCase,any(rowMask));
    for i = 1:numel(columnNames)
        values = rows(rowMask,column(schema,tableName,columnNames{i}));
        verifyFalse(testCase,any(isnan(values)));
        verifyTrue(testCase,all(ismember(values,[0 1])));
    end
end

function index = column(schema,tableName,columnName)
    index = find(strcmp(schema.columns.(tableName),columnName),1);
end

function silentOutput(varargin)
end
