# REMO_new2_AdaMaO 算法详解

## 一、算法背景与定位

REMO_new2_AdaMaO（Adaptive Many-objective Algorithm）是 REMO_new2_WFG10 的**自适应版本**，专门针对高维多目标优化问题设计。它的核心创新在于：**根据运行时诊断结果，动态切换不同的训练和选择策略**。

### 1.1 算法定位

| 场景维度       | 适用范围                                  |
| -------------- | ----------------------------------------- |
| 决策变量维度 D | 任意（D≤10 时 N=11D-1，否则 N=100）      |
| 目标维度 M     | 多目标 / 高维多目标（many-objective）     |
| 评估代价       | 昂贵（expensive），真实评估次数受预算限制 |
| 标签           | `<multi/many> <real> <expensive>`       |

### 1.2 设计动机

在高维多目标优化中，不同的进化阶段和种群状态需要不同的策略：

| 阶段     | 特征                       | 最优策略                           |
| -------- | -------------------------- | ---------------------------------- |
| 早期探索 | 模型不精确，种群分散       | 保守模式，避免过度依赖不确定的模型 |
| 中期开发 | 模型逐渐精确，种群开始聚集 | 加权模式，利用置信度信息           |
| 后期精细 | 模型精确，种群高度聚集     | 指标模式，使用 PIEA 的指标思想     |

REMO_new2_AdaMaO 通过**运行时诊断**自动判断当前状态，选择最合适的策略。

---

## 二、文件组成与依赖关系

```
REMO_new2_AdaMaO.m  (主入口)
├── HybridPBI_Classification.m        混合分类，输出好/坏标签、置信度、参考解
│   ├── UniformPoint                   （PlatEMO 公共函数）
│   ├── NDSort                         （PlatEMO 公共函数）
│   ├── kmeans                         （MATLAB 内置）
│   ├── RefSelect.m                    动态参考解选择（RSEA 策略）
│   └── GetOutput_PBI.m                PBI 阈值划分动态标签
├── GetRelationPairs_confidence.m     【来自 WFG10】带置信度权重的关系对生成
├── GetRelationPairs.m                【来自 REMO_new2】原始关系对生成
├── DataProcess_confidence.m          【来自 WFG10】带权重的数据集划分
├── DataProcess.m                     【来自 REMO_new2】原始数据集划分
├── onehotconv.m                      one-hot 编码/解码
├── patternnet / train                （MATLAB 神经网络工具箱）
├── AdaMaOSelection.m                 【新增】自适应候选解选择（三种模式）
├── IndicatorSelector.m               【新增】PIEA 风格的指标轮盘选择
├── UpdateInformation.m               【新增】指标轮盘的反馈更新
├── Shape_Estimate.m                  【新增】PF 形状参数 Lp 估计
├── calFitness_SDE.m                  【新增】SDE 移位密度估计
├── calFitness_epsilon.m              【新增】I_epsilon+ 不可加性指标
├── calFitness_MD.m                   【新增】Minkowski 距离指标
├── NDSort_SDR.m                      【新增】强支配关系非支配排序
└── Delequalsamples.m                 删除等价样本（备用）
```

---

## 三、整体流程

### 3.1 主循环伪代码

```
输入: 问题 Problem, 参数 k=6, gmax=3000, q_keep=0.80, lambda0=0.35, w_min=0.30,
      n_min=4, n_max=6, tau_err=0.35, use_indicator=1, debug=0

1. 初始化:
   N = (D≤10 ? 11D-1 : 100)
   PopDec ← 拉丁超立方采样
   Population ← 真实评估初始种群
   Archive ← Population
   初始化指标轮盘（SDE, I_epsilon+, Minkowski 各 1/3 概率）

2. while 未达到评估预算:
   2.1 ratio = FE / maxFE
   2.2 k_eff = min(N, max(k, ceil(1.5*M)))   // 自适应参考解数量
   2.3 HPC 混合分类 → Catalog, confidence, Ref
   2.4 运行时诊断 → coverage, degeneracy

   2.5 【动态选择关系对模式】
       if prev_p_err > tau_err:
           relation_mode = 'curriculum'    // 课程学习：只用高置信度样本
       elif p_err <= tau_err && mean_conf >= 0.55 && coverage < 0.60:
           relation_mode = 'weighted'      // 加权：用置信度加权
       else:
           relation_mode = 'conservative'  // 保守：原始方法

   2.6 根据 relation_mode 生成关系对 → XXs, YYs, WWs

   2.7 训练关系预测模型 → net, p_err

   2.8 【可选】指标轮盘选择 → Fitness, indicator_flag, Lp
       训练 SVR 指标模型 → IndicatorModel

   2.9 【动态选择候选解模式】
       if 有指标模型 && p_err <= tau_err && degeneracy >= 0.45:
           candidate_mode = 'indicator'    // 指标模式
       elif p_err <= tau_err && coverage < 0.60:
           candidate_mode = 'explore'      // 探索模式
       else:
           candidate_mode = 'conservative' // 保守模式

   2.10 AdaMaOSelection → Next（根据 candidate_mode 选择策略）

   2.11 真实评估 Next → Archive

   2.12 【可选】指标反馈 → 更新指标轮盘概率

   2.13 RefSelect(Archive, N) → Population

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
   │    │     运行时诊断        │
   │    │  coverage, degeneracy │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────────────────────┐
   │    │     动态选择关系对模式                 │
   │    │  conservative / curriculum / weighted │
   │    └──────────┬───────────────────────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 关系对生成(按模式)    │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 训练关系预测模型      │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 【可选】指标轮盘选择  │
   │    │ 训练 SVR 指标模型    │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────────────────────┐
   │    │     动态选择候选解模式                 │
   │    │  conservative / explore / indicator   │
   │    └──────────┬───────────────────────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ AdaMaOSelection      │
   │    │ (根据模式选择候选)    │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │   真实评估候选解       │
   │    │   Archive 累积        │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 【可选】指标反馈      │
   │    │ 更新指标轮盘概率      │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   └────┤  RefSelect 环境选择   │
        │  产生下一代 Population │
        └──────────────────────┘
```

---

## 四、三算法对比

### 4.1 差异总览

| 维度         | REMO_new2                      | REMO_new2_WFG10                             | REMO_new2_AdaMaO                                     |
| ------------ | ------------------------------ | ------------------------------------------- | ---------------------------------------------------- |
| 关系对生成   | `GetRelationPairs`（无权重） | `GetRelationPairs_confidence`（固定加权） | **动态选择**：conservative/curriculum/weighted |
| 数据划分     | `DataProcess`（无权重）      | `DataProcess_confidence`（固定加权）      | **动态选择**：根据 relation_mode               |
| 神经网络训练 | 等权训练                       | 固定样本加权训练                            | **动态选择**：根据是否有权重                   |
| 参考解数量   | 固定 k=6                       | 自适应 k_eff                                | 自适应 k_eff（相同）                                 |
| 候选解筛选   | 固定阈值 3.9                   | 分位数 + 不确定性                           | **动态选择**：conservative/explore/indicator   |
| 候选解数量   | 无上下限                       | n_min, n_max 约束                           | n_min, n_max 约束（相同）                            |
| 多样性选择   | 无                             | 贪心最大化最小距离                          | 贪心最大化最小距离（相同）                           |
| 指标选择     | 无                             | 无                                          | **新增**：PIEA 风格的指标轮盘选择              |
| 运行时诊断   | 无                             | 无                                          | **新增**：coverage, degeneracy                 |
| Lp 形状估计  | 无                             | 无                                          | **新增**：Shape_Estimate                       |
| 超参数数量   | 2 个                           | 7 个                                        | 10 个                                                |

### 4.2 改进一：运行时诊断

**问题**：WFG10 版本使用固定策略，无法根据种群状态调整。

**改进**：新增 `RuntimeDiagnostics` 函数，计算两个指标：

| 指标           | 含义                  | 计算方法                         |
| -------------- | --------------------- | -------------------------------- |
| `coverage`   | 参考向量覆盖率（0~1） | 种群中有多少参考方向被"覆盖"     |
| `degeneracy` | 种群退化度（0~1）     | SVD 分析种群是否集中在低维子空间 |

**决策逻辑**：

```matlab
% 关系对模式选择
if prev_p_err > tau_err
    relation_mode = 'curriculum';    // 模型不精确，用课程学习
elseif prev_p_err <= tau_err && mean_conf >= 0.55 && coverage < 0.60
    relation_mode = 'weighted';      // 模型精确但覆盖不足，用加权
else
    relation_mode = 'conservative';  // 默认保守
end

% 候选解模式选择
if use_indicator && p_err <= tau_err && degeneracy >= 0.45
    candidate_mode = 'indicator';    // 种群退化，用指标选择
elseif p_err <= tau_err && coverage < 0.60
    candidate_mode = 'explore';      // 覆盖不足，鼓励探索
else
    candidate_mode = 'conservative'; // 默认保守
end
```

### 4.3 改进二：三种关系对模式

| 模式             | 函数                            | 特点                         | 适用条件           |
| ---------------- | ------------------------------- | ---------------------------- | ------------------ |
| `conservative` | `GetRelationPairs`            | 原始方法，无权重             | 默认模式           |
| `curriculum`   | `GetRelationPairs_curriculum` | 只保留高置信度样本（前 80%） | 模型误差大         |
| `weighted`     | `GetRelationPairs_confidence` | 置信度加权                   | 模型精确且覆盖不足 |

**课程学习模式设计动机**：

课程学习（Curriculum Learning）是一种训练策略：先用"简单"样本训练，再逐步引入"难"样本。在本算法中：

- "简单"样本 = 高置信度样本（分类明确）
- "难"样本 = 低置信度样本（分类模糊）

当模型精度不高时，低置信度样本可能是噪声，会干扰训练。此时只用高置信度样本训练，等模型变精确后再引入更多样本。

### 4.4 改进三：三种候选解选择模式

| 模式             | 函数                    | 特点                          | 适用条件           |
| ---------------- | ----------------------- | ----------------------------- | ------------------ |
| `conservative` | `select_conservative` | 仅用关系得分，选 n_min 个     | 默认模式           |
| `explore`      | `select_explore`      | 关系得分 + 不确定性 + 多样性  | 模型精确但覆盖不足 |
| `indicator`    | `select_indicator`    | 关系得分粗筛 + SVR 指标重排序 | 种群退化           |

**指标模式设计动机**：

当种群退化度高时，关系得分可能不够区分候选解（因为候选解都集中在某些区域）。此时使用 PIEA 的指标思想（SDE、I_epsilon+、Minkowski）来评估候选解，这些指标能更好地区分"在同一区域但质量不同"的解。

### 4.5 改进四：PIEA 指标轮盘选择

**新增模块**：

| 模块                   | 功能                             |
| ---------------------- | -------------------------------- |
| `IndicatorSelector`  | 使用轮盘赌选择一种指标来评估种群 |
| `UpdateInformation`  | 根据反馈更新指标被选中的概率     |
| `Shape_Estimate`     | 估计 PF 形状参数 Lp              |
| `calFitness_SDE`     | SDE 移位密度估计                 |
| `calFitness_epsilon` | I_epsilon+ 不可加性指标          |
| `calFitness_MD`      | Minkowski 距离指标               |
| `NDSort_SDR`         | 强支配关系非支配排序             |

**轮盘选择机制**：

```
初始：三个指标等概率（各 1/3）
每代：
  1. 根据概率 Pw 随机选择一个指标
  2. 用该指标评估种群，得到 Fitness
  3. 用 Fitness 训练 SVR 模型（用于候选解选择）
  4. 真实评估后，计算反馈分数 score（0/1/2）
  5. 更新该指标的 Win_record
  6. 重新计算 Pw = Win_record / Choose_record
```

**反馈分数**：

- 0 = 新解被原始 NDSort 支配（不好）
- 1 = 新解在 NDSort 第一层但被 NDSort_SDR 第一层排除（一般）
- 2 = 新解同时在 NDSort 和 NDSort_SDR 第一层（很好）

---

## 五、关键模块详解

### 5.1 RuntimeDiagnostics（运行时诊断）

**覆盖率（coverage）**：

```matlab
% 生成均匀参考向量
V = UniformPoint(Nref, M, 'ILD');
% 计算每个解的方向
Direction = PopObj ./ vecnorm(PopObj, 2, 2);
% 找到每个解最近的参考向量
cosine = 1 - pdist2(Direction, V, 'cosine');
[~, assigned] = max(cosine, [], 2);
% 覆盖率 = 被覆盖的参考向量数 / 总参考向量数
coverage = numel(unique(assigned)) / size(V, 1);
```

**退化度（degeneracy）**：

```matlab
% 对种群做 SVD
Centered = PopObj - mean(PopObj, 1);
s = svd(Centered, 'econ');
energy = s.^2;
% 找到解释 90% 能量所需的秩
rank90 = find(cumsum(energy)./total >= 0.90, 1, 'first');
% 退化度 = 1 - (所需秩 / 目标维度)
degeneracy = max(0, min(1, 1 - rank90 / M));
```

### 5.2 AdaMaOSelection（自适应选择）

**三种模式的实现**：

**保守模式**：

```matlab
[~, scores] = model_select(Smodel, Candidates);
[~, order] = sort(scores, 'descend');
Next = Candidates(order(1:n_min), :);
```

**探索模式**：

```matlab
[~, scores, uncertainty] = model_select(Smodel, Candidates);
score_n = norm01(scores);
unc_n = norm01(uncertainty);
lambda_t = lambda0 * (1 - ratio) * max(0, 1 - p_err/0.45);
score_aug = score_n + lambda_t .* unc_n;
% 分位数筛选 + 多样性选择
```

**指标模式**：

```matlab
% 第一步：关系得分粗筛（前 30%）
[~, scores_rel] = model_select(Smodel, Candidates);
n_keep = max(20, ceil(size(Candidates, 1) * 0.30));
coarse_idx = sort_idx(1:n_keep);

% 第二步：SVR 指标重排序
pred = predict(Smodel.IndicatorModel, Candidates(coarse_idx, :));
scores_ind = pred;

% 第三步：分位数筛选 + 排序选择
```

### 5.3 IndicatorSelector（指标轮盘选择）

**三种指标**：

| 指标       | 公式                                             | 特点               |
| ---------- | ------------------------------------------------ | ------------------ |
| SDE        | `min(max(PopObj, PopObj_i))`                   | 适合分布均匀的前沿 |
| I_epsilon+ | `max(PopObj_i - PopObj_j)`                     | 适合收敛性评估     |
| Minkowski  | `pdist2(PopObj, min(PopObj), 'minkowski', Lp)` | 适合特定形状的 PF  |

**Lp 形状估计**：

```matlab
% 从 17 个候选 Lp 中选标准差最小的
CP = [0.27 0.36 0.43 0.5 0.57 0.66 0.75 0.86 1 1.15 1.35 1.6 2 2.4 3.1 4.2 6.5];
for i = 1:length(CP)
    Gp = (sum(PopObj .^ CP(i), 2)) .^ (1 / CP(i));
    % 用箱线图剔除离群点
    Vp(i) = std(Gp ./ max(Gp));
end
p = CP(min(Vp));
```

### 5.4 NDSort_SDR（强支配关系排序）

**与标准 NDSort 的区别**：

标准 NDSort：解 A 支配解 B，当且仅当 A 在所有目标上都不差于 B，且至少在一个目标上严格优于 B。

NDSort_SDR：引入角度阈值 Theta，使支配关系更严格：

```matlab
% 计算角度阈值
minA = median(min(Angle));
Theta = max(1, (Angle ./ minA) .^ 1);

% 支配关系
if NormP(i) * Theta(i,j) < NormP(j)
    dominate(i, j) = true;
end
```

---

## 六、关键超参数与数据流

### 6.1 算法超参数

| 参数          | 默认值 | 含义                 | 来源           |
| ------------- | ------ | -------------------- | -------------- |
| k             | 6      | 参考解数量基数       | REMO_new2      |
| gmax          | 3000   | 内层 GA 累计样本上限 | REMO_new2      |
| q_keep        | 0.80   | 候选筛选分位数       | WFG10          |
| lambda0       | 0.35   | 不确定性权重基础系数 | WFG10          |
| w_min         | 0.30   | 样本权重下限         | WFG10          |
| n_min         | 4      | 每轮最少评估数       | WFG10          |
| n_max         | 6      | 每轮最多评估数       | WFG10          |
| tau_err       | 0.35   | 模型误差阈值         | **新增** |
| use_indicator | 1      | 是否启用指标选择     | **新增** |
| debug         | 0      | 是否打印调试信息     | **新增** |

### 6.2 主要数据结构

| 名称           | 维度        | 说明                                      | 来源           |
| -------------- | ----------- | ----------------------------------------- | -------------- |
| confidence     | N×1        | 每个解的分类置信度                        | REMO_new2      |
| WWs            | n_pair×1   | 关系对样本权重                            | WFG10          |
| TrainW         | n_train×1  | 训练集样本权重                            | WFG10          |
| uncertainty    | \|Next\|×1 | 候选解的模型不确定性                      | WFG10          |
| diagnostics    | struct      | 运行时诊断（coverage, degeneracy）        | **新增** |
| indicator      | struct(3,1) | 指标轮盘（Pw, Choose_record, Win_record） | **新增** |
| Fitness        | N×1        | 指标评估值                                | **新增** |
| IndicatorModel | SVR         | 指标预测模型                              | **新增** |
| Lp             | scalar      | PF 形状参数                               | **新增** |

---

## 七、改进动机总结

### 7.1 为什么需要运行时诊断？

WFG10 版本使用固定策略（如始终使用加权训练），但不同进化阶段和种群状态需要不同策略：

- 早期模型不精确时，加权训练可能放大噪声
- 后期种群退化时，关系得分可能不够区分候选解

运行时诊断让算法能**自动判断当前状态**，选择最合适的策略。

### 7.2 为什么需要三种关系对模式？

| 模式         | 解决的问题               |
| ------------ | ------------------------ |
| conservative | 模型不精确时的默认选择   |
| curriculum   | 模型不精确时过滤噪声样本 |
| weighted     | 模型精确时利用置信度信息 |

课程学习模式的思想来自深度学习：先用"简单"样本训练，再逐步引入"难"样本。

### 7.3 为什么需要三种候选解选择模式？

| 模式         | 解决的问题             |
| ------------ | ---------------------- |
| conservative | 模型不精确时的默认选择 |
| explore      | 覆盖不足时鼓励探索     |
| indicator    | 种群退化时使用指标区分 |

指标模式的思想来自 PIEA：当种群集中在某些区域时，关系得分可能不够区分候选解，此时使用 SDE、I_epsilon+、Minkowski 等指标能更好地区分。

### 7.4 为什么需要指标轮盘选择？

不同指标适合不同形状的 PF：

- SDE 适合分布均匀的前沿
- I_epsilon+ 适合收敛性评估
- Minkowski 适合特定形状的 PF

轮盘选择让算法能**自动学习哪种指标当前最有效**，避免人工选择。

---

## 八、复杂度分析

设 N 为种群规模，D 为决策变量维度，M 为目标维度，G 为代理辅助选择内层迭代数。

| 模块                        | 复杂度                     | 来源           |
| --------------------------- | -------------------------- | -------------- |
| RuntimeDiagnostics          | O(N·M + N²)              | **新增** |
| HybridPBI_Classification    | O(N·M·Nref + N²)        | REMO_new2      |
| GetRelationPairs_confidence | O(N²·D)                  | WFG10          |
| 神经网络训练                | O(n_pair·xDim·hidden)    | REMO_new2      |
| AdaMaOSelection             | O(G·\|Next\|·(C1+C2)·D) | **新增** |
| IndicatorSelector           | O(N²·M)                  | **新增** |
| Shape_Estimate              | O(N·17)                   | **新增** |
| RefSelect                   | O(\|Archive\|²·M)        | REMO_new2      |

---

## 九、典型调用示例

```matlab
platemo('algorithm', @REMO_new2_AdaMaO, ...
        'problem',   @DTLZ2, ...
        'N',         100, ...
        'M',         10, ...
        'D',         20, ...
        'maxFE',     500);
```

---

## 十、与 REMO_new2 和 REMO_new2_WFG10 的对比总结

### 10.1 继承关系

```
REMO_new2 (2022)
    ↓ 引入置信度加权、自适应参考解、不确定性/多样性选择
REMO_new2_WFG10 (2026)
    ↓ 引入运行时诊断、动态策略切换、PIEA 指标选择
REMO_new2_AdaMaO (2026)
```

### 10.2 核心创新

| 创新点         | 描述                             | 解决的问题               |
| -------------- | -------------------------------- | ------------------------ |
| 运行时诊断     | 计算 coverage 和 degeneracy      | 自动判断种群状态         |
| 动态关系对模式 | conservative/curriculum/weighted | 根据模型精度选择训练策略 |
| 动态候选解模式 | conservative/explore/indicator   | 根据种群状态选择选择策略 |
| PIEA 指标轮盘  | SDE/I_epsilon+/Minkowski         | 自动学习最有效的指标     |
| Lp 形状估计    | 17 个候选 Lp 中选最优            | 自动适应 PF 形状         |

### 10.3 适用场景

| 算法             | 最佳适用场景                    |
| ---------------- | ------------------------------- |
| REMO_new2        | 低维目标（M≤3），简单问题      |
| REMO_new2_WFG10  | 高维目标（M≥10），固定策略足够 |
| REMO_new2_AdaMaO | 高维目标，需要自适应策略        |

---

## 十一、参考文献

1. Hao H, Zhou A, Qian H, et al. Expensive multiobjective optimization by relation learning and prediction. IEEE Transactions on Evolutionary Computation, 2022.
2. Tian Y, Cheng R, Zhang X, He C, Jin Y. Guiding evolutionary multiobjective optimization with generic front modeling. IEEE Transactions on Cybernetics, 2020.（RSEA 雷达网格策略）
3. Zhang Q, Li H. MOEA/D: A multiobjective evolutionary algorithm based on decomposition. IEEE Transactions on Evolutionary Computation, 2007.（PBI 分解原理）
4. Y. Li, W. Li, S. Li, Y. Zhao. PIEA. Information Sciences, 2024.（指标选择思想）
5. Tian Y, Cheng R, Zhang X, Jin Y. PlatEMO: A MATLAB platform for evolutionary multi-objective optimization. IEEE Computational Intelligence Magazine, 2017, 12(4): 73–87.
