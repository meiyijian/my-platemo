# 候选解模块价值探针（Candidate-Value Probe, CVP）

测量**候选解选择模块**是否真的把有限的昂贵评价花在了更有价值的候选上。

两个指标：

| 指标 | 回答的问题 |
|---|---|
| **Candidate Survival Rate (CSR)** | 我花 FE 评价的候选，有多少真的被环境选择留下？ |
| **Oracle batch overlap (Hit)** | 在同一个候选池里，我选的这一批和"真值下最优的一批"重合多少？ |

五个变体构成单因子阶梯：框架、HPC 标签、`k_eff`、内层 GA、指标模型训练、环境选择**全部相同**，唯一变化是最终选择规则。

---

## 一、快速开始

```matlab
cd D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_CandidateValueProbe

% 1. 冒烟测试（~30 秒，验证五臂都能跑通）
run_CandidateValueProbe('smoke');
analyze_CandidateValueProbe('smoke');

% 2. 正式实验（见下方"运行时间"，强烈建议分片跑）
run_CandidateValueProbe('formal');
analyze_CandidateValueProbe('formal');
```

CSV 输出在 `results/formal/csv/`。

**中断安全**：每个 job 独立成文件，写入走临时文件 + 写后校验 + 原子改名。重跑会自动跳过已完成的 job，所以可以随时 Ctrl-C 然后接着跑。

> 本文档讲**怎么跑、怎么读结果**。每个设计选择**为什么**这么定（含对应源码行号、与出厂算法的差异、刻意做的近似），见 [docs/实验设计说明.md](docs/实验设计说明.md)。写论文的方法学章节时以那份为准。

---

## 二、五个变体

| 变体 | 候选池 | 最终选择 | 隔离的因子 |
|---|---|---|---|
| **V0_REMO_RULE** | 最后一代（~2k） | `score>3.9` 否则 top-4 | 原文选择规则（池化 + 阈值） |
| **V1_POOL_ONLY** | 累积（~3000） | relation top-6 | **池化效应** |
| **V2_EXPLORE_ONLY** | 累积 | + 模糊度 + qKeep + 分散贪心 | 探索机制 |
| **V3_INDICATOR_ONLY** | 累积 | + 关系粗筛 30% + SVR 重排 | 指标重排序 |
| **V4_FULL** | 累积 | 每代按 pMix=0.5 抽签 | 完整算法 |

代码在 [CVPCandidateSelection.m](algorithms/private/CVPCandidateSelection.m)，臂定义在 [CVPArmCatalog.m](CVPArmCatalog.m)。

### V1 为什么是主对照

原版 REMO 的内循环**不累积候选**（`Next` 每轮被整体覆盖），k=6 时最终打分池只有 ~12 个；而 `AdaMaOSelection` 用 `all_candidates` 累积，M=10 时约 **2990 个**。约 250 倍差距。

**"从 3000 个里挑 6 个"本身就可能带来大部分增益，与任何打分创新无关。** V1 就是把这个因素单独隔离出来：它用和 V2/V3/V4 完全相同的累积池，只是最终按 relation 分数取 top-6。

所以：

- `V4 > V1` 才是"打分机制有效"的证据；
- `V4 ≈ V1` 说明真正的贡献是"累积候选池"这个结构性改动 —— 那也能写，但叙述要换，不能讲成模糊度和指标重排序。

### V0 不是原版 REMO

V0 保留宿主的 HPC 标签和 `k_eff`，只换选择规则。它的作用是在**标签层固定**的前提下隔离"池化 + 3.9 阈值"。真正的原版 REMO 基线是你已有的两模块消融表。

V0 的批量是 4~12 浮动（诊断表里 `v0_batch_mean` 会报告实测值），所以**V0 的对比天然被批量混杂**。这一点写在 `diagnostics.csv` 里，不要在论文里把 V0 当作干净对照。

---

## 三、两个指标的实现与陷阱

### 3.1 Candidate Survival Rate

定义：

```
CSR_t = |S_t ∩ P_{t+1}| / |S_t|
```

`S_t` 是本代真实评价的批次，`P_{t+1} = RefSelect(Archive, N)`。

**用对象身份判定，不用数值比较。** `SOLUTION` 是 handle 类，所以直接 `any(Population == NewSols(i))` 比较句柄。数值比较在重复解上会误判。

**必须处理的混杂：`|Archive|/N` 随世代增长。**

`Problem.N = 100`，`Archive` 初始就是 100，maxFE=300 时最大 300。所以：

- 第 1 代 `|Archive|/N ≈ 1`，几乎全员存活，CSR≈1 **与选择器无关**；
- 比值只走到 3.0，选择压力全程都不大。

因此 CSR 报三个口径：

| 字段 | 含义 | 用途 |
|---|---|---|
| `SurvivalRateAll` | 全程平均 | 仅完整性，**不要单独报这个** |
| `SurvivalRateLate` | `FE/maxFE ≥ 0.5` 的平均 | **主口径** |
| `SurvivalRateStage1..4` | 按 FE 四分位 | 把混杂**显示出来**而不是辩解 |

`stage_profile.csv` 就是这张分段表。审稿人问"CSR 是不是被世代污染了"，直接给这张表。

### 3.2 Oracle batch overlap

**FE 中立**：真值由 `Problem.CalObj(Problem.CalDec(dec))` 算。只有 `Problem.Evaluation` 会累加 `Problem.FE`（[PROBLEM.m:157](../../Problems/PROBLEM.m#L157)），所以这条路径完全离预算。这些值**从不返回给优化器**，单测 `testFEBudgetRespected` 守这条。

**用贪心批 oracle，不用单点排序。** 探索分支优化的是**批次边际**：两个都很好但彼此重合的解只值一个名额。按个体增益排 top-20% 会给两个都记 hit，**系统性低估反冗余机制** —— 这正是要避免的失效模式。所以 oracle 是：

```
x1 = argmin_x C(A ∪ {x})
x2 = argmin_x C(A ∪ {x1, x})
...
```

和算法批次规则同一个目标。

**覆盖度目标 C 与 IGD 的区别（重要）。** `C(S)` = 参考点到 `S` 中**最近成员**的平均距离，用**全集**而非非支配子集。PlatEMO 的 IGD 限制在 `Population.best` 上。这个差异是刻意的：

- 全集覆盖度加点后**单调不增**，贪心 oracle 定义良好，每次试算只要一个距离向量；
- 前沿限制的 IGD **不单调**（新点可能支配掉存档成员），"最优批次"无定义，且每次试算都要 NDSort。

**论文的 IGD 主表仍然用 PlatEMO 的 IGD。** C 只在这个诊断内部用，且五臂完全一致。

**两处子采样，都记录、都跨臂一致：**

| 子采样 | 默认 | 说明 |
|---|---|---|
| 参考集 | 300 | 定步长抽取，保持铺满前沿；只依赖 (problem, size)，与臂和 run 无关 |
| 候选池 | 400 | **强制包含算法实际选中的全部候选**，所以重合度对算法选择是精确的 |

池子采样用独立 RandStream（按 `(run, M)` 播种），**与全局流无关**，所以开关 oracle 不会扰动优化轨迹。读 `HitRate` 必须对照 `oracle_pool_considered_mean`。

`OracleGainRatio = AlgorithmGain / OracleGain` 是 regret 式的相对量，比裸 HitRate 更稳。

---

## 四、被刻意冻结的一处，以及它的代价

内层 GA 的父代打分对**所有臂**都固定用简单平均。而出厂算法在 explore 模式下用置信度加权平均（[AdaMaOSelection.m:337-349](../../Algorithms/Multi-objective%20optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/private/AdaMaOSelection.m#L337-L349)）。

不冻结的话，V2/V4 相对 V1 会同时改两件事：(a) 模糊度 + 分散，(b) **候选池本身的生成过程**。那样"探索有效"就指向不明。

代价被量化而非隐藏：`aggregation_changed_fraction` 报告"如果不冻结，父代集合会变的轮次比例"（冒烟实测 8.8%）。写论文时应正面报告这个数字。

> 另外注意：出厂 explore 分支的**最终**打分也用加权平均，这一点探针**保留**了（`FinalAggregationWeighted` 字段记录）。冻结只作用于内层父代选择。

---

## 五、运行时间与建议的分片方式

实测（本机 R2023a，`formal` 单 job，maxFE=300，34 代）：

| 配置 | 单 job 耗时 |
|---|---|
| DTLZ2 M=10, D=30 | **343 s** |
| 同上但关掉 oracle | ~305 s |
| WFG3 M=20, D=31 | **207 s** |

两点需要注意：

**oracle 只占 ~13%**（343 → 305 s）。大头是关系网络对 ~3000 个候选打分（每个候选要过 `2×(N_C1+N_C2)` 个样本对）。所以砍 oracle 省不了多少，不要为此牺牲指标。

**M=20 比 M=10 快，不是慢。** 反直觉但可复现：两者候选池规模几乎相同（3024 vs 3010，都被 `gmax=3000` 截断），但 M=20 的 `k_eff = ceil(1.5×20) = 30` 使每轮内循环产出 60 个而非 30 个，于是达到 `gmax` 所需的轮数减半 —— 而每轮的固定开销（GA 算子、`model_select` 调用）是按轮计的。所以 M 增大不会线性放大成本。

`formal` = 4 problems × 2 M × 10 runs × 5 arms = **400 jobs**。按上面两个测点外推（200 个 M=10 job × 343 s + 200 个 M=20 job × 207 s）≈ **31 小时**。

> 这个估算只基于 8 个 (problem, M) 组合里的 2 个，问题族之间的差异未测（WFG 的 `CalObj` 比 DTLZ 重）。当成量级参考，不要当成排期承诺。

建议分片，每片可独立中断续跑：

```matlab
% 按问题分片（推荐，4 片，每片 ~8 h）
run_CandidateValueProbe('formal', 'Problems', 'DTLZ2');
run_CandidateValueProbe('formal', 'Problems', 'DTLZ7');
run_CandidateValueProbe('formal', 'Problems', 'WFG3');
run_CandidateValueProbe('formal', 'Problems', 'WFG7');

% 或先跑 M=20 全部（~12 h，比 M=10 便宜），出初步结论后再补 M=10
run_CandidateValueProbe('formal', 'Ms', 20);

% 或先跑 5 个 run 看趋势，够显著再补到 10
run_CandidateValueProbe('formal', 'Runs', 1:5);
```

**先跑哪一片**：`Problems','DTLZ2','Ms',10` 最有信息量 —— 如果 V4 和 V1 在这里就没差别，先别跑完 400 个 job，直接改叙述。

若要降到 10 runs 以下，注意配对 Wilcoxon 在 n<6 时几乎不可能显著；此时看 `MeanDifference` 和 `EffectSize`（Cliff's delta）的方向一致性，不要报 p 值。

---

## 六、输出的 7 张 CSV

`results/<profile>/csv/`：

| 文件 | 内容 |
|---|---|
| `runs.csv` | 每 (臂, 问题, M, run) 一行：两个指标 + 最终 IGD + 全部描述字段 |
| `arm_summary.csv` | 每 (臂, 问题, M) 的 mean / std / median |
| `arm_overall.csv` | 每臂跨问题汇总 |
| `stage_profile.csv` | **按 FE 四分位的 CSR**，用来展示世代混杂 |
| `generations.csv` | 逐代完整轨迹，画图用 |
| `contrasts.csv` | 配对 Wilcoxon（vs V1 和 vs V0）+ Holm 校正 |
| `diagnostics.csv` | **完整性检查，先读这张** |

### diagnostics.csv 必须先看的几行

| 检查项 | 期望 | 不满足意味着 |
|---|---|---|
| `missing_runs` | 0 | 非 0 则结论是**部分**的 |
| `arms_balanced` | 1 | 0 则跨臂汇总不可比 |
| `fe_budget_overruns` | 0 | 非 0 则 oracle 泄漏了预算，**结果作废** |
| `batch_constant_non_v0` | 1 | 确认 V1~V4 批量恒定，批量不是它们之间的混杂 |
| `batch_truncated_generations` | 每 run ≤1 | 末代按剩余预算裁剪，已从上一行的恒定性判定中剔除；大于 run 数说明有异常提前收尾 |
| `v3_indicator_operational_fraction` | 接近 1 | 低于 1 则 V3 部分退化成 relation top-K |
| `oracle_subsampled_fraction` | 记录用 | 为 1 时 HitRate 必须对照 `oracle_pool_considered_mean` 解读 |
| `aggregation_changed_fraction` | 记录用 | 冻结内层打分的代价 |

### 配对检验的合法性

`CVPStableSeed(problemIndex, M, run)` **不含臂编号**，所以同一 `PairedKey` 的五个臂共享初始种群和全局随机流 —— 天然的 common random numbers，配对检验的统计效力显著高于独立运行。

`ResolveUniformMixMode` 的抽签走**独立 RandStream**（按 run 播种），这也是个可以主动写进论文的方法学加分项。

---

## 七、结论怎么读

因果链：

```
候选选择策略 → 候选质量 → FE 效率 → 最终 IGD
```

| 观测 | 解读 |
|---|---|
| `V4 > V1` 且 CSR/Hit 同向 | 因果链成立，候选模块可作主贡献 |
| `V4 ≈ V1`，两者都 `> V0` | 真正贡献是**累积候选池**。可以写，但必须换叙述 |
| IGD 有增益但 CSR/Hit 无差别 | 增益不来自"候选更值钱"，另找机制，别硬讲 |
| V2 有效 V3 无效（或反之） | 单分支贡献，考虑把 pMix 从 0.5 挪开或砍掉弱分支 |

**WFG3 是刻意保留的可falsify案例**：它在此前所有对照中稳定退化。如果候选模块在 WFG3 上也退化，说明退化不只是 HPC 的问题；如果不退化，就支持"WFG3 的退化归因于 HPC 的范数排序切前沿"，这对把候选模块升为贡献 1 是有用的辩护材料。

---

## 八、术语护栏

写论文时这几处不能说错：

| 不要写 | 要写 | 依据 |
|---|---|---|
| epistemic uncertainty / 置信度 | **prediction ambiguity**（softmax 预测模糊度） | 实现是 `1 - mean(max softmax)`，未校准 |
| 自适应/分阶段选择分支 | **mixed dual-mode**（固定 pMix 均匀混合） | `ResolveUniformMixMode` 每代固定概率抽签；真正随阶段变的是 `λ_t` |
| 指标是独立信息源 | **a different surrogate target** | SDE 标签来自当代 `Population.objs`，同源数据不同监督目标 |
| 保证目标空间/PF 多样性 | **决策空间冗余** | `diversity_select` 用决策变量欧氏距离 |

另外，`BatchSpreadNormalized` 只是 **sanity check**：acquisition 里显式加了 `0.25×distance`，测出批内距离变大近乎恒真。它证明"开关接通了"，**不证明"开关有用"**。

---

## 九、代码地图

```
CVPArmCatalog.m            五臂定义（单一事实来源）
CVPProtocol.m              问题矩阵、参数、job 枚举
CVPStableSeed.m            跨臂共享的种子
CVPSetupPaths.m            路径 + 冻结孪生校验
CVPResultPath.m            每 job 唯一路径
CVPValidateRunFile.m       写后校验
CVPSummarizeRun.m          单 run → 标量指标（含三口径 CSR）
run_CandidateValueProbe.m  可续跑 runner
analyze_CandidateValueProbe.m  聚合 + 7 张 CSV + 配对检验
algorithms/
  CVP_CandidateProbe.m     宿主算法（五臂共用）
  private/
    CVPCandidateSelection.m  五条选择规则
    CVPRelationScores.m      一次前向传播出两种聚合 + 模糊度
    CVPOracleBatch.m         离预算贪心批 oracle
    ...                      冻结拷贝（HPC/RefSelect/SDE/...）
tests/
  test_CandidateValueProbe.m  14 个单测，全部通过
```

### 关于 `private/` 里的冻结拷贝

仓库里有 **30+ 份同名** REMO 辅助函数（`RefSelect` 37 份、`GetOutput_PBI` 32 份…），而 `platemo.m` 用 `addpath(genpath(cd))`，全会话只有一份胜出。探针把自己的拷贝放进 `algorithms/private/`，MATLAB 从 `algorithms/` 调用时优先解析私有目录，绕开遮蔽。

`CVPSetupPaths` 会**逐字节校验**这些拷贝与出厂算法一致，不一致直接报 `CVP:FrozenTwinMismatch`。主算法改了以后重跑会立刻失败而不是静默漂移 —— 此时重新拷贝再跑。

---

## 十、自测

```matlab
addpath(genpath('D:\PlatEMO-master\PlatEMO-master')); addpath('tests');
runtests('tests/test_CandidateValueProbe.m')
```

14 个测试覆盖：臂路由、种子配对、CSR 的句柄身份判定、**oracle 的 FE 中立性**、幂等续跑、CSV 契约、Holm 单调性。
