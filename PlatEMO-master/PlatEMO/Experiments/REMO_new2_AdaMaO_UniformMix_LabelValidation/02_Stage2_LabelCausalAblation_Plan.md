# Stage 2：标签构造因果消融实施规划

> **For agentic workers:** REQUIRED SUB-SKILL: use a plan-execution workflow and complete the checkbox steps in order. This stage is offline and must never alter or rerun an optimization trajectory while comparing label variants.

**Goal:** 在 Stage 1 保存的完全相同种群快照上，分离“原始锚点二值边界、连续锚点裕量、非支配方向、固定正组比例、动态融合、方向来源和方向数量”各因素，确认当前标签机制是否产生了非平凡且可重复的分组差异。

**Architecture:** 所有标签版本都读取同一个 immutable snapshot，使用确定性排序和独立的离线随机种子生成结果。主要比较固定正组比例为25%的版本；原始二值标签保留其30%–70%的自然正例比例，只作为历史基线。该阶段只分析标签结构、重合、分歧和扰动稳定性，不使用真实 PF 效用，因此不能宣称哪个标签更正确。

**Tech Stack:** MATLAB、PlatEMO、Stage 1 的 valid MAT 文件、Statistics and Machine Learning Toolbox。

---

## 1. 实验目的和必须排除的混杂

当前算法相对原始代表解标签同时改变了多件事：

1. 少量实际代表解变为最多100个非支配分布派生方向；
2. 二值输出变为连续 PBI 得分；
3. 原始30%–70%正例比例变为固定25%；
4. 两种数值语义不同的信号被线性融合；
5. 融合权重随 `FE/maxFE` 改变。

如果只比较原始 REMO 与当前算法，以上因素无法归因。本阶段把它们放到同一快照上逐项拆开，并加入打乱和均匀方向负对照。

本阶段不训练关系网络，也不运行 `Problem.Evaluation`。任何新增 FE 都是实现错误。

## 2. 输入资格和统一设置

输入目录由 runner 的 `<profile>` 决定，并且必须读取 Stage 1 的同名 profile：

```text
results/stage1/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
```

`smoke` 只能读取 Stage 1 smoke，`pilot` 只能读取 Stage 1 pilot，`screening` 只能读取 Stage 1 screening；不得为了补文件跨 profile 混用。smoke/pilot 只验证实现和耗时，不进入研究结论。正式 screening 只接受 Stage 1 validator 判定为 valid，且 `Stage1_decision.csv` 为以下之一的数据：

```text
PASS_TO_STAGE2
PASS_WITH_LOW_ADAPTIVE_COVERAGE
```

必须同时包含 `Hybrid` 和 `AnchorNative` 两种行为轨迹；任一 `Problem/M/run` 缺少一个行为时，该 `pairedKey` 在跨行为分析中整体排除，但仍可进入行为内描述性分析。不得用另一 run 补配。

统一正式设置必须与 Stage 1 一致：

```text
Problems: DTLZ2, DTLZ4, DTLZ7, WFG3, WFG7
M: 10, 20
Requested D: 30
actualD: WFG3=31，其余=30
N: 100
maxFE: 500
Runs: 1:5
Base seed: problemIndex*10000 + M*100 + run
rGood: 0.25
theta: 5
Nref: 100
kEff: M10=15, M20=30
```

## 3. 确定性排序和离线随机数规则

所有离线 TopQ 均按以下规则确定，避免不同 MATLAB 版本对并列值给出不同结果，同时复现生产代码按当前 Population 行顺序排序的语义：

1. 第一关键字：得分降序；
2. 第二关键字：当前 snapshot 中的 `PopulationRow=1:N` 升序；
3. 取前 `ceil(N*0.25)=25` 个。

应实现唯一公共函数：

```matlab
[catalog,order] = LVTopQDeterministic(score,0.25);
```

`PopulationEvalID` 只用于跨阶段追踪解身份，不能作为生产标签原本不存在的新并列规则。`LVTopQDeterministic` 应通过 `sortrows([-score(:),(1:N)'])` 明确实现行序并列规则。

随机负对照和扰动重算使用离线种子，且在调用后恢复全局 RNG：

```matlab
snapshotSeed = baseSeed*1000 + SnapshotID;
offlineSeed  = snapshotSeed + variantCode*100 + replicate;
```

其中 `variantCode` 固定使用第4节表中的整数。离线随机数绝不能反馈到 Stage 1 轨迹。

## 4. 冻结标签版本

### 4.1 必做版本

| Code | Variant | 正例数 | 得分/标签定义 | 唯一目的 |
|---:|---|---:|---|---|
| 0 | `L0_ANCHOR_BINARY_NATIVE` | 自然比例 | `Catalog=LabelDyn` | 原始代表解二值标签历史基线 |
| 1 | `L1_ANCHOR_MARGIN_Q25` | 25 | `score=1-AnchorNormalizedG` | 控制同一锚点下的连续排序和固定25% |
| 2 | `L2_ND_SCORE_Q25` | 25 | `score=ScoreV` | 检验非支配方向单分支 |
| 3 | `L3_HYBRID_CURRENT_Q25` | 25 | `(1-ratio)*ScoreV + ratio*LabelDyn` | 当前完整标签构造 |
| 4 | `L4_HYBRID_FIXED_Q25` | 25 | `0.5*ScoreV+0.5*LabelDyn` | 检验动态调度是否必要 |
| 5 | `L5_HYBRID_REVERSE_Q25` | 25 | `ratio*ScoreV+(1-ratio)*LabelDyn` | 检验反向调度是否同样合理 |
| 6 | `L6_HYBRID_SHUFFLED_Q25` | 25 | 当前权重，但在种群内打乱 `ScoreV` | 排除任意打破并列或比例变化造成的假提升 |
| 7 | `L7_UNIFORM_SCORE_Q25` | 25 | 均匀方向、其余 PBI 公式相同 | 检验非支配派生方向是否优于均匀方向 |
| 8 | `L8_ND_SCORE_KEFF_Q25` | 25 | 非支配方向数改为 `kEff` | 检验100方向的分辨率效应 |

### 4.2 各版本的精确定义

`L0` 必须直接读取或逐值复现 Stage 1 的 `LabelDyn`，不得把它再次截断成25%。因此 L0 与其他版本的原始标签比例不同，L0 对比只用于描述历史机制，不用于单因素证明。

`L1` 使用 Stage 1 保存的最终自适应 `delta` 和按代表解距离归一化后的 `AnchorNormalizedG`：

```matlab
AnchorMargin = 1 - AnchorNormalizedG;
```

值越大代表位于原始锚点边界内侧的裕量越大。若出现非有限值，整个 snapshot 判为 invalid，不能用0或均值填充。

`L2` 使用 Stage 1 那次真实标签计算产生的 `ScoreV`，不得重新运行 K-means。这样 L2、L3、L4、L5 的差异只来自融合方式。

`L3` 必须与 Stage 1 的 `CatalogCurrent` 逐元素相等。任何不等都说明排序、并列处理或字段复现错误，必须停止分析。

`L6` 对每个 snapshot 运行100次独立 permutation。每次只打乱解与 `ScoreV` 的对应关系，保持 `ScoreV` 数值分布、`LabelDyn`、ratio 和正例数不变。分析使用100次的均值和2.5%/97.5%分位数，不能只选一次有利的打乱。

`L7` 使用：

```matlab
V = UniformPoint(100,M,'ILD');
V = V./vecnorm(V,2,2);
```

随后完全复制当前 `score_v` 的关联、`d1`、`d2` 和 `1/(1+PBI)` 公式。必须记录 `size(V,1)` 的实际值，不得假定 UniformPoint 永远恰好返回100行。

`L8` 只改变方向分辨率：

- 如果 Stage 1 当前 snapshot 使用 `ND_KMEANS`，沿用同一非支配点集和归一化方式，令 `nClusters=min(kEff,nPareto)`；
- 如果 Stage 1 当前 snapshot 使用均匀回退，L8 也使用 `kEff` 个均匀方向；
- 回退资格沿用 Stage 1 已记录结果，不因为 `Nref` 变小而改变“是否允许使用非支配方向”。

L8 的 K-means 使用第3节 `offlineSeed`、`MaxIter=100`、`Replicates=5` 和 `EmptyAction='singleton'`；调用前后恢复全局 RNG。不得让离线 K-means 改变其他 snapshot 或 permutation 的随机序列。

这样 L2 与 L8 的差异主要反映方向数量，而不是同时改变回退门槛。

## 5. 计划创建的文件及职责

```text
LVTopQDeterministic.m
ComputeLabelAblationVariants.m
ComputeUniformDirectionScore.m
ComputeReducedNDDirectionScore.m
ComputeLabelOverlapMetrics.m
ComputeLabelPerturbationStability.m
run_LabelCausalAblation.m
ValidateLabelCausalAblationFile.m
analyze_LabelCausalAblation.m
tests/test_LabelCausalAblation.m
results/stage2/                       % 运行时生成，不提交 Git
```

- `ComputeLabelAblationVariants(snapshot,metadata)`：返回 L0–L8 的得分、Catalog、排名和 provenance。
- `ComputeUniformDirectionScore`：只实现 L7，不读取未来信息。
- `ComputeReducedNDDirectionScore`：只实现 L8，并接受 Stage 1 的方向来源状态。
- `ComputeLabelOverlapMetrics`：计算固定定义的重合、相关和分歧集合。
- `ComputeLabelPerturbationStability`：执行5%和10%删点稳定性；结果单列为 exploratory。
- runner、validator、analyzer 延续 Stage 1 的跳过有效文件、阻塞无效文件和原子保存约定。

## 6. 每个 snapshot 的输出契约

结果路径：

```text
results/stage2/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
```

每个 MAT 必须保存：

```text
metadata
variantRows
overlapRows
stabilityRows
validation
```

### 6.1 `variantRows` 每行字段

```text
Behavior, Problem, Family, M, Run, Seed, PairedKey,
SnapshotID, Generation, FE, Ratio, StageBin,
VariantCode, VariantName, Replicate,
PositiveCount, PositiveRate,
ScoreMean, ScoreStd, ScoreMin, ScoreMax,
CatalogHash, RankingHash,
DirectionSource, Front1Count, UniqueDirectionCount
```

`StageBin` 固定按总 FE 比例划分：

```text
EARLY:  ratio < 0.40
MIDDLE: 0.40 <= ratio < 0.70
LATE:   ratio >= 0.70
```

正式 D>10、maxFE=500 的第一次训练通常从 ratio=0.20 左右开始；不得把“算法训练开始”错误地当作 ratio=0。

### 6.2 `overlapRows` 每行字段

```text
VariantA, VariantB,
Jaccard, IntersectionCount, UnionCount,
SpearmanScore, CatalogAgreement,
AOnlyCount, BOnlyCount
```

对没有连续得分的 L0，`SpearmanScore=NaN` 是合法的；不得伪造二值标签内部排名。

### 6.3 `stabilityRows` 每行字段

对 L1、L2、L3、L7、L8 做扰动稳定性：

```text
DropFraction       % 0.05 或 0.10
Replicate          % 1..100
RetainedJaccard
RetainedRankSpearman
DirectionSourceAfterDrop
```

比较只在保留下来的解上进行。删点后 TopQ 数为 `ceil(Nretained*0.25)`；Jaccard 前先把两个集合限制到共同保留解。稳定性是次要结果，不能代替外部效用。

## 7. 实施任务清单

### Task 1：验证输入和重现当前标签

- [ ] 扫描 Stage 1 screening manifest，只加载 valid 作业。
- [ ] 验证每个输入 snapshot 的 `PopulationEvalID` 唯一、长度为100且能映射到 `evaluations`。
- [ ] 实现 L0–L5 后，断言 L3 Catalog 与 Stage 1 `CatalogCurrent` 完全一致。
- [ ] 对 L0 断言 Catalog 与 Stage 1 `LabelDyn` 完全一致。
- [ ] 对 L1–L8（除 L6 的每个 permutation）断言正例数恰为25。

### Task 2：实现方向来源和分辨率对照

- [ ] 实现 L7，测试所有得分有限且方向行数被记录。
- [ ] 实现 L8，测试 M10 使用 `kEff=15`、M20 使用 `kEff=30`。
- [ ] 对一个手工二维矩阵做单位测试，验证 PBI 关联、`d1/d2` 和得分方向为“PBI越小，得分越高”。
- [ ] 不得在 L7/L8 中修复坐标原点；几何一致版本属于独立的后续敏感性，不混入本因果矩阵。

### Task 3：实现负对照和扰动稳定性

- [ ] L6 每 snapshot 固定100次 permutation，并验证重复执行得到相同 CatalogHash 序列。
- [ ] 验证每个 permutation 的 `sort(ShuffledScoreV)==sort(ScoreV)`，确保数值分布没有改变。
- [ ] 运行5%和10%删点稳定性各100次，保存每次结果而不只保存均值。
- [ ] 随机调用前后保存并恢复全局 RNG；单元测试验证函数调用不会改变调用者 RNG 状态。

### Task 4：实现严格 validator

- [ ] 检查 Stage 1 provenance：source file、schemaVersion、metadata hash 和 snapshot 数一致。
- [ ] 检查 VariantCode/VariantName 一一对应，L6 每 snapshot 恰有100行，其余版本恰有1行。
- [ ] 检查所有 Catalog 只含0/1、所有排名是 `1:N` 的排列、所有要求的得分有限。
- [ ] 检查 overlap 对称性：`Jaccard(A,B)==Jaccard(B,A)`。
- [ ] 检查结果没有任何 `Problem.Evaluation` 或新增 FE 字段；Stage 2 是纯离线计算。

### Task 5：运行和分析

- [ ] 先在 Stage 1 smoke 上运行单元测试，不把 smoke 纳入结论。
- [ ] 在 pilot 上验证所有版本和100次 permutation 可恢复运行。
- [ ] 对 screening 的全部 valid Stage 1 文件运行 Stage 2。
- [ ] 以 run 为统计聚类单位汇总，不把 snapshot 或解当独立重复。
- [ ] 生成第8节全部 CSV 和唯一一个 Stage 2 决策代码。

## 8. 分析输出

```text
results/stage2/<profile>/analysis/
  Stage2_run_manifest.csv
  Stage2_variant_summary.csv
  Stage2_pairwise_overlap.csv
  Stage2_stagewise_overlap.csv
  Stage2_disagreement_counts.csv
  Stage2_shuffle_envelope.csv
  Stage2_stability_summary.csv
  Stage2_decision.csv
  Stage2_analysis.mat
```

主分析必须至少报告：

1. L3 与 L1、L2、L4、L5 的 Top25 Jaccard；
2. L2 与 L7：非支配方向和均匀方向的分组差异；
3. L2 与 L8：100方向和 `kEff` 方向的分辨率差异；
4. L3 与 L6 permutation envelope：当前解—得分对应是否产生非随机结构；
5. L1/L2/L3 的分歧集合大小；
6. 上述指标按 EARLY/MIDDLE/LATE、问题和目标数分层；
7. 两种行为轨迹分别汇总，之后再做 run 级等权平均。

禁止跨问题直接平均原始 PBI 得分；跨问题只能汇总无量纲的 Jaccard、相关、比例或标准化指标。

## 9. Stage 2 决策规则

该阶段只决定机制是否值得进入外部效用验证，不决定“哪个标签更好”。

| DecisionCode | 预注册条件 | 后续动作 |
|---|---|---|
| `PASS_TO_STAGE3` | L3 与 L1/L2 至少一项存在非平凡分歧，且数据/负对照/复现检查全部有效 | 进入 Stage 3 |
| `STOP_NO_MECHANISM_SEPARATION` | L3 与 L1、L2 均在至少80%的 snapshot 中 Jaccard大于0.95，且分歧集合长期少于3个解 | 停止“融合标签创新”故事 |
| `STOP_REPRODUCTION_FAILURE` | L3 无法逐值复现 Stage 1 当前 Catalog | 修复实现，不得继续 |
| `INSUFFICIENT_DATA` | 任一问题家族少于4个有效 paired run | 补跑 Stage 1/2 |

`DecisionCode` 必须唯一。两个可能同时发生的冗余现象放在独立的 `WarningFlags` 列中，以分号连接，不得互相覆盖：

| WarningFlag | 条件 | 解释 |
|---|---|---|
| `SCHEDULE_REDUNDANT` | L3 与 L4、L5 在至少80%的 snapshot 中 Jaccard 均大于0.95 | Stage 3 仍验证外部效用，但论文暂不把调度列为贡献 |
| `DIRECTION_SOURCE_REDUNDANT` | L2 与 L7 在至少80%的 snapshot 中 Jaccard 大于0.95 | Stage 3 仍验证外部效用，并准备删除“非支配方向优于均匀方向”表述 |

决策优先级固定为：`STOP_REPRODUCTION_FAILURE` → `INSUFFICIENT_DATA` → `STOP_NO_MECHANISM_SEPARATION` → `PASS_TO_STAGE3`。只在主决策为 `PASS_TO_STAGE3` 时写入 WarningFlags。

“80% snapshot”先在每个 run 内计算比例，再对 run 取中位数；不能把所有 snapshot 混在一起让长 run 获得更高权重。

## 10. 预期结果（研究假设，不是通过标准）

如果当前机制确实利用了两种不同压缩方式，合理预期是：

- L1 与 L2 有中等而非完全重合；
- L3 在 EARLY 更接近 L2，在 LATE 更接近 L1/L0；
- L6 打乱后仍保持相同得分分布，但选中的具体解与 L3 显著不同；
- L8 可能比 L2 更粗糙，从而显示100方向带来的分辨率变化；
- WFG3 的 L2/L7 差异可能不同于 DTLZ2，反映退化 PF 对方向构造的影响。

以下结果会改变后续论文设计：

- L3≈L2：融合可能没有增加信息，应考虑方向单支路；
- L3≈L1：连续方向可能基本无作用，应保留锚点机制；
- L3≈L4≈L5：动态权重没有独立作用，应删除阶段调度故事；
- L2≈L7：非支配派生方向没有结构差异，应优先使用更简单的均匀方向解释；
- L2≈L8：方向数量从 `kEff` 增加到100没有产生分辨率变化，不应把“更多方向”作为贡献。

## 11. 执行命令

在包含 `platemo.m` 的目录执行：

```powershell
$env:ADAMAO_PLATEMO_ROOT = (Resolve-Path '.').Path
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); r=runtests(fullfile(pwd,'Experiments','REMO_new2_AdaMaO_UniformMix_LabelValidation','tests','test_LabelCausalAblation.m')); assertSuccess(r);"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelCausalAblation('smoke'); analyze_LabelCausalAblation('smoke');"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelCausalAblation('pilot'); analyze_LabelCausalAblation('pilot');"
```

确认 pilot 决策没有 STOP 后执行：

```powershell
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelCausalAblation('screening'); analyze_LabelCausalAblation('screening');"
```

交接给 Stage 3 时必须同时提供 Stage 1 原始 MAT、Stage 2 MAT、两个阶段的 manifest 和 decision CSV；不得只提供汇总 CSV，因为外部效用需要回溯 PopulationEvalID。
