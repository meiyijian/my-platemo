# Stage1 标签机制审计实验 — screening 汇总报告

- **生成时间**: 2026-08-12 02:37
- **Profile**: screening（100 个作业，10 并行进程）
- **问题集**: DTLZ2 / DTLZ4 / DTLZ7 / WFG3 / WFG7 × M∈{10,20}
- **行为对照**: Hybrid（新标签机制）vs AnchorNative（纯锚定原生）
- **等价性验证**: equivalence_passed.txt = **PASS**

## 1. 完成进度

| 指标 | 数值 |
|---|---|
| Expected | 100 |
| Completed (valid) | **100** |
| Invalid | 0 |
| Pending | 0 |
| 所有作业状态 | skipped, valid existing result |

## 2. 决策结果（Stage1_decision.csv）

| 字段 | 值 |
|---|---|
| DecisionCode | **PASS_TO_STAGE2** |
| Reason | All required jobs valid; equivalence passed; adaptive coverage >= 50% |
| ValidFiles | 100 |
| InvalidFiles | 0 |
| ND_KMEANS_below50pct | 0（无低自适应覆盖组合） |

## 3. 方向来源分布（方向 = KMEANS 自适应 vs 回退）

20 个 (problem, M, behavior) 组合，共 6,700 个快照：

- **KMEANS 自适应方向占绝对主导**：18/20 组合 ND_KMEANS 比例 = 100%
- 仅 2 个组合出现回退（原因均为数据几何退化，属预期防护行为）：
  - **DTLZ4 M=20**：Hybrid 91.9%（27/335 回退）、AnchorNative 90.4%（32/335 回退）— 原因 `OBJECTIVE_RANGE_LT_1E12`（目标值范围过小）
  - **DTLZ7 M=10 Hybrid**：98.2%（6/335 回退）— 原因 `FRONT1_LT_THRESHOLD`（第一前沿规模低于阈值）
- 全部组合自适应占比 ≥ 90%，远超 50% 门槛 → 自适应覆盖达标

## 4. 候选模式分布（Stage1_trajectory_summary.csv）

- 100 个作业全部运行满 67 代，每代平均评估个体数 ≈ 5.97（稳定）
- **模式切换正常**：每 67 代中 indicator 约 32±3 代、explore 约 35±3 代，大致对半
- **fallback 代 = 0**：全程无退化候选模式，机制未触发保护分支
- Hybrid 与 AnchorNative 模式分布几乎对称 → 标签机制本身未破坏候选模式调度

## 5. 分支重叠统计（Stage1_branch_overlap_summary.csv，均值）

| 指标 | 观察范围 | 解读 |
|---|---|---|
| corr(ScoreV, LabelDyn) | 0.03 ~ 0.58（个别负值，如 WFG3 Hybrid r1=-0.017） | DTLZ2/DTLZ7 相关性较强，WFG 系列较弱 |
| Jaccard(目录, TopQ-ScoreV) | 0.22 ~ 0.82 | DTLZ2 最高（0.54-0.82），WFG7 最低 |
| Jaccard(目录, TopQ-Margin) | 0.17 ~ 0.69 | WFG7 反而最高（0.48-0.69） |
| Jaccard(TopQ-ScoreV, TopQ-Margin) | 0.06 ~ 0.34 | 两排序标准差异显著，重叠低 |
| EffectiveScaleRatio | 0.003 ~ 0.17 | 量级小，M=20 时更小 |
| CatalogFlipRate | 0.21 ~ 0.34 | 目录标签翻转率约 25%~34% |
| IGD / IGDp | DTLZ7 远高于其余（离散前沿，符合预期） | 收敛正常 |

## 6. 结论

1. **Stage1 全部通过**：100/100 有效作业，等价性 PASS，决策 **PASS_TO_STAGE2**。
2. 标签机制在 screening 集上**方向来源以 KMEANS 自适应为主**（≥90%），仅在数据几何退化（目标范围过小 / 前沿过小）时回退，且回退为预期防护行为。
3. **无候选模式退化**（fallback=0），Hybrid/AnchorNative 调度对称，说明新标签机制未破坏原调度结构。
4. ScoreV 与 LabelDyn 的相关性在 DTLZ 系列强、WFG 系列弱；ScoreV TopQ 与 Margin TopQ 重叠低 → 两套排序视角互补，为 Stage2 分析提供依据。

## 7. 产出文件

- `Stage1_analysis.mat` — 全量聚合数据（-v7.3）
- `Stage1_snapshot_metrics.csv` — 逐快照指标（6,700 行）
- `Stage1_direction_source_summary.csv` — 方向来源分布
- `Stage1_trajectory_summary.csv` — 候选模式轨迹
- `Stage1_branch_overlap_summary.csv` — 分支重叠统计
- `Stage1_decision.csv` — 决策结果
- `Stage1_run_manifest.csv` — 运行清单
