# AdaMaO SDE-only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create an isolated PlatEMO algorithm variant that replaces AdaMaO's three-indicator roulette with the existing fixed SDE-based indicator while preserving every other algorithm mechanism.

**Architecture:** The new `REMO_new2_AdaMaO_SDEOnly` folder contains a renamed main algorithm class and a deterministic selector. A `private` folder snapshots the exact helper implementations required by the baseline so MATLAB resolves this variant's dependencies without using same-named helpers from other algorithm folders.

**Tech Stack:** MATLAB R2020b+, PlatEMO, MATLAB Unit Test framework, Statistics and Machine Learning Toolbox, Deep Learning Toolbox.

---

### Task 1: Add the failing behavior test

**Files:**
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly.m`

- [ ] **Step 1: Write the failing test**

```matlab
function tests = test_REMO_new2_AdaMaO_SDEOnly
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile     = mfilename('fullpath');
    testsDir     = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot  = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    testCase.TestData.AlgorithmDir = algorithmDir;
end

function testClassAndSelectorAreDiscoverable(testCase)
    mainFile = fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly.m');
    selectorFile = fullfile(testCase.TestData.AlgorithmDir, ...
        'IndicatorSelectorSDEOnly.m');
    verifyEqual(testCase,which('REMO_new2_AdaMaO_SDEOnly'),mainFile);
    verifyEqual(testCase,which('IndicatorSelectorSDEOnly'),selectorFile);
end

function testSelectorIsFixedSDEAndDoesNotAdvanceRng(testCase)
    t = linspace(0.02,0.98,24)';
    PopObj = [t,1-t,0.35+0.15*sin(2*pi*t)];
    Population = SOLUTION(zeros(24,2),PopObj,zeros(24,1));

    rng(19,'twister');
    stateBefore = rng;
    [fitnessA,LpA] = IndicatorSelectorSDEOnly(Population,1);
    stateAfter = rng;

    rng(91,'twister');
    [fitnessB,LpB] = IndicatorSelectorSDEOnly(Population,1);
    expected = calFitness_SDE(PopObj,LpA);

    verifyEqual(testCase,stateAfter,stateBefore);
    verifyEqual(testCase,LpA,LpB,'AbsTol',1e-12);
    verifyEqual(testCase,fitnessA,fitnessB,'AbsTol',1e-12);
    verifyEqual(testCase,fitnessA,expected,'AbsTol',1e-12);
end

function testMainSourceContainsNoRouletteMachinery(testCase)
    mainSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly.m'));
    selectorSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'IndicatorSelectorSDEOnly.m'));

    forbiddenMain = {'tau_indicator','Choose_record','Win_record', ...
        'UpdateInformation','IndicatorFeedbackScore','indicator_flag', ...
        'calFitness_epsilon','calFitness_MD'};
    for i = 1:numel(forbiddenMain)
        verifyFalse(testCase,contains(mainSource,forbiddenMain{i}), ...
            sprintf('Unexpected roulette token: %s',forbiddenMain{i}));
    end
    verifyEmpty(testCase,regexp(selectorSource,'\<rand\s*\(','once'));
    verifyTrue(testCase,contains(selectorSource,'calFitness_SDE'));
end
```

- [ ] **Step 2: Run the test and verify RED**

Run from the PlatEMO root:

```powershell
matlab -batch "results=runtests('Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly.m'); assertSuccess(results)"
```

Expected: FAIL because `REMO_new2_AdaMaO_SDEOnly` and `IndicatorSelectorSDEOnly` do not exist yet.

### Task 2: Create the isolated runtime snapshot

**Files:**
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/IndicatorSelectorSDEOnly.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/private/*.m`

- [ ] **Step 1: Copy the baseline main file and required unchanged helpers**

Copy `REMO_new2_AdaMaO.m` to the new class filename. Copy these exact unchanged helpers into the new `private` folder:

```text
AdaMaOSelection.m
calFitness_SDE.m
DataProcess.m
DataProcess_confidence.m
GetOutput_PBI.m
GetRelationPairs.m
GetRelationPairs_confidence.m
HybridPBI_Classification.m
onehotconv.m
RefSelect.m
Shape_Estimate.m
```

- [ ] **Step 2: Replace the roulette initialization with fixed-SDE state**

Use this main-loop initialization:

```matlab
%% ============ 初始化固定 SDE 指标 ============
% Lp 仍由 Shape_Estimate 每代更新，并供当前 SDE 的低分兜底使用
Lp         = 1;
prev_p_err = 1;
gen        = 0;
```

- [ ] **Step 3: Replace indicator selection with the deterministic selector**

```matlab
%% ---- 固定 SDE 指标（可选） ----
IndicatorModel = [];
Fitness = [];
if use_indicator
    try
        [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp);
    catch
        Fitness = [];
    end
    if ~isempty(Fitness)
        try
            IndicatorModel = fitrsvm(Population.decs,Fitness, ...
                'KernelFunction','rbf', ...
                'KernelScale','auto', ...
                'Standardize',true);
        catch
            IndicatorModel = [];
        end
    end
end
```

- [ ] **Step 4: Remove feedback-only code**

Delete the feedback block that calls `IndicatorFeedbackScore` and `UpdateInformation`, then delete the local `IndicatorFeedbackScore` function. Keep archive updates and debug output unchanged.

- [ ] **Step 5: Add the deterministic selector**

```matlab
function [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp_prev)
%IndicatorSelectorSDEOnly Evaluate the population with the fixed SDE score.

    PopObj = Population.objs;
    N      = length(Population);
    try
        Lp = Shape_Estimate(Population,N);
    catch
        Lp = Lp_prev;
    end
    if isempty(Lp) || ~isscalar(Lp) || ~isfinite(Lp) || Lp <= 0
        Lp = 1;
    end
    Fitness = calFitness_SDE(PopObj,Lp);
end
```

### Task 3: Verify GREEN and dependency isolation

**Files:**
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly.m`

- [ ] **Step 1: Run the focused MATLAB test**

```powershell
matlab -batch "results=runtests('Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly.m'); assertSuccess(results)"
```

Expected: 3 tests pass, 0 tests fail.

- [ ] **Step 2: Check copied helpers exactly match the baseline**

For each private helper, compare its SHA-256 hash with the corresponding file in `REMO_new2_AdaMaO`. Expected: all 11 pairs match.

- [ ] **Step 3: Check the class name and forbidden tokens**

Confirm the main file begins with `classdef REMO_new2_AdaMaO_SDEOnly < ALGORITHM`, calls `IndicatorSelectorSDEOnly`, and contains none of `tau_indicator`, `Choose_record`, `Win_record`, `UpdateInformation`, `IndicatorFeedbackScore`, `indicator_flag`, `calFitness_epsilon`, or `calFitness_MD`.

### Task 4: Run a PlatEMO smoke test

**Files:**
- Verify: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly.m`

- [ ] **Step 1: Run a small-budget DTLZ2 optimization**

```powershell
matlab -batch "[decs,objs,cons]=platemo('algorithm',@REMO_new2_AdaMaO_SDEOnly,'problem',@DTLZ2,'N',20,'M',3,'D',5,'maxFE',60); assert(~isempty(decs)); assert(size(objs,2)==3); assert(size(cons,1)==size(objs,1));"
```

Expected: MATLAB exits with code 0 and returns a nonempty three-objective result without undefined-function or path-resolution errors.

### Task 5: Final review and commit

**Files:**
- Review: all files in `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/`

- [ ] **Step 1: Review the exact diff and workspace status**

Confirm no existing AdaMaO source file was modified and the user's pre-existing CSV, prompt, and temporary-directory changes remain untouched.

- [ ] **Step 2: Run fresh verification**

Repeat the focused MATLAB test, helper hash comparison, forbidden-token scan, and smoke test. Do not claim completion unless all commands exit successfully.

- [ ] **Step 3: Commit only the SDE-only implementation**

```powershell
git add -- 'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly'
git commit -m "feat: add AdaMaO SDE-only variant"
```
