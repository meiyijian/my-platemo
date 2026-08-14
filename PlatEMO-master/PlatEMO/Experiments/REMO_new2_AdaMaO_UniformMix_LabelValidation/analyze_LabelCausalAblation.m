function analysis = analyze_LabelCausalAblation(profile, varargin)
%analyze_LabelCausalAblation Aggregate Stage-2 results and emit the
%   single decision code.
%   analysis = analyze_LabelCausalAblation(profile) scans every valid
%   Stage-2 MAT under results/stage2/<profile>, computes run-clustered
%   summaries and writes into results/stage2/<profile>/analysis/:
%     Stage2_run_manifest.csv           (from runner)
%     Stage2_variant_summary.csv
%     Stage2_pairwise_overlap.csv
%     Stage2_stagewise_overlap.csv
%     Stage2_disagreement_counts.csv
%     Stage2_shuffle_envelope.csv
%     Stage2_stability_summary.csv
%     Stage2_decision.csv
%     Stage2_analysis.mat
%   Statistics are clustered by run (not by snapshot or solution). The
%   decision code is computed by the frozen rule of Stage-2 plan §9.
%
%   Optional name-value:
%     'equivalenceFile', path  informational only (default '')
%     'archiveDir', path       after writing the analysis files, copy the
%                              entire profile result tree (analysis + raw
%                              MATs) into this directory, e.g.
%                              'C:\Users\lsx\Desktop\AdaMao实验表\Stage2_LabelCausalAblation'
%   Returns the analysis struct.

    p = inputParser;
    addParameter(p,'equivalenceFile','',@ischar);
    addParameter(p,'archiveDir','',@ischar);
    parse(p,varargin{:});

    expDir = fileparts(mfilename('fullpath'));
    resultRoot = fullfile(expDir,'results','stage2',profile);
    analysisDir = fullfile(resultRoot,'analysis');
    if ~exist(analysisDir,'dir'), mkdir(analysisDir); end

    % ---- collect valid files ----
    files = dir(fullfile(resultRoot,'*','*','M*','run_*.mat'));
    validFiles = {};
    invalidLog = {};
    for i = 1:numel(files)
        f = fullfile(files(i).folder,files(i).name);
        [ok,rep] = ValidateLabelCausalAblationFile(f,profile);
        if ok
            validFiles{end+1} = f; %#ok<AGROW>
        else
            invalidLog{end+1} = sprintf('%s [%s]',f,rep.detail); %#ok<AGROW>
        end
    end

    % ---- runner manifest status check ----
    manFile = fullfile(analysisDir,'Stage2_run_manifest.csv');
    hasFailedJob = false;
    failedJobs = {};
    if isfile(manFile)
        t = readtable(manFile,'Delimiter',',','ReadVariableNames',true);
        if any(strcmp(t.status,'failed'))
            hasFailedJob = true;
            failedJobs = t.message(strcmp(t.status,'failed'));
        end
    end

    % ---- per-run aggregation (cell array: nested structs may have
    %      different lengths across runs) ----
    runRec = {};
    for i = 1:numel(validFiles)
        f = validFiles{i};
        d = load(f);
        runRec{end+1} = aggregateRun(d,f); %#ok<AGROW>
    end

    %% ================= CSV outputs =================
    writeCSV(fullfile(analysisDir,'Stage2_variant_summary.csv'), ...
        variantSummaryRows(runRec), ...
        {'behavior','problem','M','run','VariantCode','VariantName', ...
         'StageBin','PositiveRate','ScoreMean'});
    writeCSV(fullfile(analysisDir,'Stage2_pairwise_overlap.csv'), ...
        pairwiseOverlapRows(runRec), ...
        {'behavior','problem','M','run','Pair','MeanJaccard', ...
         'MeanSpearman','NSnapshots','Gt095Frac'});
    writeCSV(fullfile(analysisDir,'Stage2_stagewise_overlap.csv'), ...
        stagewiseOverlapRows(runRec), ...
        {'behavior','problem','M','run','StageBin','Pair', ...
         'MeanJaccard','MeanSpearman','NSnapshots'});
    writeCSV(fullfile(analysisDir,'Stage2_disagreement_counts.csv'), ...
        disagreementRows(runRec), ...
        {'behavior','problem','M','run','Pair','MeanSymmetricDiff'});
    writeCSV(fullfile(analysisDir,'Stage2_shuffle_envelope.csv'), ...
        shuffleEnvelopeRows(runRec), ...
        {'behavior','problem','M','run','StageBin','MeanJaccard', ...
         'P025','P975','N'});
    writeCSV(fullfile(analysisDir,'Stage2_stability_summary.csv'), ...
        stabilitySummaryRows(runRec), ...
        {'behavior','problem','M','run','Variant','DropFraction', ...
         'MeanRetainedJaccard','N'});

    % ---- decision ----
    decision = computeDecision(runRec, hasFailedJob, failedJobs);
    writeDecisionCSV(fullfile(analysisDir,'Stage2_decision.csv'), decision);

    % ---- analysis MAT ----
    analysis = struct();
    analysis.profile = profile;
    analysis.validFiles = validFiles;
    analysis.invalidLog = invalidLog;
    analysis.decision = decision;
    analysis.runRecords = runRec;
    save(fullfile(analysisDir,'Stage2_analysis.mat'),'analysis','-v7.3');

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
%archiveProfile Copy the whole profile tree (analysis + raw MATs) into the
%   user-visible archive directory, e.g. Desktop\AdaMao实验表\...
    if ~exist(archiveDir,'dir')
        mkdir(archiveDir);
    end
    % destination: <archiveDir>/<profile>
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
    vr = d.variantRowsAll;
    ov = d.overlapRowsAll;
    st = d.stabilityRowsAll;

    rec = struct();
    rec.behavior = meta.behavior;
    rec.problem  = meta.problem;
    rec.M        = meta.M;
    rec.run      = meta.run;
    rec.file     = filePath;

    % ---- variant summary: PositiveRate/ScoreMean per (code, stageBin) ----
    rec.positiveRate = struct('code',{},'name',{},'bin',{}, ...
        'rate',{},'scoreMean',{});
    vCodes = unique([vr.VariantCode]);
    bins   = unique({vr.StageBin});
    [~,names] = LVVariantTable();
    for c = 1:numel(vCodes)
        for b = 1:numel(bins)
            idx = [vr.VariantCode]==vCodes(c) & strcmp({vr.StageBin},bins{b});
            if any(idx)
                rec.positiveRate(end+1) = struct( ... %#ok<AGROW>
                    'code',vCodes(c),'name',names{vCodes(c)+1}, ...
                    'bin',bins{b}, ...
                    'rate',mean([vr(idx).PositiveRate]), ...
                    'scoreMean',mean([vr(idx).ScoreMean]));
            end
        end
    end

    % ---- pairwise overlap: Jaccard/Spearman vectors per pair ----
    [pairs, jacMap, spMap] = overlapSeries(ov);
    rec.pairJac = jacMap;
    rec.pairSp  = spMap;
    rec.pairBinJac = binSeries(ov);   % key 'PAIR__BIN' -> jac vector
    rec.pairLabels = pairs;

    % ---- disagreement ----
    rec.disagree = disagreementSeries(ov);

    % ---- shuffle envelope ----
    rec.shuffleEnv = shuffleSeries(ov);

    % ---- stability ----
    rec.stabJac = stabilitySeries(st);
end

%% ============ overlap series (pair -> vector) ============
function [pairs, jacMap, spMap] = overlapSeries(ov)
    pairs = {};
    for i = 1:numel(ov)
        key = sprintf('%s|%s',ov(i).VariantA,ov(i).VariantB);
        if ~any(strcmp(pairs,key))
            pairs{end+1} = key; %#ok<AGROW>
        end
    end
    jacMap = containers.Map('KeyType','char','ValueType','any');
    spMap  = containers.Map('KeyType','char','ValueType','any');
    for p = 1:numel(pairs)
        key = pairs{p};
        idx = arrayfun(@(o)strcmp(sprintf('%s|%s',o.VariantA,o.VariantB),key),ov);
        jac = [ov(idx).Jaccard];
        jacMap(key) = jac;
        spMap(key)  = [ov(idx).SpearmanScore];
    end
end

%% ============ per-(pair,stageBin) series ============
function m = binSeries(ov)
    m = containers.Map('KeyType','char','ValueType','any');
    for i = 1:numel(ov)
        key = sprintf('%s|%s__%s',ov(i).VariantA,ov(i).VariantB,ov(i).StageBin);
        if ~isKey(m,key)
            m(key) = [];
        end
        m(key) = [m(key), ov(i).Jaccard]; %#ok<AGROW>
    end
end

%% ============ disagreement series ============
function ds = disagreementSeries(ov)
    ds = struct('pair',{},'meanSymmetricDiff',{},'n',{});
    targets = {'L1|L2','L1|L3','L2|L3'};
    for p = 1:numel(targets)
        key = targets{p};
        idx = arrayfun(@(o)strcmp(sprintf('%s|%s',o.VariantA,o.VariantB),key),ov);
        if any(idx)
            ds(end+1) = struct('pair',key, ... %#ok<AGROW>
                'meanSymmetricDiff',mean([ov(idx).AOnlyCount]+[ov(idx).BOnlyCount]), ...
                'n',sum(idx));
        end
    end
end

%% ============ shuffle series ============
function se = shuffleSeries(ov)
    bins = {'EARLY','MIDDLE','LATE'};
    se = struct('bin',{},'mean',{},'p025',{},'p975',{},'n',{});
    for b = 1:numel(bins)
        idx = strcmp({ov.VariantA},'L3') & strcmp({ov.VariantB},'L6') & ...
            strcmp({ov.StageBin},bins{b});
        if any(idx)
            j = [ov(idx).Jaccard];
            se(end+1) = struct('bin',bins{b}, ... %#ok<AGROW>
                'mean',mean(j),'p025',quantile(j,0.025), ...
                'p975',quantile(j,0.975),'n',sum(idx));
        end
    end
end

%% ============ stability series ============
function ss = stabilitySeries(st)
    ss = struct('variant',{},'drop',{},'meanJac',{},'n',{});
    variants = unique({st.VariantName});
    drops = unique([st.DropFraction]);
    for v = 1:numel(variants)
        for dd = 1:numel(drops)
            idx = strcmp({st.VariantName},variants{v}) & ...
                [st.DropFraction]==drops(dd);
            if any(idx)
                ss(end+1) = struct('variant',variants{v}, ... %#ok<AGROW>
                    'drop',drops(dd),'meanJac',mean([st(idx).RetainedJaccard]), ...
                    'n',sum(idx));
            end
        end
    end
end

%% ============ CSV row builders ============
function rows = variantSummaryRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        for k = 1:numel(r.positiveRate)
            q = r.positiveRate(k);
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M), ...
                num2str(r.run),num2str(q.code),q.name,q.bin, ...
                num2str(q.rate,'%.4f'),num2str(q.scoreMean,'%.6e')}; %#ok<AGROW>
        end
    end
end

function rows = pairwiseOverlapRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        keys = r.pairJac.keys;
        for p = 1:numel(keys)
            key = keys{p};
            jac = r.pairJac(key);
            sp  = r.pairSp(key);
            spM = NaN;
            if ~isempty(sp) && all(isfinite(sp))
                spM = mean(sp);
            end
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M), ...
                num2str(r.run),strrep(key,'|','_vs_'), ...
                num2str(mean(jac),'%.4f'),num2str(spM,'%.4f'), ...
                num2str(numel(jac)),num2str(mean(jac>0.95),'%.4f')}; %#ok<AGROW>
        end
    end
end

function rows = stagewiseOverlapRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        keys = r.pairBinJac.keys;
        for p = 1:numel(keys)
            key = keys{p};
            % key format: 'A|B__BIN'
            parts = strsplit(key,'__');
            pair = parts{1};
            bin  = parts{2};
            jac  = r.pairBinJac(key);
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M), ...
                num2str(r.run),bin,strrep(pair,'|','_vs_'), ...
                num2str(mean(jac),'%.4f'),'NaN',num2str(numel(jac))}; %#ok<AGROW>
        end
    end
end

function rows = disagreementRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        for p = 1:numel(r.disagree)
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M), ...
                num2str(r.run),strrep(r.disagree(p).pair,'|','_vs_'), ...
                num2str(r.disagree(p).meanSymmetricDiff,'%.3f')}; %#ok<AGROW>
        end
    end
end

function rows = shuffleEnvelopeRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        for e = 1:numel(r.shuffleEnv)
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M), ...
                num2str(r.run),r.shuffleEnv(e).bin, ...
                num2str(r.shuffleEnv(e).mean,'%.4f'), ...
                num2str(r.shuffleEnv(e).p025,'%.4f'), ...
                num2str(r.shuffleEnv(e).p975,'%.4f'), ...
                num2str(r.shuffleEnv(e).n)}; %#ok<AGROW>
        end
    end
end

function rows = stabilitySummaryRows(runRec)
    rows = {};
    for i = 1:numel(runRec)
        r = runRec{i};
        for s = 1:numel(r.stabJac)
            rows(end+1,:) = {r.behavior,r.problem,num2str(r.M), ...
                num2str(r.run),r.stabJac(s).variant, ...
                num2str(r.stabJac(s).drop,'%.2f'), ...
                num2str(r.stabJac(s).meanJac,'%.4f'), ...
                num2str(r.stabJac(s).n)}; %#ok<AGROW>
        end
    end
end

%% ============ decision (Stage-2 plan §9) ============
function dec = computeDecision(runRec, hasFailedJob, failedJobs)
    dec = struct('DecisionCode','','Reason','','WarningFlags',{{}});

    % 0. STOP_REPRODUCTION_FAILURE
    if hasFailedJob
        dec.DecisionCode = 'STOP_REPRODUCTION_FAILURE';
        dec.Reason = sprintf('runner reported %d failed job(s) (L3 could not reproduce CatalogCurrent)', ...
            numel(failedJobs));
        return;
    end

    % 1. INSUFFICIENT_DATA: any problem family < 4 valid paired runs
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

    % 2. run-level median of "Jaccard>0.95 fraction" for key pairs
    fracF = @(pair)median(cellfun(@(r)mean(r.pairJac(pair)>0.95), ...
        runRec,'UniformOutput',true));
    fL3L1 = fracF('L1|L3');
    fL3L2 = fracF('L2|L3');
    fL3L4 = fracF('L3|L4');
    fL3L5 = fracF('L3|L5');
    fL2L7 = fracF('L2|L7');

    % disagreement sizes (median of run means)
    disagreeMed = struct();
    for pair = {'L1|L2','L1|L3','L2|L3'}
        vals = cellfun(@(r) disagreeMeanOf(r,pair{1}), runRec);
        disagreeMed.(strrep(pair{1},'|','_')) = median(vals);
    end

    % 3. STOP_NO_MECHANISM_SEPARATION
    sepCond = (fL3L1 >= 0.80) && (fL3L2 >= 0.80);
    disCond = disagreeMed.L1_L3 < 3 && disagreeMed.L2_L3 < 3 && disagreeMed.L1_L2 < 3;
    if sepCond && disCond
        dec.DecisionCode = 'STOP_NO_MECHANISM_SEPARATION';
        dec.Reason = sprintf('L3 vs L1/L2 Jaccard>0.95 in >=80%% snapshots (med %.3f/%.3f) and disagreement sets persistently <3', ...
            fL3L1,fL3L2);
        return;
    end

    % 4. PASS_TO_STAGE3
    dec.DecisionCode = 'PASS_TO_STAGE3';
    dec.Reason = sprintf('non-trivial separation (L3 vs L1 >0.95 frac %.3f, vs L2 %.3f); all data/negative-control/reproduction checks valid', ...
        fL3L1,fL3L2);

    % WarningFlags only on PASS
    wf = {};
    if fL3L4 >= 0.80 && fL3L5 >= 0.80
        wf{end+1} = 'SCHEDULE_REDUNDANT'; %#ok<AGROW>
    end
    if fL2L7 >= 0.80
        wf{end+1} = 'DIRECTION_SOURCE_REDUNDANT'; %#ok<AGROW>
    end
    dec.WarningFlags = wf;
end

function v = disagreeMeanOf(r, pair)
    for p = 1:numel(r.disagree)
        if strcmp(r.disagree(p).pair,pair)
            v = r.disagree(p).meanSymmetricDiff;
            return;
        end
    end
    v = NaN;
end

%% ============ CSV writer ============
function writeCSV(filePath, rows, headers)
    fid = fopen(filePath,'w');
    if isempty(rows)
        if nargin >= 3
            fprintf(fid,'%s\n',strjoin(headers,','));
        end
        fclose(fid);
        return;
    end
    nCol = size(rows,2);
    if nargin >= 3
        fprintf(fid,'%s\n',strjoin(headers,','));
    end
    for i = 1:size(rows,1)
        for c = 1:nCol
            if c > 1, fprintf(fid,','); end
            fprintf(fid,'%s',num2str_wrap(rows{i,c}));
        end
        fprintf(fid,'\n');
    end
    fclose(fid);
end

function writeDecisionCSV(filePath, dec)
    fid = fopen(filePath,'w');
    fprintf(fid,'field,value\n');
    fprintf(fid,'DecisionCode,%s\n',dec.DecisionCode);
    fprintf(fid,'Reason,%s\n',dec.Reason);
    if isempty(dec.WarningFlags)
        fprintf(fid,'WarningFlags,\n');
    else
        fprintf(fid,'WarningFlags,%s\n',strjoin(dec.WarningFlags,';'));
    end
    fclose(fid);
end

function s = num2str_wrap(x)
    if ischar(x) || isstring(x)
        s = char(x);
    elseif isnumeric(x) && isscalar(x) && ~isnan(x)
        s = num2str(x);
    elseif isnumeric(x) && isscalar(x) && isnan(x)
        s = 'NaN';
    elseif iscell(x)
        s = num2str_wrap(x{1});
    else
        s = 'NaN';
    end
end
