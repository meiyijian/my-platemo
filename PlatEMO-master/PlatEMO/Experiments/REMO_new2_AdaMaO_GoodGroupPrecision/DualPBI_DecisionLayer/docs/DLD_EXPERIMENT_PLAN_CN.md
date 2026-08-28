# Dual-PBI 决策层实验详细规划

## Material Passport

- Origin Skill: academic-research-suite / experiment-agent
- Origin Mode: plan
- Origin Date: 2026-08-21
- Verification Status: SOURCE_GROUNDED_PLAN_NOT_EXECUTED
- Version Label: dld_experiment_plan_v1
- Approval Status: PENDING_USER_APPROVAL
- Working Language: MATLAB R2023a / PlatEMO
- Evidence Scope: 源码、既有正式 MAT/CSV 契约与既往 Stage 判决；本规划未运行任何新实验

## 0. 执行摘要

本实验不再回答“两个 PBI 视图是否互补”，因为已有互补性实验已经对此提供较强证据。本实验只回答下一层问题：

> 在每次形成训练 Catalog 的时刻，只使用当时已经可观测、部署时也能获得的状态信号，能否在未参与模型拟合的问题配置上，可靠地选择 V、A、固定混合，或回退到原始动态 Hybrid，从而降低相对于事后最佳动作的选择遗憾？

推荐采用四阶段、逐门槛推进：

1. `D1 数据与完整性`：只读复用现有 250 条 Hybrid 正式轨迹，分别生成在线特征表和未来效用表；不训练模型。
2. `D2 离线留出可行性`：以 leave-one-problem-out 为 Primary 外层划分，检验状态特征能否优于原始 Hybrid、训练折内最佳静态动作和仅使用进度的决策器。
3. `D3 小规模闭环筛选`：只有 D2 通过后才实现冻结策略，以 4 个诊断配置、10 个配对种子运行独立轨迹。
4. `D4 正式闭环验证`：只有 D3 通过且参考集稳定性问题解决后，才考虑 10 配置、25 个种子的正式算法级实验。

本轮用户审批建议只授权 `D1+D2`。`D3/D4` 必须在看到 D2 报告后重新批准。

## 1. 与现有证据的关系

### 1.1 已完成的证据

现有正式互补性实验包含 5 个问题、`M=10/20`、每配置 25 个固定种子，共 250 条独立 Hybrid 轨迹。当前 CSV 审查结论为：

- V/A Top-25% 平均 Jaccard 为 0.2326；
- 33/40 个 Problem-M-Stage 单元支持双向独有未来真阳性；
- 当前 Hybrid 的严格同时融合优势只有 1/40 个单元；
- 相对每个 run-stage 中更好的单视图，平均 `Delta_best=-0.02448`；
- WFG7 是最明确的融合失配问题；
- 当前未来真值来自 Hybrid 自身轨迹，因此属于 on-policy 关联证据。

详细证据位于：

```text
../DualPBI_Complementarity/results/analysis/formal/
    DPC_CSV_Analysis_Conclusion_CN.md
```

### 1.2 尚未完成的证据

现有实验尚未回答：

- 当前可观测信号是否能预测哪种视图或融合动作更合适；
- 这种预测是否能迁移到留出的问题配置；
- 状态信号是否提供了超出 `FE/maxFE` 时间进度的增量信息；
- 决策器在不确定时回退，是否能降低负迁移风险；
- 决策器是否能在自己的独立搜索轨迹上改善最终 IGD+/HV。

### 1.3 两个必须保留的既有警告

1. 既往 Stage 2 给出 `SCHEDULE_REDUNDANT`。它是“仅按进度切换可能没有额外价值”的警告，但不是本实验 fixed-vs-state-aware 的直接因果检验。
2. 既往 Stage 3 在 `DTLZ7_M10` 给出 `INSUFFICIENT_REFERENCE_STABILITY`。它不阻止使用稳定 EvalID 的 `population_final` 开展 D1/D2，但在 D3/D4 中若要主张最终 IGD+ 或外部标签效用，必须先解决。

## 2. 源码时序与决策边界

### 2.1 决策发生的位置

冻结流程中，每代先执行：

1. 从当前 Population 计算 `ScoreV`、`LabelDyn`、`AnchorMargin` 等视图；
2. 形成训练 `Catalog`；
3. 根据 Catalog 构造关系对；
4. 训练关系模型并计算本代 `p_err`；
5. 训练/调用指标代理并生成候选；
6. 真实评价候选并更新 Population。

因此，决策层的时间点严格定义为步骤 1 与步骤 2 之间。

### 2.2 对特征可用性的直接影响

- 当前代视图统计可以使用；
- 上一代已经完成的状态可以使用；
- 当前代关系模型的 `p_err` 尚未产生，不能作为本代 Catalog 决策特征；
- 现有随机 relation-pair 划分的 `p_err` 还存在 solution leakage 风险，不进入 Primary 特征；
- `confidence=1-|ScoreV-LabelDyn|` 只是视图一致性，不得称为正确概率；
- 所有 H1/H3/final truth、最终 Population、最终 IGD/HV 都属于未来信息，严禁进入特征构造。

## 3. 研究问题

### RQ-D1：留出泛化

仅使用当前可观测状态，决策策略能否在完全留出的 Problem 上降低相对于事后最佳动作的遗憾？

### RQ-D2：超越时间进度

视图分歧、尺度、方向场与 Anchor 稳定性特征，是否比只使用 `Ratio=FE/maxFE` 的时间决策器提供额外预测价值？

### RQ-D3：可靠回退

当预测优势不足时回退到冻结的当前动态 Hybrid，能否形成有意义的 coverage-risk 权衡，而不是在所有样本上强制选择一个动作？

### RQ-D4：问题族稳健性

决策收益是否同时存在于 DTLZ 与 WFG，而不是只由 DTLZ 的正向结果驱动？WFG7 的已有失配是否至少不再恶化？

### RQ-D5：闭环价值（后续阶段）

离线通过的冻结决策器，在独立驱动自己的搜索轨迹后，是否仍能改善最终算法表现？

RQ-D5 不属于 D1/D2 的可证明范围。

## 4. 预设假设

### Primary 假设

- `H1`：DLD 决策器在 outer-held-out 预测上的平均 regret 低于原始动态 Hybrid。
- `H2`：DLD 决策器的平均 regret 低于每个训练折内选择的最佳静态动作。
- `H3`：DLD 决策器优于只使用 Ratio 的同容量时间决策器。

H1 与 H2 构成 Primary intersection-union gate：两者必须同时成立，不能只胜过其中一个。

### 风险控制假设

- `H4`：五个留出问题中至少四个问题的平均效应不为负；
- `H5`：WFG7 留出折相对原始 Hybrid 不出现超过预设非劣界值的下降；
- `H6`：非回退覆盖率足够大，策略不是通过几乎总回退制造表面安全性。

### Secondary 假设

- 去掉视图分歧特征后性能下降；
- 去掉方向/Anchor 稳定性特征后性能下降；
- 在高预测优势子集上，实际收益高于低预测优势子集；
- 决策器的收益不仅存在于 `population_final`，在 `front_final` 上方向一致。

## 5. 实验分期与授权边界

| 阶段 | 名称 | 是否需要新搜索 | 本轮是否建议授权 | 能回答什么 |
|---|---|---:|---:|---|
| D0 | 协议规划与冻结 | 否 | 已完成规划 | 固定问题、动作、特征、划分和 gate |
| D1 | 数据集构建与完整性 | 否 | 建议 | 数据是否无泄漏、可复现、动作计算正确 |
| D2 | 离线留出决策可行性 | 否 | 建议 | 当前信号是否能在留出问题上降低 regret |
| D3 | 闭环筛选 | 是，预计 200 jobs | 暂不授权 | 决策器进入算法后是否有初步因果性能价值 |
| D4 | 正式闭环实验 | 是，最高约 1250 jobs | 暂不授权 | 正式最终性能与稳健性结论 |

D1/D2 失败时直接停止，不进入 D3。不得因为 D2 结果不理想而临时更换 truth、外层划分或 Primary baseline。

## 6. 目录与文件治理

### 6.1 实验根目录

```text
D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\
REMO_new2_AdaMaO_GoodGroupPrecision\DualPBI_DecisionLayer
```

该目录是唯一允许存放决策层代码、协议、模型和结果的目录。不得把新脚本散放到 PlatEMO 根目录、原算法目录或 `DualPBI_Complementarity` 中。

### 6.2 批准后目录契约

```text
DualPBI_DecisionLayer/
├─ README.md                         # 状态、入口和范围
├─ docs/
│  ├─ DLD_EXPERIMENT_PLAN_CN.md      # 本文档
│  ├─ DLD_PROTOCOL_LOCK.md           # 批准后冻结的最终协议
│  └─ DLD_DECISION_LOG.md            # 所有协议变更及理由
├─ config/
│  ├─ DLDProtocol.m                  # 唯一配置源
│  ├─ DLDFeatureContract.m           # 在线特征白名单/禁用字段
│  └─ DLDActionContract.m            # 动作、quota、tie-break
├─ builders/
│  ├─ build_DLDFeatureTable.m        # 不接触未来 truth
│  ├─ build_DLDActionUtilityTable.m  # 单独构造未来效用
│  ├─ build_DLDFoldManifest.m        # 在模型拟合前冻结外层折
│  └─ DLDSourceManifest.m            # 只读源文件清单与校验
├─ policy/
│  ├─ fit_DLDCrossFittedPolicy.m
│  ├─ predict_DLDPolicy.m
│  └─ DLDPolicyFeatures.m
├─ algorithms/                       # 仅 D3/D4 才创建
├─ analysis/
│  ├─ analyze_DLDFeasibility.m
│  ├─ DLDPrimaryTests.m
│  └─ DLDHolmAdjust.m
├─ tests/
│  ├─ DLDDataContractTest.m
│  ├─ DLDFoldIsolationTest.m
│  ├─ DLDActionEquivalenceTest.m
│  └─ DLDLeakageGuardTest.m
└─ results/
   ├─ feasibility/
   │  ├─ manifests/
   │  ├─ tables/
   │  ├─ models/
   │  └─ logs/
   ├─ screening/
   │  ├─ raw/
   │  ├─ analysis/
   │  ├─ manifests/
   │  └─ logs/
   └─ formal/
      ├─ raw/
      ├─ analysis/
      ├─ manifests/
      └─ logs/
```

### 6.3 文件治理规则

- 所有新 MATLAB 符号使用 `DLD` 前缀；
- 可执行入口统一为 `run_DualPBIDecisionLayer(profile, ...)`；
- 分析入口统一为 `analyze_DualPBIDecisionLayer(profile)`；
- `profile` 只允许 `feasibility`、`screening`、`formal`；
- 原始轨迹按 `Problem/M/run_NNN.mat` 保存；
- 已存在且通过校验的结果只跳过，不覆盖；
- 损坏或协议不一致的文件必须阻止覆盖并报告；
- 表格是 Primary 证据，PNG 只能由表格派生，不能成为结论来源；
- 模型必须保存训练折、特征合同、超参数、随机种子和 SHA-256；
- 正式结果不得与 feasibility/screening 混用。

## 7. 只读数据源与样本单位

### 7.1 D1/D2 数据源

```text
../DualPBI_Complementarity/results/raw/formal/<Problem>/M<M>/run_NNN.mat
```

预期覆盖：

- Problems：DTLZ2、DTLZ4、DTLZ7、WFG3、WFG7；
- M：10、20；
- Runs：每配置 25；
- 总独立轨迹：250；
- N：100；
- maxFE：500；
- 稳定身份：EvalID；
- 现有 replay equivalence：250/250 通过。

不复制这些 MAT 文件。`DLD_SourceManifest.csv` 只记录绝对路径、文件大小、修改时间、协议字段及可选 SHA-256。

### 7.2 样本层级

- 建模行：snapshot；
- 时间聚合：snapshot 嵌套在 stage；
- 推断单位：run；
- 外部迁移单位：Problem；
- 配置单位：Problem-M。

虽然 snapshot 行数远大于 250，但不能把它们当作独立重复。每个 run 的建模总权重相同，最终统计先在 run 内按 stage 等权聚合，再以 250 个 run 进行配对分析。

## 8. 防泄漏数据分离

### 8.1 两张表必须分开生成

`DLD_SnapshotFeatures.csv`：

- 只包含当下可观测特征；
- 构建函数不得调用 future-outcome 重建函数；
- 不包含任何 H1/H3/final、最终 Population 或最终性能字段。

`DLD_ActionUtilities.csv`：

- 只包含各动作在预设 future truth 下的效用；
- 通过稳定键与特征表连接；
- 构建时不得修改特征表。

稳定连接键：

```text
Problem, M, Run, Seed, SnapshotID, Generation, FE, Ratio
```

折划分在两表连接和模型训练前写入 `DLD_FoldManifest.csv`，之后不得根据结果修改。

### 8.2 禁止作为预测变量的字段

- `Problem` 名称；
- Run、Seed、SnapshotID、EvalID；
- H1/H3/final truth；
- 最终 Population、最终 Archive；
- 最终 IGD、IGD+、HV；
- 任何从 future truth 计算的 Precision、TP、regret、oracle action；
- 当前 Catalog 决策之后才产生的本代 `p_err`；
- 使用全部数据拟合的标准化参数；
- outer-test 折上的特征选择、阈值选择或动作删减结果。

这些字段可以作为键、分组变量或效用标签，但不得进入 predictor matrix。

## 9. 在线特征合同

### 9.1 Primary 特征块 F-state

| 特征组 | 具体字段/派生量 | 决策时是否可得 | 作用 |
|---|---|---:|---|
| 预算状态 | Ratio、Alpha | 是 | 与时间基线公平比较 |
| 已知维度 | M、D、N、q/N | 是 | 允许算法感知问题规模；不含 Problem 名称 |
| 分数尺度 | ScoreVStd、LabelDynStd、EffectiveScaleRatio | 是 | 诊断连续/二值尺度失衡 |
| Anchor 状态 | AnchorPositiveRate、Delta、AnchorMargin IQR | 是 | Anchor 标签密度与边界清晰度 |
| 排序分歧 | Spearman(V,A)、Top-q Jaccard、平均 percentile-rank gap | 是 | 判断两视图是否一致/互补 |
| 边界稳定 | V/A 各自第 q 与 q+1 名分数差、并列数量 | 是 | 判断 Top-q 是否脆弱 |
| 方向场 | DirectionSource、fallback flag、Front1Count/N | 是 | 识别 K-means/Uniform fallback 状态 |
| 方向覆盖 | ClusterCount/Nref、UniqueDirectionCount/Nref | 是 | 判断方向退化或重复 |
| 参考解几何 | Ref 数量、Ref 目标空间最小/中位 pairwise distance | 是 | 判断 Anchor 几何覆盖 |

Primary 不使用原始高维目标向量或决策变量，只使用低维汇总统计，避免模型记忆具体 PF 或维数相关的坐标模式。

### 9.2 Secondary 时序特征块 F-history

仅使用同一 run 的上一 snapshot：

- AnchorPositiveRate 变化；
- EffectiveScaleRatio 对数变化；
- V/A Jaccard 变化；
- 共同 EvalID 上 V/A 排名稳定性；
- RefEvalID Jaccard；
- DirectionSource 是否刚发生切换；
- 上一代已评价候选进入当前 Population 的比例。

首个 snapshot 的时序量记为缺失，并附带 missing indicator。不得用未来 snapshot 回填。

### 9.3 暂不进入 Primary 的特征

- 旧 `p_err`：既有随机 relation-pair 划分可能泄漏，且本代值在决策后产生；
- `mean(confidence)`：仅是视图一致性，可作为由 ScoreV/LabelDyn 推导的 Secondary 特征，不能命名为置信概率；
- 问题名称或手工 problem-family 标签：会把“状态判断”退化成问题查表；
- 重新运行 K-means/bootstrap 得到的额外稳定性：会增加成本并改变随机数流，除非后续单独冻结为新机制。

## 10. 动作集合

设 `q=ceil(0.25*N)=25`。所有 Primary 动作必须输出相同 q 个正组，避免 Catalog 大小、关系对数量和标签来源同时变化。

### A0：H-dyn（回退动作）

直接使用现有 `CatalogCurrent`：

```text
ScoreHybrid = (1-Ratio)*ScoreV + Ratio*double(LabelDyn)
```

这是冻结性能锚点，也是决策器不确定时的回退动作。

### A1：V25（选择方向视图）

按 `ScoreV` 降序选择 q 个解。

### A2：A25（选择 Anchor-derived 连续视图）

按 `AnchorMargin=1-AnchorNormalizedG` 降序选择 q 个解。

A25 是等配额机制动作，不等同于生产 Hybrid 中的二值 `LabelDyn`。论文与报告必须保留这一差异。

### A3：M50（尺度无关固定混合）

先在当前 Population 内把 ScoreV 和 AnchorMargin 转为 `[0,1]` percentile rank utility：

```text
uV = 1 - (rankV-1)/(N-1)
uA = 1 - (rankA-1)/(N-1)
uM = 0.5*uV + 0.5*uA
```

按 `uM` 选择 q 个解。M50 是固定控制，不是拟主张的新方法。

### Secondary 动作

- `LabelNative`：直接使用自然二值 LabelDyn，正例率约 0.30-0.70；只做机制诊断，不与 q=25 的 Primary 动作直接比较 Precision；
- `M25/M75`：rank mix 权重 0.25/0.75，仅作为敏感性分析，不允许根据 outer-test 结果选择；
- `Oracle`：每个 snapshot 事后选择效用最高动作，只作为不可部署上界。

### Tie-break

所有 Top-q 排序统一采用：

1. 主分数降序；
2. 稳定 EvalID 升序。

不得使用当前行号或 MATLAB 非稳定并列顺序决定动作。

## 11. Truth、效用和 regret

### 11.1 Primary truth

`population_final`：当前 Population 中的解是否仍在同一 Hybrid 轨迹的最终 Population。

选择理由：

- 稳定 EvalID 可精确重建；
- 相比 H1/H3 和 front 指标，天花板效应较弱；
- 与现有互补性 Primary 保持一致；
- 不依赖 DTLZ7 外部参考 PF，因此 D1/D2 不被参考集稳定性阻塞。

限制：它仍是 Hybrid-driven on-policy truth，D2 只能验证决策可行性，不能证明闭环因果收益。

### 11.2 动作效用

对动作 `a`：

```text
U_a = Precision@q(a, population_final)
```

### 11.3 Oracle regret

```text
U_oracle = max(U_Hdyn, U_V25, U_A25, U_M50)
Regret(policy) = U_oracle - U_policy
GainVsFallback = U_policy - U_Hdyn
```

### 11.4 实用等价区间

单个 snapshot 的 q=25，因此一个候选对应 0.04 Precision。建议将：

```text
epsilon_tie = 1/q = 0.04
```

作为动作效用的实用等价范围。差异小于 0.04 时不强制制造唯一“正确类别”。因此 Primary 模型预测动作相对效用，而不是把近似平局强制编码为硬分类标签。

### 11.5 Secondary truths

- `front_final`；
- `population_h1`、`population_h3`；
- `front_h1`、`front_h3`。

这些结果只作一致性/天花板敏感性分析，不替换 Primary。

## 12. 外层留出与内层调参

### 12.1 Primary：leave-one-problem-out（LOPO）

共 5 个 outer folds：

| Fold | 完全留出的测试问题 | 测试配置 | 测试 runs |
|---|---|---:|---:|
| F1 | DTLZ2 | M10、M20 | 50 |
| F2 | DTLZ4 | M10、M20 | 50 |
| F3 | DTLZ7 | M10、M20 | 50 |
| F4 | WFG3 | M10、M20 | 50 |
| F5 | WFG7 | M10、M20 | 50 |

一个测试问题的所有 M、run、stage、snapshot 必须完全离开训练集。这是“留出配置泛化”的 Primary 证据。

### 12.2 Secondary：leave-one-configuration-out（LOCO）

10 个 Problem-M outer folds，用于区分“跨问题”与“同问题跨 M”难度。LOCO 不能替换 LOPO Primary。

### 12.3 内层划分

在每个 outer training set 内，再按剩余 Problem 分组交叉验证，仅用于：

- 浅树复杂度；
- 最小叶节点大小；
- 回退阈值；
- 若启用敏感性动作，固定 mix 权重。

outer test 只运行一次，不参与任何选择。

### 12.4 标准化与缺失处理

- 任何中心化、缩放、截尾参数只从 outer training fold 估计；
- outer test 使用训练折参数；
- 类别字段使用训练期已知类别和明确的 unknown/fallback 编码；
- 缺失值不使用测试折均值回填；
- 同一 run 的全部 snapshots 分配相同样本权重总和，防止迭代次数多的 run 主导训练。

## 13. 决策模型与对照

### 13.1 推荐 Primary 模型：相对效用浅树

分别预测：

```text
Delta_V = U_V25 - U_Hdyn
Delta_A = U_A25 - U_Hdyn
Delta_M = U_M50 - U_Hdyn
```

每个 Delta 使用浅层回归树。内层候选复杂度预设为：

- `MaxNumSplits ∈ {1,3,7}`；
- `MinLeafSize ∈ {50,100,200}` snapshot rows；
- 不使用自动贝叶斯优化；
- 不事后扩展模型族。

选择预测 Delta 最大的动作。如果最大预测 Delta 未超过回退阈值 `tau`，输出 H-dyn。

建议内层候选：

```text
tau ∈ {0, 0.02, 0.04}
```

并要求内层非回退 coverage 至少为 0.20。最终每个 outer fold 的模型和 tau 单独冻结。

### 13.2 为什么不以复杂模型作为 Primary

- 有效独立轨迹只有 250；
- 复杂模型容易利用 problem-specific 代理模式；
- 研究故事需要可解释的“何时选择/回退”规则；
- 若浅树没有留出信号，直接增加深度或换成黑箱模型不能构成可信机制证据。

正则线性回归可作为稳定性敏感性分析；随机森林、Boosting、神经网络不进入首轮 Primary。

### 13.3 必须比较的 baselines

| Baseline | 定义 | 回答的问题 |
|---|---|---|
| B0 H-dyn | 总是使用原始动态 Hybrid | 是否优于当前算法 |
| B1 BestStatic-train | 仅在 outer training 中从 V25/A25/M50 选择平均效用最高者 | 是否优于简单固定动作 |
| B2 RatioOnly | 与 DLD 同容量浅树，但 predictor 只有 Ratio/Alpha | 状态特征是否超越时间进度 |
| B3 Oracle | 每 snapshot 事后最佳动作 | 理论可利用空间，不可部署 |
| B4 RandomAction | 按训练折动作频率随机选择 | 负向基线 |

## 14. Primary 统计分析

### 14.1 交叉拟合预测

五个 LOPO outer models 分别对完全未见的问题生成预测。拼接五折预测形成 250 个 run 的全量 out-of-fold 结果；任何一行都不能由看过其 Problem 的模型预测。

### 14.2 run 级聚合

对每个 run：

1. 在每个 stage 内平均 snapshot utility/regret；
2. 对 S1-S4 等权平均；
3. 得到一个 run 级 Primary 值。

这样不会因为某些阶段 snapshot 更多而改变权重。

### 14.3 Primary IUT

分别计算配对差：

```text
D0 = Regret_DLD - Regret_Hdyn
D1 = Regret_DLD - Regret_BestStaticTrain
```

对 `D0<0`、`D1<0` 做单侧配对 Wilcoxon signed-rank，并取两者 p 值最大值作为 Primary IUT p 值。报告：

- run 级均值差与中位数差；
- paired win probability；
- matched-pairs rank-biserial；
- 按 run 配对 bootstrap 95% CI；
- 五个 outer Problem 的分别效应。

若进一步对多个 feature-policy 版本进行正式比较，必须先在配置中冻结 comparison family，再做 Holm；不能从同一数据挑最好版本后只报告其 p 值。

### 14.4 Ratio-only 增量检验

同样比较 `Regret_DLD - Regret_RatioOnly`。这是 H3 的独立必要 gate，但不与 H1/H2 合并成一个更宽松的“任一通过”规则。

### 14.5 分层报告

必须分别报告：

- DTLZ 与 WFG；
- 5 个 held-out Problem；
- M=10 与 M=20；
- S1-S4；
- fallback 与 non-fallback 子集。

总平均不能掩盖 WFG7 或某一问题族反向。

## 15. Coverage-risk 与回退评估

### 15.1 定义

- Coverage：策略选择 V25/A25/M50 的比例；
- Fallback rate：选择 H-dyn 的比例；
- Selective gain：仅 non-fallback 决策的 `U_policy-U_Hdyn`；
- Harm rate：`U_policy<U_Hdyn-epsilon_tie` 的比例；
- Confidence ordering：按预测最大 Delta 分箱后，真实 gain 是否随箱位上升。

### 15.2 必须防止的假象

若策略在超过 80% 的 snapshot 上都回退，即使总体无损，也不能称为“成功识别何时混合”。因此建议设置：

```text
minimum_nonfallback_coverage = 0.20
```

该值属于建议冻结参数，需用户批准。

## 16. 建议的 D2 科学 gate

### 16.1 `PASS_TO_CLOSED_LOOP_SCREEN`

建议同时满足：

1. 数据完整性 gate 全部 PASS；
2. DLD 相对 H-dyn 的 out-of-fold 平均 utility gain 至少 `+0.01`，且配对 bootstrap 95% CI 下界大于 0；
3. DLD 相对 BestStatic-train 的平均 utility gain至少 `+0.01`，且 95% CI 下界大于 0；
4. DLD 相对 RatioOnly 的平均 utility gain为正，且 95% CI 下界大于 0；
5. 至少 4/5 held-out Problems 的平均 gain 不为负；
6. WFG7 held-out fold 相对 H-dyn 的平均 gain 不低于 `-0.01`；
7. non-fallback coverage 不低于 0.20；
8. 训练折内 utility 按 run 分组置乱的负对照不能复制真实增益。

`0.01` 相当于平均每个 Top-25 Catalog 多保留 0.25 个未来真阳性，是建议的最小平均实用效应；该阈值需在执行前由用户确认。

### 16.2 `REVISE_ONCE`

满足完整性，但出现以下任一情况：

- 优于 H-dyn，但不能优于 BestStatic-train；
- 优于 RatioOnly 的证据不足；
- 效果只存在于 DTLZ；
- coverage 过低；
- 特征阈值在五个 outer folds 间高度不稳定。

只允许一次预先受限的修订：在 `DLD_DECISION_LOG.md` 中记录，且不能改 truth、outer split 或基线。允许的修订仅限删除不稳定特征、提高回退强度或把动作集合简化为 V/A/H-dyn。

### 16.3 `STOP_DECISION_LAYER`

以下任一情况建议停止，不进入 D3：

- 相对 H-dyn 的 out-of-fold gain 不为正；
- BestStatic-train 与 DLD 等价或更好；
- RatioOnly 与完整状态模型等价，说明“状态判断”故事没有增量证据；
- WFG7 继续明显恶化；
- 置乱负对照得到相近效果；
- 结果依赖使用 Problem 名称、future truth 或外层测试调参；
- 模型规则在不同 held-out Problems 间完全相反且无法形成可解释共同条件。

停止不否定已有“双视图互补”结论，只表示当前观测量不足以支持可迁移的决策层。

## 17. D1 完整性与自动测试

### 17.1 数据源 gate

- 250/250 source MAT 可读；
- 10/10 配置完整；
- 每配置 25/25 run；
- Problem、M、D、N、maxFE、seed 与冻结协议一致；
- replay equivalence 证据仍为 PASS；
- 所有 stable keys 唯一；
- Feature 与 Utility 表连接为一对一；
- 所有 `population_final` 可用行数与源文件契约一致。

### 17.2 动作 gate

- H-dyn 与保存的 `CatalogCurrent` 精确一致；
- V25/A25/M50 每个 snapshot 恰有 q 个 true；
- Top-q tie-break 对相同行输入可重复；
- 改变 MATLAB 行顺序后，以 EvalID 对齐得到相同 Catalog；
- 所有动作效用可从 truth 与 Catalog 独立复算。

### 17.3 折隔离 gate

- LOPO 测试 Problem 不出现在对应训练折；
- 同一 run 的任何 snapshot 不跨 train/test；
- inner tuning 不接触 outer test；
- 所有 250 个 run 恰好获得一次 out-of-fold 预测；
- Problem 字段不在 predictor names 中。

### 17.4 泄漏 gate

`DLDFeatureContract` 必须拒绝包含以下模式的 predictor：

```text
truth, future, final, h1, h3, igd, hv, precision, tp, regret,
oracle, run, seed, snapshotid, evalid, problem
```

字段名拒绝只是第一层检查；另需验证 feature builder 在 future outcome 文件暂时不可见时仍可完整运行。

### 17.5 决定性 gate

固定模型随机种子后，重复执行 D1/D2 两次应得到：

- FoldManifest 完全一致；
- Feature/Utility 表在排序后数值一致；
- CrossFittedPredictions 完全一致；
- PrimaryTests 完全一致。

## 18. D1/D2 预期输出

| 文件 | 目录 | 内容 |
|---|---|---|
| `DLD_SourceManifest.csv` | feasibility/manifests | 250 个只读源文件契约 |
| `DLD_FoldManifest.csv` | feasibility/manifests | LOPO/LOCO/inner fold 冻结划分 |
| `DLD_FeatureContract.csv` | feasibility/manifests | predictor 白名单、时序和可用性 |
| `DLD_SnapshotFeatures.csv` | feasibility/tables | 仅在线特征 |
| `DLD_ActionUtilities.csv` | feasibility/tables | 各动作未来效用 |
| `DLD_CrossFittedPredictions.csv` | feasibility/tables | 每 snapshot 的 held-out 动作和预测 Delta |
| `DLD_RunSummary.csv` | feasibility/tables | run 级等 stage 权聚合 |
| `DLD_PrimaryTests.csv` | feasibility/tables | Primary IUT、效应量和 CI |
| `DLD_ProblemBreakdown.csv` | feasibility/tables | 5 个 held-out Problem 结果 |
| `DLD_CoverageRisk.csv` | feasibility/tables | fallback coverage-risk |
| `DLD_FeatureAblations.csv` | feasibility/tables | Ratio-only、去分歧、去稳定性 |
| `DLD_NegativeControls.csv` | feasibility/tables | run-grouped permutation 结果 |
| `DLD_FinalGate.csv` | feasibility/tables | PASS/REVISE/STOP 与理由 |
| `DLD_Feasibility_Report_CN.md` | feasibility | 仅依据 CSV 的详细结论 |

模型输出必须按 outer fold 单独保存，不允许只保存一个在全数据重新训练的模型后冒充 held-out 结果。

## 19. D3：可选闭环筛选计划

D3 只有在 D2=`PASS_TO_CLOSED_LOOP_SCREEN` 且用户再次批准后才创建算法代码和运行结果。

### 19.1 冻结算法臂

| Arm | Catalog 决策 |
|---|---|
| H0 | 当前 H-dyn |
| V | V25 |
| A | A25 |
| M | M50 |
| DLD | D2 冻结的状态决策器，含 H-dyn fallback |

其他 DataProcess、关系网络、旧 p_err、lambda0/lambda_t、SDE 代理、UniformMix 候选路由、qKeep、nMin/nMax 和真实评价预算保持相同。

### 19.2 推荐筛选配置

| 配置 | 选择理由 |
|---|---|
| DTLZ2-M20 | 方向视图相对稳定的对照 |
| DTLZ4-M10 | Anchor-derived 视图较强的对照 |
| WFG3-M20 | 已存在局部严格融合成功的对照 |
| WFG7-M20 | 最明确的失配压力测试 |

每臂每配置 10 个相同种子，共：

```text
5 arms × 4 configurations × 10 runs = 200 jobs
```

所有任务使用 `maxFE=500`。不得用 300 FE 作为 500 FE 的截断替代，因为 Ratio 直接参与基线与决策逻辑。

### 19.3 D3 证据边界

- 每个 arm 必须驱动自己的后续搜索；
- 离线 D2 模型及 SHA-256 在 D3 前冻结；
- 不允许根据 D3 结果重新训练模型再报告同一 D3；
- D3 是筛选，不作为论文正式显著性结论；
- 最终 IGD+ 的正式主张仍受 DTLZ7/reference stability gate 约束；
- 必须同时记录候选真实评价、进入 Population/Archive、下一阶段贡献和运行时间。

### 19.4 D3 进入正式实验的门槛

建议同时满足：

- DLD 在 4 个配置总体上优于 H0 和最佳静态 arm；
- WFG7-M20 不再出现当前量级的明显失配；
- 至少 3/4 配置效应方向不为负；
- 运行时间增量可解释且不改变 FE；
- 动作频率不是几乎恒定选择同一 arm；
- 候选成功率方向与最终指标方向基本一致。

## 20. D4：正式闭环实验预算边界

若保持 5 arms、10 配置、25 seeds，完整矩阵最高为：

```text
5 × 10 × 25 = 1250 independent jobs
```

因此 D4 绝不能在 D2/D3 之前启动。D2 可以决定删除无意义的静态 arm，D3 可以决定是否值得承担正式成本。

正式阶段建议另设完全不用于 D2 开发的外部问题；候选为 DTLZ1 和 WFG6，但必须在批准 D4 时重新检查问题设置、参考集稳定性与实验成本，不能现在把它们当成既定正式结论来源。

## 21. 主要风险与缓解

| 风险 | 严重度 | 缓解措施 |
|---|---|---|
| Hybrid-driven on-policy truth 偏向 H-dyn | P0 | D2 只称可行性；D3 用独立轨迹验证 |
| snapshot 伪重复 | P0 | run 等权、run 级统计、Problem 级 outer holdout |
| outer test 被调参污染 | P0 | 先写 FoldManifest；嵌套 CV；完整日志 |
| 当前代 p_err 时间穿越 | P0 | 从 Primary 特征白名单排除 |
| relation-pair leakage | P0 | 不使用旧 p_err 主张泛化；后续做 solution-disjoint |
| A25 与生产 LabelDyn 不同构 | P1 | 明确分轨；LabelNative 只做 Secondary |
| 仅 5 个 Problem，外推范围有限 | P1 | LOPO、逐问题报告；D4 增加外部问题 |
| DTLZ/WFG 总体均值反转 | P1 | 问题族和 WFG7 harm gate |
| 特征/模型选择自由度过大 | P1 | 单一 Primary 模型族、有限网格、一次受限修订 |
| fallback 造成“几乎不决策” | P1 | minimum coverage gate |
| reference stability 未解决 | P0（D3/D4 性能主张） | D1/D2 使用 population_final；正式性能前先解 gate |
| 复杂策略难解释 | P2 | 深度受限浅树、保存规则和阈值 |
| 特征计算改变随机流 | P1 | D1 离线；D3 只用确定性汇总，不额外调用随机算法 |

## 22. 不允许的事后改动

D1 开始后，未经新版本协议和用户批准，不得：

- 把 Primary truth 从 population_final 换成效果更好的 truth；
- 把 LOPO 换成随机 snapshot split；
- 使用 Problem 名称作为特征；
- 根据 WFG7 test 结果重新设计规则后继续把它称为 held-out；
- 从大量模型中挑最好一个而不报告选择过程；
- 删除负向 Problem 或 run；
- 把 D2 离线提升写成最终 IGD/HV 因果提升；
- 把 A25 写成生产 Hybrid 原本使用的二值 LabelDyn；
- 把 confidence 或预测 margin 写成校准正确概率。

## 23. 用户审批项

执行前需要用户逐项确认。推荐选项已经填在右列：

| 审批项 | 推荐方案 |
|---|---|
| 本轮授权范围 | 仅 D1+D2，不运行 D3/D4 |
| 数据源 | 只读复用现有 250 个 complementarity formal MAT |
| Primary truth | population_final |
| Primary outer split | 5-fold leave-one-problem-out |
| Primary actions | H-dyn、V25、A25、M50 |
| 回退动作 | H-dyn |
| Primary model | 预测相对效用的深度受限浅树 |
| Primary baselines | H-dyn、BestStatic-train、RatioOnly |
| tie/equivalence | 0.04，即 1/q |
| 最小平均实用增益 | 0.01 |
| 最小 non-fallback coverage | 0.20 |
| WFG7 非劣界 | -0.01 相对 H-dyn |
| D2 后动作 | PASS 才另行申请 D3；REVISE 最多一次；STOP 不扩展 |

建议用户确认时使用：

```text
同意按 DLD v1 推荐方案执行 D1+D2；D3/D4 暂不授权。
```

若需要修改，应在执行前明确指出要改的审批项。批准后先生成 `DLD_PROTOCOL_LOCK.md`，再开始任何代码实现。

## 24. 当前状态

- 规划目录：已建立；
- 详细规划：已建立；
- 协议锁：未建立，等待用户批准；
- 数据构建器：未实现；
- 模型代码：未实现；
- 算法变体：未实现；
- 实验运行：0；
- 结果文件：0；
- 下一强制 gate：用户审阅并批准或修改第 23 节。
