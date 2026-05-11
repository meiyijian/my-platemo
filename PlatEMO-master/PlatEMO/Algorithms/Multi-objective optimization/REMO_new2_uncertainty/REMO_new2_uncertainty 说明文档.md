# REMO_new2_uncertainty 说明文档

## 1. 概述

`REMO_new2_uncertainty` 是在 `REMO_new2` 基础上引入**双层不确定性分析**的算法变体，用于处理昂贵多目标优化中的模型预测不确定性问题。

核心思想：不仅学习解之间的优劣关系，还量化模型对每对关系预测的置信度，在选择阶段优先选择"模型确信且优质"的解，同时适度探索"模型不确定但可能好"的解。

---

## 2. 改动来源与动机

### 2.1 训练阶段：置信度加权训练

| 项目 | 内容 |
|------|------|
| **来源** | `REMO_new2_confidence` 变体 |
| **参考文件** | `REMO_new2_confidence/GetRelationPairs_confidence.m`、`REMO_new2_confidence/DataProcess_confidence.m` |
| **动机** | 原版 REMO_new2 中 `HybridPBI_Classification` 已计算每个解的置信度 `confidence = 1 - |score_v - label_dyn|`，但未使用。REMO_new2_confidence 验证了利用该信号对关系对样本加权训练的有效性。 |
| **原理** | 每对关系的权重 = 两端解置信度的几何平均 `sqrt(conf_i * conf_j)`，体现"两端都确定则关系越可靠"。训练时通过 patternnet 的 Error Weights (EW) 参数对损失加权，让网络更关注高置信度样本。 |
| **改动** | 直接复用 `GetRelationPairs_confidence.m` 和 `DataProcess_confidence.m`，不修改。 |

### 2.2 选择阶段：预测概率信息熵

| 项目 | 内容 |
|------|------|
| **来源** | R2AEA 算法的 `RMOselect.m` 第 155-199 行 |
| **参考文件** | `R2AEA/RMOselect.m` |
| **动机** | 代理模型（神经网络）对不同候选解的预测置信度不同。如果模型对某个候选解与好解/差解的关系预测概率分布接近均匀（熵高），说明模型不确定，此时选择该解存在风险。 |
| **原理** | 对每组配对（C1Xi、XiC1、C2Xi、XiC2）的预测概率分布计算信息熵 `H = -sum(p .* log2(p))`，累加得到每个候选解的总不确定性。熵越高，模型越不确定。 |
| **改动** | 在 `model_select_uncertainty.m` 中实现，新增 `C_SCORE(2)` 累积信息熵。 |

### 2.3 选择阶段：置信度加权聚合

| 项目 | 内容 |
|------|------|
| **来源** | `REMO_C2RL` 算法的 `model_select_confidence.m` |
| **参考文件** | `REMO_C2RL/model_select_confidence.m` |
| **动机** | 原版 REMO_new2 的 `model_select` 对每组配对的预测概率做简单算术平均。但不同配对的预测置信度不同，低置信度预测应被弱化。 |
| **原理** | 对每组配对的原始预测 `pre_out_raw`，先计算每对置信度 `w = max(pre_out_raw, [], 2)`（softmax 最大概率），再做加权平均 `pre = sum(pre_out_raw .* w) / sum(w)`。 |
| **改动** | 在 `model_select_uncertainty.m` 中替换原版的简单算术平均。 |

### 2.4 选择阶段：UCB 自适应探索

| 项目 | 内容 |
|------|------|
| **来源** | Multi-Armed Bandit 的 UCB (Upper Confidence Bound) 策略 + R2AEA 的得分设计 |
| **参考文件** | `R2AEA/RMOselect.m` 第 195 行 `selectscores(i) = C_SCORE(1) - C_SCORE(2)` |
| **动机** | 需要在"利用"（选高分低不确定性解）和"探索"（选高不确定性解）之间平衡。进化早期应多探索，后期应多利用。 |
| **原理** | 综合得分 `score_aug = scores + lambda * uncertainty`，其中 `lambda = lambda0 * (1 - ratio)`。初期 lambda 大，鼓励探索高不确定性区域；后期 lambda 小，侧重高置信度高得分解。 |
| **改动** | 在 `RSurrogateAssistedSelection_uncertainty.m` 的最终选择阶段实现。 |

### 2.5 选择阶段：自适应分位数阈值

| 项目 | 内容 |
|------|------|
| **来源** | `REMO_MaO` 的 `RSurrogateAssistedSelection_v2.m` |
| **参考文件** | `REMO_MaO/RSurrogateAssistedSelection_v2.m` |
| **动机** | 原版 REMO_new2 使用硬编码阈值 `>3.9`，在不同问题上可能不够灵活。 |
| **原理** | 使用 `quantile(score_aug, q_keep)` 作为阈值，q_keep=0.70 表示取 top 30% 的解。输出数量 4-8 个（替代固定 4 个）。 |
| **改动** | 在 `RSurrogateAssistedSelection_uncertainty.m` 中替换硬编码阈值。 |

---

## 3. 文件清单

### 3.1 新建文件（3个）

| 文件 | 行数 | 说明 |
|------|------|------|
| `REMO_new2_uncertainty.m` | ~95 | 主算法文件，整合置信度加权训练和不确定性选择 |
| `model_select_uncertainty.m` | ~110 | 核心打分函数，融合信息熵 + 置信度加权 |
| `RSurrogateAssistedSelection_uncertainty.m` | ~55 | 代理辅助选择包装，含 UCB 策略 |

### 3.2 复用文件（7个，来自 REMO_new2_confidence）

| 文件 | 说明 |
|------|------|
| `HybridPBI_Classification.m` | HPC 混合 PBI 分类器（输出 confidence） |
| `GetOutput_PBI.m` | PBI 阈值划分动态标签 |
| `GetRelationPairs_confidence.m` | 置信度加权关系对构造 |
| `DataProcess_confidence.m` | 带权重的数据集划分 |
| `RefSelect.m` | 参考解选择（RSEA 策略） |
| `onehotconv.m` | one-hot 编码/解码 |
| `Delequalsamples.m` | 删除等价样本（备用） |

---

## 4. 参数说明

| 参数 | 默认值 | 含义 | 来源 |
|------|--------|------|------|
| `k` | 6 | 动态参考解数量 | 原版 REMO_new2 |
| `gmax` | 3000 | GA 内循环代理评估上限 | 原版 REMO_new2 |
| `lambda0` | 0.5 | UCB 不确定性初始权重 | R2AEA/C2RL 验证值 |
| `q_keep` | 0.70 | 最终筛选分位数阈值 | REMO_MaO |
| `w_min` | 0.3 | 样本权重下限 | REMO_new2_confidence |

Lambda 衰减公式：`lambda = lambda0 * (1 - ratio)`

| 进化进度 | lambda | 行为倾向 |
|----------|--------|----------|
| 0% (初期) | 0.50 | 鼓励探索高不确定性区域 |
| 50% (中期) | 0.25 | 平衡探索与利用 |
| 90% (后期) | 0.05 | 侧重高置信度高得分解 |

---

## 5. 算法流程图

```
初始化种群 (拉丁超立方采样)
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  while 未达评估预算                                    │
│    │                                                  │
│    ▼                                                  │
│  HybridPBI_Classification ──► Catalog, confidence, Ref│
│    │                                                  │
│    ▼                                                  │
│  GetRelationPairs_confidence ──► XXs, YYs, WWs        │
│    │  (几何平均权重: sqrt(conf_i * conf_j))            │
│    ▼                                                  │
│  DataProcess_confidence ──► TrainIn/Out/W, TestIn/Out │
│    │                                                  │
│    ▼                                                  │
│  训练 patternnet (EW 加权损失) ──► net                 │
│    │                                                  │
│    ▼                                                  │
│  RSurrogateAssistedSelection_uncertainty:              │
│    │  GA内循环: model_select_uncertainty (纯性能排序)   │
│    │  最终选择: score_aug = scores + lambda*uncertainty │
│    │  阈值: quantile(score_aug, q_keep)                │
│    ▼                                                  │
│  Problem.Evaluation(Next) ──► Archive                  │
│    │                                                  │
│    ▼                                                  │
│  RefSelect(Archive, N) ──► Population                 │
│  end while                                            │
└─────────────────────────────────────────────────────┘
```

---

## 6. 与原版 REMO_new2 的关键区别

| 维度 | REMO_new2 | REMO_new2_uncertainty |
|------|-----------|----------------------|
| confidence 使用 | 计算但未使用 | 用于训练阶段样本加权 |
| 关系对权重 | 无 | 几何平均置信度权重 |
| 训练损失 | 无权重 | EW 加权损失 |
| 预测聚合 | 简单算术平均 | 置信度加权平均 |
| 不确定性度量 | 无 | 预测概率信息熵 |
| 最终选择 | 硬阈值 >3.9 | UCB + 自适应分位数 |
| 输出解数 | 固定 4 个 | 4-8 个 |

---

## 7. 测试建议

1. **功能验证**：在 PlatEMO GUI 中运行，选择 DTLZ2 (M=3, D=10)，观察是否正常终止
2. **对比实验**：与原版 REMO_new2 在相同问题、相同种子下对比 IGD/HV 指标
3. **消融实验**：
   - lambda=0 vs lambda=0.5：验证不确定性引导探索的效果
   - 无 EW 加权 vs 有 EW 加权：验证置信度加权训练的效果
4. **测试问题集**：DTLZ{1,2,4,5,6,7} (M=3,5,10) + WFG{1,4,8} (M=3,5)

---

## 8. 参考文献

1. REMO: Expensive multiobjective optimization by relation learning and prediction (2022)
2. R2AEA: Regression and Relation-Assisted Evolutionary Algorithm (Swarm and Evolutionary Computation, 2025)
3. PlatEMO: A MATLAB platform for evolutionary multi-objective optimization (IEEE CIM, 2017)
