# Stage 4：关系模型隔离泛化与候选查询验证实施规划

> **For agentic workers:** REQUIRED SUB-SKILL: use a plan-execution workflow and complete the checkbox steps in order. No solution identity may appear on both sides of the primary train/test split.

**Goal:** 验证 Stage 3 中表现较好的伪标签能否训练出对未见基础解和下一批真实评价候选更有效的关系模型，并量化当前按关系对随机划分得到的 `p_err` 是否因端点泄漏而过于乐观。

**Architecture:** 在固定快照上按稳定 EvalID 做三折 solution-disjoint 交叉验证。每折只用训练解之间的关系对训练与生产算法同架构的 patternnet；测试时分别评价“完全未见解之间的关系”和“未见候选相对训练种群的真实查询排序”。所有标签版本使用相同快照、相同解折、相同网络初始化种子和相同关系对预算。

**Tech Stack:** MATLAB Deep Learning Toolbox、Stage 1 的决策/目标/未来真实评价、Stage 2 标签、Stage 3 外部效用。

---

## 1. 实验目的、研究问题和证据层级

本阶段区分三个误差：

```text
E_pair     当前 DataProcess 按关系对随机划分的伪标签误差
E_solution 按基础解完全隔离后，对未见解关系的外部效用误差
E_query    对算法真实查询方式下候选排序和候选真实收益的误差
```

主结论以 `E_query` 和 `E_solution` 为准。`E_pair` 只用于展示当前内部误差有多乐观，不能作为“标签更好”或“优化会提升”的证据。

预注册假设：

1. Stage 3 胜出的标签版本在 solution-disjoint 的外部关系 AUC 和 query NDCG 上优于锚点对照；
2. 这种优势能在 Hybrid 与 AnchorNative 两类轨迹上保持同方向；
3. `E_pair` 通常优于 `E_solution/E_query`，但二者差距不能解释全部标签版本差异；
4. 如果标签外部效用改善却不能传递到模型，本论文不能把关系学习链路当成已验证贡献。

## 2. 启动资格和必做版本

只有 Stage 3 决策属于以下之一才运行：

```text
PASS_LABEL_COMPLEMENTARITY
SIMPLIFY_DIRECTION_ONLY
SIMPLIFY_ANCHOR_ONLY
PASS_LABEL_BUT_DROP_SCHEDULE
```

如果是 `NO_EXTERNAL_LABEL_EVIDENCE`、`INSUFFICIENT_REFERENCE_STABILITY` 或 `INSUFFICIENT_DATA`，本阶段必须停止，不能通过更复杂网络挽救标签。

### 2.1 固定比较组

无论 Stage 3 谁胜出，Stage 4 至少比较：

| ModelLabel | 来源 | 作用 |
|---|---|---|
| `M1_ANCHOR_MARGIN_Q25` | L1 | 固定25%的锚点对照 |
| `M2_ND_SCORE_Q25` | L2 | 非支配方向单支路 |
| `M3_SELECTED_LABEL` | Stage 3 决策选中的主版本 | 检验最强标签能否传递到模型 |

`M3_SELECTED_LABEL` 映射规则必须写入 metadata：

- `PASS_LABEL_COMPLEMENTARITY`：L3；
- `SIMPLIFY_DIRECTION_ONLY`：L2，此时 M2 与 M3 合并，只运行一次；
- `SIMPLIFY_ANCHOR_ONLY`：L1，此时 M1 与 M3 合并，只运行一次；
- `PASS_LABEL_BUT_DROP_SCHEDULE`：使用 Stage 3 在 L2/L3/L4/L5 中主效用最高且结构最简单的版本；并把选择依据、效应量和 decision 文件 hash 写入 metadata。

L0 原始自然比例作为 `M0_ANCHOR_BINARY_NATIVE` 次要历史对照，只在 screening run1–3 运行。L6 打乱标签只在每个 `Problem/M/Behavior` 的 run1、三个检查点、10次 permutation 上运行，不能把100次全部训练成网络后再挑选结果。

## 3. 固定数据范围和检查点

使用 Stage 3 已验证的固定检查点中的三个：

```matlab
targetRatios = [0.20 0.60 0.90];
```

每个 target 选择规则与 Stage 3 一致；不复制缺失检查点。

本阶段不重新运行优化，而是读取前三阶段结果。输入 profile 映射必须固定为：

| Stage 4 profile | Stage 1/2/3 source profile | 使用范围 |
|---|---|---|
| `smoke` | `smoke` | DTLZ2/M3/run1；源 `maxFE=35` |
| `pilot` | `screening` | DTLZ2、WFG3/M10/run1 子集；源 `maxFE=500` |
| `screening` | `screening` | 五问题、M10/M20、run1:3；源 `maxFE=500` |
| `expanded` | `screening` | 五问题、M10/M20、run1:5；源 `maxFE=500` |

路径分别为 `results/stage1/<sourceProfile>/`、`results/stage2/<sourceProfile>/` 和 `results/stage3/<sourceProfile>/`。选择 Stage 4 pilot 时使用 screening 源，是因为前三阶段 pilot 只含 DTLZ2，无法检查 WFG3 actualD=31；该映射必须写进 manifest，不能由执行主机自行猜测。

运行 profile：

| Profile | Problems | M | Runs | Behaviors | Folds | 用途 |
|---|---|---|---:|---|---:|---|
| `smoke` | DTLZ2 | 3 | 1 | Hybrid | 2 | 只验证训练/预测管线 |
| `pilot` | DTLZ2、WFG3 | 10 | 1 | Hybrid、AnchorNative | 3 | 检查隔离、耗时和WFG3 D=31 |
| `screening` | 五个问题 | 10、20 | 1:3 | Hybrid、AnchorNative | 3 | 方向性模型证据 |
| `expanded` | 五个问题 | 10、20 | 1:5 | Hybrid、AnchorNative | 3 | 仅 screening 通过后补齐 |

WFG3 requestedD=30、actualD=31；其他正式问题 actualD=30。所有模型输入维度是 `2*actualD`，不能假定永远是60。

## 4. 三折 solution-disjoint 划分

### 4.1 公共折必须独立于伪标签

为了让所有标签版本测试完全相同的解，折划分不能按某个版本的 Catalog 分层。使用 Stage 3 的独立 `OracleGreedyTop25` 分层：

1. 分开 OracleTop25 和其余75个 EvalID；
2. 使用 `splitSeed=baseSeed*1000+SnapshotID+70000` 分别打乱两组；
3. 按轮转方式分配到3折；
4. 每折约包含8–9个 Oracle 解和25个非 Oracle 解；
5. 同一 snapshot 的所有标签版本共用完全相同 foldID。

若 smoke 的解数不是100，仍按相同方法分配，并要求每折至少有2个 Oracle 与2个非 Oracle 解。

### 4.2 严格隔离约束

对 fold `f`：

- 训练基础解：`foldID~=f`；
- 测试基础解：`foldID==f`；
- 训练关系对只能是 train–train；
- 主测试关系对只能是 test–test；
- query 测试允许 candidate(test)–anchor(train)，因为这模拟新候选相对已知种群的查询，但测试候选从未作为训练端点出现。

validator 必须显式检查：

```matlab
isempty(intersect(trainEvalID,testEvalID))
```

还必须检查训练关系对的两个端点都属于 train，test–test 两端都属于 test。不能只检查关系对行号。

## 5. 关系对抽样与网络训练冻结

### 5.1 训练关系定义

对任一 Catalog，关系标签保持原始语义：

```text
0  两个训练解属于同一粗组
+1 前者属于正组、后者属于非正组
-1 前者属于非正组、后者属于正组
```

删除自配对。为了消除不同标签比例和关系对数量的影响，所有版本采用相同的生产形状预算 `2:1:1`：

```matlab
nCross = min([1000,countPlus1,countMinus1]);
nZero  = min(2*nCross,countZero);
```

分别抽取 `nZero` 个0类、`nCross` 个+1类、`nCross` 个-1类。若 `nCross<50`，该 fold 标记 `INSUFFICIENT_RELATION_CLASSES`，不训练网络。

抽样和网络初始化使用 `networkSeed=baseSeed*1000+SnapshotID*10+foldID`。在本协议的最大 baseSeed 下该值保持在 MATLAB `rng` 的合法范围内。同一 snapshot/fold 的所有标签版本使用同一 seed；抽样和训练后恢复 RNG。

### 5.2 网络架构

严格对齐生产算法：

```matlab
xDim = 2*actualD;
hidden = [ceil(xDim*1.5),xDim,ceil(xDim/2)];
net = patternnet(hidden);
net.trainParam.showWindow = 0;
net.divideFcn = 'dividetrain';
```

归一化 `mapminmax` 只在训练关系输入上拟合，然后应用到测试/query 输入。因为外部三折已承担验证，设置 `dividetrain` 避免网络内部再次把同一基础解的关系对随机拆分。

`trainParam.epochs` 保持当前 MATLAB/生产默认值，并将实际值写入 metadata。不得根据某个标签版本单独提前停止；如果训练失败，该 fold 记失败，不能用另一个版本的网络替代。

网络类别编码必须复制独立算法的 `onehotconv` 列顺序，并用手工三样本测试确认 +1/0/-1 的输出列没有颠倒。

## 6. 三种测试任务

### 6.1 `E_pair`：当前随机关系对留出误差（仅次要对照）

在完整 snapshot 上复制生产 `DataProcess` 的按关系类别75%/25%随机划分，训练一次生产形状网络，报告：

```text
PairRandomAccuracy
PairRandomMacroF1
PairRandomPError
EndpointLeakageRate
```

`EndpointLeakageRate` 定义为测试关系对中至少一个端点也出现在训练关系对的比例。预计通常很高；该结果不得进入主通过门槛。

### 6.2 `E_solution`：未见解关系泛化

test–test 关系真值不使用伪 Catalog，而使用 Stage 3 `UtilityLOO`：

```matlab
tol = max(1e-12,1e-6*max(abs(UtilityLOO)));
truth = sign(UtilityLOO_i-UtilityLOO_j);
abs(diff)<=tol 时 truth=0;
```

报告：

```text
SolutionBalancedAccuracy
SolutionMacroF1
SolutionPairwiseAUC      % 排除 truth=0 后，比较方向是否正确
SolutionBidirectionalError
```

`SolutionBidirectionalError` 是 `(i,j)` 与 `(j,i)` 预测不能互为相反关系的比例。

### 6.3 `E_query`：真实候选式查询

候选评分必须复制独立算法 `AdaMaOSelection/model_select` 的四组关系：

```text
[C1, candidate]
[candidate, C1]
[C2, candidate]
[candidate, C2]
```

并复制其 `C_SCORE(1)-C_SCORE(2)` 净证据公式。这里的 C1/C2 只来自训练基础解，candidate 来自测试折，避免 candidate 进入训练。

第一类 query 使用当前测试折解，真值为 Stage 3 `UtilityLOO/OracleTop25`，报告：

```text
QueryKendallTauB
QueryNDCGAtQuarter
QueryPrecisionAtQuarter
QueryOracleAUC
```

第二类 query 使用 Stage 1 中该 snapshot 后实际被评价的下一批新 EvalID。它们必须满足 `EvalID` 不在当前 Population 中。真值为：

```text
CandidateNondominatedAdmission
CandidateMarginalIGDPlusGain
CandidateSurvivalH1
```

这类候选带有原行为策略的选择偏差，所以单独报告为 `ObservedSelectedCandidate`，不能冒充完整候选池反事实；完整同候选池验证放在 Stage 5 的机制审计中。

## 7. 计划创建的文件及职责

```text
BuildSolutionDisjointFolds.m
BuildFrozenRelationPairs.m
TrainFrozenOriginalRelationNet.m
PredictExternalRelations.m
ScoreCandidatesLikeUniformMix.m
ComputeRelationGeneralizationMetrics.m
BuildObservedCandidateQueries.m
run_RelationModelGeneralization.m
ValidateRelationModelGeneralizationFile.m
analyze_RelationModelGeneralization.m
tests/test_RelationModelGeneralization.m
results/stage4/                       % 运行时生成，不提交 Git
```

`ScoreCandidatesLikeUniformMix.m` 必须有一个对齐测试：在实验审计类暴露相同网络、标准化结构、Population 和候选池时，其输出与生产 `model_select` 得分逐元素相等，容差 `1e-12`。

结果路径：

```text
results/stage4/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
```

顶层变量：

```text
metadata
foldAssignments
trainingRows
pairRandomRows
solutionMetricRows
queryMetricRows
observedCandidateRows
validation
```

metadata 必须记录 Stage 1/2/3 source hash、选中标签映射、网络架构、默认 epochs、每折网络 seed 和 toolbox/MATLAB 版本。

## 8. 实施任务清单

### Task 1：建立无泄漏折和关系对

- [ ] 为每个固定 snapshot 创建独立于伪标签的公共 foldID。
- [ ] 对所有模型版本验证 foldID hash 完全相同。
- [ ] 生成 train–train、test–test 和 test–train query 索引，保存端点 EvalID。
- [ ] 写故意泄漏的单元测试，确认 validator 会拒绝同一 EvalID 跨 train/test。
- [ ] 写反向关系对测试，确认 `(i,j)=+1` 时 `(j,i)=-1`。

### Task 2：冻结训练预算和网络初始化

- [ ] 实现固定 `2:1:1` 关系类预算，并记录每类可用数和实际抽样数。
- [ ] 对同 snapshot/fold 的不同标签版本使用相同 networkSeed。
- [ ] 设置 `divideFcn='dividetrain'`，确认 mapminmax 只由训练数据拟合。
- [ ] 记录训练时间、epochs、perform 和失败异常；不得静默重试直到成功。

### Task 3：实现三层评价

- [ ] 复制 DataProcess 路径计算 E_pair 和端点泄漏率。
- [ ] 用 UtilityLOO 构造 E_solution 外部关系真值，正确处理效用并列。
- [ ] 逐句复制候选四组净证据得分，完成生产对齐测试。
- [ ] 对下一批真实评价候选重建 admission、IGD+ gain 和 H1 survival。
- [ ] 所有指标先按 fold 计算，再在 snapshot 内对有效 fold 等权平均。

### Task 4：分阶段运行

- [ ] smoke 必须完成网络训练、测试和 validator，不进入统计。
- [ ] pilot 记录单网络和单 snapshot 耗时，据此估算 screening 总时间。
- [ ] screening 只跑 run1–3；通过后 expanded 补 run4–5。
- [ ] L6 打乱网络仅按第2.1节的受限子集运行，禁止扩大后选择最有利结果。
- [ ] 中断恢复时有效文件跳过、无效文件阻塞、临时文件不覆盖正式文件。

### Task 5：统计和阶段决策

- [ ] 主比较使用同 snapshot/fold/run 的配对差。
- [ ] 按 run 聚类 bootstrap 10000次，seed=`20260811`。
- [ ] 主要结果为 QueryNDCG、QueryOracleAUC、SolutionPairwiseAUC；E_pair 为次要。
- [ ] 同指标多版本比较使用 Holm 校正，并报告效应量和95% CI。
- [ ] DTLZ/WFG 分开报告；若两个家族方向相反，标记异质性，不得只报总体平均。

## 9. 分析输出

```text
results/stage4/<profile>/analysis/
  Stage4_run_manifest.csv
  Stage4_pair_split_leakage.csv
  Stage4_solution_generalization.csv
  Stage4_query_generalization.csv
  Stage4_observed_candidate_utility.csv
  Stage4_network_runtime.csv
  Stage4_pairwise_statistics.csv
  Stage4_decision.csv
  Stage4_analysis.mat
```

## 10. Stage 4 决策规则

| DecisionCode | 条件 | 后续动作 |
|---|---|---|
| `PASS_MODEL_TRANSFER` | Stage 3 主版本在 QueryNDCG/QueryAUC 至少一项优于锚点对照，另一项不劣；SolutionAUC 同方向；DTLZ/WFG 均非负 | 进入 Stage 5 |
| `PASS_DIRECTION_MODEL_ONLY` | L2 模型最好且融合模型不优于 L2 | 可进入 Stage 5 的诊断性筛查，但当前 E2 不具备启动正式30-run的模型证据；重点比较 E0/E1/E2 |
| `PASS_ANCHOR_MODEL_ONLY` | 锚点模型不弱于方向/融合 | 可做 E0/E2 的5-run反证筛查；删除新标签提升主张，不直接启动正式30-run |
| `LABEL_GAIN_NOT_TRANSFERRED` | Stage 3 标签外部效用提高，但 E_solution/E_query 无改善或变差 | 停止关系模型贡献声明；检查硬化和网络容量，但不自动加模块 |
| `PAIR_SPLIT_OPTIMISTIC` | E_pair 明显好于 E_solution/E_query，且端点泄漏率高 | 可与其他决策并列为警告；论文不能使用 p_err 证明泛化 |
| `INSUFFICIENT_DATA` | 任一问题家族有效 paired run 少于4，或多数 fold 关系类不足 | 补 expanded/修正抽样，不作结论 |

先依次判定 `INSUFFICIENT_DATA` 和 `LABEL_GAIN_NOT_TRANSFERRED`；只有两者均不成立时才在三个 PASS 代码中选择一个。PASS 条件发生重叠时，以 query 主指标更高的结构决定；若其 run-cluster 95% CI 大量重叠且差异小于0.01，则选择结构更简单的版本，不允许执行主机自行挑选最有利代码。

`PAIR_SPLIT_OPTIMISTIC` 是警告字段而不是单独的继续许可；进入 Stage 5 仍必须有一个 `PASS_*` 主代码。

## 11. 预期结果（研究假设，不是通过标准）

如果标签机制真正有用，合理预期是：

- 生产式随机关系对 `p_err` 最好看，但 solution-disjoint 指标更低；
- L3 或 Stage 3 选中的简化版本在 QueryNDCG/QueryAUC 上优于 L1；
- 模型优势能在下一批真实评价候选的 IGD+ gain 或 admission 上出现同方向；
- L6 打乱标签训练出的模型不应达到真实标签版本的 query 指标。

可能的负结果及含义：

- 标签本身与 Oracle 更一致，但 patternnet 无法利用：贡献停留在标签构造，不能声称改善关系代理；
- E_pair 提升而 E_query 不提升：属于伪标签拟合，不是优化相关泛化；
- 只有当前 Population 内测试有效，对下一批候选失效：存在分布外问题；
- M20 网络明显退化：可能是决策维数、关系对容量或硬标签压缩问题，需要如实分层报告。

## 12. 执行命令

```powershell
$env:ADAMAO_PLATEMO_ROOT = (Resolve-Path '.').Path
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); r=runtests(fullfile(pwd,'Experiments','REMO_new2_AdaMaO_UniformMix_LabelValidation','tests','test_RelationModelGeneralization.m')); assertSuccess(r);"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_RelationModelGeneralization('smoke'); analyze_RelationModelGeneralization('smoke');"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_RelationModelGeneralization('pilot'); analyze_RelationModelGeneralization('pilot');"
```

pilot 有效后运行 screening；只有 screening 产生 `PASS_*` 才补 expanded：

```powershell
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_RelationModelGeneralization('screening'); analyze_RelationModelGeneralization('screening');"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_RelationModelGeneralization('expanded'); analyze_RelationModelGeneralization('expanded');"
```

交接 Stage 5 时必须提供选中标签版本、排除版本、全部 query 指标、网络耗时和 `PAIR_SPLIT_OPTIMISTIC` 警告状态。
