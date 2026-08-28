classdef CandidateModeContributionTest < matlab.unittest.TestCase
%CANDIDATEMODECONTRIBUTIONTEST Contract tests without expensive optimization.

    methods (TestMethodSetup)
        function addExperimentPaths(testCase)
            experimentDir = fileparts(fileparts(mfilename('fullpath')));
            platemoDir = fileparts(fileparts(experimentDir));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                platemoDir,'IncludingSubfolders',true));
            addpath(experimentDir,'-begin');
            addpath(fullfile(experimentDir,'algorithms'),'-begin');
        end
    end

    methods (Test)
        function protocolIsFrozenAndStageSpecific(testCase)
            stage0 = CMCProtocol('stage0','pilot');
            stage3 = CMCProtocol('stage3','formal');

            testCase.verifyEqual(stage0.MaxFE,500);
            testCase.verifyEqual(stage0.Parameters.gmax,3000);
            testCase.verifyEqual(stage0.Parameters.nMax,6);
            testCase.verifyEqual(CMCProtocol('stage1','pilot').Checkpoints, ...
                [0.20 0.50 0.80]);
            testCase.verifyEqual(numel(CMCProtocol('stage1','pilot').Runs),5);
            testCase.verifyEqual(numel(stage3.Problems),16);
            testCase.verifyEqual(numel(stage3.Runs),30);
            testCase.verifyEqual(stage3.EndpointSaveCount,4);
            testCase.verifyTrue(isfield(stage3.ComponentHashes, ...
                'ALGORITHMS_TREE'));
            testCase.verifyNotEqual(stage0.ProtocolHash,stage3.ProtocolHash);
        end

        function armCatalogHasUniqueDropOneArms(testCase)
            catalog = CMCArmCatalog();

            testCase.verifyEqual(numel(unique(catalog.Arm)),height(catalog));
            testCase.verifyEqual(numel(unique(catalog.ArmID)),height(catalog));
            testCase.verifyTrue(all(ismember( ...
                ["A00_FULL","A01_NO_P","A07_NO_F","CURRENT_HCV"], ...
                catalog.Arm)));
        end

        function expandedJobsAreArmAwareAndPaired(testCase)
            protocol = CMCProtocol('stage2','smoke');
            catalog = CMCArmCatalog();
            arms = catalog(ismember(catalog.Arm,["A00_FULL","A01_NO_P"]),:);
            jobs = CMCExpandJobs(protocol,arms);
            pairedGroups = findgroups(jobs.PairedKey);
            pairedCounts = splitapply(@numel,jobs.Arm,pairedGroups);

            testCase.verifyEqual(numel(unique(jobs.JobID)),height(jobs));
            testCase.verifyTrue(all(pairedCounts == 2));
            testCase.verifyEqual(numel(unique(jobs.SearchSeed)),height(jobs)/2);
        end

        function stableSeedsSeparateFormalFromScreening(testCase)
            screen = CMCStableSeed('stage2','DTLZ2',10,1);
            formal = CMCStableSeed('stage3','DTLZ2',10,1);

            testCase.verifyNotEqual(screen.Search,formal.Search);
            testCase.verifyNotEqual(screen.Routing,formal.Routing);
            testCase.verifyNotEqual(screen.RandomControl,formal.RandomControl);
        end

        function resultPathsCannotCollideAcrossArms(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>
            protocol = CMCProtocol('stage2','smoke');
            paths = CMCStagePaths(protocol,root);
            catalog = CMCArmCatalog();
            jobs = CMCExpandJobs(protocol,catalog(1:2,:));

            first = CMCResultPath(paths,jobs(1,:));
            secondArm = find(jobs.PairedKey == jobs.PairedKey(1),1,'last');
            second = CMCResultPath(paths,jobs(secondArm,:));

            testCase.verifyNotEqual(string(first),string(second));
            testCase.verifyTrue(contains(first,char(jobs.Arm(1))));
            testCase.verifyTrue(contains(second,char(jobs.Arm(secondArm))));
        end

        function previousGateRequiresBothPassFiles(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>
            CandidateModeContributionTest.writeSmokeStage0Gate(root,"SMOKE_PASS");
            protocol = CMCProtocol('stage1','smoke');

            upstream = CMCRequirePreviousGate(protocol,root);

            testCase.verifyTrue(upstream.Required);
            testCase.verifyEqual(upstream.DecisionCode,"SMOKE_PASS");
            testCase.verifyNotEmpty(upstream.DecisionHash);
        end

        function previousScientificStopBlocksNextStage(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>
            CandidateModeContributionTest.writeSmokeStage0Gate( ...
                root,"STOP_NO_BEHAVIORAL_ACTIVITY");
            protocol = CMCProtocol('stage1','smoke');

            testCase.verifyError(@()CMCRequirePreviousGate(protocol,root), ...
                'CMC:PreviousScienceGateFailed');
        end

        function upstreamHashBindsAuthorizationTable(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>
            CandidateModeContributionTest.writeSmokeStage0Gate(root,"SMOKE_PASS");
            protocol = CMCProtocol('stage1','smoke');
            first = CMCRequirePreviousGate(protocol,root);
            paths = CMCStagePaths(CMCProtocol('stage0','smoke'),root);
            filePath = fullfile(paths.AnalysisRoot, ...
                'CMC_Stage0_FactorDecision.csv');
            authorization = readtable(filePath,'TextType','string');
            authorization.CarryToNextStage(:) = false;
            CMCWriteTableAtomic(authorization,filePath);
            second = CMCRequirePreviousGate(protocol,root);

            testCase.verifyNotEqual(first.DecisionHash,second.DecisionHash);
        end

        function validRunContractRejectsMissingAuditColumn(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>
            [filePath,protocol,job] = ...
                CandidateModeContributionTest.writeSyntheticStage2Run(root);
            [validBefore,~] = CMCValidateRunFile(filePath,protocol,job);
            CandidateModeContributionTest.removeOneAuditColumn(filePath);
            [validAfter,report] = CMCValidateRunFile(filePath,protocol,job);

            testCase.verifyTrue(validBefore);
            testCase.verifyFalse(validAfter);
            testCase.verifyEqual(report.Detail,"audit table columns are incomplete");
        end

        function textHashUsesSHA256(testCase)
            digest = CMCTextHash("abc");

            testCase.verifyEqual(digest, ...
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        end

        function hierarchicalSignFlipDetectsDirection(testCase)
            groups = repelem("cell"+string((1:4)'),5);
            favorable = CMCHierarchicalSignFlipP( ...
                -ones(20,1),groups,2000,1234);
            unfavorable = CMCHierarchicalSignFlipP( ...
                ones(20,1),groups,2000,1234);

            testCase.verifyLessThan(favorable,0.01);
            testCase.verifyGreaterThan(unfavorable,0.99);
        end

        function runValidatorRejectsWrongUpstreamHash(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>
            [filePath,protocol,job] = ...
                CandidateModeContributionTest.writeSyntheticStage2Run(root);

            [valid,report] = CMCValidateRunFile( ...
                filePath,protocol,job,"different-upstream");

            testCase.verifyFalse(valid);
            testCase.verifyEqual(report.Detail, ...
                "metadata does not match the frozen job");
        end

        function runValidatorRejectsDifferentExecutionHost(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>
            [filePath,protocol,job] = ...
                CandidateModeContributionTest.writeSyntheticStage2Run(root);
            data = load(filePath);
            data.metadata.HostName = 'DIFFERENT_CMC_HOST';
            save(filePath,'-struct','data');

            [valid,report] = CMCValidateRunFile(filePath,protocol,job);

            testCase.verifyFalse(valid);
            testCase.verifyEqual(report.Detail, ...
                "metadata does not match the frozen job");
        end

        function setupConfirmsFrozenSourceHashes(testCase)
            paths = CMCSetupPaths();

            testCase.verifyEqual(height(paths.SourceLock),2);
            testCase.verifyTrue(all(isfile(paths.SourceLock.Path)));
        end

        function partialScientificAnalysisIsForbidden(testCase)
            root = CandidateModeContributionTest.makeTemporaryRoot();
            cleanup = onCleanup(@()CandidateModeContributionTest.removeTemporaryRoot(root)); %#ok<NASGU>

            testCase.verifyError(@()analyze_CandidateModeContribution( ...
                'stage2','screening','ResultRoot',root, ...
                'Arms',"A00_FULL"), ...
                'CMC:PartialScientificAnalysisForbidden');
        end

        function poolOnlyEvidenceCannotBeRelabeledFull(testCase)
            protocol = CMCProtocol('stage2','screening');
            arms = ["A00_FULL";"C00_RELATION_CONTROL"; ...
                "CURRENT_HCV";"A01_NO_P"];
            decisions = CandidateModeContributionTest.gateDecisionTable( ...
                arms,[true;true;false;true], ...
                numel(protocol.Problems)*numel(protocol.Objectives));

            code = CMCStage2GateCode(decisions,"P",true,true, ...
                "PASS_TO_STAGE2_POOL_ONLY",protocol);

            testCase.verifyEqual(code,"PASS_TO_STAGE3_REDUCED");
        end

        function formalFullRequiresEveryRegisteredEvidenceArm(testCase)
            protocol = CMCProtocol('stage3','formal');
            arms = ["A00_FULL";"C00_RELATION_CONTROL"; ...
                "CURRENT_HCV";"A01_NO_P"];
            decisions = CandidateModeContributionTest.gateDecisionTable( ...
                arms,[true;true;false;true]);

            reduced = CMCStage3GateCode( ...
                decisions,"PASS_TO_STAGE3_FULL",protocol);

            catalog = CMCArmCatalog();
            evidence = catalog.Arm(ismember(catalog.Role, ...
                ["drop_one","negative_control","route_control"]));
            fullArms = ["A00_FULL";"C00_RELATION_CONTROL"; ...
                "CURRENT_HCV";evidence];
            fullQualified = [true;true;false;true(numel(evidence),1)];
            fullDecisions = ...
                CandidateModeContributionTest.gateDecisionTable( ...
                fullArms,fullQualified);
            supported = CMCStage3GateCode( ...
                fullDecisions,"PASS_TO_STAGE3_FULL",protocol);

            testCase.verifyEqual(reduced,"SUPPORTED_REDUCED_MODULE");
            testCase.verifyEqual(supported,"SUPPORTED_FULL_MODULE");
        end

        function oneRouteArmCannotSupportRoutingFactor(testCase)
            protocol = CMCProtocol('stage3','formal');
            arms = ["A00_FULL";"CURRENT_HCV";"G01_ALWAYS_EXPLORE"];
            decisions = CandidateModeContributionTest.gateDecisionTable( ...
                arms,true(3,1));

            code = CMCStage3GateCode( ...
                decisions,"PASS_TO_STAGE3_REDUCED",protocol);

            testCase.verifyEqual(code, ...
                "PERFORMANCE_GAIN_WITHOUT_FACTOR_ATTRIBUTION");
        end

        function anchorRequiresEveryObjectiveCountNoninferior(testCase)
            protocol = CMCProtocol('stage3','formal');
            decisions = CandidateModeContributionTest.gateDecisionTable( ...
                ["A00_FULL";"CURRENT_HCV"],true(2,1));
            decisions.MaxMCI95Upper(decisions.Arm == "CURRENT_HCV") = 1.06;

            testCase.verifyFalse(CMCAnchorCompatible(decisions,protocol));
        end

        function stage1LabelsTheActualCarriedSet(testCase)
            fullSet = ["P";"Q";"C";"D";"E_GEN";"E_FINAL";"F";"G"; ...
                "P_ERR_GATE";"D_SIGNAL";"F_SIGNAL"];
            full = table(fullSet,repmat("QUALIFIED",numel(fullSet),1), ...
                true(numel(fullSet),1), ...
                'VariableNames',{'Factor','FactorDecision', ...
                'CarryToNextStage'});
            onlyP = full(1,:);
            pAndQ = full(1:2,:);

            testCase.verifyEqual(CMCStage1GateCode(onlyP), ...
                "PASS_TO_STAGE2_POOL_ONLY");
            testCase.verifyEqual(CMCStage1GateCode(pAndQ), ...
                "PASS_TO_STAGE2_REDUCED");
            testCase.verifyEqual(CMCStage1GateCode(full), ...
                "PASS_TO_STAGE2_FULL");
        end

        function evidenceSummaryExcludesAnchorsAndRequiresBothRoutes(testCase)
            arms = ["A00_FULL";"C00_RELATION_CONTROL"; ...
                "CURRENT_HCV";"G01_ALWAYS_EXPLORE"];
            decisions = CandidateModeContributionTest.gateDecisionTable( ...
                arms,true(4,1));

            [qualified,dropped,assessed] = ...
                CMCSummarizeEvidenceFactors(decisions);

            testCase.verifyEmpty(qualified);
            testCase.verifyEqual(dropped,"G");
            testCase.verifyEqual(assessed,"G");
        end

        function primaryMetricLabelsMatchEstimands(testCase)
            testCase.verifyEqual(CMCPrimaryMetric('stage0'), ...
                "BEHAVIORAL_ACTIVITY");
            testCase.verifyEqual(CMCPrimaryMetric('stage1'), ...
                "DIRECT_ORACLE_EFFICIENCY_DELTA");
            testCase.verifyEqual(CMCPrimaryMetric('stage2'),"FINAL_IGDP");
            testCase.verifyEqual(CMCPrimaryMetric('stage3'),"FINAL_IGDP");
        end

        function indicatorSelectionHonorsFrozenPoolUniverse(testCase)
            candidates = (1:10)';
            score = (1:10)';
            universe = false(10,1);
            universe(1:3) = true;
            Smodel = struct('IndicatorModel',[], ...
                'RandomControlSeed',1,'Generation',1);

            [selected,retained,operational] = ...
                CMCFixedIndicatorSelection( ...
                Smodel,candidates,score,2,false,universe);

            testCase.verifyEqual(selected,[3;2]);
            testCase.verifyEqual(retained,3);
            testCase.verifyFalse(operational);
            testCase.verifyTrue(all(universe(selected)));
        end

        function exploreSelectionIgnoresOutsidePoolExtremes(testCase)
            candidates = [0;1;2;100;200];
            universe = [true;true;true;false;false];
            scoreA = [0.1;0.8;0.4;1e12;-1e12];
            scoreB = [0.1;0.8;0.4;-1e30;1e30];
            ambiguityA = [0.9;0.2;0.5;1e15;-1e15];
            ambiguityB = [0.9;0.2;0.5;-1e25;1e25];

            [selectedA,retainedA,augmentedA] = ...
                CMCFixedExploreSelection(candidates,scoreA,ambiguityA, ...
                0.35,0.50,2,true,true,universe);
            [selectedB,retainedB,augmentedB] = ...
                CMCFixedExploreSelection(candidates,scoreB,ambiguityB, ...
                0.35,0.50,2,true,true,universe);

            testCase.verifyEqual(selectedA,selectedB);
            testCase.verifyEqual(retainedA,retainedB);
            testCase.verifyEqual(augmentedA(universe), ...
                augmentedB(universe),'AbsTol',1e-12);
            testCase.verifyTrue(all(universe(selectedA)));
        end
    end

    methods (Static, Access = private)
        function root = makeTemporaryRoot()
            root = tempname;
            mkdir(root);
        end

        function removeTemporaryRoot(root)
            if isfolder(root)
                rmdir(root,'s');
            end
        end

        function writeSmokeStage0Gate(root,decisionCode)
            previous = CMCProtocol('stage0','smoke');
            paths = CMCStagePaths(previous,root);
            mkdir(paths.AnalysisRoot);
            integrity = table(previous.ProtocolHash,"PASS", ...
                'VariableNames',{'ProtocolHash','Status'});
            decision = table(previous.ProtocolHash,string(decisionCode), ...
                'VariableNames',{'ProtocolHash','DecisionCode'});
            factorDecision = table("P",true,previous.ProtocolHash, ...
                'VariableNames',{'Factor','CarryToNextStage','ProtocolHash'});
            CMCWriteTableAtomic(integrity,fullfile(paths.AnalysisRoot, ...
                'CMC_Stage0_IntegrityGate.csv'));
            CMCWriteTableAtomic(decision,fullfile(paths.AnalysisRoot, ...
                'CMC_Stage0_ScientificDecision.csv'));
            CMCWriteTableAtomic(factorDecision,fullfile(paths.AnalysisRoot, ...
                'CMC_Stage0_FactorDecision.csv'));
        end

        function [filePath,protocol,job] = writeSyntheticStage2Run(root)
            protocol = CMCProtocol('stage2','smoke');
            catalog = CMCArmCatalog();
            jobs = CMCExpandJobs(protocol,catalog(1,:));
            job = jobs(1,:);
            paths = CMCStagePaths(protocol,root);
            filePath = CMCResultPath(paths,job);
            mkdir(fileparts(filePath));
            metadata = struct('SchemaVersion',protocol.SchemaVersion, ...
                'ProtocolVersion',char(protocol.ProtocolVersion), ...
                'ProtocolHash',char(protocol.ProtocolHash), ...
                'Stage',char(protocol.Stage),'Profile',char(protocol.Profile), ...
                'Problem',char(job.Problem),'Family',char(job.Family), ...
                'M',job.M,'RequestedD',job.RequestedD, ...
                'ActualD',job.ActualD,'N',protocol.N,'Run',job.Run, ...
                'Arm',char(job.Arm),'ArmID',job.ArmID, ...
                'AlgorithmClass',char(job.AlgorithmClass), ...
                'MATLABVersion',char(protocol.ExecutionEnvironment.MATLABVersion), ...
                'Computer',char(protocol.ExecutionEnvironment.Computer), ...
                'HostName',char(protocol.ExecutionEnvironment.HostName), ...
                'CompletedFE',protocol.MaxFE,'MaxFE',protocol.MaxFE, ...
                'SearchSeed',job.SearchSeed,'RoutingSeed',job.RoutingSeed, ...
                'RandomControlSeed',job.RandomControlSeed, ...
                'JobID',char(job.JobID),'PairedKey',char(job.PairedKey), ...
                'Runtime',0.1);
            metadata.UpstreamDecisionHash = '';
            metadata.EndpointSaveCount = protocol.EndpointSaveCount;
            metadata.AnytimeIGDpDefinition = ...
                char(protocol.AnytimeIGDpDefinition);
            finalPopulation = struct('Dec',zeros(2,job.ActualD), ...
                'Obj',ones(2,job.M),'Con',zeros(2,0));
            IGD = 1; IGDp = 1; runtime = 0.1;
            traceFE = round(linspace(protocol.MaxFE/4,protocol.MaxFE, ...
                protocol.EndpointSaveCount))';
            anytimeTrace = table(traceFE,traceFE./protocol.MaxFE, ...
                repmat(IGDp,protocol.EndpointSaveCount,1), ...
                'VariableNames',{'FE','FERatio','IGDp'});
            anytimeIGDpAUC = CMCTraceAUC(anytimeTrace);
            activityRows = CMCActivitySchema();
            snapshotRows = CMCSnapshotSchema();
            referenceRows = CMCReferenceSchema();
            save(filePath,'metadata','finalPopulation','IGD','IGDp', ...
                'anytimeIGDpAUC','anytimeTrace','runtime','activityRows', ...
                'snapshotRows','referenceRows');
        end

        function removeOneAuditColumn(filePath)
            data = load(filePath);
            data.snapshotRows = removevars(data.snapshotRows,'UtilityStatus');
            save(filePath,'-struct','data');
        end

        function value = gateDecisionTable(arms,qualified,cellCount)
            if nargin < 3
                cellCount = 32;
            end
            count = numel(arms);
            lower = 0.90.*ones(count,1);
            upper = 0.99.*ones(count,1);
            maxMUpper = 0.99.*ones(count,1);
            maxFamilyM = ones(count,1);
            dtlz = ones(count,1);
            wfg = ones(count,1);
            severe = zeros(count,1);
            maxFamilyMSevere = zeros(count,1);
            cells = repmat(cellCount,count,1);
            value = table(string(arms(:)),logical(qualified(:)),lower, ...
                upper,maxMUpper,maxFamilyM,dtlz,wfg,severe, ...
                maxFamilyMSevere,cells, ...
                'VariableNames',{'Arm','Qualified','CI95Lower', ...
                'CI95Upper','MaxMCI95Upper','MaxFamilyMGeoMeanRatio', ...
                'DTLZGeoMeanRatio','WFGGeoMeanRatio', ...
                'SevereRegressionCount', ...
                'MaxFamilyMSevereRegressionCount','Cells'});
        end
    end
end
