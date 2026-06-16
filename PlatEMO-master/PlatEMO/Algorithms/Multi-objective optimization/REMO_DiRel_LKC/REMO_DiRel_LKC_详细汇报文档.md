# REMO_DiRel_LKC 算法详细汇报文档

> **算法全称**：REMO with Dual Relation Networks — Liu-K-means-Clustering Structure-Aware Variant
> **适用场景**：昂贵（Expensive）多目标 / 超多目标优化
> **框架依赖**：PlatEMO + MATLAB Neural Network Toolbox (`patternnet`)
> **作者/归属**：基于 REMO_DiRel 扩展，LKC 结构分组模块参考 Liu et al. (2026)

---

## 目录

1. [算法概述与研究背景](#1-算法概述与研究背景)
2. [整体架构与数据流](#2-整体架构与数据流)
3. [模块一：主流程控制器 REMO_DiRel_LKC.m](#3-模块一主流程控制器-remo_direl_lkcm)
4. [模块二：LKC 结构感知目标分组 BuildObjectiveStructure_LKC.m](#4-模块二lkc-结构感知目标分组-buildobjectivestructure_lkcm)
5. [模块三：目标聚合工具 AggregateObjectives_LKC.m](#5-模块三目标聚合工具-aggregateobjectives_lkcm)
6. [模块四：结构感知易目标选择 BuildStructureAwareEasySet.m](#6-模块四结构感知易目标选择-buildstructureawareeasysetm)
7. [模块五：目标难度估计 DifficultyProfiler.m](#7-模块五目标难度估计-difficultyprofilerm)
8. [模块六：冲突度计算 ConflictDegree.m](#8-模块六冲突度计算-conflictdegreem)
9. [模块七：冗余修正 RefineEasySubset.m](#9-模块七冗余修正-refineeasysubsetm)
10. [模块八：Pareto-first 关系对标签 GetRelationPairsBudgeted_LKC.m](#10-模块八pareto-first-关系对标签-getrelationpairsbudgeted_lkcm)
11. [模块九：双尺度集成网络训练 TrainDualScaleNet.m](#11-模块九双尺度集成网络训练-traindualscalenetm)
12. [模块十：权重迁移 TransferFineTune.m](#12-模块十权重迁移-transferfinetunem)
13. [模块十一：全目标优先仲裁评分 ArbitratorScore_LKC.m](#13-模块十一全目标优先仲裁评分-arbitratorscore_lkcm)
14. [模块十二：GA 候选生成与选择 ArbitratedSelection_LKC.m](#14-模块十二ga-候选生成与选择-arbitratedselection_lkcm)
15. [参数汇总与调参建议](#15-参数汇总与调参建议)
16. [优缺点综合分析](#16-优缺点综合分析)
17. [适用场景与推荐](#17-适用场景与推荐)
18. [消融实验建议](#18-消融实验建议)
19. [后续改进方向](#19-后续改进方向)

---

## 1. 算法概述与研究背景

### 1.1 问题背景

在昂贵多目标优化中，每个候选解的真实评估代价极高（例如一次 CFD 仿真需要数小时），因此算法必须在极有限的真实评估预算内（通常几十到几百次）找到高质量的 Pareto 前沿近似。

随着目标数 M 增加（M ≥ 5，即"超多目标"场景），传统进化算法面临两大挑战：

1. **目标维度诅咒**：Pareto 支配关系在高维空间中退化，几乎所有解都互不支配，选择压力消失。
2. **代理建模困难**：高维目标空间使得关系学习（哪个解更好）变得极其困难，单个代理模型难以覆盖所有目标维度。

### 1.2 REMO_DiRel 的核心思路

原始 REMO_DiRel 通过 **双关系网络** 缓解上述问题：

- **全目标关系网络 (Full-Net)**：在完整 M 维目标空间上学习解之间的优劣关系。
- **易目标子网络 (Sub-Net)**：在难度较低的目标子集上学习关系，作为补充信号。
- **仲裁融合**：通过逆方差加权融合两个网络的预测。

这种设计的直觉是：全目标网络提供全局视角，子网络在全目标网络不确定时提供补充信息。

### 1.3 LKC 变体的改进动机

原始 REMO_DiRel 的子网络直接在"原始易目标列"上训练，存在以下问题：

1. **冗余问题**：多个容易目标可能表达相同趋势，信息冗余。
2. **语义不一致**：容易目标之间可能存在结构冲突，混在一起训练会降低标签质量。
3. **缺乏结构感知**：没有显式考虑目标之间的相似性、冗余性和冲突性。

**REMO_DiRel_LKC** 的核心改进是：将"易目标子集"从原始目标列升级为**结构感知的聚合目标组**，使子网络学习更可靠、更低维的目标结构。

### 1.4 一句话总结

> REMO_DiRel_LKC = REMO_DiRel 主循环 + LKC 结构感知目标分组 + 组级易目标选择 + Pareto-first 关系标签 + 全目标优先仲裁

---

## 2. 整体架构与数据流

### 2.1 算法主循环（每代执行）

```
┌─────────────────────────────────────────────────────────────────┐
│                    REMO_DiRel_LKC 每代流程                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ① 参考解选择 ──→ RefSelect(Population, k)                      │
│       │                                                         │
│       ▼                                                         │
│  ② LKC 结构分组 ──→ BuildObjectiveStructure_LKC                 │
│       │            (Gamma矩阵 → 相似度 → K-means → 修复 → 聚合)  │
│       ▼                                                         │
│  ③ 结构感知易目标选择 ──→ BuildStructureAwareEasySet              │
│       │                (原始难度 → 组级难度 → 可靠性过滤 → 选组)   │
│       ▼                                                         │
│  ④ 全目标关系对 ──→ GetRelationPairsBudgeted_LKC(PopObj)         │
│       │                                                         │
│  ⑤ 易聚合关系对 ──→ GetRelationPairsBudgeted_LKC(EasyAggObj)    │
│       │                                                         │
│       ▼                                                         │
│  ⑥ 双网络训练 ──→ TrainDualScaleNet(nets_F, nets_S)             │
│       │                                                         │
│       ▼                                                         │
│  ⑦ 仲裁选择 ──→ ArbitratedSelection_LKC                         │
│       │        (GA生成 → 评分 → 筛选 → 迭代)                     │
│       ▼                                                         │
│  ⑧ 真实评估 + 更新 archive & population                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 数据流图

```
Population.decs (决策变量)          Population.objs (目标值)
       │                                    │
       │    ┌───────────────────────────────┘
       │    │
       ▼    ▼
  ┌──────────────────────┐
  │ BuildObjective        │
  │ Structure_LKC         │──→ StructState
  │  · Gamma矩阵          │    · Groups
  │  · 相似度Sim           │    · AggregatedObj
  │  · K-means聚类         │    · GroupReliability
  │  · 组修复              │    · GroupWeights
  └──────────────────────┘
              │
              ▼
  ┌──────────────────────┐     ┌──────────────────────┐
  │ DifficultyProfiler    │────→│ BuildStructureAware   │
  │  · 建模难度            │     │ EasySet               │
  │  · 冲突难度            │     │  · 组级难度            │
  │  · 滑动窗口平滑        │     │  · 可靠性过滤          │
  └──────────────────────┘     │  · 易组选择            │
                                └──────────────────────┘
              │                            │
              ▼                            ▼
  ┌──────────────────────┐     ┌──────────────────────┐
  │ GetRelationPairs      │     │ GetRelationPairs      │
  │ Budgeted_LKC          │     │ Budgeted_LKC          │
  │ (全目标空间)           │     │ (易聚合空间)           │
  │  · Pareto支配标签      │     │  · Pareto支配标签      │
  │  · 均值差弱偏好        │     │  · 均值差弱偏好        │
  └──────────────────────┘     └──────────────────────┘
              │                            │
              ▼                            ▼
  ┌──────────────────────────────────────────────────┐
  │              TrainDualScaleNet                     │
  │  · nets_F (全目标关系网络, 60 epochs)              │
  │  · nets_S (易聚合子网络, 30 epochs, 迁移初始化)    │
  │  · Bagging集成 (K_ens=3个网络, 70%采样)           │
  └──────────────────────────────────────────────────┘
                          │
                          ▼
  ┌──────────────────────────────────────────────────┐
  │           ArbitratedSelection_LKC                  │
  │  · GA迭代生成候选解                                │
  │  · ArbitratorScore_LKC 评分:                      │
  │    - 全目标网络主判断                              │
  │    - 子网络仅在全目标不确定时 tie-break             │
  │  · 阈值筛选 → 输出最终候选解                       │
  └──────────────────────────────────────────────────┘
```

---

## 3. 模块一：主流程控制器 REMO_DiRel_LKC.m

### 3.1 模块职责

主流程控制器，继承自 PlatEMO 的 `ALGORITHM` 类，负责：
- 参数解析与初始化
- 每代优化循环的编排
- 辅助函数（参考目标生成、诊断打包、候选清理等）

### 3.2 设计动机

作为"指挥中心"，主流程需要协调 12 个子模块的调用顺序和数据传递。LKC 版本在原始 DiRel 的 8 步流程基础上扩展为 11 步，新增了结构分组、组级易目标选择和诊断输出。

### 3.3 关键参数

| 参数 | 默认值 | 含义 |
|------|--------|------|
| `k_easy_user` | -1 | 易目标数量，-1 表示自动计算 `max(2, min(M-1, ceil(M/2)))` |
| `tau_conf` | 0.3 | 网络不确定性阈值 |
| `alpha` | 0.6 | 建模难度 vs 冲突难度的权重 |
| `k` | 6 | 参考解数量 |
| `gmax` | 1000 | 每代最大 GA 迭代次数 |
| `K_ens` | 3 | 集成网络数量 |
| `win_K` | 3 | 难度平滑滑动窗口大小 |
| `nCells` | 5 | LMVT 斜率估计的 cell 数 |
| `minRel` | 0.65 | 目标组最低可靠性阈值 |
| `scalarGap` | 0.05 | 非支配样本转偏好标签的均值差阈值 |

### 3.4 初始化策略

- **种群大小**：D ≤ 10 时 N = 11D - 1，否则 N = 100
- **初始采样**：拉丁超立方采样 (`UniformPoint(N, D, 'Latin')`)
- **初始评估**：对所有初始解进行真实函数评估

### 3.5 辅助函数

| 函数 | 作用 |
|------|------|
| `makeReferenceObjectives` | 在聚合目标空间中生成 ILD 均匀参考点，缩放到种群目标范围 |
| `makeDiagnostic` | 打包难度分数、分组信息、仲裁统计到 `lkcDiag` 诊断结构体 |
| `fallbackOffspring` | 神经网络失败时的标准 GA 离线生成 |
| `sanitizeCandidates` | 边界裁剪、去重、去已评估解、按预算截断 |
| `randomFill` | 拉丁超立方随机填充（最后手段） |

### 3.6 诊断输出

每代写入 `Algorithm.metric.lkcDiag{gen, 1}`，包含：
- 目标分组 `Groups` 和可靠性 `GroupReliability`
- 组级难度 `groupDifficulty` 和选中的易组 `easyGroups`
- 仲裁统计：`fullUncertainRatio`, `subTriggeredRatio`, `disagreementRatio`

---

## 4. 模块二：LKC 结构感知目标分组 BuildObjectiveStructure_LKC.m

### 4.1 模块职责

**这是 LKC 变体的核心创新模块。** 从已评估样本中估计目标间的局部结构相似性，将正相关目标聚合成组，并生成聚合目标值。

### 4.2 设计动机

在多/超多目标优化中，目标之间并非独立存在，而是存在以下结构关系：

- **正相关**：目标 A 增大时目标 B 也倾向增大（例如两个性能指标）
- **负相关**：目标 A 增大时目标 B 倾向减小（例如精度 vs 效率）
- **冗余**：多个目标表达几乎相同的信息
- **冲突**：目标之间存在根本性矛盾

原始 DiRel 只按单目标难度选择子集，忽略这些结构关系。LKC 的动机是：

> "目标选择"应升级为"结构选择"——把正相关且可靠的目标合成组，把负相关的目标分开，让子网络看到结构一致的聚合信号。

### 4.3 算法流程详解

#### 步骤 1：安全归一化

```matlab
% 对 PopDec 和 PopObj 做 min-max 归一化
% 处理 NaN/Inf：替换为列中位数
```

**动机**：不同目标的量纲和范围差异巨大，归一化后才能公平比较斜率特征。

#### 步骤 2：构建 LMVT 斜率特征矩阵 Gamma

这是 LKC 最核心的创新。灵感来自 LMVT（Lagrange Mean Value Theorem，拉格朗日中值定理）：

1. 将决策空间的对角方向 [0,1] 均匀划分为 `nCells` 个 cell
2. 对每个 cell 和每个决策维度 d：
   - 选择两个已评估样本 a, b，使其在维度 d 上接近 cell 的两个端点
   - 计算局部斜率：`slope = (F(b) - F(a)) / (X(b,d) - X(a,d))`
3. 得到 Gamma 矩阵：M × (nCells × D)

```
Gamma = [ γ₁,₁  γ₁,₂  ... γ₁,nCells×D ]  ← 目标1的斜率特征
        [ γ₂,₁  γ₂,₂  ... γ₂,nCells×D ]  ← 目标2的斜率特征
        [ ...                            ]
        [ γM,₁  γM,₂  ... γM,nCells×D ]  ← 目标M的斜率特征
```

**动机**：如果两个目标在相同的决策维度和局部区域有相似的斜率变化模式，说明它们对决策变量的响应结构相似——即使它们的绝对值不同。

#### 步骤 3：计算结构相似度

```matlab
Sim(i,j) = Pearson_Correlation(Gamma(i,:), Gamma(j,:))
```

**动机**：Pearson 相关衡量的是线性趋势的一致性，适合判断两个目标是否"同涨同跌"。

#### 步骤 4：K-means 聚类

- 对 Gamma 的行做归一化和中心化
- 使用相关距离（1 - |cosine similarity|）作为距离度量
- 尝试 k = 2 到 M-1，用轮廓系数选择最优 k
- 如果 M ≤ 2 或特征不足，fallback 为每个目标单独一组

**动机**：聚类的目标是把结构相似的目标自动分到一起，无需人工指定。

#### 步骤 5：组修复

- **负相关拆分**：如果组内存在 |corr| 高但符号相反的目标对，按正相关连通分量拆分
- **可靠性检查**：如果组内平均相似度 < `minGroupReliability`，拆成单目标组

**动机**：K-means 可能把负相关目标聚到一起（因为 |corr| 高），这会导致聚合后语义冲突。修复步骤确保每个组内的目标是真正正相关的。

#### 步骤 6：目标聚合

```matlab
% 对每个组 g，计算组内目标到结构特征中心的距离
dist(i) = ||Gamma(i,:) - centroid(g)||
w(i) = exp(-dist(i))
w = w / sum(w)
AggObj(:,g) = PopObj(:,C) * w'
```

**动机**：聚合把多个相关目标压缩成一个加权代表，越接近组中心的目标权重越大。这降低了子网络的目标维度，同时保留了组内的主要信息。

### 4.4 输出结构 StructState

| 字段 | 含义 |
|------|------|
| `Gamma` | M × (nCells×D) 斜率特征矩阵 |
| `Sim` | M × M Pearson 相似度矩阵 |
| `Groups` | cell 数组，每个元素是该组的目标索引 |
| `GroupReliability` | 每组的平均正相似度 |
| `GroupWeights` | 每组内目标的聚合权重 |
| `AggregatedObj` | N × G 聚合目标值 |
| `CellEdges` | cell 边界 |
| `PairIndex` | LMVT 样本对索引 |
| `PairQuality` | 样本对质量分数 |
| `ClusterK` | 选定的聚类数 |
| `SilhouetteScores` | 各 k 的轮廓系数 |
| `IsFallback` | 是否退化为单目标组 |

### 4.5 优点

1. **降低子网络维度**：将 M 个目标压缩为 G 个聚合目标（G << M），缓解维度诅咒
2. **处理目标冗余**：相似目标被合并，避免易目标子集被重复信息占满
3. **避免负相关误合并**：明确使用正相似性，负相关目标被拆开
4. **零额外评估开销**：只使用已评估样本估计结构，不增加昂贵真实评估
5. **鲁棒 fallback**：结构特征不足时退化为单目标组，不会强行聚类

### 4.6 缺点

1. **计算开销**：每代需构建 Gamma、计算相似度、聚类、修复和聚合
2. **早期不稳定**：样本较少时，局部斜率估计可能不可靠
3. **参数敏感**：`nCells` 和 `minRel` 会影响分组粒度
4. **信息损失**：聚合会压缩组内个别目标的信息，可能掩盖局部极端行为
5. **结构滞后**：如果目标关系阶段性变化，当前 population 的估计可能滞后

---

## 5. 模块三：目标聚合工具 AggregateObjectives_LKC.m

### 5.1 模块职责

独立的目标聚合接口，接收 `PopObj` 和 `StructState`，输出聚合目标值。

### 5.2 设计动机

提供一个独立于主流程的聚合接口，便于：
- 单独测试聚合逻辑
- 在其他上下文中复用聚合功能
- 作为 `BuildObjectiveStructure_LKC` 内嵌聚合的替代入口

### 5.3 核心逻辑

```matlab
for g = 1:length(Groups)
    C = Groups{g};
    centroid = mean(Gamma(C,:), 1);
    dist = vecnorm(Gamma(C,:) - centroid, 2, 2);
    w = exp(-dist);
    w = w / sum(w);
    AggObj(:,g) = PopObj(:,C) * w;
end
```

### 5.4 优缺点

与 `BuildObjectiveStructure_LKC` 中的聚合步骤相同。独立存在的价值在于模块化和可测试性。

---

## 6. 模块四：结构感知易目标选择 BuildStructureAwareEasySet.m

### 6.1 模块职责

将原始目标难度提升到组级，选择可靠且容易建模的目标组作为子网络的训练空间。

### 6.2 设计动机

原始 DiRel 的 `DifficultyProfiler` 判断的是"单个目标是否容易建模"，但子网络真正需要的是"一个低维子空间是否值得学习"。如果几个目标单独看都容易，但彼此结构不一致，直接组合成子网络仍然可能让关系标签混乱。

LKC 的组级选择把两个标准结合起来：
- **难度低**：这个组容易被代理模型学习
- **可靠性高**：组内目标结构相似，聚合后的语义更稳

### 6.3 算法流程

```
1. 调用 DifficultyProfiler → 原始难度 d_score
2. 组级难度 = mean(d_score(组内目标)) + 0.5 * std(d_score(组内目标))
3. 过滤: groupDifficulty < inf & reliability >= minRel
4. 评分: groupScore = groupDifficulty / max(reliability, eps) - λ * reliability
5. 按分数升序选择组，直到覆盖 ≥ k_easy 个原始目标
6. 若无有效组 → fallback 到原始易目标逻辑
```

### 6.4 关键设计点

**`mean + 0.5 * std` 的含义**：
- `mean` 衡量组的平均难度
- `std` 惩罚组内难度不均衡——一个困难目标不应拖累整个组
- 系数 0.5 是平衡因子，避免 std 过度主导

**可靠性过滤的含义**：
- `minRel = 0.65` 意味着组内平均正相似度必须 ≥ 0.65
- 过低的可靠性说明组内目标结构不一致，聚合后语义不稳定

### 6.5 优点

1. 子网络训练目标更一致，减少内部冲突
2. `mean + eta * std` 能惩罚组内难度不均衡
3. 可靠性过滤防止低质量聚类被使用
4. 保留原始 `DifficultyProfiler`，不完全推翻原始机制

### 6.6 缺点

1. 可靠组不足时会 fallback，LKC 优势减弱
2. 实际选中的原始目标数可能超过 `k_easy`
3. 对 `minRel` 较敏感
4. 组内聚合后，单目标难度信息只通过组难度间接体现

---

## 7. 模块五：目标难度估计 DifficultyProfiler.m

### 7.1 模块职责

计算每个原始目标的建模难度分数，用于后续的易目标选择。

### 7.2 设计动机

不同目标的建模难度差异很大：
- **值域跨度大**的目标：需要更复杂的模型才能拟合
- **改善缓慢**的目标：说明 landscape 平坦或局部最优多
- **与其他目标冲突**的目标：难以与其他目标同时优化

### 7.3 难度计算公式

```
建模难度 = 0.5 × spanScore + 0.5 × improveScore

其中:
  spanScore = normalize(log(1 + max_span))    ← 值域跨度
  improveScore = 1 - normalize(relative_improvement)  ← 改善速度

冲突难度 = 1 - normalize(ConflictDegree)

联合难度 = α × 建模难度 + (1-α) × 冲突难度
```

### 7.4 滑动窗口平滑

使用 `win_K` 代的滑动窗口对难度分数进行指数平滑，避免单代噪声导致难度估计剧烈波动。

### 7.5 优点

1. 同时考虑建模难度和冲突难度两个维度
2. 滑动窗口平滑减少噪声
3. 输出可解释的难度分数

### 7.6 缺点

1. spanScore 对异常值敏感
2. improveScore 在初期样本少时不稳定
3. α 的选择需要问题特定调参

---

## 8. 模块六：冲突度计算 ConflictDegree.m

### 8.1 模块职责

计算每个目标与其他目标之间的 Spearman 秩冲突度。

### 8.2 设计动机

Spearman 秩相关衡量的是单调关系的一致性。如果目标 j 与其他目标的秩相关普遍较低或为负，说明它与其他目标存在冲突，难以同时优化。

### 8.3 计算公式

```
conf(j) = mean(1 - |ρ(j, others)|)
```

其中 ρ 是 Spearman 秩相关系数。conf 越高，说明目标 j 与其他目标的冲突越大。

### 8.4 优缺点

- **优点**：非参数方法，不假设线性关系；计算简单
- **缺点**：只衡量两两冲突，忽略高阶交互；对样本量有要求

---

## 9. 模块七：冗余修正 RefineEasySubset.m

### 9.1 模块职责

检查候选易目标子集中的高冗余对，并替换为非冗余的次易目标。

### 9.2 设计动机

如果两个易目标的 |Spearman ρ| > 0.95，它们几乎表达相同信息，同时保留在子集中是浪费。保留更容易的那个，替换为下一个非冗余的候选目标。

### 9.3 算法

```
while 存在 |ρ(i,j)| > 0.95:
    保留 d_score 较低的目标
    替换另一个为 ranked_list 中下一个非冗余目标
确保: 2 ≤ |S_easy| ≤ M-1
```

### 9.4 优缺点

- **优点**：简单有效，避免冗余目标占满子集
- **缺点**：阈值 0.95 是硬编码的；只考虑两两冗余

---

## 10. 模块八：Pareto-first 关系对标签 GetRelationPairsBudgeted_LKC.m

### 10.1 模块职责

从已评估解对中生成带标签的训练样本，用于训练关系网络。

### 10.2 设计动机

原始 DiRel 使用 PBI 类别关系生成标签，这更接近"参考向量分类"而非真正的优劣关系。LKC 改为直接在目标空间中进行 Pareto 支配判断，使标签语义更准确。

### 10.3 标签逻辑

```
对每对解 (i, j):
  if i Pareto 支配 j → label = +1
  elif j Pareto 支配 i → label = -1
  else (互不支配):
    if mean(fi) - mean(fj) < -scalarGap → label = +1
    elif mean(fi) - mean(fj) > scalarGap → label = -1
    else → label = 0

若完全没有 +1/-1 → 退回 PBI-like catalog 采样
```

### 10.4 平衡采样

将 `pairMax` 个配额平均分配给三类标签 {0, +1, -1}，溢出配额分给剩余对。

### 10.5 优点

1. 标签语义更接近 Pareto 优劣关系
2. 同一函数可用于全目标空间和聚合空间
3. `scalarGap` 给互不支配样本提供弱偏好标签
4. 保留 PBI fallback 防止极端情况

### 10.6 缺点

1. 互不支配样本用均值差做弱偏好，引入了加权和式标量化偏好
2. `scalarGap` 过小会把大量互不支配关系强行分成 +1/-1
3. 聚合空间中的 Pareto 关系不等价于原始 Pareto 关系

---

## 11. 模块九：双尺度集成网络训练 TrainDualScaleNet.m

### 11.1 模块职责

训练两个集成分类器：全目标关系网络和易聚合子网络。

### 11.2 设计动机

双网络设计的核心思想是"多视角学习"：
- **全目标网络**：看到完整的 M 维目标空间，提供全局判断
- **子网络**：看到低维的易聚合目标空间，提供局部补充

集成（Bagging）降低单个网络的方差，提高预测稳定性。

### 11.3 网络结构

```
输入层 (2D) → 隐藏层 (max 24 nodes) → softmax 输出层 (3 classes)

其中:
  输入 = 解对的决策变量拼接 [x_i, x_j]
  输出 = [+1, 0, -1] 的 softmax 概率
```

### 11.4 训练策略

| 项目 | 全目标网络 (nets_F) | 子网络 (nets_S) |
|------|---------------------|-----------------|
| 训练数据 | 全目标关系对 | 易聚合关系对 |
| 训练轮数 | 60 epochs | 30 epochs |
| 初始化 | 随机初始化 | 从 nets_F 迁移初始化 |
| 集成大小 | K_ens 个 | K_ens 个 |
| 采样比例 | 70% bagging | 70% bagging |

### 11.5 数据处理

- 75/25 训练/测试划分，按类别分层采样
- 三类标签 → one-hot 编码：+1→[1,0,0], 0→[0,1,0], -1→[0,0,1]

### 11.6 优缺点

- **优点**：集成降低方差；迁移初始化加速子网络收敛；双视角互补
- **缺点**：`patternnet` 是黑箱模型，可解释性差；训练时间随集成数线性增长

---

## 12. 模块十：权重迁移 TransferFineTune.m

### 12.1 模块职责

将源网络的权重复制到目标网络，实现迁移初始化。

### 12.2 设计动机

子网络和全目标网络的输入维度相同（都是 2D 决策变量拼接），因此全目标网络学到的"决策空间模式"可以迁移到子网络。这比随机初始化更快收敛。

### 12.3 迁移内容

- `IW`：输入权重矩阵
- `LW`：层间权重矩阵
- `b`：偏置向量

**前提**：源和目标网络的维度必须匹配。

### 12.4 优缺点

- **优点**：简单有效，加速子网络训练
- **缺点**：如果全目标网络学到了错误模式，会迁移到子网络

---

## 13. 模块十一：全目标优先仲裁评分 ArbitratorScore_LKC.m

### 13.1 模块职责

对每个候选解进行评分，融合全目标网络和子网络的预测。

### 13.2 设计动机

这是 LKC 与原始 DiRel 的关键区别之一。原始 DiRel 使用逆方差融合，将两个网络近似对等对待。但 LKC 的子网络学习的是"易聚合目标空间"的语义，比全目标网络更窄。如果继续对等融合，子空间很确定但全目标上实际不好的情况可能导致错误推荐。

因此 LKC 采用 **全目标优先** 策略：
- 全目标网络负责主判断
- 子网络只在全目标不确定时做 tie-break
- 如果子网络与全目标信号冲突，要惩罚而不是奖励

### 13.3 评分公式

```
scores = baseFull                           % 全目标基础分
       + tieWeight × triggerSub × subPref   % 子网络 tie-break
       - betaUncertainty × uncertaintyPen   % 不确定性惩罚
       - lambdaDisagreement × disagreement  % 冲突惩罚
       + gammaNovelty × novelty             % 新颖性奖励

其中:
  baseFull = 2 + 2 × tanh(μ_F)
  subPref = max(0, tanh(μ_S))
  highF = |μ_F| ≥ margin_F & σ²_F ≤ uncertainty_F
  highS = |μ_S| ≥ margin_S & σ²_S ≤ uncertainty_S
  fullUncertain = ¬highF
  triggerSub = fullUncertain & highS
  disagreement = highS & sign(μ_F) × sign(μ_S) < 0
```

### 13.4 评分机制

对每个候选解：
1. 选择正锚点和负锚点（基于训练集的 Catalog 标签）
2. 将候选与所有锚点配对，送入网络
3. 聚合 softmax 输出得到标量分数
4. 取集成均值 μ 和方差 σ²

### 13.5 新颖性计算

```
novelty(x) = min_{t ∈ training_set} ||x - t||₂
归一化到 [0, 1]
```

### 13.6 内部参数

| 参数 | 默认值 | 含义 |
|------|--------|------|
| `margin_F` | 0.15 | 全目标网络高置信均值边界 |
| `margin_S` | 0.15 | 子网络高置信均值边界 |
| `tieWeight` | 0.5 | 子网络 tie-break 权重 |
| `betaUncertainty` | 0.25 | 不确定性惩罚权重 |
| `lambdaDisagreement` | 0.75 | 冲突惩罚权重 |
| `gammaNovelty` | 0.25 | 新颖性奖励权重 |
| `scoreThreshold` | 3.4 | 候选筛选阈值 |

### 13.7 优点

1. 降低子空间误导全局选择的风险
2. 符合 LKC 子网络的语义边界
3. 增加诊断信息（full uncertain ratio, sub triggered ratio 等）
4. 阈值从 3.9 放宽到 3.4，在更保守的评分下避免候选过少

### 13.8 缺点

1. 子网络影响力被削弱，可能发挥不出 LKC 的优势
2. 内部系数较多，需要实验确认稳定性
3. `baseFull = 2 + 2*tanh(μ_F)` 使分数主要由全目标网络控制，可能降低探索性

---

## 14. 模块十二：GA 候选生成与选择 ArbitratedSelection_LKC.m

### 14.1 模块职责

迭代生成候选解，通过仲裁评分筛选，输出高质量候选。

### 14.2 设计动机

昂贵优化中，每次真实评估都很珍贵。因此不能一次性生成大量候选解直接评估，而需要：
1. 用 GA 生成初始候选
2. 用代理模型评分
3. 选择高分候选作为"父代"生成更多候选
4. 迭代优化直到达到预算上限

### 14.3 难度自适应 GA 参数

```matlab
disC = 10 + 20 × (1 - diff)   % 交叉分布指数
disM = 5 + 20 × (1 - diff)    % 变异分布指数
proM = 1 + 0.5 × diff          % 变异率
```

**动机**：问题越难（diff 越大），需要更多变异来探索；问题越简单，可以更多依赖交叉来开发。

### 14.4 迭代筛选

```
1. 生成初始候选 (OperatorGA)
2. 评分 → 选择 top 候选
3. 从 top 候选生成新 offspring
4. 重复 2-3，直到达到 gmax 次评估
5. 最终筛选: score > threshold 或至少 top 4
```

### 14.5 优缺点

- **优点**：迭代优化提高候选质量；难度自适应参数调节探索/开发平衡
- **缺点**：GA 生成可能陷入局部最优；评分阈值可能过滤掉有潜力的候选

---

## 15. 参数汇总与调参建议

### 15.1 公开参数

| 参数 | 默认值 | 作用 | 调大影响 | 调小影响 |
|------|--------|------|----------|----------|
| `k_easy_user` | -1 | 易目标数 | 子网络维度更高 | 子网络维度更低 |
| `tau_conf` | 0.3 | 不确定性阈值 | 更多候选被判为不确定 | 更少不确定 |
| `alpha` | 0.6 | 难度权重 | 更重视建模难度 | 更重视冲突难度 |
| `k` | 6 | 参考解数 | 更多参考点，选择更分散 | 更少参考点，选择更集中 |
| `gmax` | 1000 | GA 迭代数 | 候选质量更高，但计算更慢 | 更快但候选质量可能下降 |
| `K_ens` | 3 | 集成数 | 预测更稳定，但训练更慢 | 更快但方差更大 |
| `win_K` | 3 | 平滑窗口 | 更平滑但响应更慢 | 更敏感但噪声更大 |
| `nCells` | 5 | LMVT cell 数 | 结构特征更细 | 更粗但更稳定 |
| `minRel` | 0.65 | 最低可靠性 | 分组更保守 | 分组更激进 |
| `scalarGap` | 0.05 | 偏好标签阈值 | 更多 0 标签 | 更多 +1/-1 标签 |

### 15.2 调参建议

1. **先用默认值跑基线**，观察诊断输出
2. **如果分组全是 singleton**：降低 `minRel` 或增加 `nCells`
3. **如果子网络几乎不参与**（`subTriggeredRatio ≈ 0`）：降低 `tau_conf` 或 `margin_F`
4. **如果冲突比例高**（`disagreementRatio > 0.3`）：检查分组质量，可能需要调整 `minRel`
5. **如果候选解太少**：降低 `scoreThreshold`

---

## 16. 优缺点综合分析

### 16.1 主要优点

| 优点 | 说明 |
|------|------|
| 子网络语义更稳 | 结构组内目标正相关，聚合后一致性更强 |
| 适合超多目标冗余场景 | 相似目标被合并，降低关系学习压力 |
| 避免负相关误合并 | 明确使用正相似性，负相关目标被拆开 |
| 仲裁更安全 | 全目标优先，降低局部视角误导全局选择的风险 |
| 诊断能力强 | `lkcDiag` 提供丰富的算法行为信息 |
| 零额外评估开销 | 结构分析只使用已评估样本 |

### 16.2 主要缺点

| 缺点 | 说明 |
|------|------|
| 计算更复杂 | 每代增加结构估计、聚类、修复和聚合 |
| 参数更多 | 新增 3 个公开参数 + 9 个内部仲裁系数 |
| 早期不稳定 | 初期样本少时，结构估计可能不可靠 |
| 聚合损失信息 | 组内个别目标的极端行为可能被掩盖 |
| 子网络影响偏弱 | 全目标优先仲裁可能让 LKC 子网络的优势不明显 |

---

## 17. 适用场景与推荐

### 17.1 更适合 REMO_DiRel_LKC 的场景

- 目标数较多（M ≥ 10）
- 多个目标之间存在明显冗余或相似变化趋势
- 原始 DiRel 的 `S_easy` 经常选到高度相似目标
- 需要保守使用子空间模型
- 需要更多诊断信息

### 17.2 更适合原始 REMO_DiRel 的场景

- 目标数较少（M ≤ 5）
- 目标之间关系很弱或高度动态
- 运行时间预算很紧
- 希望子网络和全目标网络以更对等方式融合

---

## 18. 消融实验建议

### 18.1 与原始算法对比

| 对比项 | 推荐 |
|--------|------|
| 算法 | REMO_DiRel vs REMO_DiRel_LKC |
| 指标 | IGD, HV, Runtime, 双网络测试误差 |
| 问题 | DTLZ2/3/4/7, WFG1/4/6/9, MaF 系列 |
| 目标数 | M = 5, 10, 15, 20 |

### 18.2 LKC 内部消融

| 变体 | 验证目标 |
|------|----------|
| 不做结构分组（全部 singleton） | LKC 分组本身是否有效 |
| 做分组但不用聚合 | 聚合目标是否有效 |
| 使用旧版逆方差仲裁 | 全目标优先仲裁是否必要 |
| 关闭组修复 | 正相关和可靠性约束是否必要 |
| scalarGap = 0 或很大 | 弱偏好标签对训练的影响 |

### 18.3 重点诊断字段

- `Groups`：目标分组是否符合问题结构
- `GroupReliability`：可靠组比例
- `fullUncertainRatio`：全目标网络不确定比例
- `subTriggeredRatio`：子网络实际参与比例
- `disagreementRatio`：全/子网络冲突比例

---

## 19. 后续改进方向

1. **缓存或低频更新结构分组**：不必每代重新构建，可每隔若干代更新
2. **自适应 `minRel`**：初期保守，中后期允许更细致分组
3. **改进非支配样本弱标签**：尝试 PBI 距离、参考向量角度、R2 指标
4. **让仲裁参数可配置**：加入 `ParameterSet` 便于实验
5. **引入组稳定性诊断**：记录相邻代分组变化，频繁震荡时触发 fallback
6. **子网络训练质量门控**：当 `p_err_S` 过高时，自动降低 tieWeight 或禁用子网络

---

## 附录：文件清单

| 文件 | 类型 | 行数 | 角色 |
|------|------|------|------|
| `REMO_DiRel_LKC.m` | classdef | 191 | 主算法入口 |
| `BuildObjectiveStructure_LKC.m` | function | 645 | LKC 核心：结构分组 |
| `AggregateObjectives_LKC.m` | function | 87 | 独立聚合工具 |
| `BuildStructureAwareEasySet.m` | function | 148 | 组级易目标选择 |
| `DifficultyProfiler.m` | function | 167 | 目标难度估计 |
| `ConflictDegree.m` | function | 76 | 冲突度计算 |
| `RefineEasySubset.m` | function | 118 | 冗余修正 |
| `GetRelationPairsBudgeted_LKC.m` | function | 275 | Pareto-first 关系标签 |
| `TrainDualScaleNet.m` | function | 392 | 双网络训练 |
| `TransferFineTune.m` | function | 95 | 权重迁移 |
| `ArbitratorScore_LKC.m` | function | 229 | 全目标优先仲裁 |
| `ArbitratedSelection_LKC.m` | function | 57 | GA 候选生成与选择 |
| `test_units_LKC.m` | function | 56 | 单元测试 |
| `run_smoke_LKC.m` | function | 22 | 冒烟测试 |
