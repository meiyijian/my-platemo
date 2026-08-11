# Stage 5：同候选池反事实与端到端优化验证实施规划

> **For agentic workers:** REQUIRED SUB-SKILL: use a plan-execution workflow and complete the checkbox steps in order. The frozen production algorithm is the target; only the label constructor may change in causal variants.

**Goal:** 先在同一候选池上验证“标签→关系模型→候选质量”的因果链，再在完全相同 UniformMix-OriginalRelation 运行时中只替换标签构造器，检验标签差异能否转化为最终 IGD+/IGD/HV 和真实候选收益。

**Architecture:** Stage 5A 复用 Stage 4 已验证的训练/评分实现，在完整快照上重训生产形状网络，并对固定中性候选池做离线 shadow evaluation，不计入官方 FE。Stage 5B 建立实验专用标签算法变体并进行5-run筛查；只有同时获得模型迁移证据并通过预注册门槛的当前算法与锚点基线进入30-run正式实验。所有生产参数、候选模式、关系训练、评价预算和随机 run ID 冻结。

**Tech Stack:** MATLAB、PlatEMO、Statistics and Machine Learning Toolbox、Deep Learning Toolbox、Stage 1–4 valid 结果。

---

## 1. 实验目的、启动条件和结论边界

必须同时满足：

1. Stage 3 的决策允许进入 Stage 4，并已识别至少一个优于打乱对照的非随机标签；若胜出者只是锚点，Stage 5 只能作为当前新标签的反证筛查；
2. Stage 4 主决策为 `PASS_MODEL_TRANSFER`、`PASS_DIRECTION_MODEL_ONLY` 或 `PASS_ANCHOR_MODEL_ONLY`；
3. Stage 4 每个问题家族至少4个有效 paired run；
4. 所选模型版本、排除版本和 `PAIR_SPLIT_OPTIMISTIC` 警告状态已写入 Stage 4 decision。

若 Stage 4 为 `LABEL_GAIN_NOT_TRANSFERRED` 或 `INSUFFICIENT_DATA`，不得启动高成本正式实验。`PASS_DIRECTION_MODEL_ONLY` 和 `PASS_ANCHOR_MODEL_ONLY` 只允许执行 Stage 5A/5B 的诊断性筛查，不自动授权 E2 的30-run正式实验。

本五阶段体系验证的是标签机制。完整论文仍需另行完成与 REMO、PC-SAEA 及其他近期算法的统一基准比较；不得把本阶段的内部标签消融表冒充完整 SOTA 对比。

## 2. 冻结生产算法和七个参数

生产目标入口必须直接使用：

```text
Algorithms/Multi-objective optimization/
  REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/
    REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m
```

正式参数固定为：

```matlab
parameters = {3000,0.50,0.25,0.80,0.35,4,6};
%              gmax pMix rGood qKeep lambda0 nMin nMax
```

除专门的 `rGood` 参数敏感性外，所有变体必须使用上述七值。不得恢复已经删除的课程学习比例、置信门控、权重、`tau_err` 或其他共享旧版本参数。

统一问题矩阵：

| Problem | M | Requested D | Actual D | N | maxFE |
|---|---|---:|---:|---:|---:|
| DTLZ2 | 10、20 | 30 | 30 | 100 | 500 |
| DTLZ4 | 10、20 | 30 | 30 | 100 | 500 |
| DTLZ7 | 10、20 | 30 | 30 | 100 | 500 |
| WFG3 | 10、20 | 30 | 31 | 100 | 500 |
| WFG7 | 10、20 | 30 | 30 | 100 | 500 |

种子和配对键沿用前四阶段：

```matlab
seed = problemIndex*10000 + M*100 + run;
pairedKey = sprintf('%s_M%d_run%03d',problem,M,run);
```

## 3. 端到端标签算法变体

所有新增类放在实验目录 `algorithms/end_to_end`，使用唯一类名，严禁修改冻结生产目录。

| Code | Class | 标签定义 | 作用 |
|---:|---|---|---|
| E0 | `LVUniformMix_E0_AnchorNative` | 原始 `LabelDyn` 自然比例 | 同运行时锚点基线 |
| E1 | `LVUniformMix_E1_NDScoreQ25` | `ScoreV` 前25% | 方向单支路 |
| E2 | 冻结生产类 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original` | 当前动态融合前25% | 论文目标算法 |
| E3 | `LVUniformMix_E3_HybridFixed` | 固定 `alpha=0.5` | 调度消融 |
| E4 | `LVUniformMix_E4_HybridReverse` | `alpha=FE/maxFE` | 反向调度消融 |

E0/E1/E3/E4 必须共享一个实验 base，base 从冻结生产类逐句复制。唯一允许变化的位置是生成训练 `Catalog` 的函数。以下内容必须完全相同：

```text
初始化和 Archive
kEff/Nref/theta
GetRelationPairs 和原始 DataProcess
patternnet 架构及训练
SDE fitrsvm
UniformMix pMix 专用模式流
AdaMaOSelection
qKeep/lambda0/nMin/nMax
真实评价截断和 RefSelect
```

E0 仍需计算并返回当前 `Ref` 供候选生成使用；不得因为不用 `ScoreV` 就改变代表解或候选流程。E1 仍使用同一次方向计算产生的 Ref，不得另选参考解。

### 3.1 可选几何一致性敏感性

当前方向关联使用原始 `PopObj`，PBI 使用 `PopObj-Zmin`。只有 Stage 3 明确显示方向分支有效时，才增加探索性：

```text
E5 LVUniformMix_E5_GeometryConsistent
```

E5 将方向构造和关联统一到理想点坐标：`V=normalize(Craw-Zmin)`，关联使用 `PopObj-Zmin`。E5 只能进入5-run敏感性，不能与旧结果混为同一算法。如果 E5 明显优于 E2，必须暂停正式实验，由项目负责人决定是否更换论文算法并重跑前四阶段。

## 4. Stage 5A：同候选池离线反事实

### 4.1 固定输入

使用 Stage 4 expanded 中 target ratio `[0.20,0.60,0.90]` 的 valid snapshot、Stage 2 的 E0–E4 对应标签，以及 Stage 4 已通过对齐测试的训练/评分代码。每个 `Problem/M/Behavior/run` 使用同一 Population、Ref、问题边界和独立 Oracle。

Stage 1 快照保存 `RefEvalID/RefObj` 而不是重复保存 Ref 决策。必须按 `RefEvalID` 从 `evaluations.Decision` 重建 `RefDec`，并断言重建行数等于 `kEff`、EvalID 全部属于当前 Population、重建目标与 `RefObj` 在 `1e-12` 容差内一致；任一失败即标记 source invalid，不能重新调用 `RefSelect` 猜一个 Ref。

Stage 4 的三折网络只用于证明未见解泛化，不能直接任选其中一折作为 Stage 5A 模型。Stage 5A 对每个 snapshot/标签版本重新训练3个“完整快照 deployment replicate”：

```matlab
deploymentSeed = baseSeed*1000 + SnapshotID*10 + (replicateID+3);
replicateID = 1:3;
```

每次训练均使用该标签版本的完整 Population，逐句复制生产 `GetRelationPairs + DataProcess + mapminmax + patternnet + train`，保持普通无权训练和生产默认网络划分；不得沿用 Stage 4 为外部交叉验证设置的 `dividetrain`。同一 replicate 的所有标签版本使用同一 seed，训练前保存 RNG、训练后恢复。三个 replicate 分别对共同候选池选 Top4/Top6并分别保存结果，分析时对三次网络结果等权汇总；不得挑选最好的一次，也不得先平均三个模型分数再制造生产代码中不存在的集成模型。

### 4.2 中性候选池

对每个 snapshot 用固定种子生成200个共同候选：

```matlab
poolSeed = baseSeed*1000 + SnapshotID + 90000;
Parent = [PopulationDec;RefDec];
CandidatePool = OperatorGA(Problem,Parent,{1,15,1,5});
```

如果一次 `OperatorGA` 返回少于200行，继续用同一专用 RandStream 生成，直到累计200个；随后：

1. 删除非有限决策；
2. 将数值误差裁剪到 `Problem.lower/upper`；
3. 按决策向量逐行去重，保留首次出现；
4. 若去重后少于100个，标记该 snapshot `INSUFFICIENT_POOL`。

候选池生成使用专用离线 RNG，调用前后恢复全局 RNG。所有模型版本读取完全相同的 CandidatePoolHash。

### 4.3 shadow 真实目标和效用

本问题矩阵均为无约束 DTLZ/WFG。使用：

```matlab
CandidateObj = Problem.CalObj(CandidatePool);
```

不得调用 `Problem.Evaluation`，因此不增加官方 FE。shadow 数量和耗时单独记录，不进入算法运行时间或最终性能曲线。

使用 Stage 3 同一 PF 参考集和归一化，计算每个候选加入当前已评价 Archive 后的：

```text
MarginalIGDPlusGain
NondominatedAdmission
DistanceToOraclePF
```

每个 deployment replicate 复制生产 `model_select` 对共同候选池打分，取 Top4 和 Top6，报告：

```text
Top4MeanGain, Top4BestGain, Top4AdmissionRate
Top6MeanGain, Top6BestGain, Top6AdmissionRate
NDCGAt20, KendallTauB, RegretToOracleTop4
```

这一步是“标签→模型→同候选池质量”的最强局部因果证据，但候选池不是生产代理搜索完整分布，三个网络 replicate 也只是对训练随机性的受控重复，因此仍不能代替端到端实验。统计独立单位仍是 run，不是 snapshot、候选或网络 replicate。

## 5. Stage 5B：5-run端到端筛查

### 5.1 固定矩阵

实现验证先运行一个不进入统计的 smoke：

```text
Algorithms: E0–E4
Problem/M/D: DTLZ2/M3/D3
Problem.N/maxFE/run: 20/35/1
Parameters: gmax=1；其余六参数保持正式值
Expected initialFE: 32
Total: 5 jobs
```

smoke 唯一允许的参数例外是 `gmax=1`；它只用于确认五个类能完成初始化、标签、关系训练、选择、剩余 FE 截断、保存和 validator。smoke 结果不得进入 screening、formal 或论文表格。

对 E0–E4 全部运行：

```text
5 algorithms × 5 problems × 2 M × 5 paired runs = 250 jobs
```

顺序可按 job index 分配到多台主机，但每个 job 的 seed 只由公式决定，不能按主机编号改种子。不同主机必须写入互不重叠的结果文件；已有 valid 文件跳过，invalid-existing 文件阻塞。

### 5.2 结果文件

端到端核心结果使用与 profile 无关的公共路径，保证 screening 的 run1–5 能被 formal 严格复用：

```text
results/stage5/end_to_end/<Algorithm>/<Problem>/M<M>/run_<RRR>.mat
results/stage5/manifests/<profile>_manifest.csv
results/stage5/manifests/<profile>_manifest.mat
```

顶层变量：

```text
metadata
finalPopulation
IGD
IGDp
HV
runtime
validation
```

生产性能文件不强制包含逐代审计。另在 `results/stage5/mechanism_audit/` 保存受限的 E2 审计等价副本；其 `generationOutcomeRows` 只使用已经正式评价的候选，保存：

```text
Generation, FEBefore, FEAfter, CandidateMode,
SelectedCount, NondominatedAdmissionCount,
ArchiveIGDpBefore, ArchiveIGDpAfter, SignedIGDpGain
```

这些记录不得产生 shadow FE；E2 的审计副本必须先通过与冻结生产类的逐值等价测试。screening/formal 的最终性能指标 E2 始终直接运行冻结生产类，审计副本只用于 run1 的机制记录，不与生产性能文件互相替代。

### 5.3 主次指标

```text
Primary:   final IGDp（越小越好）
Secondary: final IGD、HV、runtime
Mechanism-audit only: 候选 admission、SignedIGDpGain
```

M=20 的 HV 可能采用近似或成本较高；必须为每个结果固定 `metricSeed=baseSeed+700000`，在计算前保存 RNG、计算后恢复 RNG，并记录 PlatEMO 指标实现、实现文件 hash 和随机状态。若 HV 非有限或在同一 `metricSeed` 下重复计算不一致，标记 `HV_INVALID` 并保留为探索性诊断，不得替代 IGDp 主结论。候选 admission 与 `SignedIGDpGain` 只来自 E2 run1 的机制审计副本，不能伪装成全部算法、全部 run 都具备的正式性能指标。

## 6. Stage 5C：正式30-run验证

### 6.1 默认正式比较

只有 Stage 4 主决策为 `PASS_MODEL_TRANSFER`，且当前目标算法 E2 通过第10.1节 screening gate 时，才运行：

```text
E0 AnchorNative vs E2 HybridCurrent
2 algorithms × 5 problems × 2 M × 30 paired runs = 600 jobs
```

正式 manifest 直接引用公共 `end_to_end` 路径中已经通过严格 validator 的 screening run1–5；run6–30新增，不复制、不覆盖，也不得重跑后挑选更好的一次。

如果 E1/E3/E4 在 screening 明显优于 E2，而 E2 与最佳版本的几何 IGDp 比率超过1.05，则暂停 formal。因为这意味着论文目标算法可能需要改变，执行主机不得自行把算法从 E2 换成新版本。

### 6.2 正式统计

每个 Problem/M 单元：

- 报告30次中位数、IQR、均值、标准差；
- E2-E0 使用 paired Wilcoxon signed-rank；
- 报告 Hodges–Lehmann 配对位置差或中位配对差、rank-biserial effect、95% run bootstrap CI；
- 10个 Problem/M 单元的主指标 p 值使用 Holm 校正；
- 报告 E2/E0 的几何均值比，先在每个单元计算比率再跨单元等权汇总；
- 跨算法总体排名可用 Friedman，但不能替代每单元效应量。

不得跨问题直接平均原始 IGDp/HV 数值。

## 7. Stage 5D：`rGood` 正组比例敏感性

该实验专门回答“前1/4是否只是随意选择、是否应改为1/2”。固定 E2 其余六参数，运行：

```matlab
rGoodValues = [0.15 0.25 0.35 0.50];
Problems = {'DTLZ2','DTLZ4','WFG3','WFG7'};
M = 10;
Runs = 1:5;
maxFE = 500;
```

共 `4 rGood × 4 problems × 5 runs = 80 jobs`。WFG3 actualD=31，其余30。使用相同 paired run；主指标为 IGDp，辅助报告关系三类样本比例和网络 query 指标。

敏感性结果必须使用独立路径，不能覆盖 `rGood=0.25` 的默认 E2 screening/formal 文件：

```text
results/stage5/rgood/rGood_<VALUE>/<Problem>/M10/run_<RRR>.mat
```

`<VALUE>` 使用固定无歧义编码 `015/025/035/050`。即使 `rGood=0.25`，也重新写入 `rgood/rGood_025`；分析时可校验其与默认 E2 同 seed 结果等价，但不得用复制文件代替真实运行。

解释规则：

- 如果0.25在多数问题不劣且总体最好，保留默认值，并把0.25解释为经验选择而非理论最优；
- 如果0.35或0.50稳定更好，不能继续沿用0.25的旧结果，必须决定是否更新目标算法并重跑正式实验；
- 如果四值差异很小，写成“不敏感区间”，不要声称精确最优；
- 不允许看完结果后增加新的比例点并把它混入确认性分析，新增点只能标探索性。

## 8. 计划创建的文件及职责

```text
BuildCommonCandidatePool.m
TrainFullSnapshotDeploymentReplicates.m
EvaluateShadowCandidatePool.m
ComputeCandidateCounterfactualMetrics.m
run_CommonCandidateCounterfactual.m
ValidateCommonCandidateCounterfactualFile.m
algorithms/end_to_end/LVUniformMixEndToEndBase.m
algorithms/end_to_end/LVUniformMix_E0_AnchorNative.m
algorithms/end_to_end/LVUniformMix_E1_NDScoreQ25.m
algorithms/end_to_end/LVUniformMix_E3_HybridFixed.m
algorithms/end_to_end/LVUniformMix_E4_HybridReverse.m
algorithms/end_to_end/LVUniformMix_E2_HybridCurrentAudit.m
algorithms/end_to_end/LVUniformMix_E5_GeometryConsistent.m  % 仅在第3节门槛触发后创建
run_LabelEndToEndExperiment.m
ValidateLabelEndToEndResultFile.m
analyze_LabelEndToEndScreening.m
analyze_LabelEndToEndFormal.m
run_RGoodSensitivity.m
analyze_RGoodSensitivity.m
tests/test_LabelEndToEndExperiment.m
results/stage5/                       % 运行时生成，不提交 Git
```

runner 必须支持：

```text
candidate_counterfactual
smoke
screening
formal
rgood_sensitivity
```

并沿用以下安全约定：有效结果跳过、无效既有结果阻塞、`.tmp.mat` 原子保存、manifest 同时保存 CSV/MAT、失败错误完整记录。

## 9. 实施任务清单

### Task 1：证明端到端变体只改变标签

- [ ] 对 E0/E1/E3/E4 建立共享 base，禁止复制四套可能漂移的主循环。
- [ ] 静态检查七参数、候选模式、关系训练和选择函数与冻结 E2 一致。
- [ ] 为每个变体输出 mechanism manifest，逐项写出唯一变化公式。
- [ ] E2 审计副本与冻结生产类在 smoke 和 DTLZ2/M10/pilot 同 seed 下最终目标/决策逐值相等，容差 `1e-12`。
- [ ] 对冻结生产目录计算并保存 hash；整个 Stage 5 期间 hash 不得变化。

### Task 2：实现同候选池反事实

- [ ] 候选池生成、去重和边界检查使用固定 poolSeed，调用后恢复 RNG。
- [ ] 断言每个模型版本的 CandidatePoolHash 完全相同。
- [ ] 为每个标签版本训练3个完整快照 deployment replicate；同 replicate 共用 seed，且训练路径不得设置 Stage 4 专用的 `dividetrain`。
- [ ] validator 检查 replicateID 恰为1:3、deploymentSeed 公式正确，并确认没有从三次训练中选择最佳网络。
- [ ] `CalObj` shadow evaluation 不得改变 `Problem.FE`；测试调用前后 FE 相等。
- [ ] 对手工候选集验证 IGD+ gain 符号：改善为正、变差/无贡献不应伪造为正。
- [ ] 保存所有候选的分数与真实效用，不能只保存选中的 Top4/Top6。

### Task 3：实现端到端 runner/validator

- [ ] 构造 Problem 后记录 requestedD/actualD，并断言 WFG3=31。
- [ ] 每个 Algorithm/Problem/M/run 使用相同 base seed 和 run ID。
- [ ] 检查 `completedFE==maxFE`、最终 Population 非空、IGD/IGDp/runtime 有限。
- [ ] validator 检查算法类名、七参数、git commit、生产 hash、seed 和 pairedKey。
- [ ] 不得用某算法缺失的 run 与另一算法不同 run 配对。

### Task 4：按门槛运行

- [ ] 完成全套测试和 smoke。
- [ ] 先完成 Stage 5A；如果主标签不优于锚点且不优于随机/方向对照，停止 Stage 5B。
- [ ] Stage 5B 运行250个 screening 作业并分析。
- [ ] 只有 Stage 4=`PASS_MODEL_TRANSFER` 且 screening gate 通过，才启动 E0/E2 formal；否则写停止或简化决策。
- [ ] `rGood` 敏感性可与 screening 并行，但其结果不能事后改变 screening 主假设。

### Task 5：正式统计和论文证据表

- [ ] 对每个 Problem/M 输出30次原始值、配对差和校正检验。
- [ ] 输出胜/平/负，平局必须依据预注册统计和效应，不按小数点肉眼判断。
- [ ] 把机制证据链合并为：Stage 2 分歧、Stage 3 外部效用、Stage 4 query、Stage 5 candidate/end-to-end。
- [ ] 任何链条断裂都在论文限制中明确写出，不用另一个指标替代失败环节。

## 10. Screening 和 formal 决策规则

### 10.1 Screening gate

在 Stage 4=`PASS_MODEL_TRANSFER` 的前提下，E2 相对 E0 同时满足以下条件才进入默认 formal：

1. 10个 Problem/M 单元的 IGDp 几何均值比 `E2/E0 <= 1.05`；
2. IGDp 恶化超过20%的单元不多于2个；
3. DTLZ2 和 WFG7 不出现一致且明显的退化；
4. WFG3 或 DTLZ7 至少一个问题在 M10/M20 中出现可重复改善；
5. Stage 5A 的 Top4/Top6 候选效用不低于 E0，且方向与最终 IGDp 一致。

五次运行只作为方向门槛，不是正式统计证明。

### 10.2 Formal decision

| DecisionCode | 条件 | 可支持的表述 |
|---|---|---|
| `PASS_END_TO_END` | E2 在总体和至少一个困难问题上优于 E0，Holm校正后有主效应，且无系统性保护问题退化 | 标签机制有端到端支持 |
| `MECHANISM_ONLY_NO_FORMAL_GAIN` | E2 与 E0 未检出稳定最终性能差异，但 Stage 2–5A 机制链一致 | 可作为机制探索；不能声称显著提升、等效或非劣 |
| `SIMPLER_VARIANT_WINS` | E1/E3/E4 筛查明显优于 E2 | 暂停并由项目负责人决定是否更换论文算法 |
| `NO_END_TO_END_TRANSFER` | Stage 3/4 有改善但最终 IGDp 不改善 | 只能报告局部标签/模型效果，不能声称优化提升 |
| `STOP_HARMFUL_LABEL` | 多个单元显著或大幅退化，尤其 DTLZ2/WFG7 | 删除当前标签机制或回到简化版本 |
| `INSUFFICIENT_DATA` | 任何正式 Problem/M 少于30个完整配对 | 补跑，不能用不平衡样本替代 |

## 11. 预期结果（研究假设，不是通过标准）

如果完整故事成立，合理预期是：

- 同候选池下 E2 模型选出的 Top4/Top6 具有更高 IGD+ gain；
- E2 在 WFG3、DTLZ7 等困难结构上更可能获益，同时不损伤 DTLZ2/WFG7；
- E3/E4 不优于 E2，支持当前时间调度；
- E1 不优于 E2，支持两路融合而非方向单支路；
- `rGood=0.25` 在0.15–0.50范围内具有较好折中，但不一定是每个问题的精确最优。

必须接受的反例：

- Stage 5A 有候选排序改善但完整优化无改善，说明效应被后续选择/轨迹抵消；
- E1 与 E2 相同或更好，说明融合和调度不必要；
- E3/E4 更好，说明当前“早连续、晚二值”故事不成立；
- 0.50 明显更好，说明前1/4不能仅凭 PC-SAEA 习惯保留；
- 只有某一个问题改善，不能推广为普遍标签提升。

## 12. 执行命令

```powershell
$env:ADAMAO_PLATEMO_ROOT = (Resolve-Path '.').Path
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); r=runtests(fullfile(pwd,'Experiments','REMO_new2_AdaMaO_UniformMix_LabelValidation','tests','test_LabelEndToEndExperiment.m')); assertSuccess(r);"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_CommonCandidateCounterfactual('expanded');"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelEndToEndExperiment('smoke');"
```

Stage 5A 和 smoke 有效后：

```powershell
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelEndToEndExperiment('screening'); analyze_LabelEndToEndScreening;"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_RGoodSensitivity; analyze_RGoodSensitivity;"
```

只有 `Stage5_screening_decision.csv` 明确允许后执行：

```powershell
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelEndToEndExperiment('formal'); analyze_LabelEndToEndFormal;"
```

最终交接必须包含：600个正式配对作业的完整性表、全部原始指标、校正统计、机制链汇总、负结果和唯一 DecisionCode。不得只交“最好均值”表格。
