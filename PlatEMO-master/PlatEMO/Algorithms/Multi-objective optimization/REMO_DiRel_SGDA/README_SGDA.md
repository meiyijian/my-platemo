# REMO_DiRel_SGDA

SGDA means **Structure-Guided Difficulty-aware Arbitration**. This variant does not modify `REMO_DiRel` or `REMO_DiRelV2`.

## Main Idea

`REMO_DiRel_SGDA` separates relation experts by semantic scope:

- The full expert is trained on all objectives and is the only expert allowed to represent full-objective relation evidence.
- Group experts are trained on structure-aware objective groups and only express local preferences inside those groups.
- Group/easy experts are queried only when the full expert has low margin, low confidence, or an uncertain/nondominated relation.
- If group experts agree, their result becomes an auxiliary tie-break score.
- If group experts conflict, SGDA keeps the relation uncertain and falls back toward uncertainty, archive novelty, and diversity.

## Structure Grouping

`BuildObjectiveGroups_SGDA(PopDec, PopObj, d_score, cfg)` uses no additional calls to `Problem.Evaluation`.

It normalizes existing decision and objective samples, samples local neighbor/random pairs, and builds a local response signature:

```matlab
Gamma(j,p) = (F(a,j) - F(b,j)) / (norm(X(a,:) - X(b,:)) + eps)
```

Rows of `Gamma` describe local change patterns of objectives. Objective similarity is computed from row correlations. Only strong positive similarity is used for grouping. SGDA never uses `abs(rho)` because strong negative similarity indicates conflict, not redundancy.

The group difficulty is:

```matlab
D_group = mean(D_member) + 0.5 * std(D_member)
```

Groups with low difficulty, low internal difficulty spread, and high structure reliability are marked as easy groups.

## Arbitration Score

`ScoreCandidates_SGDA` uses this shape:

```matlab
score = fullWeight * R_full ...
      + tieWeight  * R_aux ...
      - beta       * uncertainty ...
      - lambda     * disagreement ...
      + gamma      * archiveNovelty
```

`R_aux` is active only when the full expert is uncertain. A confident full expert cannot be overridden by any group expert.

## Files

- `REMO_DiRel_SGDA.m`: main PlatEMO algorithm.
- `BuildObjectiveGroups_SGDA.m`: structure-guided objective grouping.
- `BuildPairBank_ParetoPBI_SGDA.m`: subset Pareto relation labels with PBI fallback.
- `TrainRelationExperts_SGDA.m`: full/group expert training.
- `ScoreCandidates_SGDA.m`: full-first relation arbitration.
- `SelectRelationAnchors_SGDA.m`, `SelectTopDiverse_SGDA.m`, `BuildSubsetReferenceVectors_SGDA.m`: support modules.
- `LogDiagnostics_SGDA.m`: per-generation diagnostics.
- `test_units_SGDA.m`: unit tests for grouping/arbitration invariants.
- `run_smoke_SGDA.m`: DTLZ2 M=5 smoke run.

## Parameters

The public algorithm parameters are:

```matlab
platemo('algorithm', {@REMO_DiRel_SGDA, gmax, K_ens, alpha_d, fullMargin, fullConfThr, groupConfThr}, ...)
```

Defaults:

- `gmax = 1000`
- `K_ens = 5`
- `alpha_d = 0.5`
- `fullMargin = 0.20`
- `fullConfThr = 0.55`
- `groupConfThr = 0.60`

## Diagnostics

`Algorithm.metric.Diag` is filled best-effort with:

- groups and group sizes,
- group difficulty and reliability,
- full expert uncertain ratio,
- tie-break active ratio,
- group conflict ratio,
- selected mode histogram: full, group tie-break, uncertainty/novelty,
- full-only, group-only, and fused score mean/variance.

## Tests

From MATLAB after adding PlatEMO to the path:

```matlab
test_units_SGDA
run_smoke_SGDA
```
