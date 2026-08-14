function decision = analyze_LabelMechanismSnapshotAudit(profile, varargin)
%analyze_LabelMechanismSnapshotAudit Descriptive analysis of Stage 1.
%   decision = analyze_LabelMechanismSnapshotAudit(profile) reads every
%   validator-passing MAT under results/stage1/<profile> and writes the
%   Stage-1 CSVs and Stage1_analysis.mat into
%   results/stage1/<profile>/analysis/.
%
%   Optional key-value:
%     'equivalenceFile',''  path to the file written by the equivalence
%                           tests. If missing, the decision cannot
%                           confirm trajectory equivalence and reports
%                           STOP_TRAJECTORY_MISMATCH (conservative).
%
%   Statistical unit: paired runs (pairedKey). Snapshot rows are
%   descriptive only; no confidence interval is computed here.

    p = inputParser;
    addParameter(p,'equivalenceFile',[],@(x)isempty(x)||ischar(x));
    parse(p,varargin{:});
    eqFile = p.Results.equivalenceFile;
    if isempty(eqFile)
        expDir = fileparts(mfilename('fullpath'));
        eqFile = fullfile(expDir,'results','stage1','equivalence_passed.txt');
    end

    expDir = fileparts(mfilename('fullpath'));
    resultRoot = fullfile(expDir,'results','stage1',profile);
    analysisDir = fullfile(resultRoot,'analysis');
    if ~exist(analysisDir,'dir'), mkdir(analysisDir); end

    % ---- collect valid files ----
    files = dir(fullfile(resultRoot,'*','*','M*','run_*.mat'));
    validFiles = {};
    invalidLog = {};
    for i = 1:numel(files)
        f = fullfile(files(i).folder,files(i).name);
        [ok,rep] = ValidateLabelMechanismSnapshotFile(f,profile);
        if ok
            validFiles{end+1} = f; %#ok<AGROW>
        else
            invalidLog{end+1} = sprintf('%s [%s]',f,rep.detail); %#ok<AGROW>
        end
    end

    % ---- load valid data ----
    S = cell(1,numel(validFiles));
    for i = 1:numel(validFiles)
        d = load(validFiles{i});
        S{i} = d;
        S{i}.file = validFiles{i};
    end

    % ---- snapshot metrics CSV ----
    snapRows = {};
    for i = 1:numel(S)
        d = S{i};
        nSnap = numel(d.snapshots);
        for s = 1:nSnap
            sn = d.snapshots(s);
            snapRows(end+1,:) = { ...
                d.metadata.behavior,d.metadata.problem, ...
                num2str(d.metadata.M),num2str(d.metadata.run), ...
                num2str(sn.Generation),num2str(sn.FE), ...
                num2str(sn.Ratio,'%.4f'),num2str(sn.Alpha,'%.4f'), ...
                num2str(sn.DirectionSource),sn.FallbackReason, ...
                num2str(sn.Front1Count),num2str(sn.ClusterCount), ...
                num2str(sn.UniqueDirectionCount), ...
                num2str(sn.ScoreVStd,'%.6e'),num2str(sn.LabelDynStd,'%.6e'), ...
                num2str(sn.EffectiveScaleRatio,'%.6e'), ...
                num2str(sn.AnchorPositiveRate,'%.4f'), ...
                num2str(sn.Delta,'%.4f')};
        end
    end
    writeCSV(fullfile(analysisDir,'Stage1_snapshot_metrics.csv'), ...
        {'behavior','problem','M','run','generation','FE','Ratio','Alpha', ...
         'DirectionSource','FallbackReason','Front1Count','ClusterCount', ...
         'UniqueDirectionCount','ScoreVStd','LabelDynStd', ...
         'EffectiveScaleRatio','AnchorPositiveRate','Delta'},snapRows);

    % ---- direction source summary ----
    probMs = uniqueKey(S,{'problem','M'});
    dirRows = {};          % cell of rows (variable width) until padding
    allReasons = {};
    for k = 1:numel(probMs)
        pm = probMs{k};
        for b = {'Hybrid','AnchorNative'}
            idx = cellfun(@(d)strcmp(d.metadata.problem,pm{1}) && ...
                d.metadata.M==pm{2} && strcmp(d.metadata.behavior,b{1}),S);
            if ~any(idx), continue; end
            total = 0; nd = 0;
            reasons = containers.Map();
            for i = find(idx)
                for s = 1:numel(S{i}.snapshots)
                    sn = S{i}.snapshots(s);
                    total = total + 1;
                    if sn.DirectionSource == 1, nd = nd + 1; end
                    if isKey(reasons,sn.FallbackReason)
                        reasons(sn.FallbackReason) = reasons(sn.FallbackReason)+1;
                    else
                        reasons(sn.FallbackReason) = 1;
                    end
                end
            end
            r = reasons.keys;
            row = {b{1},pm{1},num2str(pm{2}),num2str(total), ...
                num2str(nd),num2str(nd/total,'%.4f')};
            for j = 1:numel(r)
                row{end+1} = r{j}; %#ok<AGROW>
                row{end+1} = num2str(reasons(r{j})); %#ok<AGROW>
                if ~ismember(r{j},allReasons)
                    allReasons{end+1} = r{j}; %#ok<AGROW>
                end
            end
            dirRows{end+1} = row; %#ok<AGROW>
        end
    end
    % pad every row to a uniform width (6 fixed cols + 2 per reason)
    nReasonCols = numel(allReasons);
    width = 6 + 2*nReasonCols;
    for i = 1:numel(dirRows)
        row = dirRows{i};
        if numel(row) < width
            row((numel(row)+1):width) = {''};
        end
        dirRows{i} = row;
    end
    if isempty(dirRows)
        dirRows = cell(0,width);
    else
        dirRows = vertcat(dirRows{:});
    end
    hdr = {'behavior','problem','M','totalSnapshots','ND_KMEANS', ...
        'ND_KMEANS_ratio'};
    for j = 1:nReasonCols
        hdr{end+1} = sprintf('reason%d',j); %#ok<AGROW>
        hdr{end+1} = sprintf('count%d',j); %#ok<AGROW>
    end
    writeCSV(fullfile(analysisDir,'Stage1_direction_source_summary.csv'),hdr,dirRows);

    % ---- branch overlap summary (per file) ----
    overlapRows = {};
    for i = 1:numel(S)
        d = S{i};
        st = fileOverlapStats(d);
        overlapRows(end+1,:) = {d.metadata.behavior,d.metadata.problem, ...
            num2str(d.metadata.M),num2str(d.metadata.run), ...
            num2str(st.corrV,'%.4f'),num2str(st.jacSC,'%.4f'), ...
            num2str(st.jacAC,'%.4f'),num2str(st.jacSA,'%.4f'), ...
            num2str(st.eff,'%.6e'),num2str(st.flip,'%.4f'), ...
            num2str(d.IGD,'%.6e'),num2str(d.IGDp,'%.6e')};
    end
    writeCSV(fullfile(analysisDir,'Stage1_branch_overlap_summary.csv'), ...
        {'behavior','problem','M','run','meanCorrScoreVLabelDyn', ...
         'meanJaccard_Catalog_TopQScoreV','meanJaccard_Catalog_TopQAnchorMargin', ...
         'meanJaccard_TopQScoreV_TopQAnchorMargin','meanEffectiveScaleRatio', ...
         'meanCatalogFlipRate','IGD','IGDp'},overlapRows);

    % ---- trajectory summary (per file) ----
    trajRows = {};
    for i = 1:numel(S)
        d = S{i};
        nInd = sum(strcmp({d.trajectory.CandidateMode},'indicator'));
        nExp = sum(strcmp({d.trajectory.CandidateMode},'explore'));
        nFal = sum(strcmp({d.trajectory.CandidateMode},'fallback'));
        nEvalPerGen = arrayfun(@(t)numel(t.SelectedEvalID),d.trajectory);
        trajRows(end+1,:) = {d.metadata.behavior,d.metadata.problem, ...
            num2str(d.metadata.M),num2str(d.metadata.run), ...
            num2str(numel(d.trajectory)),num2str(nInd),num2str(nExp), ...
            num2str(nFal),num2str(mean(nEvalPerGen),'%.3f')};
    end
    writeCSV(fullfile(analysisDir,'Stage1_trajectory_summary.csv'), ...
        {'behavior','problem','M','run','generations','indicatorGens', ...
         'exploreGens','fallbackGens','meanEvalsPerGen'},trajRows);

    % ---- manifest summary (from runner output if present) ----
    manFile = fullfile(analysisDir,'Stage1_run_manifest.csv');
    if ~isfile(manFile)
        writeCSV(manFile,{'behavior','problem','M','run','pairedKey','status','message'}, {});
    end

    % ---- decision ----
    decision = decideStage1(S,invalidLog,eqFile,profile);
    writeCSV(fullfile(analysisDir,'Stage1_decision.csv'), ...
        {'field','value'},{'DecisionCode',decision.code; ...
        'Reason',decision.reason; 'ValidFiles',num2str(numel(S)); ...
        'InvalidFiles',num2str(numel(invalidLog)); ...
        'ND_KMEANS_below50pct',num2str(decision.lowAdaptive)});

    % ---- analysis MAT ----
    analysis = struct();
    analysis.profile = profile;
    analysis.validFiles = validFiles;
    analysis.invalidLog = invalidLog;
    analysis.snapshotMetrics = readCSV(fullfile(analysisDir,'Stage1_snapshot_metrics.csv'));
    analysis.directionSourceSummary = readCSV(fullfile(analysisDir,'Stage1_direction_source_summary.csv'));
    analysis.branchOverlapSummary = readCSV(fullfile(analysisDir,'Stage1_branch_overlap_summary.csv'));
    analysis.trajectorySummary = readCSV(fullfile(analysisDir,'Stage1_trajectory_summary.csv'));
    analysis.decision = decision;
    save(fullfile(analysisDir,'Stage1_analysis.mat'),'analysis','-v7.3');

    fprintf('Decision: %s\n',decision.code);
    fprintf('  %s\n',decision.reason);
    if ~isempty(invalidLog)
        fprintf('Invalid existing files (%d):\n',numel(invalidLog));
        for i = 1:numel(invalidLog), fprintf('  %s\n',invalidLog{i}); end
    end
end

%% ============ helpers ============
function stats = fileOverlapStats(d)
%fileOverlapStats Per-file aggregated descriptive statistics.
    n = numel(d.snapshots);
    corrV = NaN(n,1); jacSC = NaN(n,1); jacAC = NaN(n,1);
    jacSA = NaN(n,1); eff = NaN(n,1); flip = NaN(n,1);
    prevCat = [];
    for s = 1:n
        sn = d.snapshots(s);
        scoreV = sn.ScoreV(:);
        label  = double(sn.LabelDyn(:));
        cat    = sn.CatalogCurrent(:);
        margin = sn.AnchorMargin(:);
        Nw = numel(cat);            % actual population width of this snapshot
        topK = max(1,ceil(Nw*d.metadata.rGood));
        % Spearman correlation
        if std(scoreV)>0 && std(label)>0
            corrV(s) = corr(scoreV,label,'Type','Spearman');
        end
        % TopQ indices
        [~,iSV] = sort(scoreV,'descend');
        [~,iMA] = sort(margin,'descend');
        topSV = false(Nw,1); topSV(iSV(1:min(topK,Nw))) = true;
        topMA = false(Nw,1); topMA(iMA(1:min(topK,Nw))) = true;
        jacSC(s) = jaccard(cat,topSV);
        jacAC(s) = jaccard(cat,topMA);
        jacSA(s) = jaccard(topSV,topMA);
        eff(s)   = sn.EffectiveScaleRatio;
        if ~isempty(prevCat)
            flip(s) = mean(prevCat ~= cat);
        end
        prevCat = cat;
    end
    stats = struct( ...
        'corrV',mean(corrV,'omitnan'), ...
        'jacSC',mean(jacSC,'omitnan'), ...
        'jacAC',mean(jacAC,'omitnan'), ...
        'jacSA',mean(jacSA,'omitnan'), ...
        'eff',mean(eff,'omitnan'), ...
        'flip',mean(flip,'omitnan'));
end

function j = jaccard(a,b)
    a = a(:) > 0; b = b(:) > 0;
    inter = sum(a & b); uni = sum(a | b);
    j = inter / max(uni,1);
end

function decision = decideStage1(S,invalidLog,eqFile,profile)
%decideStage1 Apply the Stage-1 decision rules (Section 9).
    decision = struct('code','PASS_TO_STAGE2','reason','','lowAdaptive',false);

    if ~isempty(invalidLog)
        decision.code = 'STOP_SCHEMA_INVALID';
        decision.reason = sprintf('Validator failures: %d',numel(invalidLog));
        return;
    end
    if isempty(S)
        decision.code = 'INSUFFICIENT_DATA';
        decision.reason = 'No valid files found';
        return;
    end
    if strcmp(profile,'smoke')
        % smoke is pipeline validation; no paper statistics, no gate.
        decision.code = 'PASS_TO_STAGE2';
        decision.reason = 'smoke pipeline valid (not part of paper statistics)';
        return;
    end

    % equivalence gate
    eqOk = false;
    if ~isempty(eqFile) && isfile(eqFile)
        txt = strtrim(fileread(eqFile));
        eqOk = strcmpi(txt,'PASS');
    end
    if ~eqOk
        decision.code = 'STOP_TRAJECTORY_MISMATCH';
        decision.reason = sprintf('Equivalence tests not confirmed (%s)', ...
            getfield_wrap(eqFile));
        return;
    end

    % paired-run sufficiency: per (problem,M), need >= 4 valid paired runs
    probMs = uniqueKey(S,{'problem','M'});
    for k = 1:numel(probMs)
        pm = probMs{k};
        runsH = cellfun(@(d)strcmp(d.metadata.problem,pm{1}) && ...
            d.metadata.M==pm{2} && strcmp(d.metadata.behavior,'Hybrid'),S);
        runsA = cellfun(@(d)strcmp(d.metadata.problem,pm{1}) && ...
            d.metadata.M==pm{2} && strcmp(d.metadata.behavior,'AnchorNative'),S);
        keysH = cellfun(@(d)d.metadata.pairedKey,S(runsH),'UniformOutput',false);
        keysA = cellfun(@(d)d.metadata.pairedKey,S(runsA),'UniformOutput',false);
        paired = intersect(keysH,keysA);
        if numel(paired) < 4
            decision.code = 'INSUFFICIENT_DATA';
            decision.reason = sprintf('%s M%d: %d valid paired runs (< 4)', ...
                pm{1},pm{2},numel(paired));
            return;
        end
    end

    % adaptive coverage: ND_KMEANS snapshot ratio per (problem,M,behavior)
    low = {};
    for k = 1:numel(probMs)
        pm = probMs{k};
        for b = {'Hybrid','AnchorNative'}
            idx = cellfun(@(d)strcmp(d.metadata.problem,pm{1}) && ...
                d.metadata.M==pm{2} && strcmp(d.metadata.behavior,b{1}),S);
            if ~any(idx), continue; end
            total = 0; nd = 0;
            for i = find(idx)
                for s = 1:numel(S{i}.snapshots)
                    total = total + 1;
                    if S{i}.snapshots(s).DirectionSource == 1, nd = nd+1; end
                end
            end
            if total > 0 && nd/total < 0.5
                low{end+1} = sprintf('%s M%d %s: %.1f%%', ...
                    pm{1},pm{2},b{1},100*nd/total); %#ok<AGROW>
            end
        end
    end
    decision.lowAdaptive = ~isempty(low);
    if decision.lowAdaptive
        decision.code = 'PASS_WITH_LOW_ADAPTIVE_COVERAGE';
        decision.reason = strjoin(low,'; ');
    else
        decision.code = 'PASS_TO_STAGE2';
        decision.reason = 'All required jobs valid; equivalence passed; adaptive coverage >= 50%';
    end
end

function v = getfield_wrap(x), v = x; end

function keys = uniqueKey(S,fields)
%uniqueKey Unique (field1,field2,...) combinations over loaded structs.
    seen = {};
    keys = {};
    for i = 1:numel(S)
        d = S{i};
        row = cell(1,numel(fields));
        for j = 1:numel(fields)
            row{j} = d.metadata.(fields{j});
        end
        key = sprintf('%s_%s',row{1},num2str(row{2}));
        if ~ismember(key,seen)
            seen{end+1} = key; %#ok<AGROW>
            keys{end+1} = row; %#ok<AGROW>
        end
    end
end

function writeCSV(filePath,headers,rows)
    fid = fopen(filePath,'w');
    fprintf(fid,'%s\n',strjoin(headers,','));
    for i = 1:size(rows,1)
        cells = rows(i,:);
        for j = 1:numel(cells)
            if j > 1, fprintf(fid,','); end
            fprintf(fid,'%s',num2str_wrap(cells{j}));
        end
        fprintf(fid,'\n');
    end
    fclose(fid);
end

function s = num2str_wrap(x)
    if isnumeric(x)
        s = num2str(x);
    else
        s = strrep(x,',',';');
    end
end

function C = readCSV(filePath)
    fid = fopen(filePath,'r');
    C = textscan(fid,'%s','Delimiter','\n');
    fclose(fid);
    C = C{1};
end
