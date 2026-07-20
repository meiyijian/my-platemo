function tests = test_CPRExperimentHarness
% Unit tests for the CPR experiment protocol and screening analysis.

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    harnessDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(harnessDir);
    testCase.TestData.harnessDir = harnessDir;
end

function testScreeningProtocolMatrixAndPairedSeeds(testCase)
    protocol = CPRExperimentProtocol('screening');

    verifyEqual(testCase,protocol.profile,'screening');
    verifyEqual(testCase,protocol.problems, ...
        {'DTLZ2','DTLZ4','DTLZ7','WFG2','WFG3','WFG5','WFG7','WFG8'});
    verifyEqual(testCase,protocol.objectives,[10,20]);
    verifyEqual(testCase,protocol.maxFE,500);
    verifyEqual(testCase,protocol.runs,10);
    verifyEqual(testCase,protocol.algorithmLabels,{'U0','F00','F10','F01','F11'});
    verifyEqual(testCase,height(protocol.jobs),8*2*10*5);

    wfg23 = ismember(protocol.jobs.Problem,["WFG2","WFG3"]);
    verifyTrue(testCase,all(protocol.jobs.RequestedD == 30));
    verifyTrue(testCase,all(protocol.jobs.ActualD(wfg23) == 31));
    verifyTrue(testCase,all(protocol.jobs.ActualD(~wfg23) == 30));

    key = protocol.jobs.Problem == "DTLZ2" & protocol.jobs.M == 10 & ...
        protocol.jobs.Run == 3;
    verifyEqual(testCase,numel(unique(protocol.jobs.Seed(key))),1);
    verifyEqual(testCase,sum(key),5);
end

function testFormalExtremeAndMicroProfilesRemainSeparate(testCase)
    formal = CPRExperimentProtocol('formal');
    extreme = CPRExperimentProtocol('extreme');
    micro = CPRExperimentProtocol('micro');

    verifyEqual(testCase,numel(formal.problems),16);
    verifyEqual(testCase,formal.maxFE,500);
    verifyEqual(testCase,formal.runs,30);
    verifyEqual(testCase,height(formal.jobs),16*2*30*8);
    verifyEqual(testCase,formal.resultBudgetFolder,'FE500');
    verifyFalse(testCase,formal.autoExecute);
    verifyEqual(testCase,formal.comparisonAlgorithmLabels,{'REMO','PIEA','PCSAEA'});
    verifyEqual(testCase,formal.comparisonAlgorithmClasses,{'REMO','PIEA','PCSAEA'});

    verifyEqual(testCase,extreme.maxFE,300);
    verifyEqual(testCase,extreme.resultBudgetFolder,'FE300');
    verifyEqual(testCase,height(extreme.jobs),8*2*10*5);

    verifyEqual(testCase,micro.algorithmLabels, ...
        {'F11','F11_HardVote','F11_Regression'});
    verifyEqual(testCase,micro.problems,{'DTLZ2','DTLZ7','WFG3','WFG7'});

    seedScreening = pairedSeedFor(CPRExperimentProtocol('screening'),'DTLZ2',10,1);
    seedFormal = pairedSeedFor(formal,'DTLZ2',10,1);
    seedExtreme = pairedSeedFor(extreme,'DTLZ2',10,1);
    verifyEqual(testCase,seedScreening,seedFormal);
    verifyEqual(testCase,seedScreening,seedExtreme);
end

function testInvalidProfileIsRejected(testCase)
    verifyError(testCase,@()CPRExperimentProtocol('unknown'), ...
        'AdaMaO:UnknownCPRExperimentProfile');
end

function testRunnerRejectsInvalidProfileBeforeCreatingOutput(testCase)
    outputDir = tempname;
    verifyError(testCase,@()run_CPR_experiment('unknown',outputDir), ...
        'AdaMaO:UnknownCPRExperimentProfile');
    verifyFalse(testCase,isfolder(outputDir));
end

function testCompletedResultValidationRejectsCorruptAndStaleFiles(testCase)
    protocol = CPRExperimentProtocol('screening');
    job = protocol.jobs(1,:);
    folder = tempname;
    cleanup = onCleanup(@()removeTree(folder));
    mkdir(folder);
    validFile = fullfile(folder,'valid.mat');
    corruptFile = fullfile(folder,'corrupt.mat');

    metadata = matchingMetadata(protocol,job);
    IGD = 1;
    IGDp = 1.1;
    runtime = 2;
    finalPopulation = struct('objs',zeros(1,job.M));
    save(validFile,'metadata','IGD','IGDp','runtime','finalPopulation');
    [valid,message,metrics] = ValidateCPRResultFile(validFile,protocol,job);
    verifyTrue(testCase,valid,message);
    verifyEqual(testCase,[metrics.IGD,metrics.IGDp,metrics.runtime],[1,1.1,2]);

    metadata.seed = metadata.seed + 1;
    save(validFile,'metadata','IGD','IGDp','runtime','finalPopulation');
    [valid,message] = ValidateCPRResultFile(validFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'seed');

    fileID = fopen(corruptFile,'w');
    fprintf(fileID,'not a MAT file');
    fclose(fileID);
    [valid,message] = ValidateCPRResultFile(corruptFile,protocol,job);
    verifyFalse(testCase,valid);
    verifyNotEmpty(testCase,message);

    metadata = matchingMetadata(protocol,job);
    IGD = [1;2];
    IGDp = 1;
    runtime = 1;
    save(validFile,'metadata','IGD','IGDp','runtime','finalPopulation');
    [valid,message] = ValidateCPRResultFile(validFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'IGD');

    IGD = 1;
    IGDp = 'a';
    save(validFile,'metadata','IGD','IGDp','runtime','finalPopulation');
    [valid,message] = ValidateCPRResultFile(validFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'IGDp');

    IGDp = 1;
    runtime = [1,2];
    save(validFile,'metadata','IGD','IGDp','runtime','finalPopulation');
    [valid,message] = ValidateCPRResultFile(validFile,protocol,job);
    verifyFalse(testCase,valid);
    verifySubstring(testCase,message,'runtime');
end

function testScreeningAnalysisUsesPairedRunsAndKeepsObjectivesSeparate(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);

    problems = {'DTLZ2','DTLZ4','DTLZ7','WFG2','WFG3','WFG5','WFG7','WFG8'};
    objectives = [10,20];
    ratios10 = struct('F00',1.30,'F10',0.99,'F01',1.02,'F11',0.95);
    ratios20 = struct('F00',1.30,'F10',0.99,'F01',1.02,'F11',1.10);
    for m = objectives
        for p = 1:numel(problems)
            for run = 1:10
                baseline = 1 + 0.01*run + 0.001*p;
                writeSyntheticResult(resultDir,problems{p},m,run,'U0',baseline);
                labels = fieldnames(ratios10);
                for a = 1:numel(labels)
                    if m == 10
                        ratio = ratios10.(labels{a});
                    else
                        ratio = ratios20.(labels{a});
                    end
                    writeSyntheticResult(resultDir,problems{p},m,run, ...
                        labels{a},baseline*ratio);
                end
            end
        end
    end
    writeScreeningNoise(resultDir,'noise_seed','DTLZ2',10,1,'F11',999,false,false);
    writeScreeningNoise(resultDir,'noise_problem','DTLZ1',10,1,'F11',0,false,false);
    writeScreeningNoise(resultDir,'noise_dimension','WFG2',10,2,'F10',0,true,false);
    writeScreeningNoise(resultDir,'noise_class','DTLZ2',10,2,'F01',0,false,true);

    analysis = analyze_CPR_screening(resultDir);

    verifyEqual(testCase,analysis.completedRunCount,8*2*10*5);
    verifyEqual(testCase,sort(unique(analysis.perProblem.M))',[10,20]);
    verifyEqual(testCase,height(analysis.perProblem),64);
    verifyEqual(testCase,height(analysis.byFamily),16);

    row = analysis.perProblem.Algorithm == "F11" & ...
        analysis.perProblem.Problem == "DTLZ2" & analysis.perProblem.M == 10;
    verifyEqual(testCase,analysis.perProblem.GeoMeanRatio(row),0.95,'AbsTol',1e-12);

    pass10 = analysis.decision.M == 10;
    pass20 = analysis.decision.M == 20;
    verifyEqual(testCase,analysis.decision.Code(pass10), ...
        "F11_CANDIDATE_REQUIRES_STABLE_GAIN_CHECK");
    verifyEqual(testCase,analysis.decision.Code(pass20), ...
        "F01_ENGINEERING_ONLY");

    severe = analysis.byFamily.Algorithm == "F00";
    verifyTrue(testCase,all(analysis.byFamily.SevereRegressionCount(severe) >= 2));
    verifyTrue(testCase,isfile(fullfile(resultDir,'CPR_screening_per_problem.csv')));
    verifyTrue(testCase,isfile(fullfile(resultDir,'CPR_screening_by_family.csv')));
    verifyTrue(testCase,isfile(fullfile(resultDir,'CPR_screening_decision.csv')));
end

function testScreeningDecisionRejectsIncompletePairedRuns(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);
    problems = {'DTLZ2','DTLZ4','DTLZ7','WFG2','WFG3','WFG5','WFG7','WFG8'};
    for p = 1:numel(problems)
        for run = 1:2
            baseline = 1 + 0.01*run;
            writeSyntheticResult(resultDir,problems{p},10,run,'U0',baseline);
            writeSyntheticResult(resultDir,problems{p},10,run,'F01',0.9*baseline);
            writeSyntheticResult(resultDir,problems{p},10,run,'F11',0.9*baseline);
        end
    end

    analysis = analyze_CPR_screening(resultDir);

    row = analysis.decision.M == 10;
    verifyEqual(testCase,analysis.decision.Code(row),"RETAIN_U0_REJECT_DIRECTION");
    complete = analysis.byFamily.M == 10 & ...
        ismember(analysis.byFamily.Algorithm,["F01","F11"]);
    verifyFalse(testCase,any(analysis.byFamily.Complete(complete)));
end

function testScreeningFamilyBootstrapRetainsSeedUncertainty(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);
    problems = {'DTLZ2','DTLZ4','DTLZ7','WFG2','WFG3','WFG5','WFG7','WFG8'};
    for p = 1:numel(problems)
        for run = 1:10
            if mod(run,2) == 1
                ratio = 0.1;
            else
                ratio = 10;
            end
            writeSyntheticResult(resultDir,problems{p},10,run,'U0',1);
            writeSyntheticResult(resultDir,problems{p},10,run,'F01',ratio);
            writeSyntheticResult(resultDir,problems{p},10,run,'F11',ratio);
        end
    end

    analysis = analyze_CPR_screening(resultDir);

    rows = analysis.byFamily.M == 10 & analysis.byFamily.Algorithm == "F01";
    verifyTrue(testCase,all(analysis.byFamily.CILower(rows) < 1));
    verifyTrue(testCase,all(analysis.byFamily.CIUpper(rows) > 1.05));
    verifyFalse(testCase,any(analysis.byFamily.PassNonInferiority(rows)));
    decision = analysis.decision.M == 10;
    verifyEqual(testCase,analysis.decision.Code(decision), ...
        "RETAIN_U0_REJECT_DIRECTION");
end

function testFormalAnalysisUsesThirtyPairsHolmAndSeedLevelInteraction(testCase)
    resultDir = tempname;
    cleanup = onCleanup(@()removeTree(resultDir));
    mkdir(resultDir);
    ratios10 = struct('F00',1.10,'F10',0.95,'F01',1.05,'F11',0.80);
    ratios20 = struct('F00',1.20,'F10',1.10,'F01',0.90,'F11',1.02);
    labels = fieldnames(ratios10);
    for M = [10,20]
        for run = 1:30
            baselineIGD = 1 + 0.01*run;
            baselineIGDp = 1.2 + 0.015*run;
            writeFormalResult(resultDir,'DTLZ1',M,run,'U0', ...
                baselineIGD,baselineIGDp,'formal');
            for index = 1:numel(labels)
                if M == 10
                    ratio = ratios10.(labels{index});
                else
                    ratio = ratios20.(labels{index});
                end
                writeFormalResult(resultDir,'DTLZ1',M,run,labels{index}, ...
                    baselineIGD*ratio,baselineIGDp*ratio,'formal');
            end
        end
    end
    for run = 1:29
        baselineIGD = 2 + 0.01*run;
        baselineIGDp = 2.5 + 0.01*run;
        writeFormalResult(resultDir,'DTLZ2',10,run,'U0', ...
            baselineIGD,baselineIGDp,'formal');
        writeFormalResult(resultDir,'DTLZ2',10,run,'F11', ...
            0.9*baselineIGD,0.9*baselineIGDp,'formal');
    end
    writeFormalResult(resultDir,'DTLZ1',10,1,'F11',999,999,'screening');
    writeFormalNoise(resultDir,'formal_noise_seed','DTLZ1',10,1,'F11',999,false,false);
    writeFormalNoise(resultDir,'formal_noise_dimension','WFG2',10,1,'F00',0,true,false);
    writeFormalNoise(resultDir,'formal_noise_class','DTLZ1',10,2,'F01',0,false,true);

    analysis = analyze_CPR_formal(resultDir);

    verifyEqual(testCase,analysis.completedRunCount,358);
    verifyEqual(testCase,height(analysis.pairwise),16*2*7);
    verifyEqual(testCase,height(analysis.interaction),16*2);
    row10 = analysis.pairwise.Problem == "DTLZ1" & ...
        analysis.pairwise.M == 10 & analysis.pairwise.Algorithm == "F11";
    row20 = analysis.pairwise.Problem == "DTLZ1" & ...
        analysis.pairwise.M == 20 & analysis.pairwise.Algorithm == "F11";
    verifyTrue(testCase,analysis.pairwise.CompleteIGD(row10));
    verifyEqual(testCase,analysis.pairwise.PairCountIGD(row10),30);
    verifyEqual(testCase,analysis.pairwise.IGDGeoMeanRatio(row10),0.80,'AbsTol',1e-12);
    verifyEqual(testCase,analysis.pairwise.IGDGeoMeanRatio(row20),1.02,'AbsTol',1e-12);
    verifyGreaterThanOrEqual(testCase,analysis.pairwise.IGDAdjustedP(row10), ...
        analysis.pairwise.IGDRawP(row10));
    verifyEqual(testCase,analysis.pairwise.IGDpGeoMeanRatio(row10),0.80,'AbsTol',1e-12);

    partial = analysis.pairwise.Problem == "DTLZ2" & ...
        analysis.pairwise.M == 10 & analysis.pairwise.Algorithm == "F11";
    verifyEqual(testCase,analysis.pairwise.PairCountIGD(partial),29);
    verifyFalse(testCase,analysis.pairwise.CompleteIGD(partial));
    verifyTrue(testCase,isnan(analysis.pairwise.IGDRawP(partial)));
    verifyTrue(testCase,isnan(analysis.pairwise.IGDCILower(partial)));

    interaction = analysis.interaction.Problem == "DTLZ1" & ...
        analysis.interaction.M == 10;
    expected = log(0.80)-log(0.95)-log(1.05)+log(1.10);
    verifyTrue(testCase,analysis.interaction.CompleteIGD(interaction));
    verifyEqual(testCase,analysis.interaction.PairCountIGD(interaction),30);
    verifyEqual(testCase,analysis.interaction.IGDMeanInteraction(interaction), ...
        expected,'AbsTol',1e-12);
    verifyTrue(testCase,isfinite(analysis.interaction.IGDRawP(interaction)));

    summary10 = analysis.completeness.M == 10;
    verifyEqual(testCase,analysis.completeness.CompleteIGDComparisons(summary10),4);
    verifyEqual(testCase,analysis.completeness.PlannedComparisons(summary10),112);
    verifyEqual(testCase,analysis.completeness.CompleteIGDInteractions(summary10),1);
    verifyFalse(testCase,analysis.completeness.FullIGDMatrix(summary10));

    verifyTrue(testCase,isfile(fullfile(resultDir,'CPR_formal_pairwise.csv')));
    verifyTrue(testCase,isfile(fullfile(resultDir,'CPR_formal_interaction.csv')));
    verifyTrue(testCase,isfile(fullfile(resultDir,'CPR_formal_completeness.csv')));
    verifyTrue(testCase,isfile(fullfile(resultDir,'CPR_formal_analysis.mat')));
end

function seed = pairedSeedFor(protocol,problem,M,run)
    row = protocol.jobs.Problem == string(problem) & protocol.jobs.M == M & ...
        protocol.jobs.Run == run;
    seed = unique(protocol.jobs.Seed(row));
end

function writeSyntheticResult(rootDir,problem,M,run,label,igd)
    seed = stableSyntheticSeed(problem,M,run);
    metadata = struct( ...
        'profile','screening', ...
        'problem',problem, ...
        'M',M, ...
        'run',run, ...
        'seed',seed, ...
        'algorithmLabel',label, ...
        'algorithmClass',algorithmClassForLabel(label), ...
        'maxFE',500);
    IGD = igd;
    IGDp = igd;
    runtime = 0;
    finalPopulation = struct('objs',zeros(0,M));
    folder = fullfile(rootDir,problem,sprintf('M%d',M),label);
    if ~isfolder(folder)
        mkdir(folder);
    end
    save(fullfile(folder,sprintf('run_%03d.mat',run)), ...
        'metadata','IGD','IGDp','runtime','finalPopulation');
end

function metadata = matchingMetadata(protocol,job)
    metadata = struct( ...
        'profile',protocol.profile, ...
        'problem',char(job.Problem), ...
        'M',job.M, ...
        'requestedD',job.RequestedD, ...
        'actualD',job.ActualD, ...
        'run',job.Run, ...
        'seed',job.Seed, ...
        'algorithmLabel',char(job.Algorithm), ...
        'algorithmClass',char(job.AlgorithmClass), ...
        'maxFE',protocol.maxFE);
end

function writeFormalResult(rootDir,problem,M,run,label,igd,igdp,profile)
    seed = stableSyntheticSeed(problem,M,run);
    metadata = struct( ...
        'profile',profile, ...
        'problem',problem, ...
        'M',M, ...
        'run',run, ...
        'seed',seed, ...
        'algorithmLabel',label, ...
        'algorithmClass',algorithmClassForLabel(label), ...
        'maxFE',500);
    IGD = igd;
    IGDp = igdp;
    runtime = 0;
    finalPopulation = struct('objs',zeros(0,M));
    folder = fullfile(rootDir,profile,problem,sprintf('M%d',M),label);
    if ~isfolder(folder)
        mkdir(folder);
    end
    save(fullfile(folder,sprintf('run_%03d.mat',run)), ...
        'metadata','IGD','IGDp','runtime','finalPopulation');
end

function writeScreeningNoise(rootDir,folderName,problem,M,run,label,seedOffset,wrongD,wrongClass)
    seed = stableSyntheticSeed(problem,M,run) + seedOffset;
    actualD = 30;
    if ismember(problem,{'WFG2','WFG3'})
        actualD = 31;
    end
    if wrongD
        actualD = actualD - 1;
    end
    metadata = struct( ...
        'profile','screening', ...
        'problem',problem, ...
        'M',M, ...
        'requestedD',30, ...
        'actualD',actualD, ...
        'run',run, ...
        'seed',seed, ...
        'algorithmLabel',label, ...
        'algorithmClass',noiseAlgorithmClass(label,wrongClass), ...
        'maxFE',500);
    IGD = 1;
    IGDp = 1;
    folder = fullfile(rootDir,folderName);
    mkdir(folder);
    save(fullfile(folder,sprintf('run_%03d.mat',run)),'metadata','IGD','IGDp');
end

function writeFormalNoise(rootDir,folderName,problem,M,run,label,seedOffset,wrongD,wrongClass)
    seed = stableSyntheticSeed(problem,M,run) + seedOffset;
    actualD = 30;
    if ismember(problem,{'WFG2','WFG3'})
        actualD = 31;
    end
    if wrongD
        actualD = actualD - 1;
    end
    metadata = struct( ...
        'profile','formal', ...
        'problem',problem, ...
        'M',M, ...
        'requestedD',30, ...
        'actualD',actualD, ...
        'run',run, ...
        'seed',seed, ...
        'algorithmLabel',label, ...
        'algorithmClass',noiseAlgorithmClass(label,wrongClass), ...
        'maxFE',500);
    IGD = 1;
    IGDp = 1;
    folder = fullfile(rootDir,folderName);
    mkdir(folder);
    save(fullfile(folder,sprintf('run_%03d.mat',run)),'metadata','IGD','IGDp');
end

function className = noiseAlgorithmClass(label,wrongClass)
    if wrongClass
        className = ['Wrong_',label];
    else
        className = algorithmClassForLabel(label);
    end
end

function className = algorithmClassForLabel(label)
    switch label
        case 'U0'
            className = 'REMO_new2_AdaMaO_SDEOnly_UniformMix';
        case {'F00','F10','F01','F11'}
            className = ['REMO_new2_AdaMaO_CPR_',label];
        otherwise
            className = label;
    end
end

function seed = stableSyntheticSeed(problem,M,run)
    number = str2double(regexprep(problem,'\D',''));
    if startsWith(problem,'DTLZ')
        family = 1;
    else
        family = 2;
    end
    seed = family*1000000 + number*10000 + M*100 + run;
end

function removeTree(pathName)
    if isfolder(pathName)
        rmdir(pathName,'s');
    end
end
