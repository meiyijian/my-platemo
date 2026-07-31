# AdaMaO UniformMix Fixed Relation Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add weighted, curriculum-filtered, and original-unweighted UniformMix experiment entries while leaving the existing UniformMix baseline and its shared runtime byte-for-byte unchanged.

**Architecture:** Create one experimental runtime copied from the frozen `REMO_new2_AdaMaO_SDEOnly_ModeBase`. Fix its candidate policy to `uniform_mix` and replace only its adaptive relation-mode controller with a protected mode hook. Three thin subclasses return `weighted`, `curriculum`, or `conservative`; existing relation-pair preparation and network-training branches remain unchanged.

**Tech Stack:** MATLAB class definitions, PlatEMO `ALGORITHM`, `matlab.unittest`, MATLAB Code Analyzer, Git

---

### Task 1: Add a failing fixed-mode wiring test

**Files:**
- Create: `PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_FixedRelationModes.m`

- [ ] **Step 1: Write the failing test**

```matlab
function tests = test_REMO_new2_AdaMaO_FixedRelationModes
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

function testThreeFixedModeEntriesAreDiscoverableAndMapped(testCase)
    baseName = ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase';
    entries = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted','weighted'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum','curriculum'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original','conservative'};

    for i = 1:size(entries,1)
        name = entries{i,1};
        expectedFile = fullfile(testCase.TestData.AlgorithmDir,[name,'.m']);
        verifyEqual(testCase,which(name),expectedFile);
        if ~isfile(expectedFile)
            continue;
        end
        source = fileread(expectedFile);
        verifyTrue(testCase,contains(source,['< ',baseName]));
        verifyTrue(testCase,contains(source, ...
            sprintf("mode = '%s';",entries{i,2})));
    end
end

function testSharedRuntimeFixesUniformMixAndDelegatesRelationMode(testCase)
    file = fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m');
    verifyTrue(testCase,isfile(file));
    if ~isfile(file)
        return;
    end
    source = fileread(file);

    verifyTrue(testCase,contains(source, ...
        "policy = 'uniform_mix';"));
    verifyTrue(testCase,contains(source, ...
        'relation_mode = Algorithm.relationPairMode('));
    verifyTrue(testCase,contains(source, ...
        "case 'weighted'"));
    verifyTrue(testCase,contains(source, ...
        "case 'curriculum'"));
    verifyTrue(testCase,contains(source, ...
        'GetRelationPairs(Input,Catalog)'));
    verifyTrue(testCase,contains(source, ...
        "strcmp(relation_mode,'weighted')"));
    verifyFalse(testCase,contains(source, ...
        'if prev_p_err > tau_err'));
end
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
matlab -batch "f=fullfile('D:\PlatEMO-master\PlatEMO-master\PlatEMO','Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_FixedRelationModes.m'); r=runtests(f); disp(r); assert(all([r.Passed]));"
```

Expected: the test command exits non-zero because the new runtime and three
entry classes do not exist. The failure must name missing files or empty
`which` results, not a MATLAB syntax error in the test.

### Task 2: Add the shared fixed-mode runtime and three entries

**Files:**
- Create: `PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m`
- Create: `PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted.m`
- Create: `PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum.m`
- Create: `PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m`

- [ ] **Step 1: Create the shared runtime from the frozen runtime**

Create the new class with the complete `main`, `RuntimeDiagnostics`,
`NormalizeObjectives`, `GetRelationPairs_curriculum`, `KeepMostConfident`, and
`TrainRelationModel` implementations from
`REMO_new2_AdaMaO_SDEOnly_ModeBase.m`. Apply exactly these controlled
substitutions:

```matlab
classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase < ALGORITHM
% Shared UniformMix runtime for fixed relation-training ablations.
```

Replace the candidate-policy lookup:

```matlab
policy = 'uniform_mix';
```

Replace only the adaptive relation-mode block with:

```matlab
relation_mode = Algorithm.relationPairMode( ...
    prev_p_err,tau_err,mean_conf,diagnostics.coverage);
```

Replace the original protected candidate-policy method with:

```matlab
methods (Access = protected)
    function mode = relationPairMode(~,varargin) %#ok<STOUT>
        error('AdaMaO:MissingRelationPairMode', ...
            'A fixed relation-pair mode is required.');
    end
end
```

Do not modify the frozen source file. The new runtime must retain the existing
switch branches:

```matlab
switch relation_mode
    case 'weighted'
        [XXs,YYs,WWs] = GetRelationPairs_confidence( ...
            Input,Catalog,confidence);
    case 'curriculum'
        [XXs,YYs] = GetRelationPairs_curriculum( ...
            Input,Catalog,confidence,0.80);
        WWs = [];
    otherwise
        [XXs,YYs] = GetRelationPairs(Input,Catalog);
        WWs = [];
end
```

and the existing training dispatch:

```matlab
[net,TrainIn_struct,p_err] = TrainRelationModel( ...
    XXs,YYs,WWs,w_min,strcmp(relation_mode,'weighted'));
```

- [ ] **Step 2: Create the weighted entry**

```matlab
classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted < ...
        REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase
% <2026> <multi/many> <real> <expensive>
% UniformMix with agreement-weighted relation-network training

    methods (Access = protected)
        function mode = relationPairMode(~,varargin)
            mode = 'weighted';
        end
    end
end
```

- [ ] **Step 3: Create the curriculum entry**

```matlab
classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum < ...
        REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase
% <2026> <multi/many> <real> <expensive>
% UniformMix with confidence-filtered relation-network training

    methods (Access = protected)
        function mode = relationPairMode(~,varargin)
            mode = 'curriculum';
        end
    end
end
```

- [ ] **Step 4: Create the original-unweighted entry**

```matlab
classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Original < ...
        REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase
% <2026> <multi/many> <real> <expensive>
% UniformMix with original unweighted relation-network training

    methods (Access = protected)
        function mode = relationPairMode(~,varargin)
            mode = 'conservative';
        end
    end
end
```

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the Task 1 MATLAB command again.

Expected: `2 Passed, 0 Failed, 0 Incomplete`.

### Task 3: Verify syntax and frozen-baseline invariants without optimization runs

**Files:**
- Verify: the five added MATLAB files
- Verify unchanged: `REMO_new2_AdaMaO_SDEOnly_UniformMix.m`
- Verify unchanged: `REMO_new2_AdaMaO_SDEOnly_ModeBase.m`

- [ ] **Step 1: Run the existing frozen-hash test only**

```powershell
matlab -batch "f=fullfile('D:\PlatEMO-master\PlatEMO-master\PlatEMO','Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_DualPBIContVersions.m'); n='test_REMO_new2_AdaMaO_DualPBIContVersions/testHardBaselineBlobsRemainFrozen'; s=testsuite(f,'Name',n); assert(numel(s)==1); r=run(s); disp(r); assert(r.Passed && ~r.Failed && ~r.Incomplete);"
```

Expected: `1 Passed, 0 Failed, 0 Incomplete`. This selection must not execute
`testFiveVersionsCompleteOnePostInitializationUpdate`.

- [ ] **Step 2: Run MATLAB Code Analyzer on only the added files**

```powershell
matlab -batch "d=fullfile('D:\PlatEMO-master\PlatEMO-master\PlatEMO','Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly'); n={'REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m','REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted.m','REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum.m','REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m',fullfile('tests','test_REMO_new2_AdaMaO_FixedRelationModes.m')}; c=0; for i=1:numel(n), q=checkcode(fullfile(d,n{i}),'-id'); c=c+numel(q); for j=1:numel(q), fprintf('%s:%d %s %s\n',n{i},q(j).line,q(j).id,q(j).message); end, end; fprintf('CHECKCODE_TOTAL=%d\n',c); assert(c==0);"
```

Expected: `CHECKCODE_TOTAL=0`.

- [ ] **Step 3: Review the complete Git diff**

```powershell
git -C D:\PlatEMO-master status --short
git -C D:\PlatEMO-master diff --check
git -C D:\PlatEMO-master diff --stat
git -C D:\PlatEMO-master diff -- "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly"
```

Expected: only the new runtime, three new entries, and focused test are present
on the implementation branch; `git diff --check` reports no errors.

### Task 4: Commit the verified implementation

**Files:**
- Commit: the five added MATLAB files

- [ ] **Step 1: Stage only the implementation files**

```powershell
git -C D:\PlatEMO-master add -- `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m" `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted.m" `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum.m" `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m" `
  "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_FixedRelationModes.m"
```

- [ ] **Step 2: Verify the staged diff**

```powershell
git -C D:\PlatEMO-master diff --cached --check
git -C D:\PlatEMO-master diff --cached --stat
```

Expected: five added files and no whitespace errors.

- [ ] **Step 3: Commit**

```powershell
git -C D:\PlatEMO-master commit -m "feat: add fixed AdaMaO relation training modes"
```
