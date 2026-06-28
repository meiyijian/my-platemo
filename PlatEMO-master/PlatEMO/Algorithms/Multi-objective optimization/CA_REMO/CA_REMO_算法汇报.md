# CA_REMO 算法汇报

## 1. 算法名称

**CA_REMO: Confidence-Aware Relation Learning for Expensive Many-Objective Optimization**

中文名：**置信度感知关系学习的昂贵多/超多目标优化算法**

## 2. 研究动机

REMO 的核心思想是用关系模型代替目标值回归：不直接预测候选解的目标值，而是预测两个解之间的关系。这一思路比回归模型更贴合进化算法的选择本质。

但 REMO 仍有两个薄弱点：

1. **关系标签质量不稳定。** REMO 先用 PBI 把当前种群划为 good/bad，再由 good/bad 构造三分类关系对。靠近 PBI 分类边界的样本，其 good/bad 标签本身不稳定，会产生噪声关系对。
2. **模型使用缺少可靠性判断。** REMO 训练完关系模型后直接用于候选筛选，没有判断模型当前是否可靠。昂贵优化早期样本少、目标维度高，关系模型很容易误导搜索。

PCSAEA 能发表在 Swarm 的关键经验是：简单机制如果击中代理模型不可靠这个核心问题，并且有完整实验链条，就具备发表价值。`CA_REMO` 沿这个逻辑改进 REMO，但不照搬 PCSAEA 的 fitness top/bottom pair，而是从 REMO 自身的 PBI 几何边界中提取 label confidence。

## 3. 核心思想

`CA_REMO` 保留 REMO 的整体框架，只对关系学习链条做轻量增强：

1. **PBI-margin label confidence**
   - 用 `|1 - g_pbi(x)|` 衡量样本离 PBI 分类边界的距离。
   - 离边界越远，good/bad 标签越可信。

2. **Confidence-balanced relation pairs**
   - 只从 good/bad 两类中选择高置信样本构造关系对。
   - 关系对训练权重由两个样本置信度共同决定。

3. **Reliability-aware relation model management**
   - 用验证关系对判断模型是否可靠。
   - 模型可靠则正向使用。
   - 模型稳定预测反了则反向使用。
   - 模型无规律则弱化使用，避免错误代理误导昂贵评估。

## 4. 与 REMO 和 PCSAEA 的区别

| 维度 | REMO | PCSAEA | CA_REMO |
|---|---|---|---|
| 关系来源 | PBI good/bad 分类 | 综合 fitness 排序 | PBI good/bad + PBI-margin confidence |
| 样本选择 | 基本使用全部 good/bad 样本 | 最好 1/4 与最差 1/4 | 每类高置信样本 |
| 标签噪声处理 | 主要靠类别平衡 | 用 top/bottom 拉开边界 | 显式过滤低置信边界样本 |
| 模型可靠性 | 计算误差但不管理使用 | 正用/反用/忽略 | 正用/反用/弱化使用 |
| 搜索引导 | 关系投票分数 | pairwise score | 可靠性加权关系分数 + 多样性 fallback |
| 论文故事 | 提出关系模型 | pairwise comparison + reliability | confidence-aware relation learning |

## 5. 算法步骤

每一代：

1. 从当前种群中选择 `k` 个参考解。
2. 使用自适应 PBI 将种群划分为 good/bad 两类。
3. 对每个样本计算 PBI-margin confidence。
4. 分别从 good/bad 中选择高置信样本。
5. 构造三类关系对：
   - good-good / bad-bad：`0`
   - good-bad：`1`
   - bad-good：`-1`
6. 用关系对训练三分类 neural network。
7. 用验证关系对判断模型状态。
8. 在内层代理搜索中生成大量候选解。
9. 候选解与高置信 good/bad anchors 做关系比较，得到 relation score。
10. 根据模型可靠性调整 relation score，并加入轻量多样性奖励。
11. 选择少量候选解进行真实昂贵评估。
12. 从 Archive 中更新下一代种群。

## 6. 预期贡献点写法

投稿时建议将贡献写成三条：

1. **A PBI-margin based confidence estimation method** is proposed to quantify the reliability of relation labels generated from reference-guided population partition.
2. **A confidence-balanced relation pair construction strategy** is designed to reduce noisy boundary pairs and emphasize reliable pairwise comparisons.
3. **A reliability-aware relation model management strategy** is introduced to dynamically use, reverse, or weaken the relation model during surrogate-assisted candidate selection.

这三条贡献都能做独立消融，适合构成一篇简单但完整的算法论文。

## 7. 需要做的实验

### 7.1 Baseline 对比

建议至少比较：

| 类型 | 算法 |
|---|---|
| 原始关系模型 | REMO |
| pairwise comparison | PCSAEA |
| 分类代理 | CSEA, CPS-MOEA |
| 回归/GP 代理 | K-RVEA, MOEA/D-EGO, ParEGO |
| 强 many-objective expensive baseline | KTA2, EDN-ARMOEA 或其他当前可复现算法 |
| 普通 MOEA 参考 | NSGA-III 或 RVEA，可作为非昂贵优化参考 |

如果目标是一区论文，不能只和 REMO 比。必须证明该方法在关系模型、分类模型和回归模型三类 SAEA 中都有竞争力。

### 7.2 测试问题

基础测试：

1. DTLZ1-DTLZ7
2. WFG1-WFG9
3. MaF1-MaF5 或 MaF1-MaF15 中选择代表性问题

目标数建议：

`M = 5, 10, 15, 20`

如果只做 2/3 目标，很难支撑“many-objective”定位。

决策变量维度：

- 默认：DTLZ `D = M + 9` 或按 PlatEMO 默认。
- 中维测试：`D = 30, 50`，因为 REMO 原文在中维上有优势，这里可以继续放大关系学习的价值。

真实问题：

1. CSI：13-objective car side impact
2. WRM：12-objective water resource management
3. GAA：11-objective general aviation aircraft

这些真实问题与 PCSAEA 设置接近，有利于构造对照叙事。

### 7.3 指标

Benchmark：

- IGD
- HV
- 若 Pareto front 可采样，IGD 作为主指标，HV 作为补充。

真实问题：

- HV 为主。
- 非支配解数量和分布图作为辅助。

统计检验：

- 30 independent runs。
- Wilcoxon rank-sum test，显著性水平 0.05。
- Friedman test + Holm correction 或 critical difference plot，用于多算法整体排名。

### 7.4 消融实验

必须做以下消融：

| 变体 | 去掉内容 | 验证目标 |
|---|---|---|
| `CA_REMO_noConf` | 不按 PBI confidence 过滤，使用全部样本 | 证明边界置信度有效 |
| `CA_REMO_noWeight` | 训练不使用样本权重 | 证明置信度权重有效 |
| `CA_REMO_noReliability` | 模型始终正向使用 | 证明可靠性管理有效 |
| `CA_REMO_noReverse` | 只允许正用/不用，不允许反向使用 | 检验反向使用是否必要 |
| `CA_REMO_noDiv` | 去掉多样性 fallback | 证明弱模型阶段仍需探索 |
| `CA_REMO_allPairs` | 退回 REMO 式全样本关系对 | 证明高置信 relation pairs 更优 |

### 7.5 模型层证据

不能只给最终 IGD/HV。要补充代理模型本身证据：

1. 关系模型 accuracy / F1。
2. 高置信样本 vs 低置信边界样本的预测准确率。
3. 每代模型 `mode=1/-1/0` 的比例变化。
4. 被选中候选解真实评估后的质量排名。
5. PBI margin 与真实关系标签正确率的相关性。

这些图表能证明方法不是单纯调参，而是确实降低了关系标签噪声。

### 7.6 参数敏感性

至少测试：

1. `confRatio = 0.25, 0.35, 0.50, 1.00`
2. `delta = 0.55, 0.65, 0.75, 0.85`
3. `divWeight = 0, 0.02, 0.05, 0.10`
4. `k = 4, 6, 8, 10`

预期结果不是每个参数都最优，而是默认参数在多数问题上稳定，不应出现强烈依赖单一参数的情况。

## 8. 达到什么效果才有一区发表潜力

以下是务实门槛。达不到这些，不建议直接冲一区。

### 8.1 总体性能门槛

在 DTLZ/WFG/MaF 的 `M = 5, 10, 15, 20` 设置上：

1. 相比 REMO，至少在 **60%-70% 实例** 上显著更优，显著更差实例最好低于 15%。
2. 相比 PCSAEA，至少在 **50%-60% 实例** 上显著更优或持平，其中在 10/15/20 目标上要有明显优势。
3. 与所有 baseline 比，平均排名应进入前 2。
4. 至少在 WFG 或 MaF 这类复杂 PF/变量关联问题上表现出稳定优势，否则贡献会被认为只适配 DTLZ。

### 8.2 消融门槛

完整 `CA_REMO` 应显著优于关键消融：

1. 优于 `noConf`：证明 confidence 不是装饰。
2. 优于 `noReliability`：证明模型管理是必要的。
3. 优于 `allPairs`：证明不是简单减少训练样本，而是提高标签质量。

建议门槛：

- 在 WFG/MaF 上，完整算法相对主要消融至少 **60% 实例显著更优**。
- 消融曲线中完整算法应更快收敛，不能只是最后几个 FE 偶然赢。

### 8.3 模型证据门槛

应能证明：

1. 高置信关系对的验证 accuracy/F1 比全样本关系对高 **5%-10%**。
2. 低 margin 样本确实更容易产生错误关系标签。
3. `mode=0` 阶段主要出现在早期或困难问题上，后期可靠模型比例上升。
4. 可靠性门控后，被真实评估的候选解在真实目标上更常进入当前种群前 25%-40%。

如果模型层证据不成立，论文故事会变弱。

### 8.4 真实问题门槛

在 CSI/WRM/GAA 等真实问题上：

1. HV 至少在 2/3 问题上达到最好或统计持平最好。
2. 不能明显输给 REMO 和 PCSAEA。
3. 若某个真实问题失败，需要给出合理解释，例如目标结构导致 PBI confidence 不适配，并通过补充分析支撑。

### 8.5 计算成本门槛

`CA_REMO` 的运行时间应与 REMO 同量级，不能因为 confidence 机制显著增加训练成本。

建议：

- CPU 时间不超过 REMO 的 1.3 倍。
- 训练样本数低于或接近 REMO 全样本关系对。
- 在高目标数下时间增长应比回归类代理更稳定。

## 9. 论文题目建议

可选题目：

1. Confidence-Aware Relation Learning for Expensive Many-Objective Optimization
2. Reliable Relation Learning with PBI-Margin Confidence for Expensive Many-Objective Optimization
3. Confidence-Balanced Pairwise Relation Modeling for Surrogate-Assisted Many-Objective Optimization

最推荐第 1 个，简洁，和方法核心一致。

## 10. 摘要写作骨架

昂贵多/超多目标优化中，关系模型避免了直接回归复杂目标值，但现有关系学习方法通常假设由种群划分得到的关系标签可靠，并在训练后直接使用代理模型。这在样本稀缺和高维目标空间中容易引入噪声标签和误导性候选选择。本文提出 CA_REMO，一种置信度感知关系学习算法。首先，基于样本到 PBI 分类边界的 margin 估计关系标签置信度；其次，构造置信度平衡的关系对并使用样本权重训练三分类关系模型；最后，基于验证关系对动态决定模型正向使用、反向使用或弱化使用。实验应证明 CA_REMO 在 benchmark 和真实昂贵 many-objective 问题上优于现有回归、分类和关系模型辅助算法。

## 11. 当前实现状态

已创建 PlatEMO 格式源码：

- `CA_REMO.m`
- `CAPBIConfidence.m`
- `CARelationPairs.m`
- `CADataProcess.m`
- `CAOneHot.m`
- `CAReliability.m`
- `CASurrogateSelection.m`
- `CARefSelect.m`

当前实现是研究原型，下一步应在 MATLAB 中先跑小预算 sanity test，再做大规模实验。

