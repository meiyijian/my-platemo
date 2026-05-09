# PlatEMO 昂贵多/超多目标优化算法文献综述

> **标签筛选范围**：`<multi>` 或 `<multi/many>` **AND** `<expensive>`，且不含 `<constrained>` 标签（保留 `<constrained/none>`）
>
> **基线版本**：基于 PlatEMO 4.x 收录的 32 个原版已发表论文算法
>
> **整理维度**：双维度交叉（代理模型类型 × 期刊等级）
>
> **编写日期**：2026-05-02

---

## 目录

1. [引言](#1-引言)
2. [分类体系与期刊等级标注](#2-分类体系与期刊等级标注)
3. [各代理模型流派详尽分析](#3-各代理模型流派详尽分析)
   - 3.1 [流派 A：Kriging/GP 回归代理类（17 个）](#31-流派-akrigingggp-回归代理类17-个)
   - 3.2 [流派 B：分类器代理类（3 个）](#32-流派-b分类器代理类3-个)
   - 3.3 [流派 C：关系学习/成对比较类（2 个）](#33-流派-c关系学习成对比较类2-个)
   - 3.4 [流派 D：神经网络/深度学习类（3 个）](#34-流派-d神经网络深度学习类3-个)
   - 3.5 [流派 E：异构集成代理类（2 个）](#35-流派-e异构集成代理类2-个)
   - 3.6 [流派 F：标量化/子空间代理类（5 个）](#36-流派-f标量化子空间代理类5-个)
4. [期刊等级分布与发展趋势](#4-期刊等级分布与发展趋势)
5. [算法对比汇总表](#5-算法对比汇总表)
6. [BibTeX 引用规范](#6-bibtex-引用规范)

---

## 1. 引言

### 1.1 昂贵多/超多目标优化问题（EMOP / EMaOP）

**昂贵多目标优化问题**（Expensive Multi-objective Optimization Problem, EMOP）指的是单次目标函数评估代价极其高昂的多目标优化问题，其形式化定义为：

$$
\min_{\mathbf{x}\in\Omega} \mathbf{F}(\mathbf{x}) = (f_1(\mathbf{x}), f_2(\mathbf{x}), \dots, f_M(\mathbf{x}))^\top
$$

其中 $\mathbf{x}\in\mathbb{R}^D$ 为决策变量，$M\ge 2$ 为目标维度，每次计算 $\mathbf{F}(\mathbf{x})$ 需要数小时甚至数天的真实仿真（如 CFD 模拟、有限元分析、实验测试）。当 $M\ge 4$ 时进一步称为**昂贵超多目标问题**（EMaOP）。

工程典型场景：①翼型气动优化（CFD 仿真）；②建筑能耗优化（EnergyPlus 模拟）；③化工反应器设计（Aspen Plus）；④药物分子设计（DFT 计算）。这些场景下，可承受的真实评估预算通常仅为 200-600 次 FE。

### 1.2 代理辅助进化算法（SAEA）的核心动机

**代理辅助进化算法**（Surrogate-Assisted Evolutionary Algorithm, SAEA）通过引入廉价的机器学习代理模型 $\hat{f}$ 替代部分真实评估，把 FE 预算集中投放给"代理判断为最有希望"的候选解。其核心循环为：

```
初始化：拉丁超立方采样得到初始数据库 D = {(x_i, f_i)}
循环：
    1. 在 D 上训练代理模型 ĥ
    2. 进化算法生成大量候选解 P_cand（不消耗真实 FE）
    3. 用 ĥ 评估 P_cand，按 infill 准则选 μ 个最优送真实评估
    4. 将新评估解加入 D，可能更新模型
直到达到 maxFE
```

### 1.3 关键挑战

| 挑战 | 描述 | 代表性应对策略 |
|------|------|--------------|
| **代理精度** | 数据稀少（仅 100~600 个样本）下的高精度建模 | Kriging（GP）、RBFN、轻量 NN |
| **不确定性度量** | 决定何处探索（高方差）vs 开发（低均值） | EI、LCB、PoI、熵搜索 |
| **填充准则** | 如何用代理选下一批解 | EI、EHVI、APD、PBI、双指标、性能指标 |
| **决策维度灾难** | $D\ge 30$ 时代理拟合困难 | Dropout NN、子空间分解、变量分组 |
| **目标维度灾难** | $M\ge 4$ 时 HV 计算指数爆炸、Pareto 失效 | EHVI 重要性采样、参考向量分解、关系学习 |
| **多样性保持** | FE 极少时易陷入局部聚集 | 双档案、概率拥挤、SDE |
| **代理失效** | 模型与真实严重背离 | 可靠性度量、模型管理、阶段切换 |

### 1.4 本综述的范围与方法论

- **范围**：PlatEMO 平台 `Algorithms/Multi-objective optimization/` 目录下，标签同时包含 `<multi>` 或 `<multi/many>` 与 `<expensive>` 的 32 个原版已发表论文算法（已排除用户自定义衍生与纯 `<constrained>` 算法）。
- **组织**：以**代理模型类型**为主分类（6 大流派），以**期刊等级**为辅助标注（每条算法标注 Tier-1 / Tier-2 / Tier-3 / Conf）。期刊等级基于中科院 SCI 期刊分区表（2024 版）。
- **每个算法分析模板**（约 500-800 字）：基本信息 → 算法动机 → 核心思想 → 代理模型设计 → 填充准则 → 创新点 → 流程伪代码 → 关键公式 → 适用场景 → PlatEMO 实现要点。

---

## 2. 分类体系与期刊等级标注

### 2.1 6 大代理模型流派

| 流派 | 代理模型 | 数量 | 算法清单（按年份） |
|------|---------|------|--------------------|
| **A** | Kriging/GP 回归 | 17 | ParEGO(2006)、SMS-EGO(2008)、MOEA/D-EGO(2010)、MultiObjectiveEGO(2016)、EIM-EGO(2017)、K-RVEA(2018)、AB-SAEA(2020)、KTA2(2021)、PB-NSGA-III(2022)、PB-RVEA(2022)、EMMOEA(2023)、NSGAIII-EHVI(2023)、DirHV-EI(2024)、DISK(2024)、PIEA(2024)、PIMD(2024)、TEA(2024) |
| **B** | 分类器代理 | 3 | CPS-MOEA(2015)、CSEA(2019)、MCEA/D(2022) |
| **C** | 关系学习/成对比较 | 2 | REMO(2022)、PC-SAEA(2023) |
| **D** | 神经网络/深度学习 | 3 | ADSAPSO(2022)、EDN-ARMOEA(2022)、SSDE(2024) |
| **E** | 异构集成 | 2 | HeE-MOEA(2019)、ESBCEO(2023) |
| **F** | 标量化/子空间代理 | 5 | SMOA(2022)、MO-L2SMEA(2023)、AVG-SAEA(2024)、LDS-AF(2024)、SFA-DE(2024) |

> **期刊等级分布**（基于中科院 2024 分区）：
> - **Tier-1（一区）**：24 个算法（75%），主要发表于 IEEE TEVC、TSMCS、TCYB、SWEVO、Information Sciences、KBS、EAAI
> - **Tier-2（二区）**：2 个算法（6.25%），发表于 Evolutionary Computation、Complex & Intelligent Systems
> - **Tier-3（三区）**：2 个算法（6.25%），发表于 Memetic Computing
> - **Conference**：4 个算法（12.5%），CEC、PPSN、GECCO

### 2.2 期刊等级分组（基于 CCF 推荐目录与中科院分区）

> **注**：期刊等级基于中科院 SCI 期刊分区表（2024 版），部分期刊近年分区有调整。

#### Tier-1（顶级期刊，中科院 SCI 一区/一区 Top）—— 24 个算法

| 期刊 | 缩写 | 中科院分区 | 影响因子档 | 算法数 | 算法清单 |
|------|------|-----------|------------|--------|----------|
| IEEE Trans. Evolutionary Computation | TEVC | 一区 Top | ~14 | 14 | ParEGO、MOEA/D-EGO、EIM-EGO、K-RVEA、CSEA、KTA2、MCEA/D、REMO、EMMOEA、NSGAIII-EHVI、MO-L2SMEA、AVG-SAEA、DirHV-EI、DISK |
| IEEE Trans. Cybernetics | TCYB | 一区 Top | ~11 | 1 | HeE-MOEA |
| IEEE Trans. Systems, Man, and Cybernetics: Systems | TSMCS | 一区 | ~9 | 2 | EDN-ARMOEA、TEA |
| IEEE Trans. Neural Networks and Learning Systems | TNNLS | 一区 Top | ~10 | 0 | （仅 MGSAEA，已排除约束） |
| Information Sciences | Inf. Sci. | 一区 Top | ~8 | 2 | AB-SAEA、PIEA |
| Knowledge-Based Systems | KBS | 一区 | ~8 | 1 | ESBCEO |
| Swarm and Evolutionary Computation | SWEVO | 一区 Top | ~10 | 3 | PC-SAEA、SFA-DE、SSDE |
| Engineering Applications of Artificial Intelligence | EAAI | 一区 | ~8 | 1 | PIMD |

#### Tier-2（中上期刊，中科院 SCI 二区）—— 2 个算法

| 期刊 | 缩写 | 中科院分区 | 影响因子档 | 算法数 | 算法清单 |
|------|------|-----------|------------|--------|----------|
| Evolutionary Computation | EC | 二区 | ~6 | 1 | LDS-AF |
| Complex & Intelligent Systems | CIS | 二区 | ~5 | 1 | ADSAPSO |

#### Tier-3（普通期刊，中科院 SCI 三区）—— 2 个算法

| 期刊 | 缩写 | 中科院分区 | 算法数 | 算法清单 |
|------|------|-----------|--------|----------|
| Memetic Computing | MC | 三区 | 2 | PB-NSGA-III、PB-RVEA |

#### Conference（重要会议）—— 4 个算法

| 会议 | 算法数 | 算法清单 |
|------|--------|----------|
| CEC（IEEE Congress on Evolutionary Computation） | 2 | CPS-MOEA、SMOA |
| PPSN（Parallel Problem Solving from Nature） | 1 | SMS-EGO |
| GECCO（Genetic and Evolutionary Computation Conf.） | 1 | MultiObjectiveEGO |

### 2.3 32 个算法总览表（年份升序）

| # | 算法 | 年份 | 期刊/会议 | Tier | 标签 | 代理模型 | 进化框架 |
|---|------|------|-----------|------|------|----------|----------|
| 1 | ParEGO | 2006 | IEEE TEVC | T1 | multi | Kriging | EGO+ASF |
| 2 | SMS-EGO | 2008 | PPSN | Conf | multi | Kriging | EGO+HV |
| 3 | MOEA/D-EGO | 2010 | IEEE TEVC | T1 | multi | Kriging | MOEA/D |
| 4 | CPS-MOEA | 2015 | CEC | Conf | multi | k-NN 分类器 | NSGA-II |
| 5 | MultiObjectiveEGO | 2016 | GECCO | Conf | multi | Kriging | EGO+ASF |
| 6 | EIM-EGO | 2017 | IEEE TEVC | T1 | multi | Kriging | EGO+EIM |
| 7 | K-RVEA | 2018 | IEEE TEVC | T1 | multi/many | Kriging | RVEA |
| 8 | CSEA | 2019 | IEEE TEVC | T1 | multi/many | FNN 分类器 | NSGA-III 风格 |
| 9 | HeE-MOEA | 2019 | IEEE TCYB | T1 | multi | 异构集成 | NSGA-II |
| 10 | AB-SAEA | 2020 | Information Sciences | T1 | multi/many | Kriging | RVEA |
| 11 | KTA2 | 2021 | IEEE TEVC | T1 | multi/many | Kriging | Two_Arch2 |
| 12 | ADSAPSO | 2022 | Complex & Intelligent Systems | T2 | multi/many | RBF+Dropout | PSO |
| 13 | EDN-ARMOEA | 2022 | IEEE TSMCS | T1 | multi/many | Dropout NN | AR-MOEA |
| 14 | MCEA/D | 2022 | IEEE TEVC | T1 | multi/many | 多 SVM | MOEA/D |
| 15 | PB-NSGA-III | 2022 | Memetic Computing | T3 | multi/many | Kriging | NSGA-III |
| 16 | PB-RVEA | 2022 | Memetic Computing | T3 | multi/many | Kriging | RVEA |
| 17 | REMO | 2022 | IEEE TEVC | T1 | multi/many | 关系 FNN | 自定义 |
| 18 | SMOA | 2022 | CEC | Conf | multi | 监督学习 | 离线 |
| 19 | EMMOEA | 2023 | IEEE TEVC | T1 | multi | Kriging | 自定义 |
| 20 | ESBCEO | 2023 | KBS | T1 | multi | 局部 Kriging 协同 | MOEA/D |
| 21 | MO-L2SMEA | 2023 | IEEE TEVC | T1 | multi | 一维子空间 RBF | NSGA-II |
| 22 | NSGAIII-EHVI | 2023 | IEEE TEVC | T1 | multi/many | Kriging | NSGA-III |
| 23 | PC-SAEA | 2023 | SWEVO | T1 | multi/many | RBFN 成对比较 | NSGA-II |
| 24 | AVG-SAEA | 2024 | IEEE TEVC | T1 | multi | RBF | 子种群 |
| 25 | DirHV-EI | 2024 | IEEE TEVC | T1 | multi/many | Kriging | MOEA/D |
| 26 | DISK | 2024 | IEEE TEVC | T1 | multi/many | Kriging | 自定义 |
| 27 | LDS-AF | 2024 | Evol. Comp. | T2 | multi | RBF（标量化输出） | MOEA/D |
| 28 | PIEA | 2024 | Information Sciences | T1 | multi/many | Kriging | NSGA-III |
| 29 | PIMD | 2024 | EAAI | T1 | multi/many | Kriging | NSGA-III |
| 30 | SFA-DE | 2024 | SWEVO | T1 | multi/many | RBF | DE+MOEA/D |
| 31 | SSDE | 2024 | SWEVO | T1 | multi/many | SOM 自组织 | DE+NSGA |
| 32 | TEA | 2024 | IEEE TSMCS | T1 | multi/many | Kriging（两阶段） | 自定义 |

---

## 3. 各代理模型流派详尽分析

### 3.1 流派 A：Kriging/GP 回归代理类（17 个）

本流派是 SAEA 中最古老、最主流的派系。**Kriging（高斯过程，GP）** 是其核心建模工具，因其同时给出预测均值 $\hat\mu(\mathbf{x})$ 与预测方差 $\hat\sigma^2(\mathbf{x})$，天然支持基于不确定性的填充准则（如 EI、LCB、PoI）。本节按内部演化逻辑分为 4 个子派系：A.1 经典 EGO 派系、A.2 SAEA-框架派系、A.3 高级采集函数派系、A.4 自适应/特殊派系。

#### A.1 经典 EGO 派系（5 个，奠基性工作）

##### A.1.1 ParEGO（2006, IEEE TEVC）⭐ 最早的 SA-MOEA 之一

- **基本信息**：J. Knowles, "ParEGO: A hybrid algorithm with on-line landscape approximation for expensive multiobjective optimization problems", IEEE TEVC, vol. 10, no. 1, pp. 50-66, 2006. **Tier-1**, IF≈14。
- **算法动机**：单目标 EGO（Jones 1998）无法直接处理多目标。如何把 EGO 推广到 MOO？
- **核心思想**：把 MOO 通过 Tchebycheff 标量化转化为单目标，每代随机抽取一个权重向量，仅训练一个 Kriging 模型对标量化值建模，最大化 EI 推荐 1 个新解。
- **代理模型**：单个 Kriging 模型，输入 
  $$
  \mathbf{x}\in\mathbb{R}^D
  $$
  ，输出标量化值 
  $$
  g^{te}(\mathbf{x}|\boldsymbol\lambda)。
  $$
- **填充准则**：Expected Improvement
$$
\mathrm{EI}(\mathbf{x}) = (f_{\min}-\hat\mu)\Phi\left(\frac{f_{\min}-\hat\mu}{\hat\sigma}\right) + \hat\sigma \phi\left(\frac{f_{\min}-\hat\mu}{\hat\sigma}\right)
$$
- **创新点**：①首次实现 EGO 与 Tchebycheff 分解的耦合；②权重向量随机化天然带来多样性。
- **流程**：
  1. LHS 采样 $11D-1$ 个初始解，全部真实评估
  2. 随机抽取权重 $\boldsymbol\lambda$，计算 $g^{te}$ 标量化值
  3. 训练 Kriging 模型 $\hat g$
  4. 内部 GA 搜索最大化 EI 的解 $\mathbf{x}^*$
  5. 真实评估 $\mathbf{x}^*$，加入档案，回到步骤 2
- **局限**：每代仅产 1 个新解；高维 $D\ge 30$ 时 Kriging 训练慢；超多目标 $M\ge 4$ 性能下降。
- **PlatEMO 实现**：`ParEGO/ParEGO.m`，参数 `IFEs=10000`（内部 GA 评估次数）；调用 `dacefit.m`/`predictor.m` 训练 Kriging。
- **后世影响**：被 MOEA/D-EGO（用 GP 模型分别建多个子问题）、KRG-MOEA、CEGO 等大量后续工作改进。

---

##### A.1.2 SMS-EGO（2008, PPSN）⭐ HV 驱动的 EGO

- **基本信息**：W. Ponweiser et al., "Multiobjective optimization on a limited budget of evaluations using model-assisted S-metric selection", PPSN 2008, pp. 784-794. **Conference**, 重要 EC 会议。
- **算法动机**：ParEGO 的标量化是间接逼近 Pareto 前沿，能否直接用超体积（S-metric, HV）作为采集函数？
- **核心思想**：每个目标函数训练一个独立 Kriging 模型，候选解的"质量"用其加入当前 Pareto 前沿后的 HV 增量来度量；使用下置信界（LCB）惩罚高方差解避免过度乐观。
- **代理模型**：每目标一个 Kriging：$\hat\mu_i(\mathbf{x}), \hat\sigma_i^2(\mathbf{x}), i=1,\dots,M$。
- **填充准则**：基于 LCB 的 S-metric 改进
$$
\mathbf{f}^{LCB}(\mathbf{x}) = \hat{\boldsymbol\mu}(\mathbf{x}) - \alpha \hat{\boldsymbol\sigma}(\mathbf{x})
$$
然后选最大化 $\Delta\mathrm{HV}(\mathbf{f}^{LCB}, P^*)$ 的解。
- **创新点**：①HV 直接作为采集函数；②LCB 引入不确定度感知。
- **PlatEMO 实现**：`SMS-EGO/SMSEGO.m`，参数 `wmax=10000`。
- **局限**：HV 计算在 $M\ge 5$ 时指数爆炸；每代仍只产 1 解。

---

##### A.1.3 MOEA/D-EGO（2010, IEEE TEVC）⭐⭐ 分解+EGO 的开山之作

- **基本信息**：Q. Zhang, W. Liu, E. Tsang, B. Virginas, "Expensive multiobjective optimization by MOEA/D with Gaussian process model", IEEE TEVC, vol. 14, no. 3, pp. 456-474, 2010. **Tier-1**。
- **算法动机**：①ParEGO 每代仅产 1 个新解，FE 利用率低；②仅训练单个 Kriging 难以同时表征多个 Pareto 区域。
- **核心思想**：把 MOEA/D 的分解思想嵌入 EGO 框架。预先生成 $N$ 个均匀权重向量（子问题），每个子问题独立训练一个 Kriging（共 $N$ 个或共享 $M$ 个），用 EI 准则同时给所有子问题各推荐 1 个候选，按多样性聚类筛 $K$ 个真实评估。
- **代理模型**：$M$ 个 Kriging（每个目标一个）+ 模糊 C-Means 聚类训练数据。
- **填充准则**：每个子问题的 Tchebycheff 聚合 EI；K-mean 选择批量评估解。
- **创新点**：①批量并行评估（$K\ge 5$）；②模糊 C-Means 聚类减少 GP 训练量；③天然支持超多目标（通过权重数量）。
- **流程**：
  1. LHS 采样初始化
  2. 每个目标训练一个 Kriging
  3. 对每个子问题 $i$：内部 MOEA/D 搜索最大化 $\mathrm{EI}_i$
  4. 模糊 C-Means 聚类，每个簇选 1 个代表，共 $K$ 个真实评估
  5. 更新 Kriging，重复
- **PlatEMO 实现**：`MOEA-D-EGO/MOEADEGO.m`，参数 `batch_size=5`；现代实现见 GitHub `mobo-d/MOEAD-EGO`。
- **后世影响**：DirHV-EI（2024）等批量并行 EHVI 工作的直接继承者。

---

##### A.1.4 MultiObjectiveEGO（2016, GECCO）

- **基本信息**：R. Hussein, K. Deb, "A generative Kriging surrogate model for constrained and unconstrained multi-objective optimization", GECCO 2016, pp. 573-580. **Conference**。
- **算法动机**：ParEGO 权重随机化导致同一 Pareto 区域被反复采样，效率低；可否系统化地遍历 Pareto 前沿方向？
- **核心思想**：使用 **Augmented Achievement Scalarizing Function (AASF)** 系统化生成 $H$ 个参考方向，每个方向训练一个独立的 Kriging 模型；每代为每个方向各推荐 1 个候选，从中选 `num_k` 个分布良好的解真实评估。同时支持约束（标签为 `<constrained/none>`）。
- **代理模型**：$H$ 个 Kriging（每个参考方向一个）+ $\alpha=0.7$ 比例的训练数据。
- **填充准则**：每个方向的 EI 最大化。
- **AASF 公式**：
$$
g^{aasf}(\mathbf{x}|\boldsymbol\lambda) = \max_i \frac{f_i - z_i^*}{\lambda_i} + \rho \sum_i \frac{f_i - z_i^*}{\lambda_i}
$$
- **创新点**：①生成式 Kriging（每方向独立模型）；②参考方向均匀分布替代随机权重；③统一框架处理约束/无约束。
- **PlatEMO 实现**：`MultiObjectiveEGO/MultiObjectiveEGO.m`，参数 `alpha=0.7, num_k=5, H=21`。

---

##### A.1.5 EIM-EGO（2017, IEEE TEVC）⭐⭐ EI 矩阵理论

- **基本信息**：D. Zhan, Y. Cheng, J. Liu, "Expected improvement matrix-based infill criteria for expensive multiobjective optimization", IEEE TEVC, vol. 21, no. 6, pp. 956-975, 2017. **Tier-1**。
- **算法动机**：EHVI（期望超体积改进）计算复杂度高（$O(N^M)$），如何在保留 EHVI 思想的前提下降低计算复杂度？
- **核心思想**：提出 **Expected Improvement Matrix (EIM)** — 在所有非支配解处独立计算改进的期望，得到一个 $|P|\times M$ 的矩阵，通过 Euclidean / Maximin / HV 三种聚合方式得到标量采集函数。三种聚合方式都有解析闭式表达，避免 HV 的组合爆炸。
- **代理模型**：$M$ 个独立 Kriging。
- **EIM 公式**（Maximin 形式）：对每个非支配解 $\mathbf{p}_j$ 与候选 $\mathbf{x}$：
$$
EI_{ij}(\mathbf{x}) = (p_{ij} - \hat\mu_i)\Phi\left(\frac{p_{ij}-\hat\mu_i}{\hat\sigma_i}\right) + \hat\sigma_i \phi(\cdot)
$$
然后聚合：$EIM_{maximin}(\mathbf{x}) = \min_j \max_i EI_{ij}(\mathbf{x})$
- **创新点**：①**统一框架**统一了 ParEGO/SMS-EGO/EHVI 三类准则；②**全闭式解析**，比 EHVI 快 1-2 个量级；③天然适合并行批量。
- **PlatEMO 实现**：`EIM-EGO/EIMEGO.m`，参数 `InfillCriterionIndex=1`（1=Euclidean，2=Maximin，3=HV）。
- **后世影响**：DirHV-EI（2024）的方向化 EHVI 思想可看作 EIM 的进一步发展。

---

#### A.2 SAEA-框架派系（4 个，与 RVEA/Two_Arch2/NSGA-III 等结合）

##### A.2.1 K-RVEA（2018, IEEE TEVC）⭐⭐ Kriging 进入超多目标领域

- **基本信息**：T. Chugh, Y. Jin, K. Miettinen, J. Hakanen, K. Sindhya, "A surrogate-assisted reference vector guided evolutionary algorithm for computationally expensive many-objective optimization", IEEE TEVC, vol. 22, no. 1, pp. 129-142, 2018. **Tier-1**。
- **算法动机**：MOEA/D-EGO 在 $M\ge 4$ 时性能退化（聚类崩溃、HV 爆炸）；RVEA（Cheng 等 2016）使用参考向量 + APD 准则在超多目标上表现好，但 RVEA 本身不带代理。如何将 Kriging 嵌入 RVEA 处理 EMaOP？
- **核心思想**：①每个目标训一个 Kriging；②内部 RVEA 进化 $w_{\max}=20$ 代仅用代理评估；③用一个**自适应模型管理**机制：在不确定度大与小之间切换两种填充准则——APD（探索 Pareto 前沿）与 angle-penalized uncertainty（探索高方差解）。
- **代理模型**：$M$ 个 Kriging。
- **填充准则**（角度惩罚距离 APD）：
$$
APD(\mathbf{x}) = (1+M\cdot P(t))\cdot \|\mathbf{F}(\mathbf{x})-\mathbf{z}^*\|
$$
其中 $P(t) = (t/t_{\max})^\alpha \cdot \theta$，$\theta$ 是与最近参考向量的夹角。
- **创新点**：①首次实现 Kriging 与参考向量框架的耦合；②自适应模型管理（$K_e=5$ 解每代）；③推动了后续大量 RVEA-based SAEA 工作。
- **流程**：
  1. LHS 初始化 + 全部真实评估
  2. 每目标训练 Kriging
  3. 内部 RVEA 跑 $w_{\max}$ 代（仅用 $\hat\mu$ 评估）
  4. 选 5 个候选，根据收敛/多样性需求切换准则
  5. 真实评估更新 Kriging
- **PlatEMO 实现**：`K-RVEA/KRVEA.m`，参数 `alpha=2, wmax=20, mu=5`。
- **后世影响**：直接催生了 KTA2、PB-RVEA、AB-SAEA 等"代理 + RVEA"系列。

---

##### A.2.2 KTA2（2021, IEEE TEVC）⭐ 双档案 Kriging 辅助

- **基本信息**：Z. Song, H. Wang, C. He, Y. Jin, "A Kriging-assisted two-archive evolutionary algorithm for expensive many-objective optimization", IEEE TEVC, vol. 25, no. 6, pp. 1013-1027, 2021. **Tier-1**。
- **算法动机**：K-RVEA 仅用单一种群，难以同时管理收敛与多样性两个矛盾目标；Two_Arch2（Wang 2014）用 CA（收敛档案）和 DA（多样性档案）双档案管理但不带代理。如何把 Two_Arch2 与 Kriging 结合？
- **核心思想**：①CA 存储收敛性最好的解，DA 存储多样性最好的解；②Kriging 模型分别由 CA 和 DA 的数据更新（K_UpdateCA / K_UpdateDA）；③用 **Wilcoxon signrank 假设检验**比较候选解的代理预测，决定是否真实评估。
- **代理模型**：$M$ 个 Kriging（基于 DA + CA 的合并数据）。
- **填充准则**：自适应采样 — 当存档拥挤度变化小时偏向收敛准则，反之偏向多样性。
- **关键创新**：
  - 双档案 CA/DA 解耦收敛与多样性管理
  - 引入 Wilcoxon signrank 检验作为模型不确定度的非参数替代（`signrank_new.m`、`statsrexact.m`）
  - 参数 `tau=0.75` 控制噪声点比例，`phi=0.1` 控制随机选个体比例
- **PlatEMO 实现**：`KTA2/KTA2.m`，子文件 `Adaptive_sampling.m`、`UpdateCA.m`、`UpdateDA.m`。

---

##### A.2.3 PB-NSGA-III（2022, Memetic Computing）

- **基本信息**：Z. Song, H. Wang, H. Xu, "A framework for expensive many-objective optimization with Pareto-based bi-indicator infill sampling criterion", Memetic Computing, vol. 14, pp. 179-191, 2022. **Tier-3**。
- **算法动机**：单一指标准则（仅收敛 EI、仅多样性 angle）易陷入局部最优；如何同时考虑两个指标？
- **核心思想**：提出 **Pareto-based Bi-Indicator (PB)** 准则——把每个候选解的"收敛性指标 $C(\mathbf{x})$"和"多样性指标 $D(\mathbf{x})$"作为两维"目标"，对候选解集做非支配排序，选 PB 准则上的非支配前沿作为真实评估对象。
- **代理模型**：$M$ 个 Kriging。
- **创新点**：①把 infill 准则视为多目标决策问题；②与 NSGA-III 的参考点框架自然契合。
- **PlatEMO 实现**：`PB-NSGA-III/PBNSGAIII.m`，参数 `wmax=15`。

##### A.2.4 PB-RVEA（2022, Memetic Computing）

- **基本信息**：与 PB-NSGA-III 同一论文，"...within RVEA framework"。**Tier-3**。
- **核心思想**：与 PB-NSGA-III 同源，将 PB 双指标准则嵌入 RVEA 而非 NSGA-III。
- **创新点**：在 RVEA 的 APD 准则之外提供 PB 替代方案，实验显示在 DTLZ1-7 上更稳健。
- **PlatEMO 实现**：`PB-RVEA/PBRVEA.m`，参数 `alpha=2, wmax=15`。

---

#### A.3 高级采集函数派系（4 个，2023-2024 新作）

##### A.3.1 EMMOEA（2023, IEEE TEVC）

- **基本信息**：S. Qin, C. Sun, Q. Liu, Y. Jin, "A performance indicator-based infill criterion for expensive multi-/many-objective optimization", IEEE TEVC, vol. 27, no. 4, pp. 1085-1099, 2023. **Tier-1**。
- **算法动机**：经典 EI/EHVI 仅考虑收敛贡献，忽略多样性；如何用一个**性能指标**（如 IGD+）作为统一采集函数？
- **核心思想**：用 Kriging 预测的均值 $\hat\mu$ 与方差 $\hat\sigma^2$ 计算候选解加入种群后**性能指标的期望改进**，把"指标增益"作为单一采集函数。
- **代理模型**：$M$ 个 Kriging。
- **填充准则**：Expected Performance Indicator Improvement
$$
EPII(\mathbf{x}) = \mathbb{E}[I(P\cup\{\mathbf{F}(\mathbf{x})\}) - I(P)]
$$
其中 $I$ 为 IGD+ 或类似指标，$\mathbf{F}(\mathbf{x})\sim\mathcal{N}(\hat{\boldsymbol\mu},\mathrm{diag}(\hat{\boldsymbol\sigma}^2))$。
- **创新点**：①用单个性能指标统一收敛与多样性；②可灵活替换不同性能指标；③通过蒙特卡洛积分计算 EPII。
- **PlatEMO 实现**：`EMMOEA/EMMOEA.m`，参数 `gmax=10`。

---

##### A.3.2 NSGAIII-EHVI（2023, IEEE TEVC）

- **基本信息**：Y. Pang et al., "An expensive many-objective optimization algorithm based on efficient expected hypervolume improvement", IEEE TEVC, vol. 27, no. 6, pp. 1822-1836, 2023. **Tier-1**。
- **算法动机**：EHVI 在 $M\ge 4$ 时计算量爆炸（$O(N^M)$），无法应用于超多目标。
- **核心思想**：①把 EHVI 用蒙特卡洛**重要性采样**近似，让 EHVI 计算复杂度降到 $O(N\cdot \text{nSample})$；②嵌入 NSGA-III 的参考点框架获得均匀分布。
- **填充准则**：
$$
\mathrm{EHVI}(\mathbf{x}) \approx \frac{1}{N_s}\sum_{k=1}^{N_s} \Delta\mathrm{HV}(\mathbf{F}^{(k)}, P^*) \cdot w^{(k)}
$$
- **创新点**：①重要性采样大幅降低 EHVI 计算复杂度；②参数 `LB=-0.5, UB=1.2, nSample=10000` 控制采样区间。
- **PlatEMO 实现**：`NSGAIII-EHVI/NSGAIIIEHVI.m`，参数 `wmax=15, randp=0.3`。

---

##### A.3.3 DirHV-EI（2024, IEEE TEVC）⭐⭐ 方向化 EHVI

- **基本信息**：L. Zhao, Q. Zhang, "Hypervolume-guided decomposition for parallel expensive multiobjective optimization", IEEE TEVC, vol. 28, no. 2, pp. 432-444, 2024. **Tier-1**。
- **算法动机**：EHVI 计算难、不易并行批量；MOEA/D-EGO 的 Tchebycheff 分解+EI 不直接对应 HV 改进。能否把 EHVI 沿权重方向**精确分解**？
- **核心思想**：作者证明：若把 EHVI 视为各权重方向上"局部 HV 改进期望"的加权和，则在均匀权重向量集上每个方向独立计算 EI 即可重构出 EHVI；这一分解称为 **Direction-based HV Expected Improvement (DirHV-EI)**。具备：①闭式解析；②天然并行批量（$K=5$ 解/代）；③与 MOEA/D 框架完美契合。
- **代理模型**：$M$ 个 Kriging。
- **填充准则**：每个权重方向 $\boldsymbol\lambda_i$ 独立计算 DirHV-EI，按多样性聚类批量选 5 个。
- **关键创新**：
  - **解析等价性**：$\mathrm{EHVI} = \int_\Lambda \mathrm{DirEI}(\mathbf{x},\boldsymbol\lambda) d\boldsymbol\lambda$
  - **天然批量**：可一次推荐 $K$ 个解（不需 KB 启发式）
  - 实验显示在 ZDT/DTLZ/WFG 上击败 MOEA/D-EGO、SMS-EGO、EIM-EGO
- **PlatEMO 实现**：`DirHV-EI/DirHVEI.m`，参数 `batch_size=5`；GitHub: `mobo-d/DirHV-EGO`。

---

##### A.3.4 DISK（2024, IEEE TEVC）⭐ 分布信息增强

- **基本信息**：Z. Zhang, Y. Wang, G. Sun, T. Pang, "A distribution information based Kriging-assisted evolutionary algorithm for expensive many-objective optimization problems", IEEE TEVC, 2024. **Tier-1**。
- **算法动机**：现有 SA-EMaOP 仅用 Kriging 的均值/方差，未利用种群整体分布信息（CMA-ES 风格的均值 $\boldsymbol\mu$ 与协方差 $\boldsymbol\Sigma$）；如何把分布信息注入排序与选择？
- **核心思想**：①跟踪种群的全局分布参数 $(\boldsymbol\mu, \boldsymbol\Sigma)$；②提出 **NDSort_DIPD**（基于分布信息的支配排序），把每个解的"概率密度"作为排序辅助键；③在 LocalSearch 阶段用分布参数引导局部搜索方向。
- **代理模型**：$M$ 个 Kriging。
- **关键创新**：
  - **分布感知排序**：在传统非支配排序基础上加入分布密度信息
  - **多阶段环境选择**：`SEnvironmentalSelection.m`（代理空间）+ `EnvironmentalSelection.m`（真实空间）
  - **自适应探索机制**：通过 `IdentifyW.m` 识别需要探索的权重区域
- **PlatEMO 实现**：`DISK/DISK.m`，参数 `wmax=60, alpha=5`；子函数 `NDSort_DIPD.m`、`IdentifyW.m`、`LocalSearch.m`。
- **关联工作**：DISKplus（同作者，约束扩展，本综述已排除）。

---

#### A.4 自适应/特殊派系（4 个）

##### A.4.1 AB-SAEA（2020, Information Sciences）

- **基本信息**：X. Wang, Y. Jin, S. Schmitt, M. Olhofer, "An adaptive Bayesian approach to surrogate-assisted evolutionary multi-objective optimization", Information Sciences, vol. 519, pp. 317-331, 2020. **Tier-1**（中科院一区 Top）。
- **算法动机**：固定的 Kriging 超参数（如核函数尺度）在不同搜索阶段不一定最优；如何让 Kriging 在探索期与开发期自动调节？
- **核心思想**：贝叶斯框架下用动态熵权重 $\alpha$ 在搜索过程中自适应调整 Kriging 模型对探索（高方差）vs 开发（低均值）的偏向；与 RVEA 框架结合。
- **代理模型**：$M$ 个 Kriging，`THETA=5*ones(M,D)` 初始尺度。
- **填充准则**：自适应贝叶斯采集函数（含 alpha 控制 explore/exploit）。
- **创新点**：①参数 `alpha=2` 控制熵罚率；②与 K-RVEA 框架兼容。
- **PlatEMO 实现**：`AB-SAEA/ABSAEA.m`，参数 `alpha=2, wmax=20, mu=5`。

##### A.4.2 PIEA（2024, Information Sciences）

- **基本信息**：Y. Li, W. Li, S. Li, Y. Zhao, "A performance indicator-based evolutionary algorithm for expensive high-dimensional multi-/many-objective optimization", Information Sciences, 2024, 121045. **Tier-1**（中科院一区 Top）。
- **算法动机**：固定的填充准则在不同问题特征下表现不稳定；如何用历史性能信息自适应选择？
- **核心思想**：维护一个长度为 `tau=20` 的历史改进窗口，统计近期不同 infill 准则的有效性；用 ranking-based 性能指标 + 预选机制（`eta=5` 个预选幸存者）+ 重复生成上限（`R_max=20`）。
- **代理模型**：$M$ 个 Kriging。
- **创新点**：①历史窗口自适应；②预选机制减少代理误差影响。
- **PlatEMO 实现**：`PIEA/PIEA.m`，参数 `eta=5, R_max=20, tau=20`。

##### A.4.3 PIMD（2024, EAAI）

- **基本信息**：Y. Li, W. Li, Y. Zhao, S. Li, "An infill sampling criterion based on improvement of probability and mapping crowding distance for expensive multi/many-objective optimization", EAAI, vol. 133, 108616, 2024. **Tier-1**（中科院一区）。
- **算法动机**：超多目标下 Pareto 前沿密度估计困难，传统拥挤距离 (CD) 在 $M\ge 4$ 时几乎失效；如何重新设计多样性度量？
- **核心思想**：提出 **Mapping Crowding Distance (MCD)** — 把高维目标空间通过参考向量映射到一维标量上计算 CD；结合 **Probability of Improvement (PoI)** 准则形成 PIMD 双准则。
- **代理模型**：$M$ 个 Kriging。
- **填充准则**：
$$
\mathrm{Score}(\mathbf{x}) = \mathrm{PoI}(\mathbf{x}) \cdot \mathrm{MCD}(\mathbf{x})
$$
- **创新点**：①映射拥挤距离解决高维 CD 失效；②与 PoI 联合提高超多目标性能。
- **PlatEMO 实现**：`PIMD/PIMD.m`，参数 `wmax=15, eta=5`。

##### A.4.4 TEA（2024, IEEE TSMCS）⭐ 两阶段 Kriging

- **基本信息**：Z. Zhang, Y. Wang, J. Liu, G. Sun, K. Tang, "A two-phase Kriging-assisted evolutionary algorithm for expensive constrained multiobjective optimization problems", IEEE TSMCS, vol. 54, no. 8, pp. 4579-4591, 2024. **Tier-1**。
- **标签说明**：`<constrained/none>`，无约束模式可用，故纳入综述。
- **算法动机**：约束/无约束统一框架；阶段化搜索（先粗后细）。
- **核心思想**：分两阶段——Phase 1 无约束导向收敛（理想点驱动），Phase 2 满足约束/精细化搜索；阶段切换由理想点变化率（变化连续 $ct_{\max}=2$ 次小于阈值）驱动。
- **代理模型**：$M+|C|$ 个 Kriging（目标 + 约束各一个）。
- **创新点**：①两阶段切换；②基于理想点变化率的自适应切换条件；③统一处理有/无约束。
- **PlatEMO 实现**：`TEA/TEA.m`，参数 `wmax=20, mu=5`。

---

### 3.2 流派 B：分类器代理类（3 个）

本流派不再回归目标函数值，转而训练一个**分类器**预测候选解的"质量类别"（优 / 劣 / 中），把回归问题变为分类问题。优势：①分类比回归对训练样本数要求更低；②对目标函数高度非线性、多模态等情况更鲁棒；③天然适合超多目标（分类只需"好/坏"标签，与目标维度解耦）。

#### B.1 CPS-MOEA（2015, CEC）⭐ 分类器代理的奠基工作

- **基本信息**：J. Zhang, A. Zhou, G. Zhang, "A classification and Pareto domination based multiobjective evolutionary algorithm", CEC 2015, pp. 2883-2890. **Conference**。
- **算法动机**：早期 SAEA 几乎都用回归代理，能否改用分类器？分类训练数据更易构造（仅需正负样本），噪声鲁棒性也更好。
- **核心思想**：基于 Pareto 支配关系把当前种群划分为"好类"（非支配前沿）与"坏类"（被支配解）；对每个候选解 $\mathbf{x}$ 用 **k-NN 分类器**预测其属于"好类"的概率，按概率筛选送真实评估。
- **代理模型**：k-NN 二分类器（基于 Euclidean 距离投票）。
- **训练样本**：好类 = 当前种群第一前沿，坏类 = 被支配解。
- **填充准则**：每个父代生成 $M=3$ 个子代，预测概率最高的送真实评估。
- **创新点**：①首次提出"分类代理 + Pareto 支配"框架；②训练数据自然来源于 Pareto 比较，无需聚合函数；③简洁可靠（k-NN 仅需调 k 值）。
- **流程**：
  1. 初始化种群与档案
  2. 非支配排序划分好/坏类
  3. 父代每个解生成 $M$ 子代（DE 或 SBX）
  4. k-NN 预测每个子代属于"好类"概率
  5. 选概率最大者送真实评估
- **PlatEMO 实现**：`CPS-MOEA/CPSMOEA.m`，参数 `M=3`（每个父代生成的子代数）。
- **历史地位**：开启了"分类器辅助 SAEA"流派，后续 CSEA、MCEA/D 等均受其启发。

---

#### B.2 CSEA（2019, IEEE TEVC）⭐⭐ 分类代理在超多目标上的突破

- **基本信息**：L. Pan, C. He, Y. Tian, H. Wang, X. Zhang, Y. Jin, "A classification based surrogate-assisted evolutionary algorithm for expensive many-objective optimization", IEEE TEVC, vol. 23, no. 1, pp. 74-88, 2019. **Tier-1**。
- **算法动机**：CPS-MOEA 仅适用于 2-3 目标；超多目标 ($M\ge 4$) 下 Pareto 支配关系几乎全为非支配，分类标签失效。如何在超多目标场景重新构造分类？
- **核心思想**：①引入 **参考解集** $S_{ref}$（$k$ 个分布良好的代表解）；②对候选解 $\mathbf{x}$ 与每个参考解 $\mathbf{r}_i$ 比较，构造 $k$ 个二分类样本（"$\mathbf{x}$ 优于 $\mathbf{r}_i$" vs "$\mathbf{x}$ 不优于 $\mathbf{r}_i$"）；③用 **前馈神经网络（FNN）** 学习这种"相对参考解"的优劣关系。
- **代理模型**：单个 FNN（输入 $D$ 维，输出 $k$ 维概率，每维对应一个参考解的"优劣"概率）。
- **训练样本**：通过 `RefSelect.m` 选 $k=6$ 个参考解；通过 `DataProcess.m` 构造 $(x, \text{label})$ 对。
- **填充准则**：内部进化 `gmax=3000` 代仅用 FNN 评估；选 FNN 综合得分最高者送真实评估。
- **关键创新**：
  - **参考解机制**让 FNN 在超多目标下仍能稳定分类
  - **目标维度解耦**：FNN 输出维度由参考解数量 $k$ 决定，与目标数 $M$ 无关
  - **可视化辅助**：`RadarGrid.m` 提供雷达图分析
- **流程**：
  1. LHS 初始化 + 评估 $\min(11D-1, 109)$ 解
  2. `RefSelect` 选 $k$ 个参考解
  3. `DataProcess` 构造分类训练集
  4. 训练 FNN
  5. 内部 GA 跑 `gmax` 代仅用 FNN 评估
  6. 选最优送真实评估
- **PlatEMO 实现**：`CSEA/CSEA.m`，参数 `k=6, gmax=3000`；子文件 `SurrogateAssistedSelection.m`、`GetOutput.m`。
- **后世影响**：是 REMO（2022）"关系学习"思想的直接前身。

---

#### B.3 MCEA/D（2022, IEEE TEVC）⭐⭐ 分解 + 多分类器并行

- **基本信息**：T. Sonoda, M. Nakata, "Multiple classifiers-assisted evolutionary algorithm based on decomposition for high-dimensional multi-objective problems", IEEE TEVC, vol. 26, no. 6, pp. 1581-1595, 2022. **Tier-1**。
- **算法动机**：CSEA 用单个 FNN 在所有解上做分类，无法精细化每个 Pareto 区域；MOEA/D 的子问题分解能否结合分类器思想？
- **核心思想**：①把 MOEA/D 的 $N$ 个子问题独立处理；②为每个子问题训练一个独立 **SVM 二分类器**（"子问题 $i$ 上优 vs 劣"）；③对每个子问题生成至多 `Rmax=10` 个候选，仅 SVM 预测为"优"的解送真实评估；④邻域更新（`delta=0.9` 概率从邻域选父代，`nr=2` 邻居替换上限）。
- **代理模型**：$N$ 个 SVM 分类器（每个子问题一个），训练数据按 Tchebycheff 聚合值排序得正负样本。
- **填充准则**：SVM 预测概率高于阈值则真实评估；超过 `Rmax` 次仍无优解则取最好候选。
- **关键创新**：
  - **多分类器并行**：每个子问题独立 SVM，比 CSEA 的单 FNN 更精细
  - **聚合函数构造样本**：用 Tchebycheff 值排序得到子问题的"优劣"标签
  - **MOEA/D 邻域更新**保留了分解算法的搜索动力学
  - 高维变量（`<real/integer>` 标签）友好
- **流程**：
  1. LHS 初始化每子问题种群
  2. 为每子问题计算 Tchebycheff 值，排序得正负样本
  3. 训练 $N$ 个 SVM
  4. 对每个子问题：邻域采样父代 → DE 生成至多 `Rmax` 个候选 → SVM 筛选 → 真实评估最优
  5. 邻域更新（最多替换 `nr` 个邻居）
- **PlatEMO 实现**：`MCEA-D/MCEAD.m`，参数 `delta=0.9, nr=2, Rmax=10`；子文件 `SVM.m`（SVM 训练）、`SolutionGeneration.m`（候选生成）。
- **关联工作**：与 REMO 同年发表于 TEVC，但 MCEA/D 走"分类 + 分解"路线，REMO 走"关系学习 + 自定义"路线。

---

### 3.3 流派 C：关系学习/成对比较类（2 个）

本流派进一步把"分类"问题精炼为"成对比较"问题：不再预测单个解的类别，而是预测两个解之间的相对关系（A 优于 B / B 优于 A / 等价）。**关键洞见**：在昂贵 MOO 中，预测两个解的优劣比预测每个解的精确目标值更容易，因为前者只需要捕捉"相对偏好"而非"绝对值"。本流派天然适配 RankNet/Bradley-Terry 等学习排序模型。

#### C.1 REMO（2022, IEEE TEVC）⭐⭐⭐ 关系学习 SAEA 的标杆

- **基本信息**：H. Hao, A. Zhou, H. Qian, H. Zhang, "Expensive multiobjective optimization by relation learning and prediction", IEEE TEVC, vol. 26, no. 5, pp. 1157-1170, 2022. **Tier-1**。
- **算法动机**：①目标函数高度非线性时，回归代理（Kriging/RBF）难以精确拟合 → 误导填充准则；②CSEA（2019）的分类只是"绝对优劣"，未利用解之间的相对关系；③能否设计一种"看到两个解直接判断谁更好"的代理？
- **核心思想**：训练一个**前馈神经网络（FNN）** 学习两个解之间的支配关系（pairwise relation classification），输出三类标签：A 优于 B（label=1）、B 优于 A（label=-1）、等价（label=0）。在子代生成阶段，让 FNN 比较候选解与参考解（或种群解），筛选出 FNN 判定为"优"的候选送真实评估。
- **代理模型**：单个 FNN（输入 $2D$ 维：两个解决策变量拼接；输出 3 维 one-hot）
  - 隐藏层结构：`[ceil(2D*1.5), 2D, ceil(2D/2)]`
  - 训练：`patternnet` + 反向传播
  - 输入归一化：`mapminmax` 到 [-1, 1]
- **训练样本构造**（`GetRelationPairs.m`）：
  - 第一步：通过 PBI 把当前种群划分为"好类 C1"（接近参考解）与"不好类 C2"
  - 第二步：枚举 4 种配对：C1×C1=0（等价）、C1×C2=1（优）、C2×C1=-1（劣）、C2×C2=0（等价）
  - 第三步：归一化、`onehotconv` 转 one-hot 编码
- **填充准则**：内部 GA 跑 `gmax=3000` 代仅用 FNN 评估每个新解 vs 参考解的关系；筛选 FNN 判定 "优于多数参考解" 者送真实评估。
- **关键创新**：
  1. **关系学习替代回归/分类**：从根本上改变了代理目标
  2. **目标维度无关**：FNN 输入仅是决策变量，目标维度通过 PBI 隐式编码进训练标签，故天然支持超多目标 ($M\le 10$)
  3. **参考解机制 + PBI 标签**：用参考解（`RefSelect.m`）与 PBI 距离划分好/坏类
  4. **训练数据组合爆炸**：$|C_1|\times|C_2|$ 配对样本充足（无小样本问题）
  5. **代码清晰**：算法主体仅 ~100 行，可读性强
- **流程**（PlatEMO 实现）：
  1. LHS 采样 $N=11D-1$ 初始解（$D\le 10$）或 $N=100$（$D>10$），全部真实评估，进入档案 `Archive`
  2. **主循环**：
     a. `RefSelect(Population, k=6)` → 选 6 个参考解
     b. `GetOutput_PBI` → 用 PBI 把种群分为 C1/C2 类
     c. `GetRelationPairs(Input, Catalog)` → 构造关系对数据集
     d. `DataProcess` → 3:1 划分训练/测试集
     e. `mapminmax` → 归一化；`onehotconv` → 标签 one-hot
     f. `patternnet` 训练 FNN（3 层），计算测试错误率 `p_err`
     g. `RSurrogateAssistedSelection` → 内部 GA 跑 `gmax=3000` 代仅用 FNN 评估
     h. 筛出的新解 `Next` 送真实评估，加入 `Archive`
     i. `RefSelect(Archive, N)` → 重新生成下一代种群
- **关键公式**：
  - **PBI 距离**：$d^{PBI}_i = d_1 + \theta\cdot d_2$，其中 $d_1=\|(\mathbf{F}-\mathbf{z}^*)^\top \boldsymbol\lambda_i\|$, $d_2=\|\mathbf{F}-\mathbf{z}^*-d_1\boldsymbol\lambda_i\|$
  - **FNN 输出**：$\hat{y}(\mathbf{x}_a, \mathbf{x}_b) = \text{softmax}(W_3\sigma(W_2\sigma(W_1[\mathbf{x}_a;\mathbf{x}_b])))$
- **PlatEMO 实现**：`REMO/REMO.m`，参数 `k=6, gmax=3000`；子文件：
  - `RefSelect.m`：参考解选择
  - `GetOutput_PBI.m`：PBI 分类
  - `GetRelationPairs.m`：关系对生成
  - `DataProcess.m`：数据划分与归一化
  - `RSurrogateAssistedSelection.m`：代理辅助筛选
  - `Delequalsamples.m`：去重
  - `onehotconv.m`：one-hot 编码
- **历史地位**：是 2022 年以来 SAEA 关系学习路线的标杆；用户的 D-REMO、R2-REMO、DSR-REMO 等系列均基于 REMO 的关系学习思想做改进（如增加距离回归、引入 R2 指标、SDE 多样性等）。
- **后续衍生**：PC-SAEA（2023, SWEVO）将 FNN 换为 RBFN；用户仓库的 26 个 REMO 衍生变体探索了多种改进方向。

---

#### C.2 PC-SAEA（2023, SWEVO）⭐ 成对比较的 RBFN 版本

- **基本信息**：Y. Tian, J. Hu, C. He, H. Ma, L. Zhang, X. Zhang, "A pairwise comparison based surrogate-assisted evolutionary algorithm for expensive multi-objective optimization", Swarm and Evolutionary Computation, vol. 80, 101323, 2023. **Tier-1**（中科院一区 Top）。
- **算法动机**：REMO 用 FNN 做关系学习虽精度高但训练慢、超参敏感；能否换成更简洁的 RBFN？此外 REMO 直接用 FNN 输出做决策，缺少**可靠性度量**——当 FNN 误差高时该如何调整策略？
- **核心思想**：①把 REMO 的 FNN 替换为 **RBFNNPC**（Pairwise Comparison RBF 神经网络）；②设计**双错误率 $E_1, E_2$**作为可靠性度量；③提出 `delta=0.8` 阈值：当模型可靠时直接用 RBFN 决策，否则切换到 ES（Effective Selection）适应度。
- **代理模型**：RBFNNPC（径向基核 = 0.1925）+ 输入维度 $D$（不是 $2D$ 拼接，而是单解输入，通过 `Pmid` 中点机制实现成对比较）。
- **训练样本**（`CalFitnessPC.m`）：基于演化进度 `Problem.FE/Problem.maxFE` 自适应调整正负样本平衡。
- **填充准则**（`SurrogateAssistedSelectionPC.m`）：内部 GA 跑 `gmax=3000` 代，用 RBFN 与中点 `Pmid` 比较；可靠性低于 `delta` 时切换到 ES 适应度。
- **关键创新**：
  - **RBFN 替代 FNN**：训练快、稳定（适合小样本）
  - **双错误率可靠性度量**：$E_1$=正确分类率，$E_2$=错误分类率；可靠时 `RBFN 决策`，不可靠时 `ES 决策`
  - **演化进度感知**：训练样本平衡随 FE 进度自适应
- **流程**：
  1. LHS 采样 $\max(11D-1, N)$ 初始解
  2. **主循环**：
     a. `CalFitnessPC` → 平衡训练样本（输入 $X$、输出 $Y$、参考点 $Pa$、中点 $Pmid$）
     b. `DataProcess` → 划分训练/测试
     c. `RBFNNPC(0.1925)` → 训练 RBFN
     d. `lastpredict` → 测试集预测，计算 $E_1, E_2$
     e. `SurrogateAssistedSelectionPC` → 内部 GA 跑 `gmax` 代代理筛选
     f. 真实评估 `Next`，加入档案
     g. `EnvironmentalSelection` → 更新种群
- **PlatEMO 实现**：`PC-SAEA/PCSAEA.m`，参数 `delta=0.8, gmax=3000`；子文件：
  - `CalFitnessPC.m`：成对适应度计算
  - `RBFNNPC.m`：RBFN-PC 模型类
  - `SurrogateAssistedSelectionPC.m`：代理筛选
  - `ESCalFitness.m`：ES 备用适应度
- **与 REMO 的对比**：相同框架但代理换成 RBFN，加入可靠性切换机制；在低维 ($D\le 30$) 上略快，超多目标 ($M\ge 8$) 上不如 REMO 鲁棒。

---

### 3.4 流派 D：神经网络/深度学习类（3 个）

本流派的共同特点是用**神经网络（NN）** 而非 Kriging 作为代理。动机：①Kriging 训练复杂度 $O(N^3)$，在样本数 $N>500$ 或维度 $D>30$ 时不可扩展；②NN 可通过批量梯度下降在 GPU 上训练；③通过 Dropout / SOM 等技巧让 NN 也能输出不确定度。

#### D.1 ADSAPSO（2022, Complex & Intelligent Systems）

- **基本信息**：J. Lin, C. He, R. Cheng, "Adaptive dropout for high-dimensional expensive multiobjective optimization", Complex & Intelligent Systems, vol. 8, no. 1, pp. 271-285, 2022. **Tier-2**（中科院二区）。
- **算法动机**：高维变量 ($D\ge 50$) 下 Kriging 不可扩展；普通 NN 易过拟合且无不确定度。Dropout 在分类网络中常用，能否用于 SAEA 的回归代理？
- **核心思想**：①使用神经网络代理目标函数；②训练阶段加入 **Dropout 层**（比例 $\beta=0.5$）防过拟合；③在预测阶段保留 Dropout（MC-Dropout），多次前向传播得到预测均值与方差作为不确定度估计；④用 PSO 作为外层进化框架。
- **代理模型**：含 Dropout 层的 NN（输入 $D$，输出 $M$）。
- **填充准则**：用 NN 预测 + Dropout 不确定度构造类 LCB 准则；与 PSO 速度更新协同。
- **关键创新**：
  - **自适应 Dropout 率** $\beta$：根据当前样本数与维度比 $N/D$ 自适应调节
  - **MC-Dropout 不确定度**：Gal & Ghahramani (2016) 的贝叶斯近似在 SAEA 上首次系统化应用
  - **PSO 协同**：用 PSO 而非 GA 适配高维
- **流程**：
  1. LHS 初始化 `Init_Num=100` 解
  2. 选 `N_a=200` 个用于训练，`N_s=50` 个区分好/差
  3. 训练含 Dropout 的 NN
  4. PSO 进化，用 NN 预测均值与方差作适应度
  5. 选 `k=5` 个候选送真实评估
- **PlatEMO 实现**：`ADSAPSO/ADSAPSO.m`，参数 `k=5, beta=0.5`；需 Deep Learning Toolbox。

---

#### D.2 EDN-ARMOEA（2022, IEEE TSMCS）⭐⭐ Dropout NN 进入超多目标顶刊

- **基本信息**：D. Guo, X. Wang, K. Gao, Y. Jin, J. Ding, T. Chai, "Evolutionary optimization of high-dimensional multiobjective and many-objective expensive problems assisted by a dropout neural network", IEEE TSMCS, vol. 52, no. 4, pp. 2084-2097, 2022. **Tier-1**。
- **算法动机**：①K-RVEA（2018）的 Kriging 在 $D\ge 30, M\ge 5$ 时性能急剧退化；②Kriging 不可批量训练，每次更新需重训；③能否用 Dropout NN 代替 Kriging，并嵌入 AR-MOEA（Tian 2018）框架？
- **核心思想**：① **Efficient Dropout Network (EDN)**：在 NN 末端加 Dropout，多次采样得到均值与方差；②嵌入 AR-MOEA 的自适应参考点机制；③用多样性阈值 `delta=0.05` 控制采样切换。
- **代理模型**：单个 EDN（输入 $D$ 维 → 隐藏层 → Dropout → 输出 $M$ 维）。
- **填充准则**：基于 EDN 均值/方差的 LCB；当多样性指标低于 `delta` 时偏向多样性补充。
- **关键创新**：
  - **Dropout 作为变分贝叶斯近似**：理论支撑（Gal & Ghahramani）
  - **批量训练**：NN 训练复杂度 $O(N\cdot D)$ 远低于 Kriging $O(N^3)$
  - **AR-MOEA 框架适配**：用自适应参考点处理超多目标
  - **wmax=20** 代代理评估周期，每次重训增量训练
- **PlatEMO 实现**：`EDN-ARMOEA/EDNARMOEA.m`，参数 `delta=0.05, wmax=20, Ke=3`；需 Deep Learning Toolbox。
- **后世影响**：是 SAEA 走向"深度学习化"的标志性工作。

---

#### D.3 SSDE（2024, SWEVO）⭐ 自组织映射代理

- **基本信息**：A. F. R. Araújo, L. R. C. Farias, A. R. C. Gonçalves, "Self-organizing surrogate-assisted non-dominated sorting differential evolution", Swarm and Evolutionary Computation, vol. 91, 101703, 2024. **Tier-1**（中科院一区 Top）。
- **标签**：`<multi/many> <real/integer> <constrained/none> <expensive>`，无约束模式可用。
- **算法动机**：常规 NN 无空间结构，难以利用解的拓扑邻近性；自组织映射（SOM）天然保持拓扑——能否用 SOM 作代理？
- **核心思想**：①训练 **SOM**（自组织映射）将已评估解组织到二维潜空间格点；②每个 SOM 神经元代表一个局部"原型解"，存储其平均目标值作为代理；③DE 配对时优先选择潜空间邻居；④非支配排序在真实空间执行。
- **代理模型**：SOM（参数 `num_nodes` 控制每维神经元数；学习率 `eta0=0.2`；邻域 `sigma0`）。
- **填充准则**：DE 子代评估通过 SOM 邻居均值近似；选 SOM 拓扑稀疏区的解送真实评估。
- **关键创新**：
  - **拓扑保持代理**：SOM 把决策空间几何信息编码进代理
  - **邻域配对**：DE 父代来自 SOM 邻域，提高局部搜索效率
  - **统一框架**：同时支持有约束、无约束
- **PlatEMO 实现**：`SSDE/SSDE.m`，参数 `num_nodes`、`eta0=0.2`、`sigma0`。

---

### 3.5 流派 E：异构集成代理类（2 个）

本流派的核心思想：**单一代理模型在各种问题特征上表现不稳定**，可通过集成多种异构代理（GP+RBF+CART+kNN 等）取长补短。理论基础是机器学习中的 No-Free-Lunch 定理与 Bagging/Boosting 思想。

#### E.1 HeE-MOEA（2019, IEEE TCYB）⭐⭐ 异构集成的早期代表

- **基本信息**：D. Guo, Y. Jin, J. Ding, T. Chai, "Heterogeneous ensemble-based infill criterion for evolutionary multiobjective optimization of expensive problems", IEEE TCYB, vol. 49, no. 3, pp. 1012-1025, 2019. **Tier-1**。
- **算法动机**：单一代理（如 Kriging）在特定问题特征上偏差较大；NN 代理过拟合风险高。能否用多种代理的集成提升鲁棒性？
- **核心思想**：①训练多个**异构基学习器**（CART 决策树、KNN、RBFN、Kriging 等）；②基于每个学习器在测试集上的误差分配投票权重；③用集成预测值与一致性度量（不同模型分歧度）共同决定填充准则。
- **代理模型**：异构集成（CART + KNN + RBFN + GP），加权投票。
- **填充准则**：集成均值预测 + 模型分歧度（disagreement）作为不确定度。
- **关键创新**：
  - **异构模型互补**：不同代理在不同问题特征上互补
  - **分歧度 = 不确定度**：模型间预测差异大处即为不确定度大处（类似 Query-by-Committee 主动学习）
  - **Ke=5** 解每代真实评估
  - **依赖 Deep Learning Toolbox**（部分模型实现）
- **PlatEMO 实现**：`HeE-MOEA/HeEMOEA.m`，参数 `Ke=5`；需 Deep Learning Toolbox。
- **后世影响**：异构集成思想被 ESBCEO、多种自适应代理选择算法继承。

---

#### E.2 ESBCEO（2023, KBS）⭐ 局部 Kriging 协同进化 + 熵搜索

- **基本信息**：H. Bian, J. Tian, J. Yu, H. Yu, "Bayesian co-evolutionary optimization based entropy search for high-dimensional many-objective optimization", Knowledge-Based Systems, vol. 274, 110630, 2023. **Tier-1**（中科院一区）。
- **算法动机**：①全局 Kriging 在 $N\ge 200$ 时训练慢（$O(N^3)$）；②高维超多目标下单一全局模型精度差；③传统 EI 不直接捕捉"信息增益"。
- **核心思想**：①使用**多个局部 Kriging 模型**：每个子问题维护两个局部窗口（$L_1=80, L_2=20$ 训练点）的 GP；②**协同进化**：多个子种群分别由不同局部模型引导；③**熵搜索（Entropy Search）** 作为采集函数：选最大化"对最优解位置后验分布的信息增益"的解。
- **代理模型**：每子问题 2 个局部 Kriging（共 $2N$ 个），训练数据为最近邻 80/20 解。
- **填充准则**：熵搜索：
$$
\alpha_{ES}(\mathbf{x}) = H[p(\mathbf{x}^*|D)] - \mathbb{E}_{y}[H[p(\mathbf{x}^*|D\cup\{(\mathbf{x},y)\})]]
$$
- **关键创新**：
  - **局部模型规避 $O(N^3)$**：用最近邻 80 个点训练，复杂度降为 $O(80^3)$ 常数
  - **熵搜索代替 EI**：信息论度量在多模态问题上更优
  - **协同进化框架**：MOEA/D 邻域选择 (`delta=0.9`, `nr=2`) 配合多个局部模型
  - **每代评估 $K_e=5$ 解**
- **PlatEMO 实现**：`ESBCEO/ESBCEO.m`，参数 `Ke=5, delta=0.9, nr=2, L1=80, L2=20`。

---

### 3.6 流派 F：标量化/子空间代理类（5 个）

本流派的核心创新点不在代理模型本身，而在**代理建模目标的重塑**：①不近似目标函数 $\mathbf{F}: \mathbb{R}^D\to\mathbb{R}^M$，转而近似低维标量（如 PBI、ASF）；②不在全维 $\mathbb{R}^D$ 上建模，转而在子空间 / 分组变量上建模。这显著降低了拟合难度。

#### F.1 SMOA（2022, CEC）⭐ 离线监督学习多目标

- **基本信息**：T. Takagi, K. Takadama, H. Sato, "Supervised multi-objective optimization algorithm using estimation", CEC 2022. **Conference**。
- **算法动机**：传统 SAEA 在线训练代理需占用部分 FE 预算；能否完全**离线**训练，把进化过程变成纯查表？
- **核心思想**：①离线收集大量训练样本（如 `DTLZ2_M3_D12.mat/.dat`）；②学习一个映射 $\hat{f}: \mathbb{R}^M \to \mathbb{R}^D$（从目标值估计决策变量）；③在线阶段不调用真实函数也不进化，直接用 $\hat{f}$ 在均匀目标方向 $\mathbf{F}$ 上估计对应解。
- **代理模型**：监督学习模型（具体形式由参数 `H=2.6e4` 个 L1 单位向量集决定）。
- **关键创新**：
  - **完全离线**：不调用真实函数（适合有训练数据的场景）
  - **不用进化算法**：纯前向估计
  - **目标→决策方向**：与传统决策→目标方向相反
- **适用场景**：仅作为"如果有大量历史数据"的极端基线；实际工程罕用。
- **PlatEMO 实现**：`SMOA/SMOA.m`，参数 `H=2.6e4`；需提供 `<problem>_M<m>_D<d>.mat/.dat` 训练数据。

---

#### F.2 MO-L2SMEA（2023, IEEE TEVC）⭐⭐ 一维线性子空间代理

- **基本信息**：L. Si, X. Zhang, Y. Tian, S. Yang, L. Zhang, Y. Jin, "Linear subspace surrogate modeling for large-scale expensive single/multi-objective optimization", IEEE TEVC, 2023. **Tier-1**。
- **标签**：`<multi> <real> <expensive> <large/none>`，支持大规模决策变量。
- **算法动机**：大规模 ($D\ge 100$) 昂贵 MOO 是 SAEA 最大瓶颈：Kriging 不可扩展，NN 易过拟合。能否将高维问题降维处理？
- **核心思想**：①把高维决策空间分解为多个一维线性子空间（每个子空间是 $\mathbb{R}^D$ 中的一条直线）；②每个子空间训练一个一维 RBF 代理（输入 1 维标量参数 $t$，输出 $M$ 维）；③多子空间集体表征 Pareto 前沿；④全局优化由 NSGA-II 协同。
- **代理模型**：`NLinear=8` 个一维 RBF。
- **填充准则**：每个一维子空间内独立优化，再汇总。
- **关键创新**：
  - **降维拟合**：每子代理仅 1 维输入 → 训练复杂度 $O(N)$
  - **线性子空间 = 简单方向**：通过 LHS 在高维空间生成 8 个起点 + 方向向量
  - **NT=2D** 训练点，参数极少
  - **可扩展到 $D\ge 1000$**
- **PlatEMO 实现**：`MO-L2SMEA/MOL2SMEA.m`，参数 `NLinear=8`。
- **关联工作**：单目标版 L2SMEA 同期发表，本工作是其多目标扩展。

---

#### F.3 AVG-SAEA（2024, IEEE TEVC）⭐ 自适应变量分组

- **基本信息**：Y. Li, X. Feng, H. Yu, "Solving high-dimensional expensive multiobjective optimization problems by adaptive decision variable grouping", IEEE TEVC, 2024. **Tier-1**。
- **标签**：`<multi> <real/integer> <expensive> <large>`。
- **算法动机**：MO-L2SMEA 的子空间是固定线性方向；能否根据问题结构**自适应分组**决策变量？
- **核心思想**：①把 $D$ 个决策变量分为 `NumEsp=2` 组（默认）；②每组单独训练一个代理，分组方式根据变量交互性自适应；③子种群 `subDec{i}` 在各组上独立进化，跨组协同更新。
- **代理模型**：`NumEsp` 个子代理（默认 2 个，可调），每个用 `Numtrain=300` 个样本训练。
- **填充准则**：每子代理独立筛选候选，每代汇总 `mu=5` 个真实评估。
- **关键创新**：
  - **自适应分组数**：通过变量交互性分析动态调整
  - **子种群协同**：每组独立但跨组更新
  - **wmax=20** 代代理评估周期
- **PlatEMO 实现**：`AVG-SAEA/AVGSAEA.m`，参数 `Numtrain=300, wmax=20, NumEsp=2, mu=5`。

---

#### F.4 LDS-AF（2024, Evolutionary Computation）⭐ 低维标量化代理

- **基本信息**：H. Gu, H. Wang, C. He, B. Yuan, Y. Jin, "Large-scale multiobjective evolutionary algorithm guided by low-dimensional surrogates of scalarization functions", Evolutionary Computation, 2024. **Tier-2**。
- **标签**：`<multi> <real/integer> <large/none> <expensive>`。
- **算法动机**：传统代理建模 $M$ 维输出（每个目标一个代理）；标量化函数（如 PBI、Tchebycheff）把 $M$ 维聚合为 1 维标量——为何不直接对这 1 维标量建代理？
- **核心思想**：①不近似目标函数 $\mathbf{F}: \mathbb{R}^D\to\mathbb{R}^M$；②近似标量化函数 $g(\mathbf{F}(\mathbf{x})|\boldsymbol\lambda): \mathbb{R}^D\to\mathbb{R}$（输出 1 维）；③对每个权重方向训练一个一维输出 RBF；④用 MOEA/D 框架协调。
- **代理模型**：每个权重方向一个 RBF（输出 1 维）。
- **填充准则**：内部 GA 在每个权重方向上最优化代理，选 `N_s=20` 个候选送真实评估。
- **关键创新**：
  - **输出降维**：从 $M$ 维输出降到 1 维标量
  - **拟合更易**：1 维标量比 $M$ 维向量拟合精度高
  - **大规模友好**：与 MO-L2SMEA、AVG-SAEA 同属"大规模 SAEA"流派
- **PlatEMO 实现**：`LDS-AF/LDSAF.m`，参数 `delta=0.9, N_s=20`。

---

#### F.5 SFA-DE（2024, SWEVO）⭐ 标量化函数近似 + DE

- **基本信息**：Y. Horaguchi, K. Nishihara, M. Nakata, "Evolutionary multiobjective optimization assisted by scalarization function approximation for high-dimensional expensive problems", Swarm and Evolutionary Computation, vol. 86, 101516, 2024. **Tier-1**（中科院一区 Top）。
- **算法动机**：与 LDS-AF 同源——直接近似标量化函数；但用 DE 替代 GA 作为内部搜索器，更适合高维。
- **核心思想**：①每个权重方向训练一个一维输出 RBF（近似 Tchebycheff 标量化值）；②内部 DE（参数 $F=0.5, CR=0.9$）跑 $\omega=20$ 代搜索每个方向的最优；③MOEA/D 邻域更新。
- **代理模型**：每权重方向一个 RBF。
- **填充准则**：内部 DE 最优化标量化代理，选最佳真实评估。
- **关键创新**：
  - **DE 内部搜索**：$F=0.5, CR=0.9$ 默认 DE 参数，对高维更稳健
  - **标量化代理**：与 LDS-AF 思路一致，证明该路线在 $D\ge 50$ 时优于直接代理
  - **omega=20** 代搜索周期
- **PlatEMO 实现**：`SFA-DE/SFADE.m`，参数 `F=0.5, CR=0.9, omega=20`。

---

## 4. 期刊等级分布与发展趋势

### 4.1 年份 × 期刊等级矩阵

| 年份 | T1（一区） | T2（二区） | T3（三区） | Conf（会议） |
|------|-----------|-----------|-----------|--------------|
| 2006 | ParEGO | | | |
| 2008 | | | | SMS-EGO |
| 2010 | MOEA/D-EGO | | | |
| 2015 | | | | CPS-MOEA |
| 2016 | | | | MultiObjectiveEGO |
| 2017 | EIM-EGO | | | |
| 2018 | K-RVEA | | | |
| 2019 | CSEA、HeE-MOEA | | | |
| 2020 | AB-SAEA | | | |
| 2021 | KTA2 | | | |
| 2022 | EDN-ARMOEA、MCEA/D、REMO | ADSAPSO | PB-NSGA-III、PB-RVEA | SMOA |
| 2023 | EMMOEA、ESBCEO、MO-L2SMEA、NSGAIII-EHVI、PC-SAEA | | | |
| 2024 | AVG-SAEA、DirHV-EI、DISK、PIEA、PIMD、SFA-DE、SSDE、TEA | LDS-AF | | |

### 4.2 时间发展阶段

#### 阶段 1：奠基期（2006-2010）
- **关键工作**：ParEGO（2006）→ SMS-EGO（2008）→ MOEA/D-EGO（2010）
- **共同特征**：单一 Kriging 模型 + 经典 EI/HV 采集函数 + 顺序填充
- **奠定的概念**：标量化方向（ParEGO）、HV 驱动（SMS-EGO）、分解+批量（MOEA/D-EGO）

#### 阶段 2：框架成型期（2015-2019）
- **关键工作**：CPS-MOEA（2015）→ EIM-EGO（2017）→ K-RVEA（2018）→ CSEA / HeE-MOEA（2019）
- **共同特征**：与具体 EA 框架（NSGA-II/RVEA/Two_Arch2）深度耦合；提出统一的 EI 矩阵理论；分类代理首次进入主流
- **里程碑**：①K-RVEA 把代理引入超多目标；②CSEA 用神经网络做超多目标分类；③HeE-MOEA 异构集成思想

#### 阶段 3：深度学习入侵期（2020-2022）
- **关键工作**：AB-SAEA（2020）→ KTA2（2021）→ EDN-ARMOEA / ADSAPSO / MCEA/D / REMO（2022）
- **共同特征**：①Kriging 走向自适应贝叶斯；②深度学习正式入场（Dropout NN、FNN）；③从"回归"转向"分类/关系"
- **里程碑**：①EDN-ARMOEA 让 NN 代理在超多目标顶刊立足；②REMO 开启关系学习路线；③MCEA/D 把分类与分解结合

#### 阶段 4：多样化创新期（2023-2024）
- **关键工作**：13 个算法集中爆发，覆盖 4 个流派
- **共同特征**：①填充准则极度多样化（PB、PI、EHVI 重要性采样、DirHV-EI 方向化、PIMD、ES 熵搜索）；②大规模/高维问题成为新热点（MO-L2SMEA、AVG-SAEA、LDS-AF、SFA-DE）；③PC-SAEA 沿袭 REMO 关系学习路线；④TEA 探索两阶段切换
- **里程碑**：①DirHV-EI 解析化批量 EHVI；②DISK 把分布信息进入排序；③MO-L2SMEA 一维子空间打开大规模 SAEA 路径

### 4.3 发展趋势观察

1. **TEVC 主导地位明显**：32 个算法中 14 个发表于 IEEE TEVC（44%），其次 SWEVO（3 个）、Information Sciences（2 个）、TSMCS（2 个）。投稿 SAEA 优先选 TEVC。**注：SWEVO、Information Sciences、KBS、EAAI 均为中科院一区期刊。**

2. **代理模型从回归走向分类/关系**：
   - 2010 年前清一色 Kriging 回归
   - 2015 起分类代理（CPS-MOEA→CSEA→MCEA/D）成为顶刊主线
   - 2022 起关系学习（REMO→PC-SAEA）开辟新路径
   - 趋势：**从绝对值预测到相对优劣判断**

3. **填充准则多样化趋势**：
   - 经典 EI（ParEGO、MOEA/D-EGO）→ HV-EI（SMS-EGO）→ 矩阵化 EIM（EIM-EGO）
   - APD（K-RVEA）→ 双指标 PB（PB-NSGA-III/RVEA）→ 性能指标 EPII（EMMOEA）
   - 概率拥挤（PIMD）→ 熵搜索（ESBCEO）→ 方向 EHVI（DirHV-EI）
   - 趋势：**从单一标量到多准则融合，从启发式到信息论**

4. **决策维度越来越大**：
   - 早期 SAEA 仅适配 $D\le 30$
   - 2022 起 ADSAPSO 处理 $D=50$；2023-2024 大规模 SAEA（MO-L2SMEA、AVG-SAEA、LDS-AF、SFA-DE）目标 $D\ge 100$
   - 关键技术：变量分组、子空间分解、Dropout NN

5. **超多目标 ($M\ge 4$) 成为标配**：
   - 2010 年前算法多仅支持 $M\le 3$
   - K-RVEA（2018）后超多目标支持成为顶刊基本要求
   - 2024 年的算法几乎全部 `<multi/many>` 双标签

6. **代码可读性与可复用性**：
   - PlatEMO 平台标准化了所有 SAEA 的接口（`Algorithm.NotTerminated`、`Problem.Evaluation`、`UniformPoint`），后人对比基线极便利
   - 所有 32 个算法都可一行命令调用：`platemo('algorithm', @<ALGO>, 'problem', @DTLZ2, 'M', 3, 'D', 10, 'maxFE', 300)`

---

## 5. 算法对比汇总表

下表为 32 个算法的扁平化对照表（按年份升序）。

| # | 算法 | 年份 | 期刊 | Tier | M 范围 | D 范围 | 代理模型 | 填充准则 | 关键创新 | 默认参数 | 子文件夹 |
|---|------|------|------|------|--------|--------|----------|----------|---------|---------|---------|
| 1 | ParEGO | 2006 | TEVC | T1 | 2-3 | ≤30 | Kriging | EI on Tchebycheff | EGO+随机权重标量化 | IFEs=10000 | ParEGO/ |
| 2 | SMS-EGO | 2008 | PPSN | C | 2-3 | ≤30 | Kriging | LCB+ΔHV | HV 直接采集 | wmax=10000 | SMS-EGO/ |
| 3 | MOEA/D-EGO | 2010 | TEVC | T1 | 2-7 | ≤30 | Kriging | 子问题 EI | 分解+批量 | batch=5 | MOEA-D-EGO/ |
| 4 | CPS-MOEA | 2015 | CEC | C | 2-3 | ≤30 | k-NN 分类 | 概率筛选 | 首个分类 SAEA | M=3 | CPS-MOEA/ |
| 5 | MultiObjectiveEGO | 2016 | GECCO | C | 2-3 | ≤30 | Kriging | 方向 EI | AASF 方向均匀 | α=0.7,k=5,H=21 | MultiObjectiveEGO/ |
| 6 | EIM-EGO | 2017 | TEVC | T1 | 2-3 | ≤30 | Kriging | EIM 矩阵 | 解析批量 EI | idx=1 | EIM-EGO/ |
| 7 | K-RVEA | 2018 | TEVC | T1 | 2-10 | ≤30 | Kriging | APD+不确定度 | 代理+RVEA | α=2,wmax=20,μ=5 | K-RVEA/ |
| 8 | CSEA | 2019 | TEVC | T1 | 2-10 | ≤30 | FNN 分类 | 参考解优劣 | NN 处理超多目标 | k=6,gmax=3000 | CSEA/ |
| 9 | HeE-MOEA | 2019 | TCYB | T1 | 2-3 | ≤30 | 异构集成 | 集成均值+分歧 | CART+KNN+RBF+GP | Ke=5 | HeE-MOEA/ |
| 10 | AB-SAEA | 2020 | Inf. Sci. | T1 | 2-10 | ≤30 | Kriging | 自适应贝叶斯 | 熵权重 explore/exploit | α=2,wmax=20,μ=5 | AB-SAEA/ |
| 11 | KTA2 | 2021 | TEVC | T1 | 2-10 | ≤30 | Kriging | 双档案+signrank | CA/DA 解耦 | τ=0.75,φ=0.1 | KTA2/ |
| 12 | ADSAPSO | 2022 | CIS | T2 | 2-10 | ≤50 | Dropout NN | LCB+PSO | 自适应 dropout | k=5,β=0.5 | ADSAPSO/ |
| 13 | EDN-ARMOEA | 2022 | TSMCS | T1 | 2-10 | ≤50 | Dropout NN | LCB+多样性 | NN+AR-MOEA | δ=0.05,wmax=20 | EDN-ARMOEA/ |
| 14 | MCEA/D | 2022 | TEVC | T1 | 2-10 | ≤30 | 多 SVM | SVM 概率 | 子问题分类器 | δ=0.9,nr=2,Rmax=10 | MCEA-D/ |
| 15 | PB-NSGA-III | 2022 | MC | T3 | 3-10 | ≤30 | Kriging | Pareto 双指标 | 双指标非支配 | wmax=15 | PB-NSGA-III/ |
| 16 | PB-RVEA | 2022 | MC | T3 | 3-10 | ≤30 | Kriging | Pareto 双指标 | PB+RVEA | α=2,wmax=15 | PB-RVEA/ |
| 17 | REMO | 2022 | TEVC | T1 | 2-10 | ≤30 | 关系 FNN | 关系预测 | 成对支配学习 | k=6,gmax=3000 | REMO/ |
| 18 | SMOA | 2022 | CEC | C | 2-10 | 离线 | 监督学习 | 直接估计 | 无进化、查表 | H=2.6e4 | SMOA/ |
| 19 | EMMOEA | 2023 | TEVC | T1 | 2-10 | ≤30 | Kriging | EPII 性能指标 | IGD+ 期望改进 | gmax=10 | EMMOEA/ |
| 20 | ESBCEO | 2023 | KBS | T1 | 2-10 | ≤50 | 局部 Kriging | 熵搜索 | 协同+局部模型 | Ke=5,L1=80,L2=20 | ESBCEO/ |
| 21 | MO-L2SMEA | 2023 | TEVC | T1 | 2-3 | ≥100 | 一维 RBF | 一维子空间 | 大规模降维 | NLinear=8 | MO-L2SMEA/ |
| 22 | NSGAIII-EHVI | 2023 | TEVC | T1 | 3-10 | ≤30 | Kriging | EHVI 重要性采样 | 高效 EHVI | wmax=15,nSample=10000 | NSGAIII-EHVI/ |
| 23 | PC-SAEA | 2023 | SWEVO | T1 | 2-10 | ≤30 | RBFN-PC | 成对+可靠性 | 双错误率切换 | δ=0.8,gmax=3000 | PC-SAEA/ |
| 24 | AVG-SAEA | 2024 | TEVC | T1 | 2-3 | ≥50 | RBF | 分组评估 | 自适应变量分组 | Numtrain=300,NumEsp=2 | AVG-SAEA/ |
| 25 | DirHV-EI | 2024 | TEVC | T1 | 2-10 | ≤30 | Kriging | 方向 HV-EI | 解析批量 EHVI | batch=5 | DirHV-EI/ |
| 26 | DISK | 2024 | TEVC | T1 | 2-10 | ≤30 | Kriging | NDSort_DIPD | 分布信息排序 | wmax=60,α=5 | DISK/ |
| 27 | LDS-AF | 2024 | EC | T2 | 2-3 | ≥50 | RBF（标量输出） | 标量化 RBF | 1 维输出代理 | δ=0.9,N_s=20 | LDS-AF/ |
| 28 | PIEA | 2024 | Inf. Sci. | T1 | 2-10 | ≤30 | Kriging | 历史改进窗口 | 自适应历史窗口 | η=5,R_max=20,τ=20 | PIEA/ |
| 29 | PIMD | 2024 | EAAI | T1 | 3-10 | ≤30 | Kriging | PoI×MCD | 映射拥挤距离 | wmax=15,η=5 | PIMD/ |
| 30 | SFA-DE | 2024 | SWEVO | T1 | 2-10 | ≥50 | RBF（标量输出） | DE+标量化 RBF | DE 内部搜索 | F=0.5,CR=0.9,ω=20 | SFA-DE/ |
| 31 | SSDE | 2024 | SWEVO | T1 | 2-10 | ≤30 | SOM | DE+SOM 邻居 | 拓扑保持代理 | η0=0.2 | SSDE/ |
| 32 | TEA | 2024 | TSMCS | T1 | 2-10 | ≤30 | Kriging | 两阶段切换 | 理想点变化率切换 | wmax=20,μ=5 | TEA/ |

> **运行示例**：`platemo('algorithm', @REMO, 'problem', @DTLZ2, 'M', 3, 'D', 10, 'maxFE', 300)`

---

## 6. BibTeX 引用规范

以下为 32 个算法对应论文的 BibTeX 条目（按算法名字母排序），可直接复制到 LaTeX 文档使用。

```bibtex
@article{ABSAEA2020,
  author  = {Wang, Xilu and Jin, Yaochu and Schmitt, Sebastian and Olhofer, Markus},
  title   = {An adaptive {B}ayesian approach to surrogate-assisted evolutionary multi-objective optimization},
  journal = {Information Sciences},
  volume  = {519},
  pages   = {317--331},
  year    = {2020}
}

@article{ADSAPSO2022,
  author  = {Lin, Jianqing and He, Cheng and Cheng, Ran},
  title   = {Adaptive dropout for high-dimensional expensive multiobjective optimization},
  journal = {Complex \& Intelligent Systems},
  volume  = {8},
  number  = {1},
  pages   = {271--285},
  year    = {2022}
}

@article{AVGSAEA2024,
  author  = {Li, Yingwei and Feng, Xiang and Yu, Huiqun},
  title   = {Solving high-dimensional expensive multiobjective optimization problems by adaptive decision variable grouping},
  journal = {IEEE Transactions on Evolutionary Computation},
  year    = {2024}
}

@inproceedings{CPSMOEA2015,
  author    = {Zhang, Jinyuan and Zhou, Aimin and Zhang, Guixu},
  title     = {A classification and {P}areto domination based multiobjective evolutionary algorithm},
  booktitle = {Proceedings of the IEEE Congress on Evolutionary Computation},
  pages     = {2883--2890},
  year      = {2015}
}

@article{CSEA2019,
  author  = {Pan, Linqiang and He, Cheng and Tian, Ye and Wang, Handing and Zhang, Xingyi and Jin, Yaochu},
  title   = {A classification based surrogate-assisted evolutionary algorithm for expensive many-objective optimization},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {23},
  number  = {1},
  pages   = {74--88},
  year    = {2019}
}

@article{DirHVEI2024,
  author  = {Zhao, Liang and Zhang, Qingfu},
  title   = {Hypervolume-guided decomposition for parallel expensive multiobjective optimization},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {28},
  number  = {2},
  pages   = {432--444},
  year    = {2024}
}

@article{DISK2024,
  author  = {Zhang, Zhiyao and Wang, Yong and Sun, Guangyong and Pang, Tao},
  title   = {A distribution information based {K}riging-assisted evolutionary algorithm for expensive many-objective optimization problems},
  journal = {IEEE Transactions on Evolutionary Computation},
  year    = {2024}
}

@article{EDNARMOEA2022,
  author  = {Guo, Dan and Wang, Xilu and Gao, Kaifeng and Jin, Yaochu and Ding, Jinliang and Chai, Tianyou},
  title   = {Evolutionary optimization of high-dimensional multiobjective and many-objective expensive problems assisted by a dropout neural network},
  journal = {IEEE Transactions on Systems, Man, and Cybernetics: Systems},
  volume  = {52},
  number  = {4},
  pages   = {2084--2097},
  year    = {2022}
}

@article{EIMEGO2017,
  author  = {Zhan, Dawei and Cheng, Yuansheng and Liu, Jun},
  title   = {Expected improvement matrix-based infill criteria for expensive multiobjective optimization},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {21},
  number  = {6},
  pages   = {956--975},
  year    = {2017}
}

@article{EMMOEA2023,
  author  = {Qin, Shufen and Sun, Chaoli and Liu, Qiqi and Jin, Yaochu},
  title   = {A performance indicator-based infill criterion for expensive multi-/many-objective optimization},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {27},
  number  = {4},
  pages   = {1085--1099},
  year    = {2023}
}

@article{ESBCEO2023,
  author  = {Bian, Hao and Tian, Jie and Yu, Jiaqi and Yu, Hui},
  title   = {{B}ayesian co-evolutionary optimization based entropy search for high-dimensional many-objective optimization},
  journal = {Knowledge-Based Systems},
  volume  = {274},
  pages   = {110630},
  year    = {2023}
}

@article{HeEMOEA2019,
  author  = {Guo, Dan and Jin, Yaochu and Ding, Jinliang and Chai, Tianyou},
  title   = {Heterogeneous ensemble-based infill criterion for evolutionary multiobjective optimization of expensive problems},
  journal = {IEEE Transactions on Cybernetics},
  volume  = {49},
  number  = {3},
  pages   = {1012--1025},
  year    = {2019}
}

@article{KRVEA2018,
  author  = {Chugh, Tinkle and Jin, Yaochu and Miettinen, Kaisa and Hakanen, Jussi and Sindhya, Karthik},
  title   = {A surrogate-assisted reference vector guided evolutionary algorithm for computationally expensive many-objective optimization},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {22},
  number  = {1},
  pages   = {129--142},
  year    = {2018}
}

@article{KTA22021,
  author  = {Song, Zhenshou and Wang, Handing and He, Cheng and Jin, Yaochu},
  title   = {A {K}riging-assisted two-archive evolutionary algorithm for expensive many-objective optimization},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {25},
  number  = {6},
  pages   = {1013--1027},
  year    = {2021}
}

@article{LDSAF2024,
  author  = {Gu, Haoran and Wang, Handing and He, Cheng and Yuan, Bo and Jin, Yaochu},
  title   = {Large-scale multiobjective evolutionary algorithm guided by low-dimensional surrogates of scalarization functions},
  journal = {Evolutionary Computation},
  year    = {2024}
}

@article{MCEAD2022,
  author  = {Sonoda, Takumi and Nakata, Masaya},
  title   = {Multiple classifiers-assisted evolutionary algorithm based on decomposition for high-dimensional multi-objective problems},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {26},
  number  = {6},
  pages   = {1581--1595},
  year    = {2022}
}

@article{MOEADEGO2010,
  author  = {Zhang, Qingfu and Liu, Wudong and Tsang, Edward and Virginas, Botond},
  title   = {Expensive multiobjective optimization by {MOEA/D} with {G}aussian process model},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {14},
  number  = {3},
  pages   = {456--474},
  year    = {2010}
}

@article{MOL2SMEA2023,
  author  = {Si, Liming and Zhang, Xingyi and Tian, Ye and Yang, Shengxiang and Zhang, Lei and Jin, Yaochu},
  title   = {Linear subspace surrogate modeling for large-scale expensive single/multi-objective optimization},
  journal = {IEEE Transactions on Evolutionary Computation},
  year    = {2023}
}

@inproceedings{MultiObjectiveEGO2016,
  author    = {Hussein, Rayan and Deb, Kalyanmoy},
  title     = {A generative {K}riging surrogate model for constrained and unconstrained multi-objective optimization},
  booktitle = {Proceedings of the Genetic and Evolutionary Computation Conference},
  pages     = {573--580},
  year      = {2016}
}

@article{NSGAIIIEHVI2023,
  author  = {Pang, Yong and Wang, Yitang and Zhang, Shuai and Lai, Xiaonan and Sun, Wei and Song, Xueguan},
  title   = {An expensive many-objective optimization algorithm based on efficient expected hypervolume improvement},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {27},
  number  = {6},
  pages   = {1822--1836},
  year    = {2023}
}

@article{ParEGO2006,
  author  = {Knowles, Joshua},
  title   = {{ParEGO}: A hybrid algorithm with on-line landscape approximation for expensive multiobjective optimization problems},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {10},
  number  = {1},
  pages   = {50--66},
  year    = {2006}
}

@article{PBNSGAIII2022,
  author  = {Song, Zhenshou and Wang, Handing and Xu, Hao},
  title   = {A framework for expensive many-objective optimization with {P}areto-based bi-indicator infill sampling criterion},
  journal = {Memetic Computing},
  volume  = {14},
  pages   = {179--191},
  year    = {2022}
}

@article{PBRVEA2022,
  author  = {Song, Zhenshou and Wang, Handing and Xu, Hao},
  title   = {A framework for expensive many-objective optimization with {P}areto-based bi-indicator infill sampling criterion},
  journal = {Memetic Computing},
  volume  = {14},
  pages   = {179--191},
  year    = {2022}
}

@article{PCSAEA2023,
  author  = {Tian, Ye and Hu, Jiacheng and He, Cheng and Ma, Hongyu and Zhang, Lianghao and Zhang, Xingyi},
  title   = {A pairwise comparison based surrogate-assisted evolutionary algorithm for expensive multi-objective optimization},
  journal = {Swarm and Evolutionary Computation},
  volume  = {80},
  pages   = {101323},
  year    = {2023}
}

@article{PIEA2024,
  author  = {Li, Yang and Li, Wei and Li, Shuai and Zhao, Yu},
  title   = {A performance indicator-based evolutionary algorithm for expensive high-dimensional multi-/many-objective optimization},
  journal = {Information Sciences},
  pages   = {121045},
  year    = {2024}
}

@article{PIMD2024,
  author  = {Li, Yang and Li, Wei and Zhao, Yu and Li, Shuai},
  title   = {An infill sampling criterion based on improvement of probability and mapping crowding distance for expensive multi/many-objective optimization},
  journal = {Engineering Applications of Artificial Intelligence},
  volume  = {133},
  pages   = {108616},
  year    = {2024}
}

@article{REMO2022,
  author  = {Hao, Hao and Zhou, Aimin and Qian, Hong and Zhang, Hu},
  title   = {Expensive multiobjective optimization by relation learning and prediction},
  journal = {IEEE Transactions on Evolutionary Computation},
  volume  = {26},
  number  = {5},
  pages   = {1157--1170},
  year    = {2022}
}

@article{SFADE2024,
  author  = {Horaguchi, Yuma and Nishihara, Kei and Nakata, Masaya},
  title   = {Evolutionary multiobjective optimization assisted by scalarization function approximation for high-dimensional expensive problems},
  journal = {Swarm and Evolutionary Computation},
  volume  = {86},
  pages   = {101516},
  year    = {2024}
}

@inproceedings{SMOA2022,
  author    = {Takagi, Tomoaki and Takadama, Keiki and Sato, Hiroyuki},
  title     = {Supervised multi-objective optimization algorithm using estimation},
  booktitle = {Proceedings of the IEEE Congress on Evolutionary Computation},
  year      = {2022}
}

@inproceedings{SMSEGO2008,
  author    = {Ponweiser, Wolfgang and Wagner, Tobias and Biermann, Dirk and Vincze, Markus},
  title     = {Multiobjective optimization on a limited budget of evaluations using model-assisted {S}-metric selection},
  booktitle = {Proceedings of the International Conference on Parallel Problem Solving from Nature},
  pages     = {784--794},
  year      = {2008}
}

@article{SSDE2024,
  author  = {Ara{\'u}jo, Aluizio F. R. and Farias, Lucas R. C. and Gon{\c c}alves, Antonio R. C.},
  title   = {Self-organizing surrogate-assisted non-dominated sorting differential evolution},
  journal = {Swarm and Evolutionary Computation},
  volume  = {91},
  pages   = {101703},
  year    = {2024}
}

@article{TEA2024,
  author  = {Zhang, Zhiyao and Wang, Yong and Liu, Jian and Sun, Guangyong and Tang, Ke},
  title   = {A two-phase {K}riging-assisted evolutionary algorithm for expensive constrained multiobjective optimization problems},
  journal = {IEEE Transactions on Systems, Man, and Cybernetics: Systems},
  volume  = {54},
  number  = {8},
  pages   = {4579--4591},
  year    = {2024}
}
```

---

## 附录 A：流派分布饼图（文字描述）

```
代理模型流派占比（共 32 算法）：
┌─────────────────────────────────────────────────────────────┐
│ Kriging/GP         ████████████████████████████  17 (53.1%)  │
│ 标量化/子空间      █████████                      5 (15.6%)  │
│ 神经网络           ██████                         3 ( 9.4%)  │
│ 分类器             ██████                         3 ( 9.4%)  │
│ 关系学习/成对比较  ████                           2 ( 6.3%)  │
│ 异构集成           ████                           2 ( 6.3%)  │
└─────────────────────────────────────────────────────────────┘

期刊等级占比（共 32 算法，基于中科院 2024 分区）：
┌─────────────────────────────────────────────────────────────┐
│ Tier-1（一区）     ████████████████████████████████████ 24 (75.0%) │
│ Tier-2（二区）     ████                           2 ( 6.2%) │
│ Conference         █████                          4 (12.5%) │
│ Tier-3（三区）     ████                           2 ( 6.2%) │
└─────────────────────────────────────────────────────────────┘
```

---

## 附录 B：常用 PlatEMO 调用模板

```matlab
% 示例 1：在 ZDT2 (M=2, D=10) 上跑 ParEGO，预算 200 FE
platemo('algorithm', @ParEGO, 'problem', @ZDT2, 'M', 2, 'D', 10, 'maxFE', 200);

% 示例 2：在 DTLZ2 (M=5, D=10) 上跑 K-RVEA
platemo('algorithm', @KRVEA, 'problem', @DTLZ2, 'M', 5, 'D', 10, 'maxFE', 300);

% 示例 3：在 WFG3 (M=3, D=12) 上跑 REMO
platemo('algorithm', @REMO, 'problem', @WFG3, 'M', 3, 'D', 12, 'maxFE', 300);

% 示例 4：在 DTLZ2 (M=8, D=10) 上跑 DirHV-EI（超多目标）
platemo('algorithm', @DirHVEI, 'problem', @DTLZ2, 'M', 8, 'D', 10, 'maxFE', 300, 'batch_size', 5);

% 示例 5：批量对比 4 个算法（用 PlatEMO GUI 更方便）
algorithms = {@ParEGO, @KRVEA, @REMO, @DirHVEI};
for i = 1:length(algorithms)
    platemo('algorithm', algorithms{i}, 'problem', @DTLZ2, 'M', 3, 'D', 10, 'maxFE', 300);
end
```

---

## 编写说明

- 本综述基于 PlatEMO v4.x 源代码与每个算法 .m 文件顶部的论文引用元数据自动整理。
- 期刊等级分类基于 CCF 推荐目录与中科院 SCI 期刊分区表（**2024 版**）。
  - **重要修正**：SWEVO、Information Sciences、KBS、EAAI 均为中科院一区期刊（非二区），Complex & Intelligent Systems 为二区期刊（非三区）。
- 部分算法的页码、卷号若 PlatEMO 注释未给出（如 2024 年新作），以"year"占位，使用前请到原期刊网站补全。
- 用户的 REMO 衍生算法（D-REMO、R2-REMO、DSR-REMO 等）不在本综述范围；用户可基于本表的"流派 C 关系学习"位置定位自身工作的技术谱系。

---

---

---

---

---

