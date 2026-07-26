# AdaMaO Confidence Validity Probe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-perturbing UniformMix confidence probe, reproducible experiment runner, result validation, and CSV analysis that separately tests PBI agreement confidence and network softmax confidence against independent objective-based outcomes.

**Architecture:** Preserve the existing UniformMix implementation byte-for-byte and add a parallel ALGORITHM class in the same parent directory so it resolves the correct private helpers. Pure public helpers create deterministic PBI audit pairs, objective truth, candidate network predictions, survival horizons, and marginal IGD. An ignored-but-force-tracked experiment folder follows the existing CPR protocol/runner/validator/analyzer pattern.

**Tech Stack:** MATLAB R2021b, PlatEMO, MATLAB Unit Test framework, Deep Learning Toolbox, Statistics and Machine Learning Toolbox, Git.

---

## Frozen scope and paths

Git commands run from `D:\PlatEMO-master`.

MATLAB commands run from `D:\PlatEMO-master\PlatEMO-master\PlatEMO`.

Approved design:

`docs/superpowers/specs/2026-07-26-adamao-confidence-validity-probe-design.md`

Do not modify the six baseline files and blob hashes listed in the design.

### Task 1: Add failing helper and schema tests

**Files:**

- Create: `PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ConfidenceProbeHelpers.m`
- Create later: `.../SDEConfidenceProbeSchema.m`
- Create later: `.../BuildSDEConfidencePairAudit.m`
- Create later: `.../SDEConfidenceTrueRelation.m`
- Create later: `.../PredictSDEConfidenceCandidatePairs.m`
- Create later: `.../CompleteSDEConfidenceCandidateAudit.m`
- Create later: `.../UpdateSDEConfidenceProbe.m`

- [ ] Write tests that assert the schema contains four tables and distinct `PBIConfidence`/`NetworkConfidence` fields.
- [ ] Write a synthetic four-solution fixture with fixed EvalIDs, objectives, Catalog, confidence, and SDE fitness.
- [ ] Assert `PairConfidence=sqrt(c_i*c_j)`, cross-group orientation always places the predicted-good endpoint on the left, and sampling is deterministic.
- [ ] Capture `rng` before and after pair construction and assert exact equality.
- [ ] Assert constrained/Pareto truth returns `+1/-1/0` correctly.
- [ ] Use an anonymous deterministic network and mapminmax fixture to assert network pair probabilities, labels, and confidence.
- [ ] Assert candidate outcomes include dominance, nondominance, exact marginal IGD, and immediate survival.
- [ ] Assert horizon updates set H1 at the current transition, H3 after three transitions, and keep right-censored values as NaN.
- [ ] Run the helper test and verify it fails because the helper functions do not exist:

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); r=runtests('Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/tests/test_REMO_new2_AdaMaO_ConfidenceProbeHelpers.m'); assertSuccess(r);"
```

Expected: FAIL with undefined `SDEConfidenceProbeSchema` or another missing probe helper.

### Task 2: Implement pure probe helpers

**Files:**

- Create: `.../SDEConfidenceProbeSchema.m`
- Create: `.../SDEConfidenceTrueRelation.m`
- Create: `.../BuildSDEConfidencePairAudit.m`
- Create: `.../PredictSDEConfidenceCandidatePairs.m`
- Create: `.../CompleteSDEConfidenceCandidateAudit.m`
- Create: `.../UpdateSDEConfidenceProbe.m`

- [ ] Implement `SDEConfidenceProbeSchema` with numeric column-name cells, mode codes, pair-type codes, `version=1`, and `maxPairsPerType=300`.
- [ ] Implement vectorized feasibility-first strict Pareto truth with tolerance.
- [ ] Implement all unordered current-population pairs, orient cross-group pairs good-first, compute geometric-mean confidence, and deterministically retain at most 300 rows from each pair type using confidence-sorted equal-spacing.
- [ ] Implement candidate-first network inference over every selected candidate × current anchor without RNG calls.
- [ ] Complete candidate pair truth only after normal evaluation; recompute SDE on the combined real-objective pool.
- [ ] Compute exact marginal IGD by reusing the optimum-to-current-ND distance matrix and removing current points dominated by each candidate.
- [ ] Implement H1/H3/current-ND/final-ND updates by `(Generation,EvalID)` and leave unavailable H3 observations NaN.
- [ ] Run the helper test and verify all helper tests pass.

### Task 3: Add the failing algorithm integration and trajectory tests

**Files:**

- Create: `.../tests/test_REMO_new2_AdaMaO_ConfidenceProbe.m`
- Create later: `.../REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe.m`

- [ ] Add a Git blob guard for all six frozen UniformMix files.
- [ ] Run DTLZ2 with `M=3,D=3,N=20,maxFE=36`, `gmax=1`, `run=1`, seed 9001.
- [ ] Assert one post-initialization update creates nonempty solution, PBI pair, network pair, and candidate rows.
- [ ] Assert all evaluated solutions have unique positive EvalIDs and final probe FE equals 36.
- [ ] Reset seed 9001 and run original UniformMix under identical parameters.
- [ ] Sort final `[decs,objs]` rows and assert exact equality between baseline and probe plus identical FE.
- [ ] Run the integration test and verify failure because the probe class does not exist.

### Task 4: Implement the parallel ConfidenceProbe algorithm

**Files:**

- Create: `.../REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe.m`
- Do not modify: original UniformMix, ModeBase, HybridPBI, GetOutput_PBI, AdaMaOSelection, or RefSelect.

- [ ] Copy the ModeBase optimization chain and retain the original parameter defaults and uniform-mix stream draw.
- [ ] Pass sequential EvalIDs as `Problem.Evaluation(...,EvalIDs)`.
- [ ] Reuse the one existing HybridPBI call; never call it from diagnostics.
- [ ] Reuse the operational SDE result and deterministically capture solution/PBI pair rows.
- [ ] After `AdaMaOSelection` and before evaluation, run read-only candidate network inference.
- [ ] After the normal evaluation, complete true candidate relations and outcomes.
- [ ] After `RefSelect`, update H1/H3/current ND/final ND and assign the probe struct into `Algorithm.metric.confidenceProbe`.
- [ ] Update the metric every completed generation because PlatEMO terminates via `PlatEMO:Termination`.
- [ ] Run algorithm integration/trajectory tests and helper tests; require all pass.

### Task 5: Add failing experiment-harness tests

**Files:**

- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_ConfidenceProbe/tests/test_ConfidenceProbeHarness.m`
- Create later: `.../ConfidenceProbeProtocol.m`
- Create later: `.../ValidateConfidenceProbeResultFile.m`
- Create later: `.../AssignConfidenceProbeBins.m`
- Create later: `.../analyze_ConfidenceProbe.m`
- Create later: `.../run_ConfidenceProbe_experiment.m`

- [ ] Test smoke, pilot, screening, and confirmation job counts, dimensions, FE, runs, and deterministic seeds.
- [ ] Assert WFG3 requested D=30 becomes actual D=31.
- [ ] Assert quantile bins are deterministic, balanced within one observation, and do not mix strata.
- [ ] Create a valid synthetic run MAT and malformed variants; assert validator acceptance/rejection messages.
- [ ] Analyze synthetic runs containing both correct and incorrect high/low-confidence cases.
- [ ] Assert all seven required CSV files and the MAT analysis file are generated with required columns.
- [ ] Run harness tests and verify failure because protocol/validator/analyzer functions do not exist.

### Task 6: Implement protocol, runner, validator, analyzer, and README

**Files:**

- Create: `.../ConfidenceProbeProtocol.m`
- Create: `.../run_ConfidenceProbe_experiment.m`
- Create: `.../ValidateConfidenceProbeResultFile.m`
- Create: `.../AssignConfidenceProbeBins.m`
- Create: `.../analyze_ConfidenceProbe.m`
- Create: `.../README.md`

- [ ] Implement the four approved profiles and stable problem/M/run seeds.
- [ ] Seed immediately before `Algorithm.Solve` and restore the caller RNG with `onCleanup`.
- [ ] Use `outputFcn=@silentOutput`, validate existing results before skipping, and save via temporary MAT plus atomic move.
- [ ] Save `confidenceProbe`, metadata, finalPopulation, IGD, IGDp, and runtime with `-v7.3`.
- [ ] Validate schema version, metadata/job match, required numeric matrices, completed FE, unique EvalIDs, and finite confidence ranges.
- [ ] Assign bins within the prespecified run/generation/stratum blocks.
- [ ] Produce run-level bin rates, problem-level differences/AUROC, M-level hierarchical bootstrap, and the frozen decision gate.
- [ ] Document exact smoke, pilot, screening, confirmation, analysis, and resume commands.
- [ ] Force-add experiment source files because `.gitignore` ignores the whole Experiments directory; keep generated results ignored.
- [ ] Run all harness tests and require all pass.

### Task 7: Fresh verification and review

**Files:**

- Verify every file added above.

- [ ] Run focused helper, algorithm, and harness tests together.
- [ ] Run the existing DualPBI/UniformMix regression suite.
- [ ] Run `checkcode(...,'-id')` over every new MATLAB file and require zero issues.
- [ ] Run `run_ConfidenceProbe_experiment('smoke',tempdir)` and validate its result.
- [ ] Run `analyze_ConfidenceProbe(smokeResultDir)` and verify all seven CSV tables are readable and nonempty where applicable.
- [ ] Recompute all six frozen Git blobs and compare with the design manifest.
- [ ] Inspect `git diff --check`, `git status`, and the complete diff.
- [ ] Request an independent spec-compliance review, then a code-quality/statistical-validity review; fix every critical or important issue and re-run verification.
- [ ] Commit the design, implementation, tests, and force-tracked experiment harness on the user-approved master branch without pushing.

