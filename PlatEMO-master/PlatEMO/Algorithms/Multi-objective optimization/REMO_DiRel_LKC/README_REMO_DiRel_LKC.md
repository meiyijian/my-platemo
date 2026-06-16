# REMO_DiRel_LKC

`REMO_DiRel_LKC` is a structure-aware variant of the original `REMO_DiRel`.
It keeps the original expensive-optimization loop and dual relation networks,
but changes the sub-network target space.

## Core Idea

Original `REMO_DiRel` ranks raw objectives by difficulty and trains the easy
network in a raw easy-objective subset.  That easy-network output is not a
full-objective dominance judgment.

This variant first uses the LKC idea from Liu et al. (2026): local LMVT slope
features are estimated from the already evaluated population, positive
structural similarity is used to group objectives, and each group is aggregated
with distance-to-center exponential weights.  Strong negative correlation is
treated as conflict and is never merged by `abs(corr)`.

Difficulty awareness is then applied to the structural groups:

- raw objective difficulty is still computed by `DifficultyProfiler`;
- group difficulty is `mean(d_score) + 0.5 * std(d_score)`;
- reliable and easy groups are selected for the sub-network;
- the sub-network learns relations only in the easy aggregated objective space.

## Arbitration Semantics

The full network predicts relations learned from the complete objective space.
If the full network is confident, it dominates the candidate score.

The sub-network is only a tie-break signal when the full network is uncertain.
It cannot override a confident full-network prediction.  If the full and sub
signals disagree, a disagreement penalty is applied.

## Main Files

- `REMO_DiRel_LKC.m`: PlatEMO algorithm entrypoint.
- `BuildObjectiveStructure_LKC.m`: LMVT/PCC/K-means structure grouping.
- `BuildStructureAwareEasySet.m`: group-level difficulty and easy group choice.
- `GetRelationPairsBudgeted_LKC.m`: Pareto-first relation pair labels.
- `ArbitratorScore_LKC.m`: full-first arbitration with subspace tie-break.
- `ArbitratedSelection_LKC.m`: GA candidate generation and scoring loop.
- `test_units_LKC.m`: local unit checks for grouping and dimensions.
- `run_smoke_LKC.m`: small DTLZ2 run.

## Usage

```matlab
platemo('algorithm', @REMO_DiRel_LKC, ...
        'problem', @DTLZ2, ...
        'M', 5, 'D', 7, ...
        'maxFE', 120, 'save', 0);
```

Parameter order is compatible with the original first seven parameters:

```matlab
{@REMO_DiRel_LKC, k_easy, tau_conf, alpha, k, gmax, K_ens, win_K, nCells, minRel, scalarGap}
```

Defaults are `-1, 0.3, 0.6, 6, 1000, 3, 3, 5, 0.65, 0.05`.

