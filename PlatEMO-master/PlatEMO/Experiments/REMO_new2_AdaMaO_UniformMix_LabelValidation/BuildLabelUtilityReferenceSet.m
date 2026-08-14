function ref = BuildLabelUtilityReferenceSet(problem, M, profile, varargin)
%BuildLabelUtilityReferenceSet Build and cache the independent PF reference
%   sets R4096/R8192 (+R16384 if requested) with the fixed zmin/scale
%   normalization (Stage-3 plan §4).
%
%   ref = BuildLabelUtilityReferenceSet(problem, M, profile)
%   returns a struct with fields:
%     problem, M, requestedD, actualD, referenceSeed,
%     R4096, R8192, R16384 (only when with16384), zmin, scale,
%     actualRows4096, actualRows8192, actualRows16384,
%     builderVersion, sourceClassHash
%
%   NESTING (plan §4.1): R8192 is a PREFIX of the master set Rmaster that
%   also contains R4096, so the sensitivity analysis only adds reference
%   points and never draws an independent second sample:
%       Rmaster = Problem.GetOptimum(16384)     (DTLZ7: dedicated Rmaster)
%       R4096 = Rmaster(1:4096,:)
%       R8192 = Rmaster(1:8192,:)
%   The actual returned row count is recorded (UniformPoint may differ
%   from the requested count); a guard asserts it never exceeds 20000.
%
%   Cache: results/stage3/<profile>/reference/<Problem>_M<M>_ref.mat
%   The same Problem/M combination is shared by all behaviors, runs and
%   snapshots of that profile.
%
%   Optional name-value:
%     'with16384', bool   also return R16384 (default false)
%     'force', bool       ignore cache and rebuild (default false)

    p = inputParser;
    addParameter(p,'with16384',false,@islogical);
    addParameter(p,'force',false,@islogical);
    parse(p,varargin{:});

    builderVersion = 2;   % v2: nested-prefix construction

    expDir = fileparts(mfilename('fullpath'));
    refDir = fullfile(expDir,'results','stage3',profile,'reference');
    if ~exist(refDir,'dir'), mkdir(refDir); end
    cacheFile = fullfile(refDir,sprintf('%s_M%d_ref.mat',problem,M));

    % ---- cache hit ----
    if isfile(cacheFile) && ~p.Results.force
        c = load(cacheFile);
        if isfield(c,'ref') && isfield(c.ref,'builderVersion') && ...
                c.ref.builderVersion == builderVersion
            ref = c.ref;
            if p.Results.with16384 && ~isfield(ref,'R16384')
                ref.R16384 = build16384(ref,problem,M);
                ref.actualRows16384 = size(ref.R16384,1);
                persist(ref,cacheFile);
            end
            return;
        end
    end

    % ---- frozen problem construction (same as Stage-1 runner) ----
    Problem = feval(problem,'N',100,'M',M,'D',30,'maxFE',500, ...
        'maxRuntime',inf);
    actualD = Problem.D;
    sourceClassHash = LVHashString(class(Problem));

    referenceSeed = 20260811 + problemIndex(problem)*100 + M;

    % ---- build Rmaster (16384-targeted) ----
    if strcmp(problem,'DTLZ7')
        % bounded dedicated construction (plan §4.1)
        saved = rng;
        rng(referenceSeed,'twister');
        U = UniformPoint(16384,M-1,'Latin');
        interval = [0,0.251412,0.631627,0.859401];
        median = (interval(2)-interval(1)) / ...
            (interval(4)-interval(3)+interval(2)-interval(1));
        X = U;
        X(U<=median) = U(U<=median)*(interval(2)-interval(1))/median ...
            + interval(1);
        X(U>median) = (U(U>median)-median)* ...
            (interval(4)-interval(3))/(1-median) + interval(3);
        Rmaster = [X,2*(M-sum(X/2.*(1+sin(3*pi*X)),2))];
        rng(saved);
        assert(size(Rmaster,2)==M, ...
            'DTLZ7 Rmaster cols %d ~= M %d',size(Rmaster,2),M);
    else
        Rmaster = Problem.GetOptimum(16384);
        assert(size(Rmaster,2)==M,'%s Rmaster cols %d ~= M %d',problem,size(Rmaster,2),M);
    end

    nM = size(Rmaster,1);
    assert(nM <= 20000,'REFERENCE_SIZE_OVERFLOW', ...
        'reference row count %d > 20000',nM);
    assert(nM >= 8192, ...
        'REFERENCE_UNDERSIZED','%s M%d master has %d rows < 8192', ...
        problem,M,nM);

    % ---- nested prefixes ----
    R4096 = Rmaster(1:4096,:);
    R8192 = Rmaster(1:8192,:);
    actualRows4096 = 4096;
    actualRows8192 = 8192;

    if ~all(isfinite(R4096(:))) || ~all(isfinite(R8192(:)))
        error('BuildLabelUtilityReferenceSet:NonFinite', ...
            'reference set contains non-finite values (%s M%d)',problem,M);
    end

    % ---- fixed normalization on R4096 (plan §4.2) ----
    zmin  = min(R4096,[],1);
    zmax  = max(R4096,[],1);
    scale = zmax - zmin;
    constant = scale < 1e-12;
    scale(constant) = max(abs(zmax(constant)),1);
    if any(scale < 1e-12)
        error('BuildLabelUtilityReferenceSet:ZeroScale', ...
            'normalization scale still < 1e-12 after guard');
    end

    ref = struct( ...
        'problem',problem,'M',M,'requestedD',30,'actualD',actualD, ...
        'referenceSeed',referenceSeed, ...
        'R4096',R4096,'R8192',R8192, ...
        'zmin',zmin,'scale',scale, ...
        'actualRows4096',actualRows4096,'actualRows8192',actualRows8192, ...
        'builderVersion',builderVersion, ...
        'sourceClassHash',sourceClassHash);

    if p.Results.with16384
        ref.R16384 = build16384(ref,problem,M);
        ref.actualRows16384 = size(ref.R16384,1);
    end

    persist(ref,cacheFile);
end

%% ============ R16384 (nested prefix of the same master) ============
function R = build16384(ref,problem,M)
    if strcmp(problem,'DTLZ7')
        % Rmaster prefix: reproduce deterministically from seed
        saved = rng;
        rng(ref.referenceSeed,'twister');
        U = UniformPoint(16384,M-1,'Latin');
        interval = [0,0.251412,0.631627,0.859401];
        median = (interval(2)-interval(1)) / ...
            (interval(4)-interval(3)+interval(2)-interval(1));
        X = U;
        X(U<=median) = U(U<=median)*(interval(2)-interval(1))/median ...
            + interval(1);
        X(U>median) = (U(U>median)-median)* ...
            (interval(4)-interval(3))/(1-median) + interval(3);
        R = [X,2*(M-sum(X/2.*(1+sin(3*pi*X)),2))];
        rng(saved);
        assert(size(R,2)==M,'DTLZ7 R16384 cols mismatch');
        return;
    end
    Problem = feval(problem,'N',100,'M',M,'D',30,'maxFE',500, ...
        'maxRuntime',inf);
    R = Problem.GetOptimum(16384);
    assert(size(R,2)==M,'R16384 cols %d ~= M %d',size(R,2),M);
    assert(size(R,1) <= 20000,'REFERENCE_SIZE_OVERFLOW');
end

%% ============ persistence ============
function persist(ref,cacheFile)
    save(cacheFile,'ref');
end

%% ============ problem index (frozen order, plan §2) ============
function idx = problemIndex(name)
    list = {'DTLZ2','DTLZ4','DTLZ7','WFG3','WFG7'};
    idx = find(strcmp(list,name),1);
    if isempty(idx), idx = 0; end
end
