# PACDIS FE500 independent convergence figures

## 2026-10-13 DTLZ4 replaces the DTLZ6 convergence case

The active four favorable cases are DTLZ1, DTLZ4, WFG2 and WFG7, with
WFG3 retained as the separate failure case in the same manuscript float.
The manuscript explicitly identifies the four as lowest-endpoint-mean cases.
Main-table results, including the PIEA advantage on DTLZ6, are unchanged.

DTLZ4 uses the original runs 1--20 at M=10, D=30 and configured FE500.
The endpoint means are 0.6132632638 for PACDIS, 0.6347078213 for REMO
and 0.8198199986 for PIEA. PIEA leads early; PACDIS passes it later.
The main table's rank-sum test detects no difference between PACDIS and REMO.

`export_piea_dtlz4_metric_cache.m` reconstructs 18 missing PIEA DTLZ4
trajectories from saved populations. `piea_dtlz4_recomputed_igdp.mat`
stores source hashes, FE coordinates and unchanged FE counters; checks
against the stock metric and a complete stored trajectory both give zero error.
This additional cache preserves the original cache used by WFG3 and the
historical DTLZ6 figure. `piea_metrics.py` selects it only for missing DTLZ4
trajectories. The source manifest records both caches and reproduction scripts.

All figure dimensions, colors, markers, fonts, FE alignment and aggregation
rules remain unchanged. The replacement audit is in
`../dtlz4_curve_20261013/`; the previous DTLZ6 assets are historical files.

## Historical notes: 2026-10-13 PIEA replacement

The active seven-algorithm figures replace SAMOEA-TL2M with PIEA from the
original `10目标/n30/FE500/PIEA` directory, using runs 1--20. PIEA inherits
the previous gray color and plus marker. Physical dimensions, typography,
line weights, legend position, FE alignment and budget policy are unchanged.
DTLZ6 now favors PIEA at FE500 (5.6406 versus 13.3208 for PACDIS).

Some legacy PIEA files do not store a complete `metric.IGDp` trajectory.
`export_piea_metric_cache.m` reconstructs 72 missing trajectories from saved
populations for DTLZ6, WFG2, WFG7 and WFG3. It never evaluates objectives or
changes source MAT files. The cache `piea_recomputed_igdp.mat` includes raw
source hashes, actual FE coordinates and unchanged problem FE counters.
For each problem the script checks two snapshots against stock PlatEMO
IGDp and one complete stored trajectory; both maximum errors were zero.
`piea_metrics.py` rejects a cache whose source hash or FE coordinates differ.

Reconstruction, export and plotting are separate: run the MATLAB cache script
only when missing-metric raw files change, then run the existing Python
exporter and drawing script. Run `validate_convergence_fe500.py` after drawing.
The validation reconstructs all 28 means from 560 original run files and
checks that all plotted points use 20 runs and FE <= 500.

The main table uses the supplied finalized workbooks; it does not use this
run-1--20 subset. PIEA table means and curve endpoints therefore need not match.
Earlier notes below describe the prior baseline set.

## Historical notes before PIEA replacement

This dataset supplies four separate ten-objective figures: DTLZ1,
DTLZ6, WFG2, and WFG7. Each figure compares PACDIS with REMO, SSDE,
PC-SAEA, SAMOEA-TL2M, CSEA, and HES-EA using runs 1–20.
The manuscript also includes a WFG3 failure case, documented in
[`../fe500_convergence_wfg3/README.md`](../fe500_convergence_wfg3/README.md).

## Data identity and FE policy

- Source root: `C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\FE500`.
- PACDIS source class: `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`.
- The configured budget is 500 real evaluations, including initialization.
- WFG2 has actual D=31; the other selected problems have D=30. All use M=10.
- `convergence_igdp_fe500.csv` preserves all 13,661 recorded snapshots from
  560 source files, including terminal overshoots. Its column format and
  original data remain unchanged. `source_manifest.json` records each file's
  SHA-256, actual FE coverage, identity, and dimension.
- Each run is aligned to FE=100,…,500 using its latest saved value with
  saved FE at most the grid coordinate. Metrics at FE>500 never contribute.
  A recorded terminal FE above 500 establishes run coverage only.
- No value is drawn before the first recorded snapshot or beyond the observed
  run interval. Duplicate FE entries use the last snapshot. Every plotted
  point averages all 20 runs; partial-run averages are rejected.
- PC-SAEA, HES-EA, and SAMOEA-TL2M initialize with 11D−1 evaluations, hence
  start at FE329 or FE340. These intervals are initialization costs, not
  missing early recordings.
- Endpoints are latest eligible saved values, not an exact reconstruction of
  unsaved populations at FE500. The main tables summarize terminal results,
  which can include a small FE overshoot and can therefore differ.

## Outputs and reproduction

Run, in order, using a Python environment with NumPy, pandas, SciPy,
Matplotlib, PyMuPDF, and Pillow:

1. `export_convergence_fe500.py` in this directory.
2. `../../figures/build_convergence_fe500.py`.
3. `validate_convergence_fe500.py` in this directory.
4. Compile `../../HPDC-MaOEA.tex` twice from its directory.

The drawing script writes `fig_convergence_fe500_<problem>_m10.pdf`, `.svg`,
`.png`, and `_manifest.json` under `../../figures/`. Each image contains one
problem at 88×70 mm, with editable SVG text and a 600 dpi PNG counterpart.
PDF is the manuscript format. `../../figures/figure_convergence_fe500.tex`
defines four independent figures and labels.

`convergence_mean_igdp_fe500.csv` contains the 28 arithmetic-mean curves,
including FE and the number of runs at each point. `convergence_at_500.json`
and `convergence_fe500_coverage.json` record endpoints and coverage.
The legacy composite `fig_convergence_fe500_m10` files remain historical
artifacts; this workflow does not regenerate or include them.

The independent reconstruction checker revisits every original MAT file,
verifies source hashes, and reconstructs every plotted mean with a sequential
snapshot traversal. It checks budget exclusion, initialization, duplicate FE,
non-monotone values, incomplete-run rejection, vector geometry, embedded
fonts, and raster resolution. `validation.json` records these results.
`validation.md` records manuscript layout and independent review.
