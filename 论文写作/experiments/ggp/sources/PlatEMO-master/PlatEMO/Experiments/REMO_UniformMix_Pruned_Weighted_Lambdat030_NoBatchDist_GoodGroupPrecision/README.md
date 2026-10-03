# NoBatchDist Good-group Precision experiment

This experiment records the **current NoBatchDist trajectory** and evaluates
PAQC's positive group against later outcomes. It is independent of the older
Lambdat030 GGP results, which used an in-batch distance term and maxFE=500.

## Formal protocol

- Algorithm: `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`, with
  parameters `{gmax,pMix,rGood,qKeep,nMax}={3000,0.50,0.25,0.70,6}`.
- Problems: DTLZ2, DTLZ4, DTLZ5, DTLZ7; `M=10,20`; requested `D=30`; `N=100`;
  `maxFE=300`; run IDs 1–20: **160 independent runs**.
- DTLZ2/4/5 reproduce the prior formal GGP problem set. DTLZ7 was described
  there as an optional negative control and is the fourth problem here.
- Seed: the prior GGP formula `problemIndex*10000 + M*100 + run`, retaining
  indices DTLZ2=1, DTLZ4=2, DTLZ7=3, DTLZ5=7. Matching seeds do not make
  the old and new runs the same trajectory.
- The primary fixed-quota view selects the top 25% by PAQC's hybrid score.
  Direction score and anchor margin use the same quota as within-run controls.
  The dynamic binary label is analyzed separately at its natural quota.
- Primary truth: whether each checkpoint's selected evaluated solution is
  retained in the **final population**. Chance is the final-positive
  prevalence at that checkpoint; report precision and lift relative to it.
  The framework also records H1/H3 retention and archive nondominance truths.
- Aggregate checkpoints within each run and FE stage before treating runs as
  independent units. Paired comparisons are within the same run; the existing
  analysis reports raw and Holm-adjusted p-values. Stage results can be
  censored near termination and should be interpreted with their valid counts.

## Run from MATLAB

```matlab
addpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_GoodGroupPrecision');
maxNumCompThreads(1);
verify_NBGGP;  % production/audit equality gate; required before any result run
run_NoBatchDistGoodGroupPrecision('smoke');
analyze_NoBatchDistGoodGroupPrecision('smoke');
run_NoBatchDistGoodGroupPrecision('formal', ...
    'Problems',["DTLZ2","DTLZ4","DTLZ5","DTLZ7"]);
finish_NBGGP;  % validates 160 runs, analyzes, then writes completion marker
```

For a short first formal run, use `'Problems',"DTLZ2",'Ms',10,'Runs',1`.
Rerun the full formal command after an interruption: valid run files are
skipped; invalid existing files stop execution without being overwritten.
Run `finish_NBGGP` only after all configurations have finished.

Results are kept under this directory's `results/raw/formal/`, with summaries
in `results/analysis/formal/`. `results/FORMAL_COMPLETE.txt` is written only
after 160/160 files and 8/8 configurations pass validation. A smoke result
is never part of the formal analysis.

The audit class uses frozen copies of the PAQC helpers and the current
NoBatchDist candidate selector, plus stable evaluation IDs. `verify_NBGGP`
compares production and audit final results and RNG states on three small
budgets before permitting formal runs. If the production algorithm changes,
rerun this equality gate and review the frozen copies before interpreting
new data.
