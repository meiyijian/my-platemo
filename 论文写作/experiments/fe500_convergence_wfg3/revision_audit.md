# WFG3 failure-case addition: verification record

Date: 2026-10-11. Scope: Section 4.2, the final paragraph of Section 5, and the
WFG3 convergence figure. No algorithm modifications or new optimization runs.

## Source and numerical checks

- Independently checked all 140 original MAT files against their SHA-256 hashes.
- Verified all 3,428 exported FE/IGDp rows against original stored results.
- Reconstructed seven mean trajectories on FE100--500 using a sequential traversal,
  independently of the drawing script's search-based alignment.
- All plotted means use 20 runs; values at FE > 500 never enter a mean.
- Verified PACDIS's nonincreasing mean curve, REMO's lower mean at every coordinate
  from FE340 through FE500, and SAMOEA-TL2M's higher FE340 mean and lower FE500 mean.
- Verified the rounded endpoint values 1.4387, 1.2630, and 0.89820, respectively.
- The figure keeps upward changes in other trajectories; no smoothing or monotonic
  transformation is used. `validation.json` records exact reconstruction error.

An independent reviewer separately read all 140 MAT files and confirmed these
data claims without reading MATLAB algorithm source.

## Editorial review

The independent paper-writing review requested two minor revisions: shorten the
failure-case heading and explicitly identify mean IGD+ in the conclusion.
Both revisions were applied; the follow-up review returned zero remaining
findings for the changed text and its evidential claims.

Both author and independent reviewer ran the mechanical Part C checks on changed
prose and the new caption. Final counts: M1, M11, M3/M4/M8/M9, M6, M5/M16, M10,
M17, M18, M12, M13, M14, M15, precision-pair and decomposition-count patterns: 0.
M2: 3 factual negations, all retained:

- `do not measure this proposed mechanism`: the curve does not test the hypothesis.
- `does not establish Pareto-front coverage`: bounds the existing group diagnostic.
- `do not enter the curves`: states the actual over-budget metric exclusion.

No coverage or candidate-quality measurements were invented. The proposed
screening/coverage mechanism remains a hypothesis. The addition does not resolve
other manuscript novelty, module-causality, or statistical-protocol concerns.

## PDF and figure checks

- New source figure: vector PDF, 88 x 70 mm, embedded fonts, editable SVG text,
  600 dpi PNG, no image clipping or legend/data overlap.
- All five independently numbered convergence figures share a float-only page.
  Their display width is 0.94 x 0.48 of the text width; ordinary figure text remains
  above 7 pt. Original four figure assets and numerical data remain unchanged.
- Two sequential MiKTeX builds in an isolated output directory both exited 0.
  Isolation avoids auxiliary-file races with automatic editor builds.
- Final manuscript: 16 pages; no undefined references, changed-label warnings,
  oversized floats, or overfull boxes in the final build log.
- Visually inspected the added discussion (page 9), all five curves and captions
  (page 10), and the conclusion (page 15). All visible PDF text remains within its
  page boundary. Existing underfull-box spacing notices are outside this revision.
- The journal guide could not be fetched during this task. This check establishes
  consistency with the existing manuscript, not certification of venue requirements.
