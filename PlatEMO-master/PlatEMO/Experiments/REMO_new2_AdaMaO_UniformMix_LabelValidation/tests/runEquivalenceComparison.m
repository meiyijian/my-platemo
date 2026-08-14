function eq = runEquivalenceComparison(problemName,M,D,N,maxFE,gmax,run)
%runEquivalenceComparison Run frozen and Hybrid-audit algorithms under the
%   same seed and compare final solutions, FE, IGD and IGDp.
%   Returns a struct with .matched, .message, .dFE, .dIGD, .dIGDp,
%   .maxAbsDiffDec, .maxAbsDiffObj.
%
%   This helper is shared by tests/test_LabelMechanismSnapshotAudit.m and
%   the Stage-1 equivalence verification workflow.

    eq = struct('matched',false,'message','','dFE',NaN, ...
        'dIGD',NaN,'dIGDp',NaN,'maxAbsDiffDec',NaN,'maxAbsDiffObj',NaN);
    seed = LabelValidationStableSeed(1,M,run);

    % Warm up the deep-learning toolbox. The FIRST patternnet train() call
    % in a MATLAB session consumes extra random numbers (toolbox init),
    % which would otherwise make the frozen run (train call #1) and the
    % audit run (train call #2) diverge. After one warm-up call, train()
    % is deterministic w.r.t. the global RNG.
    warmupDeepLearning();

    % ---- frozen algorithm ----
    rng(seed,'twister');
    ProblemF = feval(problemName,'N',N,'M',M,'D',D, ...
        'maxFE',maxFE,'maxRuntime',inf);
    AlgF = feval('REMO_new2_AdaMaO_SDEOnly_UniformMix_Original', ...
        'parameter',{gmax,0.50,0.25,0.80,0.35,4,6}, ...
        'run',run,'save',0,'outputFcn',@silentOutput);
    try
        AlgF.Solve(ProblemF);
    catch err
        eq.message = sprintf('frozen run error: %s',err.message);
        return;
    end
    popF = AlgF.result{end,2};
    feF  = ProblemF.FE;

    % ---- audit Hybrid algorithm ----
    rng(seed,'twister');
    ProblemA = feval(problemName,'N',N,'M',M,'D',D, ...
        'maxFE',maxFE,'maxRuntime',inf);
    AlgA = feval('LVUniformMixAudit_Hybrid', ...
        'parameter',{gmax,0.50,0.25,0.80,0.35,4,6}, ...
        'run',run,'save',0,'outputFcn',@silentOutput);
    try
        AlgA.Solve(ProblemA);
    catch err
        eq.message = sprintf('audit run error: %s',err.message);
        return;
    end
    popA = AlgA.result{end,2};
    feA  = ProblemA.FE;

    eq.dFE = abs(feF-feA);
    if feF ~= feA
        eq.message = sprintf('FE differ: %d vs %d',feF,feA);
        return;
    end

    % ---- compare sorted final solutions ----
    try
        decF = sortrows([popF.objs,popF.decs]);
        decA = sortrows([popA.objs,popA.decs]);
    catch err
        eq.message = sprintf('sort error: %s',err.message);
        return;
    end
    if size(decF,1) ~= size(decA,1)
        eq.message = sprintf('population sizes differ: %d vs %d', ...
            size(decF,1),size(decA,1));
        return;
    end
    M_ = M;
    eq.maxAbsDiffObj = max(abs(decF(:,1:M_)-decA(:,1:M_)),[],'all');
    eq.maxAbsDiffDec = max(abs(decF(:,M_+1:end)-decA(:,M_+1:end)),[],'all');
    if eq.maxAbsDiffObj > 1e-12 || eq.maxAbsDiffDec > 1e-12
        eq.message = sprintf('trajectory mismatch: objDiff=%.3e decDiff=%.3e', ...
            eq.maxAbsDiffObj,eq.maxAbsDiffDec);
        return;
    end

    % ---- IGD / IGDp ----
    igdF  = ProblemF.CalMetric('IGD',popF);
    igdA  = ProblemA.CalMetric('IGD',popA);
    igdpF = ProblemF.CalMetric('IGDp',popF);
    igdpA = ProblemA.CalMetric('IGDp',popA);
    eq.dIGD  = abs(igdF-igdA);
    eq.dIGDp = abs(igdpF-igdpA);
    if eq.dIGD > 1e-12 || eq.dIGDp > 1e-12
        eq.message = sprintf('metric mismatch: dIGD=%.3e dIGDp=%.3e', ...
            eq.dIGD,eq.dIGDp);
        return;
    end

    eq.matched = true;
    eq.message = sprintf('matched (maxDiff dec=%.2e obj=%.2e)', ...
        eq.maxAbsDiffDec,eq.maxAbsDiffObj);
end

function silentOutput(varargin)
end

function warmupDeepLearning()
%warmupDeepLearning Fire one patternnet train() and one fitrsvm so that
%   toolbox initialization random consumption happens BEFORE the
%   experiment runs.
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
