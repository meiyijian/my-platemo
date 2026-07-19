function analysis = analyze_CPR_screening(resultDir)
%ANALYZE_CPR_SCREENING Analyze paired CPR screening results against U0.
%   ANALYSIS = ANALYZE_CPR_SCREENING(RESULTDIR) loads completed screening
%   runs recursively. M=10 and M=20 are always analyzed separately. Run
%   pairs are matched by problem, M, run, and seed; family confidence
%   intervals use a hierarchical bootstrap: paired seeds are resampled
%   within each problem and problems are then resampled with equal weight.

    if nargin < 1 || isempty(resultDir)
        thisDir = fileparts(mfilename('fullpath'));
        resultDir = fullfile(thisDir,'results','FE500','screening');
    end
    if ~(ischar(resultDir) || (isstring(resultDir) && isscalar(resultDir)))
        error('AdaMaO:InvalidCPRResultDirectory', ...
            'resultDir must be a character vector or scalar string.');
    end
    resultDir = char(resultDir);
    if ~isfolder(resultDir)
        error('AdaMaO:MissingCPRResultDirectory', ...
            'Result directory does not exist: %s.',resultDir);
    end

    protocol = CPRExperimentProtocol('screening');
    records = loadRecords(resultDir,protocol);
    records = records(records.Profile == "screening" & records.MaxFE == 500,:);
    if isempty(records)
        error('AdaMaO:NoCPRScreeningResults', ...
            'No completed FE=500 screening results were found in %s.',resultDir);
    end
    assertUniqueRecords(records);

    stream = RandStream('mt19937ar','Seed',protocol.analysis.bootstrapSeed);
    alternatives = string(protocol.algorithmLabels(2:end));
    [perProblem,pairData] = buildPerProblem(records,alternatives,protocol,stream);
    byFamily = buildByFamily(perProblem,pairData,alternatives,protocol,stream);
    decision = buildDecision(byFamily,protocol.objectives);

    analysis = struct();
    analysis.perProblem = perProblem;
    analysis.byFamily = byFamily;
    analysis.decision = decision;
    analysis.settings = protocol.analysis;
    analysis.resultDir = resultDir;
    analysis.completedRunCount = height(records);

    writetable(perProblem,fullfile(resultDir,'CPR_screening_per_problem.csv'));
    writetable(byFamily,fullfile(resultDir,'CPR_screening_by_family.csv'));
    writetable(decision,fullfile(resultDir,'CPR_screening_decision.csv'));
    save(fullfile(resultDir,'CPR_screening_analysis.mat'),'analysis');
end

function records = loadRecords(resultDir,protocol)
    files = dir(fullfile(resultDir,'**','run_*.mat'));
    records = table(strings(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        'VariableNames',{'Profile','Problem','M','Run','Seed','Algorithm', ...
        'MaxFE','IGD','IGDp'});
    for index = 1:numel(files)
        filePath = fullfile(files(index).folder,files(index).name);
        try
            loaded = load(filePath,'metadata','IGD','IGDp');
        catch exception
            warning('AdaMaO:SkippedMalformedCPRResult', ...
                'Skipping unreadable result %s: %s.',filePath,exception.message);
            continue;
        end
        if ~isfield(loaded,'metadata') || ~isstruct(loaded.metadata) || ...
                ~isscalar(loaded.metadata) || ~isfield(loaded,'IGD')
            warning('AdaMaO:SkippedMalformedCPRResult', ...
                'Skipping result without metadata and IGD: %s.',filePath);
            continue;
        end
        required = {'profile','problem','M','run','seed','algorithmLabel','maxFE'};
        if ~all(isfield(loaded.metadata,required))
            warning('AdaMaO:SkippedMalformedCPRResult', ...
                'Skipping result with incomplete metadata: %s.',filePath);
            continue;
        end
        if ~isTextScalar(loaded.metadata.profile) || ...
                ~strcmp(char(loaded.metadata.profile),'screening')
            continue;
        end
        [expected,validMetadata] = expectedScreeningJob(loaded.metadata,protocol);
        if ~validMetadata
            continue;
        end
        if ~(isnumeric(loaded.IGD) && isreal(loaded.IGD) && ...
                isscalar(loaded.IGD) && isfinite(loaded.IGD))
            continue;
        end
        if isfield(loaded,'IGDp')
            if isnumeric(loaded.IGDp) && isreal(loaded.IGDp) && ...
                    isscalar(loaded.IGDp) && isfinite(loaded.IGDp)
                igdp = double(loaded.IGDp);
            else
                igdp = nan;
            end
        else
            igdp = nan;
        end
        row = {"screening",expected.Problem,expected.M,expected.Run, ...
            expected.Seed,expected.Algorithm,protocol.maxFE,double(loaded.IGD),igdp};
        records(end+1,:) = row; %#ok<AGROW>
    end
end

function [job,valid] = expectedScreeningJob(metadata,protocol)
    job = protocol.jobs([],:);
    valid = isTextScalar(metadata.problem) && isTextScalar(metadata.algorithmLabel) && ...
        isFiniteScalar(metadata.M) && isFiniteScalar(metadata.run) && ...
        isFiniteScalar(metadata.seed) && isFiniteScalar(metadata.maxFE);
    if ~valid || double(metadata.maxFE) ~= protocol.maxFE
        return;
    end
    rows = protocol.jobs.Problem == string(metadata.problem) & ...
        protocol.jobs.M == double(metadata.M) & ...
        protocol.jobs.Run == double(metadata.run) & ...
        protocol.jobs.Seed == double(metadata.seed) & ...
        protocol.jobs.Algorithm == string(metadata.algorithmLabel);
    if sum(rows) ~= 1
        valid = false;
        return;
    end
    job = protocol.jobs(rows,:);
    if isfield(metadata,'requestedD')
        valid = isFiniteScalar(metadata.requestedD) && ...
            double(metadata.requestedD) == job.RequestedD;
    end
    if valid && isfield(metadata,'actualD')
        valid = isFiniteScalar(metadata.actualD) && ...
            double(metadata.actualD) == job.ActualD;
    end
    if valid && isfield(metadata,'algorithmClass')
        valid = isTextScalar(metadata.algorithmClass) && ...
            strcmp(char(metadata.algorithmClass),char(job.AlgorithmClass));
    end
end

function valid = isTextScalar(value)
    valid = ischar(value) || (isstring(value) && isscalar(value));
end

function valid = isFiniteScalar(value)
    valid = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end

function assertUniqueRecords(records)
    keys = records.Problem + "|M" + string(records.M) + "|R" + ...
        string(records.Run) + "|S" + string(records.Seed) + "|" + records.Algorithm;
    if numel(unique(keys)) ~= numel(keys)
        error('AdaMaO:DuplicateCPRScreeningResult', ...
            'Duplicate result keys were found; remove or archive duplicate run files.');
    end
end

function [perProblem,pairData] = buildPerProblem(records,alternatives,protocol,stream)
    perProblem = table(strings(0,1),strings(0,1),zeros(0,1),strings(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),false(0,1), ...
        'VariableNames',{'Family','Problem','M','Algorithm','PairCount', ...
        'MeanLogIGDRatio','GeoMeanRatio','CILower','CIUpper','SevereRegression'});
    pairData = table(strings(0,1),strings(0,1),zeros(0,1),strings(0,1), ...
        cell(0,1),'VariableNames',{'Family','Problem','M','Algorithm','LogRatios'});

    for M = protocol.objectives
        for problemIndex = 1:numel(protocol.problems)
            problem = string(protocol.problems{problemIndex});
            family = familyOf(problem);
            baseline = records(records.Problem == problem & records.M == M & ...
                records.Algorithm == "U0",:);
            for algorithm = alternatives
                alternative = records(records.Problem == problem & records.M == M & ...
                    records.Algorithm == algorithm,:);
                logRatios = pairedLogRatios(baseline,alternative);
                if isempty(logRatios)
                    continue;
                end
                [lower,upper] = bootstrapMeanRatio(logRatios,stream, ...
                    protocol.analysis.bootstrapSamples);
                meanLog = mean(logRatios);
                ratio = exp(meanLog);
                row = {family,problem,M,algorithm,numel(logRatios),meanLog,ratio, ...
                    lower,upper,ratio > protocol.analysis.severeRegressionRatio};
                perProblem(end+1,:) = row; %#ok<AGROW>
                pairData(end+1,:) = {family,problem,M,algorithm,{logRatios}}; %#ok<AGROW>
            end
        end
    end
end

function logRatios = pairedLogRatios(baseline,alternative)
    logRatios = zeros(0,1);
    for index = 1:height(alternative)
        match = baseline.Run == alternative.Run(index) & ...
            baseline.Seed == alternative.Seed(index);
        if sum(match) ~= 1
            continue;
        end
        baseValue = baseline.IGD(match);
        altValue = alternative.IGD(index);
        if isfinite(baseValue) && isfinite(altValue) && ...
                baseValue > 0 && altValue > 0
            logRatios(end+1,1) = log(altValue/baseValue); %#ok<AGROW>
        end
    end
end

function byFamily = buildByFamily(perProblem,pairData,alternatives,protocol,stream)
    byFamily = table(strings(0,1),zeros(0,1),strings(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        false(0,1),false(0,1),false(0,1), ...
        'VariableNames',{'Family','M','Algorithm','ProblemCount', ...
        'ExpectedProblemCount','GeoMeanRatio','CILower','CIUpper', ...
        'SevereRegressionCount','Complete','UpperWithinMargin', ...
        'PassNonInferiority'});
    families = ["DTLZ","WFG"];
    for M = protocol.objectives
        for family = families
            expectedProblems = string(protocol.problems);
            expectedCount = sum(startsWith(expectedProblems,family));
            for algorithm = alternatives
                rows = perProblem.M == M & perProblem.Family == family & ...
                    perProblem.Algorithm == algorithm;
                values = perProblem.MeanLogIGDRatio(rows);
                if isempty(values)
                    lower = nan;
                    upper = nan;
                    ratio = nan;
                else
                    dataRows = pairData.M == M & pairData.Family == family & ...
                        pairData.Algorithm == algorithm;
                    [lower,upper] = hierarchicalBootstrapMeanRatio( ...
                        pairData.LogRatios(dataRows),stream, ...
                        protocol.analysis.bootstrapSamples);
                    ratio = exp(mean(values));
                end
                problemCount = sum(rows);
                severeCount = sum(perProblem.SevereRegression(rows));
                complete = problemCount == expectedCount && ...
                    all(perProblem.PairCount(rows) == protocol.runs);
                upperWithinMargin = isfinite(upper) && ...
                    upper <= protocol.analysis.nonInferiorityMargin;
                pass = complete && upperWithinMargin && ...
                    severeCount <= protocol.analysis.maxSevereRegressionCount;
                row = {family,M,algorithm,problemCount,expectedCount,ratio, ...
                    lower,upper,severeCount,complete,upperWithinMargin,pass};
                byFamily(end+1,:) = row; %#ok<AGROW>
            end
        end
    end
end

function decision = buildDecision(byFamily,objectives)
    decision = table(zeros(0,1),false(0,1),false(0,1),strings(0,1), ...
        strings(0,1),'VariableNames',{'M','F01Pass','F11Pass','Code','Summary'});
    for M = objectives
        f01Pass = variantPasses(byFamily,M,"F01");
        f11Pass = variantPasses(byFamily,M,"F11");
        if ~f01Pass && ~f11Pass
            code = "RETAIN_U0_REJECT_DIRECTION";
            summary = "F01 与 F11 均未通过非劣门槛，保留 U0。";
        elseif ~f01Pass && f11Pass
            code = "ADOPT_F11_JOINT_CHANGE_REQUIRED";
            summary = "仅 F11 通过，评分源与软关系需要联合改造。";
        elseif f01Pass && ~f11Pass
            code = "F01_ENGINEERING_ONLY";
            summary = "仅 F01 通过，可保留为工程简化，不作为主创新。";
        else
            code = "F11_CANDIDATE_REQUIRES_STABLE_GAIN_CHECK";
            summary = "F01 与 F11 均非劣，需继续检查 F11 相对 U0/F01 的稳定增益。";
        end
        decision(end+1,:) = {M,f01Pass,f11Pass,code,summary}; %#ok<AGROW>
    end
end

function pass = variantPasses(byFamily,M,algorithm)
    rows = byFamily.M == M & byFamily.Algorithm == algorithm;
    pass = sum(rows) == 2 && all(byFamily.PassNonInferiority(rows));
end

function [lower,upper] = bootstrapMeanRatio(values,stream,sampleCount)
    values = values(:);
    if numel(values) == 1
        lower = exp(values);
        upper = lower;
        return;
    end
    indices = randi(stream,numel(values),numel(values),sampleCount);
    bootMeans = mean(values(indices),1);
    bounds = quantile(bootMeans,[0.025,0.975]);
    lower = exp(bounds(1));
    upper = exp(bounds(2));
end

function [lower,upper] = hierarchicalBootstrapMeanRatio(problemSamples,stream,sampleCount)
    problemCount = numel(problemSamples);
    if problemCount == 0
        lower = nan;
        upper = nan;
        return;
    end
    selectedProblems = randi(stream,problemCount,problemCount,sampleCount);
    slotMeans = zeros(problemCount,sampleCount);
    for slot = 1:problemCount
        for problemIndex = 1:problemCount
            columns = find(selectedProblems(slot,:) == problemIndex);
            if isempty(columns)
                continue;
            end
            values = problemSamples{problemIndex}(:);
            indices = randi(stream,numel(values),numel(values),numel(columns));
            slotMeans(slot,columns) = mean(values(indices),1);
        end
    end
    bootMeans = mean(slotMeans,1);
    bounds = quantile(bootMeans,[0.025,0.975]);
    lower = exp(bounds(1));
    upper = exp(bounds(2));
end

function family = familyOf(problem)
    if startsWith(problem,"DTLZ")
        family = "DTLZ";
    else
        family = "WFG";
    end
end
