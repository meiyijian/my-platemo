# WFG3 failure-case convergence at FE500

## 2026-10-13 PIEA replacement

The active WFG3 figure replaces SAMOEA-TL2M with PIEA using original runs
1--20, preserving the 88 x 70 mm style, gray color, plus marker and placement.
PIEA starts at FE100 and reaches an FE500 mean of 0.94563543, compared with
1.43866196 for PACDIS and 1.26301468 for REMO. Both PIEA and PACDIS initialize
with 100 evaluations. The final narrative uses these curve endpoints,
independently of the finalized workbook means in the main table.

The shared `../fe500_convergence/piea_metrics.py` reads the source-hashed
reconstruction cache for missing PIEA IGD+ trajectories. Rebuild the cache
with the MATLAB script described in that directory, export with
`python figures/build_convergence_wfg3_fe500.py --export`, and run
`python experiments/fe500_convergence_wfg3/validate.py`.
All 140 original sources are hash-checked; seven curves retain all 20 runs.
Earlier notes below record the original SAMOEA-TL2M extension.

## Historical notes before PIEA replacement

This extension adds the WFG3 ten-objective failure case to Section 4.2. It
preserves the four existing favorable-case figures and their source exports.
Seven algorithms use runs 1--20; the actual recorded dimension is D=31.
The source manifest identifies and hashes all 140 MAT files. Only stored
`result(:,1)` FE coordinates and `metric.IGDp` values are read.

## Rebuild

From the manuscript directory, run:

```text
python figures/build_convergence_wfg3_fe500.py
```

Use `--export` only to refresh the CSV from the local MAT sources listed in
`source_manifest.json`. The script imports the existing FE500 plot style and
alignment functions; it does not regenerate the other four figures.

## Estimator and budget policy

- Arithmetic means of all 20 runs on the integer FE grid 100--500.
- Initialization counts toward FE. A curve starts only at the first saved FE.
- Hold the latest eligible saved value between checkpoints. At duplicate FE,
  use the final record. No backward extrapolation, smoothing, or monotonic envelope.
- Ignore every metric value recorded at FE > 500. A later snapshot establishes
  observation coverage only. It never supplies a plotted metric value.
- Reject partial run coverage; the denominator is always 20 at plotted points.
- PACDIS, REMO, HES-EA, and SAMOEA-TL2M have snapshots at FE=500 in every run.
  PC-SAEA holds FE495 values; CSEA holds FE478--481 values; SSDE holds values
  from FE473--500, depending on the run. See `coverage_fe500.json`.
- This figure uses the same eligible-snapshot policy as the four existing curves.
  Main-table terminal results can include small budget overshoots, so their values
  need not match every curve endpoint. The three endpoints quoted in the new
  paragraph all come from exact FE500 snapshots and agree with the main table.

## Evidence boundary

The plot supports a whole-algorithm performance limitation. It does not identify
the causal module, measure reference-direction coverage, or compare retained and
rejected candidate quality. The manuscript labels the screening/coverage account
as a hypothesis requiring those measurements. No algorithm code or new evaluations
are involved in this addition.

The PDF is vector artwork with embedded fonts, matching the existing 88 x 70 mm
figures. SVG, 600 dpi PNG, figure manifest, and PDF-rendered QA image accompany it.
The manuscript groups all five separately numbered figures on one float page,
using the same display scale for all five. The original four PDF assets and their
data remain unchanged. Each displayed figure retains ordinary text above 7 pt.

Run `python experiments/fe500_convergence_wfg3/validate.py` from the manuscript
directory to independently reconstruct all means from the local MAT sources and
check the new prose's numerical claims. See `validation.json` for machine-readable
results and `revision_audit.md` for the editorial and rendered-page checks.
