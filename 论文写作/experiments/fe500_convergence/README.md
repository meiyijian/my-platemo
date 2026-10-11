# PACDIS FE500 independent convergence figures

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
