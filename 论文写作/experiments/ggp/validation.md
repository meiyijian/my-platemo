# GGP integration validation — 2026-10-04

## Scope

Replaced the GGP placeholder in Section 4.4, added the complete two-outcome table, synchronized the GGP sentence in the conclusion, and kept experimental floats before the conclusion. Algorithm behavior and original experiment files remain unchanged.

## Data reconstruction

- `audit_ggp.m` completed on all 160 MAT files and 5440 checkpoints.
- Checked problem/run/seed identity, parameters, actual D=30, initial FE=100, terminal FE=300, per-round evaluation increments, stable evaluation IDs, and decision/objective records.
- Reconstructed current low-g labels and final-population membership directly from each saved trajectory.
- Reconstructed hybrid scores and selected groups; all groups contain exactly 25 solutions; no g boundary ties.
- Reconstructed checkpoint precision matches both existing analysis exports within absolute tolerance 1e-12.
- Production/frozen hashes agree for PBIQualityClassification, DiversifiedInfillSelection, GetRelationPairs, and RepresentativeBasedClassification.
- No additional objective evaluations or optimization runs.

## Statistics and reproducibility

- Statistical unit: mean of 34 checkpoints within one run, 20 paired runs per configuration.
- MATLAB signed-rank tests use integer hit differences to preserve exact ties. Denominator: 850 selected checkpoint positions per run.
- One Holm family contains all 32 PAQC-versus-control comparisons across two outcomes and eight configurations. Python independently verifies the adjusted-p arithmetic.
- Every run mean is checked against checkpoint aggregation. Every comparison mean and win/tie/loss count is checked against the exported run data.
- `build_ggp.py` passes with raw inputs present; `build_ggp.py --from-exports` passes using only the committed CSVs.
- A source manifest identifies 160 original MAT files by SHA-256. Raw MAT files remain in the experiment directory; committed checkpoint exports support table regeneration.
- Source-archive attributes preserve original bytes and recognize CRLF line endings. Staged Git blobs match every archived source hash.
- Descriptive bootstrap intervals resample whole paired runs within each fixed configuration, 10000 times, seed 20261004.

## Mechanical gate

Changed GGP text, table, and the added conclusion sentence:

```text
M1: 0
M11: 0
M2: 0
M3/M4/M8/M9: 0
M6: 0
M5/M16: 0
M10: 0
M17: 0
M18: 0
M12: 0
M13: 0
M14: 0
M15: 0
Part B: 0
```

Terms: PAQC H; direction control S; representative-margin control A; native binary label L. Counts: two outcomes, three equal-quota rules, eight configurations, 32 pairwise comparisons. No new empirical claim of diversity gain or final IGD+/HV causality.

## Independent review

Final status: CLEAN, zero surviving CRITICAL/MAJOR/MINOR findings. The first attempt stopped at the account usage limit; the reviewer resumed after reset and completed the checks.

- Independently verified all 214 source-manifest entries, including all 160 original MAT hashes.
- Independently recomputed checkpoint-to-run aggregation: maximum discrepancy 4.62e-14.
- Independently reconstructed 272 raw checkpoints across eight runs, covering every configuration: maximum precision discrepancy 5.00e-16.
- Independently reran all 32 MATLAB signed-rank tests using integer hit differences: maximum p-value discrepancy 4.44e-16; all win/tie/loss counts matched.
- Independently verified Holm arithmetic, reported means, differences, and comparison counts.
- Independently reran mechanical checks, including expanded intensifier scans: zero hits; manual decorative-triad check also passed.
- Semantic review confirmed outcome definitions, retrospective g analysis, A-versus-L distinction, descriptive native-group comparison, trajectory scope, and conclusion consistency.

## Compilation and rendered output

- Two consecutive successful pdflatex passes after the final numerical rebuild.
- PDF: 15 pages; no undefined references/citations, duplicate labels, errors, or overfull boxes.
- All 18 PDF fonts are embedded.
- Inspected rendered pages 11–14: GGP text, ablation floats, GGP table on page 13, sensitivity table and conclusion on page 14. Table values, bold maxima, and comparison symbols are legible.
- Existing underfull bibliography spacing warnings remain. MiKTeX prints an update-check advisory; compilation succeeds.
- Existing manuscript TODOs remain for the author list, abstract, main-experiment provenance/statistics, convergence figure, and final performance conclusion. The GGP result placeholder is resolved.

## Git scope

Only `HPDC-MaOEA.tex` and `experiments/ggp/` belong to this change. Existing Work2 changes and unrelated untracked files are excluded. The PDF is a local compilation artifact under the repository's existing ignore policy.
