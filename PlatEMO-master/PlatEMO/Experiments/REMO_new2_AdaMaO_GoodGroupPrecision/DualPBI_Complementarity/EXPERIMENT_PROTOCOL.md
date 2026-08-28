# 双 PBI 互补性补充实验协议

## Material Passport

- Origin Skill: experiment-agent
- Origin Mode: plan-and-implement
- Origin Date: 2026-08-19
- Verification Status: IMPLEMENTED_AND_UNIT_TESTED_PENDING_FORMAL_RUN
- Version Label: dpc_protocol_v1

## 1. 研究目标与证据边界

本实验在冻结的 Hybrid 搜索轨迹上检验双 PBI 的预测互补性：方向 PBI 视图和 Anchor-PBI 视图是否提供非冗余未来优质解信息，以及动态 Hybrid 是否同时优于两个单视图。

所有未来真值仍由 Hybrid 驱动轨迹产生，因此结果属于 on-policy 机制关联证据。它不能单独证明动态权重因果优于固定权重，也不能证明最终 IGD+/HV、候选成功率或关系模型泛化得到提升。

## 2. 实验矩阵

| 项目 | 正式设置 |
|---|---|
| Problems | DTLZ2、DTLZ4、DTLZ7、WFG3、WFG7 |
| M | 10、20 |
| D | 请求 30；WFG3 实际 31 |
| N | 100 |
| maxFE | 500 |
| Runs | 每配置 25 个固定种子，共 250 |
| Good-group quota | 25% |
| Stages | S1=[0,.25]、S2=(.25,.50]、S3=(.50,.75]、S4=(.75,1] |

一次正式启动会遍历全部 250 个任务。没有 smoke/pilot 人工 gate，也不会因为科学效果差而提前停止。

## 3. 数据身份与重放

补充实验使用原正式 MAT 文件作为只读来源。每个任务使用相同 Problem、M、D、N、maxFE、算法参数、run 和 seed 重新运行 `LVUniformMixAudit_Hybrid`，在内存中读取逐快照视图和稳定 EvalID。

每个 replay 必须满足：

1. CompletedFE 完全一致；
2. 最终 `[Obj,Dec]` 排序后最大绝对差不超过 `1e-12`；
3. IGD 与 IGD+ 最大绝对差不超过 `1e-12`；
4. Hybrid `CatalogCurrent` 等于 Hybrid score 的 Top-25%；
5. 所有逐解集合分解满足守恒关系。

未通过的任务只记录失败，不写入有效 raw 文件，不自动重试；程序继续处理其他任务。

## 4. 三个视图及重要区别

- `V`：`score_v` Top-25%。
- `A`：`anchor_margin=1-normalizedG` Top-25%。
- `H`：生产算法的 `CatalogCurrent`。

生产 Hybrid 的精确输入是连续 `score_v` 和二值 `label_dyn`，而等配额 Anchor 基线是连续 `anchor_margin`。因此实验同时报告 `H` 与自然 `label_dyn` 集合的重叠，避免把二者误写为完全相同的信号。

## 5. Primary 研究问题

### 5.1 双向非冗余

在每个 Problem-M-Stage 单元中，分别统计 25 个独立 run 是否出现：

- `V \\ A` 中至少一个 `population_final` 真阳性；
- `A \\ V` 中至少一个 `population_final` 真阳性。

两个方向分别对“出现概率不超过 0.5”做单侧精确二项检验，取

\[
p_{unique}=\max(p_{V-only},p_{A-only}).
\]

40 个单元的 `p_unique` 统一进行 Holm 校正。

### 5.2 严格融合增益

Primary metric 为 `population_final` 的 Precision@25%。在每个 Problem-M-Stage 单元中，对配对 run 分别做：

\[
H_{0V}:P_H\le P_V,\qquad H_{0A}:P_H\le P_A.
\]

采用单侧 Wilcoxon signed-rank，并令

\[
p_{fusion}=\max(p_{HV},p_{HA}).
\]

40 个 `p_fusion` 统一 Holm 校正。报告均值差、中位数差、paired win probability、matched-pairs rank-biserial，以及

\[
\Delta_{best}=P_H-\max(P_V,P_A)
\]

的均值、中位数和配对 bootstrap 95% CI。

### 5.3 单元级科学判定

只有同一 Problem-M-Stage 同时满足以下条件时，`ComplementaritySupported=true`：

- `p_fusion_Holm<=0.05`；
- `p_unique_Holm<=0.05`；
- H-V 和 H-A 的效应方向均为正；
- V-only 与 A-only 两个方向均存在正的独有真阳性贡献。

不设置“必须有多少单元成功”的事后阈值。全部正向、负向和不显著结果都输出。

## 6. Secondary 分析

其他 truths、Lift、AUC、Recall 和阶段变化是次要/探索性分析。输出逐快照和 run-stage 指标，但最终 `GGP_ComplementarityDecision.csv` 只由预设 primary 规则产生。

## 7. 逐快照指标

### 7.1 选择重叠

- `BothCount`、`VOnlyCount`、`AOnlyCount`、`NeitherCount`
- `JaccardVA`、`AgreementVA`
- `JaccardHV`、`JaccardHA`
- `JaccardVLabelNative`、`JaccardHLabelNative`
- 三个视图的边界并列数量

### 7.2 独有真阳性

- `TPBoth`、`TPVOnly`、`TPAOnly`
- `UniqueTPRateV`、`UniqueTPRateA`
- `UniquePrecisionV`、`UniquePrecisionA`
- `UniqueTPShare`

### 7.3 Hybrid 来源与损失

- `HybridFromBoth`、`HybridFromVOnly`、`HybridFromAOnly`、`HybridFromNeither`
- 对应四类 Hybrid 真阳性
- `LostTrueFromV`、`LostTrueFromA`

分母为零时输出 NaN；H1/H3 末端删失保持 NaN，不插补为零。

## 8. 统计单位与多重比较

快照嵌套在 run 中。程序先聚合到 `run × stage × truth`，再以 run 为独立统计单位。不得把快照当作独立重复。

Primary 的 40 个 Problem-M-Stage 单元分别对 fusion IUT 和 unique IUT 做 Holm family-wise 校正。报告原始 p 值、校正 p 值、有效配对数、效应量和 CI，不只报告显著/不显著。

## 9. 唯一最终 gate

`FINAL_INTEGRITY_GATE` 只判断实验是否完整可信，不判断效果是否优秀：

- ExpectedRuns=250；
- ValidReplayRuns=250；
- CompleteConfigurations=10；
- ReplayEquivalenceFailures=0；
- PrimaryFusionCells=40；
- PrimaryUniqueCells=40；
- DecisionCells=40。

此外，每个 primary 单元的 `AvailableRuns` 与有效配对数都必须等于该配置预设的 25 个 run；只有行数正确但配对不完整时，gate 仍为 `FAIL`。

满足时 `PASS`，否则 `FAIL`。效果差、WFG7 反向或没有单元支持互补性，都不会使完整性 gate 失败。

## 10. 结果文件

| 文件 | 说明 |
|---|---|
| `raw/.../run_NNN.mat` | 每个 replay 的逐快照互补指标和等价性记录 |
| `GGP_ComplementarityPerRunStage.csv` | run-stage 聚合表 |
| `GGP_StrictFusionTests.csv` | Hybrid 同时对两个单视图的 primary IUT |
| `GGP_UniqueContributionTests.csv` | 双向独有真阳性的 primary IUT |
| `GGP_ComplementarityDecision.csv` | 40 个单元的科学判定 |
| `GGP_ReplayEquivalence.csv` | 逐任务重放等价性 |
| `GGP_ComplementarityCoverage.csv` | 10 个配置的覆盖率 |
| `GGP_FinalGate.csv` | 唯一最终完整性 gate |

## 11. 可支持与不可支持的表述

可支持：在明确的 Problem-M-Stage 单元中，两个 PBI 视图各自识别对方遗漏的未来优质解，且 Hybrid 同时优于两个等配额单视图。

不可支持：动态权重相对固定权重的因果优势、最终 IGD+/HV 改善、candidate success 提升、关系模型泛化以及跨 PF 的普遍鲁棒性。
