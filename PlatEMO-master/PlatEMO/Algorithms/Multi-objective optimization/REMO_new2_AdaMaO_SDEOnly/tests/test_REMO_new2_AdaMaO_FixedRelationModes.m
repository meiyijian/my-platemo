function tests = test_REMO_new2_AdaMaO_FixedRelationModes
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

function testThreeFixedModeEntriesAreDiscoverableAndMapped(testCase)
    baseName = ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase';
    entries = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted','weighted'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum','curriculum'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','conservative'};

    for i = 1:size(entries,1)
        name = entries{i,1};
        expectedFile = fullfile(testCase.TestData.AlgorithmDir,[name,'.m']);
        verifyEqual(testCase,which(name),expectedFile);
        if ~isfile(expectedFile)
            continue;
        end
        source = fileread(expectedFile);
        verifyTrue(testCase,contains(source,['< ',baseName]));
        verifyTrue(testCase,contains(source, ...
            sprintf("mode = '%s';",entries{i,2})));
    end
end

function testSharedRuntimeFixesUniformMixAndDelegatesRelationMode(testCase)
    file = fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m');
    verifyTrue(testCase,isfile(file));
    if ~isfile(file)
        return;
    end
    source = fileread(file);

    verifyTrue(testCase,contains(source, ...
        "policy = 'uniform_mix';"));
    verifyTrue(testCase,contains(source, ...
        'relation_mode = Algorithm.relationPairMode('));
    verifyTrue(testCase,contains(source, ...
        "case 'weighted'"));
    verifyTrue(testCase,contains(source, ...
        "case 'curriculum'"));
    verifyTrue(testCase,contains(source, ...
        'GetRelationPairs(Input,Catalog)'));
    verifyTrue(testCase,contains(source, ...
        "strcmp(relation_mode,'weighted')"));
    verifyFalse(testCase,contains(source, ...
        'if prev_p_err > tau_err'));
end
