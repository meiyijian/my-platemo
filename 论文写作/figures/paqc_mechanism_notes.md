# PAQC illustration included in the manuscript

- Source supplied by the user: `figures/PAQC示意图` (PNG without a filename extension).
- Original raster asset: `figures/paqc_mechanism.png`, an identical binary copy; SHA-256 `4CF736AB4A74DADF7CF04C7E06F4208C07A8BC26E7A1FA92AF85FA8897C2503B`. The subsequently supplied `PAQC示意图.png` has the same hash.
- The artwork was developed in this conversation through generative image editing, using the user-supplied REMO geometric illustration as a reference. The manuscript acknowledges REMO through the existing bibliography key `ref:remo`; that bibliography entry remains incomplete in the source manuscript.
- The figure is a conceptual illustration of the adaptive direction branch, not a numerical example or experiment. The two-dimensional execution branch uses uniform directions. The illustrated adaptive directions use current nondominated objective vectors, not an oracle PF. The idealised choice O=Z makes the radial directions pass through their source points.
- The figure displays selected solutions; the shown counts do not specify the algorithm's positive-group quota. Nondominated membership alone does not guarantee positive-group membership. The schematic local boundaries and point assignments have not been numerically verified.
- The text connects the drawing to the existing direction, PBI, fusion and group equations, and restricts cross-label ordering reversals to the early-budget regime described by the existing proposition.
- Placement: introduced in Section 3.2, explained after the fusion/group equations in Section 3.2.3; Figure 2 appears on page 4 in the compiled seven-page manuscript.
- Validation: two consecutive successful pdflatex passes after placement changes; new cross-references resolve; no overfull boxes; rendered figure page inspected for clipping, overlap and readable labels.
- Existing manuscript issues remain: unresolved `sec:exp:paqc`, `sec:exp:candidate`, `sec:exp:sensitivity` references; incomplete bibliography and other TODOs. These are outside this insertion.

## Single-column vector revision

The user-supplied `PAQC示意图.svg` is editable vector artwork (no embedded image), but is not geometrically identical to the PNG. It omits the right-panel unlabelled candidate, omits the origin-to-P2 direction segment and v2 label, starts rays away from the indicated origin, and uses slightly different PF curves and corresponding coordinates. In particular, its P2 markers are below the drawn PF.

`build_paqc_vector.py` preserves those source files and creates `paqc_mechanism_single_column.svg` plus `paqc_mechanism_single_column.pdf`. The repair uses a common panel geometry, puts A/P1/P2 on the illustrative PF, restores the missing candidate, and constructs both complete blue rays through their source points. Both representative rays originate at O=Z and pass through the reference markers. Local schematic boundaries pass through the reference markers. These are geometric consistency corrections, not a numerical validation of the classification labels.

The two panels are stacked to fit one 88.56 mm column without reducing the 7--9 pt labels to the 3--4 pt size of a directly reduced horizontal version. The manuscript now includes the vector PDF via `width=\columnwidth` in a single-column figure environment. PDF inspection reports zero raster image objects. The diagram remains Figure 2 on page 4; the rendered page was visually checked. Rebuild with the script command in its docstring; the exporter prints dependency versions for traceability.

## Latest user-selected replacement

The user subsequently selected `paqc_reference_edit/paqc_geometry_v5_editable.svg` explicitly. This supersedes the stacked version above. The manuscript now includes its vector export `paqc_reference_edit/paqc_geometry_v5_editable.pdf`, retaining the selected artwork's horizontal panel arrangement and the requested single-column width. The original selected SVG is unmodified. `export_editable_pdf.py` resolves relative tspan font sizes in memory to work around CairoSVG's percentage-font rendering issue, then exports the PDF without raster image objects.

Two successful compilation passes produced `HPDC-MaOEA_updated.pdf`; the normal `HPDC-MaOEA.pdf` was locked by another application and could not be overwritten. Figure 2 is on page 3 of that updated output. The rendered page has no clipping, but the selected horizontal layout has small annotations at single-column width. Existing experiment-reference warnings remain unchanged.
