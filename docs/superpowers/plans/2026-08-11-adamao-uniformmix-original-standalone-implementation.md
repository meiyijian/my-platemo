# UniformMix-OriginalRelation Standalone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original` into a self-contained PlatEMO algorithm directory with exactly seven GUI parameters and no weighted, curriculum, or adaptive relation-mode code.

**Architecture:** Add a direct `ALGORITHM` subclass in a new same-named directory. Keep the OriginalRelation data flow fixed to unweighted `GetRelationPairs` plus ordinary `DataProcess`, expose `pMix` and `rGood`, and place copied runtime helpers under the new directory's `private` folder so old algorithms retain their path resolution. Remove the old same-named entry only after the new entry exists and its path contract test passes.

**Tech Stack:** MATLAB/PlatEMO, `matlab.unittest`, MATLAB Code Analyzer, Git

---

## File map

Create the following files under:

```text
D:/PlatEMO-master/PlatEMO-master/PlatEMO/
Algorithms/Multi-objective optimization/
REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/
```

```text
REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m
ResolveUniformMixMode.m
private/AdaMaOSelection.m
private/DataProcess.m
private/GetOutput_PBI.m
private/GetRelationPairs.m
private/HybridPBI_Classification.m
private/IndicatorSelectorSDEOnly.m
private/RefSelect.m
private/Shape_Estimate.m
private/calFitness_SDE.m
private/CreateSDECandidateModeStream.m
private/onehotconv.m
tests/test_REMO_new2_AdaMaO_UniformMixOriginalStandalone.m
```

Modify these existing tests:

```text
Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_FixedRelationModes.m
Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_CascadeAudit.m
```

Delete only after the new entry is available:

```text
Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m
```

Do not modify the old `REMO_new2_AdaMaO_SDEOnly_UniformMix.m`, old `ModeBase`, old `RelationModeBase`, old operational private helpers, reports, or the existing untracked `notes` directory.

### Task 1: Add the standalone contract tests and verify RED

**Files:**

- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/tests/test_REMO_new2_AdaMaO_UniformMixOriginalStandalone.m`

- [ ] **Step 1: Write the failing test file**

The test suite must establish the desired public contract before any new production file exists:

```matlab
function tests = test_REMO_new2_AdaMaO_UniformMixOriginalStandalone
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile = mfilename('fullpath');
    testsDir = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    rehash;
    testCase.TestData.AlgorithmDir = algorithmDir;
end

function testEntryResolvesOnlyToStandaloneDirectory(testCase)
    name = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original';
    expected = fullfile(testCase.TestData.AlgorithmDir,[name,'.m']);
    verifyTrue(testCase,isfile(expected));
    verifyEqual(testCase,which(name),expected);

    legacy = fullfile(fileparts(testCase.TestData.AlgorithmDir),[name,'.m']);
    verifyFalse(testCase,isfile(legacy));
end

function testGuiParameterContractContainsOnlySevenActiveParameters(testCase)
    source = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m'));
    names = {'gmax','pMix','rGood','qKeep','lambda0','nMin','nMax'};
    defaults = {'3000','0.50','0.25','0.80','0.35','4','6'};
    for i = 1:numel(names)
        verifyTrue(testCase,contains(source,[names{i},' --- ',defaults{i}]));
    end
    verifyTrue(testCase,contains(source, ...
        'Algorithm.ParameterSet(3000,0.50,0.25,0.80,0.35,4,6)'));
    forbidden = {'w_min','tau_err','use_indicator','debug', ...
        'RelationModeBase','GetRelationPairs_confidence', ...
        'GetRelationPairs_curriculum','RuntimeDiagnostics'};
    for i = 1:numel(forbidden)
        verifyFalse(testCase,contains(source,forbidden{i}), ...
            sprintf('Removed token remains in entry: %s',forbidden{i}));
    end
end

function testStandaloneDependencyBoundary(testCase)
    root = testCase.TestData.AlgorithmDir;
    files = [dir(fullfile(root,'*.m')); ...
             dir(fullfile(root,'private','*.m'))];
    source = '';
    for i = 1:numel(files)
        source = [source,newline,fileread(fullfile(files(i).folder,files(i).name))]; %#ok<AGROW>
    end
    forbidden = {'RelationModeBase','GetRelationPairs_confidence', ...
        'GetRelationPairs_curriculum','DataProcess_confidence', ...
        'w_min','tau_err','use_indicator','prev_p_err', ...
        'RuntimeDiagnostics','KeepMostConfident'};
    for i = 1:numel(forbidden)
        verifyFalse(testCase,contains(source,forbidden{i}), ...
            sprintf('Forbidden dependency remains: %s',forbidden{i}));
    end
    verifyTrue(testCase,isfile(fullfile(root,'private','AdaMaOSelection.m')));
    verifyTrue(testCase,isfile(fullfile(root,'private','HybridPBI_Classification.m')));
    verifyTrue(testCase,isfile(fullfile(root,'private','IndicatorSelectorSDEOnly.m')));
end

function testUniformMixResolverUsesConfiguredProbability(testCase)
    [below,pBelow] = ResolveUniformMixMode(true,0.49,0.50);
    [boundary,pBoundary] = ResolveUniformMixMode(true,0.50,0.50);
    [zero,pZero] = ResolveUniformMixMode(true,0.99,0.00);
    [one,pOne] = ResolveUniformMixMode(true,0.00,1.00);
    [fallback,pFallback] = ResolveUniformMixMode(false,0.00,1.00);

    verifyEqual(testCase,below,'indicator');
    verifyEqual(testCase,boundary,'explore');
    verifyEqual(testCase,zero,'explore');
    verifyEqual(testCase,one,'indicator');
    verifyEqual(testCase,fallback,'explore');
    verifyEqual(testCase,[pBelow,pBoundary,pZero,pOne,pFallback], ...
        [0.50,0.50,0.00,1.00,1.00],'AbsTol',1e-12);
end

function testInvalidUniformMixProbabilityIsRejected(testCase)
    verifyError(testCase,@() ResolveUniformMixMode(true,0.2,-0.01), ...
        'AdaMaO:InvalidCandidateMixProbability');
    verifyError(testCase,@() ResolveUniformMixMode(true,0.2,1.01), ...
        'AdaMaO:InvalidCandidateMixProbability');
end

function testMainRejectsInvalidParameterConfiguration(testCase)
    algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Original( ...
        'parameter',{1,0.50,0.51,0.80,0.35,2,1}, ...
        'save',0,'outputFcn',@silentOutput,'run',1);
    problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',32,'maxRuntime',inf);
    verifyError(testCase,@() algorithm.Solve(problem), ...
        'AdaMaO:InvalidParameter');
end

function testHybridPbiUsesConfiguredPositiveGroupRatio(testCase)
    root = testCase.TestData.AlgorithmDir;
    addpath(fullfile(root,'private'));
    testCase.addTeardown(@() rmpath(fullfile(root,'private')));

    N = 20;
    D = 3;
    t = linspace(0.01,0.99,N)';
    PopDec = [t,1-t,0.5*ones(N,1)];
    PopObj = [t,1-t,0.25+0.5*t];
    Population = SOLUTION(PopDec,PopObj,zeros(N,1));

    [~,~,catalogQuarter] = HybridPBI_Classification( ...
        Population,0.5,'Nref',N,'k',6,'theta',5,'rGood',0.25);
    [~,~,catalogHalf] = HybridPBI_Classification( ...
        Population,0.5,'Nref',N,'k',6,'theta',5,'rGood',0.50);

    verifyEqual(testCase,nnz(catalogQuarter),ceil(N*0.25));
    verifyEqual(testCase,nnz(catalogHalf),ceil(N*0.50));
end

function testShortRunAcceptsSevenParameters(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Original( ...
        'parameter',{1,0.50,0.25,0.80,0.35,1,1}, ...
        'save',0,'outputFcn',@silentOutput,'run',1);
    problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',35,'maxRuntime',inf);
    rng(9001,'twister');
    algorithm.Solve(problem);

    verifyEqual(testCase,problem.FE,35);
    verifyNotEmpty(testCase,algorithm.result);
end

function silentOutput(varargin)
end
```

The `files` expression above is intentionally restricted to the new root and
its private directory; it does not inspect the test file or the old mixed
directory. The new entry must avoid the forbidden tokens even in comments so
the boundary test remains meaningful.

- [ ] **Step 2: Run the focused suite to verify RED**

Run from `D:\PlatEMO-master\PlatEMO-master\PlatEMO`:

```powershell
matlab -batch "f=fullfile(pwd,'Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','tests','test_REMO_new2_AdaMaO_UniformMixOriginalStandalone.m'); r=runtests(f); disp(r); assert(all([r.Passed]));"
```

Expected: non-zero exit because the new directory, resolver, and standalone
entry do not exist. If the test file has a syntax error, fix the test first and
rerun until the failure is caused by the missing implementation or missing
path contract.

### Task 2: Implement the standalone entry and UniformMix resolver

**Files:**

- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/ResolveUniformMixMode.m`

- [ ] **Step 1: Add the PlatEMO header and seven-parameter interface**

The entry must begin with this class/header and parameter call:

```matlab
classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Original < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% UniformMix with original unweighted relation-network training
% gmax   --- 3000 --- Maximum surrogate-assisted training generations
% pMix   --- 0.50 --- Probability of using indicator-based selection
% rGood  --- 0.25 --- Proportion of solutions assigned to the positive group
% qKeep  --- 0.80 --- Proportion retained during exploratory selection
% lambda0 --- 0.35 --- Initial exploration strength
% nMin   --- 4    --- Minimum number of candidate solutions
% nMax   --- 6    --- Maximum number of candidate solutions

    methods
        function main(Algorithm,Problem)
            [gmax,pMix,rGood,qKeep,lambda0,nMin,nMax] = ...
                Algorithm.ParameterSet(3000,0.50,0.25,0.80,0.35,4,6);
            validateUniformMixParameters( ...
                gmax,pMix,rGood,qKeep,lambda0,nMin,nMax);
```

Use the current `REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m` as
the operational template for initialization, archive handling, candidate
generation, and fallback, but implement the fixed OriginalRelation data flow
directly in this class instead of subclassing that base. The exact fixed core
must be:

```matlab
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            InitFE = Problem.FE;
            Archive = Population;

            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp = 1;

            while Algorithm.NotTerminated(Archive)
                u = rand(modeStream,1);
                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                [~,~,Catalog,~,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff, ...
                    'theta',5,'rGood',rGood);

                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    continue;
                end

                [net,TrainIn_struct,p_err] = ...
                    TrainOriginalRelationModel(XXs,YYs);

                IndicatorModel = [];
                Fitness = [];
                try
                    [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp);
                catch
                    Fitness = [];
                end
                if ~isempty(Fitness)
                    try
                        IndicatorModel = fitrsvm(Population.decs,Fitness, ...
                            'KernelFunction','rbf', ...
                            'KernelScale','auto','Standardize',true);
                    catch
                        IndicatorModel = [];
                    end
                end

                candidate_mode = ResolveUniformMixMode( ...
                    ~isempty(IndicatorModel),u,pMix);
```

`TrainOriginalRelationModel` may be a local function at the end of the entry;
it must call `DataProcess`, `mapminmax`, `onehotconv`, `patternnet`, and
`train` exactly as the existing ordinary branch does, and compute `p_err`
from the held-out set. It must not accept `WWs`, `w_min`, or `use_weights`.

- [ ] **Step 2: Complete the unchanged selection/fallback block**

Build `Smodel` with exactly these fields:

```matlab
                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                Smodel.lambda0 = lambda0;
                Smodel.ratio = ratio;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode = candidate_mode;
                Smodel.q_keep = qKeep;
                Smodel.n_min = nMin;
                Smodel.n_max = nMax;

                Next = AdaMaOSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    qKeep,nMin,nMax);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = Next(1:min(nMin,size(Next,1)),:);
                end
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end
```

Do not reintroduce the old debug print, relation-mode switch, diagnostics,
curriculum filter, or `prev_p_err` state. Keep the generation-level `rand`
draw before the PBI calculation so default mode-stream consumption remains
paired with the existing OriginalRelation trajectory.

- [ ] **Step 3: Add explicit parameter validation**

Add this local function after the class definition:

```matlab
function validateUniformMixParameters(gmax,pMix,rGood,qKeep,lambda0,nMin,nMax)
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('AdaMaO:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(pMix) || ~isscalar(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('AdaMaO:InvalidParameter', ...
            'pMix must be in [0,1].');
    end
    if ~isnumeric(rGood) || ~isscalar(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('AdaMaO:InvalidParameter', ...
            'rGood must be in (0,0.5].');
    end
    if ~isnumeric(qKeep) || ~isscalar(qKeep) || ~isfinite(qKeep) || ...
            qKeep < 0 || qKeep > 1
        error('AdaMaO:InvalidParameter', ...
            'qKeep must be in [0,1].');
    end
    if ~isnumeric(lambda0) || ~isscalar(lambda0) || ~isfinite(lambda0) || ...
            lambda0 < 0
        error('AdaMaO:InvalidParameter', ...
            'lambda0 must be nonnegative.');
    end
    if ~isnumeric(nMin) || ~isscalar(nMin) || ~isfinite(nMin) || ...
            nMin < 1 || nMin ~= floor(nMin)
        error('AdaMaO:InvalidParameter', ...
            'nMin must be a positive integer.');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('AdaMaO:InvalidParameter', ...
            'nMax must be a positive integer.');
    end
    if nMin > nMax
        error('AdaMaO:InvalidParameter', ...
            'nMin must not exceed nMax.');
    end
end
```

- [ ] **Step 4: Add the unique UniformMix resolver**

Create `ResolveUniformMixMode.m` with this complete behavior:

```matlab
function [mode,pInd] = ResolveUniformMixMode(indicatorAvailable,u,pMix)
    if ~isscalar(pMix) || ~isnumeric(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('AdaMaO:InvalidCandidateMixProbability', ...
            'pMix must be a finite scalar in [0,1].');
    end
    if ~isscalar(u) || ~isnumeric(u) || ~isfinite(u) || u < 0 || u >= 1
        error('AdaMaO:InvalidCandidateModeDraw', ...
            'The candidate-mode draw must be a finite scalar in [0,1).');
    end
    if ~isscalar(indicatorAvailable) || ~logical(indicatorAvailable)
        indicatorAvailable = false;
    end
    pInd = pMix;
    mode = 'explore';
    if indicatorAvailable && u < pMix
        mode = 'indicator';
    end
end
```

- [ ] **Step 5: Run the resolver and contract tests**

Run the focused suite again. Expected at this checkpoint: resolver tests pass,
but dependency and short-run tests may still fail until the copied private
helpers and HybridPBI change are complete. Do not move to the next task while
the test file has MATLAB syntax errors.

### Task 3: Add the private runtime dependency closure and the rGood change

**Files:**

- Create exact operational copies under the new `private` directory:
  `AdaMaOSelection.m`, `DataProcess.m`, `GetOutput_PBI.m`, `GetRelationPairs.m`,
  `IndicatorSelectorSDEOnly.m`, `RefSelect.m`, `Shape_Estimate.m`,
  `calFitness_SDE.m`, `CreateSDECandidateModeStream.m`, and `onehotconv.m`.
- Create modified: `private/HybridPBI_Classification.m`.

- [ ] **Step 1: Add the copied helpers without changing their behavior**

Use the current files as exact sources:

```text
old/private/AdaMaOSelection.m                 -> new/private/AdaMaOSelection.m
old/private/DataProcess.m                     -> new/private/DataProcess.m
old/private/GetOutput_PBI.m                   -> new/private/GetOutput_PBI.m
old/private/GetRelationPairs.m                -> new/private/GetRelationPairs.m
old/IndicatorSelectorSDEOnly.m                -> new/private/IndicatorSelectorSDEOnly.m
old/private/RefSelect.m                       -> new/private/RefSelect.m
old/private/Shape_Estimate.m                  -> new/private/Shape_Estimate.m
old/private/calFitness_SDE.m                  -> new/private/calFitness_SDE.m
old/CreateSDECandidateModeStream.m            -> new/private/CreateSDECandidateModeStream.m
old/private/onehotconv.m                      -> new/private/onehotconv.m
```

The copied `IndicatorSelectorSDEOnly` must resolve `Shape_Estimate` and
`calFitness_SDE` from the same new private directory. The copied mode stream
must retain the existing seed rule and must not touch MATLAB's global RNG.

- [ ] **Step 2: Make only the positive-group ratio configurable in HybridPBI**

Change the new private copy's option documentation and parsing to add:

```matlab
rGood = get_option(varargin,'rGood',0.25);
if ~isscalar(rGood) || ~isnumeric(rGood) || ~isfinite(rGood) || ...
        rGood <= 0 || rGood > 0.5
    error('AdaMaO:InvalidPositiveGroupRatio', ...
        'rGood must be a finite scalar in (0,0.5].');
end
```

Replace only the hard-coded group count:

```matlab
good_num = ceil(N/4);
```

with:

```matlab
good_num = ceil(N*rGood);
```

Keep `theta` as an internal option with default `5`, keep the adaptive
reference-vector branch unchanged, and leave the old mixed-directory
`HybridPBI_Classification.m` untouched. Update comments in the new copy from
`N/4` to `N*rGood` so documentation matches behavior.

- [ ] **Step 3: Replace the temporary original training call with a local ordinary trainer**

The local `TrainOriginalRelationModel` in the new entry must use this exact
ordinary branch shape:

```matlab
function [net,TrainIn_struct,p_err] = TrainOriginalRelationModel(XXs,YYs)
    [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');

    if isempty(TestIn)
        p_err = 1;
    else
        TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
        TestPre = onehotconv(net(TestIn_nor')',2);
        p_err = sum(TestPre ~= TestOut) / size(TestPre,1);
    end
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
end
```

The helper must be placed after the class definition in the same entry file,
so it resolves the new private `DataProcess` and `onehotconv` functions.

- [ ] **Step 4: Run the focused tests and verify GREEN for the contract**

Run:

```powershell
matlab -batch "f=fullfile(pwd,'Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','tests','test_REMO_new2_AdaMaO_UniformMixOriginalStandalone.m'); r=runtests(f); disp(r); assert(all([r.Passed]));"
```

Expected: all standalone contract tests pass. If the short run fails in a
runtime dependency, first identify whether the missing symbol is a framework
function or a missing file from the explicit closure above; do not add the old
mixed directory as a runtime dependency.

### Task 4: Remove the legacy duplicate and update regression tests

**Files:**

- Delete: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m`
- Modify: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_FixedRelationModes.m`
- Modify: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_CascadeAudit.m`

- [ ] **Step 1: Delete only the legacy same-named entry**

Use `apply_patch` to delete the old thin subclass after the new standalone
entry and focused contract test are green. Do not delete the old relation-mode
base or the weighted/curriculum entries; other experiments still use them.

- [ ] **Step 2: Update the fixed-mode discoverability test**

Keep the weighted and curriculum entries mapped to the old relation-mode base.
Replace the original entry assertion with:

```matlab
originalName = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original';
standaloneDir = fullfile(fileparts(testCase.TestData.AlgorithmDir), ...
    originalName);
originalFile = fullfile(standaloneDir,[originalName,'.m']);
verifyTrue(testCase,isfile(originalFile));
verifyEqual(testCase,which(originalName),originalFile);
originalSource = fileread(originalFile);
verifyTrue(testCase,contains(originalSource,'< ALGORITHM'));
verifyFalse(testCase,contains(originalSource, ...
    'UniformMix_RelationModeBase'));
```

Remove the old test's expectation that the Original entry contains a
`relationPairMode` method returning `conservative`; the standalone entry fixes
the data flow directly.

- [ ] **Step 3: Update CascadeAudit's operational reference construction**

In `test_REMO_new2_AdaMaO_CascadeAudit.m`:

1. Remove only the old `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m` item
   and its expected hash from `testFrozenOperationalSourcesKeepTheirGitBlobs`.
2. Replace both `parameters(1:10)` calls in `makeOriginalRun` and
   `makeWarmupRun` with `originalParameters()`.
3. Add this helper near `auditParameters`:

```matlab
function parameters = originalParameters()
    parameters = {1,[],[],[],[],1,1};
end
```

This maps `gmax=1`, default `pMix=0.50`, default `rGood=0.25`, default
`qKeep=0.80`, default `lambda0=0.35`, and `nMin=nMax=1`, matching the old
audit run's effective settings without accidentally mapping old `gmax=1` into
the new `pMix` slot.

- [ ] **Step 4: Run the updated fixed-mode and CascadeAudit tests**

Run the two focused files separately:

```powershell
matlab -batch "f=fullfile(pwd,'Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_FixedRelationModes.m'); r=runtests(f); disp(r); assert(all([r.Passed]));"
matlab -batch "f=fullfile(pwd,'Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_CascadeAudit.m'); r=runtests(f); disp(r); assert(all([r.Passed]));"
```

Expected: fixed-mode discoverability passes; CascadeAudit's operational
trajectory comparison passes with the new seven-parameter entry, including
equal final FE and equal global RNG state. If the trajectories differ, compare
the first differing stage in this order: initialization, mode-stream draw,
`HybridPBI` Catalog, relation-pair training, candidate mode, and archive update.

### Task 5: Run static checks, short integration checks, and the affected suite

**Files:**

- Verify all new production files and the two modified tests.

- [ ] **Step 1: Check path uniqueness and dependency boundary**

Run:

```powershell
matlab -batch "root=fullfile(pwd,'Algorithms','Multi-objective optimization'); addpath(genpath(fileparts(fileparts(root)))); rehash; n='REMO_new2_AdaMaO_SDEOnly_UniformMix_Original'; p=which(n); expected=fullfile(root,n,[n,'.m']); assert(strcmp(p,expected)); assert(~isfile(fullfile(root,'REMO_new2_AdaMaO_SDEOnly',[n,'.m']))); disp(p);"
```

Expected: one path, pointing to the new standalone directory.

- [ ] **Step 2: Run Code Analyzer on new and modified MATLAB files**

Run:

```powershell
matlab -batch "root=fullfile(pwd,'Algorithms','Multi-objective optimization'); files={fullfile(root,'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m'),fullfile(root,'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','ResolveUniformMixMode.m'),fullfile(root,'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','tests','test_REMO_new2_AdaMaO_UniformMixOriginalStandalone.m'),fullfile(root,'REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_FixedRelationModes.m'),fullfile(root,'REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_CascadeAudit.m')}; files=[files,cellstr(string(fullfile(root,'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','private','*.m')))]; total=0; for i=1:numel(files), if contains(files{i},'*'), d=dir(files{i}); targets=fullfile({d.folder},{d.name}); else, targets={files{i}}; end; for j=1:numel(targets), q=checkcode(targets{j},'-id'); total=total+numel(q); for k=1:numel(q), fprintf('%s:%d %s %s\n',targets{j},q(k).line,q(k).id,q(k).message); end; end; end; fprintf('CHECKCODE_TOTAL=%d\n',total); assert(total==0);"
```

Expected: `CHECKCODE_TOTAL=0`. Warnings that are already present in copied
legacy helper code must be fixed in the new copy if they are reported by the
new-file check; do not edit the old helper solely to silence a warning.

- [ ] **Step 3: Run the affected test files and a short PlatEMO smoke run**

Run the standalone suite, fixed relation-mode suite, SDEOnly discoverability
suite, and CascadeAudit suite. Then run the direct short smoke command from
Task 1 once more. Every command must report zero failed and zero incomplete
tests; the smoke run must finish at `Problem.FE=35`.

- [ ] **Step 4: Inspect the final diff and preserve unrelated changes**

Run:

```powershell
git -C D:\PlatEMO-master status --short
git -C D:\PlatEMO-master diff --check
git -C D:\PlatEMO-master diff --stat
git -C D:\PlatEMO-master diff -- "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly" "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original"
```

The diff must contain only the new standalone implementation, the intentional
legacy-entry deletion, and the two regression-test updates. The pre-existing
`.workbuddy/memory` modifications and untracked `notes` directory must remain
unstaged.

### Task 6: Commit the verified migration

**Files:**

- Commit only the new standalone directory, the legacy-entry deletion, and
  the two updated tests.

- [ ] **Step 1: Stage the exact implementation paths**

```powershell
git -C D:/PlatEMO-master add -- `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original" `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m" `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_FixedRelationModes.m" `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_CascadeAudit.m"
```

- [ ] **Step 2: Verify the staged diff**

```powershell
git -C D:\PlatEMO-master diff --cached --check
git -C D:\PlatEMO-master diff --cached --stat
```

Expected: no whitespace errors and no staged `.workbuddy` or `notes` files.

- [ ] **Step 3: Commit after all fresh verification commands pass**

```powershell
git -C D:\PlatEMO-master commit -m "feat: add standalone UniformMix OriginalRelation"
```

After the commit, re-run `git status --short` and report the commit hash,
verification counts, and any unrelated pre-existing dirty files left untouched.
