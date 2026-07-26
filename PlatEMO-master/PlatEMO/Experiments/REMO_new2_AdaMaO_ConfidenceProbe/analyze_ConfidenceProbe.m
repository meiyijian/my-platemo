function analysis = analyze_ConfidenceProbe(resultDir,varargin)
%ANALYZE_CONFIDENCEPROBE Analyze independent confidence-validity outcomes.
%   The primary decision uses only good-rest PBI pairs. Network confidence,
%   candidate outcomes, and solution survival are reported as auxiliary
%   diagnostics and are never pooled into the PBI decision.

    parser = inputParser;
    parser.FunctionName = mfilename;
    addRequired(parser,'resultDir',@(x)ischar(x) || ...
        (isstring(x) && isscalar(x)));
    addParameter(parser,'OutputDir','',@(x)ischar(x) || ...
        (isstring(x) && isscalar(x)));
    addParameter(parser,'BootstrapSamples',10000,@(x)isnumeric(x) && ...
        isscalar(x) && isfinite(x) && x >= 1 && x == floor(x));
    addParameter(parser,'BootstrapSeed',20260726,@(x)isnumeric(x) && ...
        isscalar(x) && isfinite(x));
    parse(parser,resultDir,varargin{:});

    resultDir = char(parser.Results.resultDir);
    if ~isfolder(resultDir)
        error('AdaMaO:ConfidenceProbeResultDirectoryMissing', ...
            'Result directory does not exist: %s.',resultDir);
    end
    outputDir = char(parser.Results.OutputDir);
    if isempty(outputDir)
        outputDir = resultDir;
    end
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end
    bootstrapSamples = double(parser.Results.BootstrapSamples);
    bootstrapSeed = double(parser.Results.BootstrapSeed);

    [records,protocol] = loadRecords(resultDir);
    assertUniqueRuns(records);
    stream = RandStream('mt19937ar','Seed',bootstrapSeed);

    pbiPairBins = concatenateRecordTables(records,@aggregatePBIPairs);
    solutionBins = concatenateRecordTables(records,@aggregateSolutions);
    networkPairBins = concatenateRecordTables( ...
        records,@aggregateNetworkPairs);
    candidateBins = concatenateRecordTables(records,@aggregateCandidates);
    runMetrics = buildRunMetrics(records);
    summaryByProblem = summarizeProblems( ...
        runMetrics,protocol,bootstrapSamples,stream);
    summaryByM = summarizeObjectives( ...
        runMetrics,summaryByProblem,protocol,bootstrapSamples,stream);
    decision = makeDecision(summaryByM);

    outputFiles = { ...
        'Confidence_PBI_pair_bins.csv',pbiPairBins; ...
        'Confidence_PBI_solution_bins.csv',solutionBins; ...
        'Confidence_network_pair_bins.csv',networkPairBins; ...
        'Confidence_candidate_bins.csv',candidateBins; ...
        'Confidence_summary_by_problem.csv',summaryByProblem; ...
        'Confidence_summary_by_M.csv',summaryByM; ...
        'Confidence_decision.csv',decision};
    for i = 1:size(outputFiles,1)
        writetable(outputFiles{i,2},fullfile(outputDir,outputFiles{i,1}));
    end

    analysis = struct();
    analysis.schemaVersion = 1;
    analysis.resultDir = resultDir;
    analysis.outputDir = outputDir;
    analysis.bootstrapSamples = bootstrapSamples;
    analysis.bootstrapSeed = bootstrapSeed;
    analysis.completedRunCount = numel(records);
    analysis.expectedRunCount = height(protocol.jobs);
    analysis.profile = protocol.profile;
    analysis.pbiPairBins = pbiPairBins;
    analysis.solutionBins = solutionBins;
    analysis.networkPairBins = networkPairBins;
    analysis.candidateBins = candidateBins;
    analysis.runMetrics = runMetrics;
    analysis.summaryByProblem = summaryByProblem;
    analysis.summaryByM = summaryByM;
    analysis.decision = decision;
    save(fullfile(outputDir,'Confidence_analysis.mat'), ...
        'analysis','-v7.3');
end

function [records,protocol] = loadRecords(resultDir)
    files = dir(fullfile(resultDir,'**','run_*.mat'));
    if isempty(files)
        files = dir(fullfile(resultDir,'run_*.mat'));
    end
    if ~isempty(files)
        exactName = arrayfun(@(entry) ...
            ~isempty(regexp(entry.name,'^run_[0-9]{3}\.mat$','once')), ...
            files);
        files = files(exactName);
    end
    if isempty(files)
        error('AdaMaO:NoConfidenceProbeRuns', ...
            'No exact run_NNN.mat files were found beneath %s.',resultDir);
    end
    if isempty(files)
        error('AdaMaO:NoConfidenceProbeRuns', ...
            'No run_*.mat files were found beneath %s.',resultDir);
    end
    fullNames = arrayfun(@(entry)fullfile(entry.folder,entry.name), ...
        files,'UniformOutput',false);
    [~,order] = sort(fullNames);
    files = files(order);
    records = repmat(struct( ...
        'file','','metadata',struct(),'probe',struct()),numel(files),1);
    protocol = [];
    for i = 1:numel(files)
        file = fullfile(files(i).folder,files(i).name);
        try
            metadataOnly = load(file,'metadata');
        catch exception
            error('AdaMaO:UnreadableConfidenceProbeRun', ...
                'Cannot read %s: %s',file,exception.message);
        end
        if ~isfield(metadataOnly,'metadata') || ...
                ~isstruct(metadataOnly.metadata) || ...
                ~isscalar(metadataOnly.metadata) || ...
                ~isfield(metadataOnly.metadata,'profile')
            error('AdaMaO:InvalidConfidenceProbeRun', ...
                '%s is missing scalar metadata.profile.',file);
        end
        profile = char(string(metadataOnly.metadata.profile));
        if isempty(protocol)
            try
                protocol = ConfidenceProbeProtocol(profile);
            catch exception
                error('AdaMaO:InvalidConfidenceProbeAnalysisRun', ...
                    '%s has unsupported profile %s: %s', ...
                    file,profile,exception.message);
            end
        elseif ~strcmp(protocol.profile,profile)
            error('AdaMaO:MixedConfidenceProbeProfiles', ...
                '%s has profile %s, expected %s.', ...
                file,profile,protocol.profile);
        end
        jobMask = matchingJob(protocol.jobs,metadataOnly.metadata);
        if sum(jobMask) ~= 1
            error('AdaMaO:UnmatchedConfidenceProbeJob', ...
                '%s does not uniquely match one %s protocol job.', ...
                file,protocol.profile);
        end
        job = protocol.jobs(jobMask,:);
        [valid,message] = ValidateConfidenceProbeResultFile( ...
            file,protocol,job);
        if ~valid
            error('AdaMaO:InvalidConfidenceProbeAnalysisRun', ...
                '%s failed full result validation: %s',file,message);
        end
        loaded = load(file,'metadata','confidenceProbe');
        records(i).file = file;
        records(i).metadata = loaded.metadata;
        records(i).probe = loaded.confidenceProbe;
    end
end

function mask = matchingJob(jobs,metadata)
    required = {'jobID','problem','M','run','seed'};
    if ~all(isfield(metadata,required))
        mask = false(height(jobs),1);
        return;
    end
    mask = jobs.JobID == string(metadata.jobID) & ...
        jobs.Problem == string(metadata.problem) & ...
        jobs.M == metadata.M & jobs.Run == metadata.run & ...
        jobs.Seed == metadata.seed;
end

function assertUniqueRuns(records)
    keys = strings(numel(records),1);
    for i = 1:numel(records)
        metadata = records(i).metadata;
        keys(i) = sprintf('%s|M%d|run%d|seed%d', ...
            char(metadata.problem),metadata.M,metadata.run,metadata.seed);
    end
    if numel(unique(keys)) ~= numel(keys)
        [~,first] = unique(keys,'stable');
        duplicateIndex = setdiff((1:numel(keys))',first);
        duplicateFiles = string({records(duplicateIndex).file});
        error('AdaMaO:DuplicateConfidenceProbeRun', ...
            ['Duplicate Problem/M/Run/Seed files include: %s. Analyze ', ...
            'one profile directory at a time.'], ...
            strjoin(cellstr(duplicateFiles),', '));
    end
end

function combined = concatenateRecordTables(records,aggregateFunction)
    tables = cell(numel(records),1);
    for i = 1:numel(records)
        tables{i} = aggregateFunction(records(i));
    end
    combined = vertcat(tables{:});
end

function result = aggregatePBIPairs(record)
    schema = record.probe;
    rows = schema.pbiPairRows;
    generation = getColumn(rows,schema,'pbiPairRows','Generation');
    pairType = getColumn(rows,schema,'pbiPairRows','PairType');
    confidence = getColumn(rows,schema,'pbiPairRows','PairConfidence');
    predicted = getColumn(rows,schema,'pbiPairRows','PredictedRelation');
    pareto = getColumn(rows,schema,'pbiPairRows','ParetoRelation');
    sde = getColumn(rows,schema,'pbiPairRows','SDERelation');
    bins = AssignConfidenceProbeBins(confidence, ...
        table(generation,pairType),5);
    keys = table(generation,pairType,bins, ...
        'VariableNames',{'Generation','PairType','ConfidenceBin'});
    [group,keyRows] = findgroups(keys);
    count = height(keyRows);

    N = zeros(count,1);
    MeanPBIConfidence = nan(count,1);
    ComparableParetoN = zeros(count,1);
    ParetoErrorRate = nan(count,1);
    ParetoAccuracyRate = nan(count,1);
    ComparableSDEN = zeros(count,1);
    SDEErrorRate = nan(count,1);
    SDEConsistencyRate = nan(count,1);
    LeftSurviveH1Rate = nan(count,1);
    RightSurviveH1Rate = nan(count,1);
    LeftSurviveH3Rate = nan(count,1);
    RightSurviveH3Rate = nan(count,1);
    LeftFinalNDRate = nan(count,1);
    RightFinalNDRate = nan(count,1);
    for g = 1:count
        mask = group == g;
        N(g) = sum(mask);
        MeanPBIConfidence(g) = mean(confidence(mask));
        [ComparableParetoN(g),ParetoErrorRate(g), ...
            ParetoAccuracyRate(g)] = relationRates( ...
            predicted(mask),pareto(mask));
        [ComparableSDEN(g),SDEErrorRate(g), ...
            SDEConsistencyRate(g)] = relationRates( ...
            predicted(mask),sde(mask));
        LeftSurviveH1Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'pbiPairRows','LeftSurviveH1'));
        RightSurviveH1Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'pbiPairRows','RightSurviveH1'));
        LeftSurviveH3Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'pbiPairRows','LeftSurviveH3'));
        RightSurviveH3Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'pbiPairRows','RightSurviveH3'));
        LeftFinalNDRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'pbiPairRows','LeftFinalND'));
        RightFinalNDRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'pbiPairRows','RightFinalND'));
    end
    [Problem,M,Run,Seed] = metadataColumns(record.metadata,count);
    result = table(Problem,M,Run,Seed,keyRows.Generation, ...
        keyRows.PairType,keyRows.ConfidenceBin,N,MeanPBIConfidence, ...
        ComparableParetoN,ParetoErrorRate,ParetoAccuracyRate, ...
        ComparableSDEN,SDEErrorRate,SDEConsistencyRate, ...
        LeftSurviveH1Rate,RightSurviveH1Rate, ...
        LeftSurviveH3Rate,RightSurviveH3Rate, ...
        LeftFinalNDRate,RightFinalNDRate, ...
        'VariableNames',{'Problem','M','Run','Seed','Generation', ...
        'PairType','ConfidenceBin','N','MeanPBIConfidence', ...
        'ComparableParetoN','ParetoErrorRate','ParetoAccuracyRate', ...
        'ComparableSDEN','SDEErrorRate','SDEConsistencyRate', ...
        'LeftSurviveH1Rate','RightSurviveH1Rate', ...
        'LeftSurviveH3Rate','RightSurviveH3Rate', ...
        'LeftFinalNDRate','RightFinalNDRate'});
end

function result = aggregateSolutions(record)
    schema = record.probe;
    rows = schema.solutionRows;
    generation = getColumn(rows,schema,'solutionRows','Generation');
    catalog = getColumn(rows,schema,'solutionRows','Catalog');
    confidence = getColumn(rows,schema,'solutionRows','PBIConfidence');
    bins = AssignConfidenceProbeBins(confidence, ...
        table(generation,catalog),5);
    keys = table(generation,catalog,bins, ...
        'VariableNames',{'Generation','Catalog','ConfidenceBin'});
    [group,keyRows] = findgroups(keys);
    count = height(keyRows);

    N = zeros(count,1);
    MeanPBIConfidence = nan(count,1);
    CurrentNDRate = nan(count,1);
    SurviveH1Rate = nan(count,1);
    SurviveH3Rate = nan(count,1);
    FinalNDRate = nan(count,1);
    for g = 1:count
        mask = group == g;
        N(g) = sum(mask);
        MeanPBIConfidence(g) = mean(confidence(mask));
        CurrentNDRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'solutionRows','CurrentND'));
        SurviveH1Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'solutionRows','SurviveH1'));
        SurviveH3Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'solutionRows','SurviveH3'));
        FinalNDRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'solutionRows','FinalND'));
    end
    [Problem,M,Run,Seed] = metadataColumns(record.metadata,count);
    result = table(Problem,M,Run,Seed,keyRows.Generation, ...
        keyRows.Catalog,keyRows.ConfidenceBin,N,MeanPBIConfidence, ...
        CurrentNDRate,SurviveH1Rate,SurviveH3Rate,FinalNDRate, ...
        'VariableNames',{'Problem','M','Run','Seed','Generation', ...
        'Catalog','ConfidenceBin','N','MeanPBIConfidence', ...
        'CurrentNDRate','SurviveH1Rate','SurviveH3Rate','FinalNDRate'});
end

function result = aggregateNetworkPairs(record)
    schema = record.probe;
    rows = schema.networkPairRows;
    generation = getColumn(rows,schema,'networkPairRows','Generation');
    predicted = getColumn( ...
        rows,schema,'networkPairRows','PredictedRelation');
    confidence = getColumn( ...
        rows,schema,'networkPairRows','NetworkConfidence');
    pareto = getColumn(rows,schema,'networkPairRows','ParetoRelation');
    sde = getColumn(rows,schema,'networkPairRows','SDERelation');
    bins = AssignConfidenceProbeBins(confidence, ...
        table(generation,predicted),5);
    keys = table(generation,predicted,bins, ...
        'VariableNames',{'Generation','PredictedRelation', ...
        'ConfidenceBin'});
    [group,keyRows] = findgroups(keys);
    count = height(keyRows);

    N = zeros(count,1);
    MeanNetworkConfidence = nan(count,1);
    ComparableParetoN = zeros(count,1);
    ParetoErrorRate = nan(count,1);
    ParetoAccuracyRate = nan(count,1);
    ComparableSDEN = zeros(count,1);
    SDEErrorRate = nan(count,1);
    SDEConsistencyRate = nan(count,1);
    CandidateSurviveH1Rate = nan(count,1);
    CandidateSurviveH3Rate = nan(count,1);
    CandidateFinalNDRate = nan(count,1);
    for g = 1:count
        mask = group == g;
        N(g) = sum(mask);
        MeanNetworkConfidence(g) = mean(confidence(mask));
        [ComparableParetoN(g),ParetoErrorRate(g), ...
            ParetoAccuracyRate(g)] = relationRates( ...
            predicted(mask),pareto(mask));
        [ComparableSDEN(g),SDEErrorRate(g), ...
            SDEConsistencyRate(g)] = relationRates( ...
            predicted(mask),sde(mask));
        CandidateSurviveH1Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'networkPairRows', ...
            'CandidateSurviveH1'));
        CandidateSurviveH3Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'networkPairRows', ...
            'CandidateSurviveH3'));
        CandidateFinalNDRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'networkPairRows', ...
            'CandidateFinalND'));
    end
    [Problem,M,Run,Seed] = metadataColumns(record.metadata,count);
    result = table(Problem,M,Run,Seed,keyRows.Generation, ...
        keyRows.PredictedRelation,keyRows.ConfidenceBin,N, ...
        MeanNetworkConfidence,ComparableParetoN,ParetoErrorRate, ...
        ParetoAccuracyRate,ComparableSDEN,SDEErrorRate, ...
        SDEConsistencyRate,CandidateSurviveH1Rate, ...
        CandidateSurviveH3Rate,CandidateFinalNDRate, ...
        'VariableNames',{'Problem','M','Run','Seed','Generation', ...
        'PredictedRelation','ConfidenceBin','N', ...
        'MeanNetworkConfidence','ComparableParetoN', ...
        'ParetoErrorRate','ParetoAccuracyRate','ComparableSDEN', ...
        'SDEErrorRate','SDEConsistencyRate', ...
        'CandidateSurviveH1Rate','CandidateSurviveH3Rate', ...
        'CandidateFinalNDRate'});
end

function result = aggregateCandidates(record)
    schema = record.probe;
    rows = schema.candidateRows;
    confidence = getColumn( ...
        rows,schema,'candidateRows','NetworkConfidence');
    fe = getColumn(rows,schema,'candidateRows','FE');
    phaseCode = max(1,min(3,ceil(3*fe/record.metadata.maxFE)));
    bins = AssignConfidenceProbeBins(confidence,phaseCode,5);
    keys = table(phaseCode,bins, ...
        'VariableNames',{'PhaseCode','ConfidenceBin'});
    [group,keyRows] = findgroups(keys);
    count = height(keyRows);

    N = zeros(count,1);
    MeanNetworkConfidence = nan(count,1);
    MeanPredictedBetterRate = nan(count,1);
    DominatesAnyRate = nan(count,1);
    DominatedByAnyRate = nan(count,1);
    IsNondominatedRate = nan(count,1);
    MeanMarginalIGD = nan(count,1);
    MarginalIGDPositiveRate = nan(count,1);
    SurviveH1Rate = nan(count,1);
    SurviveH3Rate = nan(count,1);
    ArchiveNDNextRate = nan(count,1);
    FinalNDRate = nan(count,1);
    for g = 1:count
        mask = group == g;
        N(g) = sum(mask);
        MeanNetworkConfidence(g) = mean(confidence(mask));
        MeanPredictedBetterRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','PredictedBetterRate'));
        DominatesAnyRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','DominatesAny'));
        DominatedByAnyRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','DominatedByAny'));
        IsNondominatedRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','IsNondominated'));
        MeanMarginalIGD(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','MarginalIGD'));
        MarginalIGDPositiveRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','MarginalIGDPositive'));
        SurviveH1Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','SurviveH1'));
        SurviveH3Rate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','SurviveH3'));
        ArchiveNDNextRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','ArchiveNDNext'));
        FinalNDRate(g) = observedMean(getColumn( ...
            rows(mask,:),schema,'candidateRows','FinalND'));
    end
    phaseNames = ["early";"middle";"late"];
    Phase = phaseNames(keyRows.PhaseCode);
    [Problem,M,Run,Seed] = metadataColumns(record.metadata,count);
    result = table(Problem,M,Run,Seed,Phase,keyRows.ConfidenceBin,N, ...
        MeanNetworkConfidence,MeanPredictedBetterRate, ...
        DominatesAnyRate,DominatedByAnyRate,IsNondominatedRate, ...
        MeanMarginalIGD,MarginalIGDPositiveRate,SurviveH1Rate, ...
        SurviveH3Rate,ArchiveNDNextRate,FinalNDRate, ...
        'VariableNames',{'Problem','M','Run','Seed','Phase', ...
        'ConfidenceBin','N','MeanNetworkConfidence', ...
        'MeanPredictedBetterRate','DominatesAnyRate', ...
        'DominatedByAnyRate','IsNondominatedRate','MeanMarginalIGD', ...
        'MarginalIGDPositiveRate','SurviveH1Rate','SurviveH3Rate', ...
        'ArchiveNDNextRate','FinalNDRate'});
end

function runMetrics = buildRunMetrics(records)
    count = numel(records);
    Problem = strings(count,1);
    M = zeros(count,1);
    Run = zeros(count,1);
    Seed = zeros(count,1);
    Q1ErrorRate = nan(count,1);
    Q5ErrorRate = nan(count,1);
    Q5MinusQ1Error = nan(count,1);
    AUROC = nan(count,1);
    ComparablePairN = zeros(count,1);
    PrimaryJointValid = false(count,1);
    PBISDEQ5MinusQ1Error = nan(count,1);
    PBISDEAUROC = nan(count,1);
    PBISDEComparableN = zeros(count,1);
    NetworkParetoQ5MinusQ1Error = nan(count,1);
    NetworkParetoAUROC = nan(count,1);
    NetworkParetoComparableN = zeros(count,1);
    NetworkSDEQ5MinusQ1Error = nan(count,1);
    NetworkSDEAUROC = nan(count,1);
    NetworkSDEComparableN = zeros(count,1);
    CandidateMarginalIGDPositiveQ5MinusQ1 = nan(count,1);
    CandidateSurvivalH1Q5MinusQ1 = nan(count,1);
    CandidateSurvivalH3Q5MinusQ1 = nan(count,1);
    CandidateArchiveNDNextQ5MinusQ1 = nan(count,1);
    CandidateFinalNDQ5MinusQ1 = nan(count,1);
    SolutionGoodSurvivalH1Q5MinusQ1 = nan(count,1);
    SolutionGoodSurvivalH3Q5MinusQ1 = nan(count,1);
    SolutionGoodFinalNDQ5MinusQ1 = nan(count,1);
    SolutionRestSurvivalH1Q5MinusQ1 = nan(count,1);
    SolutionRestSurvivalH3Q5MinusQ1 = nan(count,1);
    SolutionRestFinalNDQ5MinusQ1 = nan(count,1);
    for i = 1:count
        record = records(i);
        Problem(i) = string(record.metadata.problem);
        M(i) = record.metadata.M;
        Run(i) = record.metadata.run;
        Seed(i) = record.metadata.seed;
        [Q1ErrorRate(i),Q5ErrorRate(i),AUROC(i), ...
            ComparablePairN(i)] = primaryPBIRun(record);
        Q5MinusQ1Error(i) = Q5ErrorRate(i)-Q1ErrorRate(i);
        PrimaryJointValid(i) = all(isfinite([ ...
            Q1ErrorRate(i),Q5ErrorRate(i), ...
            Q5MinusQ1Error(i),AUROC(i)]));
        [PBISDEQ5MinusQ1Error(i),PBISDEAUROC(i), ...
            PBISDEComparableN(i)] = pbiSDERun(record);
        [NetworkParetoQ5MinusQ1Error(i),NetworkParetoAUROC(i), ...
            NetworkParetoComparableN(i), ...
            NetworkSDEQ5MinusQ1Error(i),NetworkSDEAUROC(i), ...
            NetworkSDEComparableN(i)] = networkRun(record);
        [CandidateMarginalIGDPositiveQ5MinusQ1(i), ...
            CandidateSurvivalH1Q5MinusQ1(i), ...
            CandidateSurvivalH3Q5MinusQ1(i), ...
            CandidateArchiveNDNextQ5MinusQ1(i), ...
            CandidateFinalNDQ5MinusQ1(i)] = candidateRun(record);
        [SolutionGoodSurvivalH1Q5MinusQ1(i), ...
            SolutionGoodSurvivalH3Q5MinusQ1(i), ...
            SolutionGoodFinalNDQ5MinusQ1(i), ...
            SolutionRestSurvivalH1Q5MinusQ1(i), ...
            SolutionRestSurvivalH3Q5MinusQ1(i), ...
            SolutionRestFinalNDQ5MinusQ1(i)] = solutionRun(record);
    end
    runMetrics = table(Problem,M,Run,Seed,Q1ErrorRate,Q5ErrorRate, ...
        Q5MinusQ1Error,AUROC,ComparablePairN, ...
        PrimaryJointValid,PBISDEQ5MinusQ1Error,PBISDEAUROC, ...
        PBISDEComparableN,NetworkParetoQ5MinusQ1Error, ...
        NetworkParetoAUROC,NetworkParetoComparableN, ...
        NetworkSDEQ5MinusQ1Error,NetworkSDEAUROC, ...
        NetworkSDEComparableN,CandidateMarginalIGDPositiveQ5MinusQ1, ...
        CandidateSurvivalH1Q5MinusQ1, ...
        CandidateSurvivalH3Q5MinusQ1, ...
        CandidateArchiveNDNextQ5MinusQ1,CandidateFinalNDQ5MinusQ1, ...
        SolutionGoodSurvivalH1Q5MinusQ1, ...
        SolutionGoodSurvivalH3Q5MinusQ1, ...
        SolutionGoodFinalNDQ5MinusQ1, ...
        SolutionRestSurvivalH1Q5MinusQ1, ...
        SolutionRestSurvivalH3Q5MinusQ1, ...
        SolutionRestFinalNDQ5MinusQ1);
end

function [q1,q5,auc,comparableCount] = primaryPBIRun(record)
    schema = record.probe;
    rows = schema.pbiPairRows;
    pairType = getColumn(rows,schema,'pbiPairRows','PairType');
    rows = rows(pairType == schema.codes.pairType.goodRest,:);
    generation = getColumn(rows,schema,'pbiPairRows','Generation');
    confidence = getColumn(rows,schema,'pbiPairRows','PairConfidence');
    predicted = getColumn(rows,schema,'pbiPairRows','PredictedRelation');
    truth = getColumn(rows,schema,'pbiPairRows','ParetoRelation');
    bins = AssignConfidenceProbeBins(confidence,generation,5);
    comparable = truth ~= 0;
    error = predicted ~= truth;
    q1 = conditionalMean(error,bins == 1 & comparable);
    q5 = conditionalMean(error,bins == 5 & comparable);
    comparableCount = sum(comparable);
    auc = binaryAUC(confidence(comparable),~error(comparable));
end

function [difference,auc,comparableCount] = pbiSDERun(record)
    schema = record.probe;
    rows = schema.pbiPairRows;
    pairType = getColumn(rows,schema,'pbiPairRows','PairType');
    rows = rows(pairType == schema.codes.pairType.goodRest,:);
    generation = getColumn(rows,schema,'pbiPairRows','Generation');
    confidence = getColumn(rows,schema,'pbiPairRows','PairConfidence');
    predicted = getColumn(rows,schema,'pbiPairRows','PredictedRelation');
    truth = getColumn(rows,schema,'pbiPairRows','SDERelation');
    bins = AssignConfidenceProbeBins(confidence,generation,5);
    comparable = truth ~= 0;
    error = predicted ~= truth;
    q1 = conditionalMean(error,bins == 1 & comparable);
    q5 = conditionalMean(error,bins == 5 & comparable);
    difference = q5-q1;
    comparableCount = sum(comparable);
    auc = binaryAUC(confidence(comparable),~error(comparable));
end

function [paretoDifference,paretoAUC,paretoComparableCount, ...
    sdeDifference,sdeAUC,sdeComparableCount] = networkRun(record)
    schema = record.probe;
    rows = schema.networkPairRows;
    generation = getColumn(rows,schema,'networkPairRows','Generation');
    predicted = getColumn( ...
        rows,schema,'networkPairRows','PredictedRelation');
    confidence = getColumn( ...
        rows,schema,'networkPairRows','NetworkConfidence');
    bins = AssignConfidenceProbeBins(confidence, ...
        table(generation,predicted),5);
    pareto = getColumn(rows,schema,'networkPairRows','ParetoRelation');
    [paretoDifference,paretoAUC,paretoComparableCount] = ...
        binnedRelationSummary(confidence,predicted,pareto,bins);
    sde = getColumn(rows,schema,'networkPairRows','SDERelation');
    [sdeDifference,sdeAUC,sdeComparableCount] = ...
        binnedRelationSummary(confidence,predicted,sde,bins);
end

function [improvementDifference,survivalH1Difference, ...
    survivalH3Difference,archiveNDNextDifference, ...
    finalNDDifference] = candidateRun(record)
    schema = record.probe;
    rows = schema.candidateRows;
    confidence = getColumn( ...
        rows,schema,'candidateRows','NetworkConfidence');
    fe = getColumn(rows,schema,'candidateRows','FE');
    phase = max(1,min(3,ceil(3*fe/record.metadata.maxFE)));
    bins = AssignConfidenceProbeBins(confidence,phase,5);
    improvement = getColumn( ...
        rows,schema,'candidateRows','MarginalIGDPositive');
    improvementDifference = observedBinDifference( ...
        improvement,bins);
    survivalH1Difference = observedBinDifference(getColumn( ...
        rows,schema,'candidateRows','SurviveH1'),bins);
    survivalH3Difference = observedBinDifference(getColumn( ...
        rows,schema,'candidateRows','SurviveH3'),bins);
    archiveNDNextDifference = observedBinDifference(getColumn( ...
        rows,schema,'candidateRows','ArchiveNDNext'),bins);
    finalNDDifference = observedBinDifference(getColumn( ...
        rows,schema,'candidateRows','FinalND'),bins);
end

function [goodH1Difference,goodH3Difference,goodFinalDifference, ...
    restH1Difference,restH3Difference,restFinalDifference] = ...
    solutionRun(record)
    schema = record.probe;
    rows = schema.solutionRows;
    confidence = getColumn(rows,schema,'solutionRows','PBIConfidence');
    generation = getColumn(rows,schema,'solutionRows','Generation');
    catalog = getColumn(rows,schema,'solutionRows','Catalog');
    bins = AssignConfidenceProbeBins(confidence, ...
        table(generation,catalog),5);
    good = catalog == 1;
    rest = catalog == 0;
    surviveH1 = getColumn(rows,schema,'solutionRows','SurviveH1');
    surviveH3 = getColumn(rows,schema,'solutionRows','SurviveH3');
    finalND = getColumn(rows,schema,'solutionRows','FinalND');
    goodH1Difference = observedBinDifference( ...
        surviveH1(good),bins(good));
    goodH3Difference = observedBinDifference( ...
        surviveH3(good),bins(good));
    goodFinalDifference = observedBinDifference( ...
        finalND(good),bins(good));
    restH1Difference = observedBinDifference( ...
        surviveH1(rest),bins(rest));
    restH3Difference = observedBinDifference( ...
        surviveH3(rest),bins(rest));
    restFinalDifference = observedBinDifference( ...
        finalND(rest),bins(rest));
end

function [difference,auc,comparableCount] = ...
    binnedRelationSummary(confidence,predicted,truth,bins)
    comparable = truth ~= 0;
    error = predicted ~= truth;
    q1 = conditionalMean(error,bins == 1 & comparable);
    q5 = conditionalMean(error,bins == 5 & comparable);
    difference = q5-q1;
    comparableCount = sum(comparable);
    auc = binaryAUC(confidence(comparable),~error(comparable));
end

function summary = summarizeProblems(runMetrics,protocol,B,stream)
    keys = unique(protocol.jobs(:,{'Problem','M'}),'rows','stable');
    count = height(keys);
    ExpectedRunCount = zeros(count,1);
    CompletedRunCount = zeros(count,1);
    ValidPrimaryRunCount = zeros(count,1);
    PrimaryDataComplete = false(count,1);
    RunCount = zeros(count,1);
    Q1ErrorRate = nan(count,1);
    Q5ErrorRate = nan(count,1);
    Q5MinusQ1Error = nan(count,1);
    DiffCILower = nan(count,1);
    DiffCIUpper = nan(count,1);
    AUROC = nan(count,1);
    AUROCCILower = nan(count,1);
    AUROCCIUpper = nan(count,1);
    DirectionNegative = false(count,1);
    ComparablePairN = zeros(count,1);
    for i = 1:count
        expectedMask = protocol.jobs.Problem == keys.Problem(i) & ...
            protocol.jobs.M == keys.M(i);
        mask = runMetrics.Problem == keys.Problem(i) & ...
            runMetrics.M == keys.M(i);
        data = runMetrics(mask,:);
        joint = data(data.PrimaryJointValid,:);
        ExpectedRunCount(i) = sum(expectedMask);
        CompletedRunCount(i) = height(data);
        ValidPrimaryRunCount(i) = height(joint);
        PrimaryDataComplete(i) = ...
            CompletedRunCount(i) == ExpectedRunCount(i) && ...
            ValidPrimaryRunCount(i) == ExpectedRunCount(i);
        RunCount(i) = CompletedRunCount(i);
        Q1ErrorRate(i) = observedMean(joint.Q1ErrorRate);
        Q5ErrorRate(i) = observedMean(joint.Q5ErrorRate);
        Q5MinusQ1Error(i) = observedMean(joint.Q5MinusQ1Error);
        diffSamples = bootstrapMean( ...
            joint.Q5MinusQ1Error,B,stream);
        [DiffCILower(i),DiffCIUpper(i)] = interval(diffSamples);
        AUROC(i) = observedMean(joint.AUROC);
        aucSamples = bootstrapMean(joint.AUROC,B,stream);
        [AUROCCILower(i),AUROCCIUpper(i)] = interval(aucSamples);
        DirectionNegative(i) = ...
            PrimaryDataComplete(i) && Q5MinusQ1Error(i) < 0;
        ComparablePairN(i) = sum(joint.ComparablePairN);
    end
    summary = table(keys.Problem,keys.M,ExpectedRunCount, ...
        CompletedRunCount,ValidPrimaryRunCount,PrimaryDataComplete, ...
        RunCount,Q1ErrorRate, ...
        Q5ErrorRate,Q5MinusQ1Error,DiffCILower,DiffCIUpper, ...
        AUROC,AUROCCILower,AUROCCIUpper,ComparablePairN, ...
        DirectionNegative, ...
        'VariableNames',{'Problem','M','ExpectedRunCount', ...
        'CompletedRunCount','ValidPrimaryRunCount', ...
        'PrimaryDataComplete','RunCount','Q1ErrorRate', ...
        'Q5ErrorRate','Q5MinusQ1Error','DiffCILower','DiffCIUpper', ...
        'AUROC','AUROCCILower','AUROCCIUpper','ComparablePairN', ...
        'DirectionNegative'});
    summary = addProblemAuxiliaryMetrics( ...
        summary,runMetrics,B,stream);
    summary = addProblemComparableCounts(summary,runMetrics);
end

function summary = summarizeObjectives( ...
    runMetrics,summaryByProblem,protocol,B,stream)
    objectives = unique(protocol.jobs.M,'stable');
    count = numel(objectives);
    M = objectives;
    ExpectedRunCount = zeros(count,1);
    CompletedRunCount = zeros(count,1);
    ValidPrimaryRunCount = zeros(count,1);
    ValidPrimaryProblemCount = zeros(count,1);
    PrimaryDataComplete = false(count,1);
    ProblemCount = zeros(count,1);
    RunCount = zeros(count,1);
    NegativeProblemCount = zeros(count,1);
    Q1ErrorRate = nan(count,1);
    Q5ErrorRate = nan(count,1);
    Q5MinusQ1Error = nan(count,1);
    DiffCILower = nan(count,1);
    DiffCIUpper = nan(count,1);
    AUROC = nan(count,1);
    AUROCCILower = nan(count,1);
    AUROCCIUpper = nan(count,1);
    ComparablePairN = zeros(count,1);
    for i = 1:count
        runMask = runMetrics.M == M(i);
        problemMask = summaryByProblem.M == M(i);
        data = runMetrics(runMask,:);
        problems = summaryByProblem(problemMask,:);
        joint = data(data.PrimaryJointValid,:);
        ExpectedRunCount(i) = sum(protocol.jobs.M == M(i));
        CompletedRunCount(i) = height(data);
        ValidPrimaryRunCount(i) = height(joint);
        ValidPrimaryProblemCount(i) = sum( ...
            problems.PrimaryDataComplete);
        PrimaryDataComplete(i) = ...
            CompletedRunCount(i) == ExpectedRunCount(i) && ...
            ValidPrimaryRunCount(i) == ExpectedRunCount(i) && ...
            ValidPrimaryProblemCount(i) == height(problems);
        ProblemCount(i) = height(problems);
        RunCount(i) = CompletedRunCount(i);
        NegativeProblemCount(i) = sum(problems.DirectionNegative);
        Q1ErrorRate(i) = observedMean(problems.Q1ErrorRate);
        Q5ErrorRate(i) = observedMean(problems.Q5ErrorRate);
        Q5MinusQ1Error(i) = observedMean(problems.Q5MinusQ1Error);
        diffSamples = hierarchicalBootstrap( ...
            joint.Q5MinusQ1Error,joint.Problem,B,stream);
        [DiffCILower(i),DiffCIUpper(i)] = interval(diffSamples);
        AUROC(i) = observedMean(problems.AUROC);
        aucSamples = hierarchicalBootstrap( ...
            joint.AUROC,joint.Problem,B,stream);
        [AUROCCILower(i),AUROCCIUpper(i)] = interval(aucSamples);
        ComparablePairN(i) = sum(joint.ComparablePairN);
    end
    summary = table(M,ProblemCount,ExpectedRunCount,CompletedRunCount, ...
        ValidPrimaryRunCount,ValidPrimaryProblemCount, ...
        PrimaryDataComplete,RunCount,NegativeProblemCount, ...
        Q1ErrorRate,Q5ErrorRate,Q5MinusQ1Error, ...
        DiffCILower,DiffCIUpper,AUROC,AUROCCILower,AUROCCIUpper, ...
        ComparablePairN);
    summary = addObjectiveAuxiliaryMetrics( ...
        summary,runMetrics,summaryByProblem,B,stream);
    summary = addObjectiveComparableCounts(summary,runMetrics);
end

function summary = addProblemAuxiliaryMetrics( ...
    summary,runMetrics,B,stream)
    specs = auxiliaryMetricSpecs();
    for specIndex = 1:numel(specs)
        spec = specs(specIndex);
        point = nan(height(summary),1);
        lower = nan(height(summary),1);
        upper = nan(height(summary),1);
        for i = 1:height(summary)
            mask = runMetrics.Problem == summary.Problem(i) & ...
                runMetrics.M == summary.M(i);
            values = runMetrics.(spec.RunColumn)(mask);
            point(i) = observedMean(values);
            samples = bootstrapMean(values,B,stream);
            [lower(i),upper(i)] = interval(samples);
        end
        summary.(spec.SummaryColumn) = point;
        summary.([spec.CIStem,'CILower']) = lower;
        summary.([spec.CIStem,'CIUpper']) = upper;
    end
end

function summary = addProblemComparableCounts(summary,runMetrics)
    columns = {'PBISDEComparableN','NetworkParetoComparableN', ...
        'NetworkSDEComparableN'};
    for columnIndex = 1:numel(columns)
        total = zeros(height(summary),1);
        for i = 1:height(summary)
            mask = runMetrics.Problem == summary.Problem(i) & ...
                runMetrics.M == summary.M(i);
            total(i) = sum(runMetrics.(columns{columnIndex})(mask));
        end
        summary.(columns{columnIndex}) = total;
    end
end

function summary = addObjectiveAuxiliaryMetrics( ...
    summary,runMetrics,summaryByProblem,B,stream)
    specs = auxiliaryMetricSpecs();
    for specIndex = 1:numel(specs)
        spec = specs(specIndex);
        point = nan(height(summary),1);
        lower = nan(height(summary),1);
        upper = nan(height(summary),1);
        favorableCount = zeros(height(summary),1);
        for i = 1:height(summary)
            runMask = runMetrics.M == summary.M(i);
            problemMask = summaryByProblem.M == summary.M(i);
            problemValues = summaryByProblem.( ...
                spec.SummaryColumn)(problemMask);
            point(i) = observedMean(problemValues);
            samples = hierarchicalBootstrap( ...
                runMetrics.(spec.RunColumn)(runMask), ...
                runMetrics.Problem(runMask),B,stream);
            [lower(i),upper(i)] = interval(samples);
            if spec.FavorableSign ~= 0
                favorableCount(i) = sum(isfinite(problemValues) & ...
                    spec.FavorableSign*problemValues > 0);
            end
        end
        summary.(spec.SummaryColumn) = point;
        summary.([spec.CIStem,'CILower']) = lower;
        summary.([spec.CIStem,'CIUpper']) = upper;
        if ~isempty(spec.FavorableCountColumn)
            summary.(spec.FavorableCountColumn) = favorableCount;
        end
    end
end

function summary = addObjectiveComparableCounts(summary,runMetrics)
    columns = {'PBISDEComparableN','NetworkParetoComparableN', ...
        'NetworkSDEComparableN'};
    for columnIndex = 1:numel(columns)
        total = zeros(height(summary),1);
        for i = 1:height(summary)
            mask = runMetrics.M == summary.M(i);
            total(i) = sum(runMetrics.(columns{columnIndex})(mask));
        end
        summary.(columns{columnIndex}) = total;
    end
end

function specs = auxiliaryMetricSpecs()
    definitions = { ...
        'PBISDEQ5MinusQ1Error','PBISDEQ5MinusQ1Error', ...
            'PBISDEDiff',-1,'PBISDEFavorableProblemCount'; ...
        'PBISDEAUROC','PBISDEAUROC','PBISDEAUROC',0,''; ...
        'NetworkParetoQ5MinusQ1Error', ...
            'NetworkParetoQ5MinusQ1Error','NetworkParetoDiff',-1,''; ...
        'NetworkParetoAUROC','NetworkParetoAUROC', ...
            'NetworkParetoAUROC',0,''; ...
        'NetworkSDEQ5MinusQ1Error','NetworkSDEQ5MinusQ1Error', ...
            'NetworkSDEDiff',-1,''; ...
        'NetworkSDEAUROC','NetworkSDEAUROC','NetworkSDEAUROC',0,''; ...
        'CandidateMarginalIGDPositiveQ5MinusQ1', ...
            'CandidateMarginalIGDPositiveQ5MinusQ1', ...
            'CandidateMarginalIGDPositive',0,''; ...
        'CandidateSurvivalH1Q5MinusQ1', ...
            'CandidateSurviveH1Q5MinusQ1','CandidateSurviveH1',0,''; ...
        'CandidateSurvivalH3Q5MinusQ1', ...
            'CandidateSurviveH3Q5MinusQ1','CandidateSurviveH3',0,''; ...
        'CandidateArchiveNDNextQ5MinusQ1', ...
            'CandidateArchiveNDNextQ5MinusQ1', ...
            'CandidateArchiveNDNext',0,''; ...
        'CandidateFinalNDQ5MinusQ1','CandidateFinalNDQ5MinusQ1', ...
            'CandidateFinalND',0,''; ...
        'SolutionGoodSurvivalH1Q5MinusQ1', ...
            'SolutionGoodSurviveH1Q5MinusQ1', ...
            'SolutionGoodSurviveH1',1, ...
            'SolutionGoodSurviveH1FavorableProblemCount'; ...
        'SolutionGoodSurvivalH3Q5MinusQ1', ...
            'SolutionGoodSurviveH3Q5MinusQ1', ...
            'SolutionGoodSurviveH3',1, ...
            'SolutionGoodSurviveH3FavorableProblemCount'; ...
        'SolutionGoodFinalNDQ5MinusQ1', ...
            'SolutionGoodFinalNDQ5MinusQ1','SolutionGoodFinalND',1, ...
            'SolutionGoodFinalNDFavorableProblemCount'; ...
        'SolutionRestSurvivalH1Q5MinusQ1', ...
            'SolutionRestSurviveH1Q5MinusQ1', ...
            'SolutionRestSurviveH1',-1, ...
            'SolutionRestSurviveH1FavorableProblemCount'; ...
        'SolutionRestSurvivalH3Q5MinusQ1', ...
            'SolutionRestSurviveH3Q5MinusQ1', ...
            'SolutionRestSurviveH3',-1, ...
            'SolutionRestSurviveH3FavorableProblemCount'; ...
        'SolutionRestFinalNDQ5MinusQ1', ...
            'SolutionRestFinalNDQ5MinusQ1','SolutionRestFinalND',-1, ...
            'SolutionRestFinalNDFavorableProblemCount'};
    specs = repmat(struct('RunColumn','','SummaryColumn','', ...
        'CIStem','','FavorableSign',0,'FavorableCountColumn',''), ...
        size(definitions,1),1);
    for i = 1:size(definitions,1)
        specs(i).RunColumn = definitions{i,1};
        specs(i).SummaryColumn = definitions{i,2};
        specs(i).CIStem = definitions{i,3};
        specs(i).FavorableSign = definitions{i,4};
        specs(i).FavorableCountColumn = definitions{i,5};
    end
end

function decision = makeDecision(summary)
    M = summary.M;
    ProblemCount = summary.ProblemCount;
    ExpectedRunCount = summary.ExpectedRunCount;
    CompletedRunCount = summary.CompletedRunCount;
    ValidPrimaryRunCount = summary.ValidPrimaryRunCount;
    ValidPrimaryProblemCount = summary.ValidPrimaryProblemCount;
    PrimaryDataComplete = summary.PrimaryDataComplete;
    NegativeProblemCount = summary.NegativeProblemCount;
    DiffCIUpper = summary.DiffCIUpper;
    AUROCCILower = summary.AUROCCILower;
    AbsoluteErrorReduction = -summary.Q5MinusQ1Error;
    PrimaryGatePassed = false(height(summary),1);
    DecisionCode = strings(height(summary),1);
    Interpretation = strings(height(summary),1);
    for i = 1:height(summary)
        if ProblemCount(i) < 5
            DecisionCode(i) = "INSUFFICIENT_PROBLEMS";
            Interpretation(i) = ...
                "Fewer than five problems; no primary conclusion.";
            continue;
        end
        if ~PrimaryDataComplete(i)
            DecisionCode(i) = "INSUFFICIENT_DATA";
            Interpretation(i) = ...
                "Expected runs or joint-valid primary outcomes are missing.";
            continue;
        end
        PrimaryGatePassed(i) = isfinite(DiffCIUpper(i)) && ...
            DiffCIUpper(i) < 0 && isfinite(AUROCCILower(i)) && ...
            AUROCCILower(i) > 0.5 && NegativeProblemCount(i) >= 4;
        if ~PrimaryGatePassed(i)
            DecisionCode(i) = "NO_DISCRIMINATIVE_EVIDENCE";
            Interpretation(i) = ...
                "The frozen PBI confidence gate was not passed.";
        elseif AbsoluteErrorReduction(i) >= 0.05
            DecisionCode(i) = "GATE_DEVELOPMENT_VALUE";
            Interpretation(i) = ...
                "PBI confidence passed the gate with at least 5pp " + ...
                "absolute error reduction.";
        else
            DecisionCode(i) = "WEAK_DISCRIMINATIVE_INFORMATION";
            Interpretation(i) = ...
                "PBI confidence passed statistically but the effect " + ...
                "was below 5pp.";
        end
    end
    decision = table(M,ProblemCount,ExpectedRunCount,CompletedRunCount, ...
        ValidPrimaryRunCount,ValidPrimaryProblemCount, ...
        PrimaryDataComplete,NegativeProblemCount,DiffCIUpper, ...
        AUROCCILower,AbsoluteErrorReduction,PrimaryGatePassed, ...
        DecisionCode,Interpretation);
end

function samples = bootstrapMean(values,B,stream)
    values = values(isfinite(values));
    if isempty(values)
        samples = nan(B,1);
        return;
    end
    indices = randi(stream,numel(values),numel(values),B);
    samples = mean(values(indices),1)';
end

function samples = hierarchicalBootstrap(values,problem,B,stream)
    keep = isfinite(values);
    values = values(keep);
    problem = problem(keep);
    problemNames = unique(problem,'stable');
    count = numel(problemNames);
    if count == 0
        samples = nan(B,1);
        return;
    end
    samples = nan(B,1);
    for b = 1:B
        chosen = randi(stream,count,count,1);
        problemMeans = nan(count,1);
        for j = 1:count
            runValues = values(problem == problemNames(chosen(j)));
            runIndices = randi(stream,numel(runValues), ...
                numel(runValues),1);
            problemMeans(j) = mean(runValues(runIndices));
        end
        samples(b) = mean(problemMeans);
    end
end

function [lower,upper] = interval(samples)
    samples = samples(isfinite(samples));
    if isempty(samples)
        lower = nan;
        upper = nan;
    else
        bounds = prctile(samples,[2.5,97.5]);
        lower = bounds(1);
        upper = bounds(2);
    end
end

function auc = binaryAUC(score,label)
    score = score(:);
    label = logical(label(:));
    keep = isfinite(score);
    score = score(keep);
    label = label(keep);
    positiveCount = sum(label);
    negativeCount = sum(~label);
    if positiveCount == 0 || negativeCount == 0
        auc = nan;
        return;
    end
    ranks = tiedrank(score);
    auc = (sum(ranks(label))- ...
        positiveCount*(positiveCount+1)/2) / ...
        (positiveCount*negativeCount);
end

function difference = observedBinDifference(values,bins)
    q1 = conditionalObservedMean(values,bins == 1);
    q5 = conditionalObservedMean(values,bins == 5);
    difference = q5-q1;
end

function value = conditionalMean(values,mask)
    values = double(values(mask));
    if isempty(values)
        value = nan;
    else
        value = mean(values);
    end
end

function value = conditionalObservedMean(values,mask)
    values = values(mask);
    value = observedMean(values);
end

function value = observedMean(values)
    values = values(isfinite(values));
    if isempty(values)
        value = nan;
    else
        value = mean(values);
    end
end

function [count,errorRate,accuracyRate] = relationRates(predicted,truth)
    comparable = truth ~= 0 & isfinite(truth) & isfinite(predicted);
    count = sum(comparable);
    if count == 0
        errorRate = nan;
        accuracyRate = nan;
    else
        errorRate = mean(predicted(comparable) ~= truth(comparable));
        accuracyRate = 1-errorRate;
    end
end

function values = getColumn(rows,schema,tableName,columnName)
    index = find(strcmp(schema.columns.(tableName),columnName),1);
    if isempty(index)
        error('AdaMaO:MissingConfidenceProbeColumn', ...
            '%s is missing column %s.',tableName,columnName);
    end
    values = rows(:,index);
end

function [Problem,M,Run,Seed] = metadataColumns(metadata,rowCount)
    Problem = repmat(string(metadata.problem),rowCount,1);
    M = repmat(double(metadata.M),rowCount,1);
    Run = repmat(double(metadata.run),rowCount,1);
    Seed = repmat(double(metadata.seed),rowCount,1);
end
