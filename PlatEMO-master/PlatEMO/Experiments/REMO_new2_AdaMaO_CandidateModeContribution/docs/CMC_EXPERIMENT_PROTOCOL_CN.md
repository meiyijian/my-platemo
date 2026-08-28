# 候选解模式贡献实验冻结协议

## Material Passport

- Origin Skill: `academic-research-suite / experiment-agent`
- Origin Mode: `plan`
- Origin Date: `2026-08-24`
- Verification Status: `CURRENT_CODE_SYNCED_SMOKE_VERIFIED_FORMAL_NOT_EXECUTED`
- Version Label: `cmc_protocol_v2`
- Schema Version: `2`
- Protocol Version: `CMC-2026-08-24-v2`
- Contract Tests: `24/24 PASS`
- Frozen Smoke: `frozen2；Stage0 2/2、Stage1 2/2、Stage2 6/6、Stage3 6/6；全部 IntegrityGate=PASS、DecisionCode=SMOKE_PASS`

## 1. 协议性质与证据边界

本文档是 `REMO_new2_AdaMaO_CandidateModeContribution` 当前实现的预注册协议。配置以 `CMCProtocol.m` 为唯一事实源，实验臂以 `CMCArmCatalog.m` 为唯一事实源，阶段推进以实际生成的 `IntegrityGate`、`ScientificDecision` 和授权 CSV 为准。

四个阶段回答不同问题：

| 阶段 | 主要问题 | 不能单独证明 |
|---|---|---|
| Stage 0 | 因素是否获得足够机会、触发并实际改变选择 | 直接效用和最终性能 |
| Stage 1 | 同一 Archive、候选池、K 和真值下，规则是否提高直接批效用 | 独立闭环轨迹上的最终 IGD+ 优势 |
| Stage 2 | 获授权因素是否出现值得正式验证的闭环端点信号 | 正式、普遍的性能结论 |
| Stage 3 | 冻结正式矩阵上，净模块和具体证据因素是否获得端点支持 | 未测试问题、预算、环境或宿主上的普遍有效性 |

Stage 0/1 不证明最终性能；Stage 2 是 screening，不作正式性能结论；Stage 3 是本协议终点，没有 Stage 4。负结果、退化、数据不足、仅部分因素有效和结果不确定，均是合法结果，不能通过改门槛、删问题或换指标绕过。

当前完成的 `24/24` 契约测试和四阶段 frozen2 smoke 只证明代码契约、文件写入和门控链可运行，不证明候选模块有效。正式 pilot、screening 和 formal 尚须按本协议运行。

## 2. 冻结协议、环境与复用边界

### 2.1 通用参数

```text
SchemaVersion    = 2
ProtocolVersion  = CMC-2026-08-24-v2
RequestedD       = 30
N                = 100
maxFE            = 500（非 smoke）
gmax             = 3000
pMix             = 0.50
rGood            = 0.25
qKeep            = 0.80
lambda0          = 0.35
nMin             = 4
nMax             = 6
nHarm            = 2
wConFlag         = 0
Checkpoints      = [0.20, 0.50, 0.80]
RandomReplicates = 500
ReferenceSizes   = [4096, 8192, 16384]
EndpointSaveCount = 0（Stage 0/1），4（Stage 2/3）
AnytimeIGDpDefinition = TRAPEZOID_MEAN_FROM_FIRST_OBSERVED_FE_TO_MAXFE
```

WFG2/WFG3 在 `D-(M-1)` 为奇数时使用实际 `D=31`；其余问题保持请求 D。各阶段使用独立 seed 空间；同一阶段、同一 `Problem-M-Run` 的不同 arm 共用 SearchSeed 和 PairedKey。

### 2.2 冻结阈值

```text
DirectMCID                 = 0.05
EndpointMCIDRatio          = 0.98
NonInferiorityMargin       = 1.05
SevereRegressionRatio      = 1.20
MaxSevereRegressionCount   = 1
BootstrapSamples           = 10000
BootstrapSeed              = 20260824
SignFlipSamples            = 20000
SignFlipSeed               = 20260825
Alpha                      = 0.05
ActivityRate               = 0.10
MaxOverlapAtK              = 0.90
ReferenceSpearman          = 0.95
ReferenceJaccard           = 0.90
UtilityTolerance           = 1e-12
```

### 2.3 ProtocolHash 边界

每个阶段/profile 的 `ProtocolHash` 绑定：

- `SchemaVersion`、`ProtocolVersion`、阶段、profile、问题矩阵、M、Runs、D、N、maxFE 和算法参数；
- 全部阈值、检查点、随机重复数、参考集大小、端点保存数和 anytime AUC 定义；
- 冻结 HCV 宿主源码哈希；
- `CMCProtocol.m` 自身、runner、analyzer、validator、上游门、统计门、schema、算法核心等组件；
- 完整 `algorithms/` MATLAB 源码树；
- 实验目录下除 `tests/` 外的 MATLAB 源码树；
- 分析辅助函数哈希。

源码树和 helper 使用相对路径参与哈希，因此相同代码可位于不同安装绝对路径；绝对路径本身不触发漂移。`tests/` 不参与冻结科学协议，但测试仍必须通过。

协议还绑定当前执行环境：

```text
MATLABVersion
Computer
HostName
```

raw MAT 的 metadata 保存并校验这三个值。不同 MATLAB 版本、`computer` 标识或主机名会形成不同 ProtocolHash；同一正式阶段不得跨 host 混跑或拼接结果。可以在同一主机上用多个 MATLAB 进程处理互不重叠的任务，但不能让两个进程写同一 `Arm-Problem-M-Run`。

### 2.4 上游授权指纹

Stage 1--3 的入口要求上一阶段同时存在且通过：

- `CMC_StageN_IntegrityGate.csv`；
- `CMC_StageN_ScientificDecision.csv`；
- 授权 CSV：Stage 0 为 `CMC_Stage0_FactorDecision.csv`，Stage 1 为 `CMC_Stage1_FactorDecision.csv`，Stage 2 为 `CMC_Stage2_ArmDecision.csv`。

`DecisionHash` 绑定上一阶段 ProtocolHash，以及 IntegrityGate、ScientificDecision 和授权 CSV 的内容指纹；只忽略 `GeneratedAt`。该值写入下游 raw MAT 的 `metadata.UpstreamDecisionHash`。上游重分析、DecisionCode 变化或授权行变化后，旧下游结果立即失效，不能跨授权变化复用；runner 会先把旧文件移入 `invalidated_raw` 再重跑。

## 3. 冻结矩阵与实验臂

### 3.1 阶段矩阵

| 阶段 | Profile | Problems | M | Runs | maxFE |
|---|---|---|---|---|---:|
| Stage 0 | `pilot` | DTLZ2、DTLZ7、WFG3、WFG7 | 10、20 | 1:3 | 500 |
| Stage 1 | `pilot` | DTLZ2、DTLZ4、DTLZ7、WFG3、WFG4、WFG7 | 10、20 | 1:5 | 500 |
| Stage 2 | `screening` | DTLZ2、DTLZ4、DTLZ7、WFG3、WFG4、WFG7 | 10 | 1:10 | 500 |
| Stage 3 | `formal` | DTLZ1--DTLZ7、WFG1--WFG9 | 10、20 | 1:30 | 500 |

Stage 0 有 24 个 `AUDIT_CURRENT` job，Stage 1 有 60 个。Stage 2 每个授权 arm 有 60 个 job；Stage 3 每个携带 arm 有 960 个 job，实际 arm 数由上游授权决定。

四个 smoke 均使用 DTLZ2、WFG3、`M=3`、`RequestedD=6`、`Runs=1`、`maxFE=83`、`gmax=24`、检查点 0.75、20 次随机重复和 `[64,128,256]` 参考集。Stage 0/1 smoke 各 2 个 job；Stage 2/3 smoke 固定 `A00_FULL、A01_NO_P、CURRENT_HCV`，各 6 个 job。

### 3.2 因素与 arm

| 证据因素 | 定义 | Stage 2/3 所需 arm |
|---|---|---|
| P | 累积去重候选池相对最后一代去重候选池 | `A01_NO_P` |
| Q | explore 分位保留 | `A02_NO_Q` |
| C | explore 决策空间多样性项 | `A03_NO_C` |
| D | explore 预测模糊度奖励 | `A04_NO_D` |
| E_GEN | 内层 GA 的加权聚合 | `A05_NO_EGEN` |
| E_FINAL | 最终 explore 选择的加权聚合 | `A06_NO_EFINAL` |
| F | indicator 关系粗筛后的 SVR 重排 | `A07_NO_F` |
| G | explore/indicator 路由 | `G01_ALWAYS_EXPLORE` 和 `G02_ALWAYS_INDICATOR` |
| D_SIGNAL | 候选间预测模糊度身份置换 | `N01_SHUFFLE_D` |
| F_SIGNAL | 关系粗筛集内 SVR 预测身份置换 | `N02_SHUFFLE_F` |
| P_ERR_GATE | 移除 `p_err` 对 `lambda_t` 的门控 | `N03_NO_PERR_GATE` |

这是 11 项因子级证据。G 需要两个 route arm，因此完整证据集合实际有 12 个 comparator arm：A01--A07、N01--N03、G01、G02。

其他固定 arm：

- `A00_FULL`：固定 K=6 的完整候选模块；
- `C00_RELATION_CONTROL`：累积池上的纯关系 top-K 多因素净模块对照；
- `CURRENT_HCV`：未经改写、批量规则未显式冻结的当前 HCV 外部非劣锚；
- `AUDIT_CURRENT`：Stage 0/1 的只读审计副本。

`CURRENT_HCV` 不是固定 K 的单因素归因基线。因素证据统一由 `A00_FULL` 对相应 arm 得出；净模块优先使用 `C00_RELATION_CONTROL`，只有缺失时才回退 `CURRENT_HCV`。

`A01_NO_P` 有两个冻结硬合同：

1. indicator 分支的 relation coarse、指标预测和最终 top-K 的 eligible universe 只能是 `lastUnique`；
2. explore 分支的 score/ambiguity min-max 归一化、qKeep 分位阈值、候选不足时的 fallback top-K、diversity 贪心及其内部 score/distance 归一化，都只能在 `lastUnique` 内计算。

因此，最后一代池外的候选及其极端 score/ambiguity 值不得改变 A01 的归一化、保留集合或最终结果。冻结测试已包含“池外极值不变性”检查。不得再把 A01 解释成只限制 explore 输出，或允许池外值参与标定。

K 只在 Stage 0 诊断；当前没有 K 的独立端点 arm，不能归因 K 的最终贡献。

## 4. 统计单位、多重比较与端点合同

### 4.1 统一统计单位

- Stage 0：独立 run 是活性汇总单位；候选点和代不是独立样本。
- Stage 1：先在每个 run 内对有效快照等权平均，再以 `RUN_NESTED_IN_PROBLEM_M` 推断；快照和 500 个随机批次不是新增独立样本。
- Stage 2/3：原始推断量是同一 Problem-M-Run、同一 PairedKey 下的配对 log-ratio；run 嵌套于 Problem-M，Problem-M 等权。

端点原始量为：

```text
l_pmr = log(max(IGDp_A00_FULL, realmin))
        - log(max(IGDp_Comparator, realmin))
```

若两端 IGD+ 都为 0，则该 log-ratio 记为 0。每个 Problem-M 单元先对配对 run 求均值，arm 总体点估计再对 Problem-M 单元等权：

```text
GeoMeanRatioIGDp = exp(mean(Problem-M mean log-ratio))
```

比值小于 1 表示 `A00_FULL` 更好。

### 4.2 两层 bootstrap

Stage 1 的 CI 按 Problem-M 分组；Stage 2/3 的 arm 总体 CI 使用全部 run 层原始 log-ratio。两者都执行 10000 次两层 bootstrap：

1. 等权重采样 Problem-M 组；
2. 在每个抽中的组内重采样 run；
3. 对各组均值再等权平均。

单个 Problem-M 的 CI 仅重采样该单元内配对 run。Stage 3 的逐 M CI 也从对应 M 的 run 层原始量按 Problem-M 两层重采样，不能从单元均值假装获得更多样本。

### 4.3 p 值与 Holm 边界

Stage 1 九个直接对照的 RawP/HolmP 会写出，但不进入 Stage 1 `QUALIFIED` 硬门。

Stage 2/3 有两类 Holm：

- `EndpointComparisons.HolmP`：在每个 comparator 内，对计划 Problem-M 单元校正；只作单元报告，不决定 arm 最终 Qualified；
- `ArmDecision.ArmHolmP`：对当前完整授权分析中的全部 comparator arm 做跨臂 Holm 校正，排除 A00_FULL；这是硬门。

每个 arm 的 `ArmRawP` 来自 20000 次单侧层次 sign-flip。统计量给每个 Problem-M 等权、组内每个 run 等权；负 log-ratio 有利于 A00_FULL。最终：

```text
Qualified = PracticalQualified && ArmHolmP <= 0.05
```

因此不能再声称正式 arm 硬门“不要求 HolmP”。单元级 HolmP 与臂级 ArmHolmP 的作用不同，报告时不得混用。

### 4.4 四点 anytimeTrace 与 AUC

Stage 2/3 固定 `save=4`，每个 raw MAT 必须保存恰好 4 行：

```text
anytimeTrace = table(FE, FERatio, IGDp)
FERatio      = FE / maxFE
```

runner 使用结果对象中实际存在的保存 FE，排序并去重；末点必须是 `maxFE`，且末点 IGD+ 替换为 final IGD+。validator 要求：

- 恰好 4 行、FE 和 FERatio 严格递增；
- `FERatio=FE/maxFE`；
- 末行 `FE=maxFE`、`FERatio=1`；
- 末行 IGD+ 等于 final IGD+；
- 从 trace 复算的 AUC 与保存值误差不超过 `1e-12*max(1,abs(AUC))`。

设 `x_i=FERatio_i`、`y_i=IGDp_i`，冻结定义为：

```text
AnytimeIGDpAUC = trapz(x,y) / (x_end-x_first)
```

即从首个实际保存 FE 到 maxFE 的归一化梯形均值，不向 FE=0 外推。AUC 当前是可复算辅助端点；Stage 2/3 的主门仍使用 final IGD+。

## 5. 目录与运行总则

默认目录：

```text
results/<StageFolder>/
├─ raw/<profile>/<Arm>/<Problem>/M<M>/run_<NNN>.mat
├─ invalidated_raw/<Arm>/<Problem>/M<M>/run_<NNN>_<时间>_<UUID>.mat
├─ manifests/<profile>/CMC_<stage>_<profile>_<时间>_pid<PID>.csv
├─ logs/<profile>/
└─ analysis/<profile>/
```

所有分析 CSV 直接写在 `analysis/<profile>/`，没有 `tables/` 子目录。阶段目录是：

```text
stage0_activity
stage1_counterfactual
stage2_screening
stage3_formal
```

MATLAB 入口目录：

```matlab
experimentDir = fullfile('D:','PlatEMO-master','PlatEMO-master', ...
    'PlatEMO','Experiments','REMO_new2_AdaMaO_CandidateModeContribution');
cd(experimentDir);
```

运行完整契约测试：

```matlab
testResults = runtests(fullfile(experimentDir,'tests', ...
    'CandidateModeContributionTest.m'));
assertSuccess(testResults);   % 当前冻结基线：24/24 PASS
```

runner 支持 `Problems`、`Ms`、`Runs`、`Arms`、`ResultRoot`、`RunAnalysis`；默认 `RunAnalysis=false`。Stage 0/1 固定 `AUDIT_CURRENT`，不能传 `Arms`。Stage 2/3 的 `Arms` 只允许缩小上游授权范围，用于分批运行，不能扩大授权。

正式非 smoke analyzer 禁止非空 `Arms`，否则报 `CMC:PartialScientificAnalysisForbidden`。分批全部完成后，最终分析必须不带 `Arms`，以完整授权集合生成唯一 gate。analyzer 只接受 `ResultRoot` 和 `Arms`，不接受 Problems/Ms/Runs 过滤。

若使用自定义 ResultRoot，同一推进链的 run 和 analyze 必须一直传入同一路径：

```matlab
resultRoot = 'D:\CMC_results';
run_CMCStage0('pilot','ResultRoot',resultRoot);
stage0 = analyze_CMCStage0('pilot','ResultRoot',resultRoot);
```

## 6. Stage 0：行为活性门

### 6.1 活性判据

矩阵：4 problems × 2 M × 3 runs = 24 个 `AUDIT_CURRENT` job。runner 首先生成并验证 `CMC_Stage0_SourceTwinEquivalence.csv`；Generation history、完成 FE、最终 RNG、最终决策/目标、IGD、IGD+ 必须在 `1e-12` 容差内与当前 HCV 等价。

每个有效代必须记录 P、Q、K、C、D、E_GEN、E_FINAL、F、G、P_ERR_GATE 十类因子。非 smoke 的机会充分要求：

```text
EligibleRuns      >= 4
DTLZEligibleRuns  >= 2
WFGEligibleRuns   >= 2
EligibleEvents    >= 30
```

状态按顺序判定：

| FactorStatus | 条件 | CarryToStage1 |
|---|---|---:|
| `CONSTANT_K6_NOT_ADAPTIVE` | K 机会充分且全部 SelectedK=6 | 0 |
| `INSUFFICIENT_OPPORTUNITIES` | 机会覆盖不足 | 0 |
| `LOW_TRIGGER` | run 中位触发率 <0.10 | 0 |
| `LOW_DECISION_SEPARATION` | 有限的 run 中位 OverlapAtK >0.90 | 0 |
| `ACTIVE` | 触发率 >=0.10、OverlapAtK 不越过 0.90、改变率 >=0.10 | 1 |
| `LOW_ACTIVITY` | 0<改变率<0.10 | 0 |
| `DORMANT` | 改变率=0 | 0 |

只有 `ACTIVE` 携带；LOW 状态不携带。Stage 0 的主推进集合是 P、Q、C、D、E_GEN、E_FINAL、F、G；P_ERR_GATE 可授权后续直接对照，但不能单独放行，K 仅诊断。

### 6.2 运行

```matlab
run_CMCStage0('pilot');
stage0 = analyze_CMCStage0('pilot');
```

可分 Problems/Ms/Runs 执行，分批时保持 `RunAnalysis=false`；所有 24 job 完成后再运行不带过滤的 analyzer。

### 6.3 唯一 DecisionCode

| DecisionCode | 条件 | 可运行 Stage 1 |
|---|---|---:|
| `SMOKE_PASS` | smoke 完整性通过 | 仅 smoke 链 |
| `STOP_TRAJECTORY_MISMATCH` | SourceTwin 缺失或失败 | 0 |
| `STOP_SCHEMA_INVALID` | job/schema/audit 完整性失败 | 0 |
| `INSUFFICIENT_DATA` | 完整性通过但 EventAudit 为空 | 0 |
| `INSUFFICIENT_BEHAVIORAL_OPPORTUNITIES` | 八个主因素全部机会不足 | 0 |
| `STOP_NO_BEHAVIORAL_ACTIVITY` | 八个主因素没有任何 ACTIVE | 0 |
| `PASS_TO_STAGE1_REDUCED` | 至少一个、但不是全部八个主因素 ACTIVE | 1 |
| `PASS_TO_STAGE1` | 八个主因素全部 ACTIVE | 1 |

只有 IntegrityGate=`PASS` 且 DecisionCode 为 `PASS_TO_STAGE1` 或 `PASS_TO_STAGE1_REDUCED`，才能运行 Stage 1。Stage 0 的 `PrimaryMetric=BEHAVIORAL_ACTIVITY`。

### 6.4 输出 CSV

```text
CMC_Stage0_SourceTwinEquivalence.csv
CMC_Stage0_JobStatus.csv
CMC_Stage0_Coverage.csv
CMC_Stage0_IntegrityGate.csv
CMC_Stage0_EventAudit.csv
CMC_Stage0_FactorActivity.csv
CMC_Stage0_FactorDecision.csv
CMC_Stage0_ScientificDecision.csv
```

## 7. Stage 1：同状态直接效应门

### 7.1 快照、参考集和匹配随机

矩阵：6 problems × 2 M × 5 runs = 60 个 `AUDIT_CURRENT` source run；检查点固定为 0.20、0.50、0.80。

每个检查点冻结同一 Archive、模型状态、候选池和 K。全池候选通过 `CalObj/CalCon` 离线计算一次，必须保持 Problem.FE 和全局 RNG 不变；`OfflineCandidateEvaluations>0` 且 `CountedTowardFE=false`。

参考集是严格嵌套的 R4096 ⊂ R8192 ⊂ R16384。先比较 4096/8192 的候选边际效用 Spearman 和 oracle top-K Jaccard：

```text
UtilitySpearman   >= 0.95
OracleTopKJaccard >= 0.90
```

失败时升级并比较 8192/16384。全部计划快照最终都必须 `Stable=true`；任一失败输出 `INSUFFICIENT_REFERENCE_STABILITY`。

每个快照生成 500 个 K 匹配随机批次。随机基线按规则匹配候选资格集合：

- `FINAL_MATCHED` 使用 LAST；
- `ACCUM_MATCHED` 使用 ALL；
- indicator 规则和 `SHUFFLED_F` 使用 IND 关系粗筛集；
- explore 规则使用 EXP 保留集；
- `RANDOM_MATCHED` 随实际 mode 选择 IND 或 EXP。

因此随机百分位不是从不相干全集抽样，也不增加独立样本量。

### 7.2 九个直接对照和两个 deferred 因素

```text
P          : ACCUM_MATCHED       vs FINAL_MATCHED
Q          : EXP_FULL            vs EXP_NO_Q
C          : EXP_FULL            vs EXP_NO_C
D          : EXP_FULL            vs EXP_NO_D
E_FINAL    : EXP_FULL            vs EXP_SIMPLE_FULL
F          : IND_FULL            vs IND_RELATION_ONLY
D_SIGNAL   : EXP_FULL            vs SHUFFLED_D
F_SIGNAL   : IND_FULL            vs SHUFFLED_F
P_ERR_GATE : EXP_FULL            vs EXP_NO_PERR_GATE
```

`P_ERR_GATE` 是第九个直接对照，不是 deferred，也不得在 FactorDecision 重复。只有 E_GEN 和 G 不能在同一冻结池归因；若 Stage 0 为 ACTIVE，它们在 Stage 1 记为 `DEFER_TO_STAGE2`。

Stage 0 授权继续约束直接结果：D_SIGNAL 继承 D 的活性授权，F_SIGNAL 继承 F；其他直接项使用自己的 Stage 0 行。未获 Stage 0 ACTIVE 授权的行即使数值达标，也改记 `NOT_AUTHORIZED_BY_STAGE0_ACTIVITY` 且不携带。

批效用：

```text
BatchGainIGDp    = IGDp(Archive) - IGDp(Archive union Batch)
OracleEfficiency = BatchGainIGDp / OracleGainIGDp
```

若 `OracleGainIGDp <= 1e-12*max(1,ArchiveIGDpBefore)`，快照状态为 `INSUFFICIENT_UTILITY_VARIATION`。

每个直接对照先在 run 内平均有效快照，再按 Problem-M/Run 两层 bootstrap。`QUALIFIED` 同时要求：

1. DTLZ 和 WFG 各至少覆盖 2 个有效问题、4 个有效 run 行；
2. `MeanDeltaOracleEfficiency >=0.05`；
3. `CI95Lower>0`；
4. run 级 `MedianRandomPercentile` 的总体中位数 `>=0.75`。

Stage 1 RawP/HolmP 不进入该布尔门。

### 7.3 9 项推进集合与 11 项 FULL

可单独触发向 Stage 2 推进的九个主项是：

```text
P,Q,C,D,E_GEN,E_FINAL,F,G,P_ERR_GATE
```

D_SIGNAL、F_SIGNAL 不能单独推进。完整 FULL 集合是在上述九项基础上再加 D_SIGNAL、F_SIGNAL，共 11 项。G 仍是一个因子项，但闭环阶段要求两个 route arm。

### 7.4 运行

```matlab
run_CMCStage1('pilot');
stage1 = analyze_CMCStage1('pilot');
```

### 7.5 唯一 DecisionCode

| DecisionCode | 条件 | 可运行 Stage 2 |
|---|---|---:|
| `SMOKE_PASS` | smoke 完整性通过 | 仅 smoke 链 |
| `STOP_COUNTERFACTUAL_INVALID` | IntegrityGate 不为 PASS | 0 |
| `INSUFFICIENT_REFERENCE_STABILITY` | 任一参考行不稳定 | 0 |
| `INSUFFICIENT_UTILITY_VARIATION` | 没有 UtilityStatus=PASS 的快照 | 0 |
| `INSUFFICIENT_DIRECT_EFFECT_DATA` | 没有主项携带，且至少一个主项为 INSUFFICIENT* | 0 |
| `STOP_NO_DIRECT_EFFECT` | 九个主项均未携带，且不是数据不足 | 0 |
| `PASS_TO_STAGE2_POOL_ONLY` | 全部 CarryToNextStage 中只有 P | 1 |
| `PASS_TO_STAGE2_REDUCED` | 至少一个九项主因素携带，但不满足 POOL_ONLY/FULL | 1 |
| `PASS_TO_STAGE2_FULL` | 11 项全部 CarryToNextStage=true | 1 |

只有 IntegrityGate=`PASS` 且 DecisionCode 为三个 `PASS_TO_STAGE2_*` 之一，才能运行 Stage 2。Stage 1 的 `PrimaryMetric=DIRECT_ORACLE_EFFICIENCY_DELTA`。通过仍不证明最终 IGD+。

### 7.6 输出 CSV

```text
CMC_Stage1_JobStatus.csv
CMC_Stage1_Coverage.csv
CMC_Stage1_IntegrityGate.csv
CMC_Stage1_SnapshotUtility.csv
CMC_Stage1_ReferenceSensitivity.csv
CMC_Stage1_PerRun.csv
CMC_Stage1_PairedComparisons.csv
CMC_Stage1_FactorDecision.csv
CMC_Stage1_ScientificDecision.csv
```

## 8. Stage 2：闭环 screening 门

### 8.1 授权 arm

Stage 2 始终授权 `A00_FULL、C00_RELATION_CONTROL、CURRENT_HCV`。Stage 1 `CarryToNextStage=true` 的因素按以下方式追加：P/Q/C/D/E_GEN/E_FINAL/F 分别映射 A01--A07；D_SIGNAL/F_SIGNAL 分别映射 N01/N02；P_ERR_GATE 映射 N03；G 同时映射 G01/G02。

runner 的 `Arms` 只能用于分批，正式 analyzer 必须无 Arms。

### 8.2 arm Qualified 和 CURRENT_HCV 非劣锚

Stage 2 comparator 的 `PracticalQualified` 同时要求：

```text
总体 GeoMeanRatioIGDp <= 0.98
总体两层 bootstrap CI95Upper < 1
DTLZGeoMeanRatio <= 1.05
WFGGeoMeanRatio <= 1.05
全部 Problem-M 中严重退化单元数 <= 1
```

随后必须 `ArmHolmP<=0.05` 才得到 `Qualified=true`。

`CURRENT_HCV` 是固定因素宿主非劣锚，不要求它优于 A00_FULL，也不要求其自身 Qualified。锚必须完整覆盖所有计划单元，并同时满足：

```text
Cells == numel(Problems)*numel(Objectives)
总体 CI95Upper <= 1.05
每个 M 的 CI95Upper 最大值 <= 1.05
每个 Family-M 的点估计几何均值比最大值 <= 1.05
DTLZGeoMeanRatio <= 1.05
WFGGeoMeanRatio <= 1.05
每个 Family-M 的严重退化计数最大值 <= 1
```

若 Stage 2 允许推进，CURRENT_HCV 会被强制 `CarryToNextStage=true`，即使它不满足“优于完整臂”的 Qualified 门，以便 Stage 3 继续做宿主非劣校验。

### 8.3 planned 支持与 FULL/REDUCED

`planned` 是 Stage 1 FactorDecision 中全部 CarryToNextStage=true 的因素。每个 planned 因素必须具有完整 required arm，且全部 required arm Qualified 才算 supported；G 必须 G01、G02 两臂都通过。

要推进 Stage 3，必须：

1. IntegrityGate=PASS；
2. CURRENT_HCV 锚兼容；
3. 净模块 comparator 优先取 C00_RELATION_CONTROL，且必须 Qualified；
4. 至少一个主要因素 P/Q/C/D/E_GEN/E_FINAL/F/G/P_ERR_GATE supported；D_SIGNAL/F_SIGNAL 不能单独放行。

`PASS_TO_STAGE3_FULL` 还必须同时满足：

- 上游 Stage 1 DecisionCode=`PASS_TO_STAGE2_FULL`；
- 完整 11 项都在 planned；
- 完整 11 项都 supported；
- 所有 planned 因素都 supported。

否则只要前四项满足，就是 `PASS_TO_STAGE3_REDUCED`。

### 8.4 运行

```matlab
run_CMCStage2('screening');
stage2 = analyze_CMCStage2('screening');
```

分批示例：

```matlab
run_CMCStage2('screening','Arms', ...
    ["A00_FULL","C00_RELATION_CONTROL"], ...
    'Runs',1:5,'RunAnalysis',false);

% 全部上游授权 arm 和正式 job 完成后：
stage2 = analyze_CMCStage2('screening');
```

### 8.5 唯一 DecisionCode

| DecisionCode | 条件 | 可运行 Stage 3 |
|---|---|---:|
| `SMOKE_PASS` | smoke 完整性通过 | 仅 smoke 链 |
| `INSUFFICIENT_DATA` | 完整性失败，或 net/anchor/planned/required arm 不完整 | 0 |
| `STOP_FACTOR_HOST_MISMATCH` | CURRENT_HCV 非劣锚失败 | 0 |
| `INCONCLUSIVE_ENDPOINT_SCREEN` | net 未 Qualified，且 CI 同时跨越 0.98 与 1.05 | 0 |
| `STOP_NO_ENDPOINT_SIGNAL` | net 明确不通过，或无主要因素支持 | 0 |
| `PASS_TO_STAGE3_REDUCED` | net、锚和至少一个主要因素通过，但不满足 FULL | 1 |
| `PASS_TO_STAGE3_FULL` | net、锚通过，且上游/完整 11 项条件全部满足 | 1 |

Stage 2 的 `PrimaryMetric=FINAL_IGDP`，但其结果仍只用于 screening。

### 8.6 输出 CSV

```text
CMC_Stage2_JobStatus.csv
CMC_Stage2_Coverage.csv
CMC_Stage2_IntegrityGate.csv
CMC_Stage2_PerRunEndpoint.csv
CMC_Stage2_EndpointComparisons.csv
CMC_Stage2_ArmDecision.csv
CMC_Stage2_ScientificDecision.csv
```

## 9. Stage 3：正式终点验证

### 9.1 正式 PracticalQualified

Stage 3 只运行 Stage 2 ArmDecision 中 CarryToNextStage=true 的 arm，使用独立 Stage 3 seed。每个 comparator 的 `PracticalQualified` 同时要求：

1. 总体 `GeoMeanRatioIGDp<=0.98`；
2. 总体两层 bootstrap `CI95Upper<1`；
3. 至少一个 M 同时满足该 M ratio<=0.98 且该 M CI95Upper<1；
4. 每个 M 要么满足第 3 条，要么该 M CI95Upper<=1.05；
5. 每个 Family-M 点估计几何均值比都 <=1.05；
6. 至少 60% 的 Problem-M 单元 ratio<1；
7. 每个 Family-M 中 ratio>=1.20 的严重退化单元不超过 1。

随后还必须 `ArmHolmP<=0.05` 才是 Qualified。Stage 3 的 CURRENT_HCV 非劣锚使用与 Stage 2 相同的完整覆盖、逐 M CI、Family-M 点比、族总体比和 Family-M 严重退化规则。

### 9.2 FULL/REDUCED 和终点代码

主要贡献因素是 P、Q、C、D、E_GEN、E_FINAL、F、G、P_ERR_GATE。D_SIGNAL/F_SIGNAL 不能单独形成 factorGain。因素级汇总只包含 drop-one、negative-control 和 route-control 证据，排除 FULL、CONTROL、ANCHOR；G 只有两个 route arm 都存在且 Qualified 才进入 QualifiedFactors。

`SUPPORTED_FULL_MODULE` 要求：

- CURRENT_HCV 锚兼容；
- net Qualified；
- 至少一个主要因素 Qualified；
- 上游 Stage 2 为 `PASS_TO_STAGE3_FULL`；
- 12 个注册证据 arm 全部存在且全部 Qualified。

任一完整条件不满足，但锚、net 和至少一个主要因素仍通过，则为 `SUPPORTED_REDUCED_MODULE`。

### 9.3 运行

```matlab
run_CMCStage3('formal');
stage3 = analyze_CMCStage3('formal');
```

可分批 runner，但终局分析必须无 Arms：

```matlab
run_CMCStage3('formal','Problems',"DTLZ2",'Ms',10, ...
    'Runs',1,'Arms',"A00_FULL",'RunAnalysis',false);

% 全部正式任务完成后：
stage3 = analyze_CMCStage3('formal');
```

### 9.4 唯一 DecisionCode

| DecisionCode | 条件 |
|---|---|
| `SMOKE_PASS` | smoke 完整性通过；仍为终点 |
| `INSUFFICIENT_FORMAL_DATA` | IntegrityGate 不为 PASS |
| `FACTOR_HOST_NOT_NONINFERIOR_TO_CURRENT` | CURRENT_HCV 非劣锚失败 |
| `SUPPORTED_FULL_MODULE` | 锚、net、主要因素通过，上游 FULL，12 个证据 arm 全通过 |
| `SUPPORTED_REDUCED_MODULE` | 锚、net、至少一个主要因素通过，但不满足完整正式证据 |
| `PERFORMANCE_GAIN_WITHOUT_FACTOR_ATTRIBUTION` | net 通过，没有主要因素获得完整归因 |
| `FACTOR_EFFECT_WITHOUT_NET_PERFORMANCE_GAIN` | 至少一个主要因素通过，net 不通过 |
| `INCONCLUSIVE_FORMAL_EFFECT` | 无 net/因素支持，且 net CI 同时跨越 0.98 与 1.05 |
| `NO_CONFIRMED_ENDPOINT_ADVANTAGE` | 数据完整，但以上支持/不确定条件均不满足 |

Stage 3 是终点。无论代码为何，`CanProceed=false`、`NextStage` 为空；`PrimaryMetric=FINAL_IGDP`。

### 9.5 当前未实现的硬门

当前没有独立 Stage 3 reference preflight、ReferenceSensitivity、MechanismAssociation、FamilySummary、Completeness 或 FactorDecision CSV。`ArchiveEntryRate`、`MeanBatchGainPerFE`、`WastedFECount`、`FixedNicheCoverage` 当前为 NaN 保留列，不参与 IntegrityGate、ScientificDecision 或论文结论。

### 9.6 输出 CSV

```text
CMC_Stage3_JobStatus.csv
CMC_Stage3_Coverage.csv
CMC_Stage3_IntegrityGate.csv
CMC_Stage3_PerRunEndpoint.csv
CMC_Stage3_EndpointComparisons.csv
CMC_Stage3_ArmDecision.csv
CMC_Stage3_ScientificDecision.csv
```

## 10. 阶段推进总表

| 推进 | IntegrityGate | 允许的 ScientificDecision |
|---|---|---|
| Stage 0 -> Stage 1 | `PASS` | `PASS_TO_STAGE1`、`PASS_TO_STAGE1_REDUCED` |
| Stage 1 -> Stage 2 | `PASS` | `PASS_TO_STAGE2_POOL_ONLY`、`PASS_TO_STAGE2_REDUCED`、`PASS_TO_STAGE2_FULL` |
| Stage 2 -> Stage 3 | `PASS` | `PASS_TO_STAGE3_REDUCED`、`PASS_TO_STAGE3_FULL` |
| Stage 3 | `PASS` 才能形成完整终局解释 | 无下一阶段 |

smoke 只按 Stage 0 -> 1 -> 2 -> 3 的 smoke 链使用 `SMOKE_PASS`，不能授权 pilot、screening 或 formal。

## 11. 完整 CSV 契约

### 11.1 Runner manifest

动态文件名：`CMC_<stage>_<profile>_<时间>_pid<PID>.csv`。

```text
Stage,Profile,ProtocolHash,UpstreamDecisionHash,JobID,PairedKey,Arm,
Status,ResultFile,Message,IGD,IGDp,Runtime
```

### 11.2 通用分析 CSV

`CMC_StageN_JobStatus.csv`：

```text
Problem,Family,M,Run,Arm,Observed,Valid,ResultFile,Detail
```

`CMC_StageN_Coverage.csv`：

```text
Stage,Profile,Problem,Family,M,Arm,ExpectedRuns,ObservedRuns,
ValidRuns,MissingRuns,InvalidRuns,Complete
```

`CMC_StageN_IntegrityGate.csv`：

```text
ProtocolHash,Status,RequiredJobs,ValidJobs,MissingJobs,InvalidJobs,
SourceTwinStatus,AuditComplete,Reason,GeneratedAt
```

`CMC_StageN_ScientificDecision.csv`：

```text
SchemaVersion,Profile,Stage,DecisionCode,CanProceed,NextStage,
ProtocolHash,RequiredJobs,ValidJobs,MissingJobs,InvalidJobs,
ReferenceStatus,StatisticalUnit,PrimaryMetric,QualifiedFactors,
DroppedFactors,WarningFlags,Reason,GeneratedAt
```

Stage 0 `StatisticalUnit=RUN`；Stage 1--3 为 `RUN_NESTED_IN_PROBLEM_M`。Stage 2/3 的 QualifiedFactors/DroppedFactors 只聚合真实证据因素，排除 FULL/CONTROL/ANCHOR，G 要求两条 route arm 全部通过。

### 11.3 Stage 0 专用 CSV

`CMC_Stage0_SourceTwinEquivalence.csv`：

```text
Status,ProtocolHash,SameGenerationHistory,SameCompletedFE,SameFinalRNG,
MaxDecisionError,MaxObjectiveError,FirstMismatchFE,InitialDecisionError,
IGDError,IGDpError,Tolerance,SourceMainSHA256,SourceSelectionSHA256,
GeneratedAt
```

`CMC_Stage0_EventAudit.csv`：

```text
SchemaVersion,Profile,ProtocolHash,Problem,Family,M,Run,Seed,PairedKey,
Generation,FE,FERatio,StageBin,AttemptedMode,ActualMode,
IndicatorAvailable,OperationalIndicatorUsed,FallbackReason,
RequestedK,SelectedK,PostClipK,LastPoolCount,AccumRawCount,
AccumUniqueCount,RetainedCount,LambdaT,PErr,Factor,Eligible,Triggered,
DecisionChanged,OverlapAtK,SelectedFromNonFinalCount,
SelectedOriginMeanRound,DuplicateArchiveCount,NearDuplicateArchiveCount
```

`CMC_Stage0_FactorActivity.csv`：

```text
Factor,EligibleRuns,EligibleEvents,TriggeredEvents,ChangedEvents,
MedianRunTriggerRate,MedianRunChangeRate,MedianRunOverlapAtK,
DTLZEligibleRuns,WFGEligibleRuns,FactorStatus,CarryToStage1,Reason,
ProtocolHash
```

`CMC_Stage0_FactorDecision.csv`：

```text
Factor,FactorStatus,CarryToNextStage,Reason
```

### 11.4 Stage 1 专用 CSV

`CMC_Stage1_SnapshotUtility.csv`：

```text
SchemaVersion,Profile,ProtocolHash,Problem,Family,M,Run,Seed,PairedKey,
SnapshotID,Generation,FE,FERatio,StageBin,Rule,FactorContrast,K,
PoolDefinition,RetainedDefinition,SelectedIDsHash,ArchiveIGDpBefore,
ArchiveIGDpAfter,BatchGainIGDp,OracleGainIGDp,OracleEfficiency,
RandomMeanEfficiency,RandomP95Efficiency,RandomPercentile,
OracleRecallAtK,NondominatedRate,OfflineCandidateEvaluations,
CountedTowardFE,ReferenceSize,ReferenceHash,UtilityStatus
```

`CMC_Stage1_ReferenceSensitivity.csv`：

```text
SchemaVersion,Profile,ProtocolHash,Problem,Family,M,Run,Seed,PairedKey,
SnapshotID,Generation,FE,LowReferenceSize,HighReferenceSize,
UtilitySpearman,OracleTopKJaccard,Escalated,FinalReferenceSize,Stable,Status
```

`CMC_Stage1_PerRun.csv`：

```text
Factor,RuleA,RuleB,Problem,Family,M,Run,Seed,PairedKey,
ValidSnapshots,MeanDelta,MedianRandomPercentile
```

`CMC_Stage1_PairedComparisons.csv`：

```text
Factor,RuleA,RuleB,ValidRuns,ValidProblems,Complete,
MeanDeltaOracleEfficiency,MedianDelta,HodgesLehmann,
CI95Lower,CI95Upper,RawP,HolmP,RankBiserial,
PairedWinProbability,DirectMCID,PracticalPass,FactorDecision
```

`CMC_Stage1_FactorDecision.csv`：

```text
Factor,FactorDecision,CarryToNextStage,MeanDeltaOracleEfficiency,
CI95Lower,CI95Upper,CoveragePass,RandomPercentilePass,Contrast,ProtocolHash
```

### 11.5 Stage 2/3 端点 CSV

`CMC_StageN_PerRunEndpoint.csv`：

```text
SchemaVersion,Profile,ProtocolHash,UpstreamDecisionHash,
MATLABVersion,Computer,HostName,Problem,Family,M,RequestedD,ActualD,N,
MaxFE,Run,Seed,PairedKey,Arm,AlgorithmClass,EnabledFactors,CompletedFE,
IGD,IGDp,AnytimeIGDpAUC,WallTime,ArchiveEntryRate,MeanBatchGainPerFE,
WastedFECount,FixedNicheCoverage,Valid,ResultFile
```

`CMC_StageN_EndpointComparisons.csv`：

```text
ContrastID,Factor,Problem,Family,M,ArmA,ArmB,ExpectedPairs,ValidPairs,
Complete,MeanLogRatioIGDp,GeoMeanRatioIGDp,CILower,CIUpper,
MedianPairedDelta,HodgesLehmann,RawP,HolmP,RankBiserial,
PairedWinProbability,PassMCID,PassNonInferiority,SevereRegression,Decision
```

`CMC_StageN_ArmDecision.csv`：

```text
Arm,Factor,GeoMeanRatioIGDp,CI95Lower,CI95Upper,MaxMCI95Upper,
MaxFamilyMGeoMeanRatio,DTLZGeoMeanRatio,WFGGeoMeanRatio,
SevereRegressionCount,MaxFamilyMSevereRegressionCount,DirectionFraction,
ArmRawP,ArmHolmP,PracticalQualified,Qualified,CarryToNextStage,Cells,
ProtocolHash,Reason,IsFull
```

### 11.6 raw MAT 必需变量

每个合法结果至少包含：

```text
metadata,finalPopulation,IGD,IGDp,anytimeIGDpAUC,anytimeTrace,runtime,
activityRows,snapshotRows,referenceRows
```

metadata 必须匹配 Schema/Protocol/Stage/Profile/Problem/M/D/N/Run/Arm、三类 seed、JobID、PairedKey、完成 FE、上游指纹、端点保存合同和执行环境。任何不匹配的 raw MAT 都不得进入分析。

## 12. 结论许可边界

- Stage 0 通过：只能说因素 ACTIVE 并改变行为。
- Stage 1 通过：只能说同状态直接批效用或 deferred 活性获得闭环检验资格。
- Stage 2 通过：只能说获得正式验证资格，不得把 screening 写成正式优势。
- Stage 3 净模块和具体因素同时通过：只能支持当前冻结 HCV 宿主、环境、问题矩阵和预算中的条件贡献。
- net 通过但没有因素归因：只能支持候选包整体表现，不能定位因素。
- 因素通过但 net 不通过：不能声称获得净性能优势。
- D_SIGNAL/F_SIGNAL 可影响完整证据和 FULL/REDUCED，但不能单独形成主要 factorGain。
- 当前四个 NaN 机制字段不能支持信息效率、浪费 FE、进档率或 niche 覆盖结论。
- 本协议没有第三宿主、跨 host 或跨预算验证，不能自动支持可移植模块或普遍因果主效应。
