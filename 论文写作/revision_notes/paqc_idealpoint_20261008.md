# PAQC common ideal-point manuscript revision (2026-10-08)

## Scope

Revise `HPDC-MaOEA.tex` under the requested common ideal-point formulation. The two PAQC signals use the current population minimum for direction construction, cosine association, and projection distances. This task changes manuscript definitions only; executable algorithm files, archived trajectories, experimental tables, and numerical results remain untouched.

## Definition and consistency changes

- Define the common displacement `y_i = f_i - z*`, with no additional objective scaling.
- Construct adaptive directions from nonzero nondominated displacements; use uniform directions under the stated fallback conditions.
- Associate solutions and representatives using the same displacement coordinates.
- Use direct unit-vector projections in both PBI calculations.
- State the ideal-point score and label rules and handle absent valid representative directions explicitly.
- Explain that each nondominated solution aligns with its own adaptive direction: its perpendicular distance is zero and its continuous score ranks radial distance to the ideal point. Uniform directions retain the full PBI expression.
- Synchronize the abstract, overview, method equations, PAQC pseudocode, figure caption, and interpretation of `O=Z` as the displacement-coordinate origin.
- Retain all archived numerical results with their original protocol identity. The abstract and Experimental Studies state that matched validation is necessary before assigning these measurements to the revised formulation. GGP references use recorded scores and the archived grouping protocol.

## Independent review

An independent reviewer read the latest manuscript and diff, reran the mechanical gate, inspected the geometric figure, and applied the paper-writing semantic checks. Final result: zero CRITICAL, zero MAJOR, and zero unresolved MINOR findings within this revision.

Resolved findings:

1. S15/S17/S9: distinguish revised formulation conventions from archived experimental evidence; remove the wording that identifies archived Full as the current implementation of the new geometry.
2. S9/S4: add an explicit pseudocode assignment `S_i = 1` at the ideal point, where cosine association is undefined.

Independent mechanical evidence (`all` includes pre-existing manuscript wording; `changed` scans this revision):

```text
M1: all=0, changed=0
M11: all=39, changed=0
M2: all=16, changed=2
M3M4M8M9: all=0, changed=0
M6: all=0, changed=0
M5M16: all=18, changed=0
M10: all=0, changed=0
M17: all=0, changed=0
M18: all=0, changed=0
M12: all=0, changed=0
M13: all=2, changed=0
M14: all=13, changed=1
M15: all=4, changed=0
Precision: all=0, changed=0
Decomposition: all=0, changed=0
```

New hits and their disposition:

```text
M2, line 508: they do not specify a complete population
M2, line 619: The target fraction need not be attainable in a degenerate population.
M14, line 616: Otherwise
```

Both M2 hits give necessary factual limits; `Otherwise` is a suffix-regex false positive. No unexplained new mechanical hits remain. Original manuscript style issues fall outside this focused revision.

## Compilation and visual verification

- The built-in editor opened the TeX file, but its compiler returned `Unable to find standard directories for platform`. This is an environment failure, not a TeX diagnostic.
- The existing local MiKTeX compiler successfully compiled the final source twice to `HPDC-MaOEA.pdf`: 18 pages.
- No overfull boxes, unresolved references, or unresolved citations remain in the final log. All listed PDF fonts are embedded.
- Rendered all pages for an overview and inspected the method pages at full page resolution. Re-rendered the final PAQC pseudocode/figure page and evidence-scope page after the last corrections; no clipping or overlap appeared.
- Two existing PDF warnings remain: the imported schematic uses PDF 1.7 while the output targets 1.5, and the appendix reuses the `table.1` hyperlink destination. Both also appear in the pre-revision log.
- The original author placeholder remains. This check establishes correctness of the scoped manuscript revision, not submission readiness or experimental validation of the revised formulation.
- `git diff --check` passes. Only the TeX file and this review record belong to the focused commit.

## Rollback

Revert the focused commit and push normally to restore the prior manuscript definitions. Generated PDFs are ignored by Git; recompile the reverted TeX source to regenerate the corresponding PDF.
