classdef DualPBIComplementarityTest < matlab.unittest.TestCase
    %DualPBIComplementarityTest - Test dual-PBI complementarity utilities

    methods (TestClassSetup)
        function addExperimentPaths(testCase)
            testsDirectory = fileparts(mfilename("fullpath"));
            supplementDirectory = fileparts(testsDirectory);
            experimentDirectory = fileparts(supplementDirectory);
            repositoryDirectory = fileparts(fileparts(fileparts( ...
                experimentDirectory)));
            fixture = matlab.unittest.fixtures.PathFixture( ...
                repositoryDirectory, "IncludingSubfolders", true);
            testCase.applyFixture(fixture);
        end
    end

    methods (Test)
        function knownPartitionIsExact(testCase)
            v = logical([1 1 0 0 1 0 0 0]);
            a = logical([1 0 1 0 0 1 0 0]);
            h = logical([1 1 1 0 0 0 0 0]);
            label = logical([1 0 1 1 0 0 0 0]);
            truth = logical([1 1 1 0 0 0 1 0]);

            actual = DPCComputeSetComplementarity(v, a, h, label, truth);

            testCase.verifyEqual(actual.BothCount, 1);
            testCase.verifyEqual(actual.VOnlyCount, 2);
            testCase.verifyEqual(actual.AOnlyCount, 2);
            testCase.verifyEqual(actual.NeitherCount, 3);
            testCase.verifyEqual(actual.TPBoth, 1);
            testCase.verifyEqual(actual.TPVOnly, 1);
            testCase.verifyEqual(actual.TPAOnly, 1);
            testCase.verifyEqual(actual.HybridTP, 3);
        end

        function identicalViewsHaveJaccardOne(testCase)
            selection = logical([1 1 0 0]);
            truth = logical([1 0 1 0]);

            actual = DPCComputeSetComplementarity( ...
                selection, selection, selection, selection, truth);

            testCase.verifyEqual(actual.JaccardVA, 1, "AbsTol", 1e-12);
            testCase.verifyEqual(actual.VOnlyCount, 0);
            testCase.verifyEqual(actual.AOnlyCount, 0);
        end

        function disjointViewsHaveJaccardZero(testCase)
            v = logical([1 1 0 0]);
            a = logical([0 0 1 1]);
            truth = logical([1 0 1 0]);

            actual = DPCComputeSetComplementarity(v, a, v, a, truth);

            testCase.verifyEqual(actual.JaccardVA, 0, "AbsTol", 1e-12);
            testCase.verifyEqual(actual.AgreementVA, 0, "AbsTol", 1e-12);
        end

        function censoredTruthKeepsSetMetrics(testCase)
            selection = logical([1 0 1 0]);

            actual = DPCComputeSetComplementarity( ...
                selection, selection, selection, selection, NaN(1, 4));

            testCase.verifyTrue(actual.Censored);
            testCase.verifyEqual(actual.JaccardVA, 1, "AbsTol", 1e-12);
            testCase.verifyTrue(isnan(actual.TPVOnly));
            testCase.verifyTrue(isnan(actual.HybridPrecision));
        end

        function zeroDenominatorsReturnNaN(testCase)
            selection = logical([1 1 0 0]);
            truth = false(1, 4);

            actual = DPCComputeSetComplementarity( ...
                selection, selection, selection, selection, truth);

            testCase.verifyTrue(isnan(actual.UniqueTPRateV));
            testCase.verifyTrue(isnan(actual.UniquePrecisionV));
            testCase.verifyTrue(isnan(actual.UniqueTPShare));
        end

        function sizeMismatchRaisesContractError(testCase)
            testCase.verifyError(@() DPCComputeSetComplementarity( ...
                logical([1 0]), logical([1 0 0]), logical([1 0]), ...
                logical([1 0]), logical([1 0])), ...
                "DPC:SelectionSizeMismatch");
        end

        function strictFusionRequiresBothWins(testCase)
            inputTable = DualPBIComplementarityTest.makeFusionTable(true);

            actual = DPCBuildStrictFusionTests(inputTable, ...
                "BootstrapSamples", 200);

            testCase.verifyTrue(actual.FusionSupported);
            testCase.verifyEqual(actual.PValueFusionRaw, ...
                max(actual.PValueHybridVsV, actual.PValueHybridVsA), ...
                "AbsTol", 1e-12);
            testCase.verifyGreaterThan(actual.MeanDeltaHybridVsV, 0);
            testCase.verifyGreaterThan(actual.MeanDeltaHybridVsA, 0);
        end

        function strictFusionFailsWhenAnchorWins(testCase)
            inputTable = DualPBIComplementarityTest.makeFusionTable(false);

            actual = DPCBuildStrictFusionTests(inputTable, ...
                "BootstrapSamples", 200);

            testCase.verifyFalse(actual.FusionSupported);
            testCase.verifyLessThan(actual.MeanDeltaHybridVsA, 0);
        end

        function uniqueContributionRequiresBothDirections(testCase)
            inputTable = DualPBIComplementarityTest.makeUniqueTable(true);

            actual = DPCBuildUniqueContributionTests(inputTable);

            testCase.verifyTrue(actual.UniqueSupported);
            testCase.verifyEqual(actual.SuccessRunsV, 20);
            testCase.verifyEqual(actual.SuccessRunsA, 19);
        end

        function uniqueContributionFailsForOneDirection(testCase)
            inputTable = DualPBIComplementarityTest.makeUniqueTable(false);

            actual = DPCBuildUniqueContributionTests(inputTable);

            testCase.verifyFalse(actual.UniqueSupported);
            testCase.verifyEqual(actual.SuccessRunsA, 4);
        end

        function finalGateDoesNotDependOnScientificOutcome(testCase)
            coverage = table("DTLZ2", 10, 25, 25, true, ...
                'VariableNames', {'Problem','M','ExpectedRuns', ...
                'ValidRuns','Complete'});
            replay = table(true(25, 1), 'VariableNames', {'EquivalencePass'});
            [fusion, unique, decisions] = ...
                DualPBIComplementarityTest.makeGateTables(false);

            actual = DPCBuildFinalGate(coverage, replay, fusion, unique, ...
                decisions, 25, 1);

            testCase.verifyEqual(actual.Status, "PASS");
        end

        function finalGateRejectsIncompletePairedRuns(testCase)
            coverage = table("DTLZ2", 10, 25, 25, true, ...
                'VariableNames', {'Problem','M','ExpectedRuns', ...
                'ValidRuns','Complete'});
            replay = table(true(25, 1), 'VariableNames', {'EquivalencePass'});
            [fusion, unique, decisions] = ...
                DualPBIComplementarityTest.makeGateTables(true);
            fusion.ValidPairs(1) = 24;

            actual = DPCBuildFinalGate(coverage, replay, fusion, unique, ...
                decisions, 25, 1);

            testCase.verifyEqual(actual.Status, "FAIL");
            testCase.verifyFalse(actual.FusionRunComplete);
        end
    end

    methods (Static, Access = private)
        function data = makeFusionTable(anchorIsLower)
            run = (1:25).';
            seed = 1000 + run;
            hybrid = 0.70 + run/10000;
            vScore = 0.50 + run/10000;
            anchorLow = 0.60 + run/10000;
            anchorHigh = 0.80 + run/10000;
            if anchorIsLower
                anchor = anchorLow;
            else
                anchor = anchorHigh;
            end
            data = DualPBIComplementarityTest.makeThreeViewTable( ...
                run, seed, hybrid, vScore, anchor);
        end

        function data = makeThreeViewTable(run, seed, hybrid, vScore, anchor)
            problem = repmat("DTLZ2", 75, 1);
            objectiveCount = repmat(10, 75, 1);
            runAll = repmat(run, 3, 1);
            seedAll = repmat(seed, 3, 1);
            stage = repmat("S1_[0,0.25]", 75, 1);
            view = [repmat("score_hybrid", 25, 1); ...
                repmat("score_v", 25, 1); ...
                repmat("anchor_margin", 25, 1)];
            selectionRule = repmat("top25", 75, 1);
            truth = repmat("population_final", 75, 1);
            meanPrecision = [hybrid; vScore; anchor];
            data = table(problem, objectiveCount, runAll, seedAll, stage, ...
                view, selectionRule, truth, meanPrecision, ...
                'VariableNames', {'Problem','M','Run','Seed','Stage', ...
                'View','SelectionRule','Truth','MeanPrecision'});
        end

        function data = makeUniqueTable(bothDirections)
            run = (1:25).';
            seed = 2000 + run;
            problem = repmat("DTLZ2", 25, 1);
            objectiveCount = repmat(10, 25, 1);
            stage = repmat("S1_[0,0.25]", 25, 1);
            truth = repmat("population_final", 25, 1);
            meanTPVOnly = double(run <= 20);
            successA = 19;
            if ~bothDirections
                successA = 4;
            end
            meanTPAOnly = double(run <= successA);
            meanUniqueTPRateV = meanTPVOnly/10;
            meanUniqueTPRateA = meanTPAOnly/10;
            meanUniquePrecisionV = meanTPVOnly/5;
            meanUniquePrecisionA = meanTPAOnly/5;
            data = table(problem, objectiveCount, run, seed, stage, truth, ...
                meanTPVOnly, meanTPAOnly, meanUniqueTPRateV, ...
                meanUniqueTPRateA, meanUniquePrecisionV, ...
                meanUniquePrecisionA, ...
                'VariableNames', {'Problem','M','Run','Seed','Stage', ...
                'Truth','MeanTPVOnly','MeanTPAOnly', ...
                'MeanUniqueTPRateV','MeanUniqueTPRateA', ...
                'MeanUniquePrecisionV','MeanUniquePrecisionA'});
        end


        function [fusion, unique, decisions] = makeGateTables(supported)
            stages = ["S1_[0,0.25]"; "S2_(0.25,0.50]"; ...
                "S3_(0.50,0.75]"; "S4_(0.75,1.00]"];
            problem = repmat("DTLZ2", 4, 1);
            objectiveCount = repmat(10, 4, 1);
            availableRuns = repmat(25, 4, 1);
            validPairs = repmat(25, 4, 1);
            validRuns = repmat(25, 4, 1);
            fusionSupported = repmat(supported, 4, 1);
            uniqueSupported = repmat(supported, 4, 1);
            fusion = table(problem, objectiveCount, stages, ...
                availableRuns, validPairs, fusionSupported, ...
                'VariableNames', {'Problem','M','Stage','AvailableRuns', ...
                'ValidPairs','FusionSupported'});
            unique = table(problem, objectiveCount, stages, ...
                availableRuns, validRuns, uniqueSupported, ...
                'VariableNames', {'Problem','M','Stage','AvailableRuns', ...
                'ValidRuns','UniqueSupported'});
            decisions = table(problem, objectiveCount, stages, ...
                fusionSupported & uniqueSupported, ...
                'VariableNames', {'Problem','M','Stage', ...
                'ComplementaritySupported'});
        end
    end
end
