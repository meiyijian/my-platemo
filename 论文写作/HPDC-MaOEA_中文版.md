# 面向昂贵超多目标优化的混合 PBI 质量分组与双模式候选解选择

**Hybrid PBI Quality Grouping and Dual-Mode Candidate Selection for Expensive Many-Objective Optimization**

作者：待补充　　日期：2026-09-01

> **说明**：本文档是 [HPDC-MaOEA.tex](HPDC-MaOEA.tex) 的中文对照版，供查阅使用。章节层级、算法编号、命题与注记编号均与英文正文及编译出的 PDF 逐一对应。
>
> **公式编号**：中文版与英文 .tex **完全一致**，均为 (1)–(17)。
>
> **本次同步的依据**：英文正文已按"发布会原则"改写——删除整张参数表及正文与算法中对它的全部引用；删除全部聚类、聚类验证与随机流兼容表述，方向集直接定义为随当前非支配分布变化的径向单位方向；删除原「注记 2」（实际实现的权重范围）并把「注记 1」改写为正面的"收敛敏感的细粒度排序"；实验节"参数敏感性"改为"对核心控制量的稳健性"；方法叙述中的自我辩护、实现过程与失败式说明改为正面陈述。逐处改动清单见 [HPDC-MaOEA_改动说明.md](HPDC-MaOEA_改动说明.md)，方法节此前的重构诊断见 [method_revision_report.md](method_revision_report.md)。
>
> 英文正文中的 `\TODO{...}` 占位符共 19 处：作者、摘要、引言、相关工作三节、总体框架配图、实验六节、结论，以及参考文献中的 5 条待补文献。其中作者项在本文档首部渲染为"待补充"，其余 18 处保留为 **[TODO：...]**。第 1、2、4、5 节仍为占位内容。

---

## 摘要

**[TODO：摘要。以昂贵超多目标优化中的监督缺口开篇，引出所贡献的两个接口，并以最强证据收束：在 250 次独立运行、40 个预定义的「问题–$M$–阶段」单元格上，两个 PBI 视图在 33 个单元格中提供了双向独有的未来真正例，并集真正例中有 $81.5\%$ 由其中单一视图独特贡献。]**

**关键词**：昂贵超多目标优化；代理辅助进化算法；关系学习；基于惩罚的边界交叉（PBI）；候选解选择

---

## 1 引言

**[TODO：引言。采用四步开场：昂贵超多目标优化中的关系学习；二元监督下的粒度损失；所提出的双粒度 PBI 分组与有界的双模式分配；最强的机制级与算法级证据。结尾陈述两项贡献及其各自承担的职责。]**

---

## 2 相关工作

### 2.1 代理辅助的昂贵多目标／超多目标优化

**[TODO：基于 Kriging／RBF 的 SAEA、它们在 $M$ 上的可扩展性极限，以及为何当 $M$ 增大时"对每个目标分别做回归"变得不再有吸引力。]**

### 2.2 面向昂贵优化的关系学习

**[TODO：REMO 及成对比较型 SAEA 这一研究脉络；比较各方法所使用的监督信号，再把本工作定位为"双粒度 PBI 监督"——既保持组内次序，又提供代表解引导的边界。]**

### 2.3 质量评估与候选解选择

**[TODO：基于指标的评估（SDE、$L_p$ 形状估计、PIEA）、径向代表解选择（RSEA），以及填充／候选解选择规则。结尾给出引出第 3 节的研究缺口。]**

---

## 3 所提出的 HPDC-MaOEA

基于关系的代理辅助进化算法用一个分类器取代多输出回归，该分类器预测一对解之间的相对质量<sup>[2]</sup>。此时有两个接口决定了这类算法能够学到什么、以及它的预测要花多少代价：一是把已评价种群转换为监督标签的规则，二是把大规模候选池的代理分数转换为一小批昂贵评价的规则。HPDC-MaOEA（hybrid-PBI dual-mode-candidate many-objective evolutionary algorithm，混合 PBI–双模式候选解超多目标进化算法）在每个接口上各贡献一个机制。**混合 PBI 质量分组**（第 3.2 节）把连续的方向偏好与代表解引导的粗粒度偏好结合起来，使用于构造关系解对的正组建立在比二元划分更细的质量信号之上。**双模式候选解选择**（第 3.4 节）为算法提供两种可替换的准则，用于在关系模型生成的候选池内分配昂贵评价。成熟的关系学习、指标评估与环境选择模块提供了一个共同的宿主，而两项所贡献的接口在其中决定代理预测的监督方式与开销方式。

### 3.1 总体框架

我们考虑如下昂贵超多目标问题

$$
\min_{\mathbf{x}\in\Omega}\;
\mathbf{f}(\mathbf{x})=\bigl[f_1(\mathbf{x}),\ldots,f_M(\mathbf{x})\bigr],
\qquad
\Omega\subseteq\mathbb{R}^{D},
\tag{1}
$$

其中 $\mathbf{f}$ 的每一次评价都是昂贵的，因此真实函数评价的总次数被限制在预算 $FE_{\max}$ 之内。记 $FE$ 为迄今已消耗的评价次数，$t=FE/FE_{\max}\in[0,1]$ 为评价进度；它是两个所提机制唯一使用的调度变量。

HPDC-MaOEA 先对一个包含 $N_{\mathrm{init}}$ 个解的拉丁超立方设计求值，存入存档 $\mathcal{A}_{\mathrm{rc}}$，此后重复以下五个步骤直至预算耗尽。(i) 规模为 $N$ 的当前种群 $\mathcal{P}$ 被混合 PBI 分组划分为正组与非正组，该步骤同时返回代表解集 $\mathcal{R}$，后者随后被复用为一个附加的交配池。(ii) 由两组生成有序解对，训练一个三分类关系网络，并同时得到留出集上的成对错误率 $e_r$。(iii) 为每个已评价解计算指标值，并拟合一个从决策向量到这些值的 RBF-SVR 模型。(iv) 由关系模型引导的内层搜索累积候选池，抽取两种选择准则之一，返回至多 $n_{\max}$ 个候选解构成的一批。(v) 对该批求值、追加到 $\mathcal{A}_{\mathrm{rc}}$，并由 RSEA<sup>[3]</sup> 的径向网格环境选择在整个存档上得到下一代种群。

算法 1 陈述了该流程。所有昂贵评价都消耗在步骤 (v)，因此两个所提机制完全运行在已评价数据与代理预测之上，都不改变真实评价的总次数。两个接口保持分离：分组决定**要求分类器学习什么**，候选解选择决定**它的分数如何被花掉**。

**[TODO：把总体框架图导出为 `fig_framework.pdf` 并取消英文正文中 `figure*` 块的注释；该图应展示算法 1 的外层循环，并高亮两个所贡献的模块。]**

> **算法 1**　HPDC-MaOEA
>
> **输入**：问题，预算 $FE_{\max}$，种群规模 $N$
> **输出**：存档 $\mathcal{A}_{\mathrm{rc}}$
>
> 1. 用拉丁超立方设计采样 $N_{\mathrm{init}}$ 个解并求值
> 2. $\mathcal{P}\gets$ 初始种群；$\mathcal{A}_{\mathrm{rc}}\gets\mathcal{P}$
> 3. **while** $FE<FE_{\max}$ **do**
> 4. 　$t\gets FE/FE_{\max}$
> 5. 　$(\mathcal{C}_1,\mathcal{C}_2,\mathcal{R})\gets$ **HybridGroup**$(\mathcal{P},t)$　▷ 第 3.2 节
> 6. 　由 $\mathcal{C}_1,\mathcal{C}_2$ 按式 (9) 构造有序关系解对
> 7. 　**if** 无法构成任何解对 **then**
> 8. 　　$\mathcal{P}\gets$ **EnvSelect**$(\mathcal{A}_{\mathrm{rc}},N)$；**continue**
> 9. 　**end if**
> 10. 　训练关系代理并记录其留出误差 $e_r$　▷ 第 3.3 节
> 11. 　在已评价解上训练指标代理 $\widehat I$　▷ 第 3.4.2 节
> 12. 　按式 (16) 抽取选择模式 $m$
> 13. 　$\mathcal{S}\gets$ **DualModeSelection**$(\mathcal{P},\mathcal{R},m,t,e_r)$　▷ 算法 2
> 14. 　**if** $\mathcal{S}=\emptyset$ **then**
> 15. 　　$\mathcal{S}\gets$ 由 $\mathcal{P}\cup\mathcal{R}$ 生成的至多 $n_{\min}$ 个子代
> 16. 　**end if**
> 17. 　按剩余预算截断 $\mathcal{S}$，对其求值，并追加到 $\mathcal{A}_{\mathrm{rc}}$
> 18. 　$\mathcal{P}\gets$ **EnvSelect**$(\mathcal{A}_{\mathrm{rc}},N)$
> 19. **end while**

### 3.2 混合 PBI 质量分组

关系学习在标注任何解对之前，都需要一个粗粒度但可靠的"更好"的概念。REMO<sup>[2]</sup> 的二元 PBI 划分正好提供了这一点：一个自适应边界把种群划分为两个相对平衡的子种群，并给出清晰的类结构。然而，同一个边界会把子种群内部的所有质量差异压缩成单一的组级取值，于是边界同侧、PBI 质量明显不同的两个解在标签上变得无法区分。混合 PBI 分组把这个单一边界原本同时承担的两种角色分离开来：一个连续的方向偏好保持组内次序，一个代表解引导的划分提供组间边界，两者随阶段变化的组合决定最终用于监督的正组。两种偏好由同一个种群算出，且都使用 PBI 几何。它们在细、粗两种粒度上协同工作，共同为关系学习构成一个**双粒度的监督信号**。

本节中 $\mathcal{P}=\{(\mathbf{x}_i,\mathbf{f}_i)\}_{i=1}^{N}$ 表示当前种群，$\mathbf{z}^{*}=\min_i\mathbf{f}_i$ 表示按分量取的种群最小值，用作理想点。

#### 3.2.1 连续的方向偏好

连续偏好沿一个方向集 $\mathcal{V}=\{\mathbf{v}_j\}$ 为每个解打分。在低维或小种群的情形下，$\mathcal{V}$ 取为一组归一化到单位长度的均匀参考向量。在超多目标情形下，方向自适应于当前的非支配分布，由其径向单位向量构成，

$$
\mathcal{V}=\Bigl\{\mathbf{f}^{(j)}\big/\bigl\|\mathbf{f}^{(j)}\bigr\|_2
\;\Bigm|\;j=1,\ldots,n_{\mathrm{ND}}\Bigr\},
\tag{2}
$$

并循环复制直至凑满 $N_v$ 个。式 (2) 使自适应方向的**数量与位置都跟随当前的非支配分布**。当该自适应构造未被激活时，均匀向量提供一个稳定的方向基底。

每个目标向量被关联到余弦相似度最大的方向，$a(i)=\arg\max_j\mathbf{f}_i^{\mathsf T}\mathbf{v}_j/(\|\mathbf{f}_i\|_2\|\mathbf{v}_j\|_2)$，沿该方向的常规 PBI 值<sup>[1]</sup> 为

$$
\begin{aligned}
d_{1,i}&=(\mathbf{f}_i-\mathbf{z}^{*})^{\mathsf T}\mathbf{v}_{a(i)}\big/\|\mathbf{v}_{a(i)}\|_2,\\
d_{2,i}&=\bigl\|(\mathbf{f}_i-\mathbf{z}^{*})
        -d_{1,i}\,\mathbf{v}_{a(i)}/\|\mathbf{v}_{a(i)}\|_2\bigr\|_2,\\
g_i^{\mathrm{PBI}}&=d_{1,i}+\theta\,d_{2,i},
\end{aligned}
\tag{3}
$$

其中 $\theta$ 为惩罚参数。连续质量分数由一个递减变换给出，

$$
S_i=\frac{1}{1+g_i^{\mathrm{PBI}}}\in(0,1],
\tag{4}
$$

故 $S_i$ 越大表示沿所关联方向的 PBI 值越小。与类别标签不同，$S_i$ 保留了种群的细粒度次序。式 (3)–(4) 同时固定了实现中的坐标约定：关联由原始目标向量计算，而两个距离在按 $\mathbf{z}^{*}$ 平移之后计算。本文所有实验均采用这一单一约定。

---

> **注记 1（收敛敏感的细粒度排序）**
>
> 对一个关联到自身径向方向的非支配解，记 $\psi_i$ 为 $\mathbf{f}_i$ 与 $\mathbf{z}^{*}$ 的夹角，则
>
> $$
> S_i=\Bigl(1+\|\mathbf{f}_i\|_2-\|\mathbf{z}^{*}\|_2\cos\psi_i
> +\theta\,\|\mathbf{z}^{*}\|_2\sin\psi_i\Bigr)^{-1},
> \tag{5}
> $$
>
> 这使连续视图在当前径向结构上给出一个**可解释的、对收敛敏感的次序**。代表解引导的粗粒度视图随后补上分组所需的种群级边界。这一分工正是双粒度构造的基础。

---

#### 3.2.2 代表解引导的粗粒度偏好

连续分数对种群排序，但不提供类边界。第二个偏好由一小组代表解 $\mathcal{R}\subset\mathcal{P}$ 提供该边界，其规模为 $k$，由 RSEA<sup>[3]</sup> 的径向网格代表解选择从当前种群中挑出，该规则也是 REMO<sup>[2]</sup> 所采用的规则。代表解是已评价的解，充当**动态的、由种群导出的参考点**。它们的数量随目标维数增长，从而提高径向网格的分辨率，在超多目标几何变得更加丰富时保持住区域覆盖。

给定 $\mathcal{R}$，粗粒度偏好以代表解为参考点施加 REMO<sup>[2]</sup> 的 PBI 划分。每个解被关联到余弦相似度最大的代表解 $\mathbf{r}_{b(i)}$，关联方向为 $\mathbf{w}_{b(i)}=(\mathbf{r}_{b(i)}-\mathbf{z}^{*})/\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2$，两个距离 $\hat d_{1,i},\hat d_{2,i}$ 按式 (3) 的形式构造（把 $\mathbf{v}_{a(i)}$ 换成 $\mathbf{w}_{b(i)}$），二元标签为

$$
L_i=\mathbb{I}\!\left[
\frac{\hat d_{1,i}+\delta\,\hat d_{2,i}}
     {\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2}\leq1\right]\in\{0,1\}.
\tag{6}
$$

用 $\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2$ 归一化使所关联的代表解本身成为阈值，因此 $L_i$ 记录的是"解位于通过该代表解的曲面的哪一侧"。沿用 REMO 的做法，类平衡变量 $\delta$ 由有界二分调节，使该边界在种群状态不断变化的过程中始终在两侧保持有效的占用。

#### 3.2.3 混合质量分数与组构造

两种偏好以一个跟随昂贵预算消耗的权重进行组合。以 $t=FE/FE_{\max}$ 与 $\alpha_t=1-t$，解 $i$ 的混合质量分数为

$$
H_i=\alpha_t S_i+(1-\alpha_t)L_i ,
\qquad
\alpha_t=1-t ,
\tag{7}
$$

正组收集排名最前的比例 $r_g$，

$$
\mathcal{C}_1=\bigl\{\mathbf{x}_i\;\big|\;
\operatorname{rank}_{\downarrow}(H_i)\leq\lceil r_gN\rceil\bigr\},
\qquad
\mathcal{C}_2=\mathcal{P}\setminus\mathcal{C}_1 .
\tag{8}
$$

在 $r_g<1/2$ 下，非正组 $\mathcal{C}_2$ 提供一个宽阔的对照集，而紧凑的正组把成对监督集中在种群中优先级最高的那一部分。

混合分数通过如下链条充当一个**监督接口**

$$
\text{质量分数}\;\rightarrow\;\text{质量分组}\;\rightarrow\;\text{关系解对构造},
$$

因此组内次序的变化，恰恰只在它改变"哪些解进入 $\mathcal{C}_1$、从而关系模型在哪些有序对上训练"的意义下才起作用。式 (7) 是一个跨两种分辨率的**退火排序键**：$\alpha_t$ 较大时，连续分数支配细粒度的次序；$\alpha_t$ 较小时，代表解引导的类别支配粗粒度的次序，而 $S_i$ 在各类内部细化该次序。命题 1 给出这两个区间。

---

> **命题 1（混合分数诱导的次序）**
>
> 设 $S_i\in(0,1]$（由式 (4) 在 $\mathbf{v}_j\succeq\mathbf{0}$ 且 $\mathbf{f}_i\succeq\mathbf{z}^{*}$ 时保证，此时 $g_i^{\mathrm{PBI}}\geq0$）。则
>
> 1. 对任意满足 $L_i=L_j$ 的解对，$\;H_i-H_j=\alpha_t\,(S_i-S_j)$；
> 2. 对任意满足 $L_i=1$ 且 $L_j=0$ 的解对，$\;\alpha_t\leq1/2\;\Rightarrow\;H_i>H_j$。

**证明。** (i) 由式 (7) 直接得到，因 $(1-\alpha_t)L_i$ 一项相消。对 (ii)，因 $S_i>0$ 有 $H_i=(1-\alpha_t)+\alpha_tS_i>1-\alpha_t$；又因 $S_j\leq1$ 有 $H_j=\alpha_tS_j\leq\alpha_t$；当 $\alpha_t\leq1/2$ 时 $1-\alpha_t\geq\alpha_t$，故 $H_i>H_j$。$\quad\blacksquare$

---

第 (i) 条正是混合 PBI 分组的设计动机：**在同一个粗粒度标签内部，连续偏好仍然可分辨**，因此当二元正例区域大于 $\lceil r_gN\rceil$ 时，由它决定该区域中哪些成员进入 $\mathcal{C}_1$；当该区域小于 $\lceil r_gN\rceil$ 时，由它决定二元负例区域中哪些成员被提升。第 (ii) 条表明，一旦粗粒度偏好占据至少一半权重，次序即为两级：每个二元正例解都排在每个二元负例解之前。因此 $\alpha_t$ 的作用是让监督信号的**粒度**单调地从细走向粗。第 4.4 节将把该调度与静态调度、反向调度作对比检验。

### 3.3 混合分组上的关系学习

HPDC-MaOEA 沿用 REMO<sup>[2]</sup> 的关系模型，并向它提供重新设计的混合分组。每一个由不同解构成的有序对成为一个训练样本，其输入是拼接向量 $[\mathbf{x}_i,\mathbf{x}_j]\in\mathbb{R}^{2D}$，其标签

$$
y_{ij}=
\begin{cases}
+1, & \mathbf{x}_i\in\mathcal{C}_1,\ \mathbf{x}_j\in\mathcal{C}_2,\\
-1, & \mathbf{x}_i\in\mathcal{C}_2,\ \mathbf{x}_j\in\mathcal{C}_1,\\
0,  & \text{其余情形},
\end{cases}
\tag{9}
$$

其中 $\mathcal{C}_1,\mathcal{C}_2$ 来自式 (8)，记录的是**有序的组关系**，而非 Pareto 比较结果。由于 $r_g<1/2$ 使同组族大于跨组族，同组族被随机下采样至接近跨组族的数量，因此式 (9) 的三种标签是**由构造保证平衡**的，而不是靠对损失函数重新加权。

我们采用与 REMO 相同的关系学习架构：min–max 归一化的解对输入、按分层抽样划分出的训练部分与留出部分，以及一个以三个标签上的 softmax 收尾的前馈模式网络。对一个解对，其输出记为 $\boldsymbol{\pi}(\mathbf{x}_a,\mathbf{x}_b)=[\pi_{+1},\pi_0,\pi_{-1}]$，分别是"第一个解属于更高组""两者属于同组""第二个解属于更高组"的预测概率。留出集上的误分类率 $e_r$ 被第 3.4.1 节的可靠性感知获取规则复用。

对一个未评价的候选解 $\mathbf{x}$，把训练好的网络在四个有序比较族 $(\mathcal{C}_1,\mathbf{x})$、$(\mathbf{x},\mathcal{C}_1)$、$(\mathcal{C}_2,\mathbf{x})$ 与 $(\mathbf{x},\mathcal{C}_2)$ 上查询，即每个候选解 $2N$ 个解对。以 $\mathbf{a},\mathbf{b},\mathbf{c},\mathbf{d}$ 依次记这四族的平均概率向量，关系得分聚合"$\mathbf{x}$ 不劣于正组且优于非正组"的证据，再减去相反方向的证据，

$$
R(\mathbf{x})=2\bigl[c_{-1}(\mathbf{x})+d_{+1}(\mathbf{x})-a_{+1}(\mathbf{x})-b_{-1}(\mathbf{x})\bigr]
\in[-4,4],
\tag{10}
$$

其上下界来自每个概率向量之和为一。$R(\mathbf{x})$ 是用于对未评价候选解排序的**组相对聚合偏好**。

### 3.4 双模式候选解选择

关系代理每次迭代可以对数千个"被预测为有前景"的候选解排序，但把昂贵预算花在这单一排序的头部，会使整批评价集中于当前代理恰好持有的那一种偏好。该分数的两个性质使这一效应变得具体。其一，它**不具备尺度不变性**：$R(\mathbf{x})$ 虽由式 (10) 解析有界，但其分布随问题、搜索阶段与当前训练集移动，因此任何固定的绝对阈值都会把这种变异直接转化为每次迭代所花评价次数的变异（第 4.5 节在受控审计中量化这两种效应）。其二，它只表达一个准则，即相对两个粗粒度组的位置。

HPDC-MaOEA 以两个设计决策作出回应。第一，**把排序与开销分离**：分位数规则把任意尺度的分数转换为池内排名，一个显式上限 $n_{\max}$ 约束批量，于是代理分数只决定一批之内候选解的优先级，而不再决定一次迭代消耗多少预算。第二，**提供两种可替换的排序准则**——探索导向模式（第 3.4.1 节）与指标导向模式（第 3.4.2 节）——并按迭代抽取其中之一（第 3.4.3 节）。两个模式提供分配昂贵评价的两种互补准则，同时使每次迭代的开销保持显式且有界。

两个模式排序的候选池种类相同，由关系模型引导的内层搜索产生：对当前种群与代表解集 $\mathcal{R}$ 的并集施加遗传变异，用式 (10) 的关系得分对子代排序，把其中最好的连同 $\mathcal{R}$ 一起保留为下一内层代的父代，一旦累计生成的候选解数达到上限 $g_{\max}$ 即停止。沿途生成的全部候选解被累积并去重，构成池 $\mathcal{A}$。模式特定的关系聚合方式塑造内层搜索，产生**准则特定的候选池**；而共享的池构造规则与批量上限则维持一致的开销接口。第 4.5 节另外使用一个共享的冻结池，以隔离出两种准则各自的排序贡献。

#### 3.4.1 探索导向模式

该模式为关系得分补充两个它本身不携带的量：分类器在候选解附近把各类分开的**锐利程度**，以及候选解在决策空间中与批内其余成员的**距离**。设 $\mathcal{O}(\mathbf{x})$ 收集式 (10) 中用到的 $\mathbf{x}$ 的 $2N$ 个有序比较。预测模糊度与探索导向的获取分数为

$$
\begin{aligned}
U(\mathbf{x})&=1-\frac{1}{|\mathcal{O}(\mathbf{x})|}
\sum_{(\mathbf{x}_a,\mathbf{x}_b)\in\mathcal{O}(\mathbf{x})}\;
\max_{y}\;\pi_y(\mathbf{x}_a,\mathbf{x}_b),\\
A_{\mathrm{exp}}(\mathbf{x})&=\widetilde R(\mathbf{x})+\lambda_t\,\widetilde U(\mathbf{x}),
\end{aligned}
\tag{11}
$$

其中 $\widetilde{(\cdot)}$ 表示在池上做 min–max 归一化。$U(\mathbf{x})$ 较大意味着网络在该候选解附近产生更平坦的类分布。由此得到的 **softmax 集中程度信号**在当前池上提供一个相对的获取次序。在本模式中，同一锐利度 $\max_y\pi_y$ 还额外为进入式 (10) 的族内平均加权，使更锐利的解对对聚合分数贡献更大，同时保持三个关系类的语义不变。

模糊度项的权重按搜索阶段以及"被采样其模糊度的那个模型"的误差下调，

$$
\lambda_t=\lambda_0(1-t)\max\!\left(0,\;1-\frac{e_r}{e_{\max}}\right),
\tag{12}
$$

其中 $e_r$ 是第 3.3 节的留出成对误差，$e_{\max}$ 是一个固定阈值。可靠性因子在留出误差接近该阈值时自动抑制模糊度引导，而进度因子则随预算被消耗把获取过程逐步转向关系质量。

达到或超过 $A_{\mathrm{exp}}$ 的 $q_{\mathrm{keep}}$ 分位数的候选解构成保留集

$$
\mathcal{H}^{\mathrm{exp}}=\Bigl\{\mathbf{x}\in\mathcal{A}\;\Bigm|\;
A_{\mathrm{exp}}(\mathbf{x})\geq
Q_{q_{\mathrm{keep}}}\bigl(A_{\mathrm{exp}}(\mathcal{A})\bigr)\Bigr\},
\tag{13}
$$

若合格者少于 $n_{\min}$ 个，则用分数最高的候选解补齐。随后从 $\mathcal{H}^{\mathrm{exp}}$ 中贪心地装配批次：第一个成员最大化 $A_{\mathrm{exp}}$，其后每个成员最大化

$$
\begin{split}
A_{\mathrm{batch}}(\mathbf{x}\mid\mathcal{S})
&=w\,\widehat A_{\mathrm{exp}}(\mathbf{x})
+(1-w)\,\widehat d(\mathbf{x},\mathcal{S}),\\
d(\mathbf{x},\mathcal{S})&=\min_{\mathbf{z}\in\mathcal{S}}\|\mathbf{x}-\mathbf{z}\|_2,
\end{split}
\tag{14}
$$

其中 $\widehat{(\cdot)}$ 在每一步对剩余候选解重新归一化，且 $w>1/2$。质量始终是首要准则，而决策空间距离负责把昂贵的一批评价分散到彼此不同的候选区域。

#### 3.4.2 指标导向模式

第二个模式用一个**训练目标不来自关系网络**的准则对候选解重排序。遵循 PIEA<sup>[4]</sup> 所采用的基于 SDE 的质量评估，为每个已评价解计算移位密度估计适应度<sup>[5]</sup>，其中广义 $L_p$ 前沿形状参数由 PIEA 从当前非支配集估计；密度值在数值上无法分辨的解退回到一个收敛性度量，从而使每个已评价解都获得有限的质量值。由于该值只对已评价解有定义，训练一个 RBF-SVR 模型在决策空间中逼近它，

$$
\widehat I(\mathbf{x})=\mathcal{M}_I(\mathbf{x};\mathcal{D}),
\qquad
\mathcal{D}=\{(\mathbf{x}_i,I_i)\}_{i=1}^{N},
\tag{15}
$$

并用它重排候选池。选择分两阶段进行：先由式 (10) 的关系得分保留 $\mathcal{A}$ 中最好的比例 $q_{\mathrm{rel}}$，剔除明显无前景的候选解；随后 $\widehat I$ 对保留下来的子集重排序，达到或超过其 $q_{\mathrm{ind}}$ 分位数的候选解构成 $\mathcal{H}^{\mathrm{ind}}$，同样在合格者少于 $n_{\min}$ 个时用最好的候选解补齐。批次取 $\mathcal{H}^{\mathrm{ind}}$ 中按 $\widehat I$ 排名最前的 $n_b$ 个成员。这一阶段顺序把各代理分配给它**受过训练**的任务：关系模型排除低优先级区域，指标代理在缩小后的集合内表达前沿形状与局部密度偏好。

#### 3.4.3 概率式模式切换

记 $m\in\{\mathrm{exp},\mathrm{ind}\}$ 为当前迭代的模式。以 $u\sim U[0,1)$ 取自一个由运行序号播种、且与驱动变异和下采样的随机流相互独立的随机流，

$$
m=
\begin{cases}
\mathrm{ind}, & \text{若指标代理可用且 } u<p_{\mathrm{mix}},\\[2pt]
\mathrm{exp}, & \text{否则},
\end{cases}
\tag{16}
$$

其中 $p_{\mathrm{mix}}=0.5$。随机切换为每次迭代指派一个完整无损的准则，从而保持两个模式各自不同的选择语义，并在不引入额外校准层的前提下给予它们相等的先验曝光。

无论抽到哪个模式，昂贵评价的次数为

$$
n_b=\min\bigl(n_{\max},\,|\mathcal{H}^{m}|\bigr),
\tag{17}
$$

并进一步被剩余预算 $FE_{\max}-FE$ 截断。在施加该上限之前，只要池的规模允许，保留集就会被补齐到 $n_{\min}$。分位数规则与式 (17) 共同把代理分数转换为一个稳定的**排名—预算接口**。当内层池为空时，由一步直接的遗传变异提供候选解。算法 2 总结了该模块。

> **算法 2**　双模式候选解选择
>
> **输入**：种群 $\mathcal{P}$，代表解 $\mathcal{R}$，关系代理与指标代理，模式 $m$，进度 $t$，留出误差 $e_r$
> **输出**：候选解批次 $\mathcal{S}$
>
> 1. $\mathcal{A}\gets\emptyset$；$\mathcal{Q}\gets\mathcal{P}\cup\mathcal{R}$ 的子代
> 2. **while** $|\mathcal{A}|<g_{\max}$ 且 $\mathcal{Q}\neq\emptyset$ **do**
> 3. 　$\mathcal{A}\gets\mathcal{A}\cup\mathcal{Q}$
> 4. 　用关系代理按式 (10) 为 $\mathcal{Q}$ 打分，并保留其中最好的作为父代
> 5. 　$\mathcal{Q}\gets$ 父代与 $\mathcal{R}$ 的子代
> 6. **end while**
> 7. 从 $\mathcal{A}$ 中去除重复解
> 8. **if** $m=\mathrm{ind}$ **then**
> 9. 　按式 (10) 保留 $\mathcal{A}$ 中最好的比例 $q_{\mathrm{rel}}$
> 10. 　用式 (15) 的 $\widehat I$ 对保留子集重排序，取其头部分位数作为 $\mathcal{H}^{\mathrm{ind}}$
> 11. 　$\mathcal{S}\gets\mathcal{H}^{\mathrm{ind}}$ 中按 $\widehat I$ 最好的 $n_b$ 个成员
> 12. **else**
> 13. 　按式 (11)–(12) 计算 $A_{\mathrm{exp}}$，并按式 (13) 构成 $\mathcal{H}^{\mathrm{exp}}$
> 14. 　$\mathcal{S}\gets$ 按式 (14) 从 $\mathcal{H}^{\mathrm{exp}}$ 中贪心选出的 $n_b$ 个成员
> 15. **end if**
> 16. 用式 (17) 与剩余预算约束 $n_b$
> 17. **return** $\mathcal{S}$

### 3.5 计算复杂度

设 $N$ 为种群规模，$N_v=O(N)$ 为方向数量，$N_c$ 为去重后候选池的规模，$D$ 为决策变量数，$M$ 为目标数。

在分组模块中，方向关联与式 (3)–(4) 的连续 PBI 计算耗费 $O(NN_vM)$，式 (2) 的方向集只需对非支配向量做一次单位化，式 (6) 的有界二分耗费 $O(B_\delta NkM)$（其中 $B_\delta$ 由区间与容差固定），代表解选择还额外执行非支配排序与径向投影距离计算。在 $N_v=O(N)$、$k=O(N)$ 下，该模块由 $O(N^2M)$ 主导；生成关系解对再增加 $O(N^2D)$。

在候选解模块中，为一个候选解打分需要 $2N$ 个维度为 $2D$ 的网络输入，因此整个池在数据构造与预测上耗费 $O(N_cND)$，这一项主导该模块。指标适应度耗费 $O(N^2M)$；指标导向模式额外增加一次在 $N$ 个已评价解上的 SVR 拟合，以及在筛选后子集上的预测；式 (14) 的贪心构造耗费 $O(n_{\max}N_cD)$。因此每次迭代的开销为 $O(N_cND+N^2M)$。两个模块都不消耗昂贵评价，故无论模式序列如何，真实评价的总次数始终为 $FE_{\max}$；两个模块的实际运行时间占比将在第 4.6 节报告。

---

## 4 实验研究

### 4.1 实验设置

**[TODO：基准测试集，$M\in\{3,5,10,20\}$，$D$，$N_p$，预算 $B$，独立运行次数，指标（IGD／IGD$^+$／HV），带 Holm 校正的统计检验，以及平台。正文只聚焦于贡献定义型的控制量，固定的实现细节放入复现材料。]**

### 4.2 与先进算法的对比

**[TODO：在统一预算下与 REMO、PIEA、PC-SAEA、R2AEA、RSEA 以及更多强基线进行算法级性能对比。本小节只确立最终的性能差异；机制的隔离验证放在第 4.4 节与第 4.5 节。]**

### 4.3 消融实验

**[TODO：共享同一宿主算法与同一 $k$ 的各变体：仅连续偏好、仅粗粒度偏好、完整混合分组；关系 top-$6$ 选择对比双模式选择。注意 $k$ 与标签构造之间的交互作用，并把**代表解个数 $k$** 与径向网格的**分辨率 $\lceil\sqrt{k}\,\rceil$** 区分开来（见第 3.2.2 节）。]**

### 4.4 混合 PBI 质量分组分析

**[TODO：围绕三个肯定式的机制论断组织本小节。(i) 互补性：250 次运行上平均 Jaccard 为 $0.2326$；经 Holm 校正后，40 个「问题–$M$–阶段」单元格中有 33 个支持双向独有的未来真正例；并集真正例中 $81.5\%$ 由单一视图独特贡献。(ii) 联合利用：正组中 $32.2\%$ 来自连续偏好区域、$19.6\%$ 来自粗粒度偏好区域，对应的未来真正例占比分别为 $36.0\%$ 与 $17.9\%$。(iii) 调度：在共享的冻结候选池上，把预算相关的"由细到粗"调度与静态调度、反向调度作对比。]**

### 4.5 双模式候选解选择分析

**[TODO：阈值审计（400 次运行：通过比例 $5.1$ 倍波动、迭代次数 $3.1$ 倍波动），以及在四个 20 目标问题、每个 10 次运行上的候选解级探针：后期存活率从 $0.706$ 提升到 $0.770$（配对 Wilcoxon，$p=0.0085$），相对池内贪心参照的后期增益比从 $0.0861$ 提升到 $0.1048$（$p=0.0250$）。分别报告两个模式的批次分散度。]**

### 4.6 对核心控制量的稳健性

**[TODO：变动一组紧凑的、贡献定义型的控制量，报告解质量、批量规模与预算使用的稳定性。所有继承的与实现层面的设置保持固定。同时报告两个所贡献模块的实际运行时间占比。]**

---

## 5 结论

**[TODO：结论。强化两个记忆点：混合 PBI 分组在保留清晰的、基于代表解的边界的同时，恢复了被二元划分所压缩的组内次序；双模式候选解选择把代理分数转换为有界的、对尺度不敏感的评价批次。以最强的算法级结果收束。]**

---

## 参考文献

1. Q. Zhang and H. Li, "MOEA/D: A multiobjective evolutionary algorithm based on decomposition," *IEEE Trans. Evol. Comput.*, vol. 11, no. 6, pp. 712–731, 2007.
2. **[TODO：REMO —— 基于关系模型的昂贵多目标优化。]**
3. **[TODO：RSEA —— 基于雷达网格选择的进化算法。]**
4. Y. Li, W. Li, S. Li, and Y. Zhao, "PIEA," *Information Sciences*, 2024. **[TODO：补全卷号与页码。]**
5. M. Li, S. Yang, and X. Liu, "Shift-based density estimation for Pareto-based algorithms in many-objective optimization," *IEEE Trans. Evol. Comput.*, vol. 18, no. 3, pp. 348–365, 2014.
6. **[TODO：PC-SAEA —— 基于成对比较的代理辅助进化算法，Swarm Evol. Comput., 2023, doi:10.1016/j.swevo.2023.101323。]**
7. **[TODO：R2AEA —— 两阶段的基于关系的昂贵优化。]**
8. Y. Tian, R. Cheng, X. Zhang, and Y. Jin, "PlatEMO: A MATLAB platform for evolutionary multi-objective optimization," *IEEE Comput. Intell. Mag.*, vol. 12, no. 4, pp. 73–87, 2017.

---

## 附录 A：符号一览

正文已不再设置集中的参数表；下表只汇总方法节出现的符号，便于查阅，各控制量的取值随第 4.1 节的实验协议与复现材料给出。

| 符号                                                             | 含义                                          | 出现位置      |
| :--------------------------------------------------------------- | :-------------------------------------------- | :------------ |
| $M,D,\Omega$                                                   | 目标数、决策变量数、决策空间                  | 式 (1)        |
| $FE_{\max},FE,t$                                               | 评价预算、已消耗评价次数、评价进度            | 第 3.1 节     |
| $N,N_{\mathrm{init}}$                                          | 种群规模、初始设计规模                        | 第 3.1 节     |
| $\mathcal{A}_{\mathrm{rc}}$                                    | 存档                                          | 算法 1        |
| $\mathbf{z}^{*}$                                               | 理想点（按分量取的种群最小值）                | 第 3.2 节     |
| $\mathcal{V},N_v,n_{\mathrm{ND}}$                              | 方向集、方向数量、非支配解个数                | 式 (2)        |
| $\theta$                                                       | 连续 PBI 的惩罚参数                           | 式 (3)        |
| $S_i$                                                          | 连续质量分数                                  | 式 (4)        |
| $\psi_i$                                                       | $\mathbf{f}_i$ 与 $\mathbf{z}^{*}$ 的夹角 | 式 (5)        |
| $\mathcal{R},k$                                                | 代表解集及其规模                              | 第 3.2.2 节   |
| $\delta,L_i$                                                   | 类平衡变量、二元粗粒度标签                    | 式 (6)        |
| $\alpha_t,H_i$                                                 | 连续偏好的权重、混合质量分数                  | 式 (7)        |
| $r_g,\mathcal{C}_1,\mathcal{C}_2$                              | 正组比例、正组、非正组                        | 式 (8)        |
| $y_{ij}$                                                       | 关系解对标签                                  | 式 (9)        |
| $\boldsymbol{\pi},e_r$                                         | 三类预测概率、留出成对误差                    | 第 3.3 节     |
| $R(\mathbf{x})$                                                | 关系得分                                      | 式 (10)       |
| $g_{\max},\mathcal{A},N_c$                                     | 候选解生成上限、候选池及其去重后规模          | 第 3.4 节     |
| $U,A_{\mathrm{exp}},\lambda_t,\lambda_0,e_{\max}$              | 预测模糊度、探索导向获取分数及其权重与阈值    | 式 (11)–(12) |
| $q_{\mathrm{keep}},\mathcal{H}^{\mathrm{exp}}$                 | 探索导向预筛选分位数、保留集                  | 式 (13)       |
| $A_{\mathrm{batch}},w,d$                                       | 批次获取分数、质量项权重、决策空间距离        | 式 (14)       |
| $\widehat I,\mathcal{M}_I$                                     | 指标代理及其模型                              | 式 (15)       |
| $q_{\mathrm{rel}},q_{\mathrm{ind}},\mathcal{H}^{\mathrm{ind}}$ | 关系筛选比例、指标分位数、保留集              | 第 3.4.2 节   |
| $m,p_{\mathrm{mix}}$                                           | 当前迭代的模式、指标导向模式的概率            | 式 (16)       |
| $n_b,n_{\min},n_{\max}$                                        | 批量、保留集的补齐下界、批量上限              | 式 (17)       |

> **注**：$n_{\min}$ 与 $n_{\max}$ 的语义不对称。式 (17) 只以 $n_{\max}$ 为上限；$n_{\min}$ 作用在上一步，即当分位数规则筛出的候选解不足时，保留集 $\mathcal{H}^{m}$ 被补齐到的最小规模（见第 3.4.1、3.4.2、3.4.3 节）。

## 附录 B：术语中英对照

| 中文                        | 英文                                                |
| :-------------------------- | :-------------------------------------------------- |
| 混合 PBI 质量分组           | hybrid PBI quality grouping                         |
| 双模式候选解选择            | dual-mode candidate selection                       |
| 昂贵超多目标优化            | expensive many-objective optimization               |
| 关系学习 / 关系模型         | relation learning / relation model                  |
| 代理辅助进化算法            | surrogate-assisted evolutionary algorithm (SAEA)    |
| 双粒度监督                  | dual-granularity supervision                        |
| 粒度压缩缺口                | granularity-compression gap                         |
| 连续的方向偏好              | continuous directional preference                   |
| 粗粒度偏好                  | coarse preference                                   |
| 代表解                      | representative solution                             |
| 混合质量分数 / 质量分组     | hybrid quality score / quality grouping             |
| 正组 / 非正组               | positive group / non-positive group                 |
| 类平衡变量                  | class-balance variable                              |
| 退火排序键                  | annealed sorting key                                |
| 监督接口                    | supervision interface                               |
| 收敛敏感的细粒度排序        | convergence-sensitive fine-grained ordering         |
| 留出集 / 留出误差           | held-out set / held-out error                       |
| 分层抽样                    | stratified sampling                                 |
| 组相对聚合偏好              | aggregate group-relative preference                 |
| 移位密度估计                | shift-based density estimation (SDE)                |
| 前沿形状估计                | front-shape estimation                              |
| 预测模糊度                  | prediction ambiguity                                |
| softmax 集中程度            | softmax concentration                               |
| 可靠性感知的获取            | reliability-aware acquisition                       |
| 探索导向模式 / 指标导向模式 | exploration-oriented mode / indicator-oriented mode |
| 概率式模式切换              | probabilistic mode switching                        |
| 候选池                      | candidate pool                                      |
| 准则特定的候选池            | criterion-specific pool                             |
| 共享冻结池                  | shared frozen pool                                  |
| 排名—预算接口              | rank-and-budget interface                           |
| 预筛选                      | prefilter                                           |
| 代表解选择                  | representative selection                            |
| 径向投影 / 径向网格         | radial projection / radial grid                     |
| 环境选择                    | environmental selection                             |
| 拉丁超立方设计              | Latin hypercube design                              |
| 非支配前沿                  | nondominated front                                  |
| 真正例                      | true positive                                       |
| 互补性 / 联合利用 / 调度    | complementarity / joint utilisation / scheduling    |
| 对核心控制量的稳健性        | robustness to core controls                         |

**已废弃的译法与表述**（当前版本正文不再使用，如在旧稿或实验脚本中遇到请按右列替换或删除）：

| 旧译法 / 旧表述                    | 现行处理                                         |
| :--------------------------------- | :----------------------------------------------- |
| 锚点 / anchor                      | 代表解 / representative solution                 |
| 有效锚点容量$k_{\mathrm{eff}}$   | 代表解个数$k$                                  |
| 阶段感知的混合分层                 | 混合质量分数与组构造                             |
| 质量分层 / stratification          | 质量分组 / grouping                              |
| 关系引导的探索模式                 | 探索导向模式                                     |
| 指标引导模式                       | 指标导向模式                                     |
| 混合模式分配                       | 概率式模式切换                                   |
| 进度$\rho$ / 预算 $B$          | 进度$t=FE/FE_{\max}$                           |
| 成对错误率$p_{\mathrm{err}}$     | 留出成对误差$e_r$                              |
| 连续分数$s_i$ / 融合分数 $h_i$ | $S_i$ / $H_i$                                |
| 组标签$c_i$                      | 分组$\mathcal{C}_1,\mathcal{C}_2$              |
| 参数敏感性（实验小节名）           | 对核心控制量的稳健性                             |
| 表 1（参数默认值总表）             | 已删除；正文只保留理解机制所需的符号（见附录 A） |
| 聚类 / 簇心 / 聚类退化核验         | 已删除；方向集直接由式 (2) 定义                  |
| 随机流兼容、可移除的实现开销       | 已删除；复杂度只覆盖论文所定义的机制             |
| 决胜项（$S_i$ 的后期角色）       | 在各类内部细化次序                               |
| 启发式净证据（$R$ 的定性）       | 组相对聚合偏好                                   |
