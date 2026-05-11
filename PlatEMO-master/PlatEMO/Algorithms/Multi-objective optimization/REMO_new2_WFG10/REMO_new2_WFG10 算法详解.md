# REMO_new2_WFG10 算法详解

## 一、算法背景与定位

REMO_new2_WFG10 是在 REMO_new2 基础上专门针对 **10 目标 WFG 问题** 调优的变体。WFG（Walking Fish Group）系列是多目标优化领域的标准测试集，10 目标场景属于"高维多目标"（many-objective），对算法提出了特殊挑战：

- 参考向量难以均匀覆盖真实 Pareto 前沿
- 代理模型的分类置信度参差不齐
- 候选解容易在决策空间中聚集

本变体保留了 REMO_new2 的混合 PBI 分类框架，添加了三个**保守改进**：

| 改进 | 对应模块 | 核心思想 |
|------|---------|---------|
| 置信度加权训练 | `GetRelationPairs_confidence` + `DataProcess_confidence` | 让高置信度样本对模型影响更大 |
| 自适应参考解数量 | 主循环 `k_eff` 计算 | 高维目标需要更多参考解 |
| 不确定性/多样性感知选择 | `RSurrogateAssistedSelection` | 避免候选解聚集，平衡探索与开发 |

### 适用场景

| 场景维度 | 适用范围 |
|---------|---------|
| 决策变量维度 D | 任意（D≤10 时 N=11D-1，否则 N=100） |
| 目标维度 M | 高维多目标（many-objective，≥10） |
| 评估代价 | 昂贵（expensive），评估次数受预算限制 |
| 标签 | `<multi/many> <real> <expensive>` |

---

## 二、文件组成与依赖关系

```
REMO_new2_WFG10.m  (主入口)
├── HybridPBI_Classification.m        混合分类，输出好/坏标签、置信度、参考解
│   ├── UniformPoint                   （PlatEMO 公共函数）
│   ├── NDSort                         （PlatEMO 公共函数）
│   ├── kmeans                         （MATLAB 内置）
│   ├── RefSelect.m                    动态参考解选择（RSEA 策略）
│   └── GetOutput_PBI.m                PBI 阈值划分动态标签
├── GetRelationPairs_confidence.m     【新增】带置信度权重的关系对生成
├── GetRelationPairs.m                原始关系对生成（备用，主流程未调用）
├── DataProcess_confidence.m          【新增】带权重的数据集划分
├── DataProcess.m                     原始数据集划分（备用，主流程未调用）
├── onehotconv.m                      one-hot 编码/解码
├── patternnet / train                （MATLAB 神经网络工具箱）
├── RSurrogateAssistedSelection.m     【改进】代理模型辅助选择（含不确定性+多样性）
└── Delequalsamples.m                 删除等价样本（备用，主流程未调用）
```

---

## 三、整体流程

### 3.1 主循环伪代码

```
输入: 问题 Problem, 参数 k=6, gmax=3000, q_keep=0.80, lambda0=0.35, w_min=0.30, n_min=4, n_max=6

1. 初始化:
   N = (D≤10 ? 11D-1 : 100)
   PopDec ← 拉丁超立方采样
   Population ← 真实评估初始种群
   Archive ← Population

2. while 未达到评估预算:
   2.1 ratio = FE / maxFE                    // 进化比例
   2.2 k_eff = min(N, max(k, ceil(1.5*M)))   // 自适应参考解数量
   2.3 HPC 混合分类 → Catalog, confidence, Ref
   2.4 GetRelationPairs_confidence → XXs, YYs, WWs  // 带权重的关系对
   2.5 DataProcess_confidence → TrainIn, TrainOut, TrainW, TestIn, TestOut
   2.6 训练 patternnet（带样本权重 EW）
   2.7 测试集评估 → p_err
   2.8 RSurrogateAssistedSelection → Next（含不确定性+多样性选择）
   2.9 if Next 为空: GA 备选方案
   2.10 真实评估 Next → Archive
   2.11 RefSelect(Archive, N) → Population    // 环境选择

3. 输出 Archive
```

### 3.2 流程图

```
        ┌──────────────────────┐
        │   拉丁超立方采样初始化  │
        └──────────┬───────────┘
                   ▼
        ┌──────────────────────┐
   ┌───►│  HPC 混合分类（打分）  │
   │    │  产生 Catalog, conf  │
   │    │  & Ref (自适应数量)   │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 关系对生成(带置信度)   │
   │    │ GetRelationPairs_    │
   │    │ confidence → XXs,    │
   │    │ YYs, WWs             │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 数据划分(带权重)      │
   │    │ DataProcess_         │
   │    │ confidence           │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ patternnet 训练      │
   │    │ (样本加权 EW)        │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 代理辅助 GA 搜索     │
   │    │ + 不确定性感知打分    │
   │    │ + 多样性选择          │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │   真实评估候选解       │
   │    │   Archive 累积        │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   └────┤  RefSelect 环境选择   │
        │  产生下一代 Population │
        └──────────────────────┘
```

---

## 四、与 REMO_new2 的关键差异

### 4.1 差异总览

| 维度 | REMO_new2 | REMO_new2_WFG10 |
|------|----------|-----------------|
| 关系对生成 | `GetRelationPairs`（无权重） | `GetRelationPairs_confidence`（带置信度权重） |
| 数据划分 | `DataProcess`（无权重） | `DataProcess_confidence`（同步划分权重） |
| 神经网络训练 | 等权训练 | 样本加权训练（EW 权重） |
| 参考解数量 | 固定 k=6 | 自适应 k_eff = min(N, max(k, ceil(1.5*M))) |
| 候选解筛选 | 固定阈值 3.9 | 分位数 q_keep + 不确定性加权 |
| 候选解数量 | 无上下限 | n_min=4, n_max=6 约束 |
| 多样性选择 | 无 | 贪心最大化最小距离 |
| 超参数数量 | 2 个 (k, gmax) | 7 个 (+q_keep, lambda0, w_min, n_min, n_max) |

### 4.2 改进一：置信度加权关系对训练

**问题**：原始 REMO_new2 中所有关系对样本被等权对待，但 HPC 分类输出的 confidence 信号表明某些解的分类更可靠（两个信号一致），某些更模糊（两个信号矛盾）。

**改进**：
1. `GetRelationPairs_confidence` 为每对样本生成权重 = sqrt(conf_i * conf_j)（几何平均）
2. `DataProcess_confidence` 同步划分权重到训练集/测试集
3. 训练时将权重 EW 归一化后传入 `train(net, ..., EW)`，让高置信度样本对梯度贡献更大

**效果**：模型更信任"两端都确定"的关系对，减少模糊样本对模型的干扰。

### 4.3 改进二：自适应参考解数量

**问题**：10 目标问题中，固定 k=6 个参考解不足以覆盖高维 Pareto 前沿。

**改进**：`k_eff = min(Problem.N, max(k, ceil(1.5*Problem.M)))`

- 10 目标时 k_eff = min(N, max(6, 15)) = min(N, 15)
- 比固定的 6 个参考解多出 2.5 倍覆盖

**效果**：更充分地采样 Pareto 前沿的不同区域。

### 4.4 改进三：不确定性/多样性感知的候选解选择

**问题**：原始 REMO_new2 用固定阈值 3.9 筛选候选解，可能导致：
- 候选解数量不可控（可能极少或极多）
- 候选解在决策空间中聚集（都落在同一局部区域）

**改进**：

1. **分位数筛选**：保留 score_aug 前 q_keep (80%) 比例的候选，替代固定阈值
2. **不确定性加权得分**：`score_aug = score_n + lambda_t * unc_n`
   - `unc_n` = 1 - 平均预测置信度（网络输出最大概率越低，不确定性越高）
   - `lambda_t` 随进化递减（早期鼓励探索，后期侧重开发）
3. **多样性选择**：贪心最大化最小距离
   - 每次选 score 最高的候选
   - 后续选择综合考虑得分和与已选解的距离
   - `acq = 0.75 * score_norm + 0.25 * dist_norm`

**效果**：候选解既高分又分散，避免聚集在单一区域。

---

## 五、关键模块详解

### 5.1 GetRelationPairs_confidence（带置信度的关系对生成）

在原 `GetRelationPairs` 基础上，为每对样本生成权重。

**权重计算**：
```
W(C1C1 对) = sqrt(conf_i * conf_j)   // 好-好对
W(C2C2 对) = sqrt(conf_i * conf_j)   // 坏-坏对
W(C1C2 对) = sqrt(conf_i * conf_j)   // 好-坏对
W(C2C1 对) = sqrt(conf_i * conf_j)   // 坏-好对
```

几何平均的含义：只有两端解都高置信时，这对关系才被赋予高权重。

### 5.2 DataProcess_confidence（带权重的数据划分）

在原 `DataProcess` 基础上，同步划分权重向量。

```matlab
pha = 3/4
对每个类别 (0, +1, -1):
    随机抽 ceil(pha * 类内样本数) 进入训练集
    剩下 1/4 进入测试集
    权重同步按相同索引划分
最后整体打乱顺序（训练集和测试集分别打乱）
```

### 5.3 RSurrogateAssistedSelection（代理辅助选择，改进版）

**主流程**：

```
Next = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5})   // 初始 GA 子代
i = 0
while i < gmax:
    [sorted_idx, ~] = model_select(Smodel, Next)             // 神经网络打分
    keepNum = min(|Ref|, |Next|)                              // 自适应保留数量
    Input = Next(sorted_idx(1:keepNum), :)
    Next = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5})
    i = i + |Next|

最后:
    [~, scores, uncertainty] = model_select(Smodel, Next)    // 返回不确定性
    score_n = norm01(scores)                                  // 归一化得分
    unc_n = norm01(uncertainty)                               // 归一化不确定性
    lambda_t = lambda0 * (1-ratio) * max(0, 1 - p_err/0.45)  // 自适应权重
    score_aug = score_n + lambda_t * unc_n                    // 增强得分

    threshold = quantile(score_aug, q_keep)                   // 分位数阈值
    cand_idx = score_aug >= threshold                         // 候选集合

    若 |cand_idx| < n_min: 取得分最高的 n_min 个
    n_eval = min(n_max, max(n_min, |cand_idx|))

    diversity_select → 最终候选                                 // 多样性选择
```

**model_select 内部**（与 REMO_new2 相同的打分机制，但新增不确定性输出）：

```
对每个候选 Xi:
    构造 4 类样本对: [C1,Xi], [Xi,C1], [C2,Xi], [Xi,C2]
    网络预测每对的概率 [p+1, p0, p-1]
    加权平均（用 pair_conf 加权）
    累加打分规则 → scores(i)
    uncertainty(i) = 1 - mean(所有对的预测置信度)
```

**lambda_t 的含义**：
- `lambda0` = 0.35（基础系数）
- `(1-ratio)`：随进化递减（早期大，鼓励探索不确定性高的区域）
- `max(0, 1 - p_err/0.45)`：模型越准（p_err 小），越信任不确定性信号

### 5.4 diversity_select（多样性选择）

贪心策略：每次选一个候选加入已选集合，选择标准综合考虑得分和距离。

```
1. 先选 score_aug 最高的候选
2. 循环直到选满 n_eval 个:
   对剩余候选 j:
     dist_to_selected = min(||Next_j - 已选集合||)   // 到最近已选解的距离
     acq_j = 0.75 * score_norm(j) + 0.25 * dist_norm(j)
   选 acq 最大的 j 加入已选集合
```

0.75:0.25 的权重分配表明以得分为主，多样性为辅。

### 5.5 HybridPBI_Classification（混合 PBI 分类）

与 REMO_new2 完全相同，此处简述：

1. 自适应参考向量场（K-means 聚类非支配解，或均匀向量）
2. PBI 距离计算全局得分 score_v
3. 动态参考解标签 label_dyn（GetOutput_PBI）
4. 融合：score_hybrid = (1-ratio) * score_v + ratio * label_dyn
5. 置信度：confidence = 1 - |score_v - label_dyn|
6. 按 score_hybrid 排序，前 N/4 为好解，后 N/4 为坏解

### 5.6 RefSelect（参考解选择，RSEA 策略）

与 REMO_new2 完全相同：

1. NDSort 非支配排序
2. 目标值归一化
3. 识别极端解
4. 雷达网格映射
5. 迭代填充：最稀疏网格中选收敛性+距离综合最优者

---

## 六、关键超参数与数据流

### 6.1 算法超参数

| 参数 | 默认值 | 含义 | 对比 REMO_new2 |
|------|--------|------|---------------|
| k | 6 | 参考解数量基数 | 相同 |
| gmax | 3000 | 内层 GA 累计样本上限 | 相同 |
| q_keep | 0.80 | 候选筛选分位数 | **新增** |
| lambda0 | 0.35 | 不确定性权重基础系数 | **新增** |
| w_min | 0.30 | 样本权重下限 | **新增** |
| n_min | 4 | 每轮最少评估数 | **新增** |
| n_max | 6 | 每轮最多评估数 | **新增** |
| theta (θ) | 5 | PBI 惩罚系数 | 相同 |
| Nref | N | 参考向量个数 | 相同 |
| pha | 3/4 | 训练集占比 | 相同 |

### 6.2 主要数据结构

| 名称 | 维度 | 说明 | 对比 REMO_new2 |
|------|------|------|---------------|
| confidence | N×1 | 每个解的分类置信度 | 相同 |
| WWs | n_pair×1 | 关系对样本权重 | **新增** |
| TrainW | n_train×1 | 训练集样本权重 | **新增** |
| EW | 1×n_train | 归一化后的训练权重 | **新增** |
| uncertainty | |Next|×1 | 候选解的模型不确定性 | **新增** |
| score_aug | |Next|×1 | 增强得分（得分+不确定性） | **新增** |

---

## 七、改进动机总结

### 7.1 为什么需要置信度加权？

在 HPC 分类中，有些解的 score_v 和 label_dyn 信号一致（高置信度），有些矛盾（低置信度）。低置信度样本的关系标签可能是噪声。等权训练会让噪声样本拉偏模型，加权训练则让模型更关注"确定"的关系。

### 7.2 为什么需要自适应参考解数量？

10 目标问题的 Pareto 前沿是 9 维超曲面，6 个参考解远远不够。1.5*M = 15 个参考解能更均匀地覆盖前沿不同区域，提高分类的准确性。

### 7.3 为什么需要不确定性+多样性选择？

固定阈值 3.9 是在低维目标下调的经验值，10 目标时分数分布可能完全不同。分位数筛选更鲁棒。不确定性加权让算法在模型不够确信的区域多探索。多样性选择防止候选解聚集在同一区域，浪费评估预算。

---

## 八、复杂度分析

设 N 为种群规模，D 为决策变量维度，M 为目标维度，G 为代理辅助选择内层迭代数（≈ gmax/N）。

| 模块 | 复杂度 |
|------|--------|
| HybridPBI_Classification | O(N·M·Nref + N²) （含 K-means） |
| GetRelationPairs_confidence | O((|C1|+|C2|)²·D) ≈ O(N²·D) |
| 神经网络训练 | 与 patternnet 实现相关，单 epoch O(n_pair·xDim·hidden) |
| RSurrogateAssistedSelection | O(G · |Next| · (|C1|+|C2|) · D) |
| diversity_select | O(n_eval · |cand_idx| · D) |
| RefSelect 环境选择 | O(|Archive|² · M) |

---

## 九、典型调用示例

```matlab
platemo('algorithm', @REMO_new2_WFG10, ...
        'problem',   @WFG10, ...
        'N',         100, ...
        'M',         10, ...
        'D',         20, ...
        'maxFE',     500);
```

---

## 十、参考文献

1. Hao H, Zhou A, Qian H, et al. Expensive multiobjective optimization by relation learning and prediction. IEEE Transactions on Evolutionary Computation, 2022.
2. Tian Y, Cheng R, Zhang X, He C, Jin Y. Guiding evolutionary multiobjective optimization with generic front modeling. IEEE Transactions on Cybernetics, 2020.（RSEA 雷达网格策略）
3. Zhang Q, Li H. MOEA/D: A multiobjective evolutionary algorithm based on decomposition. IEEE Transactions on Evolutionary Computation, 2007.（PBI 分解原理）
4. Tian Y, Cheng R, Zhang X, Jin Y. PlatEMO: A MATLAB platform for evolutionary multi-objective optimization. IEEE Computational Intelligence Magazine, 2017, 12(4): 73–87.
