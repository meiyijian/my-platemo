classdef GoodGroupPrecisionTest < matlab.unittest.TestCase
%GOODGROUPPRECISIONTEST Contract, metric, persistence, and smoke tests.

    properties (SetAccess = private)
        ExperimentDirectory
        ResultRoot
        SmokeResultFile
        SmokeData
    end

    methods (TestClassSetup)
        function prepareExperiment(testCase)
            testFile = mfilename("fullpath");
            testsDirectory = fileparts(testFile);
            testCase.ExperimentDirectory = fileparts(testsDirectory);
            repositoryDirectory = fileparts(fileparts(fileparts( ...
                testCase.ExperimentDirectory)));
            pathFixture = matlab.unittest.fixtures.PathFixture( ...
                repositoryDirectory, "IncludingSubfolders", true);
            testCase.applyFixture(pathFixture);

            testCase.ResultRoot = tempname();
            mkdir(testCase.ResultRoot);
            testCase.addTeardown(@() GoodGroupPrecisionTest.removeTestRoot( ...
                testCase.ResultRoot));

            manifest = run_GoodGroupPrecision("smoke", ...
                "ResultRoot", testCase.ResultRoot);
            testCase.verifyEqual(manifest.Status, "completed");
            testCase.SmokeResultFile = char(manifest.File(1));
            testCase.SmokeData = load(testCase.SmokeResultFile);
        end
    end

    methods (Test)
        function formalProtocolIsExact(testCase)
            config = GGPProtocol("formal");
            jobs = config.Jobs;

            testCase.verifyNumElements(jobs, 250);
            testCase.verifyEqual(unique([jobs.M]), [10, 20]);
            testCase.verifyEqual(unique([jobs.RequestedD]), 30);
            testCase.verifyEqual(unique([jobs.MaxFE]), 500);
            testCase.verifyEqual(unique([jobs.Run]), 1:25);
            testCase.verifyEqual(numel(unique([jobs.Seed])), 250);
            testCase.verifyEqual(unique([jobs.Problem]), ...
                ["DTLZ2", "DTLZ4", "DTLZ7", "WFG3", "WFG7"]);
            testCase.verifyEqual(GGPStableSeed(1, 10, 1), 11001);
            testCase.verifyEqual(GGPStableSeed(4, 20, 25), 42025);
        end

        function wfg3DimensionIsExplicit(testCase)
            problem = WFG3('N', 100, 'M', 10, 'D', 30, 'maxFE', 500);
            testCase.verifyEqual(problem.D, 31);
        end

        function compatibilityAliasUsesAuditedSearch(testCase)
            algorithm = REMO_GGP('save', 0);
            testCase.verifyTrue(isa(algorithm, 'LVUniformMixAudit_Hybrid'));
        end

        function stageBoundariesMatchClaim(testCase)
            actual = arrayfun(@GGPStageBin, [0, 0.25, 0.25001, 0.50, ...
                0.50001, 0.75, 0.75001, 1]);
            expected = ["S1_[0,0.25]", "S1_[0,0.25]", ...
                "S2_(0.25,0.50]", "S2_(0.25,0.50]", ...
                "S3_(0.50,0.75]", "S3_(0.50,0.75]", ...
                "S4_(0.75,1.00]", "S4_(0.75,1.00]"];
            testCase.verifyEqual(actual, expected);
        end

        function binaryMetricsAreCorrect(testCase)
            metrics = GGPBinaryMetrics( ...
                logical([1, 0, 1, 0]), logical([1, 1, 0, 0]), [4, 3, 2, 1]);

            testCase.verifyEqual(metrics.Precision, 0.5, "AbsTol", 1e-12);
            testCase.verifyEqual(metrics.Recall, 0.5, "AbsTol", 1e-12);
            testCase.verifyEqual(metrics.Chance, 0.5, "AbsTol", 1e-12);
            testCase.verifyEqual(metrics.Lift, 1, "AbsTol", 1e-12);
            testCase.verifyEqual(metrics.AUC, 1, "AbsTol", 1e-12);
        end

        function aucHandlesTiesAndSingleClass(testCase)
            tied = GGPBinaryMetrics(logical([1, 0, 0, 0]), ...
                logical([1, 0, 1, 0]), [1, 1, 0, 0]);
            singleClass = GGPBinaryMetrics(logical([1, 0, 0]), ...
                true(1, 3), [3, 2, 1]);

            testCase.verifyEqual(tied.AUC, 0.5, "AbsTol", 1e-12);
            testCase.verifyTrue(isnan(singleClass.AUC));
        end

        function censoredTruthStaysMissing(testCase)
            metrics = GGPBinaryMetrics(logical([1, 0, 1]), ...
                NaN(1, 3), [3, 2, 1]);

            testCase.verifyTrue(metrics.Censored);
            testCase.verifyTrue(isnan(metrics.Precision));
            testCase.verifyTrue(isnan(metrics.AUC));
        end

        function holmAndPairedEffectAreCorrect(testCase)
            adjusted = GGPHolmAdjust([0.01, 0.04, 0.03]);
            comparison = GGPComparePaired([0.8, 0.7, 0.9], [0.6, 0.7, 0.8]);

            testCase.verifyEqual(adjusted, [0.03, 0.06, 0.06], "AbsTol", 1e-12);
            testCase.verifyEqual(comparison.NumberOfPairs, 3);
            testCase.verifyEqual(comparison.PairedWinProbability, 5/6, ...
                "AbsTol", 1e-12);
            testCase.verifyGreaterThan(comparison.RankBiserial, 0);
        end

        function smokeFilePassesSchemaAndMetricRules(testCase)
            [isValid, report] = GGPValidateRunFile( ...
                testCase.SmokeResultFile, "smoke");
            metrics = testCase.SmokeData.checkpointMetrics;
            topRows = metrics.SelectionRule == "top25";
            nativeRows = metrics.SelectionRule == "native";

            testCase.verifyTrue(isValid, report.Detail);
            testCase.verifyEqual(report.Detail, "PASS");
            testCase.verifyTrue(all(metrics.SelectedCount(topRows) == ...
                ceil(0.25*metrics.PopulationSize(topRows))));
            testCase.verifyTrue(all(isnan(metrics.PrecisionAt25(nativeRows))));
            testCase.verifyTrue(all(isnan(metrics.NativePrecision(topRows))));
        end

        function validExistingRunIsNotOverwritten(testCase)
            before = dir(testCase.SmokeResultFile);
            manifest = run_GoodGroupPrecision("smoke", ...
                "ResultRoot", testCase.ResultRoot);
            after = dir(testCase.SmokeResultFile);

            testCase.verifyEqual(manifest.Status, "skipped");
            testCase.verifyEqual(after.bytes, before.bytes);
            testCase.verifyEqual(after.datenum, before.datenum);
        end

        function analysisUsesRunStageUnits(testCase)
            outputs = analyze_GoodGroupPrecision("smoke", ...
                "ResultRoot", testCase.ResultRoot);

            testCase.verifyNotEmpty(outputs.PerRunStage);
            testCase.verifyTrue(all(outputs.PerRunStage.Run == 1));
            testCase.verifyTrue(all(outputs.Coverage.Complete));
            testCase.verifyTrue(isfile(outputs.Paths.PairedComparisons));
            testCase.verifyTrue(isfile(outputs.Paths.NativeLabelSummary));
        end

        function auditedSearchMatchesFrozenSearch(testCase)
            frozen = GoodGroupPrecisionTest.runFrozenSmoke( ...
                testCase.SmokeData.metadata);
            audited = testCase.SmokeData.finalPopulation;
            frozenRows = sortrows([frozen.Obj, frozen.Dec]);
            auditedRows = sortrows([audited.Obj, audited.Dec]);

            testCase.verifyEqual(frozen.FE, testCase.SmokeData.metadata.CompletedFE);
            testCase.verifyEqual(auditedRows, frozenRows, "AbsTol", 1e-12);
        end
    end

    methods (Static, Access = private)
        function frozen = runFrozenSmoke(metadata)
            GoodGroupPrecisionTest.warmupLearningToolboxes();
            rng(metadata.Seed, "twister");
            problem = feval(char(metadata.Problem), ...
                'N', metadata.ProblemN, 'M', metadata.M, 'D', metadata.RequestedD, ...
                'maxFE', metadata.MaxFE, 'maxRuntime', inf);
            parameters = {metadata.Gmax, metadata.PMix, metadata.RGood, ...
                metadata.QKeep, metadata.Lambda0, metadata.NMin, metadata.NMax};
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Original( ...
                'parameter', parameters, 'run', metadata.Run, 'save', 0, ...
                'outputFcn', @GoodGroupPrecisionTest.silentOutput);
            algorithm.Solve(problem);
            finalResult = algorithm.result{end, 2};
            frozen = struct("Dec", finalResult.decs, "Obj", finalResult.objs, ...
                "FE", problem.FE);
        end

        function warmupLearningToolboxes()
            savedRandomState = rng();
            randomCleanup = onCleanup(@() rng(savedRandomState));
            rng(12345, "twister");
            inputs = rand(20, 4);
            outputs = double(inputs(:, 1) > 0.5);
            network = patternnet(2);
            network.trainParam.showWindow = 0;
            train(network, inputs.', outputs.');
            try
                fitrsvm(inputs, outputs, 'KernelFunction', 'rbf', ...
                    'KernelScale', 'auto', 'Standardize', true);
            catch
                % The frozen algorithm already defines an SVM fallback.
            end
        end

        function silentOutput(varargin)
        end

        function removeTestRoot(testRoot)
            if isfolder(testRoot)
                rmdir(testRoot, "s");
            end
        end
    end
end
