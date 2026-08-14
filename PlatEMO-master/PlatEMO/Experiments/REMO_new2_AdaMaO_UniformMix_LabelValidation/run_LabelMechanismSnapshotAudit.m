function manifest = run_LabelMechanismSnapshotAudit(profile, varargin)
%run_LabelMechanismSnapshotAudit Resumable runner for Stage 1.
%   manifest = run_LabelMechanismSnapshotAudit(profile) runs all jobs of
%   the given profile ('smoke' | 'pilot' | 'screening'). For every job:
%     - an existing, validator-passing result file is skipped;
%     - an existing, invalid result file BLOCKS the job (never overwritten);
%     - otherwise the job runs, writes a .tmp.mat, validates it, and
%       atomically moves it to the final path.
%   The global RNG state is saved before each job and restored afterwards;
%   rng(job.Seed,'twister') is applied before constructing the algorithm.
%
%   Optional key-value filters (subset execution, for parallel workers):
%     'problems',{...}  cellstr of problem names (default: all)
%     'Ms',[...]        objective counts (default: all)
%     'behaviors',{...} cellstr of behaviors (default: all)
%     'runs',[...]      run numbers (default: all)
%   Returns the manifest table as a struct array.

    p = inputParser;
    addParameter(p,'problems',{},@(x)isempty(x)||iscellstr(x));
    addParameter(p,'Ms',[],@(x)isempty(x)||isnumeric(x));
    addParameter(p,'behaviors',{},@(x)isempty(x)||iscellstr(x));
    addParameter(p,'runs',[],@(x)isempty(x)||isnumeric(x));
    parse(p,varargin{:});

    cfg = LabelValidationProtocol(profile);
    jobs = cfg.jobs;

    % ---- subset filter ----
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
    resultRoot = fullfile(expDir,'results','stage1',profile);
    analysisDir = fullfile(resultRoot,'analysis');
    if ~exist(analysisDir,'dir'), mkdir(analysisDir); end

    % Warm up the deep-learning toolbox so that the first patternnet
    % train() call of the session (extra RNG consumption) does not happen
    % inside any job.
    warmupDeepLearning();

    manifest = struct('behavior',{},'problem',{},'M',{},'run',{}, ...
        'pairedKey',{},'file',{},'status',{},'message',{});

    for i = 1:numel(jobs)
        job = jobs(i);
        behaviorClass = ['LVUniformMixAudit_',job.behavior];
        outFile = fullfile(resultRoot,job.behavior,job.problem, ...
            sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));

        entry = struct( ...
            'behavior',job.behavior,'problem',job.problem,'M',job.M, ...
            'run',job.run,'pairedKey',job.pairedKey,'file',outFile, ...
            'status','pending','message','');

        % ---- resume / block on existing files ----
        if isfile(outFile)
            [ok,rep] = ValidateLabelMechanismSnapshotFile(outFile,profile);
            if ok
                entry.status = 'skipped';
                entry.message = 'valid existing result';
                manifest(end+1) = entry; %#ok<AGROW>
                continue;
            else
                entry.status = 'invalid-existing';
                entry.message = rep.detail;
                manifest(end+1) = entry; %#ok<AGROW>
                error('LabelValidation:InvalidExistingResult', ...
                    'Existing result is invalid and will NOT be overwritten: %s [%s]', ...
                    outFile,rep.detail);
            end
        end

        % ---- run the job ----
        try
            entry = runSingleJob(job,cfg,outFile,profile);
        catch err
            entry.status = 'failed';
            entry.message = sprintf('%s: %s',err.identifier,err.message);
        end
        manifest(end+1) = entry; %#ok<AGROW>
        fprintf('[%d/%d] %s %s M%d run%03d -> %s\n',i,numel(jobs), ...
            job.behavior,job.problem,job.M,job.run,entry.status);
    end

    % ---- write manifest ----
    manifestFile = fullfile(analysisDir,'Stage1_run_manifest.csv');
    writeManifestCSV(manifest,manifestFile);
    fprintf('Manifest written: %s\n',manifestFile);
end

%% ============ single job ============
function entry = runSingleJob(job,cfg,outFile,profile)
%runSingleJob Execute one (behavior, problem, M, run) job.
    entry = struct('behavior',job.behavior,'problem',job.problem, ...
        'M',job.M,'run',job.run,'pairedKey',job.pairedKey, ...
        'file',outFile,'status','running','message','');

    % Save global RNG state; restore in finally-like block
    savedState = rng;
    cleanup = onCleanup(@() rng(savedState));
    rng(job.Seed,'twister');

    % ---- construct problem (frozen contract) ----
    Problem = feval(job.problem, ...
        'N',job.N,'M',job.M,'D',job.requestedD,'maxFE',job.maxFE, ...
        'maxRuntime',inf);

    % ---- construct algorithm ----
    params = {cfg.parameters.gmax,cfg.parameters.pMix,cfg.parameters.rGood, ...
        cfg.parameters.qKeep,cfg.parameters.lambda0,cfg.parameters.nMin, ...
        cfg.parameters.nMax};
    Algorithm = feval(['LVUniformMixAudit_',job.behavior], ...
        'parameter',params,'run',job.run,'save',0, ...
        'outputFcn',@silentOutput);

    % ---- solve ----
    tWall = tic;
    Algorithm.Solve(Problem);
    wallTime = toc(tWall);

    % ---- metrics on the final archive (frozen result{end}) ----
    finalPop = Algorithm.result{end,2};
    IGD  = Problem.CalMetric('IGD',finalPop);
    IGDp = Problem.CalMetric('IGDp',finalPop);

    % ---- assemble MAT ----
    ad = Algorithm.auditData;
    meta = struct();
    schema = LabelValidationSchema();
    meta.schemaVersion = schema.version;
    meta.profile       = profile;
    meta.behavior      = job.behavior;
    meta.problem       = job.problem;
    meta.family        = job.family;
    meta.M             = job.M;
    meta.requestedD    = job.requestedD;
    meta.actualD       = Problem.D;
    meta.problemN      = ad.populationN;
    meta.initialFE     = ad.initialFE;
    meta.maxFE         = job.maxFE;
    meta.completedFE   = ad.completedFE;
    meta.gmax          = cfg.parameters.gmax;
    meta.pMix          = cfg.parameters.pMix;
    meta.rGood         = cfg.parameters.rGood;
    meta.qKeep         = cfg.parameters.qKeep;
    meta.lambda0       = cfg.parameters.lambda0;
    meta.nMin          = cfg.parameters.nMin;
    meta.nMax          = cfg.parameters.nMax;
    meta.run           = job.run;
    meta.seed          = job.Seed;
    meta.pairedKey     = job.pairedKey;
    meta.algorithmClass = class(Algorithm);
    meta.frozenAlgorithmClass = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original';
    meta.matlabVersion = version;
    meta.computer      = getenv('COMPUTERNAME');
    if isempty(meta.computer), meta.computer = computer; end
    meta.completedAt   = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));

    evaluations     = ad.evaluations;
    snapshots       = ad.snapshots;
    trajectory      = ad.trajectory;
    finalPopulation = ad.finalPopulation;
    runtime         = Algorithm.metric.runtime;
    auditRuntime    = ad.auditRuntime;
    validation      = struct('wallTime',wallTime,'probe','runner');

    % ---- atomic write: tmp then validate then move ----
    [d,~,~] = fileparts(outFile);
    if ~exist(d,'dir'), mkdir(d); end
    tmpFile = [outFile,'.tmp.mat'];
    try
        metadata = meta;   % top-level variable name per schema contract
        save(tmpFile,'metadata','evaluations','snapshots','trajectory', ...
            'finalPopulation','IGD','IGDp','runtime','auditRuntime', ...
            'validation','-v7.3');
        [ok,rep] = ValidateLabelMechanismSnapshotFile(tmpFile,profile);
        if ~ok
            if isfile(tmpFile), delete(tmpFile); end
            error('LabelValidation:PostWriteInvalid', ...
                'Generated file failed validation: %s',rep.detail);
        end
        movefile(tmpFile,outFile,'f');
        entry.status = 'completed';
        entry.message = sprintf('IGD=%.6e IGDp=%.6e',IGD,IGDp);
    catch err
        if isfile(tmpFile), delete(tmpFile); end
        rethrow(err);
    end
end

%% ============ manifest CSV ============
function writeManifestCSV(manifest,filePath)
    fid = fopen(filePath,'w');
    fprintf(fid,'behavior,problem,M,run,pairedKey,status,message\n');
    for i = 1:numel(manifest)
        msg = strrep(manifest(i).message,',',';');
        fprintf(fid,'%s,%s,%d,%d,%s,%s,%s\n', ...
            manifest(i).behavior,manifest(i).problem,manifest(i).M, ...
            manifest(i).run,manifest(i).pairedKey,manifest(i).status,msg);
    end
    fclose(fid);
end

%% ============ silent output ============
function silentOutput(varargin)
end

%% ============ deep-learning warm-up ============
function warmupDeepLearning()
%warmupDeepLearning Fire one patternnet train() and one fitrsvm so that
%   toolbox initialization random consumption happens BEFORE any job runs.
    rng(12345,'twister');
    X = rand(20,4); Y = double(X(:,1) > 0.5);
    net = patternnet(2);
    net.trainParam.showWindow = 0;
    net = train(net,X',Y');
    try
        fitrsvm(X,Y,'KernelFunction','rbf','KernelScale','auto', ...
            'Standardize',true);
    catch
    end
end
