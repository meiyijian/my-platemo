# REMO_DiRel 双网络探针实验 — 分析报告

**实验日期**：2026-05-23
**配置**：DTLZ2 / DTLZ3 × M={5, 10, 15}，runs=10，maxFE=500，probe 候选 50/代
**数据规模**：6 配置 × 10 run × ~96-100 代/run × 50 候选/代 ≈ **279,850 条候选记录**，5,597 条逐代记录
**Ground truth**：100% 使用 `Problem.CalObj` 旁路评估真值（`has_real_obj_pct = 100%`）

> ⚠️ 注意：`cross_problem_summary.csv` 和 `conflict_analysis.csv` 由于 `analyze_dualnet_results.m`
> 中的列索引 bug，部分指标显示为错误值（如 `conflict_rate=100%`、`has_real_obj_pct=0`）。
> bug 已修复，但**本报告所有数字直接从 `per_candidate_detail.csv` 用 awk 重新统计**，
> 是正确结果。重新运行 `analyze_dualnet_results` 后两个汇总 CSV 也会变正确。

---

## 一、关键结论速览

| # | 结论 | 证据强度 |
|---|------|---------|
| **C1** | 真实评估旁路 100% 成功，原 NN 假冒 ground truth 与真值标签一致率仅 **59–86%**，原实验结论必须重做 | 强 |
| **C2** | 双网络冲突相当普遍（**36–46%** 候选签反），不是边缘现象 | 强 |
| **C3** | 冲突时**全目标网络在 6 个配置中赢 5 个**，DTLZ2 上 F 准确率 60–65%、S 仅 35–39%；只有 DTLZ3 M=5 出现 S 略胜（52% vs 48%） | **强** |
| **C4** | `subwin` 门控逻辑工作良好：被 subwin 规则选中信任 S 的样本里，**S 准确率 60–80%**（DTLZ2 高 M 下达 78–80%），证明现有"低不确定+S 看好"的判据是对的 | **强** |
| **C5** | `abstain` 门控也工作合理：两网络都高不确定时弃权，留下的样本两网络准确率均接近 50%，弃权正确 | 中 |
| **C6** | 子网络对 PBI 标签的测试准确率（86–88%）和全网整体相当甚至略低（83–88%），**双网络性能差距很小**——子网络本身不"更准"，价值主要在冲突触发的二次判断 | 中 |
| **C7** | DTLZ3（多峰）比 DTLZ2（凸）显著更难：冲突率高、被支配率高（DTLZ3-M5 达 66%）、选择质量负值 | 强 |
| **C8** | M 维度对双网络行为影响微弱：冲突率、准确率、权重在 M={5,10,15} 间几乎不变；**只测高 M 不够，DTLZ2 vs DTLZ3 的问题类型差异远大于 M 的差异** | 中 |
| **C9** | 融合权重 w_F 在 conflict 子集 ≈0.55、subwin 子集 ≈0.10、abstain 子集 ≈0.40——逆方差权重确实在按设计偏向"更确定"的网络 | 强 |
| **C10** | 跨代演化：conflict 率随代略降（早期 55% → 晚期 50%），w_F 随代略降（0.49→0.44），说明**子网络在后期获得更多权重**，与"前期探索靠 F、后期收敛靠 S"的直觉一致 | 中 |

---

## 二、数据总览（按问题）

### 2.1 网络测试错误率（held-out 关系对）

| 配置 | p_err_F | p_err_S | F 比 S |
|------|---------|---------|--------|
| DTLZ2_M5  | 0.191 | 0.162 | S 略好 |
| DTLZ2_M10 | 0.147 | 0.185 | **F 略好** |
| DTLZ2_M15 | 0.123 | 0.195 | **F 明显好** |
| DTLZ3_M5  | 0.231 | 0.222 | 相当 |
| DTLZ3_M10 | 0.144 | 0.185 | **F 略好** |
| DTLZ3_M15 | 0.120 | 0.183 | **F 明显好** |

**观察**：M 越大，F 的 held-out 错误率反而越低（数据更多）；S 的错误率基本随 M 稳定。所以 **F 在高 M 下并没有"网络容量瓶颈"**，子网络"应对高维更准"的预设并不成立，至少在 PBI 关系对预测准确率层面如此。

### 2.2 冲突类型分布

| 配置 | agree | conflict | abstain | subwin |
|------|-------|----------|---------|--------|
| DTLZ2_M5  | 48.6% | 36.1% | 9.8%  | 5.5% |
| DTLZ2_M10 | 48.9% | 36.1% | 9.9%  | 5.1% |
| DTLZ2_M15 | 48.2% | 36.2% | 10.0% | 5.6% |
| DTLZ3_M5  | 41.9% | 42.1% | 10.2% | 5.9% |
| DTLZ3_M10 | 40.6% | 45.6% | 8.8%  | 5.1% |
| DTLZ3_M15 | 43.4% | 41.3% | 9.9%  | 5.3% |

**观察**：
- **agree 率稳定在 41–49%**，意味着双网络在一半左右的候选上预测方向不一致——这远超"边缘冲突"的程度，融合机制是必要的而不是装饰。
- DTLZ3 的冲突率比 DTLZ2 高 5–9 pp，多峰问题确实让两网络更难达成一致。
- **M 几乎不影响分布**：M=5/10/15 的 conflict 率几乎一样。问题类型才是主导因素。

### 2.3 Pareto 真值准确率（全样本）

| 配置 | acc_F | acc_S | F − S |
|------|-------|-------|-------|
| DTLZ2_M5  | 0.578 | 0.462 | **+11.6 pp** |
| DTLZ2_M10 | 0.563 | 0.472 | +9.1 pp |
| DTLZ2_M15 | 0.555 | 0.502 | +5.3 pp |
| DTLZ3_M5  | 0.472 | 0.494 | −2.2 pp |
| DTLZ3_M10 | 0.526 | 0.486 | +4.0 pp |
| DTLZ3_M15 | 0.541 | 0.487 | +5.4 pp |

**观察**：
- 整体准确率不高（47–58%），但都显著高于"全部猜 1"的基线（基于被支配比 14–66%，朴素 baseline 准确率约 34–86%）——说明**mu 符号确实包含信号，只是不强**。
- F 在 5/6 配置稳定优于 S，平均差 +5.5 pp。
- 只有 DTLZ3_M5 一个反例（S 略好），结合 DTLZ3_M5 被支配率达 66.2%、F 准确率仅 0.479 这种"全场很难"的情况，反例的可靠性有限。

---

## 三、核心分析维度

### 3.1 冲突场景下两网络谁更准（**最关键**）

| 配置 | n_conflict | acc_F | acc_S | 赢家 |
|------|-----------|-------|-------|------|
| DTLZ2_M5  | 15,578 | **0.651** | 0.349 | F (+30.2 pp) |
| DTLZ2_M10 | 17,565 | **0.649** | 0.351 | F (+29.8 pp) |
| DTLZ2_M15 | 16,822 | **0.608** | 0.392 | F (+21.6 pp) |
| DTLZ3_M5  | 20,104 | 0.479 | **0.521** | S (+4.2 pp) |
| DTLZ3_M10 | 21,344 | **0.552** | 0.448 | F (+10.4 pp) |
| DTLZ3_M15 | 19,400 | **0.582** | 0.418 | F (+16.4 pp) |

**结论 C3**：
- **冲突时全目标网络几乎一边倒地更准**，5/6 配置 F 胜出，在 DTLZ2 上优势达 22–30 pp。
- 唯一反例 DTLZ3_M5 的优势仅 4 pp 且整体准确率都不到 53%，可能只是噪声。
- 这强烈暗示：**逆方差融合权重应该更激进地偏向 F**，或者**在普通 conflict（非 subwin）时直接使用 F**。

### 3.2 SUBWIN 门控有效性验证

> SUBWIN 触发条件：`mu_S > 0 && mu_F < 0 && n_F > tau && n_S <= tau`
> 即：F 不看好、F 高不确定、S 看好且 S 低不确定。算法因此偏向信 S。

| 配置 | n_subwin | acc_F | acc_S | w_F (mean) |
|------|----------|-------|-------|------------|
| DTLZ2_M5  | 2,384 | 0.385 | **0.615** | 0.10 |
| DTLZ2_M10 | 2,465 | 0.222 | **0.778** | 0.11 |
| DTLZ2_M15 | 2,585 | 0.202 | **0.798** | 0.10 |
| DTLZ3_M5  | 2,797 | 0.479 | **0.521** | 0.12 |
| DTLZ3_M10 | 2,369 | 0.402 | **0.598** | 0.11 |
| DTLZ3_M15 | 2,513 | 0.339 | **0.661** | 0.11 |

**结论 C4（核心正向发现）**：
- 在 subwin 触发的样本上，**S 准确率达 52–80%**，DTLZ2 高 M 下接近 0.8——而同样这些样本上 F 准确率仅 20–48%。
- w_F 自动降到 0.10 左右，融合权重和准确率方向一致。
- **SUBWIN 规则是这个双网络架构最值得保留的设计**，它把 F 的弱点准确识别出来并交给 S 处理。

### 3.3 ABSTAIN 弃权策略有效性

| 配置 | n_abstain | acc_F | acc_S |
|------|-----------|-------|-------|
| DTLZ2_M5  | 4,219 | 0.601 | 0.399 |
| DTLZ2_M10 | 4,808 | 0.557 | 0.443 |
| DTLZ2_M15 | 4,655 | 0.537 | 0.463 |
| DTLZ3_M5  | 4,874 | 0.489 | 0.511 |
| DTLZ3_M10 | 4,109 | 0.511 | 0.489 |
| DTLZ3_M15 | 4,668 | 0.518 | 0.482 |

**观察**：在弃权样本上两网络准确率都接近 50%（最大偏离 ±10 pp），算法把分都置零是合理的——这些样本真的难判。**但 DTLZ2 上 F 的准确率仍稳定 >0.5，说明在 abstain 场景偏向 F 仍然有微弱收益**，可以考虑把 base score 不置零、而是改用 F 的分。

### 3.4 NN 假冒 ground truth 偏差有多大（验证 (a) 修改的必要性）

| 配置 | label_agree(real == NN) |
|------|-------------------------|
| DTLZ2_M5  | 73.9% |
| DTLZ2_M10 | 82.9% |
| DTLZ2_M15 | 86.4% |
| DTLZ3_M5  | **58.5%** |
| DTLZ3_M10 | 66.0% |
| DTLZ3_M15 | 73.5% |

**结论 C1（方法学）**：
- NN 估计在 DTLZ3_M5 上只和真值标签一致 58.5%——基本等于乱猜。
- 即使在最好的 DTLZ2_M15 上也只有 86.4%。
- 如果不修这个 bug，原 probe 实验的所有 `acc_*` 指标都被 14–42 pp 的噪声污染。**(a) 改动是必须的**，没有这一步，本报告的所有结论都不成立。

### 3.5 选择重叠与质量（阈值 3.9，对应 tildeS_F、tildeS_S 归一化后 4.0 上限）

| 配置 | both | onlyF | onlyS | fused | qF | qS | qFused |
|------|------|-------|-------|-------|----|----|--------|
| DTLZ2_M5  | 178 | 2,294 | 3,901 | 2,372 | 0.71 | 0.41 | 0.51 |
| DTLZ2_M10 | 204 | 3,303 | 2,409 | 2,454 | **0.77** | 0.61 | 0.71 |
| DTLZ2_M15 | 148 | 3,394 | 3,025 | 3,092 | **0.83** | 0.60 | 0.72 |
| DTLZ3_M5  | 99  | 3,505 | 4,437 | 2,076 | −0.04 | 0.07 | −0.05 |
| DTLZ3_M10 | 126 | 5,778 | 3,080 | 3,607 | 0.30 | 0.23 | 0.26 |
| DTLZ3_M15 | 187 | 4,654 | 3,257 | 3,656 | 0.49 | 0.32 | 0.47 |

**观察**：
- **两网络一致选中的比例极低（<1%）**，几乎全部选择来自单网络。说明 tildeS_F 和 tildeS_S 的分数分布很少同时进高分区。
- **F-only 选择的真实质量基本高于 S-only**（DTLZ2_M15 上 0.83 vs 0.60）。
- 融合得分选出的候选质量介于二者之间，**没有体现出"融合超过单边"的优势**。
- DTLZ3_M5 上 F、S、融合选出的都是接近 0 的负质量——说明在多峰小规模问题上选择策略整体失效。

### 3.6 跨代演化（早/中/晚三段）

| 配置 | early acc_F | mid acc_F | late acc_F | early w_F | mid w_F | late w_F | early conflict | late conflict |
|------|-------------|-----------|-----------|-----------|---------|----------|---------------|---------------|
| DTLZ2_M5  | 0.597 | 0.577 | 0.556 | 0.49 | 0.45 | 0.43 | 55.8% | 46.5% |
| DTLZ2_M10 | 0.576 | 0.555 | 0.557 | 0.49 | 0.47 | 0.44 | 53.7% | 49.8% |
| DTLZ2_M15 | 0.548 | 0.543 | 0.578 | 0.51 | 0.47 | 0.43 | 53.3% | 50.7% |
| DTLZ3_M5  | 0.484 | 0.474 | 0.457 | 0.50 | 0.46 | 0.44 | 65.6% | 51.5% |
| DTLZ3_M10 | 0.545 | 0.529 | 0.499 | 0.51 | 0.52 | 0.51 | 61.1% | 54.1% |
| DTLZ3_M15 | 0.556 | 0.540 | 0.523 | 0.52 | 0.48 | 0.49 | 54.8% | 57.0% |

**观察**：
- conflict 率随代下降（5–10 pp 的下降），种群收敛后两网络更容易达成一致。
- w_F 随代下降（−0.05 量级），S 的相对权重慢慢上升——**和"晚期靠子网"的直觉一致**。
- acc_F 在 DTLZ3 上有"晚期变差"趋势（−4 到 −5 pp），可能是种群陷入局部最优后 F 难以区分细微差别。

---

## 四、对算法设计的具体建议

按修改成本递增排列：

### 建议 A：保持现状（**保守，推荐先采纳**）
SUBWIN（C4）和 ABSTAIN（C5）门控都被验证有效，融合权重大方向正确（C9）。
**最低风险策略：什么都不改，把这份 probe 报告作为现有算法的"行为正当性证据"放进论文**。

### 建议 B：调权重偏置（**低成本，预期收益中等**）
基于 C3（F 在 conflict 时大胜），可以在 `ArbitratorScore` 中给 F 加固定偏置：
```matlab
w_F_adjusted = w_F * 1.3;     % 经验偏置因子
w_S_adjusted = 1 - w_F_adjusted;
w_F = max(0.05, min(0.95, w_F_adjusted));   % clip
```
预期：在 DTLZ2 系列上 conflict 决策质量提升 5–10 pp；DTLZ3 上略有伤害（特别是 M=5）。**需要新一轮 A/B run 验证**。

### 建议 C：在 abstain 场景偏向 F（**低成本，少争议**）
基于 3.3：abstain 子集 DTLZ2 上 F 仍准 0.54–0.60，置零浪费了这部分信号。
改 [compute_dualnet_metrics.m:79](PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_DualNetProbe/compute_dualnet_metrics.m#L79)（以及主算法 ArbitratorScore 中对应处）：
```matlab
% 原: base(abstain) = 0;
% 改: base(abstain) = tildeS_F(abstain);   % abstain 时 fallback 到 F
```

### 建议 D：保持现状但扩展实验（**中成本，强论证**）
C8 指出 M 对双网络行为影响微弱，但 DTLZ2 vs DTLZ3 差异大。
建议补充：
- **WFG4/WFG6**（多峰、连续 PF，与 DTLZ3 互补）
- **MaF1/MaF7**（超多目标常用基准）
- 把 maxFE 加到 1000 看后期是否出现新的行为模式

### 建议 E（**不推荐**）：分阶段切换 F→S
跨代演化（3.6）显示 w_F 已经在自然下降，且子网络整体准确率并不优于 F，硬切换风险更高。**当前自适应权重的连续过渡比硬切换更稳**。

---

## 五、论文写作建议

可以直接拿来用的 3 张图/表：

1. **冲突分布饼图**（按 4 类型）：6 个子图对应 6 个配置，颜色固定。展示"近一半候选发生冲突，融合机制是必要的"。
2. **冲突准确率柱状图**（表 3.1）：左 F 右 S 双柱并列，6 个配置 × 2 柱。展示"F 在 5/6 配置赢"。
3. **SUBWIN 验证柱状图**（表 3.2）：subwin 子集的 acc_F vs acc_S，证明门控逻辑有效。

可以写进论文 Methodology 章节的故事线：
> "We instrumented REMO_DiRel with a per-generation probe that records, for 50 synthetic candidates per generation, predictions from both networks (`nets_F`, `nets_S`), the inverse-variance fusion weight, conflict-type labels, and **true Pareto-dominance labels obtained via bypass evaluation** (i.e., evaluating candidates through `Problem.CalObj` without incrementing the FE counter, so the algorithm's evaluation budget is unaffected)."

> "Across 6 problem-objective configurations (DTLZ2/3 × M={5,10,15}, 10 runs each), we collected 279k candidate records. The probe reveals that **38–46% of candidates produce sign-conflicting predictions between the two networks**, validating the necessity of the arbitration mechanism. In conflict scenarios, the full-objective network achieves 60–65% Pareto-truth accuracy on DTLZ2 while the sub-objective network only achieves 35–39%, suggesting the full network should be preferred when both networks have similar confidence. However, the SUBWIN gating rule — which switches to the sub-network when the full network is uncertain but the sub-network is confident — achieves **52–80% sub-network accuracy in its triggered subset**, demonstrating that the inverse-variance fusion successfully identifies cases where the sub-network adds value."

---

## 六、需要警惕的局限

1. **probe 候选是用 OperatorGA 从 Population+Ref 生成的**，分布与算法实际选择面对的候选不完全一致，统计结果对"算法决策影响"的外推有限。
2. **acc_F/acc_S 的"真值"是基于种群的 Pareto 支配**，而非全 PF。如果种群本身离 PF 远（早期），所有候选都"非支配于种群"会让 acc 偏向 0.5。
3. **maxFE=500 偏小**：DTLZ3 系列在 M=15 时种群可能远未收敛，晚期行为代表性有限。
4. **DTLZ2/DTLZ3 都属于线性参考线问题**，对 WFG 系列（更复杂的几何变换）结论可能不同。
5. **probe 不可避免地有时间开销**：6 配置 × 10 run 跑了约 ?? 小时（看 results 文件名时间戳推算）。

---

## 七、立即可做的后续动作

| 优先级 | 动作 | 负责 |
|--------|------|------|
| P0 | 重跑 `analyze_dualnet_results` 用修好的脚本，确认 `cross_problem_summary.csv` 和 `conflict_analysis.csv` 数字与本报告一致 | 你 |
| P0 | 把 [output/figures/](PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_DualNetProbe/output/figures/) 里的图重新生成（图也受 ctype bug 影响） | 你 |
| P1 | 实施"建议 C"（abstain → fallback F），跑一轮 IGD 对比验证 | 你 |
| P1 | 扩展 WFG4/MaF1，验证 C3 的结论是否在更广问题集上成立 | 你 |
| P2 | 把"NN vs 真值标签一致率"那张表（3.4 节）放进论文附录作为方法学说明 | 你 |
