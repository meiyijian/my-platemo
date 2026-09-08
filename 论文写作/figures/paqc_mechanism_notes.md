# PAQC illustration included in the manuscript

- Source supplied by the user: `figures/PAQC示意图` (PNG without a filename extension).
- Manuscript asset: `figures/paqc_mechanism.png`, an identical binary copy; SHA-256 `4CF736AB4A74DADF7CF04C7E06F4208C07A8BC26E7A1FA92AF85FA8897C2503B`.
- The artwork was developed in this conversation through generative image editing, using the user-supplied REMO geometric illustration as a reference. The manuscript acknowledges REMO through the existing bibliography key `ref:remo`; that bibliography entry remains incomplete in the source manuscript.
- The figure is a conceptual illustration of the adaptive direction branch, not a numerical example or experiment. The two-dimensional execution branch uses uniform directions. The illustrated adaptive directions use current nondominated objective vectors, not an oracle PF. The idealised choice O=Z makes the radial directions pass through their source points.
- The figure displays selected solutions; the shown counts do not specify the algorithm's positive-group quota. Nondominated membership alone does not guarantee positive-group membership. The schematic local boundaries and point assignments have not been numerically verified.
- The text connects the drawing to the existing direction, PBI, fusion and group equations, and restricts cross-label ordering reversals to the early-budget regime described by the existing proposition.
- Placement: introduced in Section 3.2, explained after the fusion/group equations in Section 3.2.3; Figure 2 appears on page 4 in the compiled seven-page manuscript.
- Validation: two consecutive successful pdflatex passes after placement changes; new cross-references resolve; no overfull boxes; rendered figure page inspected for clipping, overlap and readable labels.
- Existing manuscript issues remain: unresolved `sec:exp:paqc`, `sec:exp:candidate`, `sec:exp:sensitivity` references; incomplete bibliography and other TODOs. These are outside this insertion.
