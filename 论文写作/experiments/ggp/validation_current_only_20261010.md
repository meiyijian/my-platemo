# Current-convergence presentation revision (2026-10-10)

## Scope

Section 4.4 and its main table now compare PAQC H with equal-quota representative-margin A using current convergence precision only. The abstract, method cross-reference, and conclusion use this same scope. Final-retention and direction-only results and the unused appendix TeX files were removed from the manuscript assets. The original checkpoint, run, comparison, and provenance exports remain unchanged.

The main table generator now emits only `table_ggp.tex`. Rebuilding the table does not recreate the appendix or restore omitted columns. The presentation does not claim superiority over every grouping rule or a causal improvement in final IGD+.

## Numerical and statistical verification

- `build_ggp.py --from-exports` passed: 5440 checkpoints, 160 run records, 34 checkpoints per run, 20 runs per configuration, and 32 original comparisons.
- The original Holm family remains two outcomes by two controls by eight configurations. The eight displayed tests retain the original adjusted p-values; no smaller-family recalculation was performed.
- An independent reviewer recomputed the original Holm adjustment and checked the displayed means and run-level sample standard deviations. All eight displayed adjusted p-values are approximately 0.0028103693.
- Overall current precision remains 73.680147% versus 35.830147%. The difference is 37.85 percentage points, the ratio is 2.056373, and the average additional low-g count is 9.4625 of 25 selected solutions.
- DTLZ7's disconnected-region qualification remains in the text. The analysis uses saved trajectories with zero additional real evaluations.

## Writing and output checks

Independent text/data/generator review returned zero CRITICAL or MAJOR findings for this change. Mechanical checks cover the abstract, Section 4.4, table, and modified conclusion sentences.

| Check | Hits | Disposition |
| --- | ---: | --- |
| M1 em-dashes | 0 | Clear |
| M11 passive voice | 0 | Clear |
| M2 antithesis | 0 | Clear |
| M3/M4/M8/M9 flourishes and empty setup | 0 | Clear |
| M6 openers | 0 | Clear |
| M5/M16 word scan | 2 | Existing defined mode names `ambiguity-oriented` and `indicator-oriented`; retained |
| M10, M17, M18, M12, M13, M14, M15, Part B | 0 each | Clear |

The final source compiled twice with pdfLaTeX to a 16-page PDF. No undefined references/citations, LaTeX warnings, or overfull boxes remain in the final log. Existing underfull line-spacing notices occur in references. All PDF fonts are embedded.

Rendered inspection covered the abstract, Section 4.4, revised Table 4, and conclusion/reference pages. Table 4 uses compact mean (SD) cells. Explicitly restoring full column height after flushing the double-column table queue fixes an otherwise nearly empty left column on the conclusion page.

The existing author/affiliation placeholders remain. This check validates the requested revision, not full submission readiness.
