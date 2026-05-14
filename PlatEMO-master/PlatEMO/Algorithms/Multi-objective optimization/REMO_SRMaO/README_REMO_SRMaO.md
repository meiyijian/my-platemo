# REMO_SRMaO

`REMO_SRMaO` is a clean experimental successor of `REMO_new2_AdaMaO` for the
paper story:

> State-aware relation surrogate-assisted expensive many-objective optimization.

It is intentionally added as a new algorithm directory so that the original
AdaMaO implementation can remain as an ablation baseline.

## Main Changes

- Uses APD/SDE binary state labelling instead of AdaMaO's high-dimensional
  PBI/radar-style selection.
- Uses binary preference pairs with continuous confidence weights.
- Trains a lightweight bagging ensemble of `patternnet` relation models.
- Computes three uncertainty signals: relation probability entropy, ensemble
  variance, and validation error-derived model trust.
- Replaces hard mode switching with continuous acquisition weights.
- Selects expensive evaluations with one acquisition:

```text
relation_score
+ adaptive_uncertainty
+ reference_coverage_gain
+ predicted_indicator_gain
```

- Uses APD environmental selection with robust t-DEA-style normalization.

## Files

- `REMO_SRMaO.m`: PlatEMO algorithm entry.
- `SRMaO_APDClassification.m`: APD/SDE binary labels and reference solutions.
- `SRMaO_BinaryRelationPairs.m`: weighted binary relation samples.
- `SRMaO_DropoutEnsemble.m`: lightweight ensemble relation surrogate.
- `SRMaOSelection.m`: unified state-aware acquisition.
- `SRMaO_RefSelectAPD.m`: APD environmental selection.
- `SRMaO_RuntimeDiagnostics.m`: coverage and degeneracy diagnostics.

## Parameters

Default parameter set:

```matlab
[k,gmax,K,q_keep,n_min,n_max,unc0,cov0,ind0,debug] = ...
    [6,3000,5,0.80,5,8,0.35,0.30,0.20,0]
```

- `k`: number of reference solutions used by the surrogate-assisted inner GA.
- `gmax`: maximum number of surrogate-screened candidates per generation.
- `K`: number of ensemble members.
- `q_keep`: acquisition quantile threshold.
- `n_min`, `n_max`: real evaluations per generation.
- `unc0`, `cov0`, `ind0`: base weights for uncertainty, reference coverage,
  and predicted indicator gain.
- `debug`: print runtime diagnostics when set to `1`.

## Smoke Test

Example command:

```matlab
addpath(genpath('PlatEMO'));
rng(2);
Algorithm = REMO_SRMaO('save',0,'outputFcn',@(varargin)[], ...
    'parameter',{6,40,1,0.75,2,3,0.30,0.30,0.10,1});
Problem = DTLZ2('M',10,'D',19,'N',40,'maxFE',108);
Algorithm.Solve(Problem);
```

## Suggested Next Experiments

Start with the instability target before running the full paper grid:

- DTLZ1-5, `M=10`, `maxFE=300/500/1000`, 30 runs.
- Compare against `REMO_new2_AdaMaO`, `REMO_MaO`, `REMO_new2_WFG10`,
  `REMO_C2RL`, and at least one R2/RVEA-style baseline.
- Track IGD, IGD+, HV or normalized HV, wall-clock time, and surrogate
  training time.

Then add ablations:

- Binary labels vs ternary labels.
- Ensemble vs single network.
- APD/SDE labels vs AdaMaO PBI labels.
- Continuous acquisition weights vs hard mode switching.
- Remove uncertainty, coverage gain, or predicted indicator gain.
