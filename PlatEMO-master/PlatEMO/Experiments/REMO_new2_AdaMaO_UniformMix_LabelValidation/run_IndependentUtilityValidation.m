function manifest = run_IndependentUtilityValidation(profile, varargin)
%run_IndependentUtilityValidation Resumable runner for Stage 3.
%   manifest = run_IndependentUtilityValidation(profile) computes the
%   independent external-utility metrics for every VALID paired
%   Stage-1/Stage-2 MAT of the same profile:
%       results/stage3/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
%   Stage 3 is PURE OFFLINE: no Problem.Evaluation call, no relation-model
%   training. It only reads Stage-1 evaluations/snapshots and Stage-2 label
%   provenance (re-deriving L0..L8 deterministically from Stage-1 snapshots
%   via ComputeLabelAblationVariants, which is byte-identical to Stage 2).
%
%   Resume semantics (same as Stage 1/2):
%     - existing, validator-passing result file is skipped;
%     - existing, invalid result file BLOCKS the job (never overwritten);
%     - otherwise the job runs, writes a .tmp.mat, validates it, and
%       atomically moves it to the final path.
%
%   Optional key-value filters (subset execution, for parallel workers):
%     'problems',{...}, 'Ms',[...], 'behaviors',{...}, 'runs',[...]
%     'Parallel',bool   run the job loop with a parfor pool (default false)
%     'refSize', char   reference size for the MAIN analysis:
%                       '4096' (default) or '16384' (plan §7 escalation).
%                       The sensitivity row always compares the main size
%                       against the next level (4096->8192, 16384->8192).
%   Returns the manifest struct array.

    p = inputParser;
    addParameter(p,'problems',{},@(x)isempty(x)||iscellstr(x));
    addParameter(p,'Ms',[],@(x)isempty(x)||isnumeric(x));
    addParameter(p,'behaviors',{},@(x)isempty(x)||iscellstr(x));
    addParameter(p,'runs',[],@(x)isempty(x)||isnumeric(x));
    addParameter(p,'Parallel',false,@(x)islogical(x));
    addParameter(p,'refSize','4096',@(x)any(strcmp(x,{'4096','16384'})));
    parse(p,varargin{:});

    cfg = LabelValidationProtocol(profile);
    jobs = cfg.jobs;

    if ~isempty(p.Results.problems)
        jobs = jobs(ismember({jobs.problem},p.Results.problems));
    end
    if ~isempty(p.Results.Ms)
        jobs = jobs(ismember([jobs.M],p.Results.Ms));
    end
    if ~isempty(p.Results.behaviors)
        jobs = jobs(ismember({jobs.behavior},p.Results.behaviors));
    end
    if ~isempty(p.Results.runs)
        jobs = jobs(ismember([jobs.run],p.Results.runs));
    end

    expDir = fileparts(mfilename('fullpath'));
    stage1Root = fullfile(expDir,'results','stage1',profile);
    stage2Root = fullfile(expDir,'results','stage2',profile);
    stage3Root = fullfile(expDir,'results','stage3',profile);
    analysisDir = fullfile(stage3Root,'analysis');
    if ~exist(analysisDir,'dir'), mkdir(analysisDir); end

    % ---- screening gate: Stage-2 decision must allow Stage 3 ----
    allowedDecisions = {'PASS_TO_STAGE3','PASS_LABEL_COMPLEMENTARITY', ...
        'SIMPLIFY_DIRECTION_ONLY','SIMPLIFY_ANCHOR_ONLY', ...
        'PASS_LABEL_BUT_DROP_SCHEDULE'};
    gateOk = true;
    if strcmp(profile,'screening')
        decFile = fullfile(stage2Root,'analysis','Stage2_decision.csv');
        if isfile(decFile)
            t = readtable(decFile,'Delimiter',',');
            row = t(strcmp(t.field,'DecisionCode'),:);
            if ~isempty(row)
                gateOk = any(strcmp(row.value{:},allowedDecisions));
            end
        else
            gateOk = false;
        end
        if ~gateOk
            error('IndependentUtilityValidation:Stage2Gate', ...
                'Stage-2 screening decision does not allow Stage 3 (missing %s or not a PASS code)',decFile);
        end
    end

    nJobs = numel(jobs);
    entries = cell(1,nJobs);
    refSize = p.Results.refSize;

    if p.Results.Parallel && nJobs > 1
        pool = gcp('nocreate');
        if isempty(pool)
            try
                pool = parpool('local');
            catch
                pool = [];
            end
        end
        if isempty(pool)
            warning('IndependentUtilityValidation:NoPool', ...
                'Parallel requested but no worker pool available; running serially.');
        else
            fprintf('Running %d jobs on %d workers...\n',nJobs,pool.NumWorkers);
        end
        parfor i = 1:nJobs
            entries{i} = runOneJob(jobs(i),stage1Root,stage2Root,stage3Root,profile,refSize);
        end
    else
        for i = 1:nJobs
            fprintf('[%d/%d] %s %s M%d run%03d ...\n',i,nJobs, ...
                jobs(i).behavior,jobs(i).problem,jobs(i).M,jobs(i).run);
            entries{i} = runOneJob(jobs(i),stage1Root,stage2Root,stage3Root,profile,refSize);
        end
    end

    manifest = struct('behavior',{},'problem',{},'M',{},'run',{}, ...
        'pairedKey',{},'file',{},'status',{},'message',{});
    for i = 1:nJobs
        manifest(end+1) = entries{i}; %#ok<AGROW>
    end

    manifestFile = fullfile(analysisDir,'Stage3_run_manifest.csv');
    writeManifestCSV(manifest,manifestFile);
    fprintf('Manifest written: %s\n',manifestFile);
end

%% ============ one job (parfor-safe) ============
function entry = runOneJob(job,stage1Root,stage2Root,stage3Root,profile,refSize)
    src1 = fullfile(stage1Root,job.behavior,job.problem, ...
        sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));
    src2 = fullfile(stage2Root,job.behavior,job.problem, ...
        sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));
    outFile = fullfile(stage3Root,job.behavior,job.problem, ...
        sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));

    entry = struct('behavior',job.behavior,'problem',job.problem, ...
        'M',job.M,'run',job.run,'pairedKey',job.pairedKey, ...
        'file',outFile,'status','pending','message','');

    % ---- inputs must exist and be valid ----
    if ~isfile(src1)
        entry.status = 'stage1-missing'; entry.message = 'Stage-1 input file missing'; return;
    end
    if ~isfile(src2)
        entry.status = 'stage2-missing'; entry.message = 'Stage-2 input file missing'; return;
    end
    [ok1,rep1] = ValidateLabelMechanismSnapshotFile(src1,profile);
    if ~ok1
        entry.status = 'stage1-invalid'; entry.message = rep1.detail; return;
    end
    [ok2,rep2] = ValidateLabelCausalAblationFile(src2,profile);
    if ~ok2
        entry.status = 'stage2-invalid'; entry.message = rep2.detail; return;
    end

    % ---- resume / block on existing Stage-3 output ----
    if isfile(outFile)
        [ok3,rep3] = ValidateIndependentUtilityFile(outFile,profile);
        if ok3
            entry.status = 'skipped';
            entry.message = 'valid existing result';
            return;
        else
            entry.status = 'invalid-existing';
            entry.message = rep3.detail;
            error('IndependentUtilityValidation:InvalidExistingResult', ...
                'Existing Stage-3 result invalid and NOT overwritten: %s [%s]', ...
                outFile,rep3.detail);
        end
    end

    % ---- run the job (pure offline) ----
    try
        entry = runSingleJob(job,src1,src2,outFile,profile,refSize);
    catch err
        entry.status = 'failed';
        entry.message = sprintf('%s: %s',err.identifier,err.message);
    end
end

%% ============ single job ============
function entry = runSingleJob(job,src1,src2,outFile,profile,refSize)
    entry = struct('behavior',job.behavior,'problem',job.problem, ...
        'M',job.M,'run',job.run,'pairedKey',job.pairedKey, ...
        'file',outFile,'status','running','message','');

    s1 = load(src1);
    s2 = load(src2);
    meta1 = s1.metadata;
    meta2 = s2.metadata;
    if ~strcmp(meta1.pairedKey,meta2.pairedKey) || ...
            meta1.M ~= meta2.M || meta1.run ~= meta2.run
        error('IndependentUtilityValidation:PairMismatch', ...
            'Stage-1/Stage-2 pairedKey mismatch');
    end

    % metadata hash of Stage-2 source provenance
    hashInputs = struct( ...
        'schemaVersion',meta1.schemaVersion,'profile',profile, ...
        'behavior',meta1.behavior,'problem',meta1.problem, ...
        'M',meta1.M,'run',meta1.run,'pairedKey',meta1.pairedKey, ...
        'completedFE',meta1.completedFE,'nSnap',numel(s1.snapshots));
    meta1Hash = LVHashString(hashInputs);
    meta2Hash = meta2.metadataHash;

    % ---- reference set (shared cache; built on demand) ----
    ref = BuildLabelUtilityReferenceSet(job.problem, job.M, profile);
    if strcmp(refSize,'16384') && ~isfield(ref,'R16384')
        ref = BuildLabelUtilityReferenceSet(job.problem, job.M, profile, ...
            'with16384',true);
    end
    mainR = ref.R4096;
    if strcmp(refSize,'16384')
        mainR = ref.R16384;
    end
    nMain = size(mainR,1);

    % ---- choose checkpoint snapshots (plan §3) ----
    targetRatios = [0.20 0.40 0.60 0.80 0.95];
    cpIdx = chooseCheckpoints(s1.snapshots, targetRatios);
    nCP = numel(cpIdx);

    % normalize zmin/scale from R4096 (fixed, plan §4.2)
    zmin = ref.zmin;
    scale = ref.scale;

    checkpointRows = struct();
    solutionUtilityRows = struct();
    variantMetricRows = struct();
    disagreementRows = struct();
    nC=0; nS=0; nM=0; nD=0;

    ev = s1.evaluations;
    for c = 1:nCP
        sidx = cpIdx(c);
        snap = s1.snapshots(sidx);

        % normalized population objectives
        Pn = (snap.PopulationObj - zmin) ./ scale;

        % ---- greedy oracle Top25 (§5.1) ----
        oro = ComputeGreedyIGDPlusOracle(Pn, mainR, snap.PopulationEvalID);

        % ---- LOO utility (§5.2) ----
        loo = ComputeLeaveOneOutIGDPlus(Pn, mainR, snap.PopulationEvalID);

        % ---- future outcomes (§5.3) ----
        fut = ReconstructFutureLabelOutcomes(s1.snapshots, s1.trajectory, ev, sidx);

        % ---- re-derive L0..L8 labels deterministically (Stage-2 equiv) ----
        lab = ComputeLabelAblationVariants(snap, meta1);

        % ---- checkpoint row ----
        nC = nC + 1;
        crow = struct('CheckpointID',c,'TargetRatio',targetRatios(c), ...
            'SnapshotID',snap.SnapshotID,'FE',snap.FE,'Ratio',snap.Ratio, ...
            'StageBin',LVStageBin(snap.Ratio), ...
            'OracleTop25Count',numel(oro.OracleGreedyTop25), ...
            'NondominatedCount',nnz(fut.NondominatedInFinalArchive==1), ...
            'UtilityLOONonZero',nnz(loo.UtilityLOO>0));
        checkpointRows = appendRow(checkpointRows,crow,nC);

        % ---- solution utility rows ----
        for i = 1:numel(snap.PopulationEvalID)
            nS = nS + 1;
            srow = struct('CheckpointID',c, ...
                'PopulationEvalID',snap.PopulationEvalID(i), ...
                'UtilityLOO',loo.UtilityLOO(i), ...
                'InOracleTop25',ismember(snap.PopulationEvalID(i),oro.OracleGreedyTop25), ...
                'InPopulationH1',fut.InPopulationH1(i), ...
                'InPopulationH3',fut.InPopulationH3(i), ...
                'InFinalPopulation',fut.InFinalPopulation(i), ...
                'NondominatedInArchiveH1',fut.NondominatedInArchiveH1(i), ...
                'NondominatedInArchiveH3',fut.NondominatedInArchiveH3(i), ...
                'NondominatedInFinalArchive',fut.NondominatedInFinalArchive(i));
            solutionUtilityRows = appendRow(solutionUtilityRows,srow,nS);
        end

        % ---- variant metric rows ----
        mrows = ComputeExternalLabelMetrics(lab.catalogs, lab.scores, loo, ...
            oro.OracleGreedyTop25, fut, meta1.rGood);
        for m = 1:numel(mrows)
            nM = nM + 1;
            mrow = struct('CheckpointID',c);
            flds = fieldnames(mrows(m));
            for k = 1:numel(flds)
                mrow.(flds{k}) = mrows(m).(flds{k});
            end
            variantMetricRows = appendRow(variantMetricRows,mrow,nM);
        end

        % ---- disagreement rows ----
        drows = ComputeDisagreementUtility(lab.catalogs, loo, ...
            oro.OracleGreedyTop25, fut);
        for d = 1:numel(drows)
            nD = nD + 1;
            drow = struct('CheckpointID',c);
            flds = fieldnames(drows(d));
            for k = 1:numel(flds)
                drow.(flds{k}) = drows(d).(flds{k});
            end
            disagreementRows = appendRow(disagreementRows,drow,nD);
        end
    end

    % ---- reference sensitivity (run 1 only, plan §7) ----
    rs = computeReferenceSensitivity(job,profile,cpIdx,s1,ref,zmin,scale,refSize);
    referenceSensitivity = rs;   % top-level variable name in the MAT

    % ---- metadata ----
    metadata = struct( ...
        'schemaVersion',LabelValidationSchema().version, ...
        'stage3SchemaVersion',1, ...
        'profile',profile, ...
        'behavior',meta1.behavior,'problem',meta1.problem, ...
        'family',meta1.family,'M',meta1.M, ...
        'requestedD',meta1.requestedD,'actualD',meta1.actualD, ...
        'problemN',meta1.problemN,'maxFE',meta1.maxFE, ...
        'completedFE',meta1.completedFE, ...
        'rGood',meta1.rGood,'run',meta1.run,'seed',meta1.seed, ...
        'pairedKey',meta1.pairedKey, ...
        'stage1File',src1,'stage2File',src2, ...
        'stage1MetadataHash',meta1Hash, ...
        'stage2MetadataHash',meta2Hash, ...
        'referenceSeed',ref.referenceSeed, ...
        'referenceSize',nMain, ...
        'nCheckpoints',nCP, ...
        'matlabVersion',version,'computer',getComputerName(), ...
        'completedAt',datestr(now,'yyyy-mm-dd HH:MM:SS'));

    validation = struct('validator','ValidateIndependentUtilityFile', ...
        'checkedAt',datestr(now,'yyyy-mm-dd HH:MM:SS'),'passed',true,'detail','');

    % ---- atomic write (v7: small-field struct arrays) ----
    [d,~,~] = fileparts(outFile);
    if ~exist(d,'dir'), mkdir(d); end
    tmpFile = [outFile,'.tmp.mat'];
    save(tmpFile,'metadata','checkpointRows','solutionUtilityRows', ...
        'variantMetricRows','disagreementRows','referenceSensitivity', ...
        'validation','-v7');

    [ok,rep] = ValidateIndependentUtilityFile(tmpFile,profile);
    if ~ok
        delete(tmpFile);
        issueStr = strjoin(rep.issues,' | ');
        error('IndependentUtilityValidation:SelfValidationFailed', ...
            'Generated file failed validation: %s [%s]',rep.detail,issueStr);
    end
    movefile(tmpFile,outFile,'f');
    entry.status = 'completed';
    entry.message = sprintf('%d checkpoints',nCP);
end

%% ============ checkpoint selection (plan §3) ============
function idx = chooseCheckpoints(snapshots, targetRatios)
    n = numel(snapshots);
    ratios = [snapshots.Ratio];
    idx = [];
    used = false(1,n);
    for t = 1:numel(targetRatios)
        best = NaN; bestD = Inf;
        for i = 1:n
            if used(i), continue; end
            d = abs(ratios(i) - targetRatios(t));
            if d < bestD - 1e-12 || (abs(d-bestD) <= 1e-12 && snapshots(i).FE < snapshots(best).FE)
                best = i; bestD = d;
            end
        end
        if ~isnan(best)
            idx(end+1) = best; %#ok<AGROW>
            used(best) = true;
        else
            idx(end+1) = NaN; %#ok<AGROW>  (no snapshot available)
        end
    end
    % drop NaNs (unavailable checkpoints are not materialized)
    idx = idx(~isnan(idx));
end

%% ============ reference sensitivity (§7) ============
function rs = computeReferenceSensitivity(job,profile,cpIdx,s1,ref,zmin,scale,refSize)
    rs = struct('ReferenceSize',{},'SpearmanLOO',{},'OracleJaccard',{}, ...
        'Passed',{},'NCheckpoints',{});
    if job.run ~= 1
        rs = struct('ReferenceSize',NaN,'SpearmanLOO',NaN, ...
            'OracleJaccard',NaN,'Passed',false,'NCheckpoints',0);
        return;
    end
    % main reference (already built by caller) and the next-level reference
    if strcmp(refSize,'16384')
        mainR = ref.R16384;
        nextR = ref.R8192;
        refSizeName = 16384;
    else
        mainR = ref.R4096;
        nextR = ref.R8192;
        refSizeName = 4096;
    end
    sp = []; jac = [];
    for c = 1:numel(cpIdx)
        snap = s1.snapshots(cpIdx(c));
        Pn = (snap.PopulationObj - zmin) ./ scale;
        loo1 = ComputeLeaveOneOutIGDPlus(Pn, mainR, snap.PopulationEvalID);
        loo2 = ComputeLeaveOneOutIGDPlus(Pn, nextR, snap.PopulationEvalID);
        if ~all(loo1.UtilityLOO == loo1.UtilityLOO(1)) && ...
                ~all(loo2.UtilityLOO == loo2.UtilityLOO(1))
            sp(end+1) = corr(loo1.UtilityLOO,loo2.UtilityLOO, ...
                'Type','Spearman'); %#ok<AGROW>
        end
        % jaccard of oracle top-25 sets across main vs next level
        oro1 = ComputeGreedyIGDPlusOracle(Pn, mainR, snap.PopulationEvalID);
        oro2 = ComputeGreedyIGDPlusOracle(Pn, nextR, snap.PopulationEvalID);
        inter = numel(intersect(oro1.OracleGreedyTop25, oro2.OracleGreedyTop25));
        union_ = numel(union(oro1.OracleGreedyTop25, oro2.OracleGreedyTop25));
        jac(end+1) = inter / max(union_,1); %#ok<AGROW>
    end
    if isempty(sp)
        sp = NaN;
    end
    pass = all(sp >= 0.95) && all(jac >= 0.90);
    rs = struct('ReferenceSize',refSizeName,'SpearmanLOO',mean(sp), ...
        'OracleJaccard',mean(jac),'Passed',pass, ...
        'NCheckpoints',numel(cpIdx));
end

%% ============ struct array append helper ============
function arr = appendRow(arr,row,n)
    if n == 1
        arr = row;
    else
        arr(n) = row; %#ok<AGROW>
    end
end

%% ============ manifest writer ============
function writeManifestCSV(manifest,filePath)
    if isempty(manifest)
        fid = fopen(filePath,'w');
        fprintf(fid,'behavior,problem,M,run,pairedKey,status,message\n');
        fclose(fid);
        return;
    end
    fid = fopen(filePath,'w');
    fprintf(fid,'behavior,problem,M,run,pairedKey,status,message\n');
    for i = 1:numel(manifest)
        e = manifest(i);
        fprintf(fid,'%s,%s,%d,%d,%s,%s,%s\n', ...
            e.behavior,e.problem,e.M,e.run,e.pairedKey,e.status,e.message);
    end
    fclose(fid);
end

function c = getComputerName()
    if ispc
        c = getenv('COMPUTERNAME');
    else
        c = getenv('HOSTNAME');
    end
    if isempty(c), c = 'unknown'; end
end
