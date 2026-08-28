# 候选解模式贡献实验操作手册

本目录用于分阶段检验最新 AdaMaO 候选解模式的具体贡献。实验从机制是否真正激活开始，依次进入同状态反事实审计、小规模闭环筛选和正式性能验证。任何阶段都不预设候选模式有效；`STOP`、不显著、退化或仅部分因子有效，都是允许且必须完整保存的结果。

## 1. 证据边界

四个阶段回答不同问题，不得相互替代：

| 阶段 | 默认正式 profile | 主要问题 | 不能单独证明 |
|---|---|---|---|
| Stage 0 | `pilot` | 候选模式及其因子是否实际触发、改变选择，并且审计记录可追踪 | 直接效用、最终性能、因果优势 |
| Stage 1 | `pilot` | 固定同一状态和候选池后，规则是否优于匹配随机或信号破坏对照 | 独立搜索轨迹上的最终性能 |
| Stage 2 | `screening` | 通过前两阶段的因子在小规模独立闭环轨迹中是否仍有正向效果 | 正式、普遍的性能结论 |
| Stage 3 | `formal` | 冻结版本在预设正式矩阵上的最终性能、稳健性和代价 | 未包含问题或预算上的普遍有效性 |

每个阶段同时产生两类门控：

- `IntegrityGate`：判断数据、覆盖率、配对、协议和结果文件是否完整可信；
- `ScientificDecision`：判断预设科学标准是否允许进入下一阶段。

完整性 `PASS` 只表示结果可分析，不表示候选模式有效。

当前冻结契约为 `SchemaVersion=2`、`ProtocolVersion=CMC-2026-08-24-v2`。协议哈希同时绑定问题矩阵、算法参数、判定门槛、端点保存数、anytime 指标定义、冻结宿主源码、MATLAB 版本、计算机架构、HostName，以及实验目录中除 `tests/` 外的全部 `.m` 源码树。测试代码变化不会使科学结果失效，其他实验源码或执行环境变化会改变协议哈希。协议哈希不同的结果不得混用；旧协议或 `SchemaVersion=1` 的 MAT 文件不属于当前有效断点。

当前 `CMCProtocol.m` 冻结的正式矩阵为：

| 阶段 | 问题 | M | Runs | FE |
|---|---|---|---|---|
| Stage 0 pilot | DTLZ2、DTLZ7、WFG3、WFG7 | 10、20 | 1:3 | 500 |
| Stage 1 pilot | DTLZ2、DTLZ4、DTLZ7、WFG3、WFG4、WFG7 | 10、20 | 1:5 | 500 |
| Stage 2 screening | DTLZ2、DTLZ4、DTLZ7、WFG3、WFG4、WFG7 | 10 | 1:10 | 500 |
| Stage 3 formal | DTLZ1–DTLZ7、WFG1–WFG9 | 10、20 | 1:30 | 500 |

Stage 0 固定为 24 个任务、名义预算 12000 FE；Stage 1 固定为 60 个任务、名义预算 30000 FE。Stage 2 为每臂 60 个任务，Stage 3 为每臂 960 个任务；完整 15 臂时，Stage 2 为 900 个任务、名义预算 450000 FE，Stage 3 为 14400 个任务、名义预算 7200000 FE。缩减推进的实际工作量等于“每臂任务数 × 上游授权臂数”，开始前应先读取授权 CSV，不要按完整 15 臂盲目估算。

Stage 1 pilot 的快照检查点固定为 `FE/maxFE=0.20、0.50、0.80`，并使用 `Runs=1:5`。不要把其他比例替换成正式检查点。

各阶段写入 `ScientificDecision` 的主指标标签已经冻结：Stage 0 为 `BEHAVIORAL_ACTIVITY`，Stage 1 为 `DIRECT_ORACLE_EFFICIENCY_DELTA`，Stage 2/3 为 `FINAL_IGDP`。这些标签对应不同证据层级，不能把 Stage 0/1 的通过解释成最终 IGD+ 已改善。

每个 smoke 阶段固定使用 DTLZ2、WFG3，`M=3`、`D=6`、`run=1`、`maxFE=83`。

## 2. 实验目录

```text
REMO_new2_AdaMaO_CandidateModeContribution/
├─ README.md
├─ docs/                         # 协议锁、设计说明和决策记录
├─ CMCProtocol.m                 # 唯一阶段配置源和协议哈希
├─ CMCArmCatalog.m               # 唯一实验臂目录
├─ CMCStagePaths.m               # 统一结果路径
├─ algorithms/                   # 隔离的实验算法或包装器
│  └─ private/                  # 算法私有辅助函数
├─ tests/                        # 单元测试、契约测试和 smoke 测试
├─ run_CMCStage0.m
├─ analyze_CMCStage0.m
├─ run_CMCStage1.m
├─ analyze_CMCStage1.m
├─ run_CMCStage2.m
├─ analyze_CMCStage2.m
├─ run_CMCStage3.m
├─ analyze_CMCStage3.m
└─ results/
   ├─ stage0_activity/
   ├─ stage1_counterfactual/
   ├─ stage2_screening/
   └─ stage3_formal/
```

各阶段结果目录遵循同一约定：

```text
results/<stage>/
├─ raw/<profile>/<Arm>/<Problem>/M<M>/run_<NNN>.mat
├─ invalidated_raw/<Arm>/<Problem>/M<M>/run_<NNN>_<时间>_<UUID>.mat
├─ manifests/<profile>/          # 每次启动的 manifest CSV 及配套 MAT
└─ analysis/<profile>/           # 分析 CSV 直接写在本目录
```

runner manifest 的文件名格式为 `CMC_<stage>_<profile>_<时间>_pid<PID>.csv`，同名 MAT 保存本次 protocol、arms 和 jobs。CSV 是正式判定依据；当前分析器不生成图片。

Stage 0/1 固定使用只读审计臂 `AUDIT_CURRENT`。Stage 2/3 的冻结实验臂由 `CMCArmCatalog.m` 唯一定义：

| 类型 | 实验臂 |
|---|---|
| 完整候选模块 | `A00_FULL` |
| 单因子删除 | `A01_NO_P`、`A02_NO_Q`、`A03_NO_C`、`A04_NO_D`、`A05_NO_EGEN`、`A06_NO_EFINAL`、`A07_NO_F` |
| 信号破坏或门控对照 | `N01_SHUFFLE_D`、`N02_SHUFFLE_F`、`N03_NO_PERR_GATE` |
| 路由对照 | `G01_ALWAYS_EXPLORE`、`G02_ALWAYS_INDICATOR` |
| 多因素关系锚 | `C00_RELATION_CONTROL` |
| 未改写 HCV 外部锚 | `CURRENT_HCV` |

`CURRENT_HCV` 保留未改写原实现；由于它的批量规则未显式冻结，因此只作外部非劣锚，不是单因子归因基线。Stage 2/3 必须先证明固定因子宿主 `A00_FULL` 相对它没有越过预设退化界限，之后才能解释候选因子证据。

`A01_NO_P` 则有严格的单因子语义：去重后的最后一代候选池 `lastUnique` 是所有分支共同的硬候选全集。indicator 分支的关系粗筛、模型预测和预测失败回退都不能选到池外；explore 分支只在池内对关系分数和模糊度做 min-max 归一化，并只在池内计算 qKeep 阈值、执行 top-K 数量不足回退和多样性贪心。改变池外候选的任意极值不会改变池内增广分数或最终选择。因而 `A00_FULL` 对 `A01_NO_P` 才对应累计池因子 `P` 的冻结对比。任何阶段实际允许运行的臂还必须服从上一阶段的 ScientificDecision。

## 3. 开始前准备

在 MATLAB Command Window 中进入实验目录：

```matlab
experimentDir = fullfile('D:', 'PlatEMO-master', 'PlatEMO-master', ...
    'PlatEMO', 'Experiments', ...
    'REMO_new2_AdaMaO_CandidateModeContribution');
cd(experimentDir);
```

也可以在 PowerShell 中使用 MATLAB R2023a 批处理模式：

```powershell
& 'D:\mathlab2023a\bin\matlab.exe' -batch "cd('D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_CandidateModeContribution'); results=runtests(fullfile(pwd,'tests','CandidateModeContributionTest.m')); assertSuccess(results);"
```

注意完整路径中包含两层 `PlatEMO-master`。

正式推进链必须在同一执行宿主完成。`CMCProtocol` 会冻结当前 `MATLABVersion`、`Computer` 和 `HostName`，runner 将它们写入 MAT，validator 逐项核对；把上游 CSV 或 raw MAT 复制到另一台主机后继续运行会造成协议或元数据不匹配。若必须更换宿主，应使用新的 `ResultRoot`，从 Stage 0 重新开始一条独立证据链。

## 4. 先运行测试

任何阶段开始前都先运行完整测试：

```matlab
results = runtests(fullfile(experimentDir, ...
    'tests', 'CandidateModeContributionTest.m'));
disp(results);
assertSuccess(results);
```

当前测试集共有 24 项；预期结果为 `24 Passed, 0 Failed, 0 Incomplete`。测试项数量或结果不符时，不开始任何阶段运行。

测试通过只说明代码契约和小预算调用正常，不说明候选模式有效。

## 5. Smoke 规则

每个阶段都支持 `smoke`，用于检查入口、依赖、文件写入、分析和 gate 生成：

```matlab
run_CMCStage0('smoke');
analyze_CMCStage0('smoke');

run_CMCStage1('smoke');
analyze_CMCStage1('smoke');

run_CMCStage2('smoke');
analyze_CMCStage2('smoke');

run_CMCStage3('smoke');
analyze_CMCStage3('smoke');
```

`smoke` 只验证工程流程。上一阶段的 smoke 必须同时得到 `IntegrityGate=PASS` 和 `DecisionCode=SMOKE_PASS`，才允许运行下一阶段的 smoke。因此上面的命令必须按 Stage 0 → 1 → 2 → 3 顺序执行。

smoke gate 只能授权 smoke → smoke，不能授权任何 `pilot`、`screening` 或 `formal` 运行，也不能替代这些正式 profile。Stage 3 smoke 仍是终点，其 `CanProceed=false`。

最终冻结版本已经完成整条 smoke 链：Stage 0 为 2/2、Stage 1 为 2/2、Stage 2 为 6/6、Stage 3 为 6/6 个有效任务；四阶段均为 `IntegrityGate=PASS`、`DecisionCode=SMOKE_PASS`，Stage 3 为终点。该记录只证明冻结版本的工程链已跑通，不构成任何科学有效性证据。

## 6. Stage 0：活性与可追踪性审计

### 6.1 目标

Stage 0 检查候选模式是否真正进入目标代码路径，包括：

- attempted mode、实际 mode 和 fallback 是否可区分；
- 每个候选因子是否在运行中获得非零暴露；
- 请求评价数与实际评价数是否一致；
- 候选池、入选批次、来源轮次和稳定身份是否可追踪；
- 与匹配参考规则相比，选择是否实际发生改变；
- 审计表、MAT、manifest 和 CSV 是否能从同一稳定键一一对应。

每个有效代必须同时记录 `P、Q、K、C、D、E_GEN、E_FINAL、F、G、P_ERR_GATE` 十类因子行。pilot 中的足够机会覆盖要求至少 4 个 eligible run、DTLZ/WFG 各至少 2 个 run，并累计至少 30 个 eligible event。一个因子还必须满足 run 中位触发率不低于 `0.10`、run 中位决策改变率不低于 `0.10`；若中位 `OverlapAtK` 为有限值，则还必须不高于 `0.90`，才标记为 `ACTIVE`。只有 `FactorStatus=ACTIVE` 才能令 `CarryToNextStage=true`；`LOW_ACTIVITY`、`LOW_TRIGGER`、`LOW_DECISION_SEPARATION`、`DORMANT` 和机会不足都不能携带。

该阶段主指标是行为活性，不以最终 IGD+ 好坏判断候选模式贡献。`K` 是诊断项；完整/缩减推进由 `P、Q、C、D、E_GEN、E_FINAL、F、G` 八个主因子决定，`P_ERR_GATE` 即使活跃也不能单独放行。

### 6.2 运行

```matlab
run_CMCStage0('pilot');
stage0 = analyze_CMCStage0('pilot');
```

这类子集分析只用于查看缺失覆盖；在 24 个 Stage 0 pilot 任务全部有效前，`IntegrityGate` 不会成为可推进的完整门控。

先运行一个子集时，可使用：

```matlab
run_CMCStage0('pilot', ...
    'Problems', {'DTLZ2'}, ...
    'Ms', 10, ...
    'Runs', 1, ...
    'RunAnalysis', false);

stage0 = analyze_CMCStage0('pilot');
```

### 6.3 正式门控 CSV

```text
results/stage0_activity/analysis/pilot/
├─ CMC_Stage0_SourceTwinEquivalence.csv
├─ CMC_Stage0_JobStatus.csv
├─ CMC_Stage0_Coverage.csv
├─ CMC_Stage0_EventAudit.csv
├─ CMC_Stage0_FactorActivity.csv
├─ CMC_Stage0_FactorDecision.csv
├─ CMC_Stage0_IntegrityGate.csv
└─ CMC_Stage0_ScientificDecision.csv
```

只有同时满足以下条件才能运行 Stage 1：

1. `CMC_Stage0_IntegrityGate.csv` 的完整性状态为 `PASS`；
2. `CMC_Stage0_ScientificDecision.csv` 的决策代码为以下之一：

```text
PASS_TO_STAGE1
PASS_TO_STAGE1_REDUCED
```

- `PASS_TO_STAGE1`：八个主因子全部为 `ACTIVE`；
- `PASS_TO_STAGE1_REDUCED`：至少一个、但不是全部主因子为 `ACTIVE`，只携带 Decision CSV 中明确保留的因子；
- `STOP_TRAJECTORY_MISMATCH`、`STOP_SCHEMA_INVALID`、`INSUFFICIENT_DATA`、`INSUFFICIENT_BEHAVIORAL_OPPORTUNITIES` 或 `STOP_NO_BEHAVIORAL_ACTIVITY`：不得运行 Stage 1。

不得手工重新加入未被 Stage 0 授权的因子。Stage 0 的 `PASS` 只证明审计副本、行为行和活性条件满足协议，不证明这些活跃因子有直接效用。

## 7. Stage 1：同状态候选池反事实审计

### 7.1 目标

Stage 1 在相同 Archive、相同候选池、相同批量和相同真值下比较规则，避免把搜索路径差异误算为候选规则的直接贡献。主要检查：

- 完整候选规则相对匹配随机批次的真实效用和随机分布百分位；
- 各组成因子在固定候选池上的增量作用；
- shuffled uncertainty、shuffled score 等信号破坏对照；
- 与预设 score-only、relation-only 或其他参考规则的差异；
- 与 clairvoyant greedy benchmark 的剩余差距；
- 按 run 聚合的平均 OracleEfficiency 差值和随机分布百分位。

Stage 1 pilot 在每个独立 run 的 `0.20、0.50、0.80` 三个预算比例记录快照，共使用 5 个独立 run。smoke 使用自己的小预算配置，不能替代这组 pilot 检查点。

真值参考集固定为嵌套的 `4096 → 8192 → 16384` 点：先比较 4096 与 8192 点的候选边际效用 Spearman 相关和 oracle top-K Jaccard；若低于 `0.95/0.90`，才升级为 8192 与 16384 点复核。所有快照都必须最终 `Stable=true`，否则决策为 `INSUFFICIENT_REFERENCE_STABILITY`。

每个快照还生成 500 次匹配随机批次。随机对照保持相同 K，并按规则匹配 `ALL、LAST、EXP、IND` 候选资格集合，而不是从不相干的全集抽样。离线候选评价不计入 FE，审计结束后 FE 和全局随机数状态都必须保持不变。因子直接效用按 run 聚合；`QUALIFIED` 同时要求每个“问题族×M”至少有 4 个有效 run 且覆盖至少 2 个问题、平均 OracleEfficiency 差值至少 `0.05`、两层 bootstrap 的 95% 下界大于 0，以及 run 随机百分位中位数至少 `0.75`。

进入闭环阶段的完整证据集合共有 11 项。它们与 Stage 1 反事实、Stage 2/3 证据臂的映射如下：

| 证据项 | Stage 1 来源 | Stage 2/3 所需臂 |
|---|---|---|
| `P` | `ACCUM_MATCHED` 对 `FINAL_MATCHED` | `A01_NO_P` |
| `Q` | `EXP_FULL` 对 `EXP_NO_Q` | `A02_NO_Q` |
| `C` | `EXP_FULL` 对 `EXP_NO_C` | `A03_NO_C` |
| `D` | `EXP_FULL` 对 `EXP_NO_D` | `A04_NO_D` |
| `E_GEN` | 同状态下不可直接归因，沿用 Stage 0 活性并延迟检验 | `A05_NO_EGEN` |
| `E_FINAL` | `EXP_FULL` 对 `EXP_SIMPLE_FULL` | `A06_NO_EFINAL` |
| `F` | `IND_FULL` 对 `IND_RELATION_ONLY` | `A07_NO_F` |
| `G` | 同状态下不可直接归因，沿用 Stage 0 活性并延迟检验 | `G01_ALWAYS_EXPLORE` 和 `G02_ALWAYS_INDICATOR`，两臂都必须通过 |
| `D_SIGNAL` | `EXP_FULL` 对 `SHUFFLED_D` | `N01_SHUFFLE_D` |
| `F_SIGNAL` | `IND_FULL` 对 `SHUFFLED_F` | `N02_SHUFFLE_F` |
| `P_ERR_GATE` | `EXP_FULL` 对 `EXP_NO_PERR_GATE` | `N03_NO_PERR_GATE` |

这里的 11 项是因子级证据，不是 11 个实验臂；由于 `G` 需要两个路由对照，完整闭环证据实际包含 12 个对照臂，另有 `A00_FULL`、`C00_RELATION_CONTROL` 和 `CURRENT_HCV`。

离线 oracle 或 greedy benchmark 只能作为参照，不是可部署算法。

### 7.2 运行

运行 Stage 1 前，入口必须自动读取并验证 Stage 0 的两个门控 CSV：

```matlab
run_CMCStage1('pilot');
stage1 = analyze_CMCStage1('pilot');
```

这类子集分析同样只用于覆盖诊断；必须先完成全部 60 个 Stage 1 pilot 任务，再以不带任何子集参数的分析结果判断是否可进入 Stage 2。

子集示例：

```matlab
run_CMCStage1('pilot', ...
    'Problems', {'DTLZ2', 'WFG7'}, ...
    'Ms', [10, 20], ...
    'Runs', 1:2, ...
    'RunAnalysis', false);

stage1 = analyze_CMCStage1('pilot');
```

### 7.3 正式门控 CSV

```text
results/stage1_counterfactual/analysis/pilot/
├─ CMC_Stage1_JobStatus.csv
├─ CMC_Stage1_Coverage.csv
├─ CMC_Stage1_SnapshotUtility.csv
├─ CMC_Stage1_ReferenceSensitivity.csv
├─ CMC_Stage1_PerRun.csv
├─ CMC_Stage1_PairedComparisons.csv
├─ CMC_Stage1_FactorDecision.csv
├─ CMC_Stage1_IntegrityGate.csv
└─ CMC_Stage1_ScientificDecision.csv
```

只有完整性状态为 `PASS`，且科学决策代码为以下之一，才能运行 Stage 2：

```text
PASS_TO_STAGE2_POOL_ONLY
PASS_TO_STAGE2_REDUCED
PASS_TO_STAGE2_FULL
```

三个代码的授权范围不同：

- `PASS_TO_STAGE2_POOL_ONLY`：实际 `CarryToNextStage=true` 的集合严格等于 `{P}`；
- `PASS_TO_STAGE2_REDUCED`：九个可推进主项 `P、Q、C、D、E_GEN、E_FINAL、F、G、P_ERR_GATE` 中至少一个被实际携带，但携带集合既不是仅 `{P}`，也没有覆盖完整 11 项；因此仅携带延迟项 `E_GEN/G` 或门控项 `P_ERR_GATE` 也可以形成 REDUCED，`D_SIGNAL/F_SIGNAL` 单独存在则不能放行；
- `PASS_TO_STAGE2_FULL`：上述九个主项加 `D_SIGNAL、F_SIGNAL`，共 11 项全部 `CarryToNextStage=true`。可同状态检验的项目须通过直接效用门槛，`E_GEN/G` 则由 Stage 0 活性授权并明确延迟到闭环检验。

`STOP_COUNTERFACTUAL_INVALID`、`INSUFFICIENT_REFERENCE_STABILITY`、`INSUFFICIENT_UTILITY_VARIATION`、`INSUFFICIENT_DIRECT_EFFECT_DATA` 或 `STOP_NO_DIRECT_EFFECT` 均不能运行 Stage 2。`PASS_TO_STAGE2_FULL` 仍只表示完整证据集合获准接受闭环检验，不表示 11 项已经带来最终性能收益。

不得把较窄授权解释成完整候选模式已经有效。

## 8. Stage 2：小规模闭环筛选

### 8.1 目标

Stage 2 让通过 Stage 1 的候选规则各自驱动独立搜索轨迹，检查离线直接效用能否转化为闭环效果。该阶段用于筛选，不用于正式论文显著性结论。

主要检查：

- 相同 Problem、M、预算和配对种子下的闭环差异；
- 完整臂 `A00_FULL` 与各已授权对照臂的配对 final IGD+；
- 几何均值 IGD+ 比、bootstrap 置信区间、方向一致性和严重退化计数；
- DTLZ 与 WFG 两个问题族是否满足预设非劣门槛；
- PerRunEndpoint 中保存的 IGD、IGD+、anytime IGD+ AUC、运行时间，以及 `MATLABVersion`、`Computer`、`HostName` 执行环境字段。

所有端点对比使用 `log(IGD+_A00_FULL / IGD+_对照臂)`；因此几何均值比小于 1 才有利于完整臂。置信区间使用两层 bootstrap：先重采样 Problem-M 层，再在层内重采样配对 run，共 10000 次。每个臂另外进行 20000 次单侧分层 sign-flip，并对臂级 p 值做 Holm 校正；`Qualified=true` 必须同时满足预设实际门槛和 `ArmHolmP<=0.05`。单个 Problem-M 的 `RawP/HolmP` 仍写入比较表，但正式因子门控读取臂级结果。

Stage 2 的实际门槛要求总体几何均值比不高于 `0.98`、总体 95% 上界小于 1、DTLZ 与 WFG 几何均值比都不高于 `1.05`，且比值达到 `1.20` 的严重退化单元不超过 1 个。`CURRENT_HCV` 另作宿主非劣锚：总体上界、每个 M 的最大上界、每个“问题族×M”几何均值比以及 DTLZ/WFG 总体比都必须不高于 `1.05`，每个“问题族×M”的严重退化计数也不得超过 1。它是否优于完整臂不是因子归因条件。

Stage 2 和 Stage 3 的 runner 都固定传入 `save=4`。每个原始 MAT 必须保存恰好 4 行 `anytimeTrace`（`FE`、`FERatio`、`IGDp`）和一个 `anytimeIGDpAUC`。校验器要求 FE 严格递增、`FERatio=FE/maxFE`、末行 `FE=maxFE` 且 `FERatio=1`、末行 IGD+ 等于 final IGD+，并从轨迹复算出同一 AUC。冻结 AUC 是从首个实际观测 FE 到 `maxFE` 的梯形平均，绝不向 `FE=0` 外推。

### 8.2 运行

运行 Stage 2 前，入口必须自动验证 Stage 1 的完整性和授权范围：

```matlab
run_CMCStage2('screening');
stage2 = analyze_CMCStage2('screening');
```

子集示例：

```matlab
run_CMCStage2('screening', ...
    'Problems', {'DTLZ2', 'WFG7'}, ...
    'Ms', 10, ...
    'Runs', 1:5, ...
    'Arms', {'A00_FULL'}, ...
    'RunAnalysis', false);

stage2 = analyze_CMCStage2('screening');
```

这里的 `Arms` 只用于 runner 分批。完成全部上游授权臂和全部正式任务后，最终分析必须像上例最后一行一样不传 `Arms`；`analyze_CMCStage2('screening','Arms',...)` 会被代码拒绝。

### 8.3 正式门控 CSV

```text
results/stage2_screening/analysis/screening/
├─ CMC_Stage2_JobStatus.csv
├─ CMC_Stage2_Coverage.csv
├─ CMC_Stage2_PerRunEndpoint.csv
├─ CMC_Stage2_EndpointComparisons.csv
├─ CMC_Stage2_ArmDecision.csv
├─ CMC_Stage2_IntegrityGate.csv
└─ CMC_Stage2_ScientificDecision.csv
```

只有完整性状态为 `PASS`，且科学决策代码为以下之一，才能运行 Stage 3：

```text
PASS_TO_STAGE3_REDUCED
PASS_TO_STAGE3_FULL
```

- `PASS_TO_STAGE3_FULL`：`CURRENT_HCV` 宿主锚非劣，`C00_RELATION_CONTROL` 净模块对比合格，至少一个主贡献因子获得支持，Stage 1 为 `PASS_TO_STAGE2_FULL`，并且完整 11 项计划证据全部存在且全部获得臂级支持；
- `PASS_TO_STAGE3_REDUCED`：宿主锚、净模块和至少一个主贡献因子满足推进条件，但不满足上述完整证据条件，只携带 `CMC_Stage2_ArmDecision.csv` 中 `CarryToNextStage=true` 的冻结臂。

`INSUFFICIENT_DATA`、`STOP_FACTOR_HOST_MISMATCH`、`INCONCLUSIVE_ENDPOINT_SCREEN` 或 `STOP_NO_ENDPOINT_SIGNAL` 均停止，不得运行 Stage 3，也不得通过增加种子、删除负向问题或更换主指标来绕过 gate。

Stage 2/3 的 `ScientificDecision.QualifiedFactors` 和 `DroppedFactors` 只汇总真实证据角色，即 drop-one、信号/门控负对照和路由对照；不把 `FULL`、`CONTROL` 或 `ANCHOR` 当成因子。`G` 只有两个路由臂都存在且都 `Qualified=true` 时才列入 `QualifiedFactors`。

## 9. Stage 3：正式性能验证

### 9.1 目标

Stage 3 对 Stage 2 冻结的版本进行正式算法级验证。协议开始后不得根据结果修改实验臂、主指标、问题集、配对种子、统计 family 或成功门槛。

正式报告至少区分：

- Primary final IGD+；
- PerRunEndpoint 中的 IGD、IGD+、anytime IGD+ AUC 和运行时间；
- 各 Problem-M 单元的配对差值、几何均值比、置信区间、效应量和 Holm 校正；
- DTLZ、WFG、各问题和 M=10/20 的方向及严重退化情况；
- `ArmDecision` 与最终单行 `ScientificDecision` 中的支持、部分支持、不确定或不支持代码。

Stage 3 沿用两层 bootstrap、臂级分层 sign-flip 和臂级 Holm 门控。一个正式对照臂的实际条件包括：总体几何均值比不高于 `0.98` 且总体上界小于 1；至少一个 M 同时达到该改善门槛；每个 M 要么改善、要么其上界不高于 `1.05`；所有“问题族×M”几何均值比不高于 `1.05`；有利方向比例至少 `0.60`；每个“问题族×M”中严重退化单元不超过 1。随后还必须满足 `ArmHolmP<=0.05` 才标记为 `Qualified`。

这些门槛只在冻结的问题、M、FE、宿主实现和授权臂范围内解释。即使最终代码含 `SUPPORTED`，也不自动证明跨预算、跨问题或跨宿主的普遍因果优势。

### 9.2 运行

```matlab
run_CMCStage3('formal');
stage3 = analyze_CMCStage3('formal');
```

可先用正式协议中的一个任务检查写入，但部分覆盖不能形成正式结论：

```matlab
run_CMCStage3('formal', ...
    'Problems', {'DTLZ2'}, ...
    'Ms', 10, ...
    'Runs', 1, ...
    'Arms', {'A00_FULL'}, ...
    'RunAnalysis', false);

stage3 = analyze_CMCStage3('formal');
```

这里的 `Arms` 同样只用于 runner 分批。形成终局 CSV 时必须不传 `Arms`；`analyze_CMCStage3('formal','Arms',...)` 会被代码拒绝。只有一个任务或一个实验臂的部分覆盖不能形成正式结论。

### 9.3 终局 CSV

```text
results/stage3_formal/analysis/formal/
├─ CMC_Stage3_JobStatus.csv
├─ CMC_Stage3_Coverage.csv
├─ CMC_Stage3_PerRunEndpoint.csv
├─ CMC_Stage3_EndpointComparisons.csv
├─ CMC_Stage3_ArmDecision.csv
├─ CMC_Stage3_IntegrityGate.csv
└─ CMC_Stage3_ScientificDecision.csv
```

Stage 3 是终局，没有下一阶段。无论正式科学代码是什么，`CMC_Stage3_ScientificDecision.csv` 都应记录 `CanProceed=false` 且 `NextStage` 为空。`CMC_Stage3_IntegrityGate.csv` 为 `PASS` 只表示正式矩阵完整可信；最终候选模式是否获得支持，以科学决策、效应量、置信区间和分问题结果共同解释。

Stage 3 的终局科学代码精确含义如下：

- `SUPPORTED_FULL_MODULE`：`CURRENT_HCV` 宿主锚非劣，净模块对比和至少一个主贡献因子合格，上游为 `PASS_TO_STAGE3_FULL`，且 12 个注册证据臂全部存在并全部合格；
- `SUPPORTED_REDUCED_MODULE`：宿主锚、净模块和至少一个主贡献因子合格，但不满足完整正式证据条件；
- `PERFORMANCE_GAIN_WITHOUT_FACTOR_ATTRIBUTION`：净模块合格，但没有主贡献因子获得完整臂级归因；
- `FACTOR_EFFECT_WITHOUT_NET_PERFORMANCE_GAIN`：至少一个主贡献因子合格，但净模块对比不合格；
- `INCONCLUSIVE_FORMAL_EFFECT`：净模块置信区间跨越预设改善与非劣边界；
- `NO_CONFIRMED_ENDPOINT_ADVANTAGE`：没有确认端点优势；
- `FACTOR_HOST_NOT_NONINFERIOR_TO_CURRENT`：固定因子宿主未通过 `CURRENT_HCV` 非劣锚；
- `INSUFFICIENT_FORMAL_DATA`：正式完整性门未通过。

这些终局代码都不会授权下一阶段。

## 10. 阶段推进总表

| 从哪一阶段进入下一阶段 | 必须满足的 IntegrityGate | 允许的 ScientificDecision |
|---|---|---|
| Stage 0 → Stage 1 | `PASS` | `PASS_TO_STAGE1`、`PASS_TO_STAGE1_REDUCED` |
| Stage 1 → Stage 2 | `PASS` | `PASS_TO_STAGE2_POOL_ONLY`、`PASS_TO_STAGE2_REDUCED`、`PASS_TO_STAGE2_FULL` |
| Stage 2 → Stage 3 | `PASS` | `PASS_TO_STAGE3_REDUCED`、`PASS_TO_STAGE3_FULL` |
| Stage 3 | `PASS` 才能形成完整正式结论 | 终局，`CanProceed=false`，无下一阶段 |

下一阶段 runner 应自动执行这些检查。仅有 CSV 文件、分析函数正常返回、smoke 通过或局部子集结果较好，都不构成放行条件。

smoke 工程链单独使用 `SMOKE_PASS`：Stage 0 smoke 只能授权 Stage 1 smoke，Stage 1 smoke 只能授权 Stage 2 smoke，Stage 2 smoke 只能授权 Stage 3 smoke。

## 11. 子集参数

各 `run_CMCStageN` 入口采用统一的 name-value 子集参数：

| 参数 | 示例 | 作用 |
|---|---|---|
| `Problems` | `{'DTLZ2','WFG7'}` | 仅运行指定问题 |
| `Ms` | `[10,20]` | 仅运行指定目标数 |
| `Runs` | `1:5` | 仅运行指定独立 run |
| `Arms` | `{'A00_FULL'}` | 仅供 Stage 2/3 runner 分批，且必须是上一阶段授权臂的子集 |
| `ResultRoot` | `'D:\temp\CMC_results'` | 使用隔离结果根目录；同一推进链的 run/analyze 必须始终传入同一路径 |
| `RunAnalysis` | `false` | 是否在 runner 完成后分析；默认就是 `false`，分批时保持 `false` |

示例：

```matlab
run_CMCStage2('screening', ...
    'Problems', {'WFG7'}, ...
    'Ms', 10, ...
    'Runs', 1:5, ...
    'Arms', {'A00_FULL'}, ...
    'RunAnalysis', false);
```

Stage 0 和 Stage 1 固定使用 `AUDIT_CURRENT`，向 runner 显式传入 `Arms` 会报错。Stage 2 和 Stage 3 的 `Arms` 不能扩大上一阶段 Decision CSV 的授权范围；未传入时自动使用全部已授权臂。`Arms` 仅用于 runner 的调试、分批和并行执行，不是正式分析筛选器。

除 smoke 工程检查外，分析器禁止 `Arms` 子集。pilot、screening 和 formal 的最终 CSV 必须分别用以下不带 `Arms` 的命令生成：

```matlab
analyze_CMCStage0('pilot');
analyze_CMCStage1('pilot');
analyze_CMCStage2('screening');
analyze_CMCStage3('formal');
```

即使 runner 分成多个 `Arms` 批次，最终分析也必须一次读取当前 profile 下的全部上游授权臂；否则不能生成科学门控。

分析入口只接受 `ResultRoot` 和 `Arms` 两个可选参数，不接受 `Problems`、`Ms` 或 `Runs` 过滤。除 smoke 外，任何显式 `Arms` 都会触发 `CMC:PartialScientificAnalysisForbidden`；因此 pilot、screening 和 formal 最终分析必须完整读取当前授权集合。

## 12. 断点续跑与并行分批

每个独立任务保存为单独 MAT 文件。再次执行同一命令时：

- 已存在且通过 schema、协议和元数据校验的结果直接跳过；
- 缺失任务继续运行；
- runner 遇到损坏、协议不一致、轨迹校验失败或上游哈希过期的已有文件时，先把原文件移动到 `invalidated_raw` 隔离区，再重新运行该任务；
- 每次启动生成独立 manifest CSV 及配套 MAT；
- 分析器读取当前 profile 下全部合法结果并重新生成 CSV。

隔离路径为 `results/<stage>/invalidated_raw/<Arm>/<Problem>/M<M>/`，文件名保留 run 编号，并附加时间和 UUID。只有成功保留旧文件后 runner 才会重跑；隔离失败会立即报错，绝不静默覆盖。

Stage 1–3 的结果还绑定上一阶段当前 ScientificDecision 及授权表的决策哈希。只要上一阶段门控或授权内容变化，哈希就会变化；runner 下次遇到旧下游 MAT 时会把它移入 `invalidated_raw` 后重跑，分析器也不会把它纳入合法结果。不要把新授权与旧下游结果拼接。

因此，运行中断后通常只需重新执行原命令：

```matlab
run_CMCStage2('screening');
```

多个 MATLAB 进程可以在同一宿主上处理互不重叠的 `Runs`、`Problems` 或 `Arms` 子集。禁止跨宿主拼接同一结果链，也不要让两个进程同时写入同一 `Arm-Problem-M-Run` 任务。

只重新分析已有结果不会重跑搜索：

```matlab
stage0 = analyze_CMCStage0('pilot');
stage1 = analyze_CMCStage1('pilot');
stage2 = analyze_CMCStage2('screening');
stage3 = analyze_CMCStage3('formal');
```

## 13. 常见误判

- `SMOKE_PASS`：只允许推进同一 smoke 工程链，不能授权其他 profile。
- `IntegrityGate=PASS`：只表示数据完整，不表示候选模式有效。
- 部分任务均为正：覆盖不完整时不能当作正式结论。
- Stage 1 胜过随机：只支持固定状态下的直接效用，不等于闭环最终性能提升。
- Stage 2 筛选为正：只决定是否值得投入正式预算，不替代 Stage 3。
- 总平均为正：不能掩盖 WFG7、某一问题族或某一目标数上的系统性退化。
- 相关机制量与最终 IGD+ 同向：属于机制一致性证据，不自动构成因果中介证明。

任何阶段未通过时，应保留原始结果、manifest、CSV 和 Decision 代码，并把结论写成“当前候选模式未获得进入下一阶段所需的证据”，而不是修改门槛直到通过。
