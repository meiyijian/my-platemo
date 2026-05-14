# REMO_new2_RegionalSR_B 算法详细汇报

## 1. 算法概述

**算法全称：** REMO_new2_RegionalSR_B — 基于区域软排序的代理辅助多目标优化算法（路线 B：每个区域独立训练局部模型）

**名称由来：**
- REMO = Relation-based Evolutionary Multi-objective Optimization
- new2 = 改进版本 2
- RegionalSR = Regional Soft Ranking（区域软排序）
- B = 路线 B（每个区域独立训练一个局部模型，不使用上下文）

**算法定位：** 与 RegionalSR_A 同系列的替代方案，通过训练多个局部模型（每个参考向量区域一个）来捕捉不同区域的排序模式，适用于高维目标昂贵优化。

---

## 2. 研究动机

### 2.1 从 RegionalSR_A 到 RegionalSR_B 的设计思考

RegionalSR_A 使用"一个全局模型 + 参考向量上下文"的策略。这种方法的优点是模型数量少（只需一个），但存在一个根本性矛盾：

**矛盾：全局模型需要同时学习所有区域的排序模式。**

即使输入中包含了参考向量上下文，神经网络仍然需要在同一个参数空间中编码所有区域的知识。当不同区域的排序模式差异很大时（这在高维目标空间中很常见），单一模型可能难以兼顾。

### 2.2 RegionalSR_B 的核心假设

**假设：每个参考向量区域的排序模式是局部的、独立的，用专门的局部模型可以更好地捕捉。**

这类似于机器学习中的"专家混合"（Mixture of Experts）思想：与其用一个通用模型处理所有情况，不如用多个专门模型各司其职。

### 2.3 两条路线的对比

| 维度 | RegionalSR_A | RegionalSR_B |
|------|-------------|-------------|
| 模型数量 | 1 个全局模型 | 多个局部模型（最多 maxModels 个） |
| 输入格式 | `[x_i, x_j, w_r]` | `[x_i, x_j]`（无上下文） |
| 区域区分方式 | 通过参考向量上下文隐式区分 | 通过不同模型显式区分 |
| 训练开销 | 低（只训练一个模型） | 高（每个区域训练一个模型） |
| 推理开销 | 低（一次推理） | 高（所有模型各推理一次） |
| 区域特化程度 | 受限于全局模型容量 | 高（每个模型专门针对一个区域） |

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
    │   为每个活跃区域训练独立的局部模型
    │        ↓
    │   代理辅助选择（所有模型分别评分，取最佳）
    │        ↓
    │   真实评估候选解 → 更新归档集
    │        ↓
    │   环境选择（RSEA 雷达网格策略）
    │        ↓
    └── 评估次数用完？→ 否 → 回到循环起点
              ↓ 是
         输出最终结果
```

### 3.2 区域信息构建（与 A 共享）

`BuildRegionalInfo_RegionalSR` 的计算过程与 RegionalSR_A 完全相同：

1. 目标值归一化到 [0,1]
2. 用余弦相似度将每个解分配到最近的参考向量
3. 计算解与参考向量的夹角
4. 计算 APD（Angle Penalized Distance）分数
5. 构建 N×R 的局部分数矩阵

### 3.3 区域模型训练（核心创新）

`TrainRegionalSoftModels_B` 是 RegionalSR_B 的核心，它为每个活跃区域训练一个独立的神经网络：

**步骤一：选择活跃区域**
```matlab
activeRegions = SelectActiveRegions_RegionalSR(Info.region, maxModels);
```

按样本数量降序排列，选择最多 `maxModels`（默认 20）个区域。

**步骤二：分配配对预算**
```matlab
perModelPairs = max(30, ceil(maxPairs / numel(activeRegions)));
```

将总配对预算 `pairMax`（默认 12000）平均分配给各区域模型，每个模型至少 30 对。

**步骤三：为每个区域训练独立模型**

```matlab
for r = activeRegions
    % 扩展区域样本池
    pool = ExpandRegionPool_RegionalSR(Info.region, W, r, neighborNum, 2);

    % 生成区域内的软排序对（无上下文）
    [XXs, Ps] = GetRegionSoftPairs_RegionalSR(Input, Info.localScoreMatrix(:,r), pool, ...
        'Alpha', alpha, 'MaxPairs', perModelPairs);

    % 划分训练集/测试集
    [TrainIn, TrainOut, TestIn, TestOut] = DataProcessSoft(XXs, Ps, 0.75);

    % 训练区域专用神经网络
    [net, mpStruct] = TrainSoftProbabilityNet_RegionalSR(TrainIn, TrainOut);

    % 选择区域锚点
    anchorIndex = SelectAnchorsForRegion_RegionalSR(Info.localScoreMatrix(:,r), pool, anchorNum);

    % 保存模型
    Models(end+1).region    = r;
    Models(end).net         = net;
    Models(end).mp_struct   = mpStruct;
    Models(end).anchorIndex = anchorIndex;
    Models(end).anchorNum   = numel(anchorIndex);
end
```

**关键区别：** 与 RegionalSR_A 不同，这里不传入 `Context` 参数给 `GetRegionSoftPairs_RegionalSR`，所以训练数据格式为 `[x_i, x_j]`（2D 维），不包含参考向量。

**步骤四：回退机制**

如果所有区域模型训练失败（样本太少），回退到训练一个基于最大区域的模型：
```matlab
if isempty(Models)
    fallbackRegion = SelectActiveRegions_RegionalSR(Info.region, 1);
    pool = (1:size(Input,1))';  % 使用所有样本
    % ... 训练一个全局回退模型
end
```

**步骤五：计算平均测试误差**
```matlab
pErr = mean(errList, 'omitnan');
```

### 3.4 区域感知的代理辅助选择

`RSurrogateAssistedSelection_RegionalSR_B` 使用所有局部模型的集成来评分候选解：

**步骤一：所有模型分别评分**

```matlab
for m = 1:numel(Models)
    anchorIndex = Models(m).anchorIndex(:);
    anchors = modelX(anchorIndex, :);

    % 构建测试对（无上下文）
    forwardPairs = [nextBlock, ancBlock];
    reversePairs = [ancBlock, nextBlock];

    % 用该区域的专用模型预测
    testPairsNor = mapminmax('apply', testPairs', Models(m).mp_struct)';
    prob = Models(m).net(testPairsNor')';

    % 计算区域分数
    pairScore = 0.5 .* (probForward + 1 - probReverse);
    regionScores(:, m) = mean(pairScore, 2);

    modelRegions(m) = Models(m).region;
end
```

**步骤二：取最佳区域分数**

```matlab
[scores, bestIdx] = max(regionScores, [], 2);
scores(~isfinite(scores)) = 0;
bestRegion = modelRegions(bestIdx)';
```

每个候选解取其在所有区域模型中的最高分数，同时记录最佳区域来源。

**步骤三：区域多样性选择**

```matlab
Next = SelectTopByRegion_RegionalSR(Next, scores, bestRegion, min(4, size(Next,1)));
```

与 RegionalSR_A 相同，使用 `SelectTopByRegion_RegionalSR` 确保最终选出的候选解来自不同区域。

### 3.5 模型结构体

每个局部模型保存以下信息：

```matlab
Models(m).region      = r;           % 区域编号
Models(m).net         = net;         % 训练好的神经网络
Models(m).mp_struct   = mpStruct;    % 归一化映射参数
Models(m).anchorIndex = anchorIndex; % 区域锚点的全局索引
Models(m).anchorNum   = numel(anchorIndex); % 锚点数量
```

---

## 4. 算法参数

| 参数 | 默认值 | 含义 |
|------|--------|------|
| `k` | 6 | 参考解数量（用于变异和环境选择） |
| `gmax` | 3000 | 每代代理辅助搜索的最大尝试次数 |
| `pairMax` | 12000 | 训练配对的最大数量（所有区域共享） |
| `alphaSoft` | 6 | Sigmoid 函数的陡峭系数 |
| `anchorNum` | 12 | 每个区域模型的锚点数量 |
| `Nref` | 100 | 参考向量数量 |
| `neighborNum` | 2 | 邻近区域扩展数量 |
| `maxModels` | 20 | 最大局部模型数量 |

**与 RegionalSR_A 的参数差异：**
- `maxRegions` → `maxModels`（语义相同，但 B 中每个区域对应一个独立模型）

---

## 5. 与 RegionalSR_A 的关键差异

| 特性 | RegionalSR_A | RegionalSR_B |
|------|-------------|-------------|
| 模型架构 | 1 个全局模型 | 多个局部模型（最多 20 个） |
| 训练对输入 | `[x_i, x_j, w_r]`（2D+M 维） | `[x_i, x_j]`（2D 维） |
| 区域区分 | 通过参考向量上下文隐式区分 | 通过不同模型显式区分 |
| 训练方式 | 一次训练，所有区域共享 | 每个区域独立训练 |
| 推理方式 | 一次推理，上下文切换 | 每个模型各推理一次 |
| 模型参数 | 共享 | 各区域独立 |
| 训练开销 | O(1) 次训练 | O(R) 次训练 |
| 推理开销 | O(1) 次推理 | O(R) 次推理 |
| 区域特化 | 受限于全局模型容量 | 高（专门模型） |
| 样本效率 | 高（所有区域共享数据） | 低（各区域数据独立） |

---

## 6. 设计优势

### 6.1 区域特化能力强

每个局部模型只学习一个区域的排序模式，不受其他区域的干扰。这对于高维目标空间中不同区域排序模式差异很大的情况特别有利。

### 6.2 输入维度更低

训练数据不需要包含参考向量上下文，输入维度为 2D（而非 2D+M）。当目标数 M 很大时，这可以减少模型复杂度和训练难度。

### 6.3 模型可解释性更好

每个模型对应一个明确的区域，可以独立评估其性能（测试误差）。如果某个区域的模型表现差，可以针对性地调整该区域的参数或策略。

### 6.4 天然支持并行化

各区域模型的训练完全独立，可以很容易地并行化以加速训练过程。

### 6.5 集成效果

多个模型的集成（取最佳分数）类似于机器学习中的 Ensemble 方法，可以提高预测的鲁棒性。

---

## 7. 可能风险与注意事项

### 7.1 训练开销增加

每个区域都需要独立训练一个神经网络，总训练时间是 RegionalSR_A 的 O(R) 倍。当活跃区域数量多时，这可能成为瓶颈。

**缓解措施：** `maxModels` 参数限制了最大模型数量（默认 20）。

### 7.2 区域样本不足

高维空间中参考向量数量多，每个区域的样本可能很少。样本不足会导致：
- 软排序对数量少，训练信号弱
- 模型过拟合
- 测试误差估计不可靠

**缓解措施：**
- 邻近区域扩展（`neighborNum`）
- 回退到全局模型
- 每个模型至少 30 对训练数据

### 7.3 模型数量爆炸

当参考向量数量很大（如 100）且大部分区域都有足够样本时，可能产生大量模型。这会显著增加推理时间和内存消耗。

**缓解措施：** `maxModels` 限制了最大模型数量，只选择样本最多的区域。

### 7.4 区域间信息不共享

每个模型独立训练，无法利用其他区域的信息。如果某些区域的样本很少，它们的模型质量会很差，但无法从邻近区域"借用"知识。

**与 RegionalSR_A 的对比：** A 的全局模型可以通过上下文在区域间共享知识。

### 7.5 推理开销

选择候选解时需要遍历所有模型，每个模型都要做一次完整的推理。当模型数量多时，推理时间可能很长。

---

## 8. 适用场景分析

### 8.1 RegionalSR_B 更适合的场景

- **目标数适中（5-10 个）**：区域数量适中，每个区域有足够样本
- **区域间差异大**：不同区域的排序模式差异显著，需要专门模型
- **计算资源充足**：可以承受多个模型的训练和推理开销
- **并行化环境**：可以利用多核/多 GPU 并行训练

### 8.2 RegionalSR_A 更适合的场景

- **目标数较多（10-20 个）**：区域数量多，每个区域样本少，需要共享数据
- **区域间有共性**：不同区域的排序模式有一定相似性，共享模型有益
- **计算资源有限**：只能承受一个模型的训练和推理开销
- **实时性要求高**：需要快速推理

---

## 9. 文件清单

| 文件名 | 功能 |
|--------|------|
| `REMO_new2_RegionalSR_B.m` | 主算法入口 |
| `TrainRegionalSoftModels_B.m` | 区域模型训练（核心创新） |
| `RSurrogateAssistedSelection_RegionalSR_B.m` | 区域模型集成选择 |
| `CreateReferenceVectors_RegionalSR.m` | 均匀参考向量生成（与 A 共享） |
| `BuildRegionalInfo_RegionalSR.m` | 区域信息构建（与 A 共享） |
| `SelectActiveRegions_RegionalSR.m` | 活跃区域选择（与 A 共享） |
| `ExpandRegionPool_RegionalSR.m` | 区域样本池扩展（与 A 共享） |
| `GetRegionSoftPairs_RegionalSR.m` | 区域内软排序对生成（与 A 共享） |
| `SelectAnchorsForRegion_RegionalSR.m` | 区域锚点选择（与 A 共享） |
| `TrainSoftProbabilityNet_RegionalSR.m` | 神经网络训练（与 A 共享） |
| `SelectTopByRegion_RegionalSR.m` | 区域多样性选择（与 A 共享） |
| `RefSelect.m` | RSEA 雷达网格环境选择（与 A 共享） |
| `DataProcessSoft.m` | 训练集/测试集划分（与 A 共享） |

---

## 10. 快速测试

```matlab
% 小预算烟雾测试（3 目标 DTLZ2）
[decs,objs,cons] = platemo(...
    'algorithm',{@REMO_new2_RegionalSR_B,6,3000,12000,6,12,100,2,20},...
    'problem',@DTLZ2,...
    'M',3,...
    'D',12,...
    'maxFE',50);
```

---

## 11. 三个算法的对比总结

| 特性 | TrueSR | RegionalSR_A | RegionalSR_B |
|------|--------|-------------|-------------|
| 排序范围 | 全局 | 区域（上下文） | 区域（独立模型） |
| 模型数量 | 1 | 1 | 多（最多 20） |
| 输入维度 | 2D | 2D+M | 2D |
| 区域区分 | 无 | 隐式（上下文） | 显式（不同模型） |
| 训练开销 | 低 | 中 | 高 |
| 推理开销 | 低 | 中 | 高 |
| 区域特化 | 无 | 中 | 高 |
| 样本效率 | 高 | 高 | 低 |
| 适用目标数 | 2-3 | 2-20 | 5-10 |
| 最佳场景 | 低维目标 | 高维目标 | 中等目标+区域差异大 |

---

## 12. 后续改进方向

### 12.1 模型管理策略

- **模型质量监控**：跟踪每个模型的测试误差，对误差大的模型降权或禁用
- **动态模型数量**：根据样本分布自适应调整活跃区域数量
- **模型更新策略**：保留上一代表现好的模型，只重新训练表现差的

### 12.2 区域间知识迁移

- **参数共享**：相邻区域的模型共享部分网络参数（如底层特征提取层）
- **迁移学习**：用邻近区域的模型参数初始化新区域的模型
- **集成学习**：不只是取最佳区域分数，而是加权融合多个区域的预测

### 12.3 计算效率优化

- **选择性重训练**：只重新训练样本变化大的区域的模型
- **模型缓存**：缓存上一代的模型，避免每代都重新训练
- **并行训练**：利用 MATLAB Parallel Computing Toolbox 并行训练多个模型

### 12.4 与 RegionalSR_A 的融合

设计一个自适应策略，根据问题特性和进化阶段动态选择使用 A 还是 B：
- 早期样本少时用 A（共享数据）
- 后期样本多时用 B（区域特化）
- 或者根据区域间差异度自动选择

---

## 13. 实验设计建议

### 13.1 消融实验

| 实验版本 | 目的 |
|---------|------|
| TrueSR | 全局排序 baseline |
| RegionalSR_A | 区域排序 + 上下文模型 |
| RegionalSR_B | 区域排序 + 独立模型 |
| RegionalSR_B (maxModels=5) | 验证模型数量的影响 |
| RegionalSR_B (maxModels=50) | 验证更多模型是否有益 |

### 13.2 参数敏感性

优先测试：
- `maxModels` = {5, 10, 20, 50}
- `Nref` = {50, 100, 200}
- `neighborNum` = {1, 2, 3, 5}

### 13.3 测试问题

建议使用标准 benchmark：
- DTLZ1-DTLZ7（3-10 目标）
- MaF1-MaF10（3-10 目标）
- 实际工程问题（如有）

### 13.4 评价指标

- HV（Hypervolume）
- IGD（Inverted Generational Distance）
- 运行时间
- 每代模型数量
- 每个区域模型的测试误差分布
