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

## Follow-up presentation and layout revision — 2026-10-04

This section records the revision after `5b23425`; the earlier raw-data audit above belongs to that baseline.

### Presentation and table structure

- The main GGP table shows PAQC H and equal-quota margin A across all eight configurations. Appendix A retains the complete H/S/A table and all Direction findings, including higher convergence precision, the DTLZ7 retention reversal, and the absence of a direction-only online IGD+ control.
- Bold values denote maxima among the displayed rules. All comparison symbols retain the original family of 32 Holm-adjusted tests; removing columns does not change the correction family.
- The ablation results now form one table with 32 configurations, one caption, one note, and overall REMO-referenced counts: 19/2/11 for w/o CDIS, 20/1/11 for w/o PAQC, and 28/2/2 for Full. The current workbook values and comparison reference remain intact.
- `build_remo_reference.py --check` passes against both archived source workbooks. `build_ggp.py --from-exports` verifies 5440 checkpoints, 160 runs, and 32 comparisons and regenerates both GGP tables. All tracked numeric GGP exports and source manifests remain unchanged from `5b23425`.

### Layout and compilation

- Removed the forced page break before the ablation subsection. Applied ragged page bottoms consistently and bounded the separation between floats on dedicated float pages.
- The single ablation table uses 9-point text and increased row spacing. Both GGP tables span the text width with 9-point values.
- Kept the GGP heading and opening paragraph together. Queued the sensitivity table earlier so the barrier before the conclusion can flush it without leaving a mostly empty page.
- Two final consecutive pdflatex passes succeed. The PDF has 15 pages, no undefined references/citations, duplicate labels, errors, or overfull boxes.
- Visually checked all 15 pages, with detailed checks of the experimental tables and appendix. Page 11 contains the complete ablation table; page 12 contains the main GGP table and the start of its text; page 13 contains sensitivity results and the conclusion; page 15 contains the complete GGP appendix.
- Existing manuscript TODOs and bibliography underfull warnings remain. No experiment was rerun or new performance claim inferred for this presentation revision.

### Mechanical audit

`style_audit.py` now includes the appendix and complete table. M1, M11, M2, M3/M4/M8/M9, M6, M5/M16, M10, M17, M18, M12, M13, M14, M15, and Part B all report zero hits. The changed ablation caption and singular table reference were also inspected.

### Follow-up Git scope

This revision includes the main TeX file, GGP presentation/generation/validation files, and the ablation table plus its generator. Unrelated Work2 files and temporary review outputs are excluded.

### Independent follow-up review

Final status: CLEAN, zero surviving CRITICAL/MAJOR/MINOR findings. One S23 heading finding was fixed by changing the appendix heading to `Grouping Signals Favor Different Outcomes`; the reviewer then checked closure against the source and rendered PDF.

- Independently matched 32 main-table and 48 appendix-table mean/SD cells, their comparison symbols, maxima, and overall means to the CSV exports.
- Confirmed five numeric CSVs and the source manifest are unchanged from `5b23425`; independent Holm recomputation differed by at most 9.99e-16.
- Matched all 32 ablation configuration rows to the baseline and verified the workbook check and combined counts.
- Confirmed disclosure of Direction's convergence advantage, retention counterexamples, the A/L distinction, and the need for a separate online IGD+ replacement control.
- Independent mechanical scans reported zero hits in every applicable category; manual decorative-triad and semantic checks passed.
- Inspected pages 11, 12, 13, and 15 and the final compilation log. No clipping, overlap, undefined references, duplicate labels, or overfull boxes.
- The first follow-up review attempt stopped at a usage limit; the resumed reviewer completed this review. This follow-up did not repeat the baseline's original MAT reconstruction.
