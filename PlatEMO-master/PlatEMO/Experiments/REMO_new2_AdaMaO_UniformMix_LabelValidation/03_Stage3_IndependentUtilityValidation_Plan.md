# Stage 3：独立真实效用标签验证实施规划

> **For agentic workers:** REQUIRED SUB-SKILL: use a plan-execution workflow and complete the checkbox steps in order. External utility must be computed without reusing either PBI label formula or SDE training targets as ground truth.

**Goal:** 使用基准问题的真实 PF 参考集和后续真实评价轨迹，判断不同伪标签是否选择了更有收敛与覆盖价值的解，并检验当前“早期偏连续方向、后期偏代表解二值边界”的调度假设。

**Architecture:** 从 Stage 1 的稳定 EvalID 和种群快照重建每个时刻的已评价档案；从 Stage 2 读取 L0–L8 标签。对固定检查点构造 PF 归一化后的 IGD+ 贪心 Top25、留一边际贡献和未来生存结果，所有版本在同一快照、同一参考集上配对比较。统计以 run 为独立单位，并使用 run-cluster bootstrap 和多重比较校正。

**Tech Stack:** MATLAB、PlatEMO 问题类、Stage 1/2 valid MAT 文件。主指标使用本阶段实现并测试的确定性 IGD+，不调用标签 PBI 或关系模型。

---

## 1. 实验目的和本阶段真正回答的问题

本阶段预注册四个可证伪假设：

### H1：非支配方向具有额外效用

在相同25%正例比例下，`L2_ND_SCORE_Q25` 的外部效用优于 `L1_ANCHOR_MARGIN_Q25`。只有 H1 成立，才能说非支配方向不仅改变了标签，而且改变方向与真实效用一致。

### H2：两路信号具有互补性

`L3_HYBRID_CURRENT_Q25` 优于 L1 和 L2 中的较好者，并优于打乱负对照 L6。只有 H2 成立，才能把“融合”作为独立贡献。

### H3：当前时间调度方向正确

早期 L2 相对 L1 更有预测力，之后该优势下降；同时 L3 优于固定权重 L4 和反向调度 L5。只有同时看到时间交互和调度版本优势，才能解释 `alpha=1-FE/maxFE`。

### H4：非支配来源和方向数量有实际意义

L2 优于均匀方向 L7，且与 `kEff` 方向版本 L8 的差异可以解释为方向分辨率，而不是随机波动。

任何单独一个 p 值或一个问题上的改善都不足以支持上述因果语言。

## 2. 输入和资格检查

必需输入由 runner 的 `<profile>` 决定：

```text
results/stage1/<profile>/**/run_*.mat
results/stage1/<profile>/analysis/Stage1_decision.csv
results/stage2/<profile>/**/run_*.mat
results/stage2/<profile>/analysis/Stage2_decision.csv
```

profile 映射固定为同名读取：Stage 3 smoke 读取两阶段 smoke，pilot 读取两阶段 pilot，screening 读取两阶段 screening。不得跨 profile 补齐缺失数据。只有 screening 能进入研究结论；smoke/pilot 只验证参考集、Oracle、未来轨迹重建和运行成本。

只接受：

- Stage 1 文件通过 `ValidateLabelMechanismSnapshotFile`；
- Stage 2 文件通过 `ValidateLabelCausalAblationFile`；
- 两阶段 metadata 的 `pairedKey/behavior/problem/M/run/seed` 完全相同；
- Stage 2 的 source hash 对应当前 Stage 1 文件；
- Stage 2 的唯一主决策是 `PASS_TO_STAGE3`；`SCHEDULE_REDUNDANT`、`DIRECTION_SOURCE_REDUNDANT` 只作为 WarningFlags 传入分层分析。

统一问题矩阵仍为 DTLZ2、DTLZ4、DTLZ7、WFG3、WFG7，`M=10/20`，每格5个 paired run，`maxFE=500`；WFG3 actual D 必须是31，其余为30。

## 3. 固定检查点和右删失规则

Stage 1 保存所有训练前快照，本阶段只分析每个 run 中最接近以下目标比例的快照：

```matlab
targetRatios = [0.20 0.40 0.60 0.80 0.95];
```

选择规则：在尚未使用的 snapshot 中，选择 `abs(snapshot.Ratio-target)` 最小者；并列时选 FE 较小者。若两个 target 映射到同一 snapshot，仅保留较早的 target，并把另一个标记为 `UNAVAILABLE_CHECKPOINT`，不得复制同一快照充数。

未来结果定义：

- `H1`：当前 snapshot 后第1个实际训练快照；
- `H3`：当前 snapshot 后第3个实际训练快照；
- `FINAL`：该 run 的最终 Population。

当后续快照不存在时，对应结果为右删失 `NaN`，不得当作0或“未生存”。分析 H1/H3 时必须报告可观察 run 数。

## 4. 独立 PF 参考集和归一化

### 4.1 参考集生成

对每个 `Problem/M` 组合生成并缓存 R4096/R8192。除 DTLZ7 外，使用问题实例的 `GetOptimum`：

```matlab
R4096 = Problem.GetOptimum(4096);
R8192 = Problem.GetOptimum(8192);
```

必须记录请求点数和实际返回行数；PlatEMO 的 `UniformPoint` 可能返回与请求值略有不同的数量。生成后立即断言行数不超过20000，超过时停止并报 `REFERENCE_SIZE_OVERFLOW`，不得先分配巨型距离矩阵。

**DTLZ7 不能直接调用高维 `GetOptimum(4096/8192)`。** 该类内部使用 `(M-1)` 维 grid；M=20 时会生成约 `2^19=524288` 行，后续 `R×N×M` 距离计算会造成不必要的内存和时间风险。DTLZ7 必须使用以下有上限的专用构造：

1. 以 `referenceSeed=20260811+problemIndex*100+M` 保存/恢复 RNG；
2. `U=UniformPoint(16384,M-1,'Latin')`，得到恰好16384行；
3. 按 DTLZ7 源码的两个真实 PF 区间映射每个元素：

```matlab
interval = [0,0.251412,0.631627,0.859401];
median = (interval(2)-interval(1)) / ...
    (interval(4)-interval(3)+interval(2)-interval(1));
X = U;
X(U<=median) = U(U<=median)*(interval(2)-interval(1))/median ...
    + interval(1);
X(U>median) = (U(U>median)-median)* ...
    (interval(4)-interval(3))/(1-median) + interval(3);
Rmaster = [X,2*(M-sum(X/2.*(1+sin(3*pi*X)),2))];
R4096 = Rmaster(1:4096,:);
R8192 = Rmaster(1:8192,:);
R16384 = Rmaster;
```

使用嵌套前缀可以让敏感性只增加参考点，不引入另一批独立随机样本。builder 必须用小样本与 DTLZ7 `GetOptimum` 的区间范围和最后目标公式做单元测试。

参考集缓存键包括：

```text
problem, M, requestedD, actualD, referenceRequest,
sourceClassHash, referenceBuilderVersion, referenceSeed
```

同一问题/M 的所有行为、run、快照和标签版本必须共用同一个缓存文件。

### 4.2 固定归一化

以 R4096 的理想点和极值范围归一化当前种群和参考集：

```matlab
zmin  = min(R4096,[],1);
zmax  = max(R4096,[],1);
scale = zmax-zmin;
constant = scale < 1e-12;
scale(constant) = max(abs(zmax(constant)),1);
Rn    = (R4096-zmin)./scale;
Pn    = (PopulationObj-zmin)./scale;
```

不能使用每个标签版本自己的 min/max，也不能使用当前 Population 的 min/max；否则不同快照的效用标尺会漂移。真实 PF 上近似常量的目标维使用 `max(abs(zmax),1)`，避免除以极小数放大舍入误差。超出 `[0,1]` 的近似解保留真实归一化值，不做截断。

### 4.3 IGD+ 精确定义

对最小化问题，参考点 `r` 到近似解 `a` 的距离为：

```matlab
dplus(r,a) = sqrt(sum(max(a-r,0).^2));
IGDplus(A,R) = mean_r min_{a in A} dplus(r,a);
```

必须创建并测试 `LVIGDPlus.m`，不依赖可能随 PlatEMO 版本变化的指标包装器。

## 5. 三类外部真实效用

### 5.1 主真值：贪心 IGD+ Top25

对当前100个解预计算 `R x N` 的 `dplus` 距离矩阵，使用缓存的当前最小距离迭代选择25个解：

1. 初始集合为空，当前最小距离为 `Inf`；
2. 对每个未选解，计算加入后 `mean(min(currentDistance,D(:,i)))`；
3. 选择使 IGD+ 最小的解；
4. 并列时选择 `PopulationEvalID` 更小者；
5. 重复至25个。

输出 `OracleGreedyTop25` 和每一步 `GreedyGain`。该真值同时考虑收敛和 PF 覆盖，是本阶段的主标签真值。

### 5.2 次真值：留一 IGD+ 边际贡献

对每个当前解 `i`：

```matlab
UtilityLOO(i) = IGDplus(P_without_i,R) - IGDplus(P,R);
```

值越大表示该解对当前整体近似更重要。大量0或并列是合法现象；相关分析使用 Kendall tau-b，并报告有效非并列对数量。

### 5.3 时间真值：未来保留和未来效用

利用 Stage 1 稳定 EvalID，记录每个当前解：

```text
InPopulationH1
InPopulationH3
InFinalPopulation
NondominatedInArchiveH1
NondominatedInArchiveH3
NondominatedInFinalArchive
```

未来 Archive 由 `evaluations.EvalID<=futureFE` 重建。非支配判断只使用已真实评价目标值。不得把未来算法标签或候选预测当真值。

时间真值受行为策略影响，因此 Hybrid 和 AnchorNative 轨迹必须分别分析；跨行为合并只能使用 run 级等权汇总。

## 6. 标签评价指标

固定25%的 L1–L8 使用：

```text
PrecisionAt25
RecallAt25
JaccardAt25
NDCGAt25_LOO
KendallTauB_LOO
PairwiseAUC_LOO
H1SurvivalRateSelected
H3SurvivalRateSelected
FinalSurvivalRateSelected
```

因为预测集和 Oracle 都有25个解，Precision@25 与 Recall@25 数值相同，但两个字段仍分别输出，便于论文方法描述。

L0 的正例数不是25，只报告：

```text
NativePositiveCount
NativePrecision
NativeRecall
NativeJaccard
```

不得把 L0 补齐或删减成25后仍称为“原始二值标签”。L1 才是固定比例下的锚点对照。

### 6.1 分歧集合直接检验

对以下三组比较计算 A-only 和 B-only 解的外部效用：

```text
L2 vs L1       % 非支配方向相对锚点裕量
L3 vs L1       % 融合相对锚点
L3 vs L2       % 融合相对方向单支路
```

主分歧指标为：

```matlab
DisagreementUtilityDelta = ...
    mean(UtilityLOO(A_only)) - mean(UtilityLOO(B_only));
```

同时报告 OracleTop25 捕获率和未来生存率差。若分歧集合少于3个解，该 snapshot 只记录样本不足，不计算均值差。

### 6.2 打乱负对照

L6 有100个 permutation。对每个 snapshot 保存 L6 指标分布，并计算 L3 指标在打乱分布中的百分位：

```matlab
ShufflePercentile = mean(metric_L6 <= metric_L3);
```

L3 只有持续高于打乱分布，才能说明解与 `ScoreV` 的对应关系有用；单纯改变类别比例不够。

## 7. 参考集敏感性

先用 R4096 完成主分析，再用 R8192 重算每个 `Problem/M/Behavior` 的 run1全部固定检查点。比较：

```text
Spearman(UtilityLOO_4096,UtilityLOO_8192)
Jaccard(OracleTop25_4096,OracleTop25_8192)
```

敏感性重算仍使用 R4096 定义的 `zmin/scale`，只改变参考点密度；否则会同时改变归一化标尺，无法判断差异来自点数还是尺度。

通过条件：

- 每个可估问题的相关不低于0.95；
- 每个检查点的 Top25 Jaccard 不低于0.90。

任何一个失败时，生成 R16384 并把该 `Problem/M` 的主分析全部重算为 R16384：DTLZ7 直接读取已缓存的 `Rmaster`；其余问题调用 `Problem.GetOptimum(16384)`，记录实际返回行数，并在任何距离矩阵分配前执行同一个“行数不超过20000”的断言。R16384 重算仍沿用 R4096 的 `zmin/scale`。若 R8192 与 R16384 之间仍达不到上述稳定性门槛，则标记 `INSUFFICIENT_REFERENCE_STABILITY`，不对该单元作标签质量结论。

## 8. 计划创建的文件及职责

```text
BuildLabelUtilityReferenceSet.m
LVIGDPlus.m
ComputeGreedyIGDPlusOracle.m
ComputeLeaveOneOutIGDPlus.m
ReconstructFutureLabelOutcomes.m
ComputeExternalLabelMetrics.m
ComputeDisagreementUtility.m
run_IndependentUtilityValidation.m
ValidateIndependentUtilityFile.m
analyze_IndependentUtilityValidation.m
tests/test_IndependentUtilityValidation.m
results/stage3/                       % 运行时生成，不提交 Git
```

结果路径：

```text
results/stage3/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
```

每个 MAT 顶层变量：

```text
metadata
checkpointRows
solutionUtilityRows
variantMetricRows
disagreementRows
referenceSensitivity
validation
```

每个 `solutionUtilityRows` 必须包含 `PopulationEvalID`，以便 Stage 4 按基础解隔离划分。

## 9. 实施任务清单

### Task 1：实现并单元测试独立效用

- [ ] 对单目标手工例子验证 `LVIGDPlus` 方向正确：近似解变差时 IGD+ 不得下降。
- [ ] 对包含支配解的二维例子验证留一贡献：删除冗余支配解的贡献应为0。
- [ ] 对小型4解/3参考点例子人工计算贪心顺序，并验证并列时按 EvalID。
- [ ] 验证外部效用代码不调用 `HybridPBI_Classification`、`GetOutput_PBI`、SDE 或关系网络。

### Task 2：建立参考集缓存和敏感性验证

- [ ] 对10个 Problem/M 组合生成 R4096/R8192，记录实际行数和源类 hash。
- [ ] 验证所有参考值有限、维度等于 M、归一化 scale 每维大于等于 `1e-12`。
- [ ] WFG3 缓存 metadata 必须记录 actualD=31。
- [ ] 同一 Problem/M 的全部作业只读取同一个只读缓存，不能每 run 随机重建。

### Task 3：重建未来结果

- [ ] 验证 Stage 1 `evaluations.EvalID` 连续且目标值与 snapshot 引用一致。
- [ ] 按后续 snapshot 顺序构建 H1/H3，不按固定 FE 差值猜测代数。
- [ ] 未来快照缺失时写 NaN 和 censor flag，不写0。
- [ ] 对最终 Population 验证100% EvalID 能映射到 evaluations。

### Task 4：计算所有标签指标和分歧效用

- [ ] 对每个固定检查点计算 OracleTop25、LOO 和未来结果。
- [ ] 对 L1–L8 计算固定25指标，对 L0 计算 native-size 指标。
- [ ] 对 L6 保存100次指标分布和 L3 百分位。
- [ ] 对三组预注册分歧比较保存解级记录，不只保存均值。
- [ ] 验证所有标签版本在同一 snapshot 使用完全相同的 Oracle 和 UtilityLOO。
- [ ] 当全部 UtilityLOO 为0或有效非并列对不足10时，把 Kendall/AUC/NDCG 标记为 `NaN` 并记录 `INSUFFICIENT_UTILITY_VARIATION`，不得用0代替未定义指标。

### Task 5：统计分析和决策

- [ ] 先按 snapshot 计算，再按 run 对检查点等权平均。
- [ ] run-cluster bootstrap 固定10000次，统计 seed 固定为 `20260811`。
- [ ] 主比较使用配对差：L2-L1、L3-max(L1,L2)、L3-L4、L3-L5、L2-L7、L2-L8。
- [ ] 同一指标的多版本比较使用 Holm 校正，报告原始 p、校正 p、配对效应和95% CI。
- [ ] 分别报告 DTLZ、WFG 两个家族；跨家族总结果使用每个问题等权，不按 snapshot 数加权。
- [ ] 生成第10节唯一决策代码，并完整报告负结果。

## 10. 分析输出和决策代码

```text
results/stage3/screening/analysis/
  Stage3_run_manifest.csv
  Stage3_reference_sensitivity.csv
  Stage3_variant_metrics.csv
  Stage3_stagewise_metrics.csv
  Stage3_disagreement_utility.csv
  Stage3_shuffle_controls.csv
  Stage3_pairwise_statistics.csv
  Stage3_decision.csv
  Stage3_analysis.mat
```

允许的主决策：

| DecisionCode | 证据模式 | 解释和动作 |
|---|---|---|
| `PASS_LABEL_COMPLEMENTARITY` | L3 在主效用上优于 L1、L2 较好者，优于 L6 打乱包络，且 DTLZ/WFG 方向不冲突 | 进入 Stage 4，保留融合故事 |
| `SIMPLIFY_DIRECTION_ONLY` | L2 优于 L1，但 L3 不优于 L2 | 进入 Stage 4，仅保留方向标签版本 |
| `SIMPLIFY_ANCHOR_ONLY` | L1 不弱于 L2/L3 | 进入 Stage 4 验证锚点模型；删除方向提升声明 |
| `PASS_LABEL_BUT_DROP_SCHEDULE` | L3/L4 有效，但 L3 不优于固定或反向调度，或时间交互不支持当前顺序 | 进入 Stage 4，固定更简单权重或按结果选单支路 |
| `NO_EXTERNAL_LABEL_EVIDENCE` | 当前/方向标签不优于打乱或锚点对照 | 停止“更好标签”主张；不进入高成本 Stage 4/5 |
| `INSUFFICIENT_REFERENCE_STABILITY` | 参考集敏感性无法通过 | 增密或修正 Oracle，不作标签结论 |
| `INSUFFICIENT_DATA` | 任一问题家族少于4个有效 run，或H1/H3可观察 run不足 | 补跑，不把缺失当无效应 |

Stage 3 的“通过”必须同时包含效应量和置信区间，不允许仅以未校正 `p<0.05` 决定。

## 11. 预期结果（研究假设，不是通过标准）

如果论文故事成立，合理预期是：

- L2 相对 L1 在 EARLY 的 OracleTop25 或 NDCG 更好，但优势随进化缩小；
- L3 在多个问题家族上比任一单支路获得更高的贪心 Oracle 捕获率；
- L3 的外部效用位于 L6 打乱分布高分位，而不是和随机打乱相同；
- L2 优于 L7 时，可以把收益归于当前非支配分布，而不只是“有100个方向”；
- 被 L3 独有选中的解具有更高的未来生存或 LOO 效用。

必须预先接受以下可能的负结果：

- 连续得分提高标签稳定性，却没有提高外部效用；
- L2 有效但融合无增益，应改为更简单的方向单支路；
- 固定0.5或反向调度与当前调度相同/更好，当前时间故事应删除；
- 改善只在 Hybrid 自己的轨迹出现，在 AnchorNative 轨迹消失，说明结论有明显状态分布依赖；
- L3 未超过打乱对照，说明变化可能只来自固定25%或打破二值并列。

## 12. 执行命令

```powershell
$env:ADAMAO_PLATEMO_ROOT = (Resolve-Path '.').Path
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); r=runtests(fullfile(pwd,'Experiments','REMO_new2_AdaMaO_UniformMix_LabelValidation','tests','test_IndependentUtilityValidation.m')); assertSuccess(r);"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_IndependentUtilityValidation('smoke'); analyze_IndependentUtilityValidation('smoke');"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_IndependentUtilityValidation('pilot'); analyze_IndependentUtilityValidation('pilot');"
```

确认 pilot 的参考集和 Oracle 验证通过后执行：

```powershell
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_IndependentUtilityValidation('screening'); analyze_IndependentUtilityValidation('screening');"
```

只有 `Stage3_decision.csv` 明确允许进入 Stage 4 时，才开始训练大量关系网络。若为 `NO_EXTERNAL_LABEL_EVIDENCE`，应停止而不是通过增加网络复杂度挽救标签故事。
