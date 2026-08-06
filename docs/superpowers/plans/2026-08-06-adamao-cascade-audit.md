# AdaMaO Cascade Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不修改冻结基线、不改变正常随机轨迹、不向优化器反馈 shadow 真值、也不增加正式 FE 的前提下，实现 AdaMaO 候选池级反事实审计，先验证“关系粗筛造成覆盖缺口”和“关系拒绝—指标认可的正分歧能够识别有用假阴性”是否真实存在。

**Architecture:** 新增一个与 `UniformMix_Original` 行为严格配对的只读 `CascadeAudit` 算法入口；从冻结的 `AdaMaOSelection.m` 建立独立审计副本，使其在保持原选择结果的同时暴露完整累积候选池、关系分数、全池 SDE-SVR 分数、actual top-30% 粗筛状态、指标是否真正参与和最终选择状态。shadow 层仅对允许的 DTLZ/WFG 合成问题调用 `CalDec/CalObj/CalCon`，以冻结参考前沿计算候选边际 IGD+、greedy-batch 覆盖损失和“替换基础批次最差指标候选”后的净 replacement gain。主审计按 post-initialization 进度捕获实际 indicator 代；版本化 numeric schema 保存候选级和代级记录；独立实验目录负责协议、断点续跑、验证、负对照和 run-level 分析。

**Tech Stack:** MATLAB R2021b, PlatEMO, MATLAB Unit Test, Deep Learning Toolbox, Statistics and Machine Learning Toolbox, Git.

---

## 0. Scope, invariants, and evidence boundary

Git commands run from:

```text
D:\PlatEMO-master
```

MATLAB commands run from:

```text
D:\PlatEMO-master\PlatEMO-master\PlatEMO
```

Algorithm directory:

```text
PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly
```

This plan implements **P0 / Stage 0 only**. It does not implement CA-CSR, online rescue, adaptive quota, or a final-paper performance comparison.

Non-negotiable invariants:

1. Do not edit the existing UniformMix, fixed relation-mode, HybridPBI, relation-network, `AdaMaOSelection`, or `RefSelect` files.
2. The operational relation mode is fixed to `conservative`: original `GetRelationPairs + DataProcess +` ordinary unweighted network training.
3. The operational candidate policy remains `uniform_mix`; its dedicated mode stream and draw position remain unchanged.
4. Shadow objective values never enter Population, Archive, relation training, indicator training, candidate selection, or environment selection.
5. `Problem.FE`, the global RNG state, the candidate-mode `RandStream`, final archive, and official evaluation batch must match `UniformMix_Original` exactly under paired seeds.
6. Shadow evaluation is allowed only for `DTLZ1`--`DTLZ7` and `WFG1`--`WFG9`; unsupported problems fail closed.
7. Main utility is marginal IGD+, not the ordinary marginal IGD in the old confidence probe.
8. Candidate-level rows are descriptive observations; inferential resampling uses run as the independent unit.
9. Stage 0 results can justify continue/stop decisions, not a claim that the final rescue algorithm already works.
10. H1/H2/H4 primary rows require actual indicator mode and successful operational SDE reranking; explore rows are separate controls.
11. H3/H4 truth is fixed-slot batch replacement gain, not merely positive individual candidate utility.
12. Audit runs require `Problem.maxRuntime=inf`; diagnostic time is recorded separately and never used as baseline runtime evidence.

Freeze these current blobs in the new regression test:

| File | Git blob |
|---|---|
| `REMO_new2_AdaMaO_SDEOnly_UniformMix.m` | `523deb264424909d84334bdeacf81377352eca8a` |
| `REMO_new2_AdaMaO_SDEOnly_ModeBase.m` | `411a828ae68111e4ede67709386832624d4c38a4` |
| `private/HybridPBI_Classification.m` | `342658c826e2f1f96937f1d300896b14331d2e2d` |
| `private/GetOutput_PBI.m` | `de30b2e915908e6d205134168a0cf87894a97cb9` |
| `private/AdaMaOSelection.m` | `b2483d050e91586356871d56e4bbb6ca4cc0aabd` |
| `private/RefSelect.m` | `241e8940b34b1c1c8cdc092d1db3cecf9407bb86` |
| `REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase.m` | `15a22a6ada08b679e5a0810a4170518fcddcde95` |
| `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m` | `02f1f019f0bf6f80c456d2c1fa4dae8763a3499f` |

Primary formulas:

```text
u_t(x) = IGD+(A_t) - IGD+(A_t union {x})
q_R, q_I in [0,1], where 1 is the best percentile rank
d(x) = q_I(x) - q_R(x)
coarse set = relation top max(20, ceil(0.30*|C_t|))
K = actual official batch size after remaining-FE truncation
z_t = baseline-selected candidate with the lowest indicator rank
Delta_t(x) = IGD+(A_t union S_base) -
             IGD+(A_t union ((S_base minus {z_t}) union {x}))
normalized batch regret = 1 - U_greedy(coarse,K)/U_greedy(all,K)
```

The audit reference front is generated once per run with `Problem.GetOptimum(referenceRequest)` and frozen; every row records the actual returned count because `UniformPoint` may return fewer points than requested. Pre-registered first/late audit generations are recomputed against full `Problem.optimum` to test utility-rank and oracle-top-K sensitivity. Reference density is a diagnostic-accuracy parameter, never an optimizer parameter.

## 1. Versioned audit data contract

Create `CascadeAuditSchema.m` with exactly these columns and codes:

```matlab
function audit = CascadeAuditSchema()
    audit.version = 1;
    audit.columns.candidateRows = { ...
        'Run','Generation','FE','PostInitProgress','CandidateIndex', ...
        'CandidateMode','OperationalIndicatorUsed', ...
        'RelationScore','RelationPercentile','IndicatorScore', ...
        'IndicatorPercentile','PositiveDisagreement','CoarseKept', ...
        'BaselineSelected','ShadowFeasible','MarginalIGDp','Useful', ...
        'ReplacementGain','NearestSelectedDistance','OracleTopK', ...
        'IndicatorTopK','MaxPositiveDisagreement'};
    audit.columns.generationRows = { ...
        'Run','Generation','FE','PostInitProgress','CandidateMode', ...
        'OperationalIndicatorUsed', ...
        'CandidateCount','CoarseCount','BatchSize','ReferenceCount', ...
        'ShadowEvaluationCount','BaselineIGDp','RecallAtK','UsefulFNR', ...
        'SingleCoverageRegret','NormalizedBatchCoverageRegret', ...
        'RescueOpportunityRate','DisagreementEnrichment','CVKendall', ...
        'MaxDisagreementReplacementGain','MaxDisagreementSuccess', ...
        'OracleRejectedReplacementGain','ReplacementCapture', ...
        'BaselineBatchUtility','IndicatorTopKMeanUtility', ...
        'FullReferenceRankCorrelation','FullReferenceTopKOverlap', ...
        'AuditSeconds'};
    audit.codes.candidateMode.unknown   = 0;
    audit.codes.candidateMode.explore   = 1;
    audit.codes.candidateMode.indicator = 2;
    audit.candidateRows  = zeros(0,numel(audit.columns.candidateRows));
    audit.generationRows = zeros(0,numel(audit.columns.generationRows));
    audit.totalShadowEvaluations = 0;
    audit.totalAuditSeconds = 0;
end
```

Candidate utility tolerance is:

```matlab
tolerance = max(1e-12,1e-10*max(1,abs(baselineIGDp)));
useful = marginalIGDp > tolerance;
```

The schema permits `NaN` in indicator-dependent fields, rejected-only replacement gain for ineligible rows, and full-reference sensitivity fields on non-sensitivity generations. Primary analysis rejects any generation where `OperationalIndicatorUsed~=1`.

---

## Task 1: Add failing tests for pure audit semantics

**Files:**

- Create: `.../tests/test_REMO_new2_AdaMaO_CascadeAuditHelpers.m`
- Create later: `.../CascadeAuditSchema.m`
- Create later: `.../RankPercentileDescending.m`
- Create later: `.../ComputeMarginalIGDp.m`
- Create later: `.../ComputeCascadeBatchCounterfactual.m`
- Create later: `.../EvaluateCascadeShadow.m`
- Create later: `.../CrossValidateSDEIndicatorRanking.m`
- Create later: `.../BuildCascadeAuditRows.m`

- [ ] Add `functiontests(localfunctions)` and the same `setupOnce` root discovery pattern used by the existing tests.
- [ ] Assert schema version, exact ordered column names, mode codes, and empty row widths.
- [ ] Assert descending tie-aware percentile ranks:

```matlab
actual = RankPercentileDescending([9;7;7;1]);
verifyEqual(testCase,actual,[1;0.5;0.5;0],'AbsTol',1e-14);
verifyEqual(testCase,RankPercentileDescending(4),1);
verifyError(testCase,@() RankPercentileDescending([1;NaN]), ...
    'AdaMaO:InvalidCascadeRankScores');
```

- [ ] Assert exact marginal IGD+ on this fixture:

```matlab
archiveObj   = [0 2;2 0];
candidateObj = [0.5 0.5;3 3];
referenceObj = [0 0;1 1];
[utility,baseline,used,baselineDistance,candidateDistance] = ...
    ComputeMarginalIGDp( ...
    archiveObj,candidateObj,referenceObj);
verifyEqual(testCase,baseline,1.5,'AbsTol',1e-14);
verifyEqual(testCase,utility,[1.5-(sqrt(0.5)+0)/2;0], ...
    'AbsTol',1e-14);
verifyEqual(testCase,used,2);
verifyEqual(testCase,baselineDistance,[2;1],'AbsTol',1e-14);
verifyEqual(testCase,candidateDistance, ...
    [sqrt(0.5),sqrt(18);0,sqrt(8)],'AbsTol',1e-14);
```

- [ ] Add a fixed four-candidate batch fixture. The baseline batch contains two selected candidates; the fixed displaced slot is the selected candidate with the lowest indicator score. Assert exact baseline-batch IGD+, each rejected candidate's signed replacement gain (including one negative value), greedy-all/coarse K-batch utility, and normalized batch coverage regret.
- [ ] Assert a candidate can have `MarginalIGDp>0` while `ReplacementGain<0`; this is the regression test preventing H4 from reverting to the wrong truth label.

- [ ] Construct `DTLZ2('N',20,'M',3,'D',3,'maxFE',40)`, call `Initialization`, snapshot `Problem.FE` and `rng`, evaluate three shadow candidates, and assert exact FE and RNG equality afterward.
- [ ] Assert `EvaluateCascadeShadow` rejects an unsupported custom/non-DTLZ/WFG problem with `AdaMaO:CascadeAuditUnsupportedProblem`.
- [ ] Build a six-candidate synthetic trace with known relation/indicator ranks, utilities, and replacement gains. Assert exact `RecallAtK`, useful-FNR, single and normalized batch regret, rescue-opportunity rate, disagreement enrichment, max-positive-disagreement replacement gain, oracle rejected replacement gain, and replacement capture.
- [ ] Assert no-useful and no-indicator denominators produce `NaN` rather than zero.
- [ ] Assert primary-row eligibility requires actual indicator mode and `OperationalIndicatorUsed=true`; an explore row with otherwise identical scores must be excluded.
- [ ] Run the new helper test before implementation:

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); f=fullfile('Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_CascadeAuditHelpers.m'); r=runtests(f); disp(r); assertSuccess(r);"
```

Expected: FAIL because `CascadeAuditSchema` or another audit helper is undefined.

## Task 2: Implement pure rank, shadow-utility, reliability, and row builders

**Files:**

- Create: `.../CascadeAuditSchema.m`
- Create: `.../RankPercentileDescending.m`
- Create: `.../ComputeMarginalIGDp.m`
- Create: `.../ComputeCascadeBatchCounterfactual.m`
- Create: `.../EvaluateCascadeShadow.m`
- Create: `.../CrossValidateSDEIndicatorRanking.m`
- Create: `.../BuildCascadeAuditRows.m`

Freeze the public helper signatures as:

```matlab
[utility,baselineIGDp,referenceCount,baselineDistance,candidateDistance] = ...
    ComputeMarginalIGDp(archiveObj,candidateObj,referenceObj)
counterfactual = ComputeCascadeBatchCounterfactual( ...
    baselineDistance,candidateDistance,selectedMask,coarseMask,indicatorScore)
shadow = EvaluateCascadeShadow( ...
    Problem,candidateDec,archiveObj,archiveCon,referenceObj)
[tau,oofPrediction,foldID] = ...
    CrossValidateSDEIndicatorRanking(decisions,fitness,seed)
[candidateRows,generationRow,primaryEligible] = ...
    BuildCascadeAuditRows(run,generation,fe,progress,candidateMode, ...
    trace,shadow,counterfactual,cvKendall)
```

- [ ] Implement the schema exactly as specified in Section 1.
- [ ] Implement rank percentiles as `1-(tiedrank(-scores)-1)/(n-1)`, with the single-row value fixed at one and all nonfinite inputs rejected.
- [ ] Implement marginal IGD+ without constructing `SOLUTION` objects. The core calculation must be equivalent to:

```matlab
reference = referenceObj;
baselineDistance = inf(size(reference,1),1);
for i = 1:size(archiveObj,1)
    delta = max(archiveObj(i,:) - reference,0);
    baselineDistance = min(baselineDistance,sqrt(sum(delta.^2,2)));
end
baselineIGDp = mean(baselineDistance);
utility = zeros(size(candidateObj,1),1);
for first = 1:256:size(candidateObj,1)
    last = min(first+255,size(candidateObj,1));
    block = candidateObj(first:last,:);
    squaredDistance = zeros(size(reference,1),size(block,1));
    for objective = 1:size(block,2)
        shifted = max(block(:,objective)' - reference(:,objective),0);
        squaredDistance = squaredDistance + shifted.^2;
    end
    candidateDistance = sqrt(squaredDistance);
    gain = max(baselineDistance-candidateDistance,0);
    utility(first:last) = mean(gain,1)';
end
utility = max(utility,0);
```

- [ ] Return `baselineDistance` and the reference-by-candidate IGD+ distance matrix from `ComputeMarginalIGDp`; `ComputeCascadeBatchCounterfactual` reuses them for greedy K-batch utility and signed replacement gain without new objective calls.
- [ ] Validate finite, real, dimension-compatible inputs and require nonempty archive/reference sets.
- [ ] In `EvaluateCascadeShadow`, allow only class names matching `^(DTLZ[1-7]|WFG[1-9])$`; require `Problem.maxRuntime=inf`; save and restore global RNG with `onCleanup`; call `CalDec`, `CalObj`, and `CalCon`; assert `Problem.FE` is unchanged before returning.
- [ ] Use feasibility-first filtering. For the approved unconstrained suite, feasible archive/candidates are all rows. If a future approved problem has constraints, compute utility only against feasible archive rows and assign utility zero to infeasible candidates; fail if the archive has no feasible row.
- [ ] Return a struct with exact fields:

```matlab
shadow.CandidateObjectives
shadow.CandidateConstraints
shadow.FeasibleMask
shadow.MarginalIGDp
shadow.BaselineIGDp
shadow.BaselineDistance
shadow.CandidateDistance
shadow.ReferenceCount
shadow.ShadowEvaluationCount
```

- [ ] Implement `ComputeCascadeBatchCounterfactual`: K is `nnz(SelectedMask)`; eligible input requires all indicator scores finite; the displaced slot is the selected row with the lowest indicator score, ties going to the smallest stable candidate index. Greedy-all and greedy-coarse repeatedly select the candidate with the largest current IGD+ reduction, again breaking ties by stable index. Replacement gain is signed and computed for every relation-rejected candidate. Return normalized batch regret, oracle rejected gain, and explicit batch/replacement opportunity flags. `ReplacementCapture` belongs in `BuildCascadeAuditRows`, after the disagreement rescue has been identified.
- [ ] Define replacement success/opportunity with `max(1e-12,1e-10*max(1,abs(BaselineBatchIGDp)))`; do not reuse the archive-baseline scale. If `GreedyAllUtility` has no positive opportunity, return `NormalizedBatchCoverageRegret=NaN` and `HasBatchCoverageOpportunity=false` rather than one.
- [ ] Implement deterministic 5-fold SDE-SVR reliability. Use a task-local seeded partition, train the same RBF `fitrsvm` configuration used by AdaMaO, predict out-of-fold fitness, and return Kendall tau-b plus optional OOF predictions/fold IDs so coverage is testable. Snapshot/restore RNG. Return `NaN` when there are fewer than ten samples, fewer than three distinct target values, a fold fails, predictions are nonfinite, or either rank vector is constant.
- [ ] Implement `BuildCascadeAuditRows(run,generation,fe,progress,candidateMode,trace,shadow,counterfactual,cvKendall)` with ties resolved by descending indicator percentile, ascending relation percentile, then stable candidate index; do not use decision-space diversity as the main tie-break.
- [ ] Define oracle-top-K by sorting `[-MarginalIGDp,CandidateIndex]`; define indicator-top-K by `[-IndicatorScore,CandidateIndex]` only when all indicator scores are finite.
- [ ] Define high positive disagreement as the top 20% of rejected candidates by `d=q_I-q_R`; compute enrichment using positive replacement gain over all rejected candidates. Return `NaN` if the baseline positive-replacement rate is zero.
- [ ] Select `MaxPositiveDisagreement` only from relation-rejected candidates and only when the maximum `d` is strictly positive.
- [ ] Compute `SingleCoverageRegret=max(MarginalIGDp_all)-max(MarginalIGDp_coarse)` as the report's absolute single-candidate diagnostic. Compute `RescueOpportunityRate` among candidates that are both relation-rejected and indicator-top-K; do not substitute the positive rate over all rejected candidates.
- [ ] Compute each rejected candidate's normalized decision-space distance to the nearest baseline-selected candidate using `Xn=(X-lower)./(upper-lower)` and Euclidean distance divided by `sqrt(D)`; never normalize with the current candidate pool's min/max.
- [ ] Re-run the helper test and require all tests to pass.

## Task 3: Add failing selector-trace and integration tests

**Files:**

- Create: `.../tests/test_REMO_new2_AdaMaO_CascadeAudit.m`
- Create later: `.../private/AdaMaOSelectionCascadeAudit.m`
- Create later: `.../REMO_new2_AdaMaO_SDEOnly_CascadeAudit.m`

- [ ] Add the eight-blob frozen-source guard from Section 0.
- [ ] Assert the new selector source contains exactly one operational `OperatorGA` initialization, one loop `OperatorGA`, and one final `switch mode`, and does not contain `Problem.CalObj`, `Problem.CalCon`, `Problem.Evaluation`, `rng`, or `rand`.
- [ ] Add a smoke run using:

```matlab
parameters = {[],1,[],[],[],1,1,[],[],[],0,32,1};
Algorithm = REMO_new2_AdaMaO_SDEOnly_CascadeAudit( ...
    'parameter',parameters,'save',0,'outputFcn',@silentOutput,'run',1);
Problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',35);
rng(9001,'twister');
Algorithm.Solve(Problem);
```

- [ ] Assert `Problem.FE==35`, nonempty `candidateRows`/`generationRows`, exact schema widths, positive shadow count, finite relation scores/utility, at least one signed replacement gain, and exact shadow/time totals.
- [ ] Add exact paired trajectory replay against `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original` under the same parameters, run ID, and seed. Compare sorted final `[decs,objs,cons]`, FE, and complete RNG structs with zero tolerance.
- [ ] Before the paired replay, execute one short warm-up run so lazy toolbox initialization is outside the comparison, matching the established confidence-probe test pattern.
- [ ] Assert every stored primary generation has indicator mode and `OperationalIndicatorUsed=1`; separately verify the dedicated mode-stream trajectory is unchanged even though noneligible explore generations are not shadow-evaluated.
- [ ] Assert every `BaselineSelected` row corresponds to an official evaluated decision in the paired generation fixture and that K equals the post-truncation official batch size.
- [ ] Run this test before implementation and require failure because the audit class/selector is missing.

## Task 4: Implement the non-perturbing selector trace

**Files:**

- Create: `.../private/AdaMaOSelectionCascadeAudit.m`
- Do not modify: `.../private/AdaMaOSelection.m`

- [ ] Start from the exact current `AdaMaOSelection.m` blob `b2483d050e91586356871d56e4bbb6ca4cc0aabd`.
- [ ] Preserve the complete candidate-generation loop and all three operational selection branches line-for-line.
- [ ] Change only the public signature to:

```matlab
function [Next,trace] = AdaMaOSelectionCascadeAudit( ...
    Problem,Ref,Input,wmax,Smodel,q_keep,n_min,n_max)
```

- [ ] After the existing operational `Next` has been produced, call a local read-only trace builder. The builder must not feed any value back into `Next`.
- [ ] Return exactly these trace fields:

```matlab
trace.Candidates
trace.RelationScores
trace.IndicatorScores
trace.CoarseMask
trace.SelectedMask
trace.IndicatorAvailable
trace.OperationalIndicatorUsed
trace.CandidateMode
trace.Valid
```

- [ ] Build the coarse mask with the exact current rule:

```matlab
nKeep = min(size(all_candidates,1), ...
    max(20,ceil(0.30*size(all_candidates,1))));
[~,order] = sort(relationScores,'descend');
coarseMask = false(size(all_candidates,1),1);
coarseMask(order(1:nKeep)) = true;
```

- [ ] In the copied indicator branch, expose whether coarse-set `predict` actually succeeded as `OperationalIndicatorUsed` without changing the selected candidates. Score the full pool with `predict(Smodel.IndicatorModel,all_candidates)` only for the trace. If the model is absent, either operational/full prediction throws, length mismatches, or any prediction is nonfinite, the generation is not eligible for primary H1/H2/H4 analysis.
- [ ] Map `Next` back to the unique candidate pool with row membership; return a well-shaped invalid/empty trace when candidate generation yields no pool.
- [ ] Re-run the selector source test. Do not yet expect the full integration test to pass until Task 5.

## Task 5: Implement the parallel CascadeAudit algorithm

**Files:**

- Create: `.../REMO_new2_AdaMaO_SDEOnly_CascadeAudit.m`
- Do not modify: any baseline algorithm or helper.

- [ ] Copy the operational chain from `UniformMix_RelationModeBase` into the parallel class and fix relation-pair construction to the original conservative path:

```matlab
[XXs,YYs] = GetRelationPairs(Input,Catalog);
[TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
```

- [ ] Preserve existing network architecture, training, SDE fitness, RBF-SVR, `ResolveSDECandidateMode`, dedicated `modeStream`, fallback, official `Problem.Evaluation`, Archive update, and `RefSelect` behavior.
- [ ] Extend the parameter list only at the end:

```matlab
[k,gmax,q_keep,lambda0,w_min,n_min,n_max,tau_err, ...
 use_indicator,debug,auditCheckpoints,referenceRequest, ...
 fullReferenceSensitivity] = Algorithm.ParameterSet( ...
 6,3000,0.80,0.35,0.30,4,6,0.35,1,0, ...
 [0.10 0.30 0.50 0.70 0.90],512,1);
```

- [ ] Validate strictly increasing `auditCheckpoints` in [0,1], positive integer `referenceRequest`, logical scalar `fullReferenceSensitivity`, `Problem.maxRuntime=inf`, and the approved static problem classes before initialization.
- [ ] Generate and freeze `auditReference=Problem.GetOptimum(referenceRequest)` once per run; record the actual returned row count. Retain `Problem.optimum` only for first/late checkpoint sensitivity.
- [ ] Initialize `audit=CascadeAuditSchema()` and assign it to `Algorithm.metric.cascadeAudit` before the loop.
- [ ] Replace only the selector call with `[Next,trace]=AdaMaOSelectionCascadeAudit(...)`.
- [ ] Apply the existing fallback and remaining-FE truncation first, then recompute `trace.SelectedMask` against the actual official `Next`, so K is exact.
- [ ] Compute post-initialization progress as `(Problem.FE-InitFE)/max(Problem.maxFE-InitFE,1)`. For each checkpoint, audit the first subsequent generation satisfying `candidate_mode='indicator'` and `trace.OperationalIndicatorUsed=true`. Do not substitute an explore generation; unresolved checkpoints remain missing and are validated as insufficient data.
- [ ] On eligible audit generations, call `EvaluateCascadeShadow` on all traced candidates and the current Archive using the frozen audit reference, compute CV Kendall from the already available `Population.decs` and SDE `Fitness`, compute batch counterfactuals, build rows, append them, update shadow/time totals, and immediately persist `Algorithm.metric.cascadeAudit`.
- [ ] If full-reference sensitivity is enabled, recompute the first eligible checkpoint and any checkpoint at or above 0.90 with `Problem.optimum`; store marginal-utility Spearman rank correlation and oracle-top-K overlap. Never use the full-reference result to change operational selection.
- [ ] Perform official `Problem.Evaluation(Next)` exactly once and only after the read-only audit. Never evaluate rejected candidates through `Problem.Evaluation`.
- [ ] Keep shadow objectives and constraints in local variables only; do not store them in `Smodel`, `Population`, or `Archive`.
- [ ] Re-run helper and integration tests. Require exact baseline trajectory, FE, and RNG parity.

## Task 6: Add failing protocol, persistence, and analysis tests

**Files:**

- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_CascadeAudit/tests/test_CascadeAuditHarness.m`
- Create later: `.../CascadeAuditProtocol.m`
- Create later: `.../run_CascadeAudit_experiment.m`
- Create later: `.../ValidateCascadeAuditResultFile.m`
- Create later: `.../analyze_CascadeAudit.m`

- [ ] Test exact profile sizes and settings:

| Profile | Problems | M | Runs | maxFE | gmax | auditCheckpoints | referenceRequest | full sensitivity |
|---|---|---:|---:|---:|---:|---|---:|---:|
| `smoke` | DTLZ2 | 3 | 1 | 35 | 1 | [0] | 32 | 1 |
| `pilot` | DTLZ2, DTLZ4, DTLZ7, WFG4, WFG6, WFG8 | 10 | 2 | 300 | 500 | [.20 .50 .80] | 256 | 1 |
| `screening` | same six | 10,20 | 10 | 500 | 3000 | [.10 .30 .50 .70 .90] | 512 | 1 |

- [ ] Fix requested decision dimension to D=30 for pilot/screening and save both requested and actual D in metadata. Verify every WFG job satisfies `D>K=M-1` and `K` is a multiple of `M-1`.
- [ ] Test stable seed generation from `(profile,problemIndex,M,run)` and assert no runner/helper changes the caller RNG.
- [ ] Build valid and malformed synthetic MAT files; validate profile/job metadata, schema version, FE completion, row widths, actual-indicator eligibility, candidate-index uniqueness within generation, finite required columns, binary masks, signed replacement gain, reference/shadow/time consistency, and allowed NaN locations.
- [ ] Test analysis on a synthetic fixture where real positive disagreement has larger normalized replacement capture than random/diversity-matched/shuffled/reverse controls and CV Kendall separates positive/negative replacement gain; assert all expected CSV files and the MAT analysis artifact.
- [ ] Test that explore-mode rows never enter H1/H2/H4 primary summaries, raw cross-problem IGD+ is never pooled, and multiple generations in one run are reduced to one run-level contribution before bootstrap.
- [ ] Test sparse/full-reference sensitivity pass, fail, and unavailable states.
- [ ] Test an insufficient-data fixture and require `INSUFFICIENT_DATA`, not a false pass/fail.
- [ ] Run harness tests before implementation and require failure because protocol/harness functions are missing.

## Task 7: Implement reproducible Stage 0 experiment harness

**Files:**

- Create: `.../CascadeAuditProtocol.m`
- Create: `.../run_CascadeAudit_experiment.m`
- Create: `.../ValidateCascadeAuditResultFile.m`
- Create: `.../analyze_CascadeAudit.m`
- Create: `.../README.md`

- [ ] Implement the three frozen profiles from Task 6. The runner must execute `smoke`, then `pilot`; `screening` is launched only after reviewing the pilot decision file.
- [ ] Seed immediately before `Algorithm.Solve`, restore caller RNG with `onCleanup`, suppress GUI output, and save one MAT file per job through a temporary file followed by an atomic move.
- [ ] Save exactly: `metadata`, `cascadeAudit`, `finalPopulation`, official `IGD`, official `IGDp`, observed total runtime, separately accumulated audit runtime, and `validation`.
- [ ] Count and report shadow evaluations and audit time separately. Never add shadow calls to official FE or use the audit-instrumented runtime as evidence about deployable algorithm overhead.
- [ ] Validate an existing result before skipping it; rerun corrupt or incomplete jobs.
- [ ] In the analyzer, produce:

```text
CascadeAudit_generation_metrics.csv
CascadeAudit_problem_summary.csv
CascadeAudit_disagreement_quintiles.csv
CascadeAudit_negative_controls.csv
CascadeAudit_gate_auc.csv
CascadeAudit_decision.csv
CascadeAudit_analysis.mat
```

- [ ] Compute all summaries first per run, then aggregate across runs. Use a fixed local analysis stream and run-level bootstrap; never treat candidate rows as independent replicates.
- [ ] Define deterministic diagnostic controls per generation:

```text
RealDisagreement: replacement gain/capture of rejected candidate with max positive d
RandomRescue: exact mean replacement gain/capture over all rejected candidates
DiversityMatchedRandom: exact mean within the target candidate's
                        nearest-selected-distance quintile
ShuffledDisagreement: mean replacement gain/capture over 100
                     within-generation indicator-rank permutations
ReverseDisagreement: replacement gain of rejected candidate with minimum d
OracleRescue: maximum signed replacement gain over all rejected candidates
IndicatorAll: greedy batch utility and oracle recall of indicator top-K
```

- [ ] Compute disagreement quintiles within each rejected set, not after pooling different generations/problems.
- [ ] Restrict primary summaries to `CandidateMode=indicator` and `OperationalIndicatorUsed=1`. Aggregate checkpoint generations within run before cross-run inference. Use normalized batch regret and replacement capture for cross-problem aggregation; raw IGD+ remains problem-specific.
- [ ] Compute gate AUROC with `CVKendall` as generation-level score and positive signed replacement gain as the label. Report per-problem direction, valid-run count, run-cluster bootstrap 95% CI, and the pre-registered `CVKendall>0` policy's mean net replacement gain and negative-replacement rate. Output `INSUFFICIENT_DATA` unless both outcome classes and at least five valid runs exist.
- [ ] Freeze the screening decision logic:

```text
H1_SCREEN_PASS:
  run-level bootstrap supports mean normalized greedy-batch coverage regret > 0
  and mean Recall@K < 0.95 in at least one DTLZ and one WFG problem.

H2_SCREEN_PASS:
  the pre-registered primary delta
  RealDisagreement replacement capture - ShuffledDisagreement capture
  is positive in both DTLZ and WFG families, and RealDisagreement also
  exceeds DiversityMatchedRandom in both families.

H4_GATE_PASS:
  CVKendall AUROC is estimable with run-cluster bootstrap CI lower > 0.5;
  CVKendall>0 lowers negative-replacement rate without lowering mean signed
  replacement gain versus ungated rescue; direction is positive in at least
  two thirds of estimable instances.

OVERALL:
  H1 fail -> STOP_CASCADE_BLIND_SPOT_STORY
  H1 pass and H2 fail -> STOP_INDICATOR_RESCUE_STORY
  H1/H2 pass and H4 fail -> CONTINUE_UNGATED_ONLY
  H1/H2/H4 pass -> CONTINUE_GATED_RESCUE_PROTOTYPE
  unmet sample requirements -> INSUFFICIENT_DATA
```

- [ ] State in README that pilot/screening are directional mechanism screens, not final statistical proof. Document exact run, resume, validate, and analyze commands.
- [ ] Report sparse/full-reference utility-rank correlation, oracle-top-K overlap, unresolved audit checkpoints, and the actual reference count. If sensitivity changes a continue/stop decision, force `INSUFFICIENT_DATA` and rerun with the full reference set.
- [ ] Because `Experiments` is ignored, force-track only source/tests/README when later committing; keep result MAT/CSV files ignored. Do not commit in this task unless the user explicitly asks.
- [ ] Run harness tests and require all pass.

## Task 8: Fresh verification and handoff

**Files:**

- Verify every new file above and the unchanged baseline manifest.

- [ ] Enumerate test names before any name-filtered execution so a typo cannot produce `0 Passed`.
- [ ] Run the focused helper, algorithm, and harness tests:

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); files={fullfile('Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_CascadeAuditHelpers.m'),fullfile('Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_CascadeAudit.m'),fullfile('Experiments','REMO_new2_AdaMaO_CascadeAudit','tests','test_CascadeAuditHarness.m')}; r=runtests(files); disp(r); assertSuccess(r);"
```

- [ ] Run the existing baseline regression suites:

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); files={fullfile('Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_SDEOnly.m'),fullfile('Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_SDEOnly_Policies.m'),fullfile('Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_FixedRelationModes.m'),fullfile('Algorithms','Multi-objective optimization','REMO_new2_AdaMaO_SDEOnly','tests','test_REMO_new2_AdaMaO_ConfidenceProbe.m')}; r=runtests(files); disp(r); assertSuccess(r);"
```

- [ ] Run `checkcode(file,'-id')` over every new MATLAB source/test file and require no actionable warnings.
- [ ] Run one smoke experiment to a new temporary result directory, validate the MAT file, analyze it, and verify all seven outputs are readable. Smoke may validate only instrumentation because it need not contain enough actual indicator checkpoints for H1/H2/H4.
- [ ] Recompute all eight frozen blobs and require exact matches.
- [ ] Inspect `git diff --check`, `git status --short`, and the complete diff. Preserve the user's existing untracked report and all unrelated work.
- [ ] Report four separate outcomes: implementation status, baseline parity, smoke-audit validity, and whether any research hypothesis has actually been tested. A smoke run validates instrumentation only; it must not be presented as H1/H2/H4 evidence.
- [ ] Stop after smoke verification and ask before starting the multi-run pilot, because the pilot consumes material compute even though it is still diagnostic.

---

## Completion criteria

Implementation is complete only when all of the following are true:

1. New focused tests and existing regression tests pass freshly.
2. All eight frozen blobs match.
3. Paired `CascadeAudit` and `UniformMix_Original` runs have identical official FE, RNG, and final trajectories.
4. Shadow evaluation produces nonempty full-pool candidate rows while leaving official state untouched.
5. Marginal IGD+, greedy-batch regret, signed replacement gain, diversity-matched controls, and all generation metrics pass exact synthetic fixtures.
6. The smoke runner can save, validate, resume, and analyze a result.
7. Primary analysis excludes explore/nonoperational-indicator rows and does not pool raw IGD+ across problems.
8. No claim is made that the cascade story is supported until pilot/screening evidence is actually analyzed.
