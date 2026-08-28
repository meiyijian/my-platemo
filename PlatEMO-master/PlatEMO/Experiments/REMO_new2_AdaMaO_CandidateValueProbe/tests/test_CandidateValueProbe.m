function tests = test_CandidateValueProbe()
%TEST_CANDIDATEVALUEPROBE Unit tests for the candidate-value probe.
%   Run with: runtests('tests/test_CandidateValueProbe.m')
%
%   These tests cover the parts that would silently corrupt a conclusion:
%   arm routing, seed pairing, the survival metric's identity tracking, the
%   oracle's FE neutrality, and the CSV contract.

    tests = functiontests(localfunctions());
end

function setupOnce(testCase)
    % functiontests treats EVERY local function as a test, so path setup is
    % done inline here rather than in a helper local function.
    here = fileparts(mfilename('fullpath'));
    experimentDirectory = fileparts(here);
    originalPath = path();
    testCase.TestData.Cleanup = onCleanup(@() path(originalPath));
    addpath(experimentDirectory);
    addpath(fullfile(experimentDirectory, 'algorithms'));

    % PlatEMO itself must be on the path here, not just the probe folders.
    % CVP_CandidateProbe subclasses ALGORITHM, so constructing it (which the
    % parameter-validation tests do) fails with MATLAB:class:InvalidSuperClass
    % unless PlatEMO resolves. Without this the two *Rejected tests only pass
    % when some earlier test has already called CVPSetupPaths as a side
    % effect, which makes them order-dependent.
    %
    % The second output is an onCleanup handle that restores the path as soon
    % as it is destroyed, so it has to be kept alive for the whole file.
    [~, testCase.TestData.PlatemoPathCleanup] = CVPSetupPaths();

    testCase.TestData.ResultRoot = fullfile(tempdir(), ...
        sprintf('cvp_test_%s', char(datetime('now', 'Format', 'yyyyMMddHHmmssSSS'))));
end

function teardownOnce(testCase)
    if isfolder(testCase.TestData.ResultRoot)
        rmdir(testCase.TestData.ResultRoot, 's');
    end
end

%% ---------------- protocol and catalog ----------------
function testCatalogHasFiveDistinctArms(testCase)
    catalog = CVPArmCatalog();
    verifyEqual(testCase, height(catalog), 5);
    verifyEqual(testCase, numel(unique(catalog.Arm)), 5);
    verifyEqual(testCase, sort(catalog.ArmID)', 0:4);
end

function testOnlyV0UsesLastRoundPool(testCase)
    catalog = CVPArmCatalog();
    lastRound = catalog.Arm(catalog.Pool == "last_round");
    verifyEqual(testCase, lastRound, "V0_REMO_RULE");
    verifyEqual(testCase, nnz(catalog.Pool == "accumulated"), 4);
end

function testSeedIsSharedAcrossArms(testCase)
    config = CVPProtocol("formal");
    jobs = config.Jobs;
    keys = unique([jobs.PairedKey]);
    sampleKey = keys(1);
    block = jobs(ismember([jobs.PairedKey], sampleKey));
    verifyEqual(testCase, numel(block), 5, ...
        'Each paired key must cover all five arms.');
    verifyEqual(testCase, numel(unique([block.Seed])), 1, ...
        'All arms of a paired key must share one seed.');
    verifyEqual(testCase, numel(unique([block.ArmID])), 5);
end

function testFormalProtocolJobCount(testCase)
    config = CVPProtocol("formal");
    % 4 problems x 2 objective counts x 10 runs x 5 arms
    verifyEqual(testCase, numel(config.Jobs), 400);
end

function testResultPathSeparatesArms(testCase)
    config = CVPProtocol("formal");
    jobs = config.Jobs;
    pathA = CVPResultPath(tempdir(), "formal", jobs(1));
    pathB = CVPResultPath(tempdir(), "formal", jobs(2));
    verifyNotEqual(testCase, pathA, pathB, ...
        'Different arms must not share a result path.');
end

%% ---------------- parameter validation ----------------
function testInvalidArmRejected(testCase)
    verifyError(testCase, @() cvpSolveProbe(9, 400), "CVP:InvalidParameter");
end

function testOraclePoolLimitBelowBatchRejected(testCase)
    verifyError(testCase, @() cvpSolveProbe(4, 3), "CVP:InvalidParameter");
end

%% ---------------- end-to-end smoke ----------------
function testSmokeProfileProducesValidRuns(testCase)
    resultRoot = testCase.TestData.ResultRoot;
    manifest = run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    verifyEqual(testCase, height(manifest), 5, 'Smoke covers five arms.');
    verifyTrue(testCase, all(manifest.Status == "completed"), ...
        sprintf('Statuses: %s', strjoin(manifest.Status', ', ')));

    config = CVPProtocol("smoke");
    for index = 1:numel(config.Jobs)
        filePath = CVPResultPath(resultRoot, "smoke", config.Jobs(index));
        [isValid, report] = CVPValidateRunFile(filePath, "smoke");
        verifyTrue(testCase, isValid, report.Detail);
    end
end

function testRunIsIdempotent(testCase)
    resultRoot = testCase.TestData.ResultRoot;
    run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    manifest = run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    verifyTrue(testCase, all(manifest.Status == "skipped"), ...
        'A second run must skip every valid existing result.');
end

function testFEBudgetRespected(testCase)
    resultRoot = testCase.TestData.ResultRoot;
    run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    config = CVPProtocol("smoke");
    for index = 1:numel(config.Jobs)
        filePath = CVPResultPath(resultRoot, "smoke", config.Jobs(index));
        stored = load(filePath, "metadata");
        verifyLessThanOrEqual(testCase, stored.metadata.CompletedFE, ...
            stored.metadata.MaxFE, ...
            'The oracle must not consume the FE budget.');
    end
end

function testSurvivalRateInUnitInterval(testCase)
    resultRoot = testCase.TestData.ResultRoot;
    run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    config = CVPProtocol("smoke");
    for index = 1:numel(config.Jobs)
        filePath = CVPResultPath(resultRoot, "smoke", config.Jobs(index));
        stored = load(filePath, "generations");
        rates = [stored.generations.SurvivalRate];
        rates = rates(isfinite(rates));
        verifyTrue(testCase, all(rates >= 0 & rates <= 1));
    end
end

function testOracleHitRateInUnitInterval(testCase)
    resultRoot = testCase.TestData.ResultRoot;
    run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    config = CVPProtocol("smoke");
    sawValidOracle = false;
    for index = 1:numel(config.Jobs)
        filePath = CVPResultPath(resultRoot, "smoke", config.Jobs(index));
        stored = load(filePath, "generations");
        valid = [stored.generations.OracleValid];
        sawValidOracle = sawValidOracle || any(valid);
        rates = [stored.generations(valid).OracleHitRate];
        verifyTrue(testCase, all(rates >= 0 & rates <= 1));
    end
    verifyTrue(testCase, sawValidOracle, ...
        'At least one generation must produce a valid oracle record.');
end

function testAnalysisWritesEveryCsv(testCase)
    resultRoot = testCase.TestData.ResultRoot;
    run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    report = analyze_CandidateValueProbe("smoke", ...
        "ResultRoot", resultRoot, "Quiet", true);

    expected = ["runs.csv", "arm_summary.csv", "arm_overall.csv", ...
        "stage_profile.csv", "generations.csv", "diagnostics.csv"];
    for name = expected
        filePath = fullfile(char(report.CsvDirectory), char(name));
        verifyTrue(testCase, isfile(filePath), ...
            sprintf('Missing CSV: %s', name));
    end
    verifyEqual(testCase, height(report.Runs), 5);
    verifyEqual(testCase, numel(report.MissingJobs), 0);
end

function testHolmAdjustmentIsMonotone(testCase)
    resultRoot = testCase.TestData.ResultRoot;
    run_CandidateValueProbe("smoke", "ResultRoot", resultRoot);
    report = analyze_CandidateValueProbe("smoke", ...
        "ResultRoot", resultRoot, "Quiet", true);
    if isempty(report.Contrasts)
        return;
    end
    raw = report.Contrasts.PValue;
    adjusted = report.Contrasts.PValueHolm;
    both = isfinite(raw) & isfinite(adjusted);
    verifyTrue(testCase, all(adjusted(both) >= raw(both) - 1e-12), ...
        'Holm-adjusted p must never fall below the raw p.');
end
