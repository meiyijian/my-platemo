# PIEA 算法详细报告

> **Performance Indicator-based Evolutionary Algorithm (PIEA)**
>
> 基于性能指标的进化算法

---

## 目录

1. [算法概述](#1-算法概述)
2. [核心思想与动机](#2-核心思想与动机)
3. [算法框架与流程](#3-算法框架与流程)
4. [核心组件详解](#4-核心组件详解)
5. [数学公式推导](#5-数学公式推导)
6. [参数说明与调参建议](#6-参数说明与调参建议)
7. [与相关算法对比](#7-与相关算法对比)
8. [实验结果与分析](#8-实验结果与分析)
9. [算法变体与改进方向](#9-算法变体与改进方向)
10. [参考文献](#10-参考文献)

---

## 1. 算法概述

### 1.1 基本信息

| 属性 | 值 |
|------|-----|
| **算法名称** | PIEA (Performance Indicator-based Evolutionary Algorithm) |
| **发表年份** | 2024 |
| **期刊** | Information Sciences (SCI 二区, IF≈8) |
| **论文标题** | A performance indicator-based evolutionary algorithm for expensive high-dimensional multi-/many-objective optimization |
| **作者** | Y. Li, W. Li, S. Li, Y. Zhao |
| **适用问题** | 昂贵高维多/超多目标优化 (Expensive MaOP) |
| **PlatEMO 标签** | `<2024> <multi/many> <real> <expensive>` |

### 1.2 关键特性

- **自适应性能指标选择**：通过轮盘赌机制动态选择最适合当前问题的性能指标
- **Lp 形状自适应**：自动估计 Pareto 前沿形状并调整距离度量
- **反馈学习机制**：利用 NDSort_SDR 强化支配关系评估指标效果
- **代理模型辅助**：使用 SVR (支持向量回归) 训练代理模型加速搜索

### 1.3 算法定位

PIEA 属于**代理辅助进化算法 (SAEA)** 中的**自适应派系**，专注于解决以下挑战：

1. **昂贵评估问题**：单次评估代价高昂 (数小时/天)
2. **高维决策空间**：D ≥ 30
3. **超多目标问题**：M ≥ 4
4. **有限评估预算**：通常 200-600 次真实评估

---

## 2. 核心思想与动机

### 2.1 问题背景

在昂贵多目标优化中，**固定填充准则**在不同问题特征下表现不稳定：

| 问题特征 | 适合的性能指标 | 原因 |
|----------|---------------|------|
| 凸 Pareto 前沿 | Minkowski 距离 (Lp=2) | 欧氏距离适合凸形状 |
| 凹 Pareto 前沿 | Minkowski 距离 (Lp<1) | 低阶范数适合凹形状 |
| 断裂/不连续前沿 | SDE (移位密度估计) | 密度估计擅长处理断裂区域 |
| 高维目标空间 | I_epsilon+ | 加性指标在高维更稳定 |

### 2.2 核心洞察

> **单一指标会失效，多指标自适应选择是关键。**

PIEA 的核心设计哲学：

1. **多指标轮盘**：维护三种性能指标 (SDE, I_epsilon+, Minkowski)
2. **历史反馈**：记录每种指标近期表现，动态调整选择概率
3. **形状感知**：通过 Lp 参数自动适应不同 Pareto 前沿形状
4. **强化评估**：使用 NDSort_SDR 提供更严格的评估标准

### 2.3 与其他方法的对比

| 方法 | 指标策略 | 形状感知 | 反馈机制 |
|------|---------|---------|---------|
| ParEGO | 固定 Tchebycheff | 无 | 无 |
| K-RVEA | 固定 APD | 无 | 无 |
| EMMOEA | 固定 IGD+ | 无 | 无 |
| **PIEA** | **三指标轮盘** | **Lp 自适应** | **NDSort_SDR 反馈** |

---

## 3. 算法框架与流程

### 3.1 整体框架图

```
┌─────────────────────────────────────────────────────────────────┐
│                           PIEA 算法框架                          │
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │ 初始化种群    │     │ Shape_Estimate│     │ 轮盘选择指标  │    │
│  │ (LHS 采样)   │ ──→ │ 估计 Lp 参数  │ ──→ │ SDE/ε+/MD    │    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│          │                                        │            │
│          ▼                                        ▼            │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │ 代理模型训练  │     │ 模型优化      │     │ 预选择       │    │
│  │ (SVR/RBF)    │ ←── │ (R_max 次)   │ ←── │ (Top-eta)    │    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│          │                                        │            │
│          ▼                                        ▼            │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │ 差异比较选择  │     │ 昂贵评估      │     │ 分层评估      │    │
│  │ (最远点)     │ ──→ │ Problem.Eval │ ──→ │ NDSort+SDR   │    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│                                                     │          │
│                                                     ▼          │
│                                            ┌──────────────┐    │
│                                            │ 更新信息      │    │
│                                            │ 更新轮盘 Pw   │    │
│                                            └──────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 详细算法步骤

```
算法 PIEA
输入: Problem (问题对象), maxFE (评估预算)
参数: eta=5 (预选数), R_max=20 (重复次数), tau=20 (窗口宽度)

────────────────────────────────────────────────────────────────
Step 0: 初始化
────────────────────────────────────────────────────────────────
  N = Problem.N (种群大小)
  P ← UniformPoint(N, D, 'Latin')                    # LHS 采样
  Population ← Problem.Evaluation(scale(P))
  A ← Population (档案)
  indicator ← {SDE: Pw=1/3, I_eps+: Pw=1/3, MD: Pw=1/3}

────────────────────────────────────────────────────────────────
主循环 while NotTerminated(A):
────────────────────────────────────────────────────────────────

  ── Step 1: PF 形状估计 ──────────────────────────────────
  Lp ← Shape_Estimate(A, N)
        # 取 NDSort 第一层非支配解
        # 在 17 个候选 Lp ∈ [0.27, 6.5] 中选择
        # 使 std(Gp/max(Gp)) 最小的 Lp

  ── Step 2: 轮盘选择性能指标 ─────────────────────────────
  r ← rand
  if r < Pw[1]:           # 概率 < Pw(SDE)
      Fitness ← calFitness_SDE(A.objs, Lp)
      flag ← 1
  elif r < Pw[1]+Pw[2]:   # 概率 < Pw(SDE)+Pw(I_eps+)
      Fitness ← calFitness_epsilon(A.objs, 0.05)
      flag ← 2
  else:                   # 概率 >= Pw(SDE)+Pw(I_eps+)
      Fitness ← calFitness_MD(A.objs, Lp)
      flag ← 3

  ── Step 3: 训练代理模型 ─────────────────────────────────
  Model ← fitrsvm(A.decs, Fitness,
                  'KernelFunction', 'rbf',
                  'KernelScale', 'auto',
                  'Standardize', true)

  ── Step 4: 模型优化 (内循环) ────────────────────────────
  Dec ← A.decs
  Arc ← Dec[randperm(end, N), :]  # 随机初始化候选集

  for r = 1 to R_max:
      MatingPool ← TournamentSelection(2, N, -Fitness)
      OffspringDec ← OperatorDE(Problem, Dec(MatingPool,:),
                                Arc, Dec(randperm(end,N),:))
      Offspringfit ← predict(Model, OffspringDec)

      if r == 1:
          Arc ← OffspringDec
          ArcFit ← Offspringfit
      else:
          # 保留适应度更高的解
          temp ← ArcFit < Offspringfit
          Arc[temp,:] ← OffspringDec[temp,:]
          ArcFit[temp] ← Offspringfit[temp]

  ── Step 5: 预选择 ───────────────────────────────────────
  [~, order] ← sort(ArcFit, 'descend')
  Arc ← Arc(order(1:eta), :)  # 选择 top-eta 个候选

  ── Step 6: 差异比较选择 ────────────────────────────────
  normADec ← (A.decs - lower) / (upper - lower)  # 归一化
  normDec ← (Arc - lower) / (upper - lower)
  distance ← min(pdist2(normDec, normADec), [], 2)
  [~, index] ← max(distance)  # 选择最远点

  ── Step 7: 昂贵评估 ─────────────────────────────────────
  New ← Problem.Evaluation(Arc(index,:))
  A ← [A, New]

  ── Step 8: 分层评估 ─────────────────────────────────────
  score ← 0
  [FrontNo, ~] ← NDSort(A.objs, 1)
  if FrontNo(end) == 1:  # 新解进入第一前沿
      score ← 1
      [FrontNo_SDR, ~] ← NDSort_SDR(A(FrontNo==1), 1)
      if FrontNo_SDR(end) == 1:  # 新解进入 SDR 第一层
          score ← 2

  ── Step 9: 更新轮盘信息 ────────────────────────────────
  indicator ← UpdateInformation(flag, score, indicator)
        # 更新 Choose_record, Win_record
        # 重新计算 Pw

End while
返回: Archive 中的非支配解
```

---

## 4. 核心组件详解

### 4.1 Shape_Estimate — PF 形状参数估计

#### 功能
估计 Pareto 前沿的几何形状参数 Lp，用于后续的 Minkowski 距离计算。

#### 算法原理

1. **归一化目标空间**：将目标值归一化到 [0, 1]
2. **计算广义距离**：
   $$
   G_p^{(i)} = \left( \sum_{j=1}^{M} F_{ij}^p \right)^{1/p}
   $$
3. **去噪处理**：使用箱线图剔除离群点
   - Q1 = 第 25 百分位数
   - Q3 = 第 75 百分位数
   - 上界 = Q3 + 1.5 × (Q3 - Q1)
4. **选择最优 Lp**：使 std(Gp/max(Gp)) 最小的 Lp 值

#### 候选 Lp 值集合

```matlab
CP = [0.27, 0.36, 0.43, 0.5, 0.57, 0.66, 0.75, 0.86,
      1, 1.15, 1.35, 1.6, 2, 2.4, 3.1, 4.2, 6.5]
```

#### Lp 的物理意义

| Lp 范围 | PF 形状 | 适用场景 |
|---------|---------|---------|
| Lp < 1 | 凹 (Concave) | DTLZ2, WFG 等 |
| Lp = 1 | 线性 (Linear) | DTLZ1 |
| Lp > 1 | 凸 (Convex) | 部分工程问题 |

### 4.2 三种性能指标

#### 4.2.1 calFitness_SDE — 移位密度估计

**公式**：

$$
\text{SDE}_i = \min_{j \neq i} \| F_i - \max(F_i, F_j) \|_2
$$

**特点**：
- 将每个解的目标值替换为与邻居的最大值
- 计算移位后的距离作为密度估计
- 适合处理断裂/不连续的 Pareto 前沿

**退化机制**：
当 SDE < 10^-4 (解聚集失去区分度) 时，自动退化为 Minkowski 距离：
$$
\text{Fitness}_i = -\| F_i - F_{\min} \|_{L_p}
$$

**最终变换**：Fitness = tansig(Fitness) 缩放到 [-1, 1]

#### 4.2.2 calFitness_epsilon — I_epsilon+ 不可加性

**公式**：

$$
I_{\epsilon}^+(F_i, F_j) = \max_{m=1}^{M} (F_{i,m} - F_{j,m})
$$

$$
\text{Fitness}_i = \sum_{j \neq i} -\exp\left( -\frac{I_{\epsilon}^+(F_i, F_j)}{C \cdot \kappa} \right) + 1
$$

其中：
- $$
  $C = \max_j |I_{\epsilon}^+(\cdot, j)|$ (归一化因子)
  $$

  
- $$
  $\kappa = 0.05$ (敏感度参数)
  $$

  

**特点**：

- 加性指标，适合高维目标空间
- 对 Pareto 支配关系敏感
- 在 M ≥ 5 时表现稳定

#### 4.2.3 calFitness_MD — Minkowski 距离

**公式**：

$$
\text{Fitness}_i = -\| F_i - F_{\min} \|_{L_p}
$$

**特点**：
- 直接计算到理想点的 Lp 距离
- Lp 参数由 Shape_Estimate 自动确定
- 简单高效，适合形状已知的问题

### 4.3 NDSort_SDR — 强支配关系排序

#### 动机
传统 NDSort 在 M ≥ 5 时几乎所有解互不支配，无区分度。

#### 核心思想
引入**角度阈值** Θ_ij，使支配关系更严格：

$$
\Theta_{ij} = \max\left(1, \frac{\angle(F_i, F_j)}{\theta_{\min}}\right)
$$

#### 新支配关系

$$
F_i \prec_{\text{SDR}} F_j \iff \|F_i\|_1 \cdot \Theta_{ij} < \|F_j\|_1
$$

其中：
- $$
  $\|F_i\|_1 = \sum_m F_{i,m}$ (L1 范数)
  $$

  
- $$
  $\theta_{\min}$ = 种群中所有最近邻角度的中位数
  $$

  

#### 物理含义
"解 A 支配解 B"需要满足：
1. A 的 L1 范数更小 (收敛性更好)
2. A 的方向与 B 相近 (角度在阈值内)

### 4.4 UpdateInformation — 轮盘信息更新

#### 滑动窗口机制

使用长度为 tau 的滑动窗口记录每种指标的历史表现：

```matlab
indicator(i).Choose_record  % 长度 tau 的二值序列，记录是否被选中
indicator(i).Win_record     % 长度 tau 的数值序列，记录选中后的表现
```

#### 更新规则

**Choose_record 更新**：
- 当代选中的指标：对应位置 ← 1
- 其他指标：对应位置 ← 0
- 窗口滑动：删除最旧记录

**Win_record 更新**：
```
if score == 0:  # 新解被支配
    所有指标记录 ← 0
else:
    if flag == 1 (SDE 被选中):
        SDE 记录 ← score/2
        其他记录 ← 0
    elif flag == 2 (I_eps+ 被选中):
        I_eps+ 记录 ← score/2
        其他记录 ← 0
    else (MD 被选中):
        MD 记录 ← score/2
        其他记录 ← 0
```

**概率 Pw 更新**：

$$
P_w^{(i)} = \frac{\sum \text{Win}^{(i)} + \epsilon}{\sum \text{Choose}^{(i)} + \epsilon}
$$

$$
P_w^{(i)} \leftarrow \frac{P_w^{(i)}}{\sum_j P_w^{(j)}} \quad \text{(归一化)}
$$

#### score 的含义

| score | 含义 | Win_record 增量 |
|-------|------|-----------------|
| 0 | 新解被支配 (差) | 0 |
| 1 | 在 NDSort F1 (中) | 0.5 |
| 2 | 在 NDSort_SDR F1 (极优) | 1.0 |

---

## 5. 数学公式推导

### 5.1 归一化处理

所有性能指标的计算都基于归一化目标值：

$$
\bar{F}_{i,m} = \frac{F_{i,m} - F_m^{\min}}{F_m^{\max} - F_m^{\min}}
$$

其中：
- $$
  $F_m^{\min} = \min_i F_{i,m}$
  $$

  
- $$
  $F_m^{\max} = \max_i F_{i,m}$
  $$

  

### 5.2 SDE 计算详解

**步骤 1：移位操作**

对每个解 i，计算移位后的目标矩阵：

$$
S_{ij} = \max(\bar{F}_i, \bar{F}_j), \quad \forall j \neq i
$$

**步骤 2：距离计算**

$$
d_{ij} = \| \bar{F}_i - S_{ij} \|_2
$$

**步骤 3：密度估计**

$$
\text{SDE}_i = \min_{j \neq i} d_{ij}
$$

**步骤 4：归一化**

$$
\text{Fitness}_i = \frac{3}{\max(\text{SDE}) + \epsilon - \min(\text{SDE})} \times (\text{SDE}_i - \min(\text{SDE}))
$$

### 5.3 Lp 范数定义

$$
\| \mathbf{x} \|_p = \left( \sum_{i=1}^{n} |x_i|^p \right)^{1/p}
$$

特殊情况下：
- p = 1: 曼哈顿距离
- p = 2: 欧氏距离
- p → ∞: 切比雪夫距离

### 5.4 轮盘选择概率计算

设三个指标的累积权重：

$$
W_1 = P_w^{(1)} \\
W_2 = P_w^{(1)} + P_w^{(2)} \\
W_3 = P_w^{(1)} + P_w^{(2)} + P_w^{(3)} = 1
$$

轮盘选择：

$$
\text{if } r < W_1: \text{选择 SDE} \\
\text{elif } r < W_2: \text{选择 I\_epsilon+} \\
\text{else}: \text{选择 Minkowski}
$$

---

## 6. 参数说明与调参建议

### 6.1 算法参数

| 参数 | 默认值 | 说明 | 调参建议 |
|------|-------|------|---------|
| **eta** | 5 | 预选存活者数量 | maxFE 充裕时可增至 8-10 |
| **R_max** | 20 | 子代生成最大重复次数 | 计算资源紧张时可降至 10-15 |
| **tau** | 20 | 历史窗口宽度 | M 大时可调到 30，更稳定 |

### 6.2 代理模型参数

| 参数 | 值 | 说明 |
|------|-----|------|
| KernelFunction | 'rbf' | 径向基核函数 |
| KernelScale | 'auto' | 自动选择核尺度 |
| Standardize | true | 输入标准化 |

### 6.3 适应度计算参数

| 参数 | 值 | 说明 |
|------|-----|------|
| kappa (I_eps+) | 0.05 | 敏感度参数，控制指数衰减速度 |
| k (Shape_Estimate) | 1.5 | 箱线图离群点系数 |

### 6.4 推荐运行配置

```matlab
% 基本运行
platemo('algorithm', @PIEA, 'problem', @DTLZ2, 'M', 5, 'D', 30, 'maxFE', 300)

% 多次运行取平均
platemo('algorithm', @PIEA, 'problem', @DTLZ2, 'M', 5, 'D', 30, 'maxFE', 300, 'run', 10)

% 自定义参数
platemo('algorithm', @PIEA, 'problem', @DTLZ2, 'M', 5, 'D', 30, 'maxFE', 300,
        'parameter', {5, 20, 20})  % {eta, R_max, tau}
```

---

## 7. 与相关算法对比

### 7.1 与同类 SAEA 对比

| 算法 | 年份 | 期刊 | 代理模型 | 指标策略 | 形状感知 |
|------|------|------|---------|---------|---------|
| ParEGO | 2006 | TEVC | Kriging | 固定 Tchebycheff | 无 |
| MOEA/D-EGO | 2010 | TEVC | Kriging | 固定 EI | 无 |
| K-RVEA | 2018 | TEVC | Kriging | 固定 APD | 无 |
| CSEA | 2019 | TEVC | FNN 分类 | 参考解优劣 | 无 |
| REMO | 2022 | TEVC | 关系 FNN | 成对关系 | 无 |
| EMMOEA | 2023 | TEVC | Kriging | 固定 IGD+ | 无 |
| **PIEA** | 2024 | Inf.Sci | SVR | **三指标轮盘** | **Lp 自适应** |

### 7.2 PIEA 的独特优势

1. **自适应指标选择**：不像其他算法使用固定指标
2. **形状感知**：通过 Lp 参数自动适应不同 PF 形状
3. **反馈学习**：通过 NDSort_SDR 评估指标效果并调整概率
4. **鲁棒性**：多指标互补，单一指标失效时自动切换

### 7.3 PIEA 的局限性

1. **代理模型精度**：使用 SVR 而非 Kriging，缺少不确定度估计
2. **计算开销**：每代需要计算三种指标 + NDSort_SDR
3. **参数敏感**：tau 窗口大小影响学习速度

---

## 8. 实验结果与分析

### 8.1 典型测试问题

| 问题 | M | D | PF 形状 | 特点 |
|------|---|---|---------|------|
| DTLZ1 | 3-15 | 10-30 | 线性 | 多模态 |
| DTLZ2 | 3-15 | 10-30 | 凹 | 标准测试 |
| DTLZ3 | 3-15 | 10-30 | 凹 | 大量局部最优 |
| DTLZ4 | 3-15 | 10-30 | 凹 | 偏向分布 |
| DTLZ5 | 3-15 | 10-30 | 退化 | 低维流形 |
| DTLZ6 | 3-15 | 10-30 | 退化 | 非均匀 |
| DTLZ7 | 3-15 | 10-30 | 断裂 | 不连续前沿 |
| WFG1-WFG9 | 3-10 | 10-30 | 多样 | 复杂形状 |

### 8.2 预期表现

根据算法设计，PIEA 在以下场景表现优异：

1. **超多目标 (M ≥ 5)**：多指标轮盘机制自动选择适合的指标
2. **复杂 PF 形状**：Lp 自适应能够处理不同形状
3. **有限预算 (maxFE ≤ 300)**：代理模型加速搜索

### 8.3 性能指标

常用评估指标：
- **IGD (Inverted Generational Distance)**：综合评估收敛性和多样性
- **HV (Hypervolume)**：超体积指标
- **Spread**：分布均匀性

---

## 9. 算法变体与改进方向

### 9.1 已有变体

基于 PIEA 的改进算法：

| 变体 | 改进点 | 位置 |
|------|--------|------|
| REMO_new2_PIEA | 集成 REMO 关系学习 | REMO_new2_PIEA/ |
| REMO_new2_PIEA2 | 加 SVR 回归 SDE | REMO_new2_PIEA2/ |
| REMO_new2_PIEA3 | 两阶段筛选机制 | REMO_new2_PIEA3/ |
| REMO_new2_PIEA4 | 增强调试功能 | REMO_new2_PIEA4/ |
| REMO_new2_PIEA5 | 完整指标体系 | REMO_new2_PIEA5/ |

### 9.2 可能的改进方向

1. **代理模型升级**
   - 使用 Kriging 替代 SVR，获得不确定度估计
   - 集成多种代理模型 (异构集成)

2. **指标扩展**
   - 增加更多性能指标 (如 R2, IGD+)
   - 基于问题特征的指标推荐

3. **批量评估**
   - 每代评估多个解，提高 FE 利用率
   - 使用聚类或分解策略选择候选解

4. **大规模问题**
   - 结合变量分组技术
   - 使用子空间分解

5. **约束处理**
   - 扩展到约束优化问题
   - 设计约束感知的性能指标

---

## 10. 参考文献

### 10.1 核心论文

```bibtex
@article{PIEA2024,
  author  = {Li, Yang and Li, Wei and Li, Shuai and Zhao, Yu},
  title   = {A performance indicator-based evolutionary algorithm for
             expensive high-dimensional multi-/many-objective optimization},
  journal = {Information Sciences},
  pages   = {121045},
  year    = {2024}
}
```

### 10.2 相关工作

1. **SDE (移位密度估计)**
   - M. Li, S. Yang, and X. Liu. "Shift-based density estimation for Pareto-based algorithms in many-objective optimization." IEEE TEVC, 2014.

2. **NDSort_SDR (强支配关系)**
   - 原作来源同 PIEA，借鉴 SPEA-R 系列的强支配关系思想。

3. **PlatEMO 平台**
   - Y. Tian, R. Cheng, X. Zhang, and Y. Jin. "PlatEMO: A MATLAB platform for evolutionary multi-objective optimization." IEEE CIM, 2017, 12(4): 73-87.

### 10.3 同类算法

4. **REMO (关系学习)**
   - H. Hao, A. Zhou, H. Qian, and H. Zhang. "Expensive multiobjective optimization by relation learning and prediction." IEEE TEVC, 2022, 26(5): 1157-1170.

5. **EMMOEA (性能指标)**
   - S. Qin, C. Sun, Q. Liu, and Y. Jin. "A performance indicator-based infill criterion for expensive multi-/many-objective optimization." IEEE TEVC, 2023, 27(4): 1085-1099.

6. **DirHV-EI (方向化 EHVI)**
   - L. Zhao and Q. Zhang. "Hypervolume-guided decomposition for parallel expensive multiobjective optimization." IEEE TEVC, 2024, 28(2): 432-444.

---

## 附录 A：代码文件说明

### 文件结构

```
PIEA/
├── PIEA.m              # 主算法文件
├── NDSort_SDR.m        # 强支配关系排序
├── Shape_Estimate.m    # PF 形状参数估计
├── UpdateInformation.m # 轮盘信息更新
└── PIEA算法详细报告.md  # 本文档
```

### 核心函数调用关系

```
PIEA.main()
├── Shape_Estimate()        # 估计 Lp
├── calFitness_SDE()        # 计算 SDE 适应度
├── CalFitness_epsilon()    # 计算 I_eps+ 适应度
├── calFitness_MD()         # 计算 Minkowski 适应度
├── fitrsvm()               # 训练 SVR 代理模型
├── predict()               # 代理模型预测
├── TournamentSelection()   # 锦标赛选择
├── OperatorDE()            # DE 算子
├── Problem.Evaluation()    # 真实评估
├── NDSort()                # 非支配排序
├── NDSort_SDR()            # 强支配排序
└── UpdateInformation()     # 更新轮盘
```

---

## 附录 B：使用示例

### 示例 1：标准测试

```matlab
% 在 DTLZ2 (M=5, D=30) 上运行 PIEA
platemo('algorithm', @PIEA, 'problem', @DTLZ2,
        'M', 5, 'D', 30, 'maxFE', 300)
```

### 示例 2：多算法对比

```matlab
% 对比 PIEA 与其他算法
algorithms = {@PIEA, @REMO, @K_RVEA};
problems = {@DTLZ2, @DTLZ4, @WFG1};
M = [5, 8, 10];

for i = 1:length(algorithms)
    for j = 1:length(problems)
        for k = 1:length(M)
            platemo('algorithm', algorithms{i},
                    'problem', problems{j},
                    'M', M(k), 'D', 30, 'maxFE', 300,
                    'run', 5);
        end
    end
end
```

### 示例 3：观察轮盘行为

在 `UpdateInformation.m` 末尾添加调试输出：

```matlab
fprintf('Pw = [SDE=%.3f, I_eps+=%.3f, MD=%.3f]\n', p(1), p(2), p(3));
fprintf('Score = %d, Flag = %d\n', score, flag);
```

预期现象：
- DTLZ2 (凹 PF, Lp≈0.5): MD 概率上升
- DTLZ1 (线性 PF, Lp≈1): 三者较均衡
- DTLZ7 (断裂): SDE 概率上升

---

## 附录 C：术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| 性能指标 | Performance Indicator | 评估解集质量的度量 |
| 轮盘选择 | Roulette Wheel Selection | 基于概率的随机选择 |
| 强支配关系 | Strengthened Dominance Relation | 角度增强的支配关系 |
| 移位密度估计 | Shift-based Density Estimation | SDE 密度度量 |
| Minkowski 距离 | Minkowski Distance | Lp 范数距离 |
| 代理模型 | Surrogate Model | 替代真实评估的近似模型 |
| 填充准则 | Infill Criterion | 选择候选解的标准 |
| 非支配排序 | Non-dominated Sorting | Pareto 前沿分层 |

---

**文档版本**: v1.0
**最后更新**: 2026-05-07
**编写者**: Claude Code Assistant

