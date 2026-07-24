# AdaMaO Continuous Dual-PBI H-A/C-A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve H-A byte-for-byte and correct C-A so that its only algorithmic change is replacing the representative-solution binary PBI label with the approved same-scale continuous PBI score, while adding non-perturbing mechanism diagnostics for H/C/G/R snapshots.

**Architecture:** Keep `REMO_new2_AdaMaO_SDEOnly_UniformMix` and its baseline helpers frozen. C-A continues to use its existing parallel runtime class, but `DualPBIContinuousSupervision` independently reproduces H-A's direction-field and representative-selection path and changes only the representative branch. A pure continuous representative-PBI function owns that geometry. Public snapshot and probe utilities sit outside the optimizer call graph; they can access the private H-A functions because they live in the algorithm parent directory, restore the global RNG after every capture, and never call `Problem.Evaluation`.

**Tech Stack:** MATLAB R2020b+, PlatEMO, MATLAB Unit Test framework, Statistics and Machine Learning Toolbox, Deep Learning Toolbox, Git.

---

## Working directory and frozen scope

Run MATLAB commands from:

`D:\PlatEMO-master\PlatEMO-master\PlatEMO`

Run Git commands from:

`D:\PlatEMO-master`

The approved design is:

`D:\PlatEMO-master\docs\superpowers\specs\2026-07-24-adamao-continuous-dual-pbi-design.md`

This plan implements formula correctness, H-A/C-A isolation, snapshot diagnostics, and minimum smoke validation. It does **not**:

- modify H-A;
- tune `theta=5`;
- restore or retune `delta`;
- change hard relation targets `{-1,0,+1}`;
- run C-U/C-F/C-W comparisons;
- run formal performance experiments;
- choose the formal problem set, seeds, budget, or statistical gate.

The existing C-U/C-F/C-W entry files remain untouched. Because they inherit the same continuous supervisor, correcting that shared supervisor also corrects their dormant score definition, but they are not executed or interpreted in this phase.

## Frozen H-A blob manifest

These Git blob hashes are part of the implementation acceptance test:

| H-A file | Git blob hash |
|---|---|
| `REMO_new2_AdaMaO_SDEOnly_UniformMix.m` | `523deb264424909d84334bdeacf81377352eca8a` |
| `REMO_new2_AdaMaO_SDEOnly_ModeBase.m` | `411a828ae68111e4ede67709386832624d4c38a4` |
| `private/HybridPBI_Classification.m` | `342658c826e2f1f96937f1d300896b14331d2e2d` |
| `private/GetOutput_PBI.m` | `de30b2e915908e6d205134168a0cf87894a97cb9` |
| `private/RefSelect.m` | `241e8940b34b1c1c8cdc092d1db3cecf9407bb86` |

Relevant baseline source anchors:

- Direction-field generation and score: `private/HybridPBI_Classification.m:43-84`
- Representative selection and binary branch: `private/HybridPBI_Classification.m:53-101`
- Adaptive direction implementation to copy exactly: `private/HybridPBI_Classification.m:141-219`
- Original `delta` and `/normR` binary threshold: `private/GetOutput_PBI.m:52-75,95-132`
- H-A runtime call and adaptive relation controller: `REMO_new2_AdaMaO_SDEOnly_ModeBase.m:42-72`
- C-A runtime call and equivalent controller: `REMO_new2_AdaMaO_SDEOnly_DualPBIContModeBase.m:42-68,153-168`

### Task 1: Lock H-A and implement the pure representative-solution continuous PBI

**Files:**

- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/ComputeReferencePBIContinuousScore.m`
- Do not modify: the five H-A files in the frozen manifest

- [ ] **Step 1: Create the test harness and baseline blob guard**

Start the new function-based test file with:

```matlab
function tests = test_REMO_new2_AdaMaO_ContinuousDualPBI
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile     = mfilename('fullpath');
    testsDir     = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot  = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    rehash;
    testCase.TestData.AlgorithmDir = algorithmDir;
end

function testHardBaselineBlobsAreFrozen(testCase)
    files = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix.m'; ...
        'REMO_new2_AdaMaO_SDEOnly_ModeBase.m'; ...
        fullfile('private','HybridPBI_Classification.m'); ...
        fullfile('private','GetOutput_PBI.m'); ...
        fullfile('private','RefSelect.m')};
    expected = { ...
        '523deb264424909d84334bdeacf81377352eca8a'; ...
        '411a828ae68111e4ede67709386832624d4c38a4'; ...
        '342658c826e2f1f96937f1d300896b14331d2e2d'; ...
        'de30b2e915908e6d205134168a0cf87894a97cb9'; ...
        '241e8940b34b1c1c8cdc092d1db3cecf9407bb86'};

    prefixCommand = sprintf('git -C "%s" rev-parse --show-prefix', ...
        testCase.TestData.AlgorithmDir);
    [prefixStatus,repoPrefix] = system(prefixCommand);
    verifyEqual(testCase,prefixStatus,0);
    repoPrefix = strtrim(repoPrefix);

    for i = 1:numel(files)
        file = fullfile(testCase.TestData.AlgorithmDir,files{i});
        repoPath = [repoPrefix,strrep(files{i},'\','/')];
        command = sprintf(['git -C "%s" hash-object --path="%s" ', ...
            '"%s"'],testCase.TestData.AlgorithmDir,repoPath,file);
        [status,blob] = system(command);
        verifyEqual(testCase,status,0);
        verifyEqual(testCase,strtrim(blob),expected{i}, ...
            sprintf('Frozen H-A file changed: %s',files{i}));
    end
end
```

- [ ] **Step 2: Add formula, scale, fallback, and RNG tests**

Append these tests. The manual calculation deliberately uses raw objectives, raw-reference cosine association, the common ideal point, the same `theta`, and no `/normR`.

```matlab
function testReferenceScoreMatchesApprovedFormula(testCase)
    PopObj = [0.20 0.90; 0.45 0.65; 0.70 0.35; 0.90 0.20];
    RefObj = [0.20 0.90; 0.90 0.20];
    theta = 5;
    fallback = [0.11;0.22;0.33;0.44];

    [score,detail] = ComputeReferencePBIContinuousScore( ...
        PopObj,RefObj,theta,fallback);

    z = min(PopObj,[],1);
    W = RefObj-z;
    W = W./vecnorm(W,2,2);
    [~,assigned] = max(1-pdist2(PopObj,RefObj,'cosine'),[],2);
    assignedW = W(assigned,:);
    shifted = PopObj-z;
    d1 = sum(shifted.*assignedW,2);
    projection = z+d1.*assignedW;
    d2 = vecnorm(PopObj-projection,2,2);
    expectedPBI = d1+theta*d2;
    expectedScore = 1./(1+expectedPBI);

    verifyEqual(testCase,score,expectedScore,'AbsTol',1e-12);
    verifyEqual(testCase,detail.pbi,expectedPBI,'AbsTol',1e-12);
    verifyEqual(testCase,detail.assignedReference,assigned);
    verifyFalse(testCase,detail.fallbackUsed);
end

function testReferenceMagnitudeDoesNotRescalePBI(testCase)
    PopObj = [0 1; 1 0; 0.25 0.75; 0.75 0.25];
    RefA = [0 2; 2 0];
    RefB = 3*RefA;
    fallback = 0.5*ones(size(PopObj,1),1);

    scoreA = ComputeReferencePBIContinuousScore(PopObj,RefA,5,fallback);
    scoreB = ComputeReferencePBIContinuousScore(PopObj,RefB,5,fallback);

    verifyEqual(testCase,scoreA,scoreB,'AbsTol',1e-12, ...
        'Reference magnitude must not act like the removed normR divisor.');
end

function testAllZeroReferenceDirectionsUseGlobalFallback(testCase)
    PopObj = [1 3; 2 2; 3 1];
    RefObj = repmat(min(PopObj,[],1),2,1);
    fallback = [0.2;0.4;0.6];

    [score,detail] = ComputeReferencePBIContinuousScore( ...
        PopObj,RefObj,5,fallback);

    verifyEqual(testCase,score,fallback,'AbsTol',0);
    verifyTrue(testCase,detail.fallbackUsed);
    verifyEmpty(testCase,detail.pbi);
    verifyEqual(testCase,detail.validReferenceMask,[false;false]);
end

function testReferenceScoreDoesNotAdvanceGlobalRng(testCase)
    PopObj = [1 4; 2 3; 3 2; 4 1];
    RefObj = PopObj([1 4],:);
    fallback = 0.5*ones(4,1);

    rng(412,'twister');
    before = rng;
    ComputeReferencePBIContinuousScore(PopObj,RefObj,5,fallback);
    after = rng;

    verifyEqual(testCase,after,before);
end
```

- [ ] **Step 3: Run the focused test and verify RED**

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "results=runtests('Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'); assertSuccess(results)"
```

Expected: the hash guard passes and the formula tests fail because `ComputeReferencePBIContinuousScore` does not exist.

- [ ] **Step 4: Implement the pure representative-view score**

Create `ComputeReferencePBIContinuousScore.m` with this implementation:

```matlab
function [scoreRef,detail] = ComputeReferencePBIContinuousScore( ...
    PopObj,RefObj,theta,fallbackScore)
%ComputeReferencePBIContinuousScore Continuous PBI around representative solutions.

    validateInputs(PopObj,RefObj,theta,fallbackScore);

    N = size(PopObj,1);
    zmin = min(PopObj,[],1);
    referenceDirections = RefObj-zmin;
    referenceNorm = vecnorm(referenceDirections,2,2);
    validMask = referenceNorm > 0;

    detail = struct();
    detail.validReferenceMask = validMask;
    detail.fallbackUsed = ~any(validMask);
    detail.assignedReference = zeros(N,1);
    detail.d1 = [];
    detail.d2 = [];
    detail.pbi = [];

    if detail.fallbackUsed
        scoreRef = fallbackScore(:);
        return;
    end

    validIndex = find(validMask);
    validRef = RefObj(validMask,:);
    W = referenceDirections(validMask,:)./referenceNorm(validMask);

    cosine = 1-pdist2(PopObj,validRef,'cosine');
    [~,assignedValid] = max(cosine,[],2);
    assignedW = W(assignedValid,:);

    shifted = PopObj-zmin;
    d1 = sum(shifted.*assignedW,2);
    projection = zmin+d1.*assignedW;
    d2 = vecnorm(PopObj-projection,2,2);
    pbi = d1+theta*d2;
    scoreRef = 1./(1+pbi);

    detail.assignedReference = validIndex(assignedValid);
    detail.d1 = d1;
    detail.d2 = d2;
    detail.pbi = pbi;
end

function validateInputs(PopObj,RefObj,theta,fallbackScore)
    validPopulation = isnumeric(PopObj) && isreal(PopObj) && ...
        ismatrix(PopObj) && ~isempty(PopObj) && size(PopObj,2) >= 1 && ...
        all(isfinite(PopObj(:)));
    if ~validPopulation
        error('AdaMaO:InvalidReferencePBIInput', ...
            'PopObj must be a nonempty finite real matrix.');
    end

    validReference = isnumeric(RefObj) && isreal(RefObj) && ...
        ismatrix(RefObj) && size(RefObj,2) == size(PopObj,2) && ...
        all(isfinite(RefObj(:)));
    if ~validReference
        error('AdaMaO:InvalidReferencePBIDimensions', ...
            'RefObj must be finite and have the same objective count.');
    end

    validTheta = isnumeric(theta) && isreal(theta) && isscalar(theta) && ...
        isfinite(theta) && theta >= 0;
    validFallback = isnumeric(fallbackScore) && isreal(fallbackScore) && ...
        isequal(size(fallbackScore),[size(PopObj,1),1]) && ...
        all(isfinite(fallbackScore(:)));
    if ~validTheta || ~validFallback
        error('AdaMaO:InvalidReferencePBIParameter', ...
            'theta and fallbackScore must be finite and dimensionally valid.');
    end
end
```

Do not call `GetOutput_PBI`, divide by a representative norm, rank-transform the result, normalize objectives, or introduce a second penalty coefficient.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the same focused command. Expected: all tests currently in the file pass.

- [ ] **Step 6: Commit the pure geometry and tests**

```powershell
git -C 'D:\PlatEMO-master' add -- 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/ComputeReferencePBIContinuousScore.m' 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'
git -C 'D:\PlatEMO-master' commit -m "test: specify continuous representative PBI"
```

### Task 2: Replace the temporary C-A supervisor with the approved continuous dual PBI

**Files:**

- Modify: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/DualPBIContinuousSupervision.m:1-26`
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m`
- Reference only: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/private/HybridPBI_Classification.m:43-84,141-219`
- Do not modify: `ComputeSDEFactorialContinuousScore.m`; it belongs to the earlier CPR factorial experiment

- [ ] **Step 1: Add boundary, fusion, catalog, and forbidden-path tests**

Append:

```matlab
function testContinuousSupervisorUsesApprovedBlend(testCase)
    N = 24;
    t = linspace(0.04,0.96,N)';
    PopDec = [t,1-t,t.^2];
    PopObj = [1+t,2-t,0.4+0.3*sin(pi*t).^2];
    Population = SOLUTION(PopDec,PopObj,zeros(N,1));

    [catalog0,agreement0,ref0,score0,detail0] = ...
        DualPBIContinuousSupervision(Population,0,N,6,5);
    [catalog1,agreement1,ref1,score1,detail1] = ...
        DualPBIContinuousSupervision(Population,1,N,6,5);
    ratio = 0.37;
    [catalogC,agreementC,refC,scoreC,detailC] = ...
        DualPBIContinuousSupervision(Population,ratio,N,6,5);

    verifyEqual(testCase,score0,detail0.scoreV,'AbsTol',0);
    verifyEqual(testCase,score1,detail1.scoreRef,'AbsTol',0);
    verifyEqual(testCase,scoreC, ...
        (1-ratio)*detailC.scoreV+ratio*detailC.scoreRef, ...
        'AbsTol',1e-12);
    verifyEqual(testCase,agreementC, ...
        1-abs(detailC.scoreV-detailC.scoreRef),'AbsTol',1e-12);
    verifyEqual(testCase,ref0.decs,ref1.decs,'AbsTol',0);
    verifyEqual(testCase,ref0.decs,refC.decs,'AbsTol',0);
    verifyEqual(testCase,sum(catalog0),ceil(N/4));
    verifyEqual(testCase,sum(catalog1),ceil(N/4));
    verifyEqual(testCase,sum(catalogC),ceil(N/4));
    verifyGreaterThanOrEqual(testCase,agreement0,zeros(N,1));
    verifyLessThanOrEqual(testCase,agreement1,ones(N,1));
    verifyEqual(testCase,detailC.theta,5);
    verifyEqual(testCase,detailC.directionMode,'uniform');

    [~,order] = sort(scoreC,'descend');
    expectedCatalog = false(N,1);
    expectedCatalog(order(1:ceil(N/4))) = true;
    verifyEqual(testCase,catalogC,expectedCatalog);
end

function testContinuousSupervisorExcludesTemporaryCPRScoring(testCase)
    source = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'DualPBIContinuousSupervision.m'));
    referenceSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'ComputeReferencePBIContinuousScore.m'));

    verifyFalse(testCase,contains(source, ...
        'ComputeSDEFactorialContinuousScore('));
    verifyFalse(testCase,contains(source,'GetOutput_PBI('));
    verifyFalse(testCase,contains(source,'rankUtility('));
    verifyTrue(testCase,contains(source, ...
        'ComputeReferencePBIContinuousScore('));
    verifyFalse(testCase,contains(referenceSource,'normR'));
    verifyFalse(testCase,contains(referenceSource,'delta'));
end
```

- [ ] **Step 2: Run the focused test and verify RED**

Expected failures:

- the current function exposes only four outputs;
- it fixes the direction field with `UniformPoint`;
- it calls the rank-based CPR score helper;
- its details and exact boundary behavior do not match the approved contract.

- [ ] **Step 3: Replace the supervisor core**

Use this public contract and core implementation:

```matlab
function [Catalog,agreement,Ref,score,detail] = ...
    DualPBIContinuousSupervision(Population,ratio,Nref,k,theta)
%DualPBIContinuousSupervision H-A geometry with a continuous reference branch.

    validateSupervisionInputs(Population,ratio,Nref,k,theta);
    N = length(Population);
    M = size(Population(1).obj,2);
    PopObj = Population.objs;

    if M <= 3 || N < 50
        V = UniformPoint(Nref,M,'ILD');
        V = V./vecnorm(V,2,2);
        directionMode = 'uniform';
    else
        V = AdaptiveReferenceVectors(PopObj,Nref);
        directionMode = 'adaptive';
    end

    Ref = RefSelect(Population,k);
    Zmin = min(PopObj,[],1);

    cosine = 1-pdist2(PopObj,V,'cosine');
    [~,refIndex] = max(cosine,[],2);
    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        w = V(refIndex(i),:);
        d1(i) = (PopObj(i,:)-Zmin)*w'/norm(w);
        projection = Zmin+d1(i)*w;
        d2(i) = norm(PopObj(i,:)-projection);
    end
    pbiV = d1+theta*d2;
    scoreV = 1./(1+pbiV);

    [scoreRef,referenceDetail] = ...
        ComputeReferencePBIContinuousScore( ...
        PopObj,Ref.objs,theta,scoreV);

    score = (1-ratio)*scoreV+ratio*scoreRef;
    agreement = 1-abs(scoreV-scoreRef);

    [~,order] = sort(score,'descend');
    goodCount = ceil(N/4);
    Catalog = false(N,1);
    Catalog(order(1:goodCount)) = true;

    detail = struct();
    detail.scoreV = scoreV;
    detail.scoreRef = scoreRef;
    detail.pbiV = pbiV;
    detail.pbiRef = referenceDetail.pbi;
    detail.globalDirections = V;
    detail.globalAssignment = refIndex;
    detail.referenceAssignment = ...
        referenceDetail.assignedReference;
    detail.referenceFallbackUsed = ...
        referenceDetail.fallbackUsed;
    detail.directionMode = directionMode;
    detail.ratio = ratio;
    detail.theta = theta;
end
```

Add strict scalar validation without clamping `ratio`:

```matlab
function validateSupervisionInputs(Population,ratio,Nref,k,theta)
    if isempty(Population)
        error('AdaMaO:EmptyPBIPopulation', ...
            'Population must not be empty.');
    end
    values = {ratio,Nref,k,theta};
    validScalars = all(cellfun(@(value) ...
        isnumeric(value) && isreal(value) && isscalar(value) && ...
        isfinite(value),values));
    if ~validScalars
        error('AdaMaO:InvalidPBISupervisionParameter', ...
            'PBI supervision parameters must be finite real scalars.');
    end
    if ratio < 0 || ratio > 1 || Nref < 1 || Nref ~= floor(Nref) || ...
            k < 1 || k ~= floor(k) || theta < 0
        error('AdaMaO:InvalidPBISupervisionParameter', ...
            'ratio, Nref, k, or theta is outside its valid range.');
    end
end
```

Copy `AdaptiveReferenceVectors` **exactly** from the frozen baseline function `private/HybridPBI_Classification.m:141-219` as a local function at the end of `DualPBIContinuousSupervision.m`. Do not improve, normalize, refactor, or deduplicate it in this phase. Exact duplication is intentional: H-A must remain frozen while C-A must consume the same random calls and fallback path.

- [ ] **Step 4: Verify the implementation contains exactly one intended branch change**

Review `DualPBIContinuousSupervision.m` against:

- baseline direction path at `HybridPBI_Classification.m:43-84`;
- baseline `RefSelect` position at `HybridPBI_Classification.m:53-56`;
- approved continuous reference formula;
- absence of objective normalization, rank utility, `delta`, and `/normR`.

The fourth output remains the fused continuous score for diagnostics. The new fifth output is additive and does not change the three-output C-A runtime call.

- [ ] **Step 5: Run the focused test and verify GREEN**

Expected: all formula, blend, catalog, agreement, source-isolation, and hash tests pass.

- [ ] **Step 6: Commit the corrected supervisor**

```powershell
git -C 'D:\PlatEMO-master' add -- 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/DualPBIContinuousSupervision.m' 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'
git -C 'D:\PlatEMO-master' commit -m "feat: align AdaMaO continuous dual PBI"
```

### Task 3: Prove H-A/C-A geometry parity and freeze the C-A isolation boundary

**Files:**

- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/CaptureAdaMaOPBISnapshot.m`
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m`
- Review only: `REMO_new2_AdaMaO_SDEOnly_ModeBase.m`
- Review only: `REMO_new2_AdaMaO_SDEOnly_DualPBIContModeBase.m`
- Review only: `REMO_new2_AdaMaO_SDEOnly_UniformMix.m`
- Review only: `REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont.m`

- [ ] **Step 1: Add low-dimensional and adaptive-direction parity tests**

Append:

```matlab
function testSnapshotPreservesRngAndMatchesLowDimensionalBaseline(testCase)
    N = 30;
    t = linspace(0.02,0.98,N)';
    PopObj = [1+t,2-t,0.5+0.2*cos(2*pi*t).^2];
    Population = SOLUTION([t,1-t],PopObj,zeros(N,1));

    rng(818,'twister');
    before = rng;
    snapshot = CaptureAdaMaOPBISnapshot(Population,0.42,N,6,5);
    after = rng;

    verifyEqual(testCase,after,before);
    verifyEqual(testCase,snapshot.scoreVHard, ...
        snapshot.scoreVContinuous,'AbsTol',1e-12);
    verifyEqual(testCase,snapshot.refHardObj, ...
        snapshot.refContinuousObj,'AbsTol',0);
    verifyEqual(testCase,snapshot.directionMode,'uniform');
end

function testSnapshotMatchesAdaptiveDirectionBaseline(testCase)
    N = 60;
    M = 5;
    t = linspace(0.02,0.98,N)';
    PopDec = [t,1-t,mod((1:N)',7)/7];
    PopObj = [t,1-t,0.2+0.7*t.^2, ...
        0.3+0.5*(1-t).^2,0.4+0.1*sin(2*pi*t)];
    Population = SOLUTION(PopDec,PopObj,zeros(N,1));

    rng(8181,'twister');
    before = rng;
    snapshot = CaptureAdaMaOPBISnapshot(Population,0.55,20,8,5);
    after = rng;

    verifyEqual(testCase,after,before);
    verifyEqual(testCase,snapshot.directionMode,'adaptive');
    verifyEqual(testCase,snapshot.scoreVHard, ...
        snapshot.scoreVContinuous,'AbsTol',1e-12);
    verifyEqual(testCase,snapshot.refHardDec, ...
        snapshot.refContinuousDec,'AbsTol',0);
    verifyTrue(testCase,snapshot.rngConsumptionMatched);
end
```

- [ ] **Step 2: Add C-A structure guards**

Append:

```matlab
function testCAKeepsUniformMixAndOriginalAdaptiveRelationGate(testCase)
    baseSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_DualPBIContModeBase.m'));
    entrySource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont.m'));

    verifyTrue(testCase,contains(baseSource, ...
        'Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6,0.35,1,0)'));
    verifyTrue(testCase,contains(baseSource, ...
        'ratio = Problem.FE / Problem.maxFE;'));
    verifyTrue(testCase,contains(baseSource, ...
        'DualPBIContinuousSupervision('));
    verifyTrue(testCase,contains(baseSource, ...
        'previousError > errorThreshold'));
    verifyTrue(testCase,contains(baseSource,'meanAgreement >= 0.55'));
    verifyTrue(testCase,contains(baseSource,'coverage < 0.60'));
    verifyTrue(testCase,contains(entrySource, ...
        "policy = 'uniform_mix';"));
end
```

- [ ] **Step 3: Run the focused test and verify RED**

Expected: snapshot tests fail because `CaptureAdaMaOPBISnapshot` does not exist.

- [ ] **Step 4: Implement the RNG-restoring H/C/G/R snapshot**

Create:

```matlab
function snapshot = CaptureAdaMaOPBISnapshot( ...
    Population,ratio,Nref,k,theta)
%CaptureAdaMaOPBISnapshot Compare hard and continuous supervision offline.

    stateBefore = rng;
    cleanup = onCleanup(@() rng(stateBefore)); %#ok<NASGU>

    rng(stateBefore);
    [~,~,catalogH,agreementH,refH] = HybridPBI_Classification( ...
        Population,ratio,'Nref',Nref,'k',k,'theta',theta);
    stateAfterHard = rng;

    PopObj = Population.objs;
    labelDyn = GetOutput_PBI(PopObj,refH.objs);
    scoreVHard = agreementH;
    scoreVHard(~labelDyn) = 1-agreementH(~labelDyn);
    scoreH = (1-ratio)*scoreVHard+ratio*double(labelDyn);

    rng(stateBefore);
    [catalogC,agreementC,refC,scoreC,detailC] = ...
        DualPBIContinuousSupervision( ...
        Population,ratio,Nref,k,theta);
    stateAfterContinuous = rng;

    refMatched = isequal(refH.decs,refC.decs) && ...
        isequal(refH.objs,refC.objs) && ...
        isequal(refH.cons,refC.cons);
    rngMatched = isequal(stateAfterHard,stateAfterContinuous);
    scoreMatched = max(abs(scoreVHard-detailC.scoreV)) <= 1e-12;
    if ~refMatched || ~rngMatched || ~scoreMatched
        error('AdaMaO:PBIBaselineParityViolation', ...
            ['H-A and C-A differ outside the representative-score ', ...
             'continuous replacement.']);
    end

    snapshot = struct();
    snapshot.ratio = ratio;
    snapshot.theta = theta;
    snapshot.labelDyn = labelDyn;
    snapshot.scoreVHard = scoreVHard;
    snapshot.scoreVContinuous = detailC.scoreV;
    snapshot.scoreRef = detailC.scoreRef;
    snapshot.scoreH = scoreH;
    snapshot.scoreC = scoreC;
    snapshot.catalogH = catalogH;
    snapshot.catalogC = catalogC;
    snapshot.agreementH = agreementH;
    snapshot.agreementC = agreementC;
    snapshot.refHardDec = refH.decs;
    snapshot.refHardObj = refH.objs;
    snapshot.refContinuousDec = refC.decs;
    snapshot.refContinuousObj = refC.objs;
    snapshot.globalDirections = detailC.globalDirections;
    snapshot.directionMode = detailC.directionMode;
    snapshot.referenceFallbackUsed = ...
        detailC.referenceFallbackUsed;
    snapshot.rngConsumptionMatched = rngMatched;
end
```

This file belongs in the algorithm parent directory so MATLAB permits it to call the frozen private functions. It is not called by H-A or C-A.

- [ ] **Step 5: Run the focused test and verify GREEN**

The adaptive test is the decisive isolation check: identical initial RNG, identical RNG consumption, identical representative solutions, and identical direction-view scores. Any failure means the implementation changed more than the representative score.

- [ ] **Step 6: Commit the snapshot parity gate**

```powershell
git -C 'D:\PlatEMO-master' add -- 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/CaptureAdaMaOPBISnapshot.m' 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'
git -C 'D:\PlatEMO-master' commit -m "test: lock hard continuous PBI parity"
```

### Task 4: Implement same-label, equal-Top-K, complementarity, and stability diagnostics

**Files:**

- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/EvaluateAdaMaOPBISnapshot.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/CompareAdaMaOPBIStability.m`
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m`

- [ ] **Step 1: Add deterministic diagnostic tests**

Append:

```matlab
function testSnapshotDiagnosticsMeasureRefinementAndEqualTopK(testCase)
    PopObj = [1 4; 2 5; 4 1; 5 2; 3 3; 3.5 3.5];
    Population = SOLUTION((1:6)',PopObj,zeros(6,1));
    snapshot = struct();
    snapshot.labelDyn = logical([1;1;0;0;1;1]);
    snapshot.scoreVContinuous = [0.8;0.7;0.9;0.3;0.6;0.4];
    snapshot.scoreRef = [0.9;0.6;0.8;0.4;0.7;0.5];
    snapshot.scoreH = [0.8;0.7;0.9;0.3;0.6;0.4];
    snapshot.scoreC = [0.85;0.65;0.85;0.35;0.65;0.45];
    optimum = [1 1; 1.5 1.5];

    metrics = EvaluateAdaMaOPBISnapshot( ...
        Population,snapshot,optimum);

    verifyEqual(testCase,metrics.topK.K,ceil(6/4));
    verifyTrue(testCase,metrics.topK.igdAvailable);
    verifyGreaterThan(testCase,metrics.refinement.sameLabelPairCount,0);
    verifyGreaterThan(testCase,metrics.refinement.dominancePairCount,0);
    verifyEqual(testCase,metrics.refinement.tieCoverage,1);
    verifyEqual(testCase,metrics.refinement.dominanceConcordance,1);
    verifyEqual(testCase,metrics.topK.igd.hard, ...
        IGD(Population(metrics.topK.index.hard),optimum), ...
        'AbsTol',0);
    verifyGreaterThanOrEqual(testCase, ...
        metrics.complementarity.globalReferenceJaccard,0);
    verifyLessThanOrEqual(testCase, ...
        metrics.complementarity.globalReferenceJaccard,1);
end

function testMissingReferenceSetSkipsOnlyTopKIGD(testCase)
    PopObj = [1 3;2 2;3 1;2.5 2.5];
    Population = SOLUTION((1:4)',PopObj,zeros(4,1));
    snapshot = struct( ...
        'labelDyn',logical([1;1;0;0]), ...
        'scoreVContinuous',[0.8;0.7;0.6;0.5], ...
        'scoreRef',[0.7;0.9;0.4;0.6], ...
        'scoreH',[0.8;0.7;0.6;0.5], ...
        'scoreC',[0.75;0.8;0.5;0.55]);

    metrics = EvaluateAdaMaOPBISnapshot(Population,snapshot,[]);

    verifyFalse(testCase,metrics.topK.igdAvailable);
    verifyEqual(testCase,metrics.topK.igdSkipReason, ...
        'missing_reference_set');
    verifyTrue(testCase,isnan(metrics.topK.igd.continuous));
    verifyTrue(testCase,isfinite(metrics.refinement.tieCoverage));
end

function testStabilityUsesOnlyExactCommonDecisionsAndNoRng(testCase)
    recordA.populationDec = [0 0;1 0;0 1];
    recordB.populationDec = [1 0;0 1;1 1];
    recordA.snapshot = struct( ...
        'scoreH',[0.9;0.7;0.4], ...
        'scoreC',[0.8;0.6;0.5], ...
        'scoreRef',[0.7;0.5;0.4], ...
        'labelDyn',logical([1;0;0]));
    recordB.snapshot = struct( ...
        'scoreH',[0.6;0.3;0.2], ...
        'scoreC',[0.55;0.45;0.1], ...
        'scoreRef',[0.5;0.35;0.2], ...
        'labelDyn',logical([1;1;0]));

    rng(991,'twister');
    before = rng;
    stability = CompareAdaMaOPBIStability(recordA,recordB);
    after = rng;

    verifyEqual(testCase,after,before);
    verifyEqual(testCase,stability.commonCount,2);
    verifyEqual(testCase,stability.coverageA,2/3,'AbsTol',0);
    verifyEqual(testCase,stability.coverageB,2/3,'AbsTol',0);
    verifyEqual(testCase,stability.labelFlipRate,0);
    verifyTrue(testCase,isfinite(stability.spearman.hard));
end

function testSparseCommonDecisionsDoNotFabricateCorrelation(testCase)
    recordA.populationDec = [0 0;1 0];
    recordB.populationDec = [1 0;0 1];
    recordA.snapshot = struct('scoreH',[0.8;0.6], ...
        'scoreC',[0.7;0.5],'scoreRef',[0.6;0.4], ...
        'labelDyn',logical([1;0]));
    recordB.snapshot = struct('scoreH',[0.5;0.3], ...
        'scoreC',[0.4;0.2],'scoreRef',[0.3;0.1], ...
        'labelDyn',logical([0;1]));

    stability = CompareAdaMaOPBIStability(recordA,recordB);

    verifyEqual(testCase,stability.commonCount,1);
    verifyTrue(testCase,isnan(stability.spearman.hard));
    verifyTrue(testCase,isnan(stability.spearman.continuous));
    verifyTrue(testCase,isnan(stability.spearman.reference));
end
```

- [ ] **Step 2: Run the focused test and verify RED**

Expected: diagnostic tests fail because both functions are absent.

- [ ] **Step 3: Implement within-snapshot diagnostics**

Create `EvaluateAdaMaOPBISnapshot.m` with this contract and data layout:

```matlab
function metrics = EvaluateAdaMaOPBISnapshot( ...
    Population,snapshot,optimum)
%EvaluateAdaMaOPBISnapshot Offline mechanism metrics on one population.

    if nargin < 3
        optimum = [];
    end
    N = length(Population);
    PopObj = Population.objs;
    fields = {'scoreH','scoreC','scoreVContinuous','scoreRef','labelDyn'};
    for i = 1:numel(fields)
        if ~isfield(snapshot,fields{i}) || ...
                numel(snapshot.(fields{i})) ~= N
            error('AdaMaO:InvalidPBISnapshot', ...
                'Snapshot fields must align with Population.');
        end
    end

    metrics = struct();
    metrics.refinement = sameLabelRefinement( ...
        PopObj,snapshot.labelDyn,snapshot.scoreRef);

    names = {'hard','continuous','global','reference'};
    scores = {snapshot.scoreH,snapshot.scoreC, ...
        snapshot.scoreVContinuous,snapshot.scoreRef};
    K = ceil(N/4);
    metrics.topK.K = K;
    for i = 1:numel(names)
        [~,order] = sort(scores{i}(:),'descend');
        metrics.topK.index.(names{i}) = order(1:K);
    end

    [available,reason] = validReferenceSet(optimum,size(PopObj,2));
    metrics.topK.igdAvailable = available;
    metrics.topK.igdSkipReason = reason;
    for i = 1:numel(names)
        if available
            index = metrics.topK.index.(names{i});
            metrics.topK.igd.(names{i}) = ...
                IGD(Population(index),optimum);
        else
            metrics.topK.igd.(names{i}) = nan;
        end
    end

    metrics.complementarity.scoreSpearman = safeSpearman( ...
        snapshot.scoreVContinuous,snapshot.scoreRef);
    metrics.complementarity.globalReferenceJaccard = ...
        jaccardIndex(metrics.topK.index.global, ...
        metrics.topK.index.reference);
    metrics.complementarity.dualMinusGlobalIGD = ...
        metrics.topK.igd.continuous-metrics.topK.igd.global;
    metrics.complementarity.dualMinusReferenceIGD = ...
        metrics.topK.igd.continuous-metrics.topK.igd.reference;
end

function result = sameLabelRefinement(PopObj,labelDyn,scoreRef)
    pairIndex = zeros(0,2);
    for label = [false,true]
        index = find(logical(labelDyn(:)) == label);
        if numel(index) >= 2
            pairIndex = [pairIndex;nchoosek(index,2)]; %#ok<AGROW>
        end
    end

    tolerance = 64*eps(max(1,max(abs(scoreRef(:)))));
    scoreDifference = abs( ...
        scoreRef(pairIndex(:,1))-scoreRef(pairIndex(:,2)));
    separated = scoreDifference > tolerance;

    dominancePairCount = 0;
    concordantCount = 0;
    tiedDominanceCount = 0;
    for i = 1:size(pairIndex,1)
        left = pairIndex(i,1);
        right = pairIndex(i,2);
        leftDominates = all(PopObj(left,:) <= PopObj(right,:)) && ...
            any(PopObj(left,:) < PopObj(right,:));
        rightDominates = all(PopObj(right,:) <= PopObj(left,:)) && ...
            any(PopObj(right,:) < PopObj(left,:));
        if leftDominates || rightDominates
            dominancePairCount = dominancePairCount+1;
            if rightDominates
                dominant = right;
                dominated = left;
            else
                dominant = left;
                dominated = right;
            end
            difference = scoreRef(dominant)-scoreRef(dominated);
            concordantCount = concordantCount+(difference > tolerance);
            tiedDominanceCount = tiedDominanceCount+ ...
                (abs(difference) <= tolerance);
        end
    end

    result.sameLabelPairCount = size(pairIndex,1);
    result.separatedPairCount = sum(separated);
    result.tieCoverage = safeRatio( ...
        result.separatedPairCount,result.sameLabelPairCount);
    result.dominancePairCount = dominancePairCount;
    result.concordantPairCount = concordantCount;
    result.tiedDominancePairCount = tiedDominanceCount;
    result.dominanceConcordance = safeRatio( ...
        concordantCount,dominancePairCount);
end

function value = safeRatio(numerator,denominator)
    if denominator == 0
        value = nan;
    else
        value = numerator/denominator;
    end
end

function value = safeSpearman(left,right)
    if numel(left) < 2
        value = nan;
    else
        value = corr(left(:),right(:), ...
            'Type','Spearman','Rows','complete');
    end
end

function value = jaccardIndex(left,right)
    intersectionCount = numel(intersect(left(:),right(:)));
    unionCount = numel(union(left(:),right(:)));
    value = intersectionCount/unionCount;
end

function [available,reason] = validReferenceSet(optimum,M)
    if nargin < 1 || isempty(optimum)
        available = false;
        reason = 'missing_reference_set';
    elseif ~isnumeric(optimum) || size(optimum,2) ~= M || ...
            any(~isfinite(optimum(:)))
        available = false;
        reason = 'invalid_reference_set';
    else
        available = true;
        reason = '';
    end
end
```

The numeric tolerance only distinguishes floating-point equality; it is not an algorithm parameter and must not be exposed for tuning.

- [ ] **Step 4: Implement adjacent-snapshot stability**

Create:

```matlab
function stability = CompareAdaMaOPBIStability(recordA,recordB)
%CompareAdaMaOPBIStability Stability on exactly matching decision vectors.

    decA = recordA.populationDec;
    decB = recordB.populationDec;
    if size(decA,2) ~= size(decB,2)
        error('AdaMaO:IncompatiblePBIRecords', ...
            'Decision dimensions must match.');
    end

    [~,indexA,indexB] = intersect(decA,decB,'rows','stable');
    commonCount = numel(indexA);
    uniqueA = unique(decA,'rows');
    uniqueB = unique(decB,'rows');
    unionCount = size(unique([uniqueA;uniqueB],'rows'),1);

    stability = struct();
    stability.commonCount = commonCount;
    stability.coverageA = commonCount/size(uniqueA,1);
    stability.coverageB = commonCount/size(uniqueB,1);
    stability.identityJaccard = commonCount/unionCount;
    stability.duplicateCountA = size(decA,1)-size(uniqueA,1);
    stability.duplicateCountB = size(decB,1)-size(uniqueB,1);

    stability.spearman.hard = commonSpearman( ...
        recordA.snapshot.scoreH,recordB.snapshot.scoreH,indexA,indexB);
    stability.spearman.continuous = commonSpearman( ...
        recordA.snapshot.scoreC,recordB.snapshot.scoreC,indexA,indexB);
    stability.spearman.reference = commonSpearman( ...
        recordA.snapshot.scoreRef,recordB.snapshot.scoreRef,indexA,indexB);

    if commonCount == 0
        stability.labelFlipRate = nan;
    else
        stability.labelFlipRate = mean( ...
            recordA.snapshot.labelDyn(indexA) ~= ...
            recordB.snapshot.labelDyn(indexB));
    end

    stability.topKJaccardDistance.hard = topKDistance( ...
        decA,recordA.snapshot.scoreH,decB,recordB.snapshot.scoreH);
    stability.topKJaccardDistance.continuous = topKDistance( ...
        decA,recordA.snapshot.scoreC,decB,recordB.snapshot.scoreC);
end

function value = commonSpearman(scoreA,scoreB,indexA,indexB)
    if numel(indexA) < 2
        value = nan;
    else
        value = corr(scoreA(indexA),scoreB(indexB), ...
            'Type','Spearman','Rows','complete');
    end
end

function distance = topKDistance(decA,scoreA,decB,scoreB)
    topA = topDecisions(decA,scoreA);
    topB = topDecisions(decB,scoreB);
    intersectionCount = size(intersect(topA,topB,'rows'),1);
    unionCount = size(unique([topA;topB],'rows'),1);
    distance = 1-intersectionCount/unionCount;
end

function decisions = topDecisions(dec,score)
    [~,order] = sort(score(:),'descend');
    K = ceil(size(dec,1)/4);
    decisions = dec(order(1:K),:);
end
```

Do not use nearest-neighbor matching or a decision-space tolerance. The approved stability definition is exact common decision vectors. Fewer than two common decisions yields `NaN` correlation, not a fabricated zero.

- [ ] **Step 5: Run the focused test and verify GREEN**

Expected: same-label, Top-K, missing-reference, G/R complementarity, and sparse-overlap tests pass without changing the RNG.

- [ ] **Step 6: Commit the diagnostic metrics**

```powershell
git -C 'D:\PlatEMO-master' add -- 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/EvaluateAdaMaOPBISnapshot.m' 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/CompareAdaMaOPBIStability.m' 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'
git -C 'D:\PlatEMO-master' commit -m "feat: add dual PBI mechanism diagnostics"
```

### Task 5: Add a non-perturbing runtime probe without modifying either optimizer

**Files:**

- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/AdaMaOPBIProbe.m`
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m`
- Do not modify: H-A or C-A runtime classes

- [ ] **Step 1: Add probe capture and on/off equivalence tests**

Append:

```matlab
function testProbeDoesNotChangeHAOrCAResults(testCase)
    names = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont'};

    for i = 1:numel(names)
        [plainObj,plainFE] = runProbeSmoke(names{i},[],620+i);
        probe = AdaMaOPBIProbe;
        [probeObj,probeFE] = runProbeSmoke(names{i},probe,620+i);

        verifyEqual(testCase,probeFE,plainFE);
        verifyEqual(testCase,probeObj,plainObj,'AbsTol',0);
        verifyNotEmpty(testCase,probe.Records);
        verifyTrue(testCase,all([probe.Records.theta] == 5));
    end
end

function [finalObj,finalFE] = runProbeSmoke(name,probe,seed)
    D = 3;
    initialFE = 11*D-1;
    parameters = {[],1,[],[],[],[],[],[],[],[]};
    if isempty(probe)
        outputFcn = @silentOutput;
    else
        outputFcn = @(Algorithm,Problem) ...
            probe.capture(Algorithm,Problem);
    end
    Algorithm = feval(name,'parameter',parameters,'save',0, ...
        'outputFcn',outputFcn,'run',17);
    Problem = DTLZ2('N',20,'M',3,'D',D,'maxFE',initialFE+4);

    rng(seed,'twister');
    Algorithm.Solve(Problem);

    last = find(~cellfun(@isempty,Algorithm.result(:,2)),1,'last');
    finalObj = Algorithm.result{last,2}.objs;
    finalFE = Problem.FE;
end

function silentOutput(varargin) %#ok<INUSD>
end
```

This is an implementation smoke test, not a performance comparison.

- [ ] **Step 2: Run the focused test and verify RED**

Expected: `AdaMaOPBIProbe` is undefined.

- [ ] **Step 3: Implement the output-function probe**

Create:

```matlab
classdef AdaMaOPBIProbe < handle
%AdaMaOPBIProbe Capture H/C/G/R diagnostics through ALGORITHM.outputFcn.

    properties(SetAccess = private)
        Records = struct([])
    end

    methods
        function capture(obj,Algorithm,Problem)
            last = find(~cellfun(@isempty,Algorithm.result(:,2)), ...
                1,'last');
            if isempty(last)
                return;
            end
            if ~isempty(obj.Records) && ...
                    obj.Records(end).FE == Problem.FE
                return;
            end

            Archive = Algorithm.result{last,2};
            if isempty(obj.Records)
                Population = Archive;
            else
                Population = RefSelect(Archive,Problem.N);
            end

            if Problem.D <= 10
                Nref = 11*Problem.D-1;
            else
                Nref = 100;
            end
            baseK = resolveBaseK(Algorithm);
            kEff = min(Problem.N,max(baseK,ceil(1.5*Problem.M)));
            ratio = Problem.FE/Problem.maxFE;
            theta = 5;

            snapshot = CaptureAdaMaOPBISnapshot( ...
                Population,ratio,Nref,kEff,theta);
            diagnostics = EvaluateAdaMaOPBISnapshot( ...
                Population,snapshot,Problem.optimum);

            record = struct();
            record.algorithm = class(Algorithm);
            record.problem = class(Problem);
            record.objectiveCount = Problem.M;
            record.decisionCount = Problem.D;
            record.run = Algorithm.run;
            record.FE = Problem.FE;
            record.ratio = ratio;
            record.theta = theta;
            record.usedForUpdate = Problem.FE < Problem.maxFE;
            record.populationDec = Population.decs;
            record.populationObj = Population.objs;
            record.populationCon = Population.cons;
            record.snapshot = snapshot;
            record.diagnostics = diagnostics;

            if isempty(obj.Records)
                obj.Records = record;
            else
                obj.Records(end+1) = record;
            end
        end
    end
end

function k = resolveBaseK(Algorithm)
    k = 6;
    parameters = Algorithm.parameter;
    if iscell(parameters) && ~isempty(parameters) && ...
            ~isempty(parameters{1})
        k = parameters{1};
    end
end
```

Why the reconstruction is faithful:

- `NotTerminated` exposes `Archive`, not the local classifier population.
- On the first callback, the local classifier population is the initial archive.
- After each update, both H-A and C-A set `Population = RefSelect(Archive,Problem.N)`.
- Duplicate callbacks at the same FE are skipped.
- `CaptureAdaMaOPBISnapshot` restores RNG state after running both views.
- `RefSelect`, metric calculations, and exact matching do not consume random values.
- The probe never calls `Problem.Evaluation`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Require exact final objective matrices with the probe off and on for both H-A and C-A. If exact equality fails, stop and diagnose before weakening the assertion.

- [ ] **Step 5: Commit the probe**

```powershell
git -C 'D:\PlatEMO-master' add -- 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/AdaMaOPBIProbe.m' 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'
git -C 'D:\PlatEMO-master' commit -m "feat: add nonperturbing dual PBI probe"
```

### Task 6: Integration verification and minimum H-A/C-A smoke

**Files:**

- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m`
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly.m`
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly_Policies.m`
- Review: all files changed by Tasks 1-5

- [ ] **Step 1: Run the new focused suite in a fresh MATLAB process**

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "results=runtests('Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'); assertSuccess(results)"
```

Expected: zero failures.

- [ ] **Step 2: Run the existing SDE-only regression suites**

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "files={'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly.m','Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly_Policies.m'}; results=runtests(files); assertSuccess(results)"
```

Expected: zero failures and no changed H-A behavior.

- [ ] **Step 3: Run the complete algorithm-directory test suite**

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "results=runtests('Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests'); assertSuccess(results)"
```

This also guards the earlier CPR factorial code. Do not rewrite or delete `ComputeSDEFactorialContinuousScore` merely because C-A no longer calls it.

- [ ] **Step 4: Run Code Analyzer on changed MATLAB files**

```matlab
files = {
    'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/ComputeReferencePBIContinuousScore.m'
    'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/DualPBIContinuousSupervision.m'
    'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/CaptureAdaMaOPBISnapshot.m'
    'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/EvaluateAdaMaOPBISnapshot.m'
    'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/CompareAdaMaOPBIStability.m'
    'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/AdaMaOPBIProbe.m'
    'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ContinuousDualPBI.m'};
for i = 1:numel(files)
    issues = checkcode(files{i},'-id');
    assert(isempty(issues), ...
        'Code Analyzer findings remain in %s.',files{i});
end
```

If a justified analyzer suppression is needed, make it local with a specific `%#ok<...>` identifier; do not disable an analyzer category globally.

- [ ] **Step 5: Recheck frozen hashes and the exact source boundary**

```powershell
$base='D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO_SDEOnly'
Get-FileHash -Algorithm SHA256 -LiteralPath "$base\REMO_new2_AdaMaO_SDEOnly_UniformMix.m","$base\REMO_new2_AdaMaO_SDEOnly_ModeBase.m","$base\private\HybridPBI_Classification.m","$base\private\GetOutput_PBI.m","$base\private\RefSelect.m"
git -C 'D:\PlatEMO-master' diff --no-index -- "$base\REMO_new2_AdaMaO_SDEOnly_ModeBase.m" "$base\REMO_new2_AdaMaO_SDEOnly_DualPBIContModeBase.m"
```

The SHA-256 values must remain:

```text
EF7F6D07123D43C6D12C0D0D0D7CCE58DC9548927E08325F4D9F8A4576CF3319
8950A3E7A2EF6D19E593ADDAE313F43B3DC5946C1A07F2E862F247FB66B5DD79
9CF1D8E56091BB4D005C1BE82E22B5D7CF501BB013E1DF258E3334D1E89F5714
332A04E49ECAFBF7E8C7AA2F8DDF9A210743C42637FD9E1D7C45F4E06B1F0F69
57ABF295E72AEB14B11558E001350E5ABD01FDDAE257B70BA3E99C12F58B24A3
```

The runtime diff must still be limited to:

- class/base names and comments;
- `HybridPBI_Classification` versus `DualPBIContinuousSupervision`;
- extraction of the identical adaptive relation-mode rule into an overridable protected method.

- [ ] **Step 6: Scan for forbidden mechanisms and unfinished work**

```powershell
$changed = @(
  'ComputeReferencePBIContinuousScore.m',
  'DualPBIContinuousSupervision.m',
  'CaptureAdaMaOPBISnapshot.m',
  'EvaluateAdaMaOPBISnapshot.m',
  'CompareAdaMaOPBIStability.m',
  'AdaMaOPBIProbe.m'
) | ForEach-Object { Join-Path 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO_SDEOnly' $_ }
Select-String -LiteralPath $changed -Pattern 'TODO|FIXME|placeholder|rankUtility\(|ComputeSDEFactorialContinuousScore\(|GetOutput_PBI\('
git -C 'D:\PlatEMO-master' diff --check
```

Expected:

- no placeholder markers;
- no CPR rank helper call;
- no `GetOutput_PBI` call in the C-A score functions;
- the sole `GetOutput_PBI` match is in the offline hard-baseline snapshot;
- `git diff --check` is clean.

- [ ] **Step 7: Review data types and edge behavior**

Confirm:

- `Catalog`, `catalogH`, `catalogC`, and `labelDyn` are logical columns;
- all score vectors are finite real `N x 1` arrays;
- both normal PBI branches use the same scalar `theta`;
- `ratio=0` and `ratio=1` are exact boundaries;
- zero representative directions are removed;
- all-invalid representative directions set `referenceFallbackUsed=true` and use `scoreV`;
- tied sorting follows MATLAB stable order and no random tiebreak is added;
- missing optimum sets only Top-K IGD to `NaN` with an explicit reason;
- fewer than two exact common decisions sets Spearman values to `NaN`;
- probe records are keyed by algorithm, problem, objective count, run, and FE;
- terminal records have `usedForUpdate=false`.

- [ ] **Step 8: Commit any final test-only corrections**

Only if Steps 1-7 required corrections:

```powershell
git -C 'D:\PlatEMO-master' add -- 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly'
git -C 'D:\PlatEMO-master' commit -m "test: verify continuous dual PBI isolation"
```

Do not stage unrelated user files.

### Task 7: Stop at the experimental approval gate

**Files:**

- Review: `docs/superpowers/specs/2026-07-24-adamao-continuous-dual-pbi-design.md`
- Review: implementation commits from Tasks 1-6

- [ ] **Step 1: Produce an implementation evidence summary**

Report separately:

- formula tests passed;
- H-A hashes unchanged;
- adaptive direction score/Ref/RNG parity passed;
- C-A relation controller and UniformMix policy unchanged;
- probe on/off objective matrices identical;
- diagnostic functions produce H/C/G/R Top-K, same-label, complementarity, and stability records;
- minimum H-A/C-A smoke passed.

State explicitly that these are implementation-validity results, not evidence of IGD superiority or mechanism effectiveness.

- [ ] **Step 2: Do not run the five-version experiment**

Stop before any formal H-A/C-A performance comparison and before C-U/C-F/C-W. Prepare a separate, predeclared experiment protocol containing:

- problem set and objective counts;
- dimension rules;
- FE budget;
- paired run IDs/seeds;
- snapshot checkpoints;
- primary performance endpoint;
- same-label, Top-K, stability, and G/R diagnostic aggregation;
- missing-reference handling;
- statistical tests and continuation/stopping gates.

Submit that protocol for user approval before observing comparative results.

## Completion definition

This implementation plan is complete only when:

1. H-A's five frozen blob hashes still match.
2. C-A uses H-A's original uniform/adaptive direction path and `RefSelect`.
3. C-A's representative branch is exactly `1/(1+d1+theta*d2)` in raw objective-space units, with no `delta`, `/normR`, rank utility, or extra normalization.
4. The shared `theta=5`, fusion, agreement, stable Top-K, hard Catalog, and hard relation labels match the approved design.
5. The adaptive parity test proves identical H-A/C-A direction-view scores, representatives, and RNG consumption.
6. The offline probe does not change FE, RNG, or final objectives.
7. The diagnostics distinguish numerical refinement from valid dominance ordering, compare equal-size H/C/G/R Top-K sets, and return honest `NaN` values when stability or reference-set evidence is unavailable.
8. No formal performance or C-U/C-F/C-W result has been generated before the separate experiment protocol is approved.
