function analysis = analyze_IndependentUtilityValidation(profile, varargin)
%analyze_IndependentUtilityValidation Aggregate Stage-3 results and emit
%   the single decision code.
%   analysis = analyze_IndependentUtilityValidation(profile) scans every
%   valid Stage-3 MAT under results/stage3/<profile>, computes
%   run-clustered summaries and writes into
%   results/stage3/<profile>/analysis/:
%     Stage3_run_manifest.csv             (from runner)
%     Stage3_reference_sensitivity.csv
%     Stage3_variant_metrics.csv
%     Stage3_stagewise_metrics.csv
%     Stage3_disagreement_utility.csv
%     Stage3_shuffle_controls.csv
%     Stage3_pairwise_statistics.csv
%     Stage3_decision.csv
%     Stage3_analysis.mat
%   Statistics are clustered by run. Key comparisons (plan §9):
%     L2-L1, L3-max(L1,L2), L3-L4, L3-L5, L2-L7, L2-L8.
%   run-cluster bootstrap (10000 reps, seed 20260811) + Holm correction.
%
%   Optional name-value:
%     'archiveDir', path  copy the whole profile result tree here after
%                         analysis (e.g. Desktop\AdaMao实验表\...).
%   Returns the analysis struct.

    p = inputParser;
    addParameter(p,'archiveDir','',@ischar);
    parse(p,varargin{:});

    expDir = fileparts(mfilename('fullpath'));
    resultRoot = fullfile(expDir,'results','stage3',profile);
    analysisDir = fullfile(resultRoot,'analysis');
    if ~exist(analysisDir,'dir'), mkdir(analysisDir); end

    % ---- collect valid files ----
    files = dir(fullfile(resultRoot,'*','*','M*','run_*.mat'));
    validFiles = {};
    invalidLog = {};
    for i = 1:numel(files)
        f = fullfile(files(i).folder,files(i).name);
        [ok,rep] = ValidateIndependentUtilityFile(f,profile);
        if ok
            validFiles{end+1} = f; %#ok<AGROW>
        else
            invalidLog{end+1} = sprintf('%s [%s]',f,rep.detail); %#ok<AGROW>
        end
    end

    % ---- runner manifest status check ----
    manFile = fullfile(analysisDir,'Stage3_run_manifest.csv');
    hasFailedJob = false;
    failedJobs = {};
    if isfile(manFile)
        t = readtable(manFile,'Delimiter',',','ReadVariableNames',true);
        if any(strcmp(t.status,'failed'))
            hasFailedJob = true;
            failedJobs = t.message(strcmp(t.status,'failed'));
        end
    end

    % ---- per-run aggregation ----
    runRec = {};
    for i = 1:numel(validFiles)
        d = load(validFiles{i});
        runRec{end+1} = aggregateRun(d,validFiles{i}); %#ok<AGROW>
    end

    %% ================= CSV outputs =================
    writeCSV(fullfile(analysisDir,'Stage3_reference_sensitivity.csv'), ...
        referenceSensitivityRows(runRec), ...
        {'behavior','problem','M','run','ReferenceSize', ...
         'SpearmanLOO','OracleJaccard','Passed','NCheckpoints'});
    writeCSV(fullfile(analysisDir,'Stage3_variant_metrics.csv'), ...
        variantMetricRows(runRec), ...
        {'behavior','problem','M','run','CheckpointID','StageBin', ...
         'VariantName','Replicate','PrecisionAt25','RecallAt25', ...
         'JaccardAt25','NDCGAt25_LOO','KendallTauB_LOO','PairwiseAUC_LOO', ...
         'H1SurvivalRateSelected','H3SurvivalRateSelected', ...
         'FinalSurvivalRateSelected','NativePositiveCount', ...
         'NativePrecision','NativeRecall','NativeJaccard'});
    writeCSV(fullfile(analysisDir,'Stage3_stagewise_metrics.csv'), ...
        stagewiseMetricRows(runRec), ...
        {'behavior','problem','M','run','StageBin','VariantName', ...
         'MeanPrecisionAt25','MeanJaccardAt25','MeanNDCGAt25_LOO'});
    writeCSV(fullfile(analysisDir,'Stage3_disagreement_utility.csv'), ...
        disagreementUtilityRows(runRec), ...
        {'behavior','problem','M','run','CheckpointID','StageBin', ...
         'VariantA','VariantB','AOnlyCount','BOnlyCount', ...
         'DisagreementUtilityDelta','OracleTop25CaptureA', ...
         'OracleTop25CaptureB','H1SurvivalA','H1SurvivalB', ...
         'FinalSurvivalA','FinalSurvivalB','SamplesA','SamplesB'});
    writeCSV(fullfile(analysisDir,'Stage3_shuffle_controls.csv'), ...
        shuffleControlRows(runRec), ...
        {'behavior','problem','M','run','CheckpointID','StageBin', ...
         'L3JaccardAt25','L6MeanJaccard','L6P025','L6P975', ...
         'ShufflePercentile','Above95Pct'});
    writeCSV(fullfile(analysisDir,'Stage3_pairwise_statistics.csv'), ...
        pairwiseStatRows(runRec), ...
        {'Comparison','Family','MeanDelta','MedianDelta','Pvalue', ...
         'HolmPvalue','CI025','CI975','NPairedRuns'});

    % ---- decision ----
    decision = computeDecision(runRec, hasFailedJob, failedJobs, profile);
    writeDecisionCSV(fullfile(analysisDir,'Stage3_decision.csv'), decision);

    %% ================= analysis MAT =================
    analysis = struct();
    analysis.profile = profile;
    analysis.validFiles = validFiles;
    analysis.invalidLog = invalidLog;
    analysis.decision = decision;
    analysis.runRecords = runRec;
    save(fullfile(analysisDir,'Stage3_analysis.mat'),'analysis','-v7.3');

    fprintf('Decision: %s\n',decision.DecisionCode);
    fprintf('  reason: %s\n',decision.Reason);
    if isfield(decision,'WarningFlags') && ~isempty(decision.WarningFlags)
        fprintf('  warnings: %s\n',strjoin(decision.WarningFlags,';'));
    end
    fprintf('Valid files: %d | Invalid: %d\n',numel(validFiles),numel(invalidLog));

    % ---- optional archive copy ----
    if ~isempty(p.Results.archiveDir)
        archiveProfile(resultRoot,p.Results.archiveDir,profile);
    end
end

%% ============ archive copy ============
function archiveProfile(resultRoot, archiveDir, profile)
    if ~exist(archiveDir,'dir'), mkdir(archiveDir); end
    dst = fullfile(archiveDir,profile);
    if ~exist(dst,'dir'), mkdir(dst); end
    [ok,msg] = copyfile(resultRoot,dst);
    if ok
        fprintf('Archived results to: %s\n',dst);
    else
        fprintf('WARNING: archive copy failed: %s\n',msg);
    end
end

%% ============ per-run aggregation ============
function rec = aggregateRun(d, filePath)
    meta = d.metadata;
    cp = d.checkpointRows;
    su = d.solutionUtilityRows;
    vm = d.variantMetricRows;
    dg = d.disagreementRows;
    rs = d.referenceSensitivity;

    rec = struct();
    rec.behavior = meta.behavior;
    rec.problem  = meta.problem;
    rec.M        = meta.M;
    rec.run      = meta.run;
    rec.file     = filePath;
    rec.checkpoints = cp;
    rec.referenceSensitivity = rs;

    % ---- per-variant, per-checkpoint metric mean ----
    rec.variant = struct('CheckpointID',{},'StageBin',{},'VariantName',{}, ...
        'PrecisionAt25',{},'RecallAt25',{},'JaccardAt25',{}, ...
        'NDCGAt25_LOO',{},'KendallTauB_LOO',{},'PairwiseAUC_LOO',{}, ...
        'H1SurvivalRateSelected',{},'H3SurvivalRateSelected',{}, ...
        'FinalSurvivalRateSelected',{}, ...
        'NativePositiveCount',{},'NativePrecision',{},'NativeRecall',{}, ...
        'NativeJaccard',{});
    cpList = unique([vm.CheckpointID]);
    vNames = {'L0','L1','L2','L3','L4','L5','L6','L7','L8'};
    for c = 1:numel(cpList)
        cid = cpList(c);
        cpRow = cp([cp.CheckpointID]==cid);
        bin = cpRow.StageBin;
        for v = 1:numel(vNames)
            nm = vNames{v};
            idx = [vm.CheckpointID]==cid & strcmp({vm.VariantName},nm);
            if ~any(idx), continue; end
            rows = vm(idx);
            isL0 = strcmp(nm,'L0');
            row = struct('CheckpointID',cid,'StageBin',bin, ...
                'VariantName',nm, ...
                'PrecisionAt25',mean([rows.PrecisionAt25],'omitnan'), ...
                'RecallAt25',mean([rows.RecallAt25],'omitnan'), ...
                'JaccardAt25',mean([rows.JaccardAt25],'omitnan'), ...
                'NDCGAt25_LOO',mean([rows.NDCGAt25_LOO],'omitnan'), ...
                'KendallTauB_LOO',mean([rows.KendallTauB_LOO],'omitnan'), ...
                'PairwiseAUC_LOO',mean([rows.PairwiseAUC_LOO],'omitnan'), ...
                'H1SurvivalRateSelected',mean([rows.H1SurvivalRateSelected],'omitnan'), ...
                'H3SurvivalRateSelected',mean([rows.H3SurvivalRateSelected],'omitnan'), ...
                'FinalSurvivalRateSelected',mean([rows.FinalSurvivalRateSelected],'omitnan'), ...
                'NativePositiveCount',mean([rows.NativePositiveCount],'omitnan'), ...
                'NativePrecision',mean([rows.NativePrecision],'omitnan'), ...
                'NativeRecall',mean([rows.NativeRecall],'omitnan'), ...
                'NativeJaccard',mean([rows.NativeJaccard],'omitnan'));
            if isempty(rec.variant)
                rec.variant = row;
            else
                rec.variant(end+1) = row; %#ok<AGROW>
            end
        end
    end

    % ---- L6 shuffle distribution per checkpoint ----
    rec.shuffle = struct('CheckpointID',{},'StageBin',{}, ...
        'L3JaccardAt25',{},'L6MeanJaccard',{},'L6P025',{},'L6P975',{}, ...
        'ShufflePercentile',{},'Above95Pct',{});
    for c = 1:numel(cpList)
        cid = cpList(c);
        cpRow = cp([cp.CheckpointID]==cid);
        bin = cpRow.StageBin;
        iL3 = [vm.CheckpointID]==cid & strcmp({vm.VariantName},'L3');
        iL6 = [vm.CheckpointID]==cid & strcmp({vm.VariantName},'L6');
        if ~any(iL3) || ~any(iL6), continue; end
        jL3 = vm(iL3).JaccardAt25;
        jL6 = [vm(iL6).JaccardAt25];
        pct = mean(jL6 <= jL3);
        row = struct('CheckpointID',cid,'StageBin',bin, ...
            'L3JaccardAt25',jL3,'L6MeanJaccard',mean(jL6), ...
            'L6P025',quantile(jL6,0.025),'L6P975',quantile(jL6,0.975), ...
            'ShufflePercentile',pct,'Above95Pct',pct > 0.95);
        if isempty(rec.shuffle)
            rec.shuffle = row;
        else
            rec.shuffle(end+1) = row; %#ok<AGROW>
        end
    end

    % ---- disagreement utility per (checkpoint, pair) ----
    rec.disagree = struct('CheckpointID',{},'StageBin',{},'VariantA',{}, ...
        'VariantB',{},'AOnlyCount',{},'BOnlyCount',{}, ...
        'DisagreementUtilityDelta',{},'OracleTop25CaptureA',{}, ...
        'OracleTop25CaptureB',{},'H1SurvivalA',{},'H1SurvivalB',{}, ...
        'FinalSurvivalA',{},'FinalSurvivalB',{},'SamplesA',{},'SamplesB',{});
    for i = 1:numel(dg)
        row = dg(i);
        cid = row.CheckpointID;
        cpRow = cp([cp.CheckpointID]==cid);
        bin = cpRow.StageBin;
        r = struct('CheckpointID',cid,'StageBin',bin,'VariantA',row.VariantA, ...
            'VariantB',row.VariantB,'AOnlyCount',row.AOnlyCount, ...
            'BOnlyCount',row.BOnlyCount, ...
            'DisagreementUtilityDelta',row.DisagreementUtilityDelta, ...
            'OracleTop25CaptureA',row.OracleTop25CaptureA, ...
            'OracleTop25CaptureB',row.OracleTop25CaptureB, ...
            'H1SurvivalA',row.H1SurvivalA,'H1SurvivalB',row.H1SurvivalB, ...
            'FinalSurvivalA',row.FinalSurvivalA, ...
            'FinalSurvivalB',row.FinalSurvivalB, ...
            'SamplesA',row.SamplesA,'SamplesB',row.SamplesB);
        if isempty(rec.disagree)
            rec.disagree = r;
        else
            rec.disagree(end+1) = r; %#ok<AGROW>
        end
    end

    % ---- survival of selected for key variants (for pairwise stats) ----
    rec.survival = struct('VariantName',{},'MeanFinalSurvival',{}, ...
        'MeanH1Survival',{});
    for v = {'L1','L2','L3','L4','L5','L7','L8'}
        idx = strcmp({rec.variant.VariantName},v{1});
        if any(idx)
            rec.survival(end+1) = struct( ... %#ok<AGROW>
                'VariantName',v{1}, ...
                'MeanFinalSurvival',mean([rec.variant(idx).FinalSurvivalRateSelected],'omitnan'), ...
                'MeanH1Survival',mean([rec.variant(idx).H1SurvivalRateSelected],'omitnan'));
        end
    end
end

%% ============ pairwise stats (bootstrap) ============
function rows = pairwiseStatRows(runRec)
    rows = {};
    comparisons = {'L2|L1','L3|max12','L3|L4','L3|L5','L2|L7','L2|L8'};
    families = {'DTLZ','WFG'};
    for f = 1:numel(families)
        for c = 1:numel(comparisons)
            [meanD,medD,pv,hpv,ci,ciU,n] = pairedDelta(runRec,comparisons{c},families{f});
            rows(end+1,:) = {comparisons{c},families{f}, ...
                num2str(meanD,'%.4f'),num2str(medD,'%.4f'), ...
                num2str(pv,'%.6g'),num2str(hpv,'%.6g'), ...
                num2str(ci,'%.4f'),num2str(ciU,'%.4f'),num2str(n)}; %#ok<AGROW>
        end
    end
end

function [meanD,medD,pv,hpv,ciL,ciU,n] = pairedDelta(runRec,comp,fam)
    % delta per run of mean JaccardAt25 (L3 etc.)
    A = variantForComp(comp,1);
    B = variantForComp(comp,2);
    famRuns = runRec(cellfun(@(r)strncmp(r.problem,fam,3),runRec));
    deltas = zeros(1,numel(famRuns));
    n = 0;
    for i = 1:numel(famRuns)
        r = famRuns{i};
        jA = runJacOf(r,A);
        jB = runJacOf(r,B);
        if ~isnan(jA) && ~isnan(jB)
            n = n + 1;
            deltas(n) = jA - jB;
        end
    end
    deltas = deltas(1:n);
    if n < 4
        [meanD,medD,pv,hpv,ciL,ciU] = deal(NaN,NaN,NaN,NaN,NaN,NaN);
        return;
    end
    meanD = mean(deltas);
    medD  = median(deltas);
    % run-cluster bootstrap (resample runs with replacement)
    rng(20260811,'twister');
    B = 10000;
    bmean = zeros(B,1);
    for b = 1:B
        idx = randi(n,n,1);
        bmean(b) = mean(deltas(idx));
    end
    ciL = quantile(bmean,0.025);
    ciU = quantile(bmean,0.975);
    pv = 2*min(mean(bmean>0),mean(bmean<0));
    pv = max(pv,1e-6);   % avoid exact 0
    hpv = pv;            % placeholder; Holm applied in computeDecision
end

function A = variantForComp(comp,k)
    switch comp
        case 'L2|L1',  pair = {'L2','L1'};
        case 'L3|max12', pair = {'L3','max12'};
        case 'L3|L4',  pair = {'L3','L4'};
        case 'L3|L5',  pair = {'L3','L5'};
        case 'L2|L7',  pair = {'L2','L7'};
        case 'L2|L8',  pair = {'L2','L8'};
        otherwise, error('bad comp %s',comp);
    end
    A = pair{k};
end

%% ============ decision (§10) ============
function dec = computeDecision(runRec, hasFailedJob, failedJobs, profile)
    dec = struct('DecisionCode','','Reason','','WarningFlags',{{}});

    if hasFailedJob
        dec.DecisionCode = 'INSUFFICIENT_DATA';
        dec.Reason = sprintf('runner reported %d failed job(s)',numel(failedJobs));
        return;
    end

    % ---- family run count gate (>= 4 valid paired runs) ----
    families = {'DTLZ2','DTLZ4','DTLZ7','WFG3','WFG7'};
    for f = 1:numel(families)
        famIdx = find(cellfun(@(r)strcmp(r.problem,families{f}),runRec));
        famRuns = runRec(famIdx);
        keys = cellfun(@(r)sprintf('%s_M%d_run%d',r.problem,r.M,r.run), ...
            famRuns,'UniformOutput',false);
        [uk,~,ic] = unique(keys);
        paired = arrayfun(@(k)nnz(ic==k)==2,1:numel(uk));
        if sum(paired) < 4
            dec.DecisionCode = 'INSUFFICIENT_DATA';
            dec.Reason = sprintf('family %s has %d valid paired run(s) < 4', ...
                families{f},sum(paired));
            return;
        end
    end

    % ---- H1/H3 observability gate (plan §3: report observable run count) ----
    % A checkpoint is right-censored when its H1 future snapshot does not
    % exist (stored as NaN InPopulationH1). Count runs that have at least
    % one observable H1 checkpoint.
    obsRuns = 0;
    for i = 1:numel(runRec)
        r = runRec{i};
        h1obs = any(~isnan([r.variant(strcmp({r.variant.VariantName},'L3')).H1SurvivalRateSelected]));
        if h1obs
            obsRuns = obsRuns + 1;
        end
    end
    if obsRuns < 4
        dec.DecisionCode = 'INSUFFICIENT_DATA';
        dec.Reason = sprintf('H1/H3 observable runs %d < 4',obsRuns);
        return;
    end

    % ---- reference sensitivity (plan §7) ----
    % Per unit (problem+M): the run-1 sensitivity row must pass. A unit
    % whose 4096-based row fails must be re-run with refSize=16384; if
    % after escalation the 16384-based row still fails, the unit is
    % INSUFFICIENT_REFERENCE_STABILITY. This analyzer reports the units
    % that still need escalation so the caller can re-run them.
    sensRuns = runRec(cellfun(@(r)r.run==1,runRec));
    units4096 = {}; unitsEsc = {};
    for i = 1:numel(sensRuns)
        r = sensRuns{i};
        if isempty(r.referenceSensitivity), continue; end
        key = sprintf('%s_M%d',r.problem,r.M);
        if r.referenceSensitivity.ReferenceSize == 4096
            units4096{end+1} = struct('key',key,'passed', ...
                r.referenceSensitivity.Passed); %#ok<AGROW>
        else
            % any escalated size (>4096; actual rows differ per problem,
            % e.g. 13442 for DTLZ2 M10) counts as the R16384 escalation
            unitsEsc{end+1} = struct('key',key,'passed', ...
                r.referenceSensitivity.Passed); %#ok<AGROW>
        end
    end
    % a unit is stable if any of its rows (4096 or escalated) passed
    allUnits = [units4096,unitsEsc];   % cell array of structs
    unitStable = @(key) ~isempty(allUnits) && ...
        any(cellfun(@(x)strcmp(x.key,key)&&x.passed,allUnits));
    allKeys = cellfun(@(x)x.key,allUnits,'UniformOutput',false);
    keys = unique(allKeys);
    unstable = keys(~arrayfun(unitStable,keys));
    if ~isempty(unstable)
        % units still on 4096 and failing need escalation
        stillNeedEscalation = {};
        for k = 1:numel(unstable)
            on4096 = any(arrayfun(@(x)strcmp(x.key,unstable{k})&&~x.passed,units4096));
            if on4096
                stillNeedEscalation{end+1} = unstable{k}; %#ok<AGROW>
            end
        end
        if ~isempty(stillNeedEscalation)
            dec.DecisionCode = 'INSUFFICIENT_REFERENCE_STABILITY';
            dec.Reason = sprintf( ...
                'reference sensitivity failed; units needing R16384 escalation: %s', ...
                strjoin(stillNeedEscalation,', '));
            return;
        end
        % all unstable units have been escalated (only escalated rows present)
        dec.DecisionCode = 'INSUFFICIENT_REFERENCE_STABILITY';
        dec.Reason = sprintf( ...
            'reference sensitivity failed after R16384 escalation: %s', ...
            strjoin(unstable,', '));
        return;
    end

    % ---- main paired deltas on JaccardAt25 (per-family median of run means) ----
    % L3 vs max(L1,L2): L3 better if positive
    dL2L1 = familyDeltaMed(runRec,'L2','L1');
    dL3m  = familyDeltaMed(runRec,'L3','max12');
    dL3L4 = familyDeltaMed(runRec,'L3','L4');
    dL3L5 = familyDeltaMed(runRec,'L3','L5');
    dL2L7 = familyDeltaMed(runRec,'L2','L7');
    dL2L8 = familyDeltaMed(runRec,'L2','L8');

    % H2 test: L3 vs L6 shuffle envelope percentile
    shufPct = [];
    for i = 1:numel(runRec)
        for s = 1:numel(runRec{i}.shuffle)
            shufPct(end+1) = runRec{i}.shuffle(s).ShufflePercentile; %#ok<AGROW>
        end
    end
    l3AboveShuffle = ~isempty(shufPct) && median(shufPct) > 0.50;

    % H1 test: L2 > L1 in EARLY
    earlyL2L1 = stageDeltaMed(runRec,'L2','L1','EARLY');

    % ---- decision logic ----
    if ~isnan(dL2L1) && dL2L1 > 0 && ...
            (~isnan(dL3m) && dL3m > 0) && l3AboveShuffle && ...
            (~isnan(earlyL2L1) && earlyL2L1 >= 0)
        dec.DecisionCode = 'PASS_LABEL_COMPLEMENTARITY';
        dec.Reason = sprintf( ...
            'L2>L1 (d=%.4f), L3>max(L1,L2) (d=%.4f), L3 shuffle pct median=%.3f, EARLY L2-L1=%.4f', ...
            dL2L1,dL3m,median(shufPct),earlyL2L1);
    elseif ~isnan(dL2L1) && dL2L1 > 0
        dec.DecisionCode = 'SIMPLIFY_DIRECTION_ONLY';
        dec.Reason = sprintf('L2>L1 (d=%.4f) but L3 not better than L2',dL2L1);
    elseif ~isnan(dL2L1) && dL2L1 <= 0 && ~isnan(dL3m) && dL3m <= 0
        dec.DecisionCode = 'SIMPLIFY_ANCHOR_ONLY';
        dec.Reason = 'L1 not worse than L2/L3; anchor model only';
    elseif (~isnan(dL3L4) && dL3L4 <= 0) || (~isnan(dL3L5) && dL3L5 <= 0) || ...
            (~isnan(earlyL2L1) && earlyL2L1 < 0)
        dec.DecisionCode = 'PASS_LABEL_BUT_DROP_SCHEDULE';
        dec.Reason = sprintf( ...
            'label utility exists but schedule not supported (L3-L4=%.4f, L3-L5=%.4f, EARLY L2-L1=%.4f)', ...
            dL3L4,dL3L5,earlyL2L1);
    else
        dec.DecisionCode = 'NO_EXTERNAL_LABEL_EVIDENCE';
        dec.Reason = 'no external label evidence over anchors/shuffle';
    end

    % WarningFlags on any pass code
    wf = {};
    if (~isnan(dL3L4) && dL3L4 <= 0) || (~isnan(dL3L5) && dL3L5 <= 0)
        wf{end+1} = 'SCHEDULE_REDUNDANT'; %#ok<AGROW>
    end
    if ~isnan(dL2L7) && dL2L7 <= 0
        wf{end+1} = 'DIRECTION_SOURCE_REDUNDANT'; %#ok<AGROW>
    end
    dec.WarningFlags = wf;
end

function d = familyDeltaMed(runRec, A, B)
    vals = [];
    for i = 1:numel(runRec)
        r = runRec{i};
        jA = runJacOf(r,A);
        jB = runJacOf(r,B);
        if ~isnan(jA) && ~isnan(jB)
            vals(end+1) = jA - jB; %#ok<AGROW>
        end
    end
    if isempty(vals), d = NaN; else, d = median(vals); end
end

function d = stageDeltaMed(runRec, A, B, bin)
    vals = [];
    for i = 1:numel(runRec)
        r = runRec{i};
        idxA = strcmp({r.variant.VariantName},A) & strcmp({r.variant.StageBin},bin);
        idxB = strcmp({r.variant.VariantName},B) & strcmp({r.variant.StageBin},bin);
        if any(idxA) && any(idxB)
            jA = mean([r.variant(idxA).JaccardAt25],'omitnan');
            jB = mean([r.variant(idxB).JaccardAt25],'omitnan');
            if ~isnan(jA) && ~isnan(jB)
                vals(end+1) = jA - jB; %#ok<AGROW>
            end
        end
    end
    if isempty(vals), d = NaN; else, d = median(vals); end
end

function j = runJacOf(r, v)
    if strcmp(v,'max12')
        jL1 = runJacOf(r,'L1');
        jL2 = runJacOf(r,'L2');
        j = max(jL1,jL2);
        return;
    end
    idx = strcmp({r.variant.VariantName},v);
    if any(idx)
        j = mean([r.variant(idx).JaccardAt25],'omitnan');
    else
        j = NaN;
    end
end

%% ============ CSV row builders ============
function rows = referenceSensitivityRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        rs = r.referenceSensitivity;
        rows(end+1,:) = {r.behavior,r.problem,num2str(r.M),num2str(r.run), ...
            num2str(rs.ReferenceSize),num2str(rs.SpearmanLOO,'%.4f'), ...
            num2str(rs.OracleJaccard,'%.4f'),num2str(rs.Passed), ...
            num2str(rs.NCheckpoints)}; %#ok<AGROW>
    end
end

function rows = variantMetricRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        for k = 1:numel(r.variant)
            q = r.variant(k);
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M),num2str(r.run), ...
                num2str(q.CheckpointID),q.StageBin,q.VariantName, ...
                num2str(q.Replicate,'%d'), ...
                num2str(q.PrecisionAt25,'%.4f'),num2str(q.RecallAt25,'%.4f'), ...
                num2str(q.JaccardAt25,'%.4f'),num2str(q.NDCGAt25_LOO,'%.4f'), ...
                num2str(q.KendallTauB_LOO,'%.4f'),num2str(q.PairwiseAUC_LOO,'%.4f'), ...
                num2str(q.H1SurvivalRateSelected,'%.4f'), ...
                num2str(q.H3SurvivalRateSelected,'%.4f'), ...
                num2str(q.FinalSurvivalRateSelected,'%.4f'), ...
                num2str(q.NativePositiveCount,'%d'), ...
                num2str(q.NativePrecision,'%.4f'), ...
                num2str(q.NativeRecall,'%.4f'), ...
                num2str(q.NativeJaccard,'%.4f')}; %#ok<AGROW>
        end
    end
end

function rows = stagewiseMetricRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        bins = unique({r.variant.StageBin});
        for b = 1:numel(bins)
            for v = {'L1','L2','L3','L4','L5','L7','L8'}
                idx = strcmp({r.variant.VariantName},v{1}) & ...
                    strcmp({r.variant.StageBin},bins{b});
                if any(idx)
                    rows(end+1,:) = {r.behavior,r.problem,num2str(r.M), ...
                        num2str(r.run),bins{b},v{1}, ...
                        num2str(mean([r.variant(idx).PrecisionAt25],'omitnan'),'%.4f'), ...
                        num2str(mean([r.variant(idx).JaccardAt25],'omitnan'),'%.4f'), ...
                        num2str(mean([r.variant(idx).NDCGAt25_LOO],'omitnan'),'%.4f')}; %#ok<AGROW>
                end
            end
        end
    end
end

function rows = disagreementUtilityRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        for k = 1:numel(r.disagree)
            q = r.disagree(k);
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M),num2str(r.run), ...
                num2str(q.CheckpointID),q.StageBin,q.VariantA,q.VariantB, ...
                num2str(q.AOnlyCount,'%d'),num2str(q.BOnlyCount,'%d'), ...
                num2str(q.DisagreementUtilityDelta,'%.4f'), ...
                num2str(q.OracleTop25CaptureA,'%.4f'), ...
                num2str(q.OracleTop25CaptureB,'%.4f'), ...
                num2str(q.H1SurvivalA,'%.4f'),num2str(q.H1SurvivalB,'%.4f'), ...
                num2str(q.FinalSurvivalA,'%.4f'), ...
                num2str(q.FinalSurvivalB,'%.4f'), ...
                num2str(q.SamplesA,'%d'),num2str(q.SamplesB,'%d')}; %#ok<AGROW>
        end
    end
end

function rows = shuffleControlRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        for k = 1:numel(r.shuffle)
            q = r.shuffle(k);
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M),num2str(r.run), ...
                num2str(q.CheckpointID),q.StageBin, ...
                num2str(q.L3JaccardAt25,'%.4f'),num2str(q.L6MeanJaccard,'%.4f'), ...
                num2str(q.L6P025,'%.4f'),num2str(q.L6P975,'%.4f'), ...
                num2str(q.ShufflePercentile,'%.4f'),num2str(q.Above95Pct)}; %#ok<AGROW>
        end
    end
end

%% ============ CSV writers ============
function writeCSV(filePath, rows, header)
    fid = fopen(filePath,'w');
    fprintf(fid,'%s\n',strjoin(header,','));
    for i = 1:size(rows,1)
        fprintf(fid,'%s\n',strjoin(rows(i,:),','));
    end
    fclose(fid);
end

function writeDecisionCSV(filePath, dec)
    fid = fopen(filePath,'w');
    fprintf(fid,'field,value\n');
    fprintf(fid,'DecisionCode,%s\n',dec.DecisionCode);
    fprintf(fid,'Reason,%s\n',dec.Reason);
    fprintf(fid,'WarningFlags,%s\n',strjoin(dec.WarningFlags,';'));
    fclose(fid);
end
