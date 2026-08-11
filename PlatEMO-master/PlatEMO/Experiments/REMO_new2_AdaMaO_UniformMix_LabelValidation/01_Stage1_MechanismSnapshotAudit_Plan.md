# Stage 1：标签机制快照与方向来源审计实施规划

> **For agentic workers:** REQUIRED SUB-SKILL: use a plan-execution workflow and complete the checkbox steps in order. Do not modify the frozen production algorithm in place.

**Goal:** 在不改变优化轨迹的前提下，记录 UniformMix-OriginalRelation 每次标签生成所使用的种群、代表解标签、非支配方向得分、方向回退原因和稳定评价编号，为后续四个阶段提供可复核的统一数据源。

**Architecture:** 在 `Experiments/REMO_new2_AdaMaO_UniformMix_LabelValidation` 中建立实验专用算法副本和审计管线。审计算法只增加输出，不额外调用 K-means、随机采样、网络训练或候选生成；当前混合标签轨迹必须与冻结算法逐值等价。另建一个“原始代表解二值标签”行为策略，其余运行机制保持相同，用于避免后续离线分析只覆盖当前算法自己访问到的状态。

**Tech Stack:** MATLAB、PlatEMO、Statistics and Machine Learning Toolbox（`kmeans`、`pdist2`、`fitrsvm`）、Deep Learning Toolbox（`patternnet`、`mapminmax`）。

---

## 1. 实验目的和结论边界

本阶段只回答以下描述性问题：

1. 在正式的 `M=10/20, N=100` 设置中，方向 `V` 有多少代真正来自当前非支配解的 K-means 中心？
2. 均匀方向回退分别由“非支配解不足、目标范围退化、NDSort 失败、K-means 失败”中的哪一种触发？
3. `score_v`、`label_dyn` 和最终 `Catalog` 在早、中、晚期分别有多大差异？
4. 系数 `alpha=1-FE/maxFE` 是否真的使连续得分主导排序，还是因为 `score_v` 方差过小而实际上仍由二值标签主导？
5. 当前混合标签轨迹与原始代表解二值标签轨迹访问到的种群状态是否明显不同？

本阶段不能证明“新标签更准确”，因为还没有引入独立的真实效用。不得把标签重合率、内部一致性或 `p_err` 写成标签正确率。

## 2. 冻结对象和源码事实

执行前必须确认 PlatEMO 根目录是包含 `platemo.m` 的目录，并确认以下入口只解析到独立算法目录：

```text
Algorithms/Multi-objective optimization/
  REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/
    REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m
```

冻结算法的七个 GUI 参数和正式取值为：

| 参数 | 正式值 | 含义 |
|---|---:|---|
| `gmax` | 3000 | 代理辅助内部最大迭代数 |
| `pMix` | 0.50 | 指标候选模式概率 |
| `rGood` | 0.25 | 混合得分正组比例 |
| `qKeep` | 0.80 | 探索模式保留分位 |
| `lambda0` | 0.35 | 初始探索强度 |
| `nMin` | 4 | 每代最少真实评价候选数 |
| `nMax` | 6 | 每代最多真实评价候选数 |

必须保持以下源码语义：

- 当 `D>10` 时，算法初始化评价数为 100；正式实验均属于此情况。
- `kEff=min(Problem.N,max(6,ceil(1.5*M)))`，因此 `M=10` 时为 15，`M=20` 时为 30。
- `Nref=100`、`theta=5`、`alpha=1-FE/maxFE`。
- `M<=3` 或 `N<50` 时直接使用均匀方向。
- 高维分支只有在第一前沿解数不少于 `max(10,Nref/2)=50`、每个目标范围不退化且 K-means 成功时，才使用非支配解派生方向。
- 当前方向关联使用原始 `PopObj` 与 `V` 的余弦，PBI 投影使用 `PopObj-Zmin`；本阶段只记录该实现，不得静默改成坐标一致版本。
- 最终关系网络训练标签仍由硬 `Catalog` 产生，不是连续监督。

严禁直接修改上述独立算法目录中的生产文件。本阶段新增内容全部放在实验目录中，并用唯一类名避免 MATLAB 路径冲突。

## 3. 统一问题矩阵、维度和随机种子

固定问题顺序如下，顺序同时决定 `problemIndex`：

| `problemIndex` | 问题 | 作用 | Requested D | Actual D |
|---:|---|---|---:|---:|
| 1 | DTLZ2 | 光滑规则 PF 对照 | 30 | 30 |
| 2 | DTLZ4 | 偏置映射与方向集中敏感性 | 30 | 30 |
| 3 | DTLZ7 | 断裂 PF 与覆盖缺口 | 30 | 30 |
| 4 | WFG3 | 退化 PF 与方向冗余 | 30 | 31 |
| 5 | WFG7 | 参数依赖且保护既有强项 | 30 | 30 |

WFG3 的 `Setting` 会把 `D=30` 调整为 31，以保证 `L=D-K` 为偶数。结果文件必须同时保存 `requestedD=30` 和 `actualD=31`，不得把 WFG3 写成实际 `D=30`。

配对种子对所有阶段保持一致：

```matlab
seed = problemIndex*10000 + M*100 + run;
```

同一 `Problem/M/run` 下，不同行为策略和不同标签版本必须使用相同 `run` 与 `seed`。统计配对键固定为：

```matlab
pairedKey = sprintf('%s_M%d_run%03d',problem,M,run);
```

### 3.1 三种运行 profile

| Profile | Behavior | Problems | M | Runs | N | maxFE | gmax | 证据用途 |
|---|---|---|---|---:|---:|---:|---:|---|
| `smoke` | Hybrid、AnchorNative | DTLZ2 | 3 | 1 | Problem.N=20 | 35 | 1 | 只验证管线；不进入论文统计 |
| `pilot` | Hybrid、AnchorNative | DTLZ2 | 10 | 2 | 100 | 300 | 300 | 验证高维自适应方向、续跑和等价性；不作正式推断 |
| `screening` | Hybrid、AnchorNative | 五个问题 | 10、20 | 5 | 100 | 500 | 3000 | 方向性机制证据，合计100个作业 |

`smoke` 的 DTLZ2 使用 `M=3,D=3`；虽然 `Problem.N=20`，算法根据 `D<=10` 初始化 `11D-1=32` 个解，因此 `initialFE=32`。验证器必须预期这一事实。

## 4. 两条行为轨迹的唯一差异

### 4.1 `Hybrid` 行为

标签和优化行为必须与冻结的 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original` 完全一致：

```matlab
Catalog = topQ(alpha*scoreV + (1-alpha)*double(labelDyn),rGood);
```

### 4.2 `AnchorNative` 行为

只把训练 `Catalog` 替换为原始代表解二值标签：

```matlab
Catalog = logical(labelDyn);
```

其余部分，包括初始化、`RefSelect`、关系对生成、原始无权关系网络、SDE 模型、UniformMix 模式流、候选生成、真实评价数和环境选择，必须与 Hybrid 审计算法相同。该版本正例比例由原始 `GetOutput_PBI` 的自适应 `delta` 决定，目标区间是 0.30–0.70，不得强行改为 0.25。

`AnchorNative` 是“只替换训练 Catalog”的受控标签干预，不是历史 REMO 可执行文件的逐值复现：它仍计算未用于 Catalog 的 `ScoreV`，从而与 Hybrid 保持相同 K-means 调用和随机数消耗。论文中可以称为 same-runtime anchor-label baseline，不能把它的轨迹或耗时冒充原始 REMO 的历史结果；完整外部算法对比需另行直接运行对应原算法入口。

## 5. 计划创建的文件及职责

后续执行本规划时，在当前实验目录创建：

```text
LabelValidationProtocol.m
LabelValidationSchema.m
LabelValidationStableSeed.m
run_LabelMechanismSnapshotAudit.m
ValidateLabelMechanismSnapshotFile.m
analyze_LabelMechanismSnapshotAudit.m
algorithms/LVUniformMixAuditBase.m
algorithms/LVUniformMixAudit_Hybrid.m
algorithms/LVUniformMixAudit_AnchorNative.m
algorithms/private/LVComputeLabelViews.m
algorithms/private/LVRefSelectWithIndex.m
tests/test_LabelMechanismSnapshotAudit.m
results/stage1/                       % 运行时生成，不提交 Git
```

职责必须严格分离：

- `LabelValidationProtocol(profile)`：返回冻结问题矩阵、参数、作业表和统计常量。
- `LabelValidationSchema()`：集中定义 MAT schema 版本、方向来源枚举和字段名。
- `LabelValidationStableSeed(problemIndex,M,run)`：只实现上面的种子公式。
- `LVComputeLabelViews`：在算法原本唯一一次标签计算中，同时返回当前算法所需输出和审计字段；禁止审计端再次运行 K-means。
- `LVRefSelectWithIndex`：复制冻结 `RefSelect` 的数值逻辑，同时返回 Archive 行号；新增输出不得增加随机调用。
- 两个入口类：只提供行为代码，所有其余实现共享同一个 base。
- runner：支持 `smoke/pilot/screening`、合法结果跳过、非法既有结果阻塞、临时文件原子保存和 manifest。
- validator：在续跑前验证 metadata、FE、维度、索引、字段宽度、有限数值和行为代码。
- analyzer：只读取通过 validator 的 MAT，并输出本阶段描述性 CSV 与阶段决定。

## 6. 快照和结果数据契约

结果路径固定为：

```text
results/stage1/<profile>/<Behavior>/<Problem>/M<M>/run_<RRR>.mat
```

每个 MAT 必须保存以下顶层变量：

```text
metadata
evaluations
snapshots
trajectory
finalPopulation
IGD
IGDp
runtime
auditRuntime
validation
```

### 6.1 `metadata` 必需字段

```text
schemaVersion, profile, behavior, problem, family, M,
requestedD, actualD, problemN, initialFE, maxFE, completedFE,
gmax, pMix, rGood, qKeep, lambda0, nMin, nMax,
run, seed, pairedKey, algorithmClass, frozenAlgorithmClass,
matlabVersion, computer, completedAt
```

### 6.2 `evaluations` 必需字段

每个真实评价解只保存一次：

```text
EvalID       % 1..completedFE 的连续整数
Decision     % completedFE x actualD
Objective    % completedFE x M
Generation   % 该解被评价时的代号；初始化为0
```

`EvalID` 只能对应正式 `Problem.Evaluation`，不得把离线重算、参考点或 shadow evaluation 混入。

### 6.3 每个 `snapshots(s)` 必需字段

```text
SnapshotID, Generation, FE, Ratio, Alpha,
PopulationEvalID, PopulationDec, PopulationObj,
RefEvalID, RefObj, kEff, Nref, Theta,
DirectionSource, FallbackReason,
Front1Count, ClusterCount, UniqueDirectionCount, V,
Delta, AnchorPositiveRate, AnchorNormalizedG, AnchorMargin,
LabelDyn, ScoreV, ScoreHybrid, CatalogCurrent,
ScoreVStd, LabelDynStd, EffectiveScaleRatio
```

定义：

```matlab
AnchorMargin = 1 - AnchorNormalizedG;
EffectiveScaleRatio = Alpha*std(ScoreV) / ...
    ((1-Alpha)*std(double(LabelDyn)) + eps);
```

`DirectionSource` 使用固定枚举：

| Code | 名称 | `FallbackReason` |
|---:|---|---|
| 1 | `ND_KMEANS` | `NONE` |
| 2 | `UNIFORM_LOW_M_OR_N` | `M_LE_3_OR_N_LT_50` |
| 3 | `UNIFORM_FRONT_TOO_SMALL` | `FRONT1_LT_THRESHOLD` |
| 4 | `UNIFORM_ZERO_RANGE` | `OBJECTIVE_RANGE_LT_1E12` |
| 5 | `UNIFORM_NDSORT_FAILURE` | `NDSORT_EXCEPTION` |
| 6 | `UNIFORM_KMEANS_FAILURE` | `KMEANS_EXCEPTION` |

不得把所有均匀方向笼统记录为“K-means失败”。

### 6.4 `trajectory` 必需字段

```text
Generation, FEBefore, FEAfter, CandidateMode,
SelectedEvalID, PopulationEvalIDAfter
```

候选模式用 `indicator/explore/fallback` 三种字符串记录。`SelectedEvalID` 必须能在 `evaluations.EvalID` 中找到。

## 7. 实施任务清单

### Task 1：建立协议、schema 与前置检查

- [ ] 创建 `LabelValidationProtocol.m`，逐字固化第3节的 profile、问题顺序、维度和七参数。
- [ ] 创建 `LabelValidationSchema.m`，schema 初始版本设为整数 `1`。
- [ ] 创建 `LabelValidationStableSeed.m`，对 DTLZ2/M10/run1 验证返回 11001，对 WFG3/M20/run5 验证返回 42005。
- [ ] 前置检查 `which`：五个问题、冻结算法、`kmeans`、`pdist2`、`fitrsvm`、`patternnet` 均必须非空。
- [ ] 验证 `which('REMO_new2_AdaMaO_SDEOnly_UniformMix_Original')` 的规范化绝对路径位于独立算法目录，不得解析到旧共享目录。
- [ ] 实例化 `WFG3('N',100,'M',10,'D',30,'maxFE',500)` 和 M20 版本，断言两者 `Problem.D==31`。

### Task 2：实现只增加输出的标签审计函数

- [ ] 从冻结私有函数逐句复制计算顺序到 `LVComputeLabelViews`，不得重排随机调用。
- [ ] 将自适应方向函数改为同时返回 `DirectionSource/FallbackReason/Front1Count/ClusterCount`，但每代仍只调用一次 K-means。
- [ ] 将原始锚点 PBI 改为同时返回最终 `delta`、每个解的 `AnchorNormalizedG` 和 `AnchorPositiveRate`；二值输出必须与冻结函数完全相等。
- [ ] 计算并返回 `ScoreV/LabelDyn/ScoreHybrid/CatalogCurrent`；Hybrid 行为直接使用该次调用的 `CatalogCurrent`。
- [ ] 保留当前坐标原点不一致的实现，不在 Stage 1 修复几何公式。

### Task 3：实现稳定 EvalID 与行为轨迹

- [ ] 使用 `LVRefSelectWithIndex` 返回 Archive 索引，并把索引映射为稳定 `EvalID`。
- [ ] 初始化解编号为 `1:initialFE`；每次真实评价后依次追加编号，不允许复用。
- [ ] 每次训练开始前保存一个 snapshot；每次真实评价后更新 `evaluations` 和 `trajectory`。
- [ ] 审计计时单独累计到 `auditRuntime`，不得加入 FE；不得进行任何额外真实评价。
- [ ] Hybrid 与 AnchorNative 入口只返回不同的行为代码，不复制两套主循环。

### Task 4：实现可恢复 runner 和严格 validator

- [ ] runner 每个 job 开始前保存并最终恢复 MATLAB 全局 RNG 状态。
- [ ] 在构造算法前执行 `rng(job.Seed,'twister')`。
- [ ] 结果先写 `run_XXX.mat.tmp.mat`，验证保存成功后原子移动为正式文件。
- [ ] 正式文件存在且验证通过时标记 `skipped`；存在但验证失败时标记 `invalid-existing`，不得覆盖。
- [ ] validator 检查 `EvalID==1:completedFE`、`completedFE==maxFE`、WFG3 actualD、所有 snapshot 行数、所有索引外键和有限数值。
- [ ] validator 检查 Hybrid 每个 snapshot 的 `sum(CatalogCurrent)==ceil(populationSize*rGood)`。
- [ ] validator 检查 AnchorNative 实际用于训练的 Catalog 等于 `LabelDyn`，但不得要求其正例比例为25%。

### Task 5：证明审计没有改变 Hybrid 轨迹

- [ ] 用相同 seed 分别运行冻结算法和 `LVUniformMixAudit_Hybrid` 的 smoke。
- [ ] 对最终解按 `[objs,decs]` 字典序排序，断言决策值与目标值逐元素相等，容差 `1e-12`。
- [ ] 断言两者完成 FE 相同、最终 IGD/IGDp 差值不超过 `1e-12`。
- [ ] 再在 pilot 的 DTLZ2/M10/run1 上重复一次；如果不等价，停止全部 screening，定位多余随机调用。
- [ ] 将等价性检查写入 `tests/test_LabelMechanismSnapshotAudit.m`，不能只人工观察。

### Task 6：运行、分析与归档

- [ ] 先运行完整测试和 smoke，确认两个行为文件均为 valid。
- [ ] 运行 pilot；检查至少出现一个高维 snapshot，且 `Front1Count/DirectionSource` 均有记录。
- [ ] 审阅 pilot 后再运行 screening 的100个作业。
- [ ] analyzer 输出第8节规定的 CSV，不得从无效或 smoke 文件汇总论文指标。
- [ ] 保存运行 manifest，失败作业必须保留错误消息和文件路径。

## 8. 分析输出和统计单位

分析目录固定为：

```text
results/stage1/<profile>/analysis/
```

必须生成：

```text
Stage1_run_manifest.csv
Stage1_snapshot_metrics.csv
Stage1_direction_source_summary.csv
Stage1_branch_overlap_summary.csv
Stage1_trajectory_summary.csv
Stage1_decision.csv
Stage1_analysis.mat
```

关键指标：

- 各问题/M/阶段的 `ND_KMEANS` 比例和各回退原因比例；
- `Front1Count`、`ClusterCount`、`UniqueDirectionCount`；
- `corr(ScoreV,LabelDyn,'Type','Spearman')`；
- `Jaccard(TopQ(ScoreV),TopQ(AnchorMargin))`；
- `Jaccard(CatalogCurrent,TopQ(ScoreV))` 和与 `TopQ(AnchorMargin)` 的重合率；
- `EffectiveScaleRatio` 和移除任一分支后的 TopQ 排名变化；
- 相邻 snapshot 的 Catalog 翻转率；
- Hybrid 与 AnchorNative 两类轨迹的前沿数、方向来源和最终 IGD/IGDp 描述性差异。

候选解和 snapshot 行只用于描述；置信区间或重采样必须以 `pairedKey/run` 为聚类单位，不能把同一 run 中的100个解当成100个独立样本。

## 9. Stage 1 决策规则

`Stage1_decision.csv` 只允许以下代码：

| DecisionCode | 条件 | 后续动作 |
|---|---|---|
| `PASS_TO_STAGE2` | 全部必需作业有效，Hybrid 等价性通过，审计字段完整 | 进入 Stage 2 |
| `PASS_WITH_LOW_ADAPTIVE_COVERAGE` | 数据有效，但任一问题家族中 `ND_KMEANS` snapshot 比例低于50% | 可进入 Stage 2，但论文不得写“主要使用非支配方向” |
| `STOP_TRAJECTORY_MISMATCH` | 审计 Hybrid 与冻结算法不等价 | 停止并修复审计实现 |
| `STOP_SCHEMA_INVALID` | FE、维度、EvalID 或外键验证失败 | 停止并修复 runner/validator |
| `INSUFFICIENT_DATA` | 某个问题家族有效 paired run 少于4个 | 补跑缺失作业，不作机制结论 |

Stage 2 只能读取 `PASS_TO_STAGE2` 或 `PASS_WITH_LOW_ADAPTIVE_COVERAGE` 对应的 valid 文件。

## 10. 预期结果（研究假设，不是通过标准）

合理预期如下：

- 在 M=10/20 的多目标环境中，第一前沿往往较大，因此多数高维 snapshot 可能使用 `ND_KMEANS`；但 WFG3 或早期阶段可能出现更多回退。
- `ScoreV` 与 `LabelDyn` 预计正相关但不完全一致，说明它们是同一数据的不同压缩，而不是独立信息源。
- 当前混合 Catalog 预计在早期更接近 `ScoreV` 排名、后期更接近 `LabelDyn`；如果 `ScoreVStd` 很小，该趋势可能不会出现。
- Hybrid 与 AnchorNative 轨迹可能逐渐分离，但在相同 paired seed 下应具有可比较的初始化和预算。

以下结果会削弱论文故事：

- 大部分高维 snapshot 都回退到均匀方向；
- `UniqueDirectionCount` 长期极低或大量重复；
- 当前 Catalog 与任一单分支的重合率几乎始终超过0.95；
- `alpha` 变化与实际排名影响无关；
- 审计实现无法保持冻结 Hybrid 的逐值轨迹。

## 11. 执行命令

在 PowerShell 中先进入包含 `platemo.m` 的 PlatEMO 根目录，然后执行：

```powershell
$env:ADAMAO_PLATEMO_ROOT = (Resolve-Path '.').Path
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); r=runtests(fullfile(pwd,'Experiments','REMO_new2_AdaMaO_UniformMix_LabelValidation','tests','test_LabelMechanismSnapshotAudit.m')); assertSuccess(r);"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelMechanismSnapshotAudit('smoke'); analyze_LabelMechanismSnapshotAudit('smoke');"
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelMechanismSnapshotAudit('pilot'); analyze_LabelMechanismSnapshotAudit('pilot');"
```

只有 `pilot/analysis/Stage1_decision.csv` 没有 STOP 代码后，才执行：

```powershell
matlab -batch "cd(getenv('ADAMAO_PLATEMO_ROOT')); addpath(genpath(pwd)); run_LabelMechanismSnapshotAudit('screening'); analyze_LabelMechanismSnapshotAudit('screening');"
```

执行完成后，将 `Stage1_decision.csv`、manifest、MAT schema 版本和有效作业数一起交给 Stage 2；不要只交一张汇总图。
