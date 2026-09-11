# 面向昂贵超多目标优化的 PBI 辅助质量分类与准则多样化候选解选择

**PBI-Assisted Quality Classification and Criterion-Diversified Infill Selection for Expensive Many-Objective Optimization**

作者：**[TODO：作者列表]**

单位：某大学某系，某街，某市，某省，某国，邮编 000000

> 本文档是 [HPDC-MaOEA.tex](HPDC-MaOEA.tex) 的中文对照版，对应 2026-09-09 的英文稿。章节、公式编号、算法、图、命题、参考文献与 TODO 均与英文稿逐项对应。当前英文主稿尚无实验章节，故本文档亦无第 4 章实验；相应内容仍保存在 `HPDC-MaOEA_with_experiments_2026-09-07.tex` 中。
>
> 排版说明（英文稿）：使用 Elsevier `elsarticle` 的 `5p` 双栏终稿版式，宽浮动体用带星号环境跨双栏；若需双倍行距单栏审稿版，把类选项换成 `[preprint,review,12pt]`。

---

## 摘要

**[TODO：采用"挑战—贡献"结构。指出两个具体缺口：<mark>仅用二元分组时，构造正组时缺少标签内的排序信息</mark>【2026-09-10 复核：循环论证，REMO 没有正组选择这一步，见文末复核说明】；固定的关系得分阈值规则会让得分分布决定有多少候选解被评价。引入 PACDIS，及其 PBI 辅助质量分类（PAQC）与准则多样化候选解选择（CDIS），分别针对训练组构造与昂贵评价选择两个环节。以在所测试的超多目标设置下、经核验的最强算法级 IGD 对比结果领起结果部分。随后给出一条关于组构成或候选批次效用的简洁机制发现。详细的重叠统计量与逐组件检验留在实验节。]**

**关键词**：昂贵超多目标优化；代理辅助进化算法；关系学习；基于惩罚的边界交叉（PBI）；候选解选择

---

## 1 引言

**[TODO：采用四步开场：昂贵超多目标优化中的关系学习；<mark>构造正组时标签内排序信息的丢失</mark>【2026-09-10 复核：同摘要，循环论证】，以及固定阈值下批量规模对关系得分分布的依赖；所提出的两个机制；算法级性能，随后是解释组构造与候选解选择的证据。把两个机制表述为同一算法中互补的设计角色。不要以选择重叠统计量开篇，也不要暗示关系网络学习到了组内排序。]**

本文的贡献包括两个方面。第一，PBI 辅助质量分类（PAQC）把连续 PBI 分数与 REMO 使用的、基于代表解的二元标签结合起来。<mark>在构造正训练组时，该连续分数能够区分被赋予同一二元标签的解。</mark>【2026-09-10 复核：仅对 $\mathcal{C}_1$ 成员资格成立，不进入监督信号】第二，准则多样化候选解选择（CDIS）降低昂贵评价对单一关系得分的依赖。它保留关系模型引导的候选解生成过程，同时由基于指标的重排序与探索导向选择为最终评价批次提供两种可替换的准则。

---

## 2 相关工作

### 2.1 代理辅助的昂贵多目标／超多目标优化

**[TODO：基于 Kriging／RBF 的 SAEA、它们在 $M$ 上的可扩展性极限，以及为何当 $M$ 增大时"对每个目标分别做回归"变得不再有吸引力。]**

### 2.2 面向昂贵优化的关系学习

**[TODO：梳理 REMO 及成对比较型 SAEA 这一研究脉络；比较各方法构造训练组或成对标签的方式，然后将本工作定位为一种混合分组信号，即把连续质量排序与基于代表解的二元组标签结合起来。]**

### 2.3 质量评估与候选解选择

**[TODO：基于指标的评估（SDE、$L_p$ 形状估计、PIEA）、径向代表解选择（RSEA），以及填充／候选解选择规则。结尾给出引出所提方法的研究缺口。]**

---

## 3 所提出的 PACDIS

基于关系的代理辅助进化算法用一个分类器代替多输出回归，由该分类器预测一对解之间的相对质量<sup>[2]</sup>。此后有两个接口决定这类算法能学到什么、以及它的预测要付出多大代价：一个是把已评价种群转换为监督标签的规则，另一个是把大规模候选池的代理得分转换为一小批昂贵评价的规则。我们提出 PACDIS，一种代理辅助超多目标进化算法，在每个接口上贡献一个机制。**PBI 辅助质量分类**（PAQC）把连续 PBI 分数与基于代表解的二元标签结合起来。<mark>在构造正训练组时，该分数能够区分被赋予同一二元标签的解。</mark>【2026-09-10 复核：同上】**准则多样化候选解选择**（CDIS）保留关系模型引导的候选解生成过程，但使用基于指标的重排序或探索导向选择来确定最终的昂贵评价批次。已有的关系学习、指标评估与环境选择模块构成宿主算法；两个所提机制改变的是其训练组的形成方式与代理得分的使用方式。

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

PACDIS 先对一个包含 $N_{\mathrm{init}}$ 个解的拉丁超立方设计求值，存入存档 $\mathcal{A}_{\mathrm{rc}}$，此后重复以下五个步骤直至预算耗尽。(i) 当前种群 $\mathcal{P}$ 被 PAQC 划分为正组与非正组，该步骤同时返回代表解集 $\mathcal{R}$，后者随后被复用为一个附加的交配池。(ii) 由两组生成有序解对，训练一个三分类关系网络，并同时得到留出集上的成对错误率 $e_r$。(iii) 为 $\mathcal{P}$ 中每个解计算指标值，并拟合一个从决策向量到这些值的 RBF-SVR 模型。(iv) 抽取两种选择模式之一，由关系模型引导的内层搜索在该模式下累积候选解，并返回至多 $n_{\max}$ 个候选解构成的一批。(v) 对该批求值、追加到 $\mathcal{A}_{\mathrm{rc}}$，并由 RSEA<sup>[3]</sup> 的径向网格环境选择在整个存档上得到下一代种群。

算法 1 陈述了该流程，其分组与候选解选择步骤分别在算法 2 与算法 3 中展开。初始设计满足 $2\leq N_{\mathrm{init}}\leq FE_{\max}$，$N$ 为环境选择的目标种群规模。关系代理 $\mathcal{M}_R$ 包含预测所需的组参照与输入归一化信息，$\mathcal{M}_I$ 表示指标代理（在可用时）。三个过程共享同一组控制量。初始化之后的所有昂贵评价都消耗在步骤 (v)，因此两个所提机制完全运行在已评价数据与代理预测之上，都不改变真实评价的总次数。两个接口保持分离：分组决定**要求分类器学习什么**，候选解选择决定**它的分数如何被花掉**。

图 1 展示了评价循环，并把 CDIS 展开为其关系引导的候选解搜索与依准则而定的填充分支。

> **图 1**　PACDIS 流程图。左侧为昂贵评价循环，其中 PAQC 构造训练组、CDIS 选择填充批次。右侧（虚线连接）为 CDIS 的展开：在关系引导搜索之前抽取模式；$c$ 统计已生成的候选解数量，$g_{\max}$ 约束其累积。当指标代理可用时，以概率 $p_{\mathrm{mix}}=0.5$ 抽到指标模式，否则使用探索模式。所抽到的模式决定最终的筛选与选择准则。分位数筛选包含批次选择前的保留集补齐；批次进一步受剩余评价预算约束。详细的保护性规则见算法 1 与算法 3。（图件源文件：`figures/fig_framework.pdf`）

> **算法 1**　PACDIS
>
> **输入**：问题 $(\Omega,\mathbf{f})$，预算 $FE_{\max}$，初始规模 $N_{\mathrm{init}}$，种群规模 $N$
> **输出**：已评价解的存档 $\mathcal{A}_{\mathrm{rc}}$
>
> 1. $\mathcal{P}\gets$ 用拉丁超立方设计采样的 $N_{\mathrm{init}}$ 个解
> 2. 对 $\mathcal{P}$ 求值；$FE\gets N_{\mathrm{init}}$
> 3. $\mathcal{A}_{\mathrm{rc}}\gets\mathcal{P}$
> 4. **while** $FE<FE_{\max}$ **do**
> 5. 　$t\gets FE/FE_{\max}$
> 6. 　$(\mathcal{C}_1,\mathcal{C}_2,\mathcal{R})\gets$ **PBIQualityClassification**$(\mathcal{P},t)$
> 7. 　由 $\mathcal{C}_1,\mathcal{C}_2$ 按式 (8) 构造有序关系解对
> 8. 　训练 $\mathcal{M}_R$ 并得到其留出误差 $e_r$
> 9. 　在 $\mathcal{P}$ 上训练 $\mathcal{M}_I$；若不可用则置 $\mathcal{M}_I\gets\emptyset$
> 10. 　按式 (15) 抽取选择模式 $m$
> 11. 　$\mathcal{S}\gets$ **DiversifiedInfillSelection**$(\mathcal{P},\mathcal{R},\mathcal{M}_R,\mathcal{M}_I,m,t,e_r)$
> 12. 　**if** $\mathcal{S}=\emptyset$ **then**
> 13. 　　$\mathcal{S}\gets$ 由 $\mathcal{P}\cup\mathcal{R}$ 生成的至多 $n_{\min}$ 个子代
> 14. 　**end if**
> 15. 　保留 $\mathcal{S}$ 中前 $\min(|\mathcal{S}|,FE_{\max}-FE)$ 个候选解
> 16. 　对 $\mathcal{S}$ 求值并追加到 $\mathcal{A}_{\mathrm{rc}}$
> 17. 　$FE\gets FE+|\mathcal{S}|$
> 18. 　$\mathcal{P}\gets$ **EnvSelect**$(\mathcal{A}_{\mathrm{rc}},N)$
> 19. **end while**
> 20. **return** $\mathcal{A}_{\mathrm{rc}}$

### 3.2 PBI 辅助质量分类（PAQC）

关系学习首先需要把已评价种群划分为可用于生成成对标签的组。REMO<sup>[2]</sup> 的二元 PBI 划分提供了清晰的组边界，但具有相同标签的所有解都获得同一个组级取值，因此无法区分位于边界同侧但 PBI 质量不同的两个解。PAQC 将连续 PBI 质量分数与基于代表解的二元标签相结合。连续分数为共享同一二元标签的解提供额外的排序信息，二元标签则保留清晰的种群级划分。两种信号随阶段变化的组合决定用于构造关系解对的正组。

图 2 给出这两种信号及其在分组中所起作用的几何示意。

> **图 2**　基于代表解的分类与 PAQC 的概念示意。黑色射线连接理想点 $Z$ 与代表解，橙色点划线段表示局部分类阈值。蓝色虚线射线表示由非支配解 $P_1$ 与 $P_2$ 构造出的方向。在 (a) 中，"Good group"与"Bad group"表示二元标签 $L_i=1$ 与 $L_i=0$；在 (b) 中，二者分别表示 $\mathcal{C}_1$ 与 $\mathcal{C}_2$。蓝色圆环突出显示 $A$ 与 $B$ 的重新归组。PF 仅作为外部参照。图中给出的是选定的若干解与示意性边界，而非完整种群或经数值求解的实例。几何呈现方式改编自 REMO<sup>[2]</sup>。（图件源文件：`figures/paqc_reference_edit/paqc_geometry_v5_editable.pdf`）

在 PAQC 中，$\mathcal{P}=\{(\mathbf{x}_i,\mathbf{f}_i)\}_{i=1}^{N}$ 表示当前种群，$N=|\mathcal{P}|$，$\mathbf{z}^{*}=\min_i\mathbf{f}_i$ 表示按分量取的种群最小值，用作理想点。

#### 3.2.1 连续 PBI 质量评估

过程 **ContinuousPBIQualityAssessment** 依据沿方向集 $\mathcal{V}=\{\mathbf{v}_j\}$ 测得的 PBI 值评价每个解。在低维或小种群情形下，$\mathcal{V}$ 由归一化到单位长度的均匀参考向量组成。在超多目标情形下，方向自适应于当前的非支配分布，并由其径向单位向量构成，

$$
\mathcal{V}=\Bigl\{\mathbf{f}^{(j)}\big/\bigl\|\mathbf{f}^{(j)}\bigr\|_2
\;\Bigm|\;j=1,\ldots,n_{\mathrm{ND}}\Bigr\},
\tag{2}
$$

这些向量直接作为自适应方向集使用。式 (2) 使方向的数量与位置都跟随当前的非支配分布。当自适应构造未被启用或满足其回退条件时，改用均匀向量。

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

其中 $\theta$ 为惩罚参数。连续质量分数是如下递减变换

$$
S_i=\frac{1}{1+g_i^{\mathrm{PBI}}}\in(0,1],
\tag{4}
$$

因此 $S_i$ 越大，表示沿其关联方向的 PBI 值越小。<mark>与类别标签不同，$S_i$ 可以区分被赋予同一二元标签的解。</mark>【2026-09-10 复核：作为标量陈述为真，但易被读成"网络拿到了这个区分"】

式 (3)–(4) 同时固定了实现中的坐标约定：方向关联由原始目标向量计算，而两个距离在按 $\mathbf{z}^{*}$ 平移之后计算。本文全部实验都使用这一唯一约定。

#### 3.2.2 基于代表解的分类

连续分数提供细粒度的排序，而由 **RepresentativeBasedClassification** 产生的二元标签则补充一条相对代表解的质量边界。该边界由一个包含 $k$ 个代表解的小集合 $\mathcal{R}\subset\mathcal{P}$ 导出；这些代表解由 RSEA<sup>[3]</sup> 的径向网格代表解选择从当前种群中选出，这也是 REMO<sup>[2]</sup> 所采用的规则。代表解本身是已评价解，充当动态的、由种群导出的参考点。它们的数量随目标维数增加，以便在超多目标几何变得更丰富时提供更细的区域覆盖。

给定 $\mathcal{R}$，二元组标签以代表解作为参考点，应用 REMO<sup>[2]</sup> 的 PBI 划分。每个解被关联到余弦相似度最大的代表解 $\mathbf{r}_{b(i)}$，其关联方向为 $\mathbf{w}_{b(i)}=(\mathbf{r}_{b(i)}-\mathbf{z}^{*})/\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2$；两个距离 $\hat d_{1,i},\hat d_{2,i}$ 按式 (3) 的方式构造，只需把 $\mathbf{v}_{a(i)}$ 换成 $\mathbf{w}_{b(i)}$；二元标签为

$$
L_i=\mathbb{I}\!\left[
\frac{\hat d_{1,i}+\delta\,\hat d_{2,i}}
     {\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2}\leq1\right]\in\{0,1\}.
\tag{5}
$$

用 $\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2$ 归一化，使所关联的代表解自身成为阈值，因此 $L_i$ 记录的是"解位于穿过该代表解的曲面的哪一侧"。沿用 REMO 的做法，类别平衡变量 $\delta$ 通过有界二分调整，使该边界在种群状态变化时仍能在两侧保持有用的占据比例。

#### 3.2.3 混合分数与正组构造

两种信号由一个跟随昂贵预算消耗的权重组合起来。以 $t=FE/FE_{\max}$ 与 $\alpha_t=1-t$，解 $i$ 的混合质量分数为

$$
H_i=\alpha_t S_i+(1-\alpha_t)L_i ,
\qquad
\alpha_t=1-t ,
\tag{6}
$$

正组收集种群中排名最高的比例 $r_g$，

$$
\mathcal{C}_1=\bigl\{\mathbf{x}_i\;\big|\;
\operatorname{rank}_{\downarrow}(H_i)\leq\lceil r_gN\rceil\bigr\},
\qquad
\mathcal{C}_2=\mathcal{P}\setminus\mathcal{C}_1 .
\tag{7}
$$

在 $r_g<1/2$ 的设置下，非正组 $\mathcal{C}_2$ 提供一个宽泛的对照集，而紧凑的正组把成对监督集中在种群中优先级最高的那一部分上。

图 2 展示了两种 PBI 信号各自不同的作用。在面板 (a) 中，代表解 $R_1$ 与 $R_2$ 定义用于得到 $L_i$ 的局部阈值。在面板 (b) 中，非支配解 $P_1$ 与 $P_2$ 通过式 (2) 提供自适应方向 $\mathbf{v}_1$ 与 $\mathbf{v}_2$；这些方向决定 $S_i$，而不是直接指派组归属。把 $A$ 与 $B$ 重新归入正组、把 $C$ 归入其补集，示意性地刻画了额外的方向性信息如何通过式 (6)–(7) 改变选择优先级。这种"二元负例解与二元正例解之间次序发生反转"的情形要求 $t<1/2$ 且连续分数之差足够大，其条件由命题 1 刻画。因此，PAQC 修改的是用于形成组的排序，而不是用一条新的几何边界替换基于代表解的边界。

该示意图用两个目标来可视化超多目标方法的自适应分支；低维运行改用均匀方向。取 $O=Z$ 使式 (2) 的径向构造可以显示为穿过 $P_1$ 与 $P_2$ 的射线。这两个解被画在 PF 上仅为便于说明，而实现中使用的是当前非支配集，并不需要真实 PF。图中它们被显示为属于正组，这是一种示意性的指派，并非由非支配性所保证的结论。

算法 2 总结了该构造过程。混合分数的并列由种群顺序打破，使正组恰好包含 $\lceil r_gN\rceil$ 个成员。

> **算法 2**　PBIQualityClassification（PAQC）
>
> **输入**：已评价种群 $\mathcal{P}$，进度 $t$
> **输出**：组 $\mathcal{C}_1,\mathcal{C}_2$ 与代表解 $\mathcal{R}$
>
> 1. $N\gets|\mathcal{P}|$；$\mathbf{z}^{*}\gets\min_i\mathbf{f}_i$
> 2. 构造参考方向集 $\mathcal{V}$
> 3. 按余弦相似度把每个解关联到其最近的方向
> 4. 按式 (3)–(4) 为所有解计算 $S_i$
> 5. 用径向网格选择选出 $k$ 个代表解 $\mathcal{R}$
> 6. 用有界二分调整 $\delta$，并按式 (5) 得到 $L_i$
> 7. $\alpha_t\gets1-t$；对所有 $i$ 计算 $H_i\gets\alpha_tS_i+(1-\alpha_t)L_i$
> 8. $\mathcal{C}_1\gets$ 按 $H_i$ 得分最高的 $\lceil r_gN\rceil$ 个解
> 9. $\mathcal{C}_2\gets\mathcal{P}\setminus\mathcal{C}_1$
> 10. **return** $(\mathcal{C}_1,\mathcal{C}_2,\mathcal{R})$

混合分数通过如下链条把质量评估与关系学习连接起来

$$
\text{质量分数}\;\rightarrow\;\text{正组构造}\;\rightarrow\;\text{关系解对构造},
$$

因此排序的改变之所以重要，是因为它改变了哪些解进入 $\mathcal{C}_1$，从而改变了关系模型被训练在哪些有序解对上。随预算变化的加权把细粒度质量排序与基于代表解的组优先级连接起来。随着评价预算被消耗，二元标签获得越来越大的权重，<mark>而在每个满足 $FE<FE_{\max}$ 的训练步上，$S_i$ 都在细化标签内部的次序。</mark>【2026-09-10 复核：这个"细化"只用到 $\mathcal{C}_1/\mathcal{C}_2$ 切分为止，切分后即被丢弃】命题 1 刻画了由此得到的排序。

---

> **命题 1（混合分数所诱导的排序）**
>
> 设式 (4) 保证 $S_i\in(0,1]$，这在 $\mathbf{v}_j\succeq\mathbf{0}$ 且 $\mathbf{f}_i\succeq\mathbf{z}^{*}$（从而 $g_i^{\mathrm{PBI}}\geq0$）时成立。则
>
> (i) 对任意满足 $L_i=L_j$ 的解对，$H_i-H_j=\alpha_t\,(S_i-S_j)$；
>
> (ii) 对任意满足 $L_i=1$ 且 $L_j=0$ 的解对，$\alpha_t\leq1/2\;\Rightarrow\;H_i>H_j$。

**证明.** (i) 由式 (6) 直接得到，因为 $(1-\alpha_t)L_i$ 一项相消。对 (ii)：若 $\alpha_t=0$，则 $H_i=1>0=H_j$。对 $0<\alpha_t\leq1/2$，由 $S_i>0$ 得 $H_i=(1-\alpha_t)+\alpha_tS_i>1-\alpha_t$，而由 $S_j\leq1$ 得 $H_j=\alpha_tS_j\leq\alpha_t$；又 $\alpha_t\leq1/2$ 时有 $1-\alpha_t\geq\alpha_t$，故 $H_i>H_j$。∎

---

<mark>第 (i) 条解释了引入连续分数的原因：当 $\alpha_t>0$ 时，构造正组时具有同一二元标签的解仍可相互区分。</mark>【2026-09-10 复核："构造正组时"是承重限定语，任何此类表述都必须紧贴这个限定】第 (ii) 条给了该调度一个具体解释：当 $t<1/2$ 时，连续分数可以跨越二元边界影响次序；当 $1/2\leq t<1$ 时，二元正例解取得优先，<mark>连续分数则在各标签内部细化次序。</mark>这一过渡把细粒度排序与清晰的组优先级随预算消耗结合起来。

### 3.3 PAQC 分组上的关系学习

PACDIS 沿用 REMO<sup>[2]</sup> 的关系模型，并向它提供由 PAQC 构造的分组。每一个由不同解构成的有序对成为一个训练样本，其输入是拼接向量 $[\mathbf{x}_i,\mathbf{x}_j]\in\mathbb{R}^{2D}$，其标签

$$
y_{ij}=
\begin{cases}
+1, & \mathbf{x}_i\in\mathcal{C}_1,\ \mathbf{x}_j\in\mathcal{C}_2,\\
-1, & \mathbf{x}_i\in\mathcal{C}_2,\ \mathbf{x}_j\in\mathcal{C}_1,\\
0,  & \text{其余情形},
\end{cases}
\tag{8}
$$

其中 $\mathcal{C}_1,\mathcal{C}_2$ 来自式 (7)，记录的是**有序的组关系**，而非 Pareto 比较结果。由于 $r_g<1/2$ 使同组族大于跨组族，同组族被随机下采样至接近跨组族的数量，因此式 (8) 的三种标签是**由构造保证平衡**的，而不是靠对损失函数重新加权。

我们采用与 REMO 相同的关系学习架构：min–max 归一化的解对输入、类别均衡的训练集与留出集划分，以及一个以三个标签上的 softmax 为输出的前馈模式网络。对一个解对，其输出记为 $\boldsymbol{\pi}(\mathbf{x}_a,\mathbf{x}_b)=[\pi_{+1},\pi_0,\pi_{-1}]$，分别表示"第一个解属于更高组""两者属于同组"和"第二个解属于更高组"的预测概率。留出集上的误分类率 $e_r$ 被面向探索型填充的可靠性感知获取规则复用。

对一个未评价的候选解 $\mathbf{x}$，把训练好的网络在四个有序比较族 $(\mathcal{C}_1,\mathbf{x})$、$(\mathbf{x},\mathcal{C}_1)$、$(\mathcal{C}_2,\mathbf{x})$ 与 $(\mathbf{x},\mathcal{C}_2)$ 上查询，即每个候选解 $2N$ 个解对。以 $\mathbf{a},\mathbf{b},\mathbf{c},\mathbf{d}$ 依次记这四族的族内平均概率向量，关系得分聚合"$\mathbf{x}$ 不劣于正组且优于非正组"的证据，再减去相反方向的证据，

$$
R(\mathbf{x})=2\bigl[c_{-1}(\mathbf{x})+d_{+1}(\mathbf{x})-a_{+1}(\mathbf{x})-b_{-1}(\mathbf{x})\bigr]
\in[-4,4],
\tag{9}
$$

其上下界来自每个概率向量之和为一。$R(\mathbf{x})$ 是用于对未评价候选解排序的**组相对聚合偏好**。

### 3.4 准则多样化候选解选择（CDIS）

关系代理每次迭代可以对数千个预测为有前景的候选解排序，但若把昂贵预算用于这单一排序的头部，整批评价就会集中在当前代理恰好持有的那一种偏好上。具体而言，通过固定阈值的候选解数量取决于 $R(\mathbf{x})$ 的分布，而该分布会随问题、搜索阶段和训练集变化。因此，即使阈值不变，由此得到的批量规模、以及单次迭代消耗的评价次数，仍可能发生变化。此外，$R(\mathbf{x})$ 只表示候选解相对于两个训练组的预测位置。

PACDIS 由此采用两个设计决定。第一，把排序与开销控制分离：分位数规则相对当前得分分布定义阈值，显式上限 $n_{\max}$ 则约束评价批次的规模。在该上限之内，分数决定候选解的优先级；保留集规模与剩余预算决定可行的批量规模。第二，提供两种可替换的排序准则——探索导向模式与指标导向模式——并在每次迭代抽取其中之一。两个模式为昂贵评价的分配提供两种备选准则，同时使每次迭代的开销保持显式且有界。

两个模式对同一类候选池进行排序，该候选池由关系模型引导的内层搜索产生：对当前种群与代表解集 $\mathcal{R}$ 的并集施加遗传变异，用式 (9) 的关系得分对子代排序，将其中至多 $|\mathcal{R}|$ 个较优者与 $\mathcal{R}$ 一同保留为下一内层代的父代，并在累计生成的候选解数量达到上限 $g_{\max}$ 时停止。过程中产生的全部候选解经累积和去重后构成池 $\mathcal{A}$。模式特定的关系聚合方式塑造内层搜索，并产生准则特定的候选池；共享的池构造规则与批量上限则维持一致的开销接口。

#### 3.4.1 基于探索的填充

过程 **ExplorationBasedInfill** 为关系得分补充两个其本身不包含的量：分类器在候选解附近区分类别的明确程度，以及候选解在决策空间中与批次其他成员的距离。设 $\mathcal{O}(\mathbf{x})$ 收集式 (9) 中涉及 $\mathbf{x}$ 的 $2N$ 个有序比较。预测模糊度与探索导向获取分数为

$$
\begin{aligned}
U(\mathbf{x})&=1-\frac{1}{|\mathcal{O}(\mathbf{x})|}
\sum_{(\mathbf{x}_a,\mathbf{x}_b)\in\mathcal{O}(\mathbf{x})}\;
\max_{y}\;\pi_y(\mathbf{x}_a,\mathbf{x}_b),\\
A_{\mathrm{exp}}(\mathbf{x})&=\widetilde R(\mathbf{x})+\lambda_t\,\widetilde U(\mathbf{x}),
\end{aligned}
\tag{10}
$$

其中 $\widetilde{(\cdot)}$ 表示在池上进行 min–max 归一化。$U(\mathbf{x})$ 较大意味着网络在该候选解附近产生更平坦的类别分布。由此得到的 softmax 集中程度信号在当前池上提供相对的获取顺序。在本模式中，同一明确度 $\max_y\pi_y$ 还用于对式 (9) 中各比较族的均值加权，使预测更明确的解对对聚合分数贡献更大，同时保持三种关系类别的语义不变。

模糊度项的权重按搜索阶段以及"被采样其模糊度的那个模型"的误差下调，

$$
\lambda_t=\lambda_0(1-t)\max\!\left(0,\;1-\frac{e_r}{e_{\max}}\right),
\tag{11}
$$

其中 $e_r$ 是关系模型的留出成对误差，$e_{\max}$ 是一个固定阈值。可靠性因子在留出误差接近该阈值时自动抑制模糊度引导，而进度因子则随预算被消耗把获取过程逐步转向关系质量。

达到或超过 $A_{\mathrm{exp}}$ 的 $q_{\mathrm{keep}}$ 分位数的候选解构成保留集

$$
\mathcal{H}^{\mathrm{exp}}=\Bigl\{\mathbf{x}\in\mathcal{A}\;\Bigm|\;
A_{\mathrm{exp}}(\mathbf{x})\geq
Q_{q_{\mathrm{keep}}}\bigl(A_{\mathrm{exp}}(\mathcal{A})\bigr)\Bigr\},
\tag{12}
$$

若合格者少于 $n_{\min}$ 个，则用分数最高的候选解补齐。随后从 $\mathcal{H}^{\mathrm{exp}}$ 中贪心地装配批次：第一个成员最大化 $A_{\mathrm{exp}}$，其后每个成员最大化

$$
\begin{split}
A_{\mathrm{batch}}(\mathbf{x}\mid\mathcal{S})
&=w\,\widehat A_{\mathrm{exp}}(\mathbf{x})
+(1-w)\,\widehat d(\mathbf{x},\mathcal{S}),\\
d(\mathbf{x},\mathcal{S})&=\min_{\mathbf{z}\in\mathcal{S}}\|\mathbf{x}-\mathbf{z}\|_2,
\end{split}
\tag{13}
$$

其中 $\widehat{(\cdot)}$ 在每一步对剩余候选解重新归一化，且 $w>1/2$。质量始终是首要准则，而决策空间距离负责把昂贵的一批评价分散到彼此不同的候选区域。

#### 3.4.2 基于指标的填充

过程 **IndicatorBasedInfill** 保留关系模型用于候选解的粗筛，仅在最终重排序阶段引入另一种质量准则。遵循 PIEA<sup>[4]</sup>，利用广义 $L_p$ 前沿形状估计及其有限的收敛性回退，为每个已评价解计算基于 SDE 的适应度<sup>[5]</sup>。由于该适应度仅对已评价解可用，使用 RBF-SVR 模型在决策空间中对其进行近似，

$$
\widehat I(\mathbf{x})=\mathcal{M}_I(\mathbf{x};\mathcal{D}),
\qquad
\mathcal{D}=\{(\mathbf{x}_i,I_i)\}_{i=1}^{N},
\tag{14}
$$

并用它重排候选池。选择分两个阶段进行：首先，式 (9) 的关系得分保留 $\mathcal{A}$ 中排名前 $q_{\mathrm{rel}}$ 比例的候选解；随后，$\widehat I$ 对缩小后的集合进行重排序。达到或超过其 $q_{\mathrm{ind}}$ 分位数的候选解构成 $\mathcal{H}^{\mathrm{ind}}$；若合格者少于 $n_{\min}$ 个，则用排名最高的候选解补齐。最终批次由 $\widehat I$ 下最优的 $n_b$ 个成员组成。因此，该模式的贡献在于"先基于关系筛选、再基于指标重排序"这一两阶段用法。

#### 3.4.3 选择准则的切换

记 $m\in\{\mathrm{exp},\mathrm{ind}\}$ 为当前迭代的模式。以 $u\sim U[0,1)$，

$$
m=
\begin{cases}
\mathrm{ind}, & \text{若指标代理可用且 } u<p_{\mathrm{mix}},\\[2pt]
\mathrm{exp}, & \text{否则},
\end{cases}
\tag{15}
$$

其中 $p_{\mathrm{mix}}=0.5$。随机切换为每次迭代指派一个完整无损的准则，从而保持两个模式各自不同的选择语义，并在指标代理可用时给予它们相等的被选概率，而不需要把两者的分数合并成单一排序。

无论抽到哪个模式，昂贵评价的次数为

$$
n_b=\min\bigl(n_{\max},\,|\mathcal{H}^{m}|\bigr),
\tag{16}
$$

并进一步被剩余预算 $FE_{\max}-FE$ 截断。在施加该上限之前，只要池规模允许，保留集就会被补齐到 $n_{\min}$。分位数规则与式 (16) 共同把代理分数转换为稳定的"排名—预算"接口。当内层池为空时，由一步直接的遗传变异提供候选解。算法 3 总结了该模块，并按选择顺序返回批次；剩余预算的截断由算法 1 在求值之前施加。

> **算法 3**　DiversifiedInfillSelection（CDIS）
>
> **输入**：种群 $\mathcal{P}$，代表解 $\mathcal{R}$，代理 $\mathcal{M}_R,\mathcal{M}_I$，模式 $m$，进度 $t$，误差 $e_r$
> **输出**：有序的候选解批次 $\mathcal{S}$
>
> 1. $\mathcal{Q}\gets$ 由 $\mathcal{P}\cup\mathcal{R}$ 生成的子代
> 2. 用 $\mathcal{Q}$ 初始化候选解列表 $\mathcal{L}$；$c\gets|\mathcal{Q}|$
> 3. **while** $c<g_{\max}$ 且 $\mathcal{Q}\neq\emptyset$ **do**
> 4. 　用 $\mathcal{M}_R$ 以模式 $m$ 对应的聚合方式为 $\mathcal{Q}$ 打分
> 5. 　保留最好的 $\min(|\mathcal{R}|,|\mathcal{Q}|)$ 个候选解作为父代
> 6. 　$\mathcal{Q}\gets$ 由这些父代与 $\mathcal{R}$ 生成的子代
> 7. 　把 $\mathcal{Q}$ 追加到 $\mathcal{L}$；$c\gets c+|\mathcal{Q}|$
> 8. **end while**
> 9. $\mathcal{A}\gets\mathcal{L}$ 中互不相同的候选解
> 10. **if** $\mathcal{A}=\emptyset$ **then return** $\emptyset$
> 11. **end if**
> 12. **if** $m=\mathrm{ind}$ **then**
> 13. 　$\mathcal{B}\gets$ 按 $R(\mathbf{x})$ 得分最高的 $\lceil q_{\mathrm{rel}}|\mathcal{A}|\rceil$ 个候选解
> 14. 　用 $\mathcal{M}_I$ 在 $\mathcal{B}$ 上预测 $\widehat I(\mathbf{x})$
> 15. 　$\tau\gets Q_{q_{\mathrm{ind}}}(\widehat I(\mathcal{B}))$
> 16. 　$\mathcal{H}^{\mathrm{ind}}\gets\{\mathbf{x}\in\mathcal{B}\mid\widehat I(\mathbf{x})\geq\tau\}$
> 17. 　如有必要，用 $\mathcal{B}$ 中按 $\widehat I$ 最好的剩余候选解把 $\mathcal{H}^{\mathrm{ind}}$ 补齐到 $\min(n_{\min},|\mathcal{B}|)$
> 18. 　$n_b\gets\min(n_{\max},|\mathcal{H}^{\mathrm{ind}}|)$
> 19. 　$\mathcal{S}\gets\mathcal{H}^{\mathrm{ind}}$ 中按 $\widehat I$ 最好的 $n_b$ 个成员
> 20. **else**
> 21. 　按式 (10)–(11) 计算 $A_{\mathrm{exp}}$，并按式 (12) 构成 $\mathcal{H}^{\mathrm{exp}}$
> 22. 　如有必要，用 $\mathcal{A}$ 中按 $A_{\mathrm{exp}}$ 最好的剩余候选解把 $\mathcal{H}^{\mathrm{exp}}$ 补齐到 $\min(n_{\min},|\mathcal{A}|)$
> 23. 　$n_b\gets\min(n_{\max},|\mathcal{H}^{\mathrm{exp}}|)$
> 24. 　用 $\mathcal{H}^{\mathrm{exp}}$ 中 $A_{\mathrm{exp}}$ 的最大化者初始化 $\mathcal{S}$
> 25. 　**while** $|\mathcal{S}|<n_b$ **do**
> 26. 　　把 $\mathcal{H}^{\mathrm{exp}}\setminus\mathcal{S}$ 上 $A_{\mathrm{batch}}(\mathbf{x}\mid\mathcal{S})$ 的最大化者追加到 $\mathcal{S}$
> 27. 　**end while**
> 28. **end if**
> 29. **return** $\mathcal{S}$

### 3.5 计算复杂度

设 $N$ 为种群规模，$N_v=O(N)$ 为方向数量，$N_c$ 为去重后候选池的规模，$D$ 为决策变量数，$M$ 为目标数。

在 PAQC 中，方向关联与式 (3)–(4) 的连续 PBI 计算耗费 $O(NN_vM)$，式 (2) 的方向集只需对非支配向量做一次单位化，式 (5) 的有界二分耗费 $O(B_\delta NkM)$（其中 $B_\delta$ 由区间与容差固定），代表解选择还额外执行非支配排序与径向投影距离计算。在 $N_v=O(N)$、$k=O(N)$ 下，该模块由 $O(N^2M)$ 主导；生成关系解对再增加 $O(N^2D)$。

在 CDIS 中，为一个候选解打分需要 $2N$ 个维度为 $2D$ 的网络输入，因此整个池在数据构造与预测上耗费 $O(N_cND)$，这一项主导该模块。指标适应度耗费 $O(N^2M)$；指标导向模式额外增加一次在 $N$ 个已评价解上的 SVR 拟合，以及在筛选后子集上的预测；式 (13) 的贪心构造耗费 $O(n_{\max}N_cD)$。因此每次迭代的开销为 $O(N_cND+N^2M)$。两个模块都不消耗昂贵评价，故无论模式序列如何，真实评价的总次数始终为 $FE_{\max}$。

---

## 4 结论

**[TODO：强化 PACDIS 的两个设计贡献：PAQC 把细粒度次序与基于代表解的组优先级结合起来；CDIS 在显式的评价批量上限内提供探索准则与指标准则。陈述最强的已核验算法级结果及其基准测试范围。最后把组构成与候选批次层面的发现连接回这两个设计角色，并把经验性能主张保持在其条件匹配对比所支持的层级上。]**

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

> 参考文献 6（PC-SAEA）与 7（R2AEA）在当前英文稿的正文中尚未被引用，仅存在于文献表中，待相关工作节写作时接入。

---

## 复核说明：关于"标签内排序"动机（2026-09-10，临时，投稿前删除）

本文档与 `HPDC-MaOEA.tex` 中共 8 处黄色标记，源自一次源码核对。核对确立两条事实：

**(a) REMO 没有"正组选择"这一步。** `REMO.m` 第 50 行是 `Catalog = GetOutput_PBI(Population.objs, Ref.objs)`，直接把 $L=1$ 的全体作为 $\mathcal{C}_1$：无配额、无排序、无 top-$k$ 截断。既然不存在"从 $L=1$ 里挑一部分"的动作，就不存在"排序信息在这一步丢失"。**真正引入配额的是 PAQC 自己**（`PBIQualityClassification.m` 中 `rGood = 0.25`，$\lceil N/4\rceil$）。把"缺少标签内排序"写成 REMO 的缺口，是把本方法自己造出来的约束记在基线账上，属循环论证（与写作骨架红线第 11 条同源）。

**(b) 连续分数不进入监督信号。** `GetRelationPairs.m` 只接收 `Catalog`，从不接收 `score_v`。解对标签严格由组归属决定：$\mathcal{C}_1\to\mathcal{C}_2$ 为 $+1$，反向为 $-1$，**同组一律为 $0$**——与 REMO 的标签集完全相同。因此 $\mathcal{C}_1$ 内部两个解之间的质量差异，在监督里同样不可见。**PAQC 并未给关系学习增加"正组内部质量辨识"。**

由此，"粗粒度二值监督缺乏正组内部质量辨识、而 PAQC 解决了它"这一说法不成立：$\mathcal{C}_1$ 内部无辨识度在 PAQC 中依然如此，且这本来也不是一个待解决的缺陷。

**可辩护的表述**（$S_i$ 唯一真实的作用位置）：$S_i$ 决定的是**哪些解进入 $\mathcal{C}_1$**，即成员资格，而非组内监督粒度。这个作用是真实且可测的——因为 $\delta$ 的二分搜索把正类率压在 $[0.3,0.7]$（`RepresentativeBasedClassification.m` 第 47 行），而配额只有 $0.25$，所以配额恒为紧约束，$L=1$ 的解必然多于 $\mathcal{C}_1$ 的名额，必须有第二判据来决定取谁。**按红线第 11 条的合法写法：先声明配额是受控设计参数，再由 $r_g=0.25 <$ 正类率下界 $0.3$ 推出配额紧约束、二值标签无法唯一确定成员，故需第二判据。**顺序不能颠倒。

正文第 3.2.3 节"因此排序的改变之所以重要，是因为它改变了哪些解进入 $\mathcal{C}_1$，从而改变了关系模型被训练在哪些有序解对上"这一句已经是正确写法，未加标记，可作为改写其余各处的模板。

标记含义：循环论证 2 处（摘要 TODO、引言 TODO）；字面为真但易被读成监督粒度主张 6 处。源码注释经全目录检索未发现同类说法，无需改动。

