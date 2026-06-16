# Workload 1: REMO_DiffUnc

## Goal

Create a REMO variant that improves expensive many-objective candidate selection by combining:

- relation prediction score;
- surrogate or model uncertainty;
- objective difficulty weight;
- diversity pressure from reference vectors or distance.

## Baselines

Minimum:

- REMO
- D_REMO
- K-RVEA

Optional:

- MOEA-D-EGO
- ParEGO
- PC-SAEA

## Benchmark Matrix

| Problem | Objectives | Seeds | Notes |
|---|---:|---:|---|
| DTLZ2 | 5, 10, 15 | 5 first, then 20 if time allows | smooth baseline |
| DTLZ3 | 5, 10 | 5 first | multimodal difficulty |
| WFG4 | 5, 10 | 5 first | deceptive/multimodal |
| WFG9 | 5, 10 | 5 first | hard WFG case |

## Suggested Score

Use a constrained candidate score:

```text
score(x) = relation_score(x)
         + alpha * uncertainty_score(x)
         + beta  * difficulty_weighted_improvement(x)
         + gamma * diversity_score(x)
```

Start with `alpha=0.2`, `beta=0.3`, `gamma=0.1`; tune only after the first ablation.

## Ablations

- REMO baseline.
- Full method.
- Full method without uncertainty.
- Full method without difficulty weights.
- Full method without diversity.

## Deliverables

- Algorithm folder or branch named `REMO_DiffUnc`.
- CSV result table with IGD, HV, runtime, and seed.
- One method section draft.
- One experiment section draft.
- One figure: IGD convergence or final IGD boxplot.

## Acceptance Criteria

The workload is usable for graduation if:

- the code runs on at least DTLZ2 and one WFG problem;
- at least one metric improves on at least two settings, or the failure pattern is clearly analyzed;
- ablations show which component contributes or fails.
