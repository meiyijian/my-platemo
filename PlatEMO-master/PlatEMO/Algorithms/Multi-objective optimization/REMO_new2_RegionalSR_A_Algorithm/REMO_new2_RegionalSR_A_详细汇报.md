# REMO_new2_RegionalSR_A 算法详细汇报

## 1. 算法概述

**算法全称：** REMO_new2_RegionalSR_A — 基于区域软排序的代理辅助多目标优化算法（路线 A：全局模型 + 参考向量上下文）

**名称由来：**
- REMO = Relation-based Evolutionary Multi-objective Optimization
- new2 = 改进版本 2
- RegionalSR = Regional Soft Ranking（区域软排序）
- A = 路线 A（一个全局模型，输入中包含参考向量上下文）

**算法定位：** 在 REMO_new2_TrueSR 基础上引入参考向量分解思想，将全局软排序扩展为区域感知的软排序，以更好地处理高维目标（5-20 个目标）的昂贵优化问题。

---

## 2. 研究动机

### 2.1 TrueSR 在高维目标下的局限

REMO_new2_TrueSR 使用全局软排序对训练一个统一的神经网络。这种方法在 2-3 个目标时效果良好，但在高维目标（many-objective，5-20 个目标）场景下存在以下问题：

**问题一：Pareto 前沿形状复杂化。** 目标数增加后，Pareto 前沿从低维的曲线/曲面变为高维超曲面，全局排序信号变得稀疏和嘈杂。

**问题二：参考向量覆盖不均。** 高维空间中均匀分布的参考向量数量呈指数增长（维度灾难），实际可用的参考向量数量有限，导致部分区域没有有效的排序信号。

**问题三：单一模型难以捕捉区域差异。** 不同参考向量区域的解可能具有完全不同的排序关系，一个全局模型难以同时学习所有区域的局部排序模式。

### 2.2 分解思想的引入

多目标优化领域的经典方法 MOEA/D 和 RVEA 证明了"分解"思想的有效性：将一个多目标问题分解为多个子问题，每个子问题由一个参考向量定义，在各自的区域内进行优化。

**核心问题：** 如何将分解思想与软排序学习结合？

### 2.3 RegionalSR_A 的设计思路

RegionalSR_A 采用"一个全局模型 + 参考向量上下文"的策略：

1. **区域划分**：用参考向量将目标空间划分为多个区域
2. **区域评分**：在每个区域内计算 APD（Angle Penalized Distance）分数
3. **上下文感知**：训练时将参考向量作为额外输入，让模型知道"在哪个区域做比较"
4. **区域多样性选择**：最终选择时确保候选解来自不同区域

---

## 3. 核心方法

### 3.1 算法总体流程

```
初始化种群（拉丁超立方采样）→ 真实评估
         ↓
    ┌─→ 选择参考解（RSEA 策略）
    │        ↓
    │   生成均匀参考向量 W
    │        ↓
    │   构建区域信息（区域分配、APD 分数）
    │        ↓
    │   选择活跃区域
    │        ↓
    │   为每个活跃区域生成带上下文的软排序对
    │        ↓
    │   训练全局神经网络（输入包含参考向量）
    │        ↓
    │   代理辅助选择（按区域评分 + 区域多样性选择）
    │        ↓
    │   真实评估候选解 → 更新归档集
    │        ↓
    │   环境选择（RSEA 雷达网格策略）
    │        ↓
    └── 评估次数用完？→ 否 → 回到循环起点
              ↓ 是
         输出最终结果
```

### 3.2 参考向量生成

`CreateReferenceVectors_RegionalSR` 使用 ILD（Incremental Lattice Design）生成均匀分布的参考向量：

```matlab
W = UniformPoint(Nref, M, 'ILD');
W = W ./ vecnorm(W, 2, 2);  % 归一化为单位向量
```

默认生成 `max(Nref, N)` 个参考向量（Nref = 100），确保覆盖足够的搜索方向。

### 3.3 区域信息构建

`BuildRegionalInfo_RegionalSR` 是区域分解的核心，它计算以下信息：

**步骤一：目标值归一化**
```matlab
PopObjN = (PopObj - Zmin) ./ range
```
消除各目标的尺度差异，将目标值映射到 [0,1] 区间。

**步骤二：区域分配**
用余弦相似度将每个解分配到最近的参考向量：
```matlab
cosine = 1 - pdist2(PopObjN, W, 'cosine');
[~, region] = max(cosine, [], 2);
```

**步骤三：角度计算**
计算每个解与其分配的参考向量之间的夹角：
```matlab
angle = real(acos(cosine))
```

**步骤四：参考向量间最小夹角（γ）**
```matlab
wCos = W * W';           % 参考向量间的余弦相似度矩阵
wAng = real(acos(wCos)); % 转为角度
wAng(logical(eye(R))) = inf;  % 对角线设为无穷
gamma = min(wAng, [], 2);     % 每个参考向量与最近邻的夹角
```

**步骤五：APD（Angle Penalized Distance）计算**
```matlab
penalty = M × ratio²
apdMatrix(:,r) = (1 + penalty × angle(:,r) / gamma(r)) × ||PopObjN||
```

APD 的设计思想：
- 第一项 `||PopObjN||`：解到原点的距离（收敛性指标，越小越好）
- 第二项 `(1 + penalty × angle / gamma)`：角度惩罚（偏离参考方向越远，惩罚越大）
- `penalty = M × ratio²`：随进化进程增大，后期更强调角度对齐

**步骤六：局部分数矩阵**
```matlab
localScoreMatrix = -apdMatrix  % APD 越小越好，取负转为越大越好
```

每个解在每个参考向量区域都有一个分数，形成 N×R 的分数矩阵。

### 3.4 活跃区域选择

`SelectActiveRegions_RegionalSR` 根据样本数量选择活跃区域：

```matlab
for i = 1:numel(activeRegions)
    counts(i) = sum(region == activeRegions(i));  % 统计每个区域的样本数
end
[~, order] = sort(counts, 'descend');  % 按样本数降序排列
activeRegions = activeRegions(1:min(maxRegions, numel(activeRegions)));
```

选择策略：优先选择样本数量最多的区域（最多 `maxRegions` = 25 个），确保每个区域有足够的训练数据。

### 3.5 区域池扩展

`ExpandRegionPool_RegionalSR` 为样本不足的区域扩展样本池：

```matlab
pool = find(region == r);  % 当前区域的样本
if numel(pool) < minSamples
    % 按参考向量间的余弦相似度找到最近的 neighborNum 个邻近区域
    cosWR = W * W(r,:)';
    [~, order] = sort(acos(cosWR), 'ascend');
    % 将邻近区域的样本加入池中
    for i = 1:maxTake
        pool = unique([pool; find(region == order(i))]);
    end
end
```

默认 `neighborNum = 2`，即最多扩展到 2 个最近邻区域。这确保了每个区域至少有 `minSamples`（默认 2）个样本用于配对。

### 3.6 带上下文的软排序对生成（核心创新）

`GetRegionalSoftRelationPairs_A` 是 RegionalSR_A 相对于 TrueSR 的核心创新：

**与 TrueSR 的关键区别：** 每个训练样本额外包含参考向量 w_r 作为上下文信息。

```
TrueSR:      [x_i, x_j] → P(x_i 比 x_j 好)
RegionalSR_A: [x_i, x_j, w_r] → P_r(x_i 在区域 r 中比 x_j 好)
```

**生成过程：**

```matlab
for r = activeRegions
    % 扩展区域样本池
    pool = ExpandRegionPool_RegionalSR(Info.region, W, r, neighborNum, 2);

    % 生成带上下文的软排序对
    [Xr, Pr, PairR] = GetRegionSoftPairs_RegionalSR(Input, ...
        Info.localScoreMatrix(:,r), pool, ...
        'Alpha', alpha, 'MaxPairs', perRegionMax, 'Context', W(r,:));

    % 拼接到总数据集
    XXs = [XXs; Xr];
    Ps  = [Ps; Pr];
end
```

`GetRegionSoftPairs_RegionalSR` 内部：
1. 从区域池中提取样本的局部分数
2. 生成所有 (i, j) 配对
3. 用 Sigmoid 函数计算软概率：`P = 1/(1+exp(-α×(score_i - score_j)))`
4. **关键步骤**：将参考向量拼接到特征末尾：`XXs = [XXs, repmat(context, size(XXs,1), 1)]`

最终训练数据格式：`[x_i(1×D), x_j(1×D), w_r(1×M)] → P(标量)`

### 3.7 神经网络训练

使用 `TrainSoftProbabilityNet_RegionalSR` 训练，网络结构与 TrueSR 相同：

```
输入层 (2D + M 维)  ← 注意：多了 M 维参考向量
    ↓
隐藏层1: ceil(1.5 × (2D+M)) 个神经元
    ↓
隐藏层2: (2D+M) 个神经元
    ↓
隐藏层3: ceil((2D+M) / 2) 个神经元
    ↓
输出层: 1 个神经元（logsig 激活）
```

**模型含义：** 一个全局模型学会了"在参考向量 w_r 的上下文中，解 i 是否比解 j 好"。不同的参考向量上下文会让模型给出不同的预测结果。

### 3.8 区域感知的代理辅助选择（核心创新）

`RSurrogateAssistedSelection_RegionalSR_A` 的选择过程与 TrueSR 有本质区别：

**步骤一：按区域分别评分**

对每个活跃区域 r，分别计算所有候选解的分数：

```matlab
for rr = 1:numel(activeRegions)
    r = activeRegions(rr);

    % 扩展区域样本池，选择锚点
    pool = ExpandRegionPool_RegionalSR(Info.region, W, r, neighborNum, 2);
    anchorIndex = SelectAnchorsForRegion_RegionalSR(Info.localScoreMatrix(:,r), pool, anchorNum);

    % 构建带上下文的测试对
    context = repmat(W(r,:), nextNum*anchorNum, 1);
    forwardPairs = [nextBlock, ancBlock, context];  % 候选解, 锚点, 参考向量
    reversePairs = [ancBlock, nextBlock, context];  % 锚点, 候选解, 参考向量

    % 用神经网络预测
    prob = net(testPairsNor')';

    % 计算区域分数
    pairScore = 0.5 .* (probForward + 1 - probReverse);
    regionScores(:,rr) = mean(pairScore, 2);
end
```

**步骤二：取最佳区域分数**

每个候选解取其在所有区域中的最高分数：
```matlab
[scores, bestIdx] = max(regionScores, [], 2);
bestRegion = activeRegions(bestIdx)';
```

**步骤三：区域多样性选择**

`SelectTopByRegion_RegionalSR` 确保最终选出的候选解来自不同区域：

1. 首先从每个区域选出分数最高的 1 个候选解
2. 然后按全局分数降序排列，补充到 maxNum 个

这种策略保证了选出的解在目标空间中有良好的分布，避免过度集中在某一区域。

### 3.9 区域锚点选择

`SelectAnchorsForRegion_RegionalSR` 为每个区域选择覆盖高、中、低排名的锚点：

```matlab
[~, order] = sort(score(pool), 'descend');  % 按区域分数排序
pool = pool(order);
rankPos = unique(round(linspace(1, numel(pool), min(anchorNum, numel(pool)))));
anchorIndex = pool(rankPos);
```

与 TrueSR 的全分布锚点类似，但在区域池内均匀采样，确保锚点覆盖该区域的整个排名分布。

---

## 4. 算法参数

| 参数 | 默认值 | 含义 |
|------|--------|------|
| `k` | 6 | 参考解数量（用于变异和环境选择） |
| `gmax` | 3000 | 每代代理辅助搜索的最大尝试次数 |
| `pairMax` | 12000 | 训练配对的最大数量（所有区域共享） |
| `alphaSoft` | 6 | Sigmoid 函数的陡峭系数 |
| `anchorNum` | 12 | 每个活跃区域的锚点数量 |
| `Nref` | 100 | 参考向量数量 |
| `neighborNum` | 2 | 邻近区域扩展数量 |
| `maxRegions` | 25 | 最大活跃区域数量 |

**与 TrueSR 的参数差异：**
- `anchorNum`：从 20 降到 12（因为多个区域共享总配对数）
- 新增 `Nref`、`neighborNum`、`maxRegions` 三个区域相关参数

---

## 5. 与 TrueSR 的关键差异

| 特性 | REMO_new2_TrueSR | REMO_new2_RegionalSR_A |
|------|------------------|------------------------|
| 排序范围 | 全局排序 | 区域排序（每个参考向量区域） |
| 训练模型 | 一个全局模型 | 一个全局模型（但输入含上下文） |
| 训练对格式 | `[x_i, x_j]` | `[x_i, x_j, w_r]` |
| 评分方式 | 全局统一评分 | 按区域分别评分，取最佳 |
| 锚点来源 | 全种群均匀采样 | 区域池内均匀采样 |
| 最终选择 | 按全局分数降序 | 区域多样性选择 |
| 适用场景 | 2-3 目标 | 2-20 目标（尤其 5+ 目标） |

---

## 6. 设计优势

### 6.1 上下文感知的排序学习

通过将参考向量作为额外输入，模型学会了"在不同搜索方向上的排序偏好"。同一个解对 (i, j) 在不同的参考向量上下文中可能有不同的排序结果，这更符合高维目标空间中"不同区域有不同的优劣标准"的现实。

### 6.2 区域自适应的评分机制

每个候选解在所有活跃区域都被评分，取最佳分数。这意味着：
- 如果一个解在某个区域特别优秀，它会被识别出来
- 即使该解在全局排名不高，在其擅长的区域也可能被选中
- 这有助于发现分布在不同区域的优质解

### 6.3 区域多样性保证

`SelectTopByRegion_RegionalSR` 确保最终选出的解来自不同区域，避免了代理选择过度集中在某一区域的问题。这对于高维目标优化尤为重要，因为 Pareto 前沿在高维空间中的分布更复杂。

### 6.4 邻近区域扩展

当某个区域样本不足时，自动扩展到邻近区域。这解决了高维空间中参考向量数量多但每个区域样本稀少的问题。

---

## 7. 可能风险与注意事项

### 7.1 上下文维度增加

训练输入维度从 2D 增加到 2D + M（M 为目标数）。当 M 较大（如 15-20）时，输入维度显著增加，可能需要更多训练样本或更深的网络。

### 7.2 区域质量不均

不同区域的样本数量和质量可能差异很大。样本少的区域的排序信号可能不可靠。当前通过邻近区域扩展和活跃区域选择来缓解，但仍需注意。

### 7.3 训练时间增加

每个区域都需要单独生成配对和选择锚点，总训练时间比 TrueSR 更长。但 `maxRegions` 限制了活跃区域数量，控制了计算开销。

### 7.4 参考向量数量敏感性

`Nref` 太小会导致区域划分过粗，太大则每个区域样本太少。默认 100 是一个折中值，具体问题可能需要调整。

---

## 8. 文件清单

| 文件名 | 功能 |
|--------|------|
| `REMO_new2_RegionalSR_A.m` | 主算法入口 |
| `GetRegionalSoftRelationPairs_A.m` | 带上下文的区域软排序对生成 |
| `RSurrogateAssistedSelection_RegionalSR_A.m` | 区域感知的代理辅助选择 |
| `CreateReferenceVectors_RegionalSR.m` | 均匀参考向量生成 |
| `BuildRegionalInfo_RegionalSR.m` | 区域信息构建（APD 分数） |
| `SelectActiveRegions_RegionalSR.m` | 活跃区域选择 |
| `ExpandRegionPool_RegionalSR.m` | 区域样本池扩展 |
| `GetRegionSoftPairs_RegionalSR.m` | 区域内软排序对生成 |
| `SelectAnchorsForRegion_RegionalSR.m` | 区域锚点选择 |
| `TrainSoftProbabilityNet_RegionalSR.m` | 神经网络训练 |
| `SelectTopByRegion_RegionalSR.m` | 区域多样性选择 |
| `RefSelect.m` | RSEA 雷达网格环境选择 |
| `DataProcessSoft.m` | 训练集/测试集划分 |

---

## 9. 快速测试

```matlab
% 小预算烟雾测试（3 目标 DTLZ2）
[decs,objs,cons] = platemo(...
    'algorithm',{@REMO_new2_RegionalSR_A,6,3000,12000,6,12,100,2,25},...
    'problem',@DTLZ2,...
    'M',3,...
    'D',12,...
    'maxFE',50);
```

---

## 10. 后续改进方向

1. **自适应参考向量**：根据 Pareto 前沿分布动态调整参考向量方向和密度
2. **区域模型质量评估**：监控每个区域的训练误差，对不可靠区域降权
3. **跨区域迁移学习**：利用邻近区域的模型参数初始化新区域的模型
4. **动态区域数量**：根据问题特性和进化阶段自适应调整活跃区域数量
