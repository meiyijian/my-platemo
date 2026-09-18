## 1. 逐格一致性：两臂同一 (问题,M,阶段,真值,指标,对比) 单元的 MeanDelta

每臂 3 共有问题 × M2 × 阶段4 × 真值6 × 指标3 × 对比3 = 1296 个比较单元。

| 单元集合 | cells | 符号一致率 | Pearson r | Spearman rho | AdaMaO 均值Δ | L030 均值Δ |
|---|---:|---:|---:|---:|---:|---:|
| 全部（含 score_v vs anchor） | 1296 | 88.2% (1132/1283 非零对) | 0.935 | 0.894 | +0.0166 | +0.0132 |
| 仅含 hybrid 的对比 | 864 | 87.9% (748/851 非零对) | 0.941 | 0.881 | +0.0190 | +0.0171 |
| score_v vs anchor_margin | 432 | 88.9% (384/432 非零对) | 0.928 | 0.916 | +0.0118 | +0.0055 |

| Metric | Contrast | r | 符号一致率 | AdaMaO 均值Δ | L030 均值Δ |
|---|---|---:|---:|---:|---:|
| Precision | score_hybrid vs score_v | 0.940 | 85.5% | +0.0037 | +0.0031 |
| Precision | score_hybrid vs anchor_margin | 0.924 | 89.4% | +0.0161 | +0.0139 |
| AUC | score_hybrid vs score_v | 0.939 | 91.7% | +0.0038 | +0.0072 |
| AUC | score_hybrid vs anchor_margin | 0.969 | 90.3% | +0.0026 | +0.0005 |
| Lift | score_hybrid vs score_v | 0.986 | 82.4% | +0.0320 | +0.0329 |
| Lift | score_hybrid vs anchor_margin | 0.886 | 88.0% | +0.0561 | +0.0452 |

## 2. 绝对水平与相对 Chance 的富集（主口径 Precision@25%，共 3 问题）

单元=run-stage（每 run 4 阶段先聚合，再跨 run 汇总）；excess = Precision − 同检查点 Chance。

| 臂 | View | Truth | Precision | Chance | excess(pp) | excess>0 的 run-stage | Lift | AUC |
|---|---|---|---:|---:|---:|---:|---:|---:|
| A_AdaMaO | score_hybrid | population_final | 0.3496 | 0.3085 | +4.11 | 75.7% (454/600) | 1.430 | 0.610 |
| A_AdaMaO | score_hybrid | front_final | 0.7995 | 0.7429 | +5.66 | 63.5% (381/600) | 1.176 | 0.565 |
| A_AdaMaO | score_v | population_final | 0.3255 | 0.3085 | +1.70 | 62.2% (373/600) | 1.237 | 0.544 |
| A_AdaMaO | score_v | front_final | 0.8056 | 0.7429 | +6.27 | 63.8% (383/600) | 1.182 | 0.585 |
| A_AdaMaO | anchor_margin | population_final | 0.3314 | 0.3085 | +2.29 | 61.3% (368/600) | 1.235 | 0.594 |
| A_AdaMaO | anchor_margin | front_final | 0.7855 | 0.7429 | +4.26 | 68.3% (410/600) | 1.127 | 0.567 |
| B_Lambdat030 | score_hybrid | population_final | 0.3535 | 0.3129 | +4.06 | 74.7% (448/600) | 1.421 | 0.609 |
| B_Lambdat030 | score_hybrid | front_final | 0.8005 | 0.7413 | +5.92 | 62.3% (374/600) | 1.205 | 0.562 |
| B_Lambdat030 | score_v | population_final | 0.3307 | 0.3129 | +1.78 | 61.0% (366/600) | 1.214 | 0.540 |
| B_Lambdat030 | score_v | front_final | 0.8079 | 0.7413 | +6.66 | 65.0% (390/600) | 1.217 | 0.583 |
| B_Lambdat030 | anchor_margin | population_final | 0.3432 | 0.3129 | +3.03 | 66.3% (398/600) | 1.292 | 0.600 |
| B_Lambdat030 | anchor_margin | front_final | 0.7900 | 0.7413 | +4.87 | 75.2% (451/600) | 1.148 | 0.569 |

## 3. excess = Precision − Chance 的配对检验（run-stage 为单位，Wilcoxon 近似）

| 臂 | View | Truth | n | 均值 excess(pp) | z | p(双侧) |
|---|---|---|---:|---:|---:|---:|
| A_AdaMaO | score_hybrid | population_final | 597 | +4.11 | +14.11 | 0 |
| A_AdaMaO | score_hybrid | front_final | 524 | +5.66 | +13.72 | 0 |
| A_AdaMaO | score_v | population_final | 599 | +1.70 | +6.78 | 1.18e-11 |
| A_AdaMaO | score_v | front_final | 524 | +6.27 | +13.85 | 0 |
| A_AdaMaO | anchor_margin | population_final | 594 | +2.29 | +7.70 | 1.38e-14 |
| A_AdaMaO | anchor_margin | front_final | 525 | +4.26 | +14.33 | 0 |
| B_Lambdat030 | score_hybrid | population_final | 597 | +4.06 | +13.06 | 0 |
| B_Lambdat030 | score_hybrid | front_final | 529 | +5.92 | +13.21 | 0 |
| B_Lambdat030 | score_v | population_final | 595 | +1.78 | +6.69 | 2.2e-11 |
| B_Lambdat030 | score_v | front_final | 528 | +6.66 | +13.81 | 0 |
| B_Lambdat030 | anchor_margin | population_final | 598 | +3.03 | +10.21 | 0 |
| B_Lambdat030 | anchor_margin | front_final | 528 | +4.87 | +16.84 | 0 |

## 4. AdaMaO 臂：共有 3 问题 vs 其余 7 问题（展示 Lambdat030 选题未覆盖的部分）

| 子集 | View | Precision(pop_final) | Chance | excess(pp) | Lift |
|---|---|---:|---:|---:|---:|
| DTLZ2/4/5（=L030 覆盖） | score_hybrid | 0.3496 | 0.3085 | +4.11 | 1.430 |
| DTLZ2/4/5（=L030 覆盖） | score_v | 0.3255 | 0.3085 | +1.70 | 1.237 |
| DTLZ2/4/5（=L030 覆盖） | anchor_margin | 0.3314 | 0.3085 | +2.29 | 1.235 |
| 其余 7 问题 | score_hybrid | 0.2619 | 0.3000 | -3.81 | 0.946 |
| 其余 7 问题 | score_v | 0.2643 | 0.3000 | -3.57 | 0.962 |
| 其余 7 问题 | anchor_margin | 0.2556 | 0.3000 | -4.44 | 0.842 |
| 其中 WFG4 题 | score_hybrid | 0.2404 | 0.3451 | -10.46 | 0.578 |
| 其中 WFG4 题 | score_v | 0.2422 | 0.3451 | -10.28 | 0.587 |
| 其中 WFG4 题 | anchor_margin | 0.2607 | 0.3451 | -8.44 | 0.671 |
| 其中 DTLZ3/6/7 | score_hybrid | 0.2905 | 0.2399 | +5.06 | 1.476 |
| 其中 DTLZ3/6/7 | score_v | 0.2936 | 0.2399 | +5.37 | 1.501 |
| 其中 DTLZ3/6/7 | anchor_margin | 0.2488 | 0.2399 | +0.89 | 1.088 |
