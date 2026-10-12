# WFG3 failure-case convergence at FE500

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
