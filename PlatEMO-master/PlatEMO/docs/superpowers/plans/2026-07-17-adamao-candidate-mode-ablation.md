# AdaMaO Candidate-Mode Ablation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the existing SDE-only algorithm as CurrentGate and add four testable PlatEMO variants whose only experimental difference is the candidate-mode policy.

**Architecture:** Four thin algorithm classes inherit one shared `ALGORITHM` subclass containing a snapshot of the CurrentGate runtime with candidate routing replaced by a pure policy function. The existing CurrentGate source and its private dependencies remain untouched. A dedicated `RandStream`, seeded from `Algorithm.run`, isolates mode draws from the optimizer's global RNG.

**Tech Stack:** MATLAB R2020b+, PlatEMO, MATLAB Unit Test framework, Statistics and Machine Learning Toolbox, Deep Learning Toolbox.

---

### Task 1: Add policy tests and verify RED

**Files:**
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly_Policies.m`

- [x] **Step 1: Test the required pure routing behavior**

Create function-based tests that call:

```matlab
[mode,pInd,progress] = ResolveSDECandidateMode( ...
    policy,indicatorAvailable,FE,InitFE,maxFE,u);
```

The test cases must assert these exact outcomes:

```matlab
% Deterministic boundaries
ResolveSDECandidateMode('always_explore',true,150,100,200,0)   % explore, P=0, progress=.5
ResolveSDECandidateMode('always_indicator',true,150,100,200,0) % indicator, P=1, progress=.5
ResolveSDECandidateMode('always_indicator',false,150,100,200,0)% explore, P=1, progress=.5

% Uniform mixture
ResolveSDECandidateMode('uniform_mix',true,150,100,200,0.49)   % indicator, P=.5
ResolveSDECandidateMode('uniform_mix',true,150,100,200,0.50)   % explore, P=.5

% Corrected linear schedule
ResolveSDECandidateMode('linear_schedule',true,100,100,200,0)  % explore, P=0
ResolveSDECandidateMode('linear_schedule',true,150,100,200,.49)% indicator, P=.5
ResolveSDECandidateMode('linear_schedule',true,200,100,200,.99)% indicator, P=1
```

Also assert clamping below `InitFE`, clamping above `maxFE`, the `maxFE<=InitFE` fallback, equal progress for equivalent post-initialization fractions, model-unavailable fallback for both random policies, and an error for an unknown policy or a draw outside `[0,1)`.

- [x] **Step 2: Test the four PlatEMO entry classes**

Assert that `which` locates the four class files in the SDE-only directory and that each source contains its intended strategy literal:

```text
always_explore
always_indicator
uniform_mix
linear_schedule
```

- [x] **Step 3: Run the focused test and verify RED**

```powershell
matlab -batch "results=runtests('Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly_Policies.m'); assertSuccess(results)"
```

Expected: FAIL because `ResolveSDECandidateMode` and the four algorithm classes do not exist.

### Task 2: Implement the pure policy function and verify GREEN

**Files:**
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/ResolveSDECandidateMode.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/CreateSDECandidateModeStream.m`

- [x] **Step 1: Implement corrected progress and routing**

Use this public contract:

```matlab
function [mode,pInd,progress] = ResolveSDECandidateMode( ...
    policy,indicatorAvailable,FE,InitFE,maxFE,u)
```

The function normalizes string input to a lower-case character vector, computes:

```matlab
if maxFE <= InitFE
    progress = 1;
else
    progress = min(1,max(0,(FE-InitFE)/(maxFE-InitFE)));
end
```

and maps policy to `P_ind` as `0`, `1`, `0.5`, or `progress`. It validates stochastic draws with `isscalar(u) && isfinite(u) && u>=0 && u<1`. If `indicatorAvailable` is false it returns `explore`; otherwise random policies return `indicator` exactly when `u < pInd`.

- [x] **Step 2: Implement and test the dedicated stream**

Use this public contract:

```matlab
function [modeStream,modeSeed] = CreateSDECandidateModeStream(runId)
```

Empty, non-scalar, non-finite, or non-positive run identifiers fall back to 1; valid identifiers are rounded down to positive integers. Compute a seed from `10000000+runId`, bounded to the `uint32` seed range, and construct `RandStream('mt19937ar','Seed',modeSeed)`. Tests must prove that equal run identifiers give equal draw sequences, different identifiers give different sequences, and creating/drawing the dedicated stream leaves `rng` unchanged.

- [x] **Step 3: Run the policy behavior tests**

Run the focused test again. The pure policy and stream assertions should pass; class-discovery assertions should remain RED because the entry classes are not yet present.

### Task 3: Add the shared runtime and four entries

**Files:**
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_ModeBase.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_AlwaysExplore.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_AlwaysIndicator.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_UniformMix.m`
- Create: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly_LinearSchedule.m`

- [x] **Step 1: Build the shared base from CurrentGate**

Copy the computational behavior of `REMO_new2_AdaMaO_SDEOnly.m` into the base class, including its ten `ParameterSet` values and its local helper implementations. Immediately after the initial `Problem.Evaluation`, add:

```matlab
InitFE     = Problem.FE;
policy     = Algorithm.candidatePolicy();
modeStream = CreateSDECandidateModeStream(Algorithm.run);
```

Keep the existing HPC progress unchanged:

```matlab
ratio = Problem.FE / Problem.maxFE;
```

At the start of every loop iteration, before any relation-pair early exit, consume the dedicated draw for stochastic policies:

```matlab
if ismember(policy,{'uniform_mix','linear_schedule'})
    u = rand(modeStream,1);
else
    u = 0;
end
[candidate_mode,p_ind,modeProgress] = ResolveSDECandidateMode( ...
    policy,~isempty(IndicatorModel),Problem.FE,InitFE,Problem.maxFE,u);
```

Keep CurrentGate's empty-relation-pair early exit before indicator training; there is no candidate set on that path, and moving model training across the relation-model block would alter the baseline's global-RNG and computation order.

The base protected method `candidatePolicy` throws an error so only a concrete entry class supplies a policy. The shared runtime must not construct or reseed the global RNG.

- [x] **Step 2: Add the four thin entry classes**

Each entry inherits `REMO_new2_AdaMaO_SDEOnly_ModeBase` and overrides only:

```matlab
methods (Access = protected)
    function policy = candidatePolicy(~)
        policy = '<exact-policy-literal>';
    end
end
```

Use the exact four literals listed in Task 1. Give every class a PlatEMO metadata comment so it appears as an expensive real-valued multi/many-objective algorithm.

- [x] **Step 3: Verify GREEN**

Run the focused policy test and the pre-existing SDE-only test. Expected: all tests pass.

### Task 4: Verify RNG isolation and run smoke optimizations

**Files:**
- Test: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_SDEOnly_Policies.m`

- [x] **Step 1: Verify source-level stream invariants**

Assert the shared base records `InitFE` after initial evaluation, preserves `ratio = Problem.FE / Problem.maxFE`, calls `ResolveSDECandidateMode`, draws through `rand(modeStream,1)` rather than `rand` on the global stream, and consumes that draw before the empty-relation-pair early exit.

- [x] **Step 2: Run four small-budget smoke tests**

For each new class, construct the problem and algorithm directly, set the same global seed immediately before `Algorithm.Solve(Problem)`, pass the same `run`, and use DTLZ2 with a budget large enough for at least one post-initialization generation. Assert a nonempty three-objective result and no undefined-function, protected-access, or path-resolution errors.

- [x] **Step 3: Re-run the complete focused suite**

Run both test files together with a fresh MATLAB process and require zero failures.

### Task 5: Final integrity review

**Files:**
- Review: `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/`
- Review: `docs/superpowers/specs/2026-07-17-adamao-candidate-mode-ablation-design.md`

- [x] **Step 1: Verify CurrentGate is unchanged**

```powershell
Get-FileHash -Algorithm SHA256 'Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/REMO_new2_AdaMaO_SDEOnly.m'
```

Expected hash: `73F1CE787679D9E4AAB308110FC49A1218718A4108F99C6C51287FD253687110`.

- [x] **Step 2: Review created files and forbidden scope changes**

Confirm no existing source or test file changed, CurrentGate still contains its original three-mode gate, and the four new policies do not use `p_err`, `coverage`, or `degeneracy` to select candidate mode.

- [x] **Step 3: Do not commit automatically**

Leave all new files in the shared workspace for user review. Do not stage or commit them unless the user explicitly requests it.
