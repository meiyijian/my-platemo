function outputs = analyze_CandidateModeContribution(stage,profile,options)
%ANALYZE_CANDIDATEMODECONTRIBUTION Analyze one complete staged data set.

    arguments
        stage {mustBeTextScalar}
        profile {mustBeTextScalar}
        options.ResultRoot {mustBeTextScalar} = ""
        options.Arms = strings(0,1)
    end
    setup = CMCSetupPaths();
    protocol = CMCProtocol(stage,profile);
    if ~isempty(options.Arms) && protocol.Profile ~= "smoke"
        error('CMC:PartialScientificAnalysisForbidden', ...
            ['Scientific gates must analyze every arm authorized by the ', ...
             'upstream stage. Use Arms only while running batches, then ', ...
             'analyze without an Arms filter.']);
    end
    resultRoot = string(options.ResultRoot);
    if strlength(resultRoot) == 0
        resultRoot = string(setup.DefaultResultRoot);
    end
    expectedUpstreamHash = "";
    if protocol.Stage ~= "stage0"
        upstream = CMCRequirePreviousGate(protocol,resultRoot);
        expectedUpstreamHash = upstream.DecisionHash;
    end
    arms = CMCResolveArms(protocol,resultRoot,options.Arms);
    jobs = CMCExpandJobs(protocol,arms);
    paths = CMCStagePaths(protocol,resultRoot);
    if ~isfolder(paths.AnalysisRoot)
        mkdir(paths.AnalysisRoot);
    end

    collected = collectRuns(protocol,paths,jobs,expectedUpstreamHash);
    coverage = buildCoverage(collected.JobStatus,protocol);
    integrity = buildIntegrity(protocol,paths,collected,coverage);
    prefix = "CMC_Stage" + string(protocol.StageNumber);
    CMCWriteTableAtomic(collected.JobStatus,fullfile(paths.AnalysisRoot, ...
        char(prefix+"_JobStatus.csv")));
    CMCWriteTableAtomic(coverage,fullfile(paths.AnalysisRoot, ...
        char(prefix+"_Coverage.csv")));
    CMCWriteTableAtomic(integrity,fullfile(paths.AnalysisRoot, ...
        char(prefix+"_IntegrityGate.csv")));

    switch protocol.Stage
        case "stage0"
            [tables,decision] = analyzeStage0( ...
                protocol,paths,collected,integrity);
        case "stage1"
            [tables,decision] = analyzeStage1( ...
                protocol,paths,collected,integrity,resultRoot);
        case {"stage2","stage3"}
            [tables,decision] = analyzeEndpoint( ...
                protocol,collected,integrity,resultRoot);
    end
    names = fieldnames(tables);
    for index = 1:numel(names)
        CMCWriteTableAtomic(tables.(names{index}),fullfile( ...
            paths.AnalysisRoot,[names{index},'.csv']));
    end
    CMCWriteTableAtomic(decision,fullfile(paths.AnalysisRoot, ...
        char(prefix+"_ScientificDecision.csv")));
    outputs = struct('Protocol',protocol,'Paths',paths,'Coverage',coverage, ...
        'IntegrityGate',integrity,'ScientificDecision',decision, ...
        'Tables',tables);
end

function collected = collectRuns(protocol,paths,jobs,expectedUpstreamHash)
    jobRows = cell(height(jobs),8);
    activity = table(); snapshots = table(); references = table();
    endpoints = table();
    for index = 1:height(jobs)
        job = jobs(index,:);
        filePath = CMCResultPath(paths,job);
        observed = isfile(filePath);
        valid = false;
        detail = "missing";
        if observed
            [valid,report] = CMCValidateRunFile( ...
                filePath,protocol,job,expectedUpstreamHash);
            detail = report.Detail;
        end
        jobRows(index,:) = {job.Problem,job.Family,job.M,job.Run,job.Arm, ...
            observed,valid,string(filePath)};
        if ~valid
            continue;
        end
        data = load(filePath,'metadata','IGD','IGDp','anytimeIGDpAUC','runtime', ...
            'activityRows','snapshotRows','referenceRows');
        if ~isempty(data.activityRows)
            activity = appendTable(activity,decorateAudit( ...
                data.activityRows,data.metadata,"activity"));
        end
        if ~isempty(data.snapshotRows)
            snapshots = appendTable(snapshots,decorateAudit( ...
                data.snapshotRows,data.metadata,"snapshot"));
        end
        if ~isempty(data.referenceRows)
            references = appendTable(references,decorateAudit( ...
                data.referenceRows,data.metadata,"reference"));
        end
        endpoints = appendTable(endpoints,endpointRow( ...
            data.metadata,data.IGD,data.IGDp,data.anytimeIGDpAUC, ...
            data.runtime,filePath));
    end
    jobStatus = cell2table(jobRows,'VariableNames', ...
        {'Problem','Family','M','Run','Arm','Observed','Valid','ResultFile'});
    jobStatus.Detail = strings(height(jobStatus),1);
    for index = 1:height(jobStatus)
        if jobStatus.Valid(index)
            jobStatus.Detail(index) = "PASS";
        elseif jobStatus.Observed(index)
            jobStatus.Detail(index) = "INVALID";
        else
            jobStatus.Detail(index) = "MISSING";
        end
    end
    collected = struct('Jobs',jobs,'JobStatus',jobStatus, ...
        'Activity',activity,'Snapshots',snapshots,'References',references, ...
        'Endpoints',endpoints);
end

function value = decorateAudit(raw,metadata,kind)
    count = height(raw);
    prefix = table( ...
        repmat(metadata.SchemaVersion,count,1), ...
        repmat(string(metadata.Profile),count,1), ...
        repmat(string(metadata.ProtocolHash),count,1), ...
        repmat(string(metadata.Problem),count,1), ...
        repmat(string(metadata.Family),count,1), ...
        repmat(metadata.M,count,1),repmat(metadata.Run,count,1), ...
        repmat(metadata.SearchSeed,count,1), ...
        repmat(string(metadata.PairedKey),count,1), ...
        'VariableNames',{'SchemaVersion','Profile','ProtocolHash','Problem', ...
        'Family','M','Run','Seed','PairedKey'});
    value = [prefix,raw];
    if ismember(kind,["activity","snapshot"])
        value.StageBin = arrayfun(@stageBin,value.FERatio);
        value = movevars(value,'StageBin','After','FERatio');
    end
end

function row = endpointRow(metadata,IGD,IGDp,anytimeIGDpAUC,runtime,filePath)
    enabled = enabledFactors(string(metadata.Arm));
    row = table(metadata.SchemaVersion,string(metadata.Profile), ...
        string(metadata.ProtocolHash),string(metadata.UpstreamDecisionHash), ...
        string(metadata.MATLABVersion),string(metadata.Computer), ...
        string(metadata.HostName), ...
        string(metadata.Problem),string(metadata.Family),metadata.M, ...
        metadata.RequestedD,metadata.ActualD,metadata.N,metadata.MaxFE, ...
        metadata.Run,metadata.SearchSeed,string(metadata.PairedKey), ...
        string(metadata.Arm),string(metadata.AlgorithmClass),enabled, ...
        metadata.CompletedFE,IGD,IGDp,anytimeIGDpAUC,runtime,NaN,NaN,NaN,NaN, ...
        true,string(filePath), ...
        'VariableNames',{'SchemaVersion','Profile','ProtocolHash', ...
        'UpstreamDecisionHash','MATLABVersion','Computer','HostName', ...
        'Problem','Family','M','RequestedD', ...
        'ActualD','N','MaxFE','Run','Seed','PairedKey','Arm', ...
        'AlgorithmClass','EnabledFactors','CompletedFE','IGD','IGDp', ...
        'AnytimeIGDpAUC','WallTime','ArchiveEntryRate', ...
        'MeanBatchGainPerFE','WastedFECount','FixedNicheCoverage', ...
        'Valid','ResultFile'});
end

function value = enabledFactors(arm)
    catalog = CMCArmCatalog();
    row = catalog(catalog.Arm == arm,:);
    if isempty(row)
        value = "AUDIT";
    elseif arm == "A00_FULL"
        value = "P,Q,C,D,E_GEN,E_FINAL,F,G";
    else
        value = row.Factor;
    end
end

function value = appendTable(value,newRows)
    if isempty(value)
        value = newRows;
    else
        value = [value;newRows];
    end
end

function value = stageBin(ratio)
    if ratio < 1/3
        value = "early";
    elseif ratio < 2/3
        value = "middle";
    else
        value = "late";
    end
end

function coverage = buildCoverage(status,protocol)
    keys = unique(status(:,{'Problem','Family','M','Arm'}),'rows','stable');
    rows = cell(height(keys),12);
    for index = 1:height(keys)
        key = keys(index,:);
        mask = status.Problem == key.Problem & status.M == key.M & ...
            status.Arm == key.Arm;
        expected = nnz(mask);
        observed = nnz(status.Observed(mask));
        valid = nnz(status.Valid(mask));
        rows(index,:) = {protocol.Stage,protocol.Profile,key.Problem,key.Family, ...
            key.M,key.Arm, ...
            expected,observed,valid,expected-observed,observed-valid, ...
            valid == expected};
    end
    coverage = cell2table(rows,'VariableNames',{'Stage','Profile','Problem', ...
        'Family','M','Arm','ExpectedRuns','ObservedRuns','ValidRuns', ...
        'MissingRuns','InvalidRuns','Complete'});
end

function integrity = buildIntegrity(protocol,paths,collected,coverage)
    required = height(collected.JobStatus);
    valid = nnz(collected.JobStatus.Valid);
    missing = nnz(~collected.JobStatus.Observed);
    invalid = nnz(collected.JobStatus.Observed & ~collected.JobStatus.Valid);
    sourceStatus = "NOT_APPLICABLE";
    sourcePass = true;
    if protocol.Stage == "stage0"
        sourceFile = fullfile(paths.AnalysisRoot, ...
            'CMC_Stage0_SourceTwinEquivalence.csv');
        if isfile(sourceFile)
            source = readtable(sourceFile,'TextType','string');
            sourceStatus = source.Status(1);
            sourcePass = height(source) == 1 && sourceStatus == "PASS" && ...
                ismember("ProtocolHash", ...
                string(source.Properties.VariableNames)) && ...
                source.ProtocolHash(1) == protocol.ProtocolHash;
        else
            sourceStatus = "MISSING";
            sourcePass = false;
        end
    end
    auditComplete = true;
    if protocol.Stage == "stage0"
        auditComplete = ~isempty(collected.Activity);
    elseif protocol.Stage == "stage1"
        auditComplete = ~isempty(collected.Snapshots) && ...
            ~isempty(collected.References);
        if auditComplete
            referenceGroups = findgroups(collected.References.PairedKey);
            counts = splitapply(@numel,collected.References.SnapshotID, ...
                referenceGroups);
            auditComplete = all(counts >= numel(protocol.Checkpoints));
        end
    end
    pass = valid == required && missing == 0 && invalid == 0 && ...
        all(coverage.Complete) && sourcePass && auditComplete;
    status = string(ternary(pass,'PASS','FAIL'));
    reasons = strings(0,1);
    if valid ~= required, reasons(end+1) = "INCOMPLETE_OR_INVALID_JOBS"; end %#ok<AGROW>
    if ~sourcePass, reasons(end+1) = "SOURCE_TWIN_MISMATCH_OR_MISSING"; end %#ok<AGROW>
    if ~auditComplete, reasons(end+1) = "AUDIT_ROWS_INCOMPLETE"; end %#ok<AGROW>
    if isempty(reasons), reasons = "ALL_REQUIRED_DATA_VALID"; end
    integrity = table(protocol.ProtocolHash,status,required,valid,missing, ...
        invalid,sourceStatus,auditComplete,strjoin(reasons,";"), ...
        string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
        'VariableNames',{'ProtocolHash','Status','RequiredJobs','ValidJobs', ...
        'MissingJobs','InvalidJobs','SourceTwinStatus','AuditComplete', ...
        'Reason','GeneratedAt'});
end

function [tables,decision] = analyzeStage0(protocol,paths,collected,integrity)
    events = collected.Activity;
    factorActivity = stage0FactorActivity(events,protocol);
    factorDecision = factorActivity(:,{'Factor','FactorStatus','CarryToStage1', ...
        'Reason'});
    factorDecision.Properties.VariableNames{'CarryToStage1'} = 'CarryToNextStage';
    if integrity.Status ~= "PASS"
        if integrity.SourceTwinStatus ~= "PASS"
            code = "STOP_TRAJECTORY_MISMATCH";
        else
            code = "STOP_SCHEMA_INVALID";
        end
    elseif protocol.Profile == "smoke"
        code = "SMOKE_PASS";
    elseif isempty(events)
        code = "INSUFFICIENT_DATA";
    elseif all(ismember(factorActivity.FactorStatus( ...
            ismember(factorActivity.Factor, ...
            ["P","Q","C","D","E_GEN","E_FINAL","F","G"])), ...
            "INSUFFICIENT_OPPORTUNITIES"))
        code = "INSUFFICIENT_BEHAVIORAL_OPPORTUNITIES";
    elseif ~any(factorActivity.CarryToStage1 & ...
            ismember(factorActivity.Factor, ...
            ["P","Q","C","D","E_GEN","E_FINAL","F","G"]))
        code = "STOP_NO_BEHAVIORAL_ACTIVITY";
    else
        primary = ["P","Q","C","D","E_GEN","E_FINAL","F","G"];
        carried = factorActivity.Factor(factorActivity.CarryToStage1);
        code = string(ternary(all(ismember(primary,carried)), ...
            'PASS_TO_STAGE1','PASS_TO_STAGE1_REDUCED'));
    end
    decision = decisionRow(protocol,integrity,code, ...
        factorActivity.Factor(factorActivity.CarryToStage1), ...
        factorActivity.Factor(~factorActivity.CarryToStage1), ...
        "NOT_APPLICABLE",stage0Reason(code));
    tables = struct('CMC_Stage0_EventAudit',events, ...
        'CMC_Stage0_FactorActivity',factorActivity, ...
        'CMC_Stage0_FactorDecision',factorDecision);
end

function summary = stage0FactorActivity(events,protocol)
    factors = ["P","Q","K","C","D","E_GEN","E_FINAL", ...
        "F","G","P_ERR_GATE"];
    rows = cell(numel(factors),14);
    if isempty(events) || ~ismember('Factor',events.Properties.VariableNames)
        for index = 1:numel(factors)
            rows(index,:) = {factors(index),0,0,0,0,NaN,NaN,NaN,0,0, ...
                "INSUFFICIENT_OPPORTUNITIES",false,"no valid events", ...
                protocol.ProtocolHash};
        end
        summary = cell2table(rows,'VariableNames',{'Factor','EligibleRuns', ...
            'EligibleEvents','TriggeredEvents','ChangedEvents', ...
            'MedianRunTriggerRate','MedianRunChangeRate','MedianRunOverlapAtK', ...
            'DTLZEligibleRuns','WFGEligibleRuns','FactorStatus','CarryToStage1', ...
            'Reason','ProtocolHash'});
        return;
    end
    for index = 1:numel(factors)
        factor = factors(index);
        data = events(events.Factor == factor,:);
        eligibleData = data(data.Eligible,:);
        runKeys = unique(eligibleData(:,{'PairedKey','Family'}),'rows');
        triggerRates = NaN(height(runKeys),1);
        changeRates = NaN(height(runKeys),1);
        overlapRates = NaN(height(runKeys),1);
        for runIndex = 1:height(runKeys)
            mask = eligibleData.PairedKey == runKeys.PairedKey(runIndex);
            triggerRates(runIndex) = mean(eligibleData.Triggered(mask));
            changeRates(runIndex) = mean(eligibleData.DecisionChanged(mask));
            overlapRates(runIndex) = median( ...
                eligibleData.OverlapAtK(mask),'omitnan');
        end
        eligibleRuns = height(runKeys);
        dtlzRuns = nnz(runKeys.Family == "DTLZ");
        wfgRuns = nnz(runKeys.Family == "WFG");
        enough = protocol.Profile == "smoke" || ...
            (eligibleRuns >= 4 && dtlzRuns >= 2 && wfgRuns >= 2 && ...
            height(eligibleData) >= 30);
        medianTrigger = median(triggerRates,'omitnan');
        medianChange = median(changeRates,'omitnan');
        medianOverlap = median(overlapRates,'omitnan');
        if factor == "K" && enough && all(data.SelectedK == 6)
            status = "CONSTANT_K6_NOT_ADAPTIVE";
        elseif ~enough
            status = "INSUFFICIENT_OPPORTUNITIES";
        elseif medianTrigger < protocol.Thresholds.ActivityRate
            status = "LOW_TRIGGER";
        elseif isfinite(medianOverlap) && ...
                medianOverlap > protocol.Thresholds.MaxOverlapAtK
            status = "LOW_DECISION_SEPARATION";
        elseif medianChange >= protocol.Thresholds.ActivityRate
            status = "ACTIVE";
        elseif medianChange > 0
            status = "LOW_ACTIVITY";
        else
            status = "DORMANT";
        end
        carry = status == "ACTIVE";
        reason = "trigger="+string(medianTrigger)+ ...
            "; change="+string(medianChange)+ ...
            "; overlap@K="+string(medianOverlap);
        rows(index,:) = {factor,eligibleRuns,height(eligibleData), ...
            nnz(eligibleData.Triggered),nnz(eligibleData.DecisionChanged), ...
            medianTrigger,medianChange,medianOverlap, ...
            dtlzRuns,wfgRuns,status,carry,reason,protocol.ProtocolHash};
    end
    summary = cell2table(rows,'VariableNames',{'Factor','EligibleRuns', ...
        'EligibleEvents','TriggeredEvents','ChangedEvents', ...
        'MedianRunTriggerRate','MedianRunChangeRate','MedianRunOverlapAtK', ...
        'DTLZEligibleRuns','WFGEligibleRuns','FactorStatus','CarryToStage1', ...
        'Reason','ProtocolHash'});
end

function reason = stage0Reason(code)
    if startsWith(code,"PASS") || code == "SMOKE_PASS"
        reason = "行为活性门通过；这不证明最终IGD+收益。";
    else
        reason = "未满足预注册的行为活性推进条件。";
    end
end

function [tables,decision] = analyzeStage1( ...
        protocol,paths,collected,integrity,resultRoot)
    snapshots = collected.Snapshots;
    references = collected.References;
    [perRun,comparisons,factorDecision] = directComparisons( ...
        snapshots,protocol,resultRoot);
    stableReference = ~isempty(references) && all(references.Stable);
    if integrity.Status ~= "PASS"
        code = "STOP_COUNTERFACTUAL_INVALID";
    elseif protocol.Profile == "smoke"
        code = "SMOKE_PASS";
    elseif ~stableReference
        code = "INSUFFICIENT_REFERENCE_STABILITY";
    elseif isempty(snapshots) || ...
            ~any(snapshots.UtilityStatus == "PASS")
        code = "INSUFFICIENT_UTILITY_VARIATION";
    else
        code = CMCStage1GateCode(factorDecision);
    end
    canProceed = startsWith(code,"PASS_TO_STAGE2") || code == "SMOKE_PASS";
    factorDecision.CarryToNextStage = ...
        factorDecision.CarryToNextStage & canProceed;
    qualified = factorDecision.Factor(factorDecision.CarryToNextStage);
    dropped = factorDecision.Factor(~factorDecision.CarryToNextStage);
    referenceStatus = string(ternary(stableReference,'PASS', ...
        'INSUFFICIENT_REFERENCE_STABILITY'));
    decision = decisionRow(protocol,integrity,code,qualified,dropped, ...
        referenceStatus, ...
        "同状态直接效应以run为统计单位；不代表端点性能因果优势。");
    tables = struct('CMC_Stage1_SnapshotUtility',snapshots, ...
        'CMC_Stage1_ReferenceSensitivity',references, ...
        'CMC_Stage1_PerRun',perRun, ...
        'CMC_Stage1_PairedComparisons',comparisons, ...
        'CMC_Stage1_FactorDecision',factorDecision);
end

function [perRun,comparisons,decisions] = directComparisons( ...
        snapshots,protocol,resultRoot)
    definitions = { ...
        'P','ACCUM_MATCHED','FINAL_MATCHED'; ...
        'Q','EXP_FULL','EXP_NO_Q'; ...
        'C','EXP_FULL','EXP_NO_C'; ...
        'D','EXP_FULL','EXP_NO_D'; ...
        'E_FINAL','EXP_FULL','EXP_SIMPLE_FULL'; ...
        'F','IND_FULL','IND_RELATION_ONLY'; ...
        'D_SIGNAL','EXP_FULL','SHUFFLED_D'; ...
        'F_SIGNAL','IND_FULL','SHUFFLED_F'; ...
        'P_ERR_GATE','EXP_FULL','EXP_NO_PERR_GATE'};
    runRows = cell(0,12);
    comparisonRows = cell(size(definitions,1),18);
    decisionRows = cell(0,10);
    for definition = 1:size(definitions,1)
        factor = string(definitions{definition,1});
        ruleA = string(definitions{definition,2});
        ruleB = string(definitions{definition,3});
        paired = pairSnapshotRules(snapshots,ruleA,ruleB);
        keys = unique(paired(:,{'Problem','Family','M','Run','Seed','PairedKey'}), ...
            'rows','stable');
        startRow = size(runRows,1)+1;
        for keyIndex = 1:height(keys)
            key = keys(keyIndex,:);
            mask = paired.PairedKey == key.PairedKey;
            delta = mean(paired.EfficiencyA(mask)-paired.EfficiencyB(mask), ...
                'omitnan');
            randomPercentile = median(paired.RandomPercentileA(mask),'omitnan');
            runRows(end+1,:) = {factor,ruleA,ruleB,key.Problem,key.Family, ...
                key.M,key.Run,key.Seed,key.PairedKey,nnz(mask),delta, ...
                randomPercentile}; %#ok<AGROW>
        end
        stopRow = size(runRows,1);
        if stopRow >= startRow
            local = cell2table(runRows(startRow:stopRow,:), ...
                'VariableNames',{'Factor','RuleA','RuleB','Problem','Family', ...
                'M','Run','Seed','PairedKey','ValidSnapshots','MeanDelta', ...
                'MedianRandomPercentile'});
            delta = local.MeanDelta;
            problemGroups = string(local.Problem)+"_M"+string(local.M);
            [groupIndex,~] = findgroups(problemGroups);
            cellMeans = splitapply(@(x)mean(x,'omitnan'),delta,groupIndex);
            equalCellMean = mean(cellMeans,'omitnan');
            [ciLower,ciUpper] = CMCBootstrapMeanCI(delta,problemGroups, ...
                protocol.Thresholds.BootstrapSamples, ...
                protocol.Thresholds.BootstrapSeed+definition);
            stats = CMCComparePaired(delta,zeros(size(delta)));
            coveragePass = stage1Coverage(local,protocol);
            randomPass = median(local.MedianRandomPercentile, ...
                'omitnan') >= 0.75;
            practical = equalCellMean >= protocol.Thresholds.DirectMCID;
            statistical = ciLower > 0;
            qualified = coveragePass && practical && statistical && randomPass;
            if ~coveragePass
                factorStatus = "INSUFFICIENT_COVERAGE";
            else
                factorStatus = string(ternary( ...
                    qualified,'QUALIFIED','NOT_QUALIFIED'));
            end
            comparisonRows(definition,:) = {factor,ruleA,ruleB,height(local), ...
                numel(unique(string(local.Problem))),coveragePass, ...
                equalCellMean,stats.MedianDelta,stats.HodgesLehmann, ...
                ciLower,ciUpper,stats.PValueRaw,NaN,stats.RankBiserial, ...
                stats.PairedWinProbability,protocol.Thresholds.DirectMCID, ...
                practical && statistical,factorStatus};
            decisionRows(end+1,:) = {factor,factorStatus,qualified, ...
                equalCellMean,ciLower,ciUpper,coveragePass,randomPass, ...
                ruleA+" vs "+ruleB,protocol.ProtocolHash}; %#ok<AGROW>
        else
            comparisonRows(definition,:) = {factor,ruleA,ruleB,0,0,false, ...
                NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
                protocol.Thresholds.DirectMCID,false,"INSUFFICIENT_DATA"};
            decisionRows(end+1,:) = {factor,"INSUFFICIENT_DATA",false, ...
                NaN,NaN,NaN,false,false,ruleA+" vs "+ruleB, ...
                protocol.ProtocolHash}; %#ok<AGROW>
        end
    end
    if isempty(runRows)
        perRun = table();
    else
        perRun = cell2table(runRows,'VariableNames',{'Factor','RuleA','RuleB', ...
            'Problem','Family','M','Run','Seed','PairedKey', ...
            'ValidSnapshots','MeanDelta','MedianRandomPercentile'});
    end
    comparisons = cell2table(comparisonRows,'VariableNames', ...
        {'Factor','RuleA','RuleB','ValidRuns','ValidProblems','Complete', ...
        'MeanDeltaOracleEfficiency','MedianDelta','HodgesLehmann', ...
        'CI95Lower','CI95Upper','RawP','HolmP','RankBiserial', ...
        'PairedWinProbability','DirectMCID','PracticalPass','FactorDecision'});
    comparisons.HolmP = CMCHolmAdjust(comparisons.RawP,height(comparisons));
    decisions = cell2table(decisionRows,'VariableNames',{'Factor', ...
        'FactorDecision','CarryToNextStage','MeanDeltaOracleEfficiency', ...
        'CI95Lower','CI95Upper','CoveragePass','RandomPercentilePass', ...
        'Contrast','ProtocolHash'});
    decisions = applyStage0Authorization(decisions,protocol,resultRoot);
    decisions = addDeferredFactors(decisions,protocol,resultRoot);
end

function pass = stage1Coverage(local,protocol)
    pass = true;
    for family = ["DTLZ","WFG"]
        for M = protocol.Objectives
            stratum = local(local.Family == family & local.M == M,:);
            pass = pass && height(stratum) >= 4 && ...
                numel(unique(stratum.Problem)) >= 2;
        end
    end
end

function decisions = applyStage0Authorization(decisions,protocol,resultRoot)
    previous = CMCProtocol('stage0',protocol.Profile);
    paths = CMCStagePaths(previous,resultRoot);
    filePath = fullfile(paths.AnalysisRoot,'CMC_Stage0_FactorDecision.csv');
    if ~isfile(filePath)
        decisions.CarryToNextStage(:) = false;
        decisions.FactorDecision(:) = "MISSING_STAGE0_AUTHORIZATION";
        return;
    end
    activity = readtable(filePath,'TextType','string');
    for index = 1:height(decisions)
        activityFactor = decisions.Factor(index);
        if activityFactor == "D_SIGNAL"
            activityFactor = "D";
        elseif activityFactor == "F_SIGNAL"
            activityFactor = "F";
        end
        row = activity(activity.Factor == activityFactor,:);
        authorized = ~isempty(row) && logical(row.CarryToNextStage(1));
        if ~authorized
            decisions.CarryToNextStage(index) = false;
            decisions.FactorDecision(index) = ...
                "NOT_AUTHORIZED_BY_STAGE0_ACTIVITY";
            decisions.Contrast(index) = decisions.Contrast(index)+ ...
                "; Stage0未授权";
        end
    end
end

function paired = pairSnapshotRules(snapshots,ruleA,ruleB)
    keys = {'Problem','Family','M','Run','Seed','PairedKey','SnapshotID'};
    if isempty(snapshots) || ~ismember('Rule',snapshots.Properties.VariableNames)
        paired = table('Size',[0,10], ...
            'VariableTypes',{'string','string','double','double','double', ...
            'string','double','double','double','double'}, ...
            'VariableNames',[keys, ...
            {'EfficiencyA','RandomPercentileA','EfficiencyB'}]);
        return;
    end
    a = snapshots(snapshots.Rule == ruleA & ...
        snapshots.UtilityStatus == "PASS",[keys, ...
        {'OracleEfficiency','RandomPercentile'}]);
    b = snapshots(snapshots.Rule == ruleB & ...
        snapshots.UtilityStatus == "PASS",[keys,{'OracleEfficiency'}]);
    a.Properties.VariableNames(end-1:end) = {'EfficiencyA','RandomPercentileA'};
    b.Properties.VariableNames(end) = {'EfficiencyB'};
    paired = innerjoin(a,b,'Keys',keys);
end

function decisions = addDeferredFactors(decisions,protocol,resultRoot)
    previous = CMCProtocol('stage0',protocol.Profile);
    paths = CMCStagePaths(previous,resultRoot);
    filePath = fullfile(paths.AnalysisRoot,'CMC_Stage0_FactorActivity.csv');
    for factor = ["E_GEN","G"]
        carry = false;
        if isfile(filePath)
            activity = readtable(filePath,'TextType','string');
            row = activity(activity.Factor == factor,:);
            carry = ~isempty(row) && logical(row.CarryToStage1(1));
        end
        status = string(ternary(carry,'DEFER_TO_STAGE2','NOT_QUALIFIED'));
        newRow = table(factor,status,carry,NaN,NaN,NaN,carry,false, ...
            "不能在同一冻结候选池上归因",protocol.ProtocolHash, ...
            'VariableNames',decisions.Properties.VariableNames);
        decisions = [decisions;newRow];
    end
end

function [tables,decision] = analyzeEndpoint( ...
        protocol,collected,integrity,resultRoot)
    endpoints = collected.Endpoints;
    [comparisons,armDecision] = endpointComparisons(endpoints,protocol);
    if integrity.Status ~= "PASS"
        code = string(ternary(protocol.Stage == "stage2", ...
            'INSUFFICIENT_DATA','INSUFFICIENT_FORMAL_DATA'));
    elseif protocol.Profile == "smoke"
        code = "SMOKE_PASS";
    elseif protocol.Stage == "stage2"
        code = stage2Code(armDecision,protocol,resultRoot);
    else
        code = stage3Code(armDecision,protocol,resultRoot);
    end
    canProceed = startsWith(code,"PASS_TO_STAGE3") || code == "SMOKE_PASS";
    if protocol.Stage == "stage2"
        armDecision.CarryToNextStage = ...
            armDecision.CarryToNextStage & canProceed;
        anchorMask = armDecision.Arm == "CURRENT_HCV";
        if canProceed && any(anchorMask) && ...
                CMCAnchorCompatible(armDecision,protocol)
            armDecision.CarryToNextStage(anchorMask) = true;
        end
    else
        armDecision.CarryToNextStage(:) = false;
    end
    [qualified,dropped] = CMCSummarizeEvidenceFactors(armDecision);
    decision = decisionRow(protocol,integrity,code,qualified,dropped, ...
        "NOT_APPLICABLE",endpointReason(protocol.Stage,code));
    prefix = "CMC_Stage"+string(protocol.StageNumber);
    tables = struct();
    tables.(char(prefix+"_PerRunEndpoint")) = endpoints;
    tables.(char(prefix+"_EndpointComparisons")) = comparisons;
    tables.(char(prefix+"_ArmDecision")) = armDecision;
end

function [comparisons,armDecision] = endpointComparisons(endpoints,protocol)
    if isempty(endpoints) || ~ismember('Arm',endpoints.Properties.VariableNames)
        comparisons = cell2table(cell(0,24), ...
            'VariableNames',endpointComparisonNames());
        armDecision = emptyArmDecision();
        return;
    end
    full = endpoints(endpoints.Arm == "A00_FULL",:);
    if isempty(full)
        comparisons = cell2table(cell(0,24), ...
            'VariableNames',endpointComparisonNames());
        armDecision = emptyArmDecision();
        return;
    end
    comparatorArms = setdiff(unique(endpoints.Arm,'stable'),"A00_FULL",'stable');
    rows = cell(0,24);
    summaryRows = cell(0,21);
    for armIndex = 1:numel(comparatorArms)
        arm = comparatorArms(armIndex);
        other = endpoints(endpoints.Arm == arm,:);
        cells = unique(full(:,{'Problem','Family','M'}),'rows','stable');
        rawLogRatio = zeros(0,1);
        rawCell = strings(0,1);
        rawM = zeros(0,1);
        cellStart = size(rows,1)+1;
        for cellIndex = 1:height(cells)
            key = cells(cellIndex,:);
            a = full(full.Problem == key.Problem & full.M == key.M, ...
                {'PairedKey','IGDp'});
            b = other(other.Problem == key.Problem & other.M == key.M, ...
                {'PairedKey','IGDp'});
            a.Properties.VariableNames{'IGDp'} = 'IGDpA';
            b.Properties.VariableNames{'IGDp'} = 'IGDpB';
            paired = innerjoin(a,b,'Keys','PairedKey');
            numerator = max(paired.IGDpA,realmin('double'));
            denominator = max(paired.IGDpB,realmin('double'));
            logRatio = log(numerator)-log(denominator);
            logRatio(paired.IGDpA == 0 & paired.IGDpB == 0) = 0;
            cellKey = key.Problem+"_M"+string(key.M);
            rawLogRatio = [rawLogRatio;logRatio]; %#ok<AGROW>
            rawCell = [rawCell;repmat(cellKey,height(paired),1)]; %#ok<AGROW>
            rawM = [rawM;repmat(key.M,height(paired),1)]; %#ok<AGROW>
            [ciLogLower,ciLogUpper] = CMCBootstrapMeanCI(logRatio, ...
                paired.PairedKey,protocol.Thresholds.BootstrapSamples, ...
                protocol.Thresholds.BootstrapSeed+armIndex*100+cellIndex);
            stats = CMCComparePaired(paired.IGDpB,paired.IGDpA);
            rho = exp(mean(logRatio,'omitnan'));
            factor = armFactor(arm);
            rows(end+1,:) = {arm+"_"+key.Problem+"_M"+string(key.M), ...
                factor,key.Problem,key.Family,key.M,"A00_FULL",arm, ...
                numel(protocol.Runs),height(paired), ...
                height(paired)==numel(protocol.Runs),mean(logRatio,'omitnan'), ...
                rho,exp(ciLogLower),exp(ciLogUpper),stats.MedianDelta, ...
                stats.HodgesLehmann,stats.PValueRaw,NaN,stats.RankBiserial, ...
                stats.PairedWinProbability,rho<=protocol.Thresholds.EndpointMCIDRatio, ...
                exp(ciLogUpper)<=protocol.Thresholds.NonInferiorityMargin, ...
                rho>=protocol.Thresholds.SevereRegressionRatio,"PENDING"}; %#ok<AGROW>
        end
        cellStop = size(rows,1);
        local = cell2table(rows(cellStart:cellStop,:), ...
            'VariableNames',endpointComparisonNames());
        logValues = local.MeanLogRatioIGDp;
        [lowerLog,upperLog] = CMCBootstrapMeanCI( ...
            rawLogRatio,rawCell, ...
            protocol.Thresholds.BootstrapSamples, ...
            protocol.Thresholds.BootstrapSeed+5000+armIndex);
        rho = exp(mean(logValues,'omitnan'));
        lower = exp(lowerLog); upper = exp(upperLog);
        [mRatios,mUppers] = perMSummaries(local,rawLogRatio,rawCell,rawM, ...
            protocol,armIndex);
        maxMUpper = max(mUppers,[],'omitnan');
        familyMRatios = perFamilyMRatios(local,protocol);
        maxFamilyMRatio = max(familyMRatios,[],'omitnan');
        maxStratumSevere = maxFamilyMSevereCount(local,protocol);
        dtlzRho = familyRatio(local,"DTLZ");
        wfgRho = familyRatio(local,"WFG");
        severe = nnz(local.GeoMeanRatioIGDp >= ...
            protocol.Thresholds.SevereRegressionRatio);
        direction = mean(local.GeoMeanRatioIGDp<1);
        if protocol.Stage == "stage2"
            practicalQualified = ...
                rho <= protocol.Thresholds.EndpointMCIDRatio && ...
                upper < 1 && dtlzRho <= protocol.Thresholds.NonInferiorityMargin && ...
                wfgRho <= protocol.Thresholds.NonInferiorityMargin && ...
                severe <= protocol.Thresholds.MaxSevereRegressionCount;
        else
            practicalQualified = formalQualified(local,rho,upper,direction, ...
                protocol,mRatios,mUppers,familyMRatios);
        end
        armRawP = CMCHierarchicalSignFlipP(rawLogRatio,rawCell, ...
            protocol.Thresholds.SignFlipSamples, ...
            protocol.Thresholds.SignFlipSeed+armIndex);
        summaryRows(end+1,:) = {arm,armFactor(arm),rho,lower,upper, ...
            maxMUpper,maxFamilyMRatio,dtlzRho,wfgRho,severe, ...
            maxStratumSevere,direction,armRawP,NaN, ...
            practicalQualified,false,false,numel(logValues), ...
            protocol.ProtocolHash,"",false}; %#ok<AGROW>
    end
    if isempty(rows)
        comparisons = cell2table(cell(0,24), ...
            'VariableNames',endpointComparisonNames());
    else
        comparisons = cell2table(rows,'VariableNames',endpointComparisonNames());
        [groups,~] = findgroups(comparisons.ArmB);
        for group = unique(groups)'
            mask = groups == group;
            planned = numel(protocol.Problems)*numel(protocol.Objectives);
            comparisons.HolmP(mask) = ...
                CMCHolmAdjust(comparisons.RawP(mask),planned);
        end
        comparisons.Decision(comparisons.PassMCID & ...
            comparisons.PassNonInferiority) = "PRACTICAL_PASS";
        comparisons.Decision(~(comparisons.PassMCID & ...
            comparisons.PassNonInferiority)) = "NO_PASS";
    end
    if isempty(summaryRows)
        armDecision = emptyArmDecision();
    else
        armDecision = cell2table(summaryRows,'VariableNames', ...
            {'Arm','Factor','GeoMeanRatioIGDp','CI95Lower','CI95Upper', ...
            'MaxMCI95Upper','MaxFamilyMGeoMeanRatio', ...
            'DTLZGeoMeanRatio','WFGGeoMeanRatio','SevereRegressionCount', ...
            'MaxFamilyMSevereRegressionCount','DirectionFraction', ...
            'ArmRawP','ArmHolmP', ...
            'PracticalQualified','Qualified','CarryToNextStage','Cells', ...
            'ProtocolHash','Reason','IsFull'});
        armDecision.ArmHolmP = CMCHolmAdjust( ...
            armDecision.ArmRawP,height(armDecision));
        armDecision.Qualified = armDecision.PracticalQualified & ...
            armDecision.ArmHolmP <= protocol.Thresholds.Alpha;
        armDecision.CarryToNextStage = armDecision.Qualified;
    end
    fullRow = table("A00_FULL","FULL",1,1,1,1,1,1,1,0,0,1,0,0, ...
        true,true,true, ...
        numel(protocol.Problems)*numel(protocol.Objectives), ...
        protocol.ProtocolHash,"candidate arm",true, ...
        'VariableNames',armDecision.Properties.VariableNames);
    armDecision = [fullRow;armDecision];
end

function value = emptyArmDecision()
    names = {'Arm','Factor','GeoMeanRatioIGDp','CI95Lower','CI95Upper', ...
        'MaxMCI95Upper','MaxFamilyMGeoMeanRatio', ...
        'DTLZGeoMeanRatio','WFGGeoMeanRatio','SevereRegressionCount', ...
        'MaxFamilyMSevereRegressionCount','DirectionFraction', ...
        'ArmRawP','ArmHolmP','PracticalQualified', ...
        'Qualified','CarryToNextStage','Cells','ProtocolHash','Reason','IsFull'};
    types = {'string','string','double','double','double','double','double', ...
        'double','double','double','double','double','double','double', ...
        'logical','logical','logical','double','string','string','logical'};
    value = table('Size',[0,numel(names)],'VariableTypes',types, ...
        'VariableNames',names);
end

function names = endpointComparisonNames()
    names = {'ContrastID','Factor','Problem','Family','M','ArmA','ArmB', ...
        'ExpectedPairs','ValidPairs','Complete','MeanLogRatioIGDp', ...
        'GeoMeanRatioIGDp','CILower','CIUpper','MedianPairedDelta', ...
        'HodgesLehmann','RawP','HolmP','RankBiserial', ...
        'PairedWinProbability','PassMCID','PassNonInferiority', ...
        'SevereRegression','Decision'};
end

function factor = armFactor(arm)
    catalog = CMCArmCatalog();
    row = catalog(catalog.Arm == arm,:);
    if isempty(row), factor = "UNKNOWN"; else, factor = row.Factor(1); end
end

function value = familyRatio(local,family)
    mask = string(local.Family) == family;
    if any(mask)
        value = exp(mean(local.MeanLogRatioIGDp(mask),'omitnan'));
    else
        value = NaN;
    end
end

function [ratios,uppers] = perMSummaries(local,rawLogRatio,rawCell,rawM, ...
        protocol,armIndex)
    Ms = protocol.Objectives(:);
    ratios = NaN(numel(Ms),1);
    uppers = NaN(numel(Ms),1);
    for index = 1:numel(Ms)
        localMask = local.M == Ms(index);
        rawMask = rawM == Ms(index);
        if any(localMask) && any(rawMask)
            ratios(index) = exp(mean( ...
                local.MeanLogRatioIGDp(localMask),'omitnan'));
            [~,upperLog] = CMCBootstrapMeanCI( ...
                rawLogRatio(rawMask),rawCell(rawMask), ...
                protocol.Thresholds.BootstrapSamples, ...
                protocol.Thresholds.BootstrapSeed+7000+armIndex*100+index);
            uppers(index) = exp(upperLog);
        end
    end
end

function ratios = perFamilyMRatios(local,protocol)
    ratios = NaN(2*numel(protocol.Objectives),1);
    row = 0;
    for family = ["DTLZ","WFG"]
        for M = protocol.Objectives
            row = row + 1;
            mask = local.Family == family & local.M == M;
            if any(mask)
                ratios(row) = exp(mean( ...
                    local.MeanLogRatioIGDp(mask),'omitnan'));
            end
        end
    end
end

function value = maxFamilyMSevereCount(local,protocol)
    counts = NaN(2*numel(protocol.Objectives),1);
    row = 0;
    for family = ["DTLZ","WFG"]
        for M = protocol.Objectives
            row = row + 1;
            mask = local.Family == family & local.M == M;
            if any(mask)
                counts(row) = nnz(local.GeoMeanRatioIGDp(mask) >= ...
                    protocol.Thresholds.SevereRegressionRatio);
            end
        end
    end
    if any(~isfinite(counts))
        value = Inf;
    else
        value = max(counts);
    end
end

function pass = formalQualified(local,rho,upper,direction,protocol, ...
        mRatios,mUppers,familyMRatios)
    mPass = mRatios <= protocol.Thresholds.EndpointMCIDRatio & mUppers < 1;
    mNoninferior = mUppers <= protocol.Thresholds.NonInferiorityMargin;
    severeOK = true;
    families = ["DTLZ","WFG"];
    for family = families
        for M = protocol.Objectives
            mask = string(local.Family)==family & local.M==M;
            severeOK = severeOK && nnz(local.GeoMeanRatioIGDp(mask) >= ...
                protocol.Thresholds.SevereRegressionRatio) <= ...
                protocol.Thresholds.MaxSevereRegressionCount;
        end
    end
    pass = rho <= protocol.Thresholds.EndpointMCIDRatio && upper < 1 && ...
        any(mPass) && all(mPass | mNoninferior) && ...
        all(familyMRatios <= protocol.Thresholds.NonInferiorityMargin) && ...
        direction >= 0.60 && severeOK;
end

function code = stage2Code(armDecision,protocol,resultRoot)
    [planned,supported,complete] = plannedFactorSupport( ...
        armDecision,resultRoot);
    code = CMCStage2GateCode(armDecision,planned,supported,complete, ...
        stage1DecisionCode(resultRoot),protocol);
end

function code = stage1DecisionCode(resultRoot)
    previous = CMCProtocol('stage1','pilot');
    paths = CMCStagePaths(previous,resultRoot);
    filePath = fullfile(paths.AnalysisRoot, ...
        'CMC_Stage1_ScientificDecision.csv');
    code = "";
    if isfile(filePath)
        decision = readtable(filePath,'TextType','string');
        if height(decision) == 1 && ...
                ismember("DecisionCode", ...
                string(decision.Properties.VariableNames))
            code = decision.DecisionCode(1);
        end
    end
end

function code = stage3Code(armDecision,protocol,resultRoot)
    upstreamCode = "";
    previous = CMCProtocol('stage2','screening');
    paths = CMCStagePaths(previous,resultRoot);
    filePath = fullfile(paths.AnalysisRoot,'CMC_Stage2_ScientificDecision.csv');
    if isfile(filePath)
        upstream = readtable(filePath,'TextType','string');
        if height(upstream) == 1
            upstreamCode = upstream.DecisionCode(1);
        end
    end
    code = CMCStage3GateCode(armDecision,upstreamCode,protocol);
end

function [planned,supported,complete] = plannedFactorSupport( ...
        armDecision,resultRoot)
    previous = CMCProtocol('stage1','pilot');
    paths = CMCStagePaths(previous,resultRoot);
    filePath = fullfile(paths.AnalysisRoot,'CMC_Stage1_FactorDecision.csv');
    planned = strings(0,1);
    if isfile(filePath)
        upstream = readtable(filePath,'TextType','string');
        if all(ismember(["Factor","CarryToNextStage"], ...
                string(upstream.Properties.VariableNames)))
            planned = unique(upstream.Factor( ...
                logical(upstream.CarryToNextStage)),'stable');
        end
    end
    supported = false(numel(planned),1);
    complete = ~isempty(planned);
    for index = 1:numel(planned)
        required = requiredArms(planned(index));
        rows = armDecision(ismember(armDecision.Arm,required),:);
        complete = complete && ~isempty(required) && ...
            height(rows) == numel(required);
        if ~isempty(required) && height(rows) == numel(required)
            supported(index) = all(rows.Qualified);
        end
    end
end

function arms = requiredArms(factor)
    switch string(factor)
        case "P", arms = "A01_NO_P";
        case "Q", arms = "A02_NO_Q";
        case "C", arms = "A03_NO_C";
        case "D", arms = "A04_NO_D";
        case "D_SIGNAL", arms = "N01_SHUFFLE_D";
        case "E_GEN", arms = "A05_NO_EGEN";
        case "E_FINAL", arms = "A06_NO_EFINAL";
        case "F", arms = "A07_NO_F";
        case "F_SIGNAL", arms = "N02_SHUFFLE_F";
        case "G", arms = ["G01_ALWAYS_EXPLORE","G02_ALWAYS_INDICATOR"];
        case "P_ERR_GATE", arms = "N03_NO_PERR_GATE";
        otherwise, arms = strings(0,1);
    end
end

function value = endpointReason(stage,code)
    if stage == "stage2"
        value = "筛选结果只决定是否值得正式验证，不构成正式性能结论。";
    else
        value = "正式结论仍是当前HCV宿主中的条件贡献，不代表跨宿主普遍主效应。";
    end
    value = value + " DecisionCode=" + code;
end

function decision = decisionRow(protocol,integrity,code,qualified,dropped, ...
        referenceStatus,reason)
    canProceed = protocol.StageNumber < 3 && ...
        (startsWith(code,"PASS_TO_STAGE") || code == "SMOKE_PASS");
    if canProceed && protocol.StageNumber < 3
        nextStage = "stage"+string(protocol.StageNumber+1);
    else
        nextStage = "";
    end
    warnings = "NONE";
    if protocol.Profile == "smoke"
        warnings = "SMOKE_NOT_SCIENTIFIC";
    end
    statisticalUnit = "RUN";
    if protocol.StageNumber >= 1
        statisticalUnit = "RUN_NESTED_IN_PROBLEM_M";
    end
    primaryMetric = CMCPrimaryMetric(protocol.Stage);
    decision = table(protocol.SchemaVersion,protocol.Profile,protocol.Stage, ...
        string(code),canProceed,nextStage,protocol.ProtocolHash, ...
        integrity.RequiredJobs,integrity.ValidJobs,integrity.MissingJobs, ...
        integrity.InvalidJobs,string(referenceStatus),statisticalUnit, ...
        primaryMetric, ...
        strjoin(unique(string(qualified)),","), ...
        strjoin(unique(string(dropped)),","),warnings,string(reason), ...
        string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
        'VariableNames',{'SchemaVersion','Profile','Stage','DecisionCode', ...
        'CanProceed','NextStage','ProtocolHash','RequiredJobs','ValidJobs', ...
        'MissingJobs','InvalidJobs','ReferenceStatus','StatisticalUnit', ...
        'PrimaryMetric','QualifiedFactors','DroppedFactors','WarningFlags', ...
        'Reason','GeneratedAt'});
end

function value = ternary(condition,a,b)
    if condition, value = a; else, value = b; end
end
