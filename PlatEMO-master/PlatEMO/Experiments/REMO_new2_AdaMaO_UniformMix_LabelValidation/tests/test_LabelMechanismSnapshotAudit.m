function tests = test_LabelMechanismSnapshotAudit
%test_LabelMechanismSnapshotAudit Equivalence and contract tests (Stage 1).
%   Tests:
%     - protocol seeds (11001 / 42005)
%     - WFG3 actual dimension == 31
%     - schema version == 1
%     - Hybrid audit == frozen algorithm on smoke (DTLZ2 M3 D3)
%     - Hybrid audit == frozen algorithm on pilot DTLZ2 M10 D30 run1
%   When all equivalence tests pass, writes
%     results/stage1/equivalence_passed.txt  (content 'PASS')
%   which the analyzer requires before emitting PASS decisions.

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile = mfilename('fullpath');
    testsDir = fileparts(testFile);
    expDir   = fileparts(testsDir);
    platemoRoot = fileparts(fileparts(fileparts(expDir)));
    addpath(genpath(platemoRoot));
    rehash;
    testCase.TestData.expDir = expDir;
    testCase.TestData.platemoRoot = platemoRoot;
    % Clean previous equivalence flags
    flagRoot = fullfile(expDir,'results','stage1');
    if exist(flagRoot,'dir')
        for f = {'equivalence_smoke.txt','equivalence_pilot.txt', ...
                 'equivalence_passed.txt'}
            p = fullfile(flagRoot,f{1});
            if isfile(p), delete(p); end
        end
    end
end

function tearDownOnce(testCase)
    % Write PASS flag only if both smoke and pilot equivalence flags exist.
    expDir  = testCase.TestData.expDir;
    flagDir = fullfile(expDir,'results','stage1');
    if ~exist(flagDir,'dir'), mkdir(flagDir); end
    smokeOk = isfile(fullfile(flagDir,'equivalence_smoke.txt'));
    pilotOk = isfile(fullfile(flagDir,'equivalence_pilot.txt'));
    if smokeOk && pilotOk
        fid = fopen(fullfile(flagDir,'equivalence_passed.txt'),'w');
        fprintf(fid,'PASS\n');
        fclose(fid);
    end
end

%% ============ contract tests ============

function testStableSeedFormula(testCase)
    verifyEqual(testCase,LabelValidationStableSeed(1,10,1),11001);
    verifyEqual(testCase,LabelValidationStableSeed(4,20,5),42005);
end

function testWFG3ActualDimension(testCase)
    p10 = WFG3('N',100,'M',10,'D',30,'maxFE',500);
    verifyEqual(testCase,p10.D,31);
    p20 = WFG3('N',100,'M',20,'D',30,'maxFE',500);
    verifyEqual(testCase,p20.D,31);
end

function testSchemaVersion(testCase)
    verifyEqual(testCase,LabelValidationSchema().version,1);
end

function testProtocolJobCount(testCase)
    cfgSmoke = LabelValidationProtocol('smoke');
    verifyEqual(testCase,numel(cfgSmoke.jobs),2);   % 2 behaviors
    cfgPilot = LabelValidationProtocol('pilot');
    verifyEqual(testCase,numel(cfgPilot.jobs),4);   % 2 runs x 2 behaviors
    cfgScreen = LabelValidationProtocol('screening');
    verifyEqual(testCase,numel(cfgScreen.jobs),100); % 5x2x5x2
end

%% ============ equivalence tests ============

function testSmokeHybridEquivalence(testCase)
    eq = runEquivalenceComparison('DTLZ2',3,3,20,35,1,1);
    verifyTrue(testCase,eq.matched,eq.message);
    verifyEqual(testCase,eq.dFE,0,['FE mismatch: ',eq.message]);
    if eq.matched
        expDir  = testCase.TestData.expDir;
        flagDir = fullfile(expDir,'results','stage1');
        if ~exist(flagDir,'dir'), mkdir(flagDir); end
        fid = fopen(fullfile(flagDir,'equivalence_smoke.txt'),'w');
        fprintf(fid,'PASS\n');
        fclose(fid);
    end
end

function testPilotHybridEquivalence(testCase)
    eq = runEquivalenceComparison('DTLZ2',10,30,100,300,300,1);
    verifyTrue(testCase,eq.matched,eq.message);
    verifyEqual(testCase,eq.dFE,0,['FE mismatch: ',eq.message]);
    if eq.matched
        expDir  = testCase.TestData.expDir;
        flagDir = fullfile(expDir,'results','stage1');
        if ~exist(flagDir,'dir'), mkdir(flagDir); end
        fid = fopen(fullfile(flagDir,'equivalence_pilot.txt'),'w');
        fprintf(fid,'PASS\n');
        fclose(fid);
    end
end
