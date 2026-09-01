# 混合 PBI 方法节：骨架评估与中英文初稿

> 文档状态：方法节第一版。文中的 `[MOEA/D]`、`[REMO]`、`[RSEA]`、`[PIEA]`、`[PC-SAEA]` 和 `[R2AEA]` 为占位引用，定稿时应替换为参考文献编号。实验结果、消融结论和统计量尚未在本文档中写成既成事实，待与最终实验表格逐项对齐后再补入。

## 一、对原写作骨架的评估

### 1. 总体判断

原骨架的主线是合理的：从昂贵多目标优化中关系标签的构造困难出发，分别定义连续 PBI 评分和二值 PBI 标签，再通过随评价预算变化的权重生成最终分组，并将其用于关系样本构造。这条叙事具有清楚的问题闭环，也与所阅读文献常用的“问题动机—总体框架—模块机制—算法流程—复杂度—实验接口”结构一致。

但原骨架还不能直接作为论文正文。最重要的问题不是公式不够，而是部分解释超过了代码和现有证据能够支持的范围。建议对骨架作“有条件通过”：保留双粒度标签、预算调度、排序命题、参考解规模和关系对构造五个核心模块，同时修正术语、归因和理论边界。

### 2. 五篇文献的共同写作思路

五篇论文虽然方法不同，但方法节具有相近的组织逻辑。

1. **先把设计困难说具体，再给总体框架。** REMO 先指出多目标关系分类同时受到收敛性、分布性和类别平衡的影响；PC-SAEA 先把“如何比较解的质量”和“如何构造样本对”拆成两个问题；R2AEA 则先解释有限评价预算下不同阶段需要承担不同任务。
2. **每个模块都形成局部闭环。** 常见写法是依次交代模块的动机、输入、计算规则、输出以及它在总流程中的作用，而不是连续堆叠公式。
3. **公式后立即给语义解释。** PIEA 对指标及其产生的偏好逐一解释；RSEA 在给出径向投影和动态参数后，紧接着说明它们分别影响收敛或分布；REMO 则把参考解选择、PBI 分组和关系对生成按数据流连接起来。
4. **算法框架统一执行顺序，正文解释设计理由。** 几篇论文普遍使用框架图或伪代码负责“怎么运行”，用分节正文回答“为什么这样设计”。
5. **把方法定义与效果验证分开。** 参数阈值、阶段切换或模块作用通常先在方法节中定义，其有效性留到实验节验证。方法节可以提出设计假设，但不应把消融结果尚未支持的机制直接写成事实。

其中，REMO 对本节的结构参考价值最大；PC-SAEA 适合借鉴模块化和问题拆分方式；PIEA 说明标签或偏好信号本身应作为一等设计对象；R2AEA 适合借鉴预算阶段的叙事；RSEA 则提供了径向参考解选择的来源及其能力边界。

| 文献    | 方法节的写作路径                                                 | 值得借鉴的表达方式                                                                         | 本文不应直接照搬的内容                                                   |
| ------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| PIEA    | 总体框架 → 多种指标定义 → 基于模型的优化 → 历史信息自适应选择 | 每个数学指标之后立即解释它代表的偏好，并在末尾集中给出复杂度                               | 指标池和历史选择属于 PIEA 的任务设定，不能用来证明双粒度 PBI 有效        |
| PC-SAEA | 框架图/伪代码 → 解质量比较 → 样本配对 → 分类与选择            | 先提出两个可回答的问题，再让每个小节解决其中一个；机制描述简洁，实验验证明确后置           | 其配对和分类目标与当前 DG-PBI 标签并不相同，只能借鉴组织方式             |
| R2AEA   | 动机分析 → 两阶段总流程 → 各阶段角色 → 切换条件               | 明确说明有限预算下各阶段承担什么功能，并把阈值合理性留给实验节                             | 两阶段算法的硬切换不能直接等同于本文连续变化的权重调度                   |
| RSEA    | 既有投影能力分析 → 总体框架 → 网格、交配和环境选择 → 动态参数 | 在提出模块前先诚实说明径向投影保留什么、损失什么；公式后解释参数随进程变化的作用           | RSEA 的动态参数作用对象不同，不能作为本文$\alpha$ 调度有效性的直接证据 |
| REMO    | 关系学习困难 → 通用框架 → 种群分组 → 关系对生成 → 模型使用   | 从类别不平衡和多目标分布困难切入，沿“分组—配对—学习”数据流展开，最适合作为本节结构模板 | REMO 原文的近 1:1 分组目标与当前仓库的 0.3–0.7 宽容区间应明确区分       |

### 3. 原骨架中需要保留的内容

- 将最终监督信号定义为**双粒度 PBI 标签**，而不是声称提出新的 PBI 标量化函数。
- 分别定义连续评分和二值标签，再说明它们如何进入统一排序。
- 使用评价进度控制两种粒度的相对权重。
- 给出跨二值类别排序的形式化命题，但要修正严格不等式条件。
- 将有效参考解数与目标数联系起来，并明确它是一个待验证的启发式设计。
- 交代正组比例、关系对构造、样本平衡和计算复杂度，使模块可以复现。

### 4. 必须修正的关键表述

| 原骨架倾向                             | 建议改写                                                                         | 原因                                                                |
| -------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| “PBI 完全按 MOEA/D 原式使用”         | “连续分支采用常规 PBI 形式；二值分支沿用 REMO 式基于参考解的 PBI 二值分组”     | 两个分支的几何对象和归一化不同，不能都归为同一原式                  |
| “连续信号负责收敛，二值信号负责分布” | “连续信号保留组内次序，二值信号给出粗粒度边界”                                 | 两者都含有平行与垂直距离，不能在没有隔离实验时作收敛/分布的独占归因 |
| 将连续值称为 margin                    | 称为 continuous PBI score                                                        | 当前量是 PBI 值的单调变换，不是分类器意义上的间隔                   |
| “原始坐标关联不影响排序”             | 明确写出“原始目标空间关联、理想点平移后计算距离”的实现约定，并承认其非平移不变 | 平移可能改变方向关联和最终排序，原解释不成立                        |
| “二值比例被保证在 0.3–0.7”          | “在有限搜索区间内寻求落入 0.3–0.7；容差终止时不构成数学保证”                  | 代码存在搜索区间和终止容差                                          |
| 将 0.3–0.7 直接归因于 REMO 论文       | 区分“REMO 论文趋近 0.5 的思想”和“当前仓库基线的宽容区间实现”                 | 论文描述与仓库实现并不完全相同                                      |
| “两种信号独立互补”                   | “两种信号具有不同表示粒度，但共享当前种群和 PBI 几何”                          | 不能把同源信号写成统计独立或几何独立                                |
| “早期连续可靠、后期二值可靠”         | “这是预算调度的设计动机，效果由消融和诊断实验检验”                             | 当前解释属于机制假设，不是源代码事实                                |
| `M=5` 时 `k_eff=6`                 | `M=5` 时 `k_eff=8`                                                           | `ceil(1.5×5)=8`                                                  |
| “评价预算仅有三代”                   | “真实评价预算为三个种群规模”                                                   | 算法内部仍可执行多轮代理搜索，不能等同于三代                        |
| “额外开销可忽略”                     | “不增加昂贵函数评价；时间占比需实测后报告”                                     | 复杂度可推导，但墙钟占比需要数据                                    |

### 5. 建议采用的章节结构

建议把原骨架整理为以下六个小节：

1. 问题定义与总体流程；
2. 种群派生的连续 PBI 评分；
3. 基于参考解的 PBI 二值分组；
4. 预算感知的双粒度融合与排序性质；
5. 面向目标数的参考解规模；
6. 关系样本构造、算法流程与复杂度。

这种安排与数据流一致：当前种群首先产生两种监督信号，随后生成最终分组，再构造关系训练样本。参考解规模紧随融合模块说明，便于解释它只作用于二值分支，而不是整个 PBI 框架。

---

## 二、中文初稿

## 3 双粒度 PBI 标签构造

在昂贵多目标优化中，代理模型不仅需要预测候选解的目标值，还可以通过学习解之间的相对关系来降低建模难度。然而，关系学习的有效性高度依赖于监督标签的质量。仅使用连续标量值能够保留当前种群中的细粒度排序，但其数值尺度和方向关联容易随种群状态变化；仅使用二值分组则能够形成清晰的决策边界，却会丢失同一组内的相对次序。为此，本文构造一种双粒度 PBI（dual-granularity PBI, DG-PBI）标签机制，将种群派生的连续 PBI 评分与基于参考解的 PBI 二值分组组合为统一的关系学习信号。

需要强调的是，本文不提出新的 PBI 标量化函数。连续分支采用常规 PBI 距离形式 `[MOEA/D]`，二值分支继承 REMO 中基于参考解进行关系分组的基本思想 `[REMO]`。本文的设计重点在于：如何把两种不同表示粒度的 PBI 信号组织为预算感知的监督标签，以及如何根据目标数设置二值分支的有效参考解规模。

### 3.1 问题定义与总体流程

设当前种群为

$$
\mathcal{P}=\{\mathbf{x}_i,\mathbf{f}_i\}_{i=1}^{N_t},
$$

其中，$N_t$ 为当前种群规模，$\mathbf{f}_i\in\mathbb{R}^{M}$ 为解 $\mathbf{x}_i$ 的 $M$ 维目标向量。DG-PBI 模块接收当前目标矩阵 $\mathbf{F}$、已消耗的真实函数评价次数 $FE$ 和最大评价预算 $B$，并输出每个个体的连续融合值 $h_i$ 及二值组标签 $c_i$。随后，算法按照 $h_i$ 对种群排序，将排名前 $\lceil r_gN_t\rceil$ 的个体划入正组，其余个体划入负组。本文实现取 $r_g=0.25$。

整个过程包含三个步骤。首先，利用当前种群或均匀参考向量构造方向集，并计算连续 PBI 评分；其次，从当前种群中选取少量参考解，并据此生成基于参考解的 PBI 二值分组；最后，根据真实评价进度组合两种信号，形成关系学习所需的最终分组。连续分支和二值分支共享同一当前种群，也都使用 PBI 几何，因此本文所说的“双粒度”表示监督信号的分辨率不同，而不意味着二者在统计或几何意义上相互独立。

### 3.2 种群派生的连续 PBI 评分

#### 3.2.1 方向集构造

连续分支需要一个方向集合

$$
\mathcal{V}=\{\mathbf{v}_j\}_{j=1}^{N_v}.
$$

当目标数较少（$M\leq 3$）或当前种群规模小于 50 时，本文采用均匀参考向量，以避免在样本不足时估计不稳定的种群方向。对于其余情形，首先通过非支配排序获得当前第一前沿 $\mathcal{P}^{\mathrm{ND}}$。若非支配解数量不足或其目标范围发生退化，则退回均匀参考向量；否则，在按各目标范围归一化后的非支配目标上执行 $k$-means 聚类，并将聚类中心映射回原目标尺度后单位化，得到种群派生的方向集。

这种构造使方向集能够随当前种群覆盖区域变化，但它也会继承当前非支配解的覆盖偏差。当方向数接近非支配解数量时，部分方向可能接近其生成样本本身。因此，本文将其描述为“种群派生方向”，而不假设它能够提供独立于当前种群的全局前沿几何。

#### 3.2.2 连续 PBI 值

对任一个体 $\mathbf{f}_i$，首先通过余弦相似度将其关联到方向 $\mathbf{v}_{a(i)}$：

$$
a(i)=\arg\max_j
\frac{\mathbf{f}_i^{\mathsf T}\mathbf{v}_j}
{\|\mathbf{f}_i\|_2\|\mathbf{v}_j\|_2}.
$$

令当前种群理想点为

$$
\mathbf{z}^{*}=\min_{i=1,\ldots,N_t}\mathbf{f}_i,
$$

其中最小值按目标逐维计算。对于与 $\mathbf{v}_{a(i)}$ 关联的个体，定义平行距离和垂直距离为

$$
d_{1,i}=
\frac{(\mathbf{f}_i-\mathbf{z}^{*})^{\mathsf T}\mathbf{v}_{a(i)}}
{\|\mathbf{v}_{a(i)}\|_2},
$$

$$
d_{2,i}=\left\|
(\mathbf{f}_i-\mathbf{z}^{*})-
d_{1,i}\frac{\mathbf{v}_{a(i)}}{\|\mathbf{v}_{a(i)}\|_2}
\right\|_2.
$$

连续 PBI 值及其单调评分分别为

$$
g_i^{\mathrm{con}}=d_{1,i}+\theta d_{2,i},
\qquad
s_i=\frac{1}{1+g_i^{\mathrm{con}}},
\tag{1}
$$

其中 $\theta=5$。较大的 $s_i$ 表示在当前关联方向下具有较小的 PBI 值。与直接输出一个二值类别相比，$s_i$ 保留了当前种群中的细粒度次序。

上述定义严格描述当前实现：方向关联在原始目标向量上完成，而距离在理想点平移后的目标向量上计算。这一约定并不具有平移不变性，改变目标原点可能同时改变方向关联和评分次序。本文所有实验均采用相同约定；若需要研究该选择的影响，应将“原始坐标关联”和“理想点平移后关联”设置为独立消融，而不在方法定义中预设二者等价。

### 3.3 基于参考解的 PBI 二值分组

连续评分给出了个体在种群方向集上的相对次序，但关系分类还需要一个稳定、可解释的粗粒度边界。为此，本文从当前种群中选取 $k_{\mathrm{eff}}$ 个参考解，记为

$$
\mathcal{R}=\{\mathbf{r}_j\}_{j=1}^{k_{\mathrm{eff}}}.
$$

参考解选择沿用 REMO 使用的径向投影式代表解选择，而该选择思想来源于 RSEA `[RSEA, REMO]`。其基本目标是在兼顾收敛状态的同时，从当前种群的不同径向区域中选取代表点。本文没有把参考解当作真实 Pareto 前沿点，而仅将其视为当前种群内部的动态参考基准。

对于个体 $\mathbf{f}_i$，首先按照原始目标空间中的夹角将其关联到参考解 $\mathbf{r}_{b(i)}$。令

$$
\mathbf{w}_{b(i)}=
\frac{\mathbf{r}_{b(i)}-\mathbf{z}^{*}}
{\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2}.
$$

相对于关联参考解的平行距离和垂直距离为

$$
\hat d_{1,i}=(\mathbf{f}_i-\mathbf{z}^{*})^{\mathsf T}\mathbf{w}_{b(i)},
$$

$$
\hat d_{2,i}=\left\|
(\mathbf{f}_i-\mathbf{z}^{*})-\hat d_{1,i}\mathbf{w}_{b(i)}
\right\|_2.
$$

在给定平衡参数 $\delta$ 时，定义基于参考解的归一化 PBI 值

$$
g_i^{\mathrm{bin}}(\delta)=
\frac{\hat d_{1,i}+\delta\hat d_{2,i}}
{\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2}.
\tag{2}
$$

相应的二值标签为

$$
\ell_i(\delta)=
\mathbb{I}\left[g_i^{\mathrm{bin}}(\delta)\leq 1\right].
\tag{3}
$$

式（2）中的 $\delta$ 是用于调节二值分组比例的有符号参数，而不是新的 PBI 函数参数主张。REMO 原文通过调节参数使两类规模尽可能接近 1:1；当前仓库基线实现则在区间 $[-20,20]$ 内进行二分搜索，并寻求使正标签比例进入 $[0.3,0.7]$ 的参数。本文沿用后一实现，以降低极端类别不平衡对关系分类训练的影响。由于搜索具有有限区间和终止容差，该过程的作用是“寻求”一个宽容的类别比例，而非对所有种群状态作数学保证。

二值分组信号只表示个体位于当前参考解所定义分组边界的哪一侧，不再区分同一类别内的相对质量。因此，它提供的是粗粒度分组信息，而不是连续评分的替代品。

### 3.4 预算感知的双粒度融合

令真实评价进度为

$$
\rho=\min\left(1,\frac{FE}{B}\right),
$$

并定义连续分支的权重

$$
\alpha=1-\rho.
\tag{4}
$$

连续评分和二值标签通过

$$
h_i=\alpha s_i+(1-\alpha)\ell_i
\tag{5}
$$

组合为最终排序值。算法按照 $h_i$ 降序排列种群，并定义

$$
c_i=
\begin{cases}
1, & \operatorname{rank}_{\downarrow}(h_i)
\leq \lceil r_gN_t\rceil,\\
0, & \text{otherwise}.
\end{cases}
\tag{6}
$$

式（4）使连续评分的名义权重随真实评价进度线性下降，而二值标签的权重相应上升。其设计意图是：在预算前段保留更多组内排序信息，在预算后段逐渐强化粗粒度边界。这里的“前段”和“后段”只描述调度策略，不预先断言哪一种信号在相应阶段必然更准确。该机制是否优于固定权重或单一信号，需要通过相同种群轨迹上的信号诊断、受控消融和最终性能实验分别验证。

#### 命题 1：二值类别诱导的两级排序

对任意 $i,j$，设 $\ell_i=1$、$\ell_j=0$，且 $s_i\in(0,1]$、$s_j\in(0,1]$。当 $\alpha\leq 1/2$ 时，有

$$
h_i>h_j.
$$

**证明。** 由式（5），

$$
h_i=(1-\alpha)+\alpha s_i>1-\alpha,
$$

而

$$
h_j=\alpha s_j\leq\alpha.
$$

当 $\alpha\leq1/2$ 时，$1-\alpha\geq\alpha$，因此 $h_i>h_j$。证毕。

命题 1 表明，当二值分支权重不小于连续分支时，式（5）形成一个明确的两级排序：二值正类整体优先于二值负类，而连续评分只负责各二值类别内部的次序。更一般地，定义跨类别连续评分差

$$
\Delta_{01}=
\max_{j:\ell_j=0}s_j-
\min_{i:\ell_i=1}s_i.
$$

若

$$
\alpha<\frac{1}{1+\Delta_{01}},
\tag{7}
$$

则二值正类仍严格排在二值负类之前。式（7）给出了一个可测的信号接口：实验中可以记录 $\Delta_{01}$、实际 $\alpha$ 及类别交叉排序次数，用于判断预算调度何时真正改变了排序结构。

需要注意，分类器第一次被调用时通常已经完成初始种群评价，因此实际使用的首个权重不是 $\alpha=1$，而是

$$
\alpha_{\mathrm{first}}=1-\frac{N_{\mathrm{init}}}{B}.
$$

例如，当 $N_{\mathrm{init}}=100$ 且 $B=300$ 时，首个实际权重为 $2/3$。因此，论文中的调度图应同时报告名义函数和算法实际访问到的权重区间。

### 3.5 面向目标数的有效参考解规模

二值分支的有效参考解数设为

$$
k_{\mathrm{eff}}=
\min\left(N_p,\max\left(6,\left\lceil1.5M\right\rceil\right)\right),
\tag{8}
$$

其中 $N_p$ 为算法的名义种群规模。该设置给每个目标配置随维度增长的代表容量，同时以 6 作为小目标数情形下的下界。例如，在 $N_p$ 不构成上限时，$M=3,5,10,20$ 分别得到 $k_{\mathrm{eff}}=6,8,15,30$。

在当前实现中，$k_{\mathrm{eff}}$ 不仅决定参考解数量，还通过

$$
n_{\mathrm{div}}=\left\lceil\sqrt{k_{\mathrm{eff}}}\right\rceil
$$

影响径向网格分辨率。因此，改变 $k_{\mathrm{eff}}$ 会同时改变参考解容量和参考解选择的空间划分。本文将式（8）视为一个面向目标数的耦合启发式，而不把“更多参考解必然更好”作为理论结论。其作用应通过固定参考解数、仅改变网格分辨率以及联合改变两者的受控消融分别检验。

### 3.6 关系样本构造与算法流程

得到最终组标签 $c_i$ 后，本文按照 REMO 的关系建模方式构造有序样本对 `[REMO]`。对于任意两个不同个体 $(\mathbf{x}_i,\mathbf{x}_j)$，根据 $(c_i,c_j)$ 形成四类关系：正–正、负–负、正–负和负–正。为避免同组样本数量远大于跨组样本，算法对正–正和负–负关系进行随机下采样，使其规模与跨组关系保持同一量级；自配对样本被移除。最终关系分类器学习的是由 DG-PBI 分组诱导的相对类别，而不是个体的精确目标值。

算法 1 总结了标签构造过程。

```text
算法 1  双粒度 PBI 标签构造
输入：当前种群 P，评价次数 FE，评价预算 B，目标数 M，正组比例 rg
输出：最终组标签 c，融合排序值 h，参考解 R

1: 构造均匀或种群派生方向集 V
2: 计算连续 PBI 值 gcon，并令 s = 1/(1+gcon)
3: 根据式（8）计算 keff
4: 从当前种群中选择 keff 个参考解 R
5: 在有限区间内搜索平衡参数 δ，并由式（2）–（3）得到二值标签 l
6: 令 α = 1 - min(1, FE/B)
7: 由 h = αs + (1-α)l 计算融合排序值
8: 将 h 最大的 ceil(rg|P|) 个体标记为正组，其余标记为负组
9: 返回 c、h 和 R
```

若连续方向数 $N_v=O(N_t)$，则个体–方向关联和连续 PBI 计算的复杂度为 $O(N_tN_vM)$。种群方向聚类的复杂度为 $O(RI\,N_{\mathrm{ND}}K_vM)$，其中 $R$、$I$ 和 $K_v$ 分别表示聚类重复次数、最大迭代次数和聚类数。二值分支的参数搜索复杂度为 $O(B_{\delta}N_tk_{\mathrm{eff}}M)$，其中 $B_{\delta}$ 是由搜索区间和容差限定的迭代次数。参考解选择还包含非支配排序和径向距离计算。在 $N_v=O(N_t)$、$k_{\mathrm{eff}}=O(N_t)$ 且聚类迭代上限固定时，标签模块的主导复杂度可写为 $O(N_t^2M)$。若同时计入关系对数据生成，则还需 $O(N_t^2D)$，其中 $D$ 为决策变量数。该模块不引入额外的昂贵目标函数评价，但其实际墙钟时间占比仍应在实验中报告。

### 3.7 方法边界与可验证主张

DG-PBI 的直接输出是当前种群上的监督分组。因此，仅凭本节定义可以主张：该方法构造了两种粒度的 PBI 信号，提供了显式预算调度，并在一定权重条件下具有可证明的两级排序性质。若实验只比较标签与后续真实结果之间的一致性，则最多支持预测关联；若比较完整算法的 IGD 或 HV，则可支持最终性能差异；只有在控制种群轨迹、候选池、归一化和回退路径的隔离消融中，才可以讨论双粒度融合相对于单一分支的因果优势。跨问题和跨目标数的泛化结论还需要独立问题族或留出设置支持。

此外，本方法依赖于当前种群能够提供有信息的方向和参考解几何。当非支配前沿退化、覆盖区域严重不均或目标空间方向关系失真时，种群派生方向和径向参考解可能同时受到影响。本文通过回退到均匀方向和限制类别比例来降低这一风险，但这些措施并不能保证在所有前沿形状上有效。

---

## III. English Draft

## 3 Dual-granularity PBI label construction

In expensive multi-objective optimization, surrogate models can learn pairwise relations between solutions instead of directly approximating every objective. The usefulness of such relation models, however, depends critically on how the supervision labels are constructed. A continuous scalar score preserves fine-grained ordering within the current population, but its scale and direction association may vary with the population state. A binary partition provides a clear decision boundary, but discards the ordering of solutions within the same class. We therefore develop a dual-granularity PBI (DG-PBI) labeling mechanism that combines a population-derived continuous PBI score with a reference-solution-based binary PBI partition.

DG-PBI does not introduce a new scalarizing function. Its continuous branch uses the conventional PBI distance form `[MOEA/D]`, whereas its binary branch follows the reference-solution-based partitioning principle used for relation learning in REMO `[REMO]`. Our design concerns how these two representations are scheduled into a unified supervision signal and how the number of reference solutions in the binary branch is adjusted to the number of objectives.

### 3.1 Problem formulation and overview

Let the current population be

$$
\mathcal{P}=\{\mathbf{x}_i,\mathbf{f}_i\}_{i=1}^{N_t},
$$

where $N_t$ is the current population size and $\mathbf{f}_i\in\mathbb{R}^{M}$ is the $M$-objective vector of solution $\mathbf{x}_i$. Given the current objective matrix $\mathbf{F}$, the number of consumed expensive function evaluations $FE$, and the maximum budget $B$, DG-PBI returns a fused score $h_i$ and a group label $c_i$ for each solution. Solutions are ranked in descending order of $h_i$; the top $\lceil r_gN_t\rceil$ solutions form the positive group and all remaining solutions form the negative group. We set $r_g=0.25$ in the present implementation.

DG-PBI consists of three steps. First, a direction set is generated from either uniform reference vectors or the current population, and a continuous PBI score is computed. Second, a small set of reference solutions is selected from the population to produce a reference-solution-based binary PBI partition. Third, the two signals are combined according to the progress of expensive evaluations. The two branches share the same population and both rely on PBI geometry. Hence, “dual granularity” refers to the resolution of their supervision signals rather than statistical or geometric independence.

### 3.2 Population-derived continuous PBI score

#### 3.2.1 Construction of the direction set

The continuous branch uses a direction set

$$
\mathcal{V}=\{\mathbf{v}_j\}_{j=1}^{N_v}.
$$

When $M\leq3$ or the current population contains fewer than 50 solutions, uniform reference vectors are used to avoid estimating population directions from insufficient samples. Otherwise, the first nondominated front $\mathcal{P}^{\mathrm{ND}}$ is identified. Uniform vectors are again used when the nondominated set is too small or its objective ranges are degenerate. In all other cases, $k$-means clustering is performed on the range-normalized nondominated objectives. The cluster centers are mapped back to the original objective scales and normalized to produce the population-derived direction set.

This construction allows the directions to adapt to the region currently covered by the population. It also inherits any coverage bias of the current nondominated set. In particular, when the number of directions approaches the number of nondominated solutions, some directions may become close to the samples from which they were generated. We therefore refer to them as population-derived directions and do not assume that they provide global front geometry independent of the current population.

#### 3.2.2 Continuous score

Each objective vector $\mathbf{f}_i$ is first associated with a direction $\mathbf{v}_{a(i)}$ by cosine similarity:

$$
a(i)=\arg\max_j
\frac{\mathbf{f}_i^{\mathsf T}\mathbf{v}_j}
{\|\mathbf{f}_i\|_2\|\mathbf{v}_j\|_2}.
$$

Let the population-wise ideal point be

$$
\mathbf{z}^{*}=\min_{i=1,\ldots,N_t}\mathbf{f}_i,
$$

where the minimum is taken component-wise. The parallel and perpendicular distances to the associated direction are

$$
d_{1,i}=
\frac{(\mathbf{f}_i-\mathbf{z}^{*})^{\mathsf T}\mathbf{v}_{a(i)}}
{\|\mathbf{v}_{a(i)}\|_2},
$$

and

$$
d_{2,i}=\left\|
(\mathbf{f}_i-\mathbf{z}^{*})-
d_{1,i}\frac{\mathbf{v}_{a(i)}}{\|\mathbf{v}_{a(i)}\|_2}
\right\|_2.
$$

The continuous PBI value and its monotone score are then defined as

$$
g_i^{\mathrm{con}}=d_{1,i}+\theta d_{2,i},
\qquad
s_i=\frac{1}{1+g_i^{\mathrm{con}}},
\tag{1}
$$

where $\theta=5$. A larger $s_i$ indicates a smaller PBI value along the currently associated direction. Unlike a hard class label, $s_i$ preserves a fine-grained ordering of the current population.

Equation (1) also makes the implementation convention explicit: direction association is performed using the original objective vectors, whereas the distances are computed after translation by the current ideal point. This convention is not translation invariant; changing the origin may alter both the direction association and the resulting ranking. All experiments use the same convention. A comparison with association after ideal-point translation should therefore be treated as a separate ablation rather than assumed to be equivalent.

### 3.3 Reference-solution-based binary PBI partition

The continuous score orders solutions over the population-derived directions, but relation classification also benefits from a coarse and interpretable boundary. We select $k_{\mathrm{eff}}$ reference solutions from the current population,

$$
\mathcal{R}=\{\mathbf{r}_j\}_{j=1}^{k_{\mathrm{eff}}}.
$$

Reference selection follows the radial-projection-based representative selection used by REMO, whose underlying selection principle was derived from RSEA `[RSEA, REMO]`. The selected solutions serve as dynamic reference representatives within the current population; they are not assumed to be samples of the true Pareto front.

Each $\mathbf{f}_i$ is first associated with a reference solution $\mathbf{r}_{b(i)}$ according to their angle in the original objective space. Define

$$
\mathbf{w}_{b(i)}=
\frac{\mathbf{r}_{b(i)}-\mathbf{z}^{*}}
{\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2}.
$$

The parallel and perpendicular distances relative to the associated reference solution are

$$
\hat d_{1,i}=(\mathbf{f}_i-\mathbf{z}^{*})^{\mathsf T}\mathbf{w}_{b(i)},
$$

and

$$
\hat d_{2,i}=\left\|
(\mathbf{f}_i-\mathbf{z}^{*})-\hat d_{1,i}\mathbf{w}_{b(i)}
\right\|_2.
$$

For a balancing parameter $\delta$, the normalized reference-solution-based PBI value is

$$
g_i^{\mathrm{bin}}(\delta)=
\frac{\hat d_{1,i}+\delta\hat d_{2,i}}
{\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2},
\tag{2}
$$

and the binary label is

$$
\ell_i(\delta)=
\mathbb{I}\left[g_i^{\mathrm{bin}}(\delta)\leq1\right].
\tag{3}
$$

Here, $\delta$ is a signed parameter used to regulate the class ratio, rather than a claim of a new PBI scalarization. The REMO paper adjusts its partition parameter toward an approximately balanced split. The repository baseline used in this study implements a tolerant variant: it searches $\delta\in[-20,20]$ by bisection and seeks a positive-label ratio within $[0.3,0.7]$. We retain this implementation to reduce extreme class imbalance in relation learning. Because the search interval and stopping tolerance are finite, the procedure seeks, but does not mathematically guarantee, a ratio in this interval for every population state.

The binary partition signal only records on which side of the boundary defined by the current reference solutions a solution lies. It therefore supplies a coarse partition and does not replace the within-class ordering preserved by the continuous score.

### 3.4 Budget-aware fusion of the two granularities

We define the expensive-evaluation progress as

$$
\rho=\min\left(1,\frac{FE}{B}\right),
$$

and assign the continuous branch the weight

$$
\alpha=1-\rho.
\tag{4}
$$

The fused score is

$$
h_i=\alpha s_i+(1-\alpha)\ell_i.
\tag{5}
$$

The final group label is obtained by ranking $h_i$:

$$
c_i=
\begin{cases}
1, & \operatorname{rank}_{\downarrow}(h_i)
\leq\lceil r_gN_t\rceil,\\
0, & \text{otherwise}.
\end{cases}
\tag{6}
$$

Equation (4) decreases the nominal contribution of the continuous score as expensive evaluations are consumed and increases the contribution of the binary partition accordingly. The intended behavior is to retain more within-group ordering early in the budget and gradually impose a coarser boundary later. This is a design hypothesis, not an assumption that either signal is necessarily more accurate at a particular stage. Its value must be examined separately through signal diagnostics on matched population states, controlled ablations, and final optimization performance.

#### Proposition 1: two-level ordering induced by the binary label

For any two solutions $i$ and $j$, suppose that $\ell_i=1$, $\ell_j=0$, and $s_i,s_j\in(0,1]$. If $\alpha\leq1/2$, then

$$
h_i>h_j.
$$

**Proof.** From Eq. (5),

$$
h_i=(1-\alpha)+\alpha s_i>1-\alpha,
$$

whereas

$$
h_j=\alpha s_j\leq\alpha.
$$

Since $1-\alpha\geq\alpha$ for $\alpha\leq1/2$, it follows that $h_i>h_j$. $\square$

Proposition 1 shows that once the binary branch receives at least half of the total weight, Eq. (5) induces an explicit two-level ordering: every binary-positive solution precedes every binary-negative solution, while the continuous score orders solutions within each binary class. More generally, let

$$
\Delta_{01}=
\max_{j:\ell_j=0}s_j-
\min_{i:\ell_i=1}s_i.
$$

Strict cross-class dominance is retained whenever

$$
\alpha<\frac{1}{1+\Delta_{01}}.
\tag{7}
$$

This condition also provides a measurable diagnostic. Recording $\Delta_{01}$, the realized $\alpha$, and the number of cross-class inversions reveals when the schedule actually changes the ordering structure.

The first realized weight is generally smaller than one because the initial population has already been evaluated when DG-PBI is first invoked:

$$
\alpha_{\mathrm{first}}=1-\frac{N_{\mathrm{init}}}{B}.
$$

For example, $N_{\mathrm{init}}=100$ and $B=300$ yield $\alpha_{\mathrm{first}}=2/3$. Both the nominal schedule and the range of weights actually visited by the algorithm should therefore be reported.

### 3.5 Objective-aware effective reference-solution set size

The number of effective reference solutions in the binary branch is

$$
k_{\mathrm{eff}}=
\min\left(N_p,\max\left(6,\left\lceil1.5M\right\rceil\right)\right),
\tag{8}
$$

where $N_p$ denotes the nominal population size. This rule increases the representative capacity with the number of objectives while retaining a lower bound of six reference solutions. When $N_p$ is not active as an upper bound, $M=3,5,10,20$ result in $k_{\mathrm{eff}}=6,8,15,30$, respectively.

In the current implementation, $k_{\mathrm{eff}}$ controls both the number of reference solutions and the resolution of the radial grid through

$$
n_{\mathrm{div}}=\left\lceil\sqrt{k_{\mathrm{eff}}}\right\rceil.
$$

Changing $k_{\mathrm{eff}}$ therefore changes both representative capacity and the spatial partition used during reference-solution selection. We regard Eq. (8) as an objective-aware coupled heuristic, rather than a theoretical claim that more reference solutions are always preferable. Its effect should be tested by separating fixed reference-solution counts, grid-only changes, and joint changes in controlled ablations.

### 3.6 Relation-pair construction and computational complexity

Once the final group labels $c_i$ have been obtained, ordered relation pairs are generated following the relation-modeling protocol of REMO `[REMO]`. For any two distinct solutions $(\mathbf{x}_i,\mathbf{x}_j)$, the pair belongs to one of four classes according to $(c_i,c_j)$: positive–positive, negative–negative, positive–negative, or negative–positive. Positive–positive and negative–negative pairs are randomly downsampled so that same-group relations remain comparable in scale to cross-group relations, and self-pairs are removed. The relation classifier thus learns categories induced by DG-PBI grouping rather than exact objective values.

Algorithm 1 summarizes the complete labeling procedure.

```text
Algorithm 1  Dual-granularity PBI labeling
Input: population P, evaluations FE, budget B, objectives M, positive ratio rg
Output: group labels c, fused scores h, reference solutions R

1: Construct uniform or population-derived directions V
2: Compute continuous PBI values gcon and set s = 1/(1+gcon)
3: Determine keff using Eq. (8)
4: Select keff reference solutions R from the current population
5: Search δ within a bounded interval and obtain binary labels l using Eqs. (2)–(3)
6: Set α = 1 - min(1, FE/B)
7: Compute h = αs + (1-α)l
8: Assign the top ceil(rg|P|) solutions ranked by h to the positive group
9: Return c, h, and R
```

With $N_v=O(N_t)$, direction association and continuous PBI evaluation require $O(N_tN_vM)$ operations. Population-direction clustering requires $O(RI\,N_{\mathrm{ND}}K_vM)$, where $R$, $I$, and $K_v$ are the number of replicates, the maximum number of iterations, and the number of clusters, respectively. The bounded search in the binary branch requires $O(B_{\delta}N_tk_{\mathrm{eff}}M)$, where $B_{\delta}$ is determined by the search interval and tolerance. Reference selection additionally includes nondominated sorting and radial-distance calculations. With $N_v=O(N_t)$, $k_{\mathrm{eff}}=O(N_t)$, and fixed clustering limits, the labeling stage is dominated by $O(N_t^2M)$. Generating relation-pair data further requires $O(N_t^2D)$, where $D$ is the number of decision variables. DG-PBI does not consume additional expensive objective evaluations; its wall-clock share should nevertheless be measured rather than assumed negligible.

### 3.7 Scope of the claims

DG-PBI directly produces supervision groups for the current population. The method definition therefore supports three immediate claims: two PBI signals with different resolutions are constructed, their contribution is explicitly scheduled over the expensive-evaluation budget, and the resulting score has a provable two-level ordering under the stated conditions. Agreement between these labels and future outcomes would establish predictive association only. Final IGD or HV comparisons can establish an algorithm-level performance difference. A causal advantage of dual-granularity fusion over either branch alone requires an isolated ablation that controls the population trajectory, candidate pool, normalization, and fallback paths. Claims of generalization further require held-out problem families or objective settings.

DG-PBI also relies on informative directions and reference-solution geometry in the current population. Degenerate fronts, severely uneven coverage, or distorted angular structure may affect both the population-derived directions and radial reference selection. Uniform-direction fallback and tolerant class balancing mitigate, but do not eliminate, this dependence.

---

## 四、定稿前需要补齐的证据与编辑项

1. **参考文献编号。** 将占位标签替换为正式编号，并核对 MOEA/D-PBI、RSEA 径向选择及 REMO 分组机制的原始出处。
2. **方法名称。** “DG-PBI”适合突出双粒度标签；若全文更强调分类器，可改为 “dual-granularity PBI classification”，但中英文必须统一。
3. **实际权重轨迹。** 从运行日志提取每次调用时的 $FE/B$ 和 $\alpha$，避免只画从 1 到 0 的理论直线。
4. **信号诊断。** 报告 $s_i$ 的分布、二值正例率、$\Delta_{01}$、跨类逆序数，以及连续/二值信号与稳定未来结果的关联。此类结果支持标签质量或预测关联，不直接等于最终优化优势。
5. **隔离消融。** 至少比较连续分支、二值分支、固定权重、反向调度和完整调度；若分析 $k_{\mathrm{eff}}$，应分离参考解数量与径向网格分辨率。
6. **最终性能。** 将 IGD/HV 的统计比较放入实验节，不在方法节提前写入“显著提升”“增强鲁棒性”等结论。
7. **坐标约定。** 若消融表明理想点平移后关联更稳定，应同步修改公式和代码；在此之前，正文保持对当前实现的忠实描述。
8. **运行开销。** 若需要声称开销较小，应报告标签模块占总运行时间的比例，而不仅给出渐近复杂度。
9. **更广泛的新颖性检索。** 当前表述只说明相对于所读五篇论文及当前 REMO 基线的设计差异；“首次提出”类主张需另行完成系统检索后再写。

## 五、建议的实验主张边界

| 证据                       | 可以支持                       | 不能单独支持                                         |
| -------------------------- | ------------------------------ | ---------------------------------------------------- |
| 标签与稳定未来结果的一致性 | 预测关联、排序可用性           | 融合的因果优势、最终 IGD/HV 提升                     |
| 单独运行连续/二值/融合版本 | 在相同实验协议下的性能差异     | 若候选池、归一化或回退路径不同，则不能归因于目标模块 |
| 完整算法的多问题统计比较   | 算法级最终性能                 | 双粒度机制是唯一原因                                 |
| 匹配种群状态的离线重放     | 同一输入下的标签差异及局部机制 | 独立搜索轨迹上的长期收益                             |
| 留出问题族或留出目标数     | 相应范围内的泛化证据           | 未覆盖问题类别上的普遍有效性                         |
