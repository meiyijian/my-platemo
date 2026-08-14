function diag_smoke_job()
%diag_smoke_job Manually run one smoke job (Hybrid DTLZ2 M3) and save the
%   MAT without the atomic-move/delete wrapper, then validate it, printing
%   every validator issue.

    addpath(genpath(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
    rehash;
    rng(12345,'twister');
    Xw = rand(20,4); Yw = double(Xw(:,1) > 0.5);
    netW = patternnet(2); netW.trainParam.showWindow = 0;
    netW = train(netW,Xw',Yw');
    try, fitrsvm(Xw,Yw,'KernelFunction','rbf','KernelScale','auto','Standardize',true); catch, end

    cfg = LabelValidationProtocol('smoke');
    job = cfg.jobs(1);   % Hybrid DTLZ2 M3 run1
    savedState = rng;
    rng(job.Seed,'twister');

    Problem = feval(job.problem,'N',job.N,'M',job.M,'D',job.requestedD, ...
        'maxFE',job.maxFE,'maxRuntime',inf);
    params = {cfg.parameters.gmax,cfg.parameters.pMix,cfg.parameters.rGood, ...
        cfg.parameters.qKeep,cfg.parameters.lambda0,cfg.parameters.nMin, ...
        cfg.parameters.nMax};
    Algorithm = feval(['LVUniformMixAudit_',job.behavior], ...
        'parameter',params,'run',job.run,'save',0,'outputFcn',@silentOutput);
    Algorithm.Solve(Problem);
    rng(savedState);

    finalPop = Algorithm.result{end,2};
    IGD  = Problem.CalMetric('IGD',finalPop);
    IGDp = Problem.CalMetric('IGDp',finalPop);
    ad = Algorithm.auditData;

    fprintf('FE=%d initialFE=%d popN=%d completedFE=%d\n', ...
        Problem.FE,ad.initialFE,ad.populationN,ad.completedFE);
    fprintf('nSnapshots=%d nTrajectory=%d\n',numel(ad.snapshots),numel(ad.trajectory));
    fprintf('IGD=%.6e IGDp=%.6e\n',IGD,IGDp);

    meta = struct('schemaVersion',1,'profile','smoke','behavior',job.behavior, ...
        'problem',job.problem,'family',job.family,'M',job.M, ...
        'requestedD',job.requestedD,'actualD',Problem.D,'problemN',ad.populationN, ...
        'initialFE',ad.initialFE,'maxFE',job.maxFE,'completedFE',ad.completedFE, ...
        'gmax',cfg.parameters.gmax,'pMix',cfg.parameters.pMix, ...
        'rGood',cfg.parameters.rGood,'qKeep',cfg.parameters.qKeep, ...
        'lambda0',cfg.parameters.lambda0,'nMin',cfg.parameters.nMin, ...
        'nMax',cfg.parameters.nMax,'run',job.run,'seed',job.Seed, ...
        'pairedKey',job.pairedKey,'algorithmClass',class(Algorithm), ...
        'frozenAlgorithmClass','REMO_new2_AdaMaO_SDEOnly_UniformMix_Original', ...
        'matlabVersion',version,'computer',getenv('COMPUTERNAME'), ...
        'completedAt',char(datetime('now')));

    evaluations = ad.evaluations;
    snapshots = ad.snapshots;
    trajectory = ad.trajectory;
    finalPopulation = ad.finalPopulation;
    runtime = Algorithm.metric.runtime;
    auditRuntime = ad.auditRuntime;
    validation = struct('wallTime',0,'probe','diag');

    out = fullfile(fileparts(mfilename('fullpath')),'results','stage1','smoke', ...
        job.behavior,job.problem,sprintf('M%d',job.M),'run_001_diag.mat');
    [d,~,~] = fileparts(out);
    if ~exist(d,'dir'), mkdir(d); end
    metadata = meta;
    save(out,'metadata','evaluations','snapshots','trajectory','finalPopulation', ...
        'IGD','IGDp','runtime','auditRuntime','validation','-v7.3');
    fprintf('SAVED %s\n',out);

    [ok,rep] = ValidateLabelMechanismSnapshotFile(out,'smoke');
    fprintf('VALIDATE ok=%d\n',ok);
    for i = 1:numel(rep.issues)
        fprintf('  ISSUE: %s\n',rep.issues{i});
    end
end

function silentOutput(varargin)
end
