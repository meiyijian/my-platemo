# NoBatchDist pMix sensitivity table

The manuscript table `../pmix_nobatchdist_igdp_table.tex` uses the `IGDp` sheet
of `sources/pMix_NoBatchDist_sensitivity.xlsx`, supplied from
`C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\pMix灵敏度_NoBatchDist`.
The source workbook SHA-256 is
`84e8bf305cd9b61a03c31ed5d4fe63cb53da9e121a6cbdb971539fef392c35d7`.

The workbook contains five pMix settings on six problems at each of M=10 and
M=20, with 20 run values per cell. The table copies the workbook means,
standard deviations, and `vs_pmix050` signs, and highlights the smallest mean
within each problem. The single average-rank row pools the 12 problem and
objective-count configurations, ranking the five unrounded cell means from
smallest to largest within each configuration. The `+/-/=` row sums the
workbook signs across those same 12 configurations. The sibling `IGD` sheet is
retained in the source workbook but is not used in the manuscript table.
