function tests = test_ConfidenceProbeHarness
% Unit tests for the confidence-probe experiment harness and analysis.

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    harnessDir = fileparts(fileparts(mfilename('fullpath')));
    platemoRoot = fileparts(fileparts(harnessDir));
    addpath(genpath(platemoRoot));
    testCase.TestData.harnessDir = harnessDir;
end

function testFourProfilesHaveFrozenMatricesAndStableSeeds(testCase)
    smoke = ConfidenceProbeProtocol('smoke');
    pilot = ConfidenceProbeProtocol('pilot');
    screening = ConfidenceProbeProtocol('screening');
    confirmation = ConfidenceProbeProtocol('confirmation');

    verifyEqual(testCase,height(smoke.jobs),1);
    verifyEqual(testCase,cellstr(smoke.jobs.Problem),{'DTLZ2'});
    verifyEqual(testCase,smoke.jobs.M,3);
    verifyEqual(testCase,smoke.jobs.RequestedD,3);
    verifyEqual(testCase,smoke.jobs.ActualD,3);
    verifyEqual(testCase,smoke.jobs.N,20);
    verifyEqual(testCase,smoke.jobs.MaxFE,36);
    verifyEqual(testCase,smoke.jobs.Run,1);
    verifyEqual(testCase,smoke.jobs.Gmax,1);

    verifyEqual(testCase,height(pilot.jobs),9);
    verifyEqual(testCase,pilot.problems,{'DTLZ2','DTLZ7','WFG3'});
    verifyEqual(testCase,unique(pilot.jobs.M),10);
    verifyEqual(testCase,unique(pilot.jobs.MaxFE),500);
    verifyEqual(testCase,sort(unique(pilot.jobs.Run))',(1:3));

    expectedProblems = {'DTLZ2','DTLZ4','DTLZ7','WFG3','WFG7'};
    verifyEqual(testCase,screening.problems,expectedProblems);
    verifyEqual(testCase,height(screening.jobs),50);
    verifyEqual(testCase,unique(screening.jobs.M),10);
    verifyEqual(testCase,sort(unique(screening.jobs.Run))',(1:10));

    verifyEqual(testCase,confirmation.problems,expectedProblems);
    verifyEqual(testCase,height(confirmation.jobs),50);
    verifyEqual(testCase,unique(confirmation.jobs.M),20);
    verifyEqual(testCase,sort(unique(confirmation.jobs.Run))',(1:10));

    protocols = {pilot,screening,confirmation};
    for i = 1:numel(protocols)
        jobs = protocols{i}.jobs;
        wfg3 = jobs.Problem == "WFG3";
        verifyTrue(testCase,all(jobs.RequestedD == 30));
        verifyTrue(testCase,all(jobs.ActualD(wfg3) == 31));
        verifyTrue(testCase,all(jobs.ActualD(~wfg3) == 30));
    end

    for run = 1:3
        pilotSeed = seedFor(pilot,'DTLZ2',10,run);
        screeningSeed = seedFor(screening,'DTLZ2',10,run);
        verifyEqual(testCase,pilotSeed,screeningSeed);
    end
    verifyEqual(testCase,numel(unique(screening.jobs.Seed)), ...
        height(screening.jobs));
end

function testUnknownProfileIsRejectedWithoutCreatingOutput(testCase)
    verifyError(testCase,@()ConfidenceProbeProtocol('unknown'), ...
        'AdaMaO:UnknownConfidenceProbeProfile');
    outputDir = tempname;
    verifyError(testCase,@()run_ConfidenceProbe_experiment( ...
        'unknown',outputDir), ...
        'AdaMaO:UnknownConfidenceProbeProfile');
    verifyFalse(testCase,isfolder(outputDir));
end

function testBinsAreStableBalancedAndIndependentWithinStrata(testCase)
    values = [0.1;0.2;0.2;0.4;0.5;0.6;0.7;0.8;0.9;1.0; ...
              9.0;8.0;8.0;7.0;6.0;5.0;4.0;3.0;2.0;1.0];
    strata = table( ...
        [ones(10,1);2*ones(10,1)], ...
        [ones(10,1);ones(10,1)], ...
        'VariableNames',{'Generation','PairType'});

    first = AssignConfidenceProbeBins(values,strata,5);
    second = AssignConfidenceProbeBins(values,strata,5);
    verifyEqual(testCase,first,second);
    for group = 1:2
        rows = strata.Generation == group;
        counts = accumarray(first(rows),1,[5,1]);
        verifyLessThanOrEqual(testCase,max(counts)-min(counts),1);
        [~,minimum] = min(values(rows));
        [~,maximum] = max(values(rows));
        groupBins = first(rows);
        verifyEqual(testCase,groupBins(minimum),1);
        verifyEqual(testCase,groupBins(maximum),5);
    end

    % Ties are broken by original row order, without consuming RNG.
    stateBefore = rng;
    tieBins = AssignConfidenceProbeBins(ones(5,1),ones(5,1),5);
    stateAfter = rng;
    verifyEqual(testCase,tieBins,(1:5)');
    verifyEqual(testCase,stateAfter,stateBefore);
end

function testValidatorAcceptsCompleteRunAndRejectsMalformedRuns(testCase)
    protocol = ConfidenceProbeProtocol('smoke');
    job = protocol.jobs(1,:);
    folder = tempname;
    cleanup = onCleanup(@()removeTree(folder));
    mkdir(folder);
    validFile = fullfile(folder,'run_001.mat');

    [metadata,confidenceProbe,finalPopulation,IGD,IGDp,runtime] = ...
        validSyntheticRun(protocol,job);
    save(validFile,'metadata','confidenceProbe','finalPopulation', ...
        'IGD','IGDp','runtime');
    [valid,message,metrics] = ValidateConfidenceProbeResultFile( ...
        validFile,protocol,job);
    verifyTrue(testCase,valid,message);
    verifyEqual(testCase,[metrics.IGD,metrics.IGDp,metrics.runtime], ...
        [IGD,IGDp,runtime]);

    staleFile = fullfile(folder,'stale.mat');
    staleMetadata = metadata;
    staleMetadata.seed = staleMetadata.seed + 1;
    save(staleFile,'staleMetadata');
    moveVariableFile(staleFile,metadata,confidenceProbe,finalPopulation, ...
        IGD,IGDp,runtime,'seed');
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        staleFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'seed');

    incompleteFile = fullfile(folder,'incomplete.mat');
    badMetadata = metadata;
    badMetadata.completedFE = badMetadata.maxFE - 1;
    saveRun(incompleteFile,badMetadata,confidenceProbe,finalPopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        incompleteFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'completedFE');

    duplicateFile = fullfile(folder,'duplicate.mat');
    duplicatePopulation = finalPopulation;
    duplicatePopulation(2).add = duplicatePopulation(1).add;
    saveRun(duplicateFile,metadata,confidenceProbe,duplicatePopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        duplicateFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'EvalID');

    badConfidenceFile = fullfile(folder,'bad_confidence.mat');
    badProbe = confidenceProbe;
    confidenceColumn = column(badProbe,'solutionRows','PBIConfidence');
    badProbe.solutionRows(1,confidenceColumn) = 1.01;
    saveRun(badConfidenceFile,metadata,badProbe,finalPopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        badConfidenceFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'PBIConfidence');

    badNetworkFile = fullfile(folder,'bad_network_relation.mat');
    badProbe = confidenceProbe;
    left = column(badProbe,'networkPairRows','ProbabilityLeftBetter');
    same = column(badProbe,'networkPairRows','ProbabilitySame');
    right = column(badProbe,'networkPairRows','ProbabilityRightBetter');
    predicted = column(badProbe,'networkPairRows','PredictedRelation');
    networkConfidence = column( ...
        badProbe,'networkPairRows','NetworkConfidence');
    badProbe.networkPairRows(1,[left,same,right]) = [0.2,0.2,0.6];
    badProbe.networkPairRows(1,predicted) = 1;
    badProbe.networkPairRows(1,networkConfidence) = 0.6;
    saveRun(badNetworkFile,metadata,badProbe,finalPopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        badNetworkFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'PredictedRelation');

    badNetworkFile = fullfile(folder,'bad_network_confidence.mat');
    badProbe = confidenceProbe;
    badProbe.networkPairRows(1,networkConfidence) = ...
        badProbe.networkPairRows(1,networkConfidence)-0.01;
    saveRun(badNetworkFile,metadata,badProbe,finalPopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        badNetworkFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'NetworkConfidence');

    badTerminalFile = fullfile(folder,'bad_terminal.mat');
    badProbe = confidenceProbe;
    finalColumn = column(badProbe,'candidateRows','FinalND');
    badProbe.candidateRows(1,finalColumn) = nan;
    saveRun(badTerminalFile,metadata,badProbe,finalPopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        badTerminalFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'FinalND');

    badH1File = fullfile(folder,'bad_h1.mat');
    badProbe = confidenceProbe;
    h1Column = column(badProbe,'solutionRows','SurviveH1');
    badProbe.solutionRows(1,h1Column) = nan;
    saveRun(badH1File,metadata,badProbe,finalPopulation,IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        badH1File,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'SurviveH1');

    badWidthFile = fullfile(folder,'bad_width.mat');
    badProbe = confidenceProbe;
    badProbe.pbiPairRows(:,end) = [];
    saveRun(badWidthFile,metadata,badProbe,finalPopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        badWidthFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'pbiPairRows');

    missingFile = fullfile(folder,'missing.mat');
    badProbe = rmfield(confidenceProbe,'candidateRows');
    saveRun(missingFile,metadata,badProbe,finalPopulation, ...
        IGD,IGDp,runtime);
    [valid,message] = ValidateConfidenceProbeResultFile( ...
        missingFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'candidateRows');
end

function testSyntheticAnalysisWritesFrozenOutputsAndPassesGate(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);
    problems = {'DTLZ2','DTLZ4','DTLZ7','WFG3','WFG7'};
    for p = 1:numel(problems)
        for run = 1:10
            writeAnalysisRun(resultDir,problems{p},10,run);
        end
    end

    analysis = analyze_ConfidenceProbe(resultDir, ...
        'BootstrapSamples',100,'BootstrapSeed',71);

    expectedCSV = { ...
        'Confidence_PBI_pair_bins.csv'; ...
        'Confidence_PBI_solution_bins.csv'; ...
        'Confidence_network_pair_bins.csv'; ...
        'Confidence_candidate_bins.csv'; ...
        'Confidence_summary_by_problem.csv'; ...
        'Confidence_summary_by_M.csv'; ...
        'Confidence_decision.csv'};
    files = dir(fullfile(resultDir,'Confidence_*.csv'));
    verifyEqual(testCase,sort({files.name})',sort(expectedCSV));
    for i = 1:numel(expectedCSV)
        file = fullfile(resultDir,expectedCSV{i});
        verifyTrue(testCase,isfile(file));
        tableData = readtable(file);
        verifyNotEmpty(testCase,tableData);
    end
    verifyTrue(testCase,isfile(fullfile(resultDir, ...
        'Confidence_analysis.mat')));

    verifyEqual(testCase,height(analysis.summaryByProblem),5);
    verifyEqual(testCase,height(analysis.summaryByM),1);
    verifyEqual(testCase,analysis.summaryByM.ProblemCount,5);
    verifyEqual(testCase,analysis.summaryByM.NegativeProblemCount,5);
    verifyEqual(testCase,analysis.summaryByM.ExpectedRunCount,50);
    verifyEqual(testCase,analysis.summaryByM.CompletedRunCount,50);
    verifyEqual(testCase,analysis.summaryByM.ValidPrimaryRunCount,50);
    verifyEqual(testCase,analysis.summaryByM.ValidPrimaryProblemCount,5);
    verifyTrue(testCase,analysis.summaryByM.PrimaryDataComplete);
    verifyEqual(testCase,analysis.summaryByM.Q5MinusQ1Error,-1, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,analysis.summaryByM.AUROC,1,'AbsTol',1e-12);
    verifyTrue(testCase,analysis.decision.PrimaryGatePassed);
    verifyEqual(testCase,analysis.decision.DecisionCode, ...
        "GATE_DEVELOPMENT_VALUE");
    verifyGreaterThanOrEqual(testCase, ...
        analysis.decision.AbsoluteErrorReduction,0.05);

    requiredProblemColumns = { ...
        'Problem','M','RunCount','Q5MinusQ1Error','DiffCIUpper', ...
        'AUROC','AUROCCILower','DirectionNegative', ...
        'PBISDEQ5MinusQ1Error','PBISDEDiffCIUpper','PBISDEAUROC', ...
        'NetworkParetoQ5MinusQ1Error','NetworkParetoDiffCIUpper', ...
        'NetworkSDEQ5MinusQ1Error','NetworkSDEAUROCCILower', ...
        'CandidateMarginalIGDPositiveQ5MinusQ1', ...
        'CandidateSurviveH1Q5MinusQ1', ...
        'CandidateSurviveH3Q5MinusQ1', ...
        'CandidateArchiveNDNextQ5MinusQ1', ...
        'CandidateFinalNDQ5MinusQ1', ...
        'SolutionGoodSurviveH1Q5MinusQ1', ...
        'SolutionGoodSurviveH3Q5MinusQ1', ...
        'SolutionGoodFinalNDQ5MinusQ1', ...
        'SolutionRestSurviveH1Q5MinusQ1', ...
        'SolutionRestSurviveH3Q5MinusQ1', ...
        'SolutionRestFinalNDQ5MinusQ1'};
    verifyTrue(testCase,all(ismember(requiredProblemColumns, ...
        analysis.summaryByProblem.Properties.VariableNames)));

    pbiBins = analysis.pbiPairBins;
    verifyTrue(testCase,all(ismember( ...
        {'PairType','ConfidenceBin','ComparableParetoN', ...
        'ParetoErrorRate','SDEConsistencyRate'}, ...
        pbiBins.Properties.VariableNames)));
    % The synthetic incomparable relation is excluded, never counted right.
    verifyEqual(testCase,sum(pbiBins.ComparableParetoN), ...
        sum(pbiBins.N)-50);

    requiredMColumns = { ...
        'PBISDEQ5MinusQ1Error','PBISDEDiffCILower', ...
        'PBISDEFavorableProblemCount', ...
        'SolutionGoodSurviveH1Q5MinusQ1', ...
        'SolutionGoodSurviveH1CILower', ...
        'SolutionGoodSurviveH1FavorableProblemCount', ...
        'SolutionRestFinalNDQ5MinusQ1', ...
        'SolutionRestFinalNDCIUpper', ...
        'SolutionRestFinalNDFavorableProblemCount'};
    verifyTrue(testCase,all(ismember(requiredMColumns, ...
        analysis.summaryByM.Properties.VariableNames)));
end

function testMissingOrJointInvalidRunCannotPassPrimaryGate(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);
    problems = {'DTLZ2','DTLZ4','DTLZ7','WFG3','WFG7'};
    for p = 1:numel(problems)
        for run = 1:10
            writeAnalysisRun(resultDir,problems{p},10,run);
        end
    end

    missingFile = analysisRunFile(resultDir,'WFG7',10,10);
    delete(missingFile);
    analysis = analyze_ConfidenceProbe(resultDir, ...
        'BootstrapSamples',50,'BootstrapSeed',72);
    verifyEqual(testCase,analysis.summaryByM.ExpectedRunCount,50);
    verifyEqual(testCase,analysis.summaryByM.CompletedRunCount,49);
    verifyFalse(testCase,analysis.summaryByM.PrimaryDataComplete);
    verifyFalse(testCase,analysis.decision.PrimaryGatePassed);
    verifyEqual(testCase,analysis.decision.DecisionCode, ...
        "INSUFFICIENT_DATA");

    writeAnalysisRun(resultDir,'WFG7',10,10,'screening',true);
    analysis = analyze_ConfidenceProbe(resultDir, ...
        'BootstrapSamples',50,'BootstrapSeed',73);
    verifyEqual(testCase,analysis.summaryByM.CompletedRunCount,50);
    verifyEqual(testCase,analysis.summaryByM.ValidPrimaryRunCount,49);
    verifyEqual(testCase,analysis.summaryByM.ValidPrimaryProblemCount,4);
    verifyFalse(testCase,analysis.summaryByM.PrimaryDataComplete);
    verifyFalse(testCase,analysis.decision.PrimaryGatePassed);
    verifyEqual(testCase,analysis.decision.DecisionCode, ...
        "INSUFFICIENT_DATA");
end

function testProfileWithFewerThanFiveProblemsIsInsufficient(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);
    writeAnalysisRun(resultDir,'DTLZ2',3,1,'smoke',false);

    analysis = analyze_ConfidenceProbe(resultDir, ...
        'BootstrapSamples',20,'BootstrapSeed',74);
    verifyEqual(testCase,analysis.decision.ProblemCount,1);
    verifyFalse(testCase,analysis.decision.PrimaryGatePassed);
    verifyEqual(testCase,analysis.decision.DecisionCode, ...
        "INSUFFICIENT_PROBLEMS");
end

function testAnalyzerRejectsFileThatFullValidatorWouldBlock(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);
    writeAnalysisRun(resultDir,'DTLZ2',3,1,'smoke',false);
    file = analysisRunFile(resultDir,'DTLZ2',3,1);
    loaded = load(file);
    probe = loaded.confidenceProbe;
    predicted = column(probe,'networkPairRows','PredictedRelation');
    probe.networkPairRows(1,predicted) = -1;
    loaded.confidenceProbe = probe;
    saveLoadedRun(file,loaded);

    caught = [];
    try
        analyze_ConfidenceProbe(resultDir,'BootstrapSamples',10);
    catch exception
        caught = exception;
    end
    verifyNotEmpty(testCase,caught);
    verifySubstring(testCase,caught.message,file);
    verifySubstring(testCase,caught.message,'PredictedRelation');
end

function testAnalyzerRejectsMixedDuplicateAndUnmatchedJobs(testCase)
    mixedDir = tempname;
    duplicateDir = tempname;
    unmatchedDir = tempname;
    cleanup = onCleanup(@()removeTrees( ...
        {mixedDir,duplicateDir,unmatchedDir}));

    mkdir(mixedDir);
    writeAnalysisRun(mixedDir,'DTLZ2',3,1,'smoke',false);
    writeAnalysisRun(mixedDir,'DTLZ2',10,1,'pilot',false);
    caught = captureAnalysisError(mixedDir);
    verifyNotEmpty(testCase,caught);
    verifySubstring(testCase,caught.message,'profile');
    verifySubstring(testCase,caught.message,'.mat');

    mkdir(duplicateDir);
    writeAnalysisRun(duplicateDir,'DTLZ2',3,1,'smoke',false);
    original = analysisRunFile(duplicateDir,'DTLZ2',3,1);
    duplicateFolder = fullfile(duplicateDir,'duplicate');
    mkdir(duplicateFolder);
    duplicate = fullfile(duplicateFolder,'run_001.mat');
    copyfile(original,duplicate);
    caught = captureAnalysisError(duplicateDir);
    verifyNotEmpty(testCase,caught);
    verifySubstring(testCase,caught.message,'Duplicate');
    verifySubstring(testCase,caught.message,duplicate);

    mkdir(unmatchedDir);
    writeAnalysisRun(unmatchedDir,'DTLZ2',3,1,'smoke',false);
    unmatched = analysisRunFile(unmatchedDir,'DTLZ2',3,1);
    loaded = load(unmatched);
    loaded.metadata.jobID = 'not_a_protocol_job';
    saveLoadedRun(unmatched,loaded);
    caught = captureAnalysisError(unmatchedDir);
    verifyNotEmpty(testCase,caught);
    verifySubstring(testCase,caught.message,unmatched);
    verifySubstring(testCase,caught.message,'uniquely match');
end

function testRunnerRestoresRNGAndResumesWithoutOverwriting(testCase)
    outputDir = tempname;
    invalidOutputDir = tempname;
    cleanup = onCleanup(@()removeTrees({outputDir,invalidOutputDir}));
    mkdir(outputDir);

    rng(43210,'twister');
    callerState = rng;
    first = run_ConfidenceProbe_experiment('smoke',outputDir);
    verifyEqual(testCase,rng,callerState);
    verifyEqual(testCase,first.Status,"completed");
    resultFile = char(first.ResultFile);
    verifyTrue(testCase,isfile(resultFile));
    verifyEmpty(testCase,dir(fullfile(outputDir,'**','*.tmp.mat')));
    bytesBefore = readFileBytes(resultFile);

    rng(87654,'twister');
    resumeState = rng;
    second = run_ConfidenceProbe_experiment('smoke',outputDir);
    verifyEqual(testCase,rng,resumeState);
    verifyEqual(testCase,second.Status,"skipped");
    verifyEqual(testCase,readFileBytes(resultFile),bytesBefore);
    verifyEmpty(testCase,dir(fullfile(outputDir,'**','*.tmp.mat')));

    invalidFile = fullfile(invalidOutputDir,'smoke','DTLZ2','M3', ...
        'run_001.mat');
    mkdir(fileparts(invalidFile));
    marker = uint8('do not overwrite invalid run');
    fileID = fopen(invalidFile,'w');
    closeFile = onCleanup(@()fclose(fileID));
    fwrite(fileID,marker,'uint8');
    clear closeFile;
    invalidBytes = readFileBytes(invalidFile);

    rng(11223,'twister');
    blockState = rng;
    blocked = run_ConfidenceProbe_experiment('smoke',invalidOutputDir);
    verifyEqual(testCase,rng,blockState);
    verifyEqual(testCase,blocked.Status,"invalid-existing");
    verifyEqual(testCase,readFileBytes(invalidFile),invalidBytes);
    verifyEmpty(testCase,dir(fullfile( ...
        invalidOutputDir,'**','*.tmp.mat')));
end

function testRunnerSourceContainsResumeAndRNGSafetyContracts(testCase)
    source = fileread(fullfile(testCase.TestData.harnessDir, ...
        'run_ConfidenceProbe_experiment.m'));
    verifyTrue(testCase,contains(source,'onCleanup'));
    verifyTrue(testCase,contains(source,'ValidateConfidenceProbeResultFile'));
    verifyTrue(testCase,contains(source,"'-v7.3'"));
    verifyTrue(testCase,contains(source,'movefile'));
    verifyNotEmpty(testCase,regexp(source, ...
        'rng\s*\(\s*job\.Seed[\s\S]{0,100}Algorithm\.Solve\s*\(', ...
        'once'));
    verifyTrue(testCase,contains(source,'@silentOutput'));
end

function seed = seedFor(protocol,problem,M,run)
    row = protocol.jobs.Problem == string(problem) & ...
        protocol.jobs.M == M & protocol.jobs.Run == run;
    seed = unique(protocol.jobs.Seed(row));
end

function [metadata,probe,finalPopulation,IGD,IGDp,runtime] = ...
    validSyntheticRun(protocol,job)
    probe = syntheticProbe();
    metadata = matchingMetadata(protocol,job);
    ids = (1:job.MaxFE)';
    finalPopulation = repmat(struct('add',0),numel(ids),1);
    for i = 1:numel(ids)
        finalPopulation(i).add = ids(i);
    end
    IGD = 0.25;
    IGDp = 0.30;
    runtime = 1.5;
end

function metadata = matchingMetadata(protocol,job)
    metadata = struct( ...
        'schemaVersion',1, ...
        'profile',protocol.profile, ...
        'problem',char(job.Problem), ...
        'M',job.M, ...
        'requestedD',job.RequestedD, ...
        'actualD',job.ActualD, ...
        'N',job.N, ...
        'maxFE',job.MaxFE, ...
        'completedFE',job.MaxFE, ...
        'gmax',job.Gmax, ...
        'run',job.Run, ...
        'seed',job.Seed, ...
        'algorithmLabel',char(job.Algorithm), ...
        'algorithmClass',char(job.AlgorithmClass), ...
        'jobID',char(job.JobID));
end

function probe = syntheticProbe()
    probe = SDEConfidenceProbeSchema();
    solution = zeros(10,numel(probe.columns.solutionRows));
    solution(:,column(probe,'solutionRows','Generation')) = 1;
    solution(:,column(probe,'solutionRows','FE')) = 20;
    solution(:,column(probe,'solutionRows','EvalID')) = (1:10)';
    solution(:,column(probe,'solutionRows','RelationMode')) = 2;
    solution(:,column(probe,'solutionRows','CandidateMode')) = 1;
    solution(:,column(probe,'solutionRows','Catalog')) = ...
        [ones(5,1);zeros(5,1)];
    solution(:,column(probe,'solutionRows','PBIConfidence')) = ...
        repmat((0.1:0.1:0.5)',2,1);
    solution(:,column(probe,'solutionRows','SDEFitness')) = (10:-1:1)';
    solution(:,column(probe,'solutionRows','CurrentND')) = 1;
    solution(:,column(probe,'solutionRows','SurviveH1')) = ...
        [0;0;0;1;1;1;1;1;0;0];
    solution(:,column(probe,'solutionRows','SurviveH3')) = ...
        [0;0;0;1;1;1;1;1;0;0];
    solution(:,column(probe,'solutionRows','FinalND')) = ...
        [0;0;0;1;1;1;1;1;0;0];
    probe.solutionRows = solution;

    pair = zeros(10,numel(probe.columns.pbiPairRows));
    pair(:,column(probe,'pbiPairRows','Generation')) = 1;
    pair(:,column(probe,'pbiPairRows','FE')) = 20;
    pair(:,column(probe,'pbiPairRows','LeftEvalID')) = (1:10)';
    pair(:,column(probe,'pbiPairRows','RightEvalID')) = (11:20)';
    pair(:,column(probe,'pbiPairRows','PairType')) = 3;
    pair(:,column(probe,'pbiPairRows','PredictedRelation')) = 1;
    pair(:,column(probe,'pbiPairRows','PairConfidence')) = (0.1:0.1:1)';
    pair(:,column(probe,'pbiPairRows','ParetoRelation')) = ...
        [-ones(5,1);ones(5,1)];
    pair(:,column(probe,'pbiPairRows','SDERelation')) = ...
        [-ones(5,1);ones(5,1)];
    pair(:,column(probe,'pbiPairRows','LeftSurviveH1')) = 1;
    pair(:,column(probe,'pbiPairRows','RightSurviveH1')) = 0;
    pair(:,column(probe,'pbiPairRows','LeftSurviveH3')) = nan;
    pair(:,column(probe,'pbiPairRows','RightSurviveH3')) = nan;
    pair(:,column(probe,'pbiPairRows','LeftFinalND')) = 1;
    pair(:,column(probe,'pbiPairRows','RightFinalND')) = 0;
    probe.pbiPairRows = pair;

    network = zeros(10,numel(probe.columns.networkPairRows));
    network(:,column(probe,'networkPairRows','Generation')) = 1;
    network(:,column(probe,'networkPairRows','FE')) = 20;
    network(:,column(probe,'networkPairRows','CandidateEvalID')) = (21:30)';
    network(:,column(probe,'networkPairRows','AnchorEvalID')) = (1:10)';
    network(:,column(probe,'networkPairRows','AnchorCatalog')) = 1;
    network(:,column(probe,'networkPairRows','PredictedRelation')) = 1;
    leftProbability = linspace(0.40,0.94,10)';
    otherProbability = (1-leftProbability)/2;
    network(:,column(probe,'networkPairRows','ProbabilityLeftBetter')) = ...
        leftProbability;
    network(:,column(probe,'networkPairRows','ProbabilitySame')) = ...
        otherProbability;
    network(:,column(probe,'networkPairRows','ProbabilityRightBetter')) = ...
        otherProbability;
    network(:,column(probe,'networkPairRows','NetworkConfidence')) = ...
        leftProbability;
    network(:,column(probe,'networkPairRows','ParetoRelation')) = ...
        [-ones(5,1);ones(5,1)];
    network(:,column(probe,'networkPairRows','SDERelation')) = ...
        [-ones(5,1);ones(5,1)];
    network(:,column(probe,'networkPairRows','CandidateSurviveH1')) = ...
        [zeros(5,1);ones(5,1)];
    network(:,column(probe,'networkPairRows','CandidateSurviveH3')) = ...
        [zeros(5,1);ones(5,1)];
    network(:,column(probe,'networkPairRows','CandidateFinalND')) = ...
        [zeros(5,1);ones(5,1)];
    probe.networkPairRows = network;

    candidate = zeros(10,numel(probe.columns.candidateRows));
    candidate(:,column(probe,'candidateRows','Generation')) = 1;
    candidate(:,column(probe,'candidateRows','FE')) = 20;
    candidate(:,column(probe,'candidateRows','EvalID')) = (21:30)';
    candidate(:,column(probe,'candidateRows','RelationMode')) = 2;
    candidate(:,column(probe,'candidateRows','CandidateMode')) = 1;
    candidate(:,column(probe,'candidateRows','NetworkConfidence')) = ...
        leftProbability;
    candidate(:,column(probe,'candidateRows','PredictedBetterRate')) = ...
        (0.1:0.1:1)';
    candidate(:,column(probe,'candidateRows','DominatesAny')) = ...
        [zeros(5,1);ones(5,1)];
    candidate(:,column(probe,'candidateRows','DominatedByAny')) = ...
        [ones(5,1);zeros(5,1)];
    candidate(:,column(probe,'candidateRows','IsNondominated')) = ...
        [zeros(5,1);ones(5,1)];
    candidate(:,column(probe,'candidateRows','MarginalIGD')) = ...
        [zeros(5,1);ones(5,1)];
    candidate(:,column(probe,'candidateRows','MarginalIGDPositive')) = ...
        [zeros(5,1);ones(5,1)];
    candidate(:,column(probe,'candidateRows','SurviveH1')) = ...
        [zeros(5,1);ones(5,1)];
    candidate(:,column(probe,'candidateRows','SurviveH3')) = ...
        [zeros(5,1);ones(5,1)];
    candidate(:,column(probe,'candidateRows','ArchiveNDNext')) = ...
        [zeros(5,1);ones(5,1)];
    candidate(:,column(probe,'candidateRows','FinalND')) = ...
        [zeros(5,1);ones(5,1)];
    probe.candidateRows = candidate;
end

function writeAnalysisRun(rootDir,problem,M,run,profile,flatPrimary)
    if nargin < 5
        profile = 'screening';
    end
    if nargin < 6
        flatPrimary = false;
    end
    probe = syntheticProbe();
    % Add one incomparable same-group PBI row per run. It must not enter
    % the Pareto correctness denominator.
    incomparable = probe.pbiPairRows(1,:);
    incomparable(column(probe,'pbiPairRows','PairType')) = 1;
    incomparable(column(probe,'pbiPairRows','PredictedRelation')) = 0;
    incomparable(column(probe,'pbiPairRows','ParetoRelation')) = 0;
    incomparable(column(probe,'pbiPairRows','SDERelation')) = 0;
    probe.pbiPairRows = [probe.pbiPairRows;incomparable];

    if flatPrimary
        goodRest = probe.pbiPairRows(:, ...
            column(probe,'pbiPairRows','PairType')) == ...
            probe.codes.pairType.goodRest;
        probe.pbiPairRows(goodRest, ...
            column(probe,'pbiPairRows','ParetoRelation')) = 1;
    end

    protocol = ConfidenceProbeProtocol(profile);
    match = protocol.jobs.Problem == string(problem) & ...
        protocol.jobs.M == M & protocol.jobs.Run == run;
    if sum(match) ~= 1
        error('Synthetic test job does not match protocol.');
    end
    job = protocol.jobs(match,:);
    metadata = matchingMetadata(protocol,job);
    confidenceProbe = probe;
    IGD = 1;
    IGDp = 1;
    runtime = 1;
    ids = (1:job.MaxFE)';
    finalPopulation = repmat(struct('add',0),numel(ids),1);
    for i = 1:numel(ids)
        finalPopulation(i).add = ids(i);
    end
    folder = fullfile(rootDir,problem,sprintf('M%d',M));
    if ~isfolder(folder)
        mkdir(folder);
    end
    save(fullfile(folder,sprintf('run_%03d.mat',run)), ...
        'metadata','confidenceProbe','IGD','IGDp','runtime', ...
        'finalPopulation');
end

function file = analysisRunFile(rootDir,problem,M,run)
    file = fullfile(rootDir,problem,sprintf('M%d',M), ...
        sprintf('run_%03d.mat',run));
end

function saveLoadedRun(file,loaded)
    metadata = loaded.metadata;
    confidenceProbe = loaded.confidenceProbe;
    finalPopulation = loaded.finalPopulation;
    IGD = loaded.IGD;
    IGDp = loaded.IGDp;
    runtime = loaded.runtime;
    save(file,'metadata','confidenceProbe','finalPopulation', ...
        'IGD','IGDp','runtime');
end

function index = column(probe,tableName,columnName)
    index = find(strcmp(probe.columns.(tableName),columnName),1);
end

function saveRun(file,metadata,confidenceProbe,finalPopulation, ...
    IGD,IGDp,runtime)
    save(file,'metadata','confidenceProbe','finalPopulation', ...
        'IGD','IGDp','runtime');
end

function moveVariableFile(file,~,confidenceProbe,finalPopulation, ...
    IGD,IGDp,runtime,fieldName)
    loaded = load(file,'staleMetadata');
    metadata = loaded.staleMetadata;
    if ~strcmp(fieldName,'seed')
        error('Unexpected test field.');
    end
    saveRun(file,metadata,confidenceProbe,finalPopulation,IGD,IGDp,runtime);
end

function caught = captureAnalysisError(resultDir)
    caught = [];
    try
        analyze_ConfidenceProbe(resultDir,'BootstrapSamples',5);
    catch exception
        caught = exception;
    end
end

function bytes = readFileBytes(file)
    fileID = fopen(file,'r');
    if fileID < 0
        error('Cannot read test file: %s',file);
    end
    closeFile = onCleanup(@()fclose(fileID));
    bytes = fread(fileID,inf,'*uint8');
end

function removeTrees(paths)
    for i = 1:numel(paths)
        removeTree(paths{i});
    end
end

function removeTree(pathName)
    if isfolder(pathName)
        rmdir(pathName,'s');
    end
end
