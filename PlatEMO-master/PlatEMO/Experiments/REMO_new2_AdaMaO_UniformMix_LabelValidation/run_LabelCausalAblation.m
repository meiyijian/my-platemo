function manifest = run_LabelCausalAblation(profile, varargin)
%run_LabelCausalAblation Resumable runner for Stage 2 (offline ablation).
%   manifest = run_LabelCausalAblation(profile) computes the L0..L8 label
%   variants on every VALID Stage-1 MAT of the same profile:
%       results/stage1/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
%   and writes:
%       results/stage2/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
%   Stage 2 is a PURE OFFLINE computation: no Problem.Evaluation call,
%   no relation-model training, no production-RNG mutation. Each variant
%   row records the provenance needed by the validator.
%
%   Resume semantics (same as Stage 1):
%     - existing, validator-passing result file is skipped;
%     - existing, invalid result file BLOCKS the job (never overwritten);
%     - otherwise the job runs, writes a .tmp.mat, validates it, and
%       atomically moves it to the final path.
%
%   Optional key-value filters (subset execution, for parallel workers):
%     'problems',{...}  cellstr of problem names
%     'Ms',[...]        objective counts
%     'behaviors',{...} cellstr of behaviors
%     'runs',[...]      run numbers
%     'Parallel',bool   run the job loop with a parfor pool (default false)
%   Returns the manifest struct array.

    p = inputParser;
    addParameter(p,'problems',{},@(x)isempty(x)||iscellstr(x));
    addParameter(p,'Ms',[],@(x)isempty(x)||isnumeric(x));
    addParameter(p,'behaviors',{},@(x)isempty(x)||iscellstr(x));
    addParameter(p,'runs',[],@(x)isempty(x)||isnumeric(x));
    addParameter(p,'Parallel',false,@(x)islogical(x));
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
    analysisDir = fullfile(stage2Root,'analysis');
    if ~exist(analysisDir,'dir'), mkdir(analysisDir); end

    % ---- screening gate: Stage-1 decision must allow Stage 2 ----
    allowedDecisions = {'PASS_TO_STAGE2','PASS_WITH_LOW_ADAPTIVE_COVERAGE'};
    gateOk = true;
    if strcmp(profile,'screening')
        decFile = fullfile(stage1Root,'analysis','Stage1_decision.csv');
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
            error('LabelCausalAblation:Stage1Gate', ...
                'Stage-1 screening decision does not allow Stage 2 (missing %s or not PASS_TO_STAGE2)',decFile);
        end
    end

    % ---- job dispatch: parfor or serial ----
    nJobs = numel(jobs);
    entries = cell(1,nJobs);

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
            warning('LabelCausalAblation:NoPool', ...
                'Parallel requested but no worker pool available; running serially.');
        else
            fprintf('Running %d jobs on %d workers...\n',nJobs,pool.NumWorkers);
        end
        parfor i = 1:nJobs
            entries{i} = runOneJob(jobs(i),stage1Root,stage2Root,profile);
        end
    else
        for i = 1:nJobs
            fprintf('[%d/%d] %s %s M%d run%03d ...\n',i,nJobs, ...
                jobs(i).behavior,jobs(i).problem,jobs(i).M,jobs(i).run);
            entries{i} = runOneJob(jobs(i),stage1Root,stage2Root,profile);
        end
    end

    % ---- assemble manifest in job order ----
    manifest = struct('behavior',{},'problem',{},'M',{},'run',{}, ...
        'pairedKey',{},'file',{},'status',{},'message',{});
    for i = 1:nJobs
        manifest(end+1) = entries{i}; %#ok<AGROW>
    end

    manifestFile = fullfile(analysisDir,'Stage2_run_manifest.csv');
    writeManifestCSV(manifest,manifestFile);
    fprintf('Manifest written: %s\n',manifestFile);
end

%% ============ one job (parfor-safe) ============
function entry = runOneJob(job,stage1Root,stage2Root,profile)
%runOneJob Resume/run/block logic for one job; returns its manifest entry.
    srcFile = fullfile(stage1Root,job.behavior,job.problem, ...
        sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));
    outFile = fullfile(stage2Root,job.behavior,job.problem, ...
        sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));

    entry = struct('behavior',job.behavior,'problem',job.problem, ...
        'M',job.M,'run',job.run,'pairedKey',job.pairedKey, ...
        'file',outFile,'status','pending','message','');

    % ---- Stage-1 input must exist and be valid ----
    if ~isfile(srcFile)
        entry.status = 'stage1-missing';
        entry.message = 'Stage-1 input file missing';
        return;
    end
    [ok1,rep1] = ValidateLabelMechanismSnapshotFile(srcFile,profile);
    if ~ok1
        entry.status = 'stage1-invalid';
        entry.message = rep1.detail;
        return;
    end

    % ---- resume / block on existing Stage-2 output ----
    if isfile(outFile)
        [ok2,rep2] = ValidateLabelCausalAblationFile(outFile,profile);
        if ok2
            entry.status = 'skipped';
            entry.message = 'valid existing result';
            return;
        else
            entry.status = 'invalid-existing';
            entry.message = rep2.detail;
            error('LabelCausalAblation:InvalidExistingResult', ...
                'Existing Stage-2 result invalid and NOT overwritten: %s [%s]', ...
                outFile,rep2.detail);
        end
    end

    % ---- run the job (pure offline) ----
    try
        entry = runSingleJob(job,srcFile,outFile,profile);
    catch err
        entry.status = 'failed';
        entry.message = sprintf('%s: %s',err.identifier,err.message);
    end
end

%% ============ single job ============
function entry = runSingleJob(job,srcFile,outFile,profile)
%runSingleJob Offline Stage-2 computation for one (behavior,problem,M,run).
    entry = struct('behavior',job.behavior,'problem',job.problem, ...
        'M',job.M,'run',job.run,'pairedKey',job.pairedKey, ...
        'file',outFile,'status','running','message','');

    s1 = load(srcFile);
    metaIn  = s1.metadata;
    snapIn  = s1.snapshots;
    nSnap   = numel(snapIn);

    % ---- metadata hash of the Stage-1 source ----
    hashInputs = struct( ...
        'schemaVersion',metaIn.schemaVersion,'profile',metaIn.profile, ...
        'behavior',metaIn.behavior,'problem',metaIn.problem, ...
        'M',metaIn.M,'run',metaIn.run,'pairedKey',metaIn.pairedKey, ...
        'completedFE',metaIn.completedFE,'nSnap',nSnap);
    metaHash = LVHashString(hashInputs);

    % ---- per-snapshot computation ----
    variantRowsAll = struct();
    overlapRowsAll = struct();
    stabilityRowsAll = struct();
    nV=0; nO=0; nS=0;

    for s = 1:nSnap
        snap = snapIn(s);
        out  = ComputeLabelAblationVariants(snap, metaIn);
        if ~out.repro.ok
            error('LabelCausalAblation:ReproductionFailure', ...
                'snapshot %d: %s',snap.SnapshotID,out.repro.detail);
        end

        % variant rows (with context)
        vr = out.variantRows;
        for r = 1:numel(vr)
            nV = nV + 1;
            row = snapshotContextRow(job,metaIn,snap);
            fv = vr(r);
            flds = fieldnames(fv);
            for k = 1:numel(flds)
                row.(flds{k}) = fv.(flds{k});
            end
            if nV == 1
                variantRowsAll = row;
            else
                variantRowsAll(nV) = row; %#ok<AGROW>
            end
        end

        % overlap rows
        ov = ComputeLabelOverlapMetrics(out.catalogs, out.scores);
        for r = 1:numel(ov)
            nO = nO + 1;
            row = snapshotContextRow(job,metaIn,snap);
            fo = ov(r);
            flds = fieldnames(fo);
            for k = 1:numel(flds)
                row.(flds{k}) = fo.(flds{k});
            end
            if nO == 1
                overlapRowsAll = row;
            else
                overlapRowsAll(nO) = row; %#ok<AGROW>
            end
        end

        % shuffle envelope rows (L3 vs each of 100 L6 replicates)
        se = ComputeShuffleEnvelope(out.catalogs);
        for r = 1:numel(se)
            nO = nO + 1;
            row = snapshotContextRow(job,metaIn,snap);
            fs = se(r);
            flds = fieldnames(fs);
            for k = 1:numel(flds)
                row.(flds{k}) = fs.(flds{k});
            end
            if nO == 1
                overlapRowsAll = row;
            else
                overlapRowsAll(nO) = row; %#ok<AGROW>
            end
        end

        % stability rows
        st = ComputeLabelPerturbationStability(snap, metaIn, out.catalogs, out.scores);
        for r = 1:numel(st)
            nS = nS + 1;
            row = snapshotContextRow(job,metaIn,snap);
            fs = st(r);
            flds = fieldnames(fs);
            for k = 1:numel(flds)
                row.(flds{k}) = fs.(flds{k});
            end
            if nS == 1
                stabilityRowsAll = row;
            else
                stabilityRowsAll(nS) = row; %#ok<AGROW>
            end
        end
    end

    % ---- metadata ----
    metadata = struct( ...
        'schemaVersion',LabelValidationSchema().version, ...
        'stage2SchemaVersion',2, ...
        'profile',profile, ...
        'behavior',metaIn.behavior,'problem',metaIn.problem, ...
        'family',metaIn.family,'M',metaIn.M, ...
        'requestedD',metaIn.requestedD,'actualD',metaIn.actualD, ...
        'problemN',metaIn.problemN,'initialFE',metaIn.initialFE, ...
        'maxFE',metaIn.maxFE,'completedFE',metaIn.completedFE, ...
        'rGood',metaIn.rGood,'theta',snapIn(1).Theta, ...
        'run',metaIn.run,'seed',metaIn.seed,'pairedKey',metaIn.pairedKey, ...
        'sourceFile',srcFile,'sourceSchemaVersion',metaIn.schemaVersion, ...
        'metadataHash',metaHash,'nSnapshots',nSnap, ...
        'matlabVersion',version,'computer',getComputerName(), ...
        'completedAt',datestr(now,'yyyy-mm-dd HH:MM:SS'));

    validation = struct('validator','ValidateLabelCausalAblationFile', ...
        'checkedAt',datestr(now,'yyyy-mm-dd HH:MM:SS'),'passed',true,'detail','');

    % ---- atomic write ----
    % Use -v7 (not -v7.3): all Stage-2 payloads are struct/char/numeric
    % arrays fully supported by the classic MAT format. -v7.3 (HDF5)
    % bloats these small-field struct arrays ~100x on disk (636 MB -> 4.6
    % MB measured for one screening file).
    [d,~,~] = fileparts(outFile);
    if ~exist(d,'dir'), mkdir(d); end
    tmpFile = [outFile,'.tmp.mat'];
    save(tmpFile,'metadata','variantRowsAll','overlapRowsAll', ...
        'stabilityRowsAll','validation','-v7');

    [ok,rep] = ValidateLabelCausalAblationFile(tmpFile,profile);
    if ~ok
        delete(tmpFile);
        error('LabelCausalAblation:SelfValidationFailed', ...
            'Generated file failed validation: %s',rep.detail);
    end
    movefile(tmpFile,outFile,'f');
    entry.status = 'completed';
    entry.message = sprintf('%d snapshots',nSnap);
end

%% ============ context row prefix ============
function row = snapshotContextRow(job,meta,snap)
    row = struct( ...
        'Behavior',job.behavior,'Problem',job.problem, ...
        'Family',meta.family,'M',job.M,'Run',job.run, ...
        'Seed',meta.seed,'PairedKey',job.pairedKey, ...
        'SnapshotID',snap.SnapshotID,'Generation',snap.Generation, ...
        'FE',snap.FE,'Ratio',snap.Ratio, ...
        'StageBin',LVStageBin(snap.Ratio));
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
