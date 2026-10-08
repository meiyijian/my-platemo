# FE500 convergence figure validation

Date: 2026-10-04 (Asia/Shanghai). Scope: four independent convergence
figures and their captions, references, and analysis in the main performance
comparison of `HPDC-MaOEA.tex`.

## Data and aggregation

- Verified all 560 original MAT files: four problems, seven algorithms,
  runs 1–20, M=10. PACDIS uses
  `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`.
- WFG2 has actual D=31; DTLZ1, DTLZ6, and WFG7 have D=30.
- Verified source hashes, recorded FE, and IGDp against the unchanged
  13,661-row raw CSV. All 28 plotted means use exactly 20 runs.
- The unit-FE grid is 100–500. Each run holds its latest eligible saved
  value; no curve starts before initialization. PC-SAEA, HES-EA, and
  SAMOEA-TL2M start at FE329 for D=30 or FE340 for D=31.
- None of the 354 snapshots at FE>500 contributes a metric to a plotted
  mean. Later records establish observed coverage only. At the budget,
  the latest saved FE≤500 is used; no unsaved population is reconstructed.
- The reconstruction checker verified all 8,411 aggregate rows with
  maximum absolute mean error 1.1368683772161603e-13. It also verified
  initialization, duplicate FE, preserved increases, budget exclusion,
  short-run coverage, arithmetic means, and partial-run rejection.
- The mean trajectories retain 216 upward steps. No smoothing or
  monotonic transformation was applied.

| Problem | PACDIS mean at FE500 | Closest baseline mean at FE500 |
|---|---:|---|
| DTLZ1 | 137.229053 | REMO: 155.901593 |
| DTLZ6 | 13.320764 | SSDE: 14.065582 |
| WFG2 | 1.368622 | HES-EA: 1.597492 |
| WFG7 | 3.127175 | HES-EA: 4.642579 |

Raw CSV SHA256:
`41704668137a6bb1fade4bf06793ed20667f0be5ab2d258cf57addbcda5343ce`.
Mean CSV SHA256:
`cb00e0ca740c8c86e9e4915c31ae3c775be1ccfeb444619dbd0e6d5c71c720e4`.

## Figures and manuscript

- Four separate vector PDFs are exactly 88×70 mm; SVG text remains
  editable and each PNG is exported at 600 dpi. Regular text is at least
  7.5 pt. All figure fonts are embedded.
- Inspected all four rendered figures for clipping, legend obstruction,
  marker visibility, and labels. No layout defect was found.
- Compiled the final manuscript twice successfully. The 17-page PDF
  has no undefined reference/citation or Overfull warning. The new
  references render as Figs. 3–6 on page 8; four independently numbered
  figures appear on page 11. Inspected pages 8, 11, and 12 at their actual
  manuscript layout.
- Native `pdffonts` confirms that all 31 manuscript font resources are
  embedded, including the existing Type3 glyph programs.
- Manuscript source SHA256:
  `5bcd5172b2c33ed03fc91f26af27a40706d3bb593ff8d38fc866d1abc01887f6`.
  Final PDF SHA256:
  `1fbab6414cf0d12f45781c0a7e1f2cb468a27fce61ba6b17edf673176820d71e`.

## Independent review

The read-only reviewer `review_fe500_figures` independently inspected
source files, original MAT data, manuscript prose, captions, rendered
figures, and the compiled PDF. The reviewer did not rely on the author's
validation report and did not edit the deliverables.

- Independently reconstructed every mean from all 560 original files;
  maximum absolute difference from the aggregate CSV was 5.68e-14,
  with no incomplete sample denominator.
- Checked every new factual sentence. The stated endpoint order,
  initialization costs, DTLZ6 late crossover (FE430), and WFG trends
  match the saved data. The claims remain limited to the selected
  problems and complete-algorithm performance.
- Mechanical checks M1, M2, M3/M4/M8/M9, M5/M16, M6, M10, M11,
  M12, M13, M14, M17, and M18 each returned zero matches. Part B,
  decomposition, and the S1 auxiliary check also returned zero matches.
- M15 returned four matches, all `!` in the four LaTeX `[!tbp]`
  float-placement modifiers; the prose contains no exclamation mark.
  M7's lists carry distinct information and are not decorative triads.
- Semantic checks of numerical support, claim scope, component causality,
  figure mapping, and rendered text passed.
- Final review: **0 CRITICAL / 0 MAJOR / 0 MINOR** findings in this scope.

## Existing items outside this change

Four existing manuscript TODOs remain. The GGP appendix still produces
the pre-existing duplicate PDF destination warning for `table.1` after
resetting its table counter. These items are outside the convergence-figure
change; this validation does not claim submission readiness for the whole
manuscript. The legacy composite convergence figure is not included in
the active manuscript.
