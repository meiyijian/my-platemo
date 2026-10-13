# DTLZ4 convergence-case replacement

User-approved scope: replace the active M10 DTLZ6 convergence figure with
DTLZ4, update the corresponding English and Chinese prose and caption,
and preserve the existing format. Baseline: `e25f295`.

Active favorable cases are DTLZ1, DTLZ4, WFG2 and WFG7. The manuscript
explicitly identifies them as lowest-endpoint-mean cases, and keeps WFG3
as a failure case. Main tables, including DTLZ6 results, remain unchanged.

DTLZ4 inputs are all seven algorithms' original runs 1--20 at M10, D30,
configured FE500, including initialization. Means use the same unit-FE
previous-snapshot hold, all 20 runs at each plotted point, and no smoothing.
The terminal means are PACDIS 0.6132632638, REMO 0.6347078213 and
PIEA 0.8198199986. PIEA leads early and PACDIS passes it later; the text
does not claim continuous superiority. The table reports REMO with `=`,
so the text retains the absence of a detected rank-sum difference.

Eighteen PIEA files lack saved IGD+. The supplemental cache and MATLAB
reproduction script in `../fe500_convergence/` reconstruct these metrics
from saved populations. Source SHA-256, FE coordinates and unchanged FE
counters are verified. Both stock-metric and stored-trajectory checks
have zero maximum error. The earlier cache remains unchanged.

Reproduction and validation:

1. Run `export_piea_dtlz4_metric_cache.m` in MATLAB only if the raw files change.
2. Run `../fe500_convergence/export_convergence_fe500.py`.
3. Run `../../figures/build_convergence_fe500.py`.
4. Run `../fe500_convergence/validate_convergence_fe500.py` and this
   directory's `validate_replacement.py`.
5. Compile the manuscript twice with a clean job name, then render and
   inspect the prose and five-figure page.

The replacement audit verifies 420 unchanged trajectories, 140 DTLZ4
trajectories, unchanged drawing functions and style settings, unchanged
main tables and unchanged Chinese table rows. Full source validation
independently reconstructs all 28 means from 560 MAT files.

The earlier DTLZ6 figure assets remain historical. Their original exported
data and manifests can be recovered from baseline commit `e25f295`.
