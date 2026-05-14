# REMO 方向必学算法清单 —— 从 PlatEMO 300+ 算法中筛出来

> **作者**：李盛薪
> **生成日期**：2026/05/13
> **配套文档**：
> - [REMO_一区论文三月攻坚计划.md](./REMO_一区论文三月攻坚计划.md)
> - [REMO_一区文章必备知识地图.md](./REMO_一区文章必备知识地图.md)
> **本文目的**：当前 PlatEMO 目录下有 **300+ 个算法**。本文按你的方向（关系学习 × 昂贵超多目标）精准筛选，明确告诉你哪些必学、哪些只看主流程、哪些跳过。

---

## 目录

- [零、先回答你的核心问题：必须掌握 = 源码吃透吗？](#零先回答你的核心问题必须掌握--源码吃透吗)
- [一、四级掌握标准（先看这个才能用下面的清单）](#一四级掌握标准先看这个才能用下面的清单)
- [二、L0 必学（源码逐行吃透，5 个）](#二l0-必学源码逐行吃透5-个)
- [三、L1 必懂（主流程 + 关键模块源码，约 12 个）](#三l1-必懂主流程--关键模块源码约-12-个)
- [四、L2 推荐了解（知道思想，约 15 个）](#四l2-推荐了解知道思想约-15-个)
- [五、L3 可跳过（与你方向无关，约 250 个）](#五l3-可跳过与你方向无关约-250-个)
- [六、你自己的 REMO 家族（特殊清单）](#六你自己的-remo-家族特殊清单)
- [七、学习顺序与时间投入](#七学习顺序与时间投入)
- [八、附录：如何"吃透"一个算法的源码](#八附录如何吃透一个算法的源码)

---

## 零、先回答你的核心问题：必须掌握 = 源码吃透吗？

**答案：不是。**

"掌握"分四个层次，**不同算法对应不同层次**。如果对所有"必须掌握"的算法都要求逐行吃透源码，**你 3 个月做不完，而且收益递减**。

正确的做法：

| 层次 | 含义 | 适用于 |
|---|---|---|
| **L0 钢印级** | 逐行源码、能脱稿讲、能自己重写 | **只有 REMO 本身**（你的 baseline） |
| **L1 模块级** | 读懂主流程图，**关键创新模块**的源码精读 | 5-10 个核心相关算法 |
| **L2 思想级** | 能口述算法核心思想、知道何时使用，**不读源码** | 15-30 个外围相关算法 |
| **L3 名字级** | 知道算法名字和大类即可 | 其他全部 |

**判断标准**（这才是关键）：

> **问自己：这个算法在我论文 Related Work 章节里要被引用 / 比较吗？**
>
> - 是 → **至少 L1**（你必须知道它的本质，否则审稿人会问倒你）
> - 否 → **L2 或 L3** 就够了

**特别强调**：

> 老师可能会让你"读 XX 算法"，**别傻傻地全部逐行读**。读之前先想清楚：这个算法的什么部分对我有用？没用的部分跳过。

**这一节就是为了让你不要陷入"我得吃透每一个算法源码"的焦虑。** 实际上，一区论文不要求你懂全部 300 个算法，只要求你把**关键 10-15 个**吃透到能讨论的程度。

---

## 一、四级掌握标准（先看这个才能用下面的清单）

在看下面的清单前，先理解每一级的**具体动作**：

### L0：钢印级（用于 REMO 本身）

- [ ] 能在不看代码的情况下，30 分钟讲清楚整个算法流程
- [ ] 能解释每个函数的输入输出
- [ ] **能解释每个超参数为什么选这个值**
- [ ] 能在白板上推导关键公式
- [ ] 能指出算法的失败模式（在什么场景下会崩）
- [ ] 能自己用 Python 或 MATLAB **从零重新实现一遍**

**投入时间**：5-7 天集中攻坚。

### L1：模块级（用于核心相关算法）

- [ ] 能 5 分钟讲清楚算法思想 + 关键创新（一两句话）
- [ ] 能画出主流程图
- [ ] **能读懂源码的主函数（main loop）和关键创新模块**
- [ ] 知道算法适用什么问题、不适用什么问题
- [ ] 能在论文里准确引用 + 一句话指出区别
- [ ] 跑过一次，看过输出

**投入时间**：每个算法 1-2 天。

**关键点**：**不需要逐行读所有 .m 文件**。读主入口 + 创新模块（通常 1-2 个 .m）就够。

### L2：思想级（用于外围相关算法）

- [ ] 能口述算法核心思想（30 秒）
- [ ] 知道算法属于哪个流派
- [ ] **不需要读源码**
- [ ] 知道它的代表作和发表期刊

**投入时间**：每个算法 30 分钟（读 abstract + intro + conclusion）。

### L3：名字级（用于无关算法）

- [ ] 知道这个名字大概是什么类（约束 / 大规模 / 多任务...）
- [ ] **不需要打开文件**

---

## 二、L0 必学（源码逐行吃透，5 个）

> **这一节的 5 个算法，每一个都要 L0 钢印级**。
> 是你 3 个月内**最优先**的学习对象。

### 1. REMO（你的 baseline）

- **目录**：`REMO/`
- **论文**：Hao et al., *Expensive Multiobjective Optimization by Relation Learning and Prediction*, IEEE TEVC 2022
- **为什么 L0**：这是你**论文的根**。每一行代码、每一个超参、每一个失败模式都必须知道。
- **关键文件**：
  - `REMO.m`（主循环）—— 钢印级
  - `RefSelect.m`（参考解选择 + 雷达图）—— 钢印级
  - `GetOutput_PBI.m`（PBI 分类）—— 钢印级
  - `GetRelationPairs.m`（配对训练数据）—— 钢印级
  - `RSurrogateAssistedSelection.m`（GA 生成 + 网络筛选）—— 钢印级
  - `DataProcess.m`、`onehotconv.m`、`Delequalsamples.m` —— 至少读懂
- **投入时间**：5-7 天（W2 整周）
- **检验标准**：见 [P0-11 自测](./REMO_一区文章必备知识地图.md)

### 2. NSGA-III（参考点法的根）

- **目录**：`NSGA-III/`
- **论文**：Deb & Jain, *An Evolutionary Many-Objective Optimization Algorithm Using Reference-Point-Based Nondominated Sorting Approach, Part I*, IEEE TEVC 2014
- **为什么 L0**：**所有 many-objective 算法的对照基线**。审稿人会问"你的方法和 NSGA-III 有什么区别"——你必须能立刻答上来。
- **关键模块**：
  - 主循环
  - **Das-Dennis 参考点生成**（很多 MaOEA 都用）
  - **Niche-preservation**（参考点关联 + 选择）
- **投入时间**：1.5 天
- **必懂的代码点**：参考点生成函数（`UniformPoint`）和关联函数

### 3. RVEA（APD 和参考向量自适应的根）

- **目录**：`RVEA/`
- **论文**：Cheng et al., *A Reference Vector Guided Evolutionary Algorithm for Many-Objective Optimization*, IEEE TEVC 2016
- **为什么 L0**：**APD 是你方向必懂的**（论文 Method 章节多半要对比/借鉴）。
- **关键模块**：
  - APD 计算
  - 参考向量自适应（reference vector adaptation）
- **投入时间**：1.5 天
- **必懂的公式**：APD 公式必须能默写

### 4. K-RVEA（昂贵超多目标的标杆）

- **目录**：`K-RVEA/`
- **论文**：Chugh et al., *A Surrogate-assisted Reference Vector Guided EA for Computationally Expensive Many-Objective Optimization*, IEEE TEVC 2018
- **为什么 L0**：**这是你最强的对照算法**。它做了昂贵超多目标的标杆——Kriging + APD + 模型管理。你的论文 90% 概率要跟它对比。
- **关键模块**：
  - Kriging 训练 / 预测
  - **模型管理（diversity-based vs convergence-based）**——这是它的核心创新
  - 不确定性使用方式
- **投入时间**：2 天
- **必懂**：为什么 K-RVEA 比 RVEA 强（不确定性管理 + 自适应参考向量）

### 5. CSEA（分类代理的根）

- **目录**：`CSEA/`
- **论文**：Pan et al., *A Classification Based Surrogate-Assisted EA for Expensive Many-Objective Optimization*, IEEE TEVC 2019
- **为什么 L0**：**和你 REMO 同根同源**——分类代理（不是回归代理）。你的论文必须解释 REMO 和 CSEA 的本质区别（关系 vs 分类）。
- **关键模块**：
  - 标签构造方式（"好"/"坏"二分类）
  - 神经网络训练
  - preselection 机制
- **投入时间**：1.5 天
- **必懂**：CSEA 的标签 vs REMO 的关系标签 —— 写在你 Related Work 章节里的关键对比

**L0 合计**：5 个算法 × 平均 2.4 天 ≈ 12 天，对应你 W2-W3。

---

## 三、L1 必懂（主流程 + 关键模块源码，约 12 个）

> **这一节算法读主流程 + 创新模块**，不要每一行都读。
> 在你方向的 Related Work 章节里需要被引用 / 比较。

### A. 昂贵优化经典基线（5 个）

#### 6. ParEGO

- **目录**：`ParEGO/`
- **论文**：Knowles, *ParEGO: A Hybrid Algorithm with On-Line Landscape Approximation for Expensive Multiobjective Optimization*, IEEE TEVC 2006
- **为什么 L1**：**多目标 EGO 的鼻祖**。
- **必懂**：随机标量化 + Kriging + EI 的组合思想
- **投入**：1 天

#### 7. MOEA-D-EGO

- **目录**：`MOEA-D-EGO/`
- **论文**：Zhang et al., *Expensive Multiobjective Optimization by MOEA/D with Gaussian Process Model*, IEEE TEVC 2010
- **为什么 L1**：**分解 + 代理**的代表
- **必懂**：把 MOEA/D 子问题用 Kriging 加速的思路
- **投入**：1 天

#### 8. AB-SAEA

- **目录**：`AB-SAEA/`
- **论文**：Wang et al., *An Adaptive Bayesian Approach to Surrogate-Assisted EA for Multiobjective Optimization*, 2022
- **为什么 L1**：**2022 年后的代表性 SAEA**。审稿人喜欢看到你跟"新"算法对比。
- **必懂**：自适应贝叶斯方法
- **投入**：1.5 天

#### 9. KTA2

- **目录**：`KTA2/`
- **论文**：Song et al., *A Kriging-Assisted Two-Archive EA for Expensive Many-Objective Optimization*, IEEE TEVC 2021
- **为什么 L1**：**两 Archive 思想 + Kriging + 超多目标**——非常相关。
- **必懂**：两 archive 怎么分工
- **投入**：1.5 天

#### 10. MGSAEA

- **目录**：`MGSAEA/`
- **论文**：Pan et al., *A Multi-objective Generative SAEA*, 2023
- **为什么 L1**：**多代理 + 多目标**的新代表
- **必懂**：多代理融合思想
- **投入**：1 天

### B. Many-objective 经典（4 个）

#### 11. MOEA-D

- **目录**：`MOEA-D/`
- **论文**：Zhang & Li, *MOEA/D: A Multiobjective EA Based on Decomposition*, IEEE TEVC 2007
- **为什么 L1**：**分解法的鼻祖**。所有分解类算法都从它来。
- **必懂**：Tchebycheff / WS / PBI 三种标量化函数（你已经在 PBI 那知道了）；邻域更新机制
- **投入**：1 天

#### 12. t-DEA（θ-DEA）

- **目录**：`t-DEA/`
- **论文**：Yuan et al., *A New Dominance Relation-Based EA for Many-Objective Optimization*, IEEE TEVC 2016
- **为什么 L1**：**θ-dominance 的根**——改造支配关系的经典做法
- **必懂**：θ-dominance 怎么解决 Pareto 失效
- **投入**：1 天

#### 13. VaEA（Vector Angle EA）

- **目录**：`VaEA/`
- **论文**：Xiang et al., *A Vector Angle-Based EA for Unconstrained Many-Objective Optimization*, IEEE TEVC 2017
- **为什么 L1**：**角度选择**的代表，超多目标专用
- **必懂**：vector angle 怎么替代拥挤度
- **投入**：1 天

#### 14. AR-MOEA

- **目录**：`AR-MOEA/`
- **论文**：Tian et al., *An Adaptive Reference Point-Based EA for Irregular PF*, IEEE TEVC 2018
- **为什么 L1**：**自适应参考点**，对 irregular PF 重要
- **必懂**：参考点自适应机制
- **投入**：1 天

### C. 指标驱动（2 个）

#### 15. IBEA

- **目录**：`IBEA/`
- **论文**：Zitzler & Künzli, *Indicator-Based Selection in Multiobjective Search*, PPSN 2004
- **为什么 L1**：**指标驱动的鼻祖**，PIEA 系列的根
- **必懂**：用 ε 或 HV 指标做选择压力
- **投入**：1 天

#### 16. HypE

- **目录**：`HypE/`
- **论文**：Bader & Zitzler, *HypE: An Algorithm for Fast Hypervolume-Based Many-Objective Optimization*, ECJ 2011
- **为什么 L1**：**HV 估算 MaOEA**，HV 用法的代表
- **必懂**：Monte Carlo HV 估算思想
- **投入**：1 天

### D. 经典基础（1 个）

#### 17. NSGA-II

- **目录**：`NSGA-II/`
- **论文**：Deb et al., *A Fast and Elitist Multiobjective GA: NSGA-II*, IEEE TEVC 2002
- **为什么 L1**：**多目标 EA 的基础**。被引 5 万+。你方向虽然不直接用 NSGA-II，但**非支配排序 + 拥挤度**是所有 MOEA 的基础设施。
- **必懂**：非支配排序、拥挤度
- **投入**：1 天

**L1 合计**：12 个 × 平均 1.1 天 ≈ 13 天，对应你 W1 + W3。

---

## 四、L2 推荐了解（知道思想，约 15 个）

> **这一节算法只需要读 abstract + intro，知道思想就好**。
> **不需要打开 .m 文件**。
> 在你方向的论文里**可能**被引用。

### A. 你方向的其他代理算法

| 算法 | 一句话 |
|---|---|
| **PC-SAEA** | 分类代理变体 |
| **MGCEA** | 多代理协同 |
| **HeE-MOEA** | 异构集成 SAEA |
| **AVG-SAEA** | 平均代理 SAEA |
| **DRL-SAEA** | 深度强化学习 + SAEA |
| **EDN-ARMOEA** | 编码 + AR-MOEA |
| **EIM-EGO** | EI 指标 EGO |
| **NSGAIII-EHVI** | EHVI 改进 NSGA-III |
| **DirHV-EI** | 方向 HV + EI |
| **MultiObjectiveEGO** | 多目标 EGO 集大成 |
| **SMS-EGO** | SMS + EGO |
| **BL-SAEA** | 贝叶斯学习 SAEA |
| **PIEA** | 你已经用过的 PIEA 本体 |
| **HEA** | 异构集成 EA |
| **PC-SAEA** | 偏好分类 SAEA |

**投入**：每个算法 30 分钟，**全部一起 1 周内完成扫描**（W1 全景扫描周）。

### B. 你方向的相关 MaOEA

| 算法 | 一句话 |
|---|---|
| **MaOEA-IGD** | IGD 驱动 MaOEA |
| **MaOEA-CSS** | 收敛聚类 MaOEA |
| **MaOEA-IT** | 倒立锥 MaOEA |
| **MaOEA-R&D** | 参考方向 MaOEA |
| **MaOEA-DDFC** | 双距离收敛 MaOEA |
| **GrEA** | 网格 MaOEA |
| **PREA** | 偏好排名 MaOEA |
| **NSGA-II-SDR** | SDR 改进支配 |
| **NSGA-II-DTI** | DTI 改进多样性 |
| **A-NSGA-III** | 自适应 NSGA-III |
| **MOMBI-II** | 指标驱动 MaOEA |
| **AGE-MOEA / AGE-MOEA-II** | 自适应几何 MaOEA |
| **RVEAa** | RVEA 增强版 |
| **PB-RVEA** | 基于偏好的 RVEA |
| **RVEA-iGNG** | 增量神经气 RVEA |

**投入**：每个算法 30 分钟，**与上面合并扫描**。

### C. 经典基础（被引常用）

| 算法 | 一句话 |
|---|---|
| **MOEA-D-DE** | MOEA/D + DE 算子 |
| **SPEA2** | 经典老牌，了解即可 |
| **e-MOEA** | ε-dominance MOEA |
| **NSGA-II-conflict** | 冲突维度处理 |

**投入**：合并扫描。

**L2 合计**：约 30 个算法 × 30 分钟 = 15 小时（约 2-3 天），分散在 W1。

---

## 五、L3 可跳过（与你方向无关，约 250 个）

> **这一节是你需要"主动忽略"的算法**。
> 看到这些目录直接跳过，不要被吓到。

### A. 约束多目标（CMOP）—— 跳过

`C-MOEA-D, C-TAEA, C-TSEA, C3M, CA-MOEA, CCMO, CMDEIPCM, CMEGL, CMME, CMMO, CMOCSO, CMODE-FTR, CMOEA-CD, CMOEA-MS, CMOEA-MSG, CMOEMT, CMOES, CMOPSO, CMOQLMT, CMOSMA, CMaDPPs, CNSDE-DVC, CPS-MOEA, CoMMEA, CSEMT, DPCPRA, DSPCMDE, EMCMMS, EMCMO, IMTCMO, IMTCMO_BS, MCCMO, MCEA-D, MSCMO, MTCMO, NSBiDiCo, POCEA, URCMO, ToP, c-DPEA, FRCG-M, PPS, DP-PPS, BiCo, NRV-MOEA, MOEA-D-DAE`

**为什么跳过**：你做的是**无约束**昂贵超多目标。约束方向是另一个研究领域。

### B. 大规模多目标（LSMOP）—— 跳过

`LMEA, LMOCSO, LMOEA-DS, LMPFE, LRMOEA, LSMOF, MOEA-DVA, RMOEA-DVA, SparseEA, SparseEA2, TS-SparseEA, WOF, FDV, DGEA, GLMO, MOEA-PSL, MMEAPSL, S-ECSO, SLMEA, SSDE, DVCEA, CCGDE3, MFFS, MGCEA, MSKEA, TPCMaO`

**为什么跳过**：大规模指的是决策变量 D ≥ 100。你昂贵优化通常 D ≤ 30。

### C. 多任务多目标（MTMO）—— 跳过

`MO-MFEA, MO-MFEA-II, MOMFEA-SADE, DBEMTO, MTEA-D-DN, MTDE-MKTA, MOEA-D-CMT, EMOSKT, MFO-SPEA2`

**为什么跳过**：多任务是知识迁移方向，与你不相关。

### D. 多模态多目标（MMOP）—— 跳过

`AC-MMEA, HHC-MMEA, MMEA-WI, MMOPSO, MP-MMEA, MO_Ring_PSO_SCD`

**为什么跳过**：多模态指的是 PS 有多个等价局部最优。

### E. 动态多目标（DMOP）—— 跳过

`DN-NSGA-II, DNSGA-II, SGEA, MOEA-D-2WA, DSSEA`

**为什么跳过**：环境随时间变化。你做的是静态问题。

### F. 双层 / 多层优化 —— 跳过

`BLEAQ-II, BiGE`

**为什么跳过**：双层结构，与你方向无关。

### G. 偏好驱动（特殊场景）—— 跳过

`g-NSGA-II, r-NSGA-II, GWASF-GA, WASF-GA, PB-NSGA-III, RPD-NSGA-II, RPEA, I-DBEA, I-SIBEA, S-CDAS, S-NSGA-II`

**为什么跳过**：要决策者偏好输入，不是通用算法。

### H. 单目标 PSO/CMA-ES（被收录但不归你方向）—— 跳过

`MO-CMA, S3-CMA-ES, SMPSO, MOPSO, MOPSO-CD, MOCell, dMOPSO, NMPSO, GPSO-M, MPSO-D, ADSAPSO, OSP-NSDE`

**为什么跳过**：PSO/CMA-ES 是优化器选择，不影响你的代理模型方向。

### I. 其他冷门 / 老旧 —— 跳过

`AdaW, BCE-IBEA, BCE-MOEA-D, CLIA, CAEAD, DAEA, DCNSGA-III, DEA-GNG, DKCA, DMOEA-eC, DPVAPS, DRLOS-EMCMO, DSR_REMO (你已用过), DWU, EAG-MOEA-D, EFR-RR, ENS-MOEA-D, FLEA, GCNMOEA, GDE3, GFM-MOEA, ICMA, IM-C-MOEA-D, IM-MOEA, IM-MOEA-D, KnEA, LCMEA, LCSA, LDS-AF, LERD, M-PAES, MO-EGS, MO-L2SMEA, MOBCA, MOCGDE, MOEA-CKF, MOEA-D-AWA, MOEA-D-CMA, MOEA-D-DCWV, MOEA-D-DQN, MOEA-D-DRA, MOEA-D-DU, MOEA-D-DYTS, MOEA-D-FRRMAB, MOEA-D-M2M, MOEA-D-MRDL, MOEA-D-PFE, MOEA-D-PaS, MOEA-D-STM, MOEA-D-UR, MOEA-D-URAW, MOEA-D-VOV, MOEA-DD, MOEA-IGD-NS, MOEA-NZD, MOEA-PC, MOEA-RE, MOED-D-DE-Meta, MOSD, MSEA, MSOPS-II, MTS, MyO-DEMR, NBLEA, NMPSO, NNDREA-MO, NNIA, NUCEA, PESA-II, PICEA-g, PIMD, PM-MOEA, PRDH, R2AEA, RGA-M1-2, RGA-M2-2, RM-MEDA, RSEA, S-CDAS, SCEA, SFA-DE, SGECF, SIBEA, SIBEA-kEMOSS, SMEA, SMOA, SMS-EMOA, SPEA-R, SPEA2+SDE, SRA, SSCEA, TEA, TELSO, TSTI, TiGE-2, TS-NSGA-II, TriMOEA-TA&R, Two_Arch2, WV-MOEA-P, hpaEA, one-by-one EA, tDEA-CPBI, EMMOEA, ESBCEO, AGSEA, AFSEA, APSEA, AGE-II, BiGE, MLP_MOO, MOEA-D-EGO（已列 L1）, Izui, MaOEA-CSS, PeEA, R2_REMO_SR, R2_REMO（你已用过）, MOSD, MOEA-D-EGO 已列...`

**为什么跳过**：这些是其他研究子方向的工作，对你不构成直接帮助。

**汇总**：300 个算法里 **80% 你可以跳过**，只读 **L0 (5) + L1 (12) + L2 (15) ≈ 32 个**。这是大幅减负。

---

## 六、你自己的 REMO 家族（特殊清单）

> 这些是你之前做过的，**不需要重新学**，但要**整理出哪个保留为消融、哪个作废**。

### A. 保留作为消融基线

| 算法 | 价值 | 用途 |
|---|---|---|
| `REMO` | 原始 baseline | 主对照 |
| `REMO_new2` | hybrid PBI 改进 | 消融 baseline 1 |
| `REMO_new2_TrueSR` | soft ranking | 消融 baseline 2 / 论文核心组件之一 |
| `REMO_new2_PIEA5` | 你 PIEA 系列的最优版 | 反例叙事素材（v4 失败 → v5 回滚） |
| `REMO_new2_RegionalSR_A/B` | 区域化软排序 | 消融 baseline 3 |

### B. 失败案例（论文写作的"叙事素材"）

| 算法 | 失败原因 |
|---|---|
| `REMO_new2_PIEA4` | DTLZ7 退化 62% —— 「合并 PBI 和 Fitness 标签会破坏关系学习」的关键证据 |
| `REMO_new2_SR` | 旧版 soft ranking，被 TrueSR 替代 |
| `REMO_new2_clean` | 清理版本，不重要 |
| `REMO_new2_confidence`, `REMO_new2_uncertainty` | 早期不确定性尝试 |
| `REMO_new2_AdaMaO` | 自适应三模式，作为对比 |

### C. 其他变体（看情况）

| 算法 | 备注 |
|---|---|
| `D_REMO`, `D_REMO_Add`, `D_REMO_NoReg`, `DSR_REMO` | 分布学习尝试 |
| `REMO_C2RL`, `REMO_DORL` | 强化学习尝试 |
| `REMO_MaO`, `REMO_SRMaO` | 超多目标尝试 |
| `REMO_My`, `REMO_SDE`, `REMO_Siamese`, `REMO_global`, `REMO_global_SDE` | 各种早期变体 |
| `REMO_new`, `REMO_new3`, `REMO_new2_WFG10` | 实验变体 |
| `Subproblem_REMO`, `Subproblem_REMO_delsample` | 分解尝试 |
| `R2_REMO`, `R2_REMO_SR` | R2 指标尝试 |

**W4 痛点定位时的关键动作**：

> 把上面的"失败案例"重新看一遍——**哪一个失败教会了你机制层面的东西？**
>
> 比如 PIEA4 的失败教会你「多方向 PBI 标签 vs 单值 Fitness 标签」的冲突——这就是论文的种子。

---

## 七、学习顺序与时间投入

把上面的清单嵌入你的 [三月攻坚计划](./REMO_一区论文三月攻坚计划.md) 里：

```
W1 (全景扫描)：
  ├─ L2 全部 15-30 个算法的速览（每个 30 分钟）= 15-20 小时
  └─ L1 中的 NSGA-II + MOEA-D 各 1 天（基础打底）= 2 天

W2 (关系学习线)：
  ├─ REMO (L0)：5 天集中攻坚
  ├─ CSEA (L0)：1.5 天
  └─ Day 6-7 准备讲解稿

W3 (超多目标线)：
  ├─ NSGA-III (L0)：1.5 天
  ├─ RVEA (L0)：1.5 天
  ├─ K-RVEA (L0)：2 天
  ├─ t-DEA + VaEA + AR-MOEA (L1)：各 1 天 = 3 天
  └─ Day 7 横向对比表

W4 (痛点定位)：
  ├─ ParEGO, MOEA-D-EGO, KTA2, AB-SAEA, MGSAEA (L1)：散读
  └─ 重读你的失败案例（PIEA4 等）

W5+ ：根据需要随时回查 L1 / L2 清单
```

**总学习时长**：
- L0 (5 个)：12 天 ≈ 48-60 小时
- L1 (12 个)：13 天 ≈ 50-60 小时
- L2 (15-30 个)：15 小时
- **合计 ≈ 120-135 小时**（占你 3 个月 364 小时的 33%）

剩下 65% 时间投入：方法设计 (W5-6) + 代码 (W7-8) + 实验 (W9-10) + 写作 (W11-13)。

---

## 八、附录：如何"吃透"一个算法的源码

### 8.1 读 L0 算法的源码顺序

1. **先读 README / 注释**（如果有）
2. **画一张数据流图**（从主入口 .m 开始，把每个函数调用画出来）
3. **逐函数读**：从 main 开始，**深度优先**
4. **每个函数读完写 3 行注释**：输入是什么 / 做了什么 / 输出是什么
5. **对每个超参问：为什么是这个值？**
6. **试跑一次**：改 1-2 个超参，看 IGD 变化
7. **写讲解稿**：自己用中文写一份完整流程（至少 3000 字）

### 8.2 读 L1 算法的源码顺序

1. 读 abstract + intro，**用 3 句话概括核心思想**
2. 打开主 .m 文件，**只读主循环**
3. 找出**最关键的 1-2 个创新模块**（通常是 .m 文件名带创新名字的）
4. 跑一次，验证你理解的输入输出
5. 写 200 字的笔记

### 8.3 不要做的事

- ❌ **不要按字母顺序遍历所有 .m**
- ❌ **不要每一行都加注释**（浪费时间，没收益）
- ❌ **不要在 L2 算法上读源码**（你不需要）
- ❌ **不要在能跑通前调 1 小时参数**（先理解算法逻辑）

### 8.4 用 AI 加速源码理解的正确方式

```
你: [粘贴 RVEA.m 的代码] 这段代码的核心思想是什么？
AI: ... [给出解释]

你: 这里的 APD 公式具体怎么影响选择？给我画一个 2D 例子
AI: ... [画图说明]

你: 如果我把 alpha = 2 改成 alpha = 0.5，行为会怎么变？
AI: ... [机制层面回答]
```

**注意**：AI 帮你**理解**，不替你**记忆**。看完 AI 解释后，**关掉 AI**自己复述一遍——记住的才算自己的。

---

## 写在最后

3 个月内你需要的**全部清单**：

```
L0 必须钢印（5 个）：
  REMO / NSGA-III / RVEA / K-RVEA / CSEA

L1 必须模块级（12 个）：
  ParEGO / MOEA-D-EGO / AB-SAEA / KTA2 / MGSAEA /
  MOEA-D / t-DEA / VaEA / AR-MOEA / IBEA / HypE / NSGA-II

L2 思想级（约 30 个）：
  其他 SAEA + 其他 MaOEA + 经典基础（清单见第四节）

L3 跳过（约 250 个）：
  约束 / 大规模 / 多任务 / 多模态 / 动态 / 双层 / 偏好等其他方向
```

> **核心认知**：
>
> 1. "必须掌握"**不等于**"源码逐行吃透"——只有 **REMO 本身**要求 L0。
> 2. 一区论文的功夫**不在于"读了多少算法"**，而在于"对 baseline 和最强对照算法的理解深度"。
> 3. 看到 300 个算法目录不要慌——**80% 跟你方向无关**。
> 4. 让 AI 帮你**理解**算法，但 **L0 钢印必须自己复述**（这是审稿和汇报的护城河）。

把这份清单贴在你的工作目录置顶。每次想"我是不是应该读 XX 算法"时，先来这里查它在哪一级。
