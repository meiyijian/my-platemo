# Good-group Precision 跨算法版本结论对拍

可比子集：DTLZ2 / DTLZ4 / DTLZ5 x M10,M20（三臂共有）；主口径 Top-25% 等规模筛选、valid pairs=25。

行数：AdaMaO 全 10 问题 4320 行，其中共有 3 问题 1296 行；Lambdat030 1296 行。

## 臂 A：AdaMaO 版（REMO_new2_AdaMaO，qKeep=0.8, lambda0=0.35）— 仅共有 3 问题

| Metric | Contrast (A vs B) | cells | A>B | A<B | Holm 显著胜 | Holm 显著负 | 中位相对增益% | 中位 win prob | cells(ValidPairs<25) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Precision | score_hybrid vs score_v | 144 | 61 (42%) | 80 (56%) | 17 | 8 | -0.029 | 0.470 | 0 |
| Precision | score_hybrid vs anchor_margin | 144 | 88 (61%) | 55 (38%) | 48 | 16 | +0.900 | 0.630 | 0 |
| AUC | score_hybrid vs score_v | 144 | 74 (51%) | 70 (49%) | 45 | 23 | +0.889 | 0.520 | 19 |
| AUC | score_hybrid vs anchor_margin | 144 | 77 (53%) | 67 (47%) | 50 | 24 | +1.598 | 0.541 | 19 |
| Lift | score_hybrid vs score_v | 144 | 64 (44%) | 78 (54%) | 17 | 8 | -0.026 | 0.480 | 1 |
| Lift | score_hybrid vs anchor_margin | 144 | 91 (63%) | 53 (37%) | 49 | 18 | +1.014 | 0.640 | 1 |

## 臂 B：Lambdat030 版（Pruned/Weighted, qKeep=0.70, lambda_t=0.30）

| Metric | Contrast (A vs B) | cells | A>B | A<B | Holm 显著胜 | Holm 显著负 | 中位相对增益% | 中位 win prob | cells(ValidPairs<25) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Precision | score_hybrid vs score_v | 144 | 62 (43%) | 78 (54%) | 15 | 15 | -0.008 | 0.480 | 0 |
| Precision | score_hybrid vs anchor_margin | 144 | 85 (59%) | 57 (40%) | 52 | 25 | +0.535 | 0.570 | 0 |
| AUC | score_hybrid vs score_v | 144 | 72 (50%) | 72 (50%) | 48 | 29 | +0.544 | 0.520 | 22 |
| AUC | score_hybrid vs anchor_margin | 144 | 77 (53%) | 67 (47%) | 49 | 26 | +0.558 | 0.520 | 22 |
| Lift | score_hybrid vs score_v | 144 | 65 (45%) | 78 (54%) | 14 | 14 | -0.004 | 0.480 | 0 |
| Lift | score_hybrid vs anchor_margin | 144 | 86 (60%) | 56 (39%) | 51 | 22 | +0.574 | 0.580 | 0 |

## 主口径逐阶段：Precision@25% vs population_final（相对两基线）

### A: AdaMaO版

| Stage | hybrid vs score_v: 均值差(pp) | 胜格/总格 | Holm显著 | hybrid vs anchor: 均值差(pp) | 胜格/总格 | Holm显著 |
|---|---:|---:|---:|---:|---:|---:|
| S1 | +3.408 | 6/6 | 2 | +1.707 | 4/6 | 1 |
| S2 | +2.190 | 6/6 | 2 | +1.371 | 4/6 | 1 |
| S3 | +2.471 | 5/6 | 2 | +2.507 | 3/6 | 3 |
| S4 | +1.568 | 5/6 | 1 | +1.698 | 5/6 | 1 |

### B: Lambdat030版

| Stage | hybrid vs score_v: 均值差(pp) | 胜格/总格 | Holm显著 | hybrid vs anchor: 均值差(pp) | 胜格/总格 | Holm显著 |
|---|---:|---:|---:|---:|---:|---:|
| S1 | +3.467 | 6/6 | 2 | +1.392 | 4/6 | 2 |
| S2 | +2.245 | 6/6 | 2 | +1.554 | 4/6 | 3 |
| S3 | +1.995 | 5/6 | 1 | +1.425 | 3/6 | 2 |
| S4 | +1.411 | 5/6 | 1 | -0.269 | 2/6 | 0 |

## 按真值族拆分：Precision 相对 score_v（全部阶段、共有 3 问题）

| 臂 | population_* 均值差(pp) | 胜格/总 | front_* 均值差(pp) | 胜格/总 |
|---|---:|---:|---:|---:|
| A: AdaMaO版 | +1.062 | 53/72 | -0.322 | 8/72 |
| B: Lambdat030版 | +0.971 | 51/72 | -0.358 | 11/72 |

## 按目标数拆分：Precision 相对 score_v / anchor（共有 3 问题）

| 臂 | M | vs score_v 均值差(pp) | vs anchor 均值差(pp) |
|---|---|---:|---:|
| A: AdaMaO版 | M10 | +0.413 | +1.114 |
| A: AdaMaO版 | M20 | +0.328 | +2.105 |
| B: Lambdat030版 | M10 | +0.297 | +0.919 |
| B: Lambdat030版 | M20 | +0.317 | +1.867 |

## 逐问题主口径：Precision@25% vs population_final（全阶段均值）

| 问题 | M | A: hybrid | A: vs V(pp) | A: vs Anchor(pp) | B: hybrid | B: vs V(pp) | B: vs Anchor(pp) |
|---|---|---:|---:|---:|---:|---:|---:|
| DTLZ2 | 10 | 0.3188 | +0.958 | +3.268 | 0.3426 | +0.976 | +2.323 |
| DTLZ2 | 20 | 0.3117 | +0.057 | +6.847 | 0.3073 | -0.274 | +4.377 |
| DTLZ4 | 10 | 0.3978 | +7.011 | -2.999 | 0.4211 | +6.930 | -1.838 |
| DTLZ4 | 20 | 0.4064 | +4.308 | +2.674 | 0.3901 | +4.149 | +1.351 |
| DTLZ5 | 10 | 0.3182 | +0.959 | -0.180 | 0.3232 | +0.894 | -0.451 |
| DTLZ5 | 20 | 0.3448 | +1.163 | +1.314 | 0.3367 | +1.000 | +0.392 |

## 臂 C：lambda_t=0.50（PWGGP）由跨臂表 MeanA/MeanB 反推的视图差

说明：跨臂表只给每视图的 25 跑均值，无逐 run 值，故此处只有方向与幅度，**无 p 值**。

| 问题 | M | Truth | hybrid-v  L030(pp) | hybrid-v  L050(pp) | hybrid-anchor L030(pp) | hybrid-anchor L050(pp) |
|---|---|---|---:|---:|---:|---:|
| DTLZ2 | 10 | population_final | +1.165 | +2.047 | +1.860 | +4.344 |
| DTLZ2 | 10 | front_final | -1.235 | -0.979 | +5.101 | +5.516 |
| DTLZ2 | 10 | population_h1 | +0.121 | +0.313 | +0.492 | +0.812 |
| DTLZ2 | 20 | population_final | -0.459 | -0.459 | +4.552 | +7.522 |
| DTLZ2 | 20 | front_final | -0.654 | -1.144 | +5.698 | +5.478 |
| DTLZ2 | 20 | population_h1 | -0.228 | -0.318 | +2.255 | +2.192 |
| DTLZ4 | 10 | population_final | +5.987 | +6.056 | -2.326 | -1.056 |
| DTLZ4 | 10 | front_final | -0.697 | -0.301 | -1.581 | -1.070 |
| DTLZ4 | 10 | population_h1 | +0.829 | +1.096 | -0.354 | -0.022 |
| DTLZ4 | 20 | population_final | +3.482 | +3.678 | +2.004 | +5.168 |
| DTLZ4 | 20 | front_final | -0.062 | -0.148 | -0.177 | -0.131 |
| DTLZ4 | 20 | population_h1 | +0.771 | +0.713 | +0.582 | +0.715 |

臂 C 方向汇总（12 个 问题-M-真值 单元，来源为跨臂表）：hybrid 优于 score_v 的单元 6 个，劣于 6 个；hybrid 优于 anchor 的单元 8 个，劣于 4 个。

## 同源校验：用跨臂表的 L030 均值反推的视图差 vs LTGGP 配对表的 MeanDelta（仅 DTLZ2/DTLZ4）

| 问题 | M | Truth | 反推 L030 hybrid-v(pp) | 配对表 MeanDelta(pp) | 反推 L030 hybrid-anchor(pp) | 配对表 MeanDelta(pp) |
|---|---|---|---:|---:|---:|---:|
| DTLZ2 | 10 | population_final | +1.165 | +0.976 | +1.860 | +2.323 |
| DTLZ2 | 10 | front_final | -1.235 | -1.048 | +5.101 | +5.462 |
| DTLZ2 | 10 | population_h1 | +0.121 | +0.099 | +0.492 | +0.489 |
| DTLZ2 | 20 | population_final | -0.459 | -0.274 | +4.552 | +4.377 |
| DTLZ2 | 20 | front_final | -0.654 | -0.638 | +5.698 | +6.639 |
| DTLZ2 | 20 | population_h1 | -0.228 | -0.216 | +2.255 | +2.293 |
| DTLZ4 | 10 | population_final | +5.987 | +6.930 | -2.326 | -1.838 |
| DTLZ4 | 10 | front_final | -0.697 | -0.674 | -1.581 | -1.182 |
| DTLZ4 | 10 | population_h1 | +0.829 | +0.562 | -0.354 | -0.005 |
| DTLZ4 | 20 | population_final | +3.482 | +4.149 | +2.004 | +1.351 |
| DTLZ4 | 20 | front_final | -0.062 | -0.064 | -0.177 | -0.126 |
| DTLZ4 | 20 | population_h1 | +0.771 | +0.606 | +0.582 | +0.477 |
