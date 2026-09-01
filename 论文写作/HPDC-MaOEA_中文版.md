# 面向昂贵超多目标优化的混合 PBI 质量分层与双模式候选解选择

**Hybrid PBI Quality Stratification and Dual-Mode Candidate Selection for Expensive Many-Objective Optimization**

作者：待补充　　日期：2026-09-01

> **说明**：本文档是 [HPDC-MaOEA.tex](HPDC-MaOEA.tex) 初稿的中文对照版，供查阅使用。章节层级、算法编号、命题与注记编号均与英文初稿及编译出的 PDF 逐一对应。
>
> **公式编号对照**：本中文版保留原有的 (1)–(44) 编号，2026-09-01 新增的四个公式以字母后缀插入，以免打乱既有引用；英文 .tex 采用连续编号，因此现为 (1)–(48)。对应关系为：中文 (7a) = 英文 (8)，中文 (7b) = 英文 (9)，中文 (11a) = 英文 (14)，中文 (11b) = 英文 (15)；此后中文 (n) 对应英文 (n+4)（例如中文 (22) 融合式 = 英文 (26)，中文 (43) 模式式 = 英文 (47)，中文 (44) 批量式 = 英文 (48)）。
>
> 原文中的 `[TODO: ...]` 占位符在此保留为 **[TODO：...]**（现为 18 处，新增第 3.2.1 节的审计字段导出一项）。
>
> 第 3 节（方法）依据"混合 PBI"与"候选解模块"两份 Markdown 初稿撰写，并已逐行对照 MATLAB 源码 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original` 核验；第 1、2、4、5 节为占位内容。

---

## 摘要

**[TODO：摘要。预留的记忆句：在 250 次独立运行、40 个预定义的「问题–$M$–阶段」单元格上，两个 PBI 视图表现出很低的集合重叠度，并在 33 个单元格中提供了双向独有的未来真正例；并集真正例中有 $81.5\%$ 仅被单一视图识别。]**

---

## 1 引言

**[TODO：引言。四个段落已在"问题–机制–证据"笔记（混合 PBI）第 5 节中拟好：(i) 在评价预算严重受限条件下关系学习的任务与重要性；(ii) 二元 PBI 划分的粒度压缩缺口；(iii) 该缺口与所提机制之间的一一对应关系；(iv) 最强证据与三项贡献。]**

---

## 2 相关工作

### 2.1 代理辅助的昂贵多目标／超多目标优化

**[TODO：基于 Kriging／RBF 的 SAEA、它们在 $M$ 上的可扩展性极限，以及为何当 $M$ 增大时"对每个目标分别做回归"变得不再有吸引力。]**

### 2.2 面向昂贵优化的关系学习

**[TODO：REMO 及成对比较型 SAEA 这一研究脉络；各自使用何种监督信号；把本工作定位为"标签接口"层面的贡献，而非一个新的聚合函数。]**

### 2.3 质量评估与候选解选择

**[TODO：基于指标的评估（SDE、$L_p$ 形状估计、PIEA）、径向代表解选择（RSEA），以及填充／候选解选择规则。结尾给出引出第 3 节的研究缺口。]**

---

## 3 所提出的 HPDC-MaOEA

基于关系的代理辅助进化算法用一个分类器取代多输出回归，该分类器预测一对解之间的相对质量。此时有两个接口决定了这类算法实际能够学到什么、又能利用什么：一是把当前种群转换为监督标签的规则，二是把大规模候选池的代理分数转换为一小批昂贵评价的规则。HPDC-MaOEA（hybrid-PBI dual-mode-candidate many-objective evolutionary algorithm，混合 PBI–双模式候选解超多目标进化算法）同时处理这两个接口。第 3.1 节给出总体框架，第 3.2 节发展用于产生监督标签的混合 PBI 质量分层，第 3.3 节描述建立在这些标签之上的关系模型，第 3.4 节发展双模式候选解选择，第 3.5 节分析计算复杂度。

### 3.1 总体框架

我们考虑如下昂贵超多目标问题

$$
\min_{\mathbf{x}\in\Omega}\;
\mathbf{f}(\mathbf{x})=\bigl[f_1(\mathbf{x}),\ldots,f_M(\mathbf{x})\bigr],
\qquad
\Omega\subseteq\mathbb{R}^{D},
\tag{1}
$$

其中 $\mathbf{f}$ 的每一次评价都是昂贵的，因此真实函数评价的总次数被限制在预算 $B$ 之内。记 $FE$ 为迄今已消耗的评价次数，

$$
\rho=\min\!\left(1,\frac{FE}{B}\right)
\tag{2}
$$

为评价进度。

HPDC-MaOEA 从一个包含 $N_{\mathrm{init}}$ 个解的拉丁超立方设计出发，对其求值，并存入存档 $\mathcal{A}_{\mathrm{rc}}$。此后每一次外层迭代执行五个步骤。

1. **质量分层。** 通过混合 PBI 分层（第 3.2 节）把当前种群 $\mathcal{P}$ 转换为二元组标签 $c_i\in\{0,1\}$；该步骤同时返回锚点集 $\mathcal{R}$，后者随后被用作一个附加的交配池。
2. **关系模型。** 由 $c_i$ 生成有序解对，训练一个三分类关系网络，并同时得到留出集上的成对错误率 $p_{\mathrm{err}}$（第 3.3 节）。
3. **指标模型。** 为每个已评价解计算 SDE 适应度值，并拟合一个从决策向量到这些值的 RBF-SVR 模型（第 3.4.3 节）。
4. **候选解选择。** 由代理辅助的内层搜索累积候选池，抽取两种选择模式之一，返回一批 $n_t\in[n_{\min},n_{\max}]$ 个候选解（第 3.4 节）。
5. **评价与环境选择。** 对该批候选解求值，追加到 $\mathcal{A}_{\mathrm{rc}}$，并在整个存档上通过雷达网格环境选择得到下一代种群。

算法 1 总结了整个流程。该设计使两个接口保持分离：混合 PBI 分层决定**要求分类器学习什么**，而双模式候选解选择决定**它的分数如何被花掉**。所有昂贵评价都消耗在步骤 5，因此这两个模块完全运行在已评价数据与代理预测之上。

> **算法 1**　HPDC-MaOEA
>
> **输入**：问题，预算 $B$，种群规模 $N_p$，候选解生成上限 $g_{\max}$，正组比例 $r_g$，分位数 $q_{\mathrm{keep}}$，探索强度 $\lambda_0$，混合概率 $p_{\mathrm{mix}}$，批量上下界 $n_{\min},n_{\max}$
> **输出**：存档 $\mathcal{A}_{\mathrm{rc}}$
>
> 1. 用拉丁超立方设计采样 $N_{\mathrm{init}}$ 个解并求值
> 2. $\mathcal{P}\gets$ 初始种群；$\mathcal{A}_{\mathrm{rc}}\gets\mathcal{P}$
> 3. 由运行序号初始化模式随机流，并令 $L_p\gets1$
> 4. **while** $FE<B$ **do**
> 5. 　$\rho\gets FE/B$；$k_{\mathrm{eff}}\gets\min\bigl(N_p,\max(6,\lceil1.5M\rceil)\bigr)$
> 6. 　$(\boldsymbol{c},\mathcal{R})\gets$ **HybridPBIStratification**$(\mathcal{P},\rho,k_{\mathrm{eff}})$　▷ 第 3.2 节
> 7. 　$(\mathcal{X},\boldsymbol{y})\gets$ **RelationPairs**$(\mathcal{P},\boldsymbol{c})$
> 8. 　**if** $\mathcal{X}=\emptyset$ **then**
> 9. 　　$\mathcal{P}\gets$ **EnvSelect**$(\mathcal{A}_{\mathrm{rc}},N_p)$；**continue**
> 10. 　**end if**
> 11. 　$(\mathrm{net},p_{\mathrm{err}})\gets$ **TrainRelationNet**$(\mathcal{X},\boldsymbol{y})$　▷ 第 3.3 节
> 12. 　$(\boldsymbol{\phi},L_p)\gets$ **SDEFitness**$(\mathcal{P},L_p)$；$\widehat\phi\gets$ **FitSVR**$(\mathcal{P},\boldsymbol{\phi})$
> 13. 　从模式随机流中抽取 $\xi\sim U[0,1)$，并按 (43) 解析出模式 $m_t$
> 14. 　$\mathcal{S}\gets$ **DualModeSelection**$(\mathcal{P},\mathcal{R},\mathrm{net},p_{\mathrm{err}},\widehat\phi,m_t,g_{\max})$　▷ 第 3.4 节
> 15. 　**if** $\mathcal{S}=\emptyset$ **then**
> 16. 　　$\mathcal{S}\gets$ 由 $\mathcal{P}\cup\mathcal{R}$ 生成的至多 $n_{\min}$ 个子代
> 17. 　**end if**
> 18. 　按剩余预算截断 $\mathcal{S}$，对其求值，并追加到 $\mathcal{A}_{\mathrm{rc}}$
> 19. 　$\mathcal{P}\gets$ **EnvSelect**$(\mathcal{A}_{\mathrm{rc}},N_p)$
> 20. **end while**

### 3.2 基于混合 PBI 的质量分层

关系学习在标注任何解对之前，都需要一个粗粒度但可靠的"更好"的概念。如 REMO<sup>[2]</sup> 中用于关系学习的二元 PBI 划分正好提供了这一点：一个自适应边界把当前种群划分为两个相对平衡的子种群，并给出清晰的类结构。然而，同一个边界会把子种群内部的所有 PBI 差异压缩成单一的组级含义，于是边界同侧、PBI 质量明显不同的两个解在标签上变得无法区分。混合 PBI 分层把这个单一边界原本同时承担的两种角色分离开来：一个连续的、基于方向的偏好保持组内次序，一个基于锚点的二元偏好提供组间边界，两者的阶段感知组合产生最终用于监督的正组。

形式化地，设当前种群为

$$
\mathcal{P}=\{\mathbf{x}_i,\mathbf{f}_i\}_{i=1}^{N_t},
\qquad
\mathbf{f}_i\in\mathbb{R}^{M},
\tag{3}
$$

其中 $N_t=|\mathcal{P}|$。该模块接收目标矩阵、式 (2) 的进度 $\rho$ 以及锚点容量 $k_{\mathrm{eff}}$，返回融合排序分数 $h_i$、二元组标签 $c_i$ 和锚点集 $\mathcal{R}$。本节中 $\mathbf{z}^{*}$ 始终表示按分量取的种群最小值

$$
\mathbf{z}^{*}=\min_{i=1,\ldots,N_t}\mathbf{f}_i .
\tag{4}
$$

两个分支都由同一个种群算出，且都使用 PBI 几何；因此"混合"指的是两种偏好在**分辨率**上的差异（连续值对二值），而不是它们之间的统计独立性或几何独立性。除分辨率之外，两者还有两项实现层面的差异：方向来源不同（连续分支用非支配前沿自身的射线，见式 (7b)；二元分支用 RSEA 选出的锚点，见式 (15)），归一化原点也不同（前者对原点单位化，后者对 $\mathbf{z}^{*}$ 单位化）。本文不声称这两项差异带来了额外的信息互补性。

#### 3.2.1 连续的、基于方向的 PBI 偏好

连续分支沿一个方向集 $\mathcal{V}=\{\mathbf{v}_j\}_{j=1}^{N_v}$ 为每个解打分，其规模固定为初始设计的规模 $N_{\mathrm{init}}$，因此在我们的设置下等于种群规模。

**方向集。** 当目标数较少（$M\leq3$）或种群较小（$N_t<50$）时，$\mathcal{V}$ 取为一组归一化到单位长度的均匀参考向量。否则，方向由种群自身导出。设

$$
\mathcal{P}^{\mathrm{ND}}
=\bigl\{\mathbf{f}^{(1)},\ldots,\mathbf{f}^{(n_{\mathrm{ND}})}\bigr\}
\tag{5}
$$

为 $\mathcal{P}$ 的第一非支配前沿，$\mathbf{z}_{\mathrm{ND}}$ 与 $\mathbf{z}_{\mathrm{ND}}^{\max}$ 为其按分量的最小值与最大值，跨度为 $\boldsymbol{\varrho}=\mathbf{z}_{\mathrm{ND}}^{\max}-\mathbf{z}_{\mathrm{ND}}$。先把该前沿映射到单位盒，

$$
\bar{\mathbf{f}}^{(j)}
=\bigl(\mathbf{f}^{(j)}-\mathbf{z}_{\mathrm{ND}}\bigr)\oslash\boldsymbol{\varrho},
\tag{6}
$$

其中 $\oslash$ 表示按分量相除。对 $\{\bar{\mathbf{f}}^{(j)}\}$ 施加簇数为 $K_v=\min(N_v,n_{\mathrm{ND}})$ 的 $K$-means 聚类，每个簇心 $\boldsymbol{\mu}_k$ 被映射回原始目标尺度并归一化，

$$
\mathbf{v}_k=\frac{\boldsymbol{\mu}_k\odot\boldsymbol{\varrho}+\mathbf{z}_{\mathrm{ND}}}
{\bigl\|\boldsymbol{\mu}_k\odot\boldsymbol{\varrho}+\mathbf{z}_{\mathrm{ND}}\bigr\|_2},
\qquad k=1,\ldots,K_v,
\tag{7}
$$

其中 $\odot$ 为按分量相乘。若 $K_v<N_v$，则循环复制簇心直至凑满 $N_v$ 个方向。

**该聚类在本文的实验设置下是恒等映射。** 由第 3.2.1 节开头，$N_v$ 固定为初始设计规模 $N_{\mathrm{init}}$；而 $\mathcal{P}^{\mathrm{ND}}$ 是规模为 $N_p$ 的当前种群的一个子集，故 $n_{\mathrm{ND}}\leq N_p$ 恒成立。当 $N_{\mathrm{init}}\geq N_p$ 时（本文全部实验取 $D=30$，于是 $N_{\mathrm{init}}=N_p=100$），必有

$$
K_v=\min(N_v,n_{\mathrm{ND}})=n_{\mathrm{ND}},
\tag{7a}
$$

即簇数等于样本数。此时"每点自成一簇"是簇内平方和为零的全局最优解，故每个簇心恰好落在一个非支配解上；又因式 (6) 的仿射归一化与式 (7) 中"映射回原尺度"两步互为逆变换，式 (7) 化简为

$$
\mathcal{V}=\Bigl\{\mathbf{f}^{(j)}\big/\bigl\|\mathbf{f}^{(j)}\bigr\|_2
\;\Bigm|\;j=1,\ldots,n_{\mathrm{ND}}\Bigr\},
\tag{7b}
$$

即**当前非支配前沿自身的径向单位方向集**：每个方向穿过一个已观测到的非支配解，方向数等于 $n_{\mathrm{ND}}$，不足 $N_v$ 的部分由循环复制补足。因此该分支不是"用少数簇心概括前沿区域"，而是**为每个非支配解各分配一个方向**。我们在 $M=5,10,20$ 的合成前沿（$N_p=100$）上逐项核验了式 (7a)–(7b)：簇心集与非支配点集的最大偏差为 $0$，式 (7) 所得 $\mathcal{V}$ 与式 (7b) 的最大偏差为 $2\times10^{-16}$。

实现中保留 $K$-means 调用是为了与已完成实验的全局随机流消耗保持一致；就所产生的方向而言，它可被式 (7b) 逐位替换。该构造不含形状参数，也不对前沿的凸性或内在维数作任何预设。

在以下两种情形下改用均匀参考向量：前沿过小以致无法支撑聚类，即 $n_{\mathrm{ND}}<\max(10,N_v/2)$；或某个目标在前沿上退化，即 $\min_m\varrho_m<10^{-12}$。若非支配排序或聚类失败，同样退回到均匀向量。第一个条件保证只有当样本已覆盖前沿时才启用种群导出的方向场，第二个条件避免式 (6) 中出现除零。于是方向的**数量**随当前非支配集的规模而变，方向的**位置**随迄今获得的最好解而变，从而使 $\mathcal{V}$ 跟踪种群当前覆盖的区域。

**连续分数。** 每个目标向量被关联到余弦相似度最大的方向，

$$
a(i)=\arg\max_{j}
\frac{\mathbf{f}_i^{\mathsf T}\mathbf{v}_j}{\|\mathbf{f}_i\|_2\,\|\mathbf{v}_j\|_2},
\tag{8}
$$

相对该方向的平行距离与垂直距离为

$$
d_{1,i}=\frac{(\mathbf{f}_i-\mathbf{z}^{*})^{\mathsf T}\mathbf{v}_{a(i)}}{\|\mathbf{v}_{a(i)}\|_2},
\tag{9}
$$

$$
d_{2,i}=\left\|(\mathbf{f}_i-\mathbf{z}^{*})
-d_{1,i}\frac{\mathbf{v}_{a(i)}}{\|\mathbf{v}_{a(i)}\|_2}\right\|_2 .
\tag{10}
$$

连续 PBI 值采用常规的基于惩罚的边界交叉形式<sup>[1]</sup>，其单调分数由一个递减变换得到，

$$
g_i^{\mathrm{con}}=d_{1,i}+\theta\,d_{2,i},
\qquad
s_i=\frac{1}{1+g_i^{\mathrm{con}}},
\tag{11}
$$

惩罚参数 $\theta=5$。$s_i$ 越大表示沿所关联方向的 PBI 值越小；与硬类别标签不同，$s_i$ 保留了当前种群的细粒度次序。

式 (8)–(10) 同时固定了实现中的坐标约定：关联由原始目标向量计算，而两个距离在按理想点 $\mathbf{z}^{*}$ 平移之后计算。本文所有实验均采用这一单一约定。

**退化方向集下连续分数的闭形式。** 式 (7b) 与式 (8) 的组合有一个必须写明的后果。由于 $\mathcal{V}$ 由非支配解自身的射线构成，任一非支配解 $\mathbf{f}_i$ 与"由它自己生成的那个方向"的余弦相似度为 $1$，即达到式 (8) 的最大值，故它必被关联到自身方向 $\mathbf{v}_{a(i)}=\mathbf{f}_i/\|\mathbf{f}_i\|_2$（存在共线解时关联对象与 $\mathbf{f}_i$ 共线，以下结论不变）。记 $\psi_i$ 为 $\mathbf{f}_i$ 与 $\mathbf{z}^{*}$ 的夹角，则式 (9)–(11) 给出

$$
d_{1,i}=\|\mathbf{f}_i\|_2-\|\mathbf{z}^{*}\|_2\cos\psi_i,
\qquad
d_{2,i}=\|\mathbf{z}^{*}\|_2\sin\psi_i,
\tag{11a}
$$

$$
s_i=\Bigl(1+\|\mathbf{f}_i\|_2
-\|\mathbf{z}^{*}\|_2\cos\psi_i
+\theta\,\|\mathbf{z}^{*}\|_2\sin\psi_i\Bigr)^{-1}.
\tag{11b}
$$

式 (11b) 中与解相关的主项是 $\|\mathbf{f}_i\|_2$；余下两项只通过 $\mathbf{f}_i$ 相对固定向量 $\mathbf{z}^{*}$ 的角度进入。因此在非支配解上，连续分支度量的**主要是沿射线的收敛性，而不是解在前沿上的位置**：它不提供分解型算法中"不同方向彼此竞争"的分布性压力，因为不存在两个解争夺同一方向的情形。对被支配解，其关联方向由最近的非支配射线给出，式 (11a)–(11b) 不再精确成立。由于在 $M\geq10$ 时种群的绝大部分为非支配解，式 (11b) 覆盖了当代种群的大多数个体。第 4.4 节将报告 $s_i$ 与 $-\|\mathbf{f}_i-\mathbf{z}^{*}\|_2$ 的实测秩相关，以量化这一退化的程度。

**[TODO：在正式协议（$M\in\{3,5,10,20\}$、$D=30$、$N_p=100$、$B=500$）下导出 `DirectionSource`、`ClusterCount`、$n_{\mathrm{ND}}$ 与 $\mathrm{corr}(s_i,-\|\mathbf{f}_i-\mathbf{z}^{*}\|_2)$ 审计字段各一次，用真实运行日志替换本节的合成前沿核验数值。]**

#### 3.2.2 基于锚点的粗粒度偏好

连续分数沿种群导出的方向对种群排序，但不提供类边界。第二个分支由一小组锚点提供该边界，

$$
\mathcal{R}=\{\mathbf{r}_j\}_{j=1}^{k_{\mathrm{eff}}}\subset\mathcal{P},
\tag{12}
$$

它们由 RSEA<sup>[3]</sup> 的基于径向投影的代表解选择挑出，该规则也是 REMO<sup>[2]</sup> 所采用的选择规则。锚点是当前种群中**已评价的解**，被用作动态参考代表；它们不被当作真实 Pareto 前沿的样本。

**锚点容量与网格分辨率。** 有效锚点数随目标数增长，

$$
k_{\mathrm{eff}}=\min\Bigl(N_p,\;\max\bigl(6,\lceil1.5M\rceil\bigr)\Bigr),
\tag{13}
$$

于是当 $N_p$ 未作为上界起作用时，$M=3,5,10,20$ 分别给出 $k_{\mathrm{eff}}=6,8,15,30$，并以六个锚点作为目标数较少时的下界。在当前实现中，$k_{\mathrm{eff}}$ 还有第二重作用。代表解选择把 $M$ 维归一化目标向量映射到二维雷达坐标，并把该平面划分为 $n_{\mathrm{div}}\times n_{\mathrm{div}}$ 网格，其中

$$
n_{\mathrm{div}}=\bigl\lceil\sqrt{k_{\mathrm{eff}}}\,\bigr\rceil ,
\tag{14}
$$

随后把代表解分布到被占据的格子上，优先选择稀疏格子，并在同一格子内部用"较小的归一化目标和"与"到已选解的较大雷达投影距离"进行权衡。因此 $k_{\mathrm{eff}}$ 同时是锚点集的容量与锚点被铺开的网格分辨率：$k_{\mathrm{eff}}=6$ 给出 $3\times3$ 网格，$k_{\mathrm{eff}}=30$ 给出 $6\times6$ 网格。这一耦合正是式 (13) 随 $M$ 缩放的直接原因；固定的锚点预算同时也会固定网格分辨率，锚点便无法随 $M$ 增大而覆盖更多的径向区域。

**二元偏好。** 每个解在原始目标空间中被关联到余弦相似度最大的锚点，得到下标 $b(i)$ 与单位方向

$$
\mathbf{w}_{b(i)}=\frac{\mathbf{r}_{b(i)}-\mathbf{z}^{*}}{\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2}.
\tag{15}
$$

相应的距离为

$$
\hat d_{1,i}=(\mathbf{f}_i-\mathbf{z}^{*})^{\mathsf T}\mathbf{w}_{b(i)},
\tag{16}
$$

$$
\hat d_{2,i}=\bigl\|(\mathbf{f}_i-\mathbf{z}^{*})-\hat d_{1,i}\mathbf{w}_{b(i)}\bigr\|_2 ,
\tag{17}
$$

对于平衡参数 $\delta$，锚点归一化的 PBI 值与二元偏好为

$$
g_i^{\mathrm{bin}}(\delta)
=\frac{\hat d_{1,i}+\delta\,\hat d_{2,i}}{\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2},
\tag{18}
$$

$$
\ell_i(\delta)
=\mathbb{I}\bigl[g_i^{\mathrm{bin}}(\delta)\leq1\bigr].
\tag{19}
$$

用 $\|\mathbf{r}_{b(i)}-\mathbf{z}^{*}\|_2$ 归一化使得式 (19) 的阈值就是锚点本身，因此 $\ell_i$ 记录的是"解位于通过其关联锚点的曲面的哪一侧"。

参数 $\delta$ 是一个**带符号的类平衡变量**，而不是一个新的聚合参数。REMO 会把它的划分参数调向近似平衡的划分；这里采用的实现在 $\delta\in[-20,20]$ 上用二分法搜索，一旦正例率

$$
r(\delta)=\frac{1}{N_t}\sum_{i=1}^{N_t}\ell_i(\delta)
\tag{20}
$$

进入宽容区间 $[0.3,0.7]$，或者当区间宽度降到 $10^{-1}$ 以下时即停止。因此这一有界搜索追求的是一个宽容的类比例，并在有限步内终止；由于区间与容差都是有限的，它**并不保证**对每一种种群状态都得到落在 $[0.3,0.7]$ 内的比例。负的 $\delta$ 是允许的，它奖励而非惩罚较大的垂直距离，这正是同一规则能在"关联锚点靠近种群"时提高正例率的原因。

#### 3.2.3 阶段感知的混合分层

两种偏好以一个跟随昂贵预算消耗的权重进行组合。以式 (2) 的 $\rho$，连续分支获得权重

$$
\alpha=1-\rho,
\tag{21}
$$

融合排序分数为

$$
h_i=\alpha\,s_i+(1-\alpha)\,\ell_i .
\tag{22}
$$

各解按 $h_i$ 降序排序，正组取排在最前的比例 $r_g$，

$$
c_i=
\begin{cases}
1, & \operatorname{rank}_{\downarrow}(h_i)\leq\lceil r_gN_t\rceil,\\
0, & \text{否则},
\end{cases}
\tag{23}
$$

其中 $r_g=0.25$。所有 $c_i=0$ 的解，无论排名居中还是靠后，都构成单一的非正组。

式 (22) 是**作用在排序键上的退火调度**，而不是两个可比量的简单加权平均。由于 $s_i\in(0,1]$ 连续而 $\ell_i\in\{0,1\}$ 离散，两个分支作用在不同的可分辨尺度上。当 $\alpha$ 较大时，$h_i$ 的差异由 $s_i$ 主导，连续分数就是排序键。一旦 $\alpha$ 小到使二元偏好贡献的间隔 $1-\alpha$ 超过连续分数所能达到的最大差异，次序就发生质变：二元类别成为排序键，而 $s_i$ 退化为各类内部的决胜项。命题 1 给出该转变的一个充分条件，它只依赖于 $\alpha$ 与 $s_i$ 的取值范围，不需要对前沿几何作任何假设。因此式 (21) 的作用是让监督信号的**粒度**单调地从细走向粗：预算早期保持组内可分辨性，预算后期强制形成稳定的类结构。第 4.4 节将把该调度与静态调度、反向调度作对比检验。

---

> **命题 1（二元偏好诱导的两级次序）**
>
> 假设方向非负，$\mathbf{v}_j\succeq\mathbf{0}$，且理想点取式 (4) 的按分量种群最小值，从而 $\mathbf{f}_i-\mathbf{z}^{*}\succeq\mathbf{0}$。则 $d_{1,i}\geq0$、$d_{2,i}\geq0$，于是 $g_i^{\mathrm{con}}\geq0$，并由式 (11) 得 $s_i\in(0,1]$。在此前提下，对任意满足 $\ell_i=1$ 且 $\ell_j=0$ 的解对 $i,j$，有
>
> $$
> \alpha\leq\tfrac{1}{2}
> \quad\Longrightarrow\quad
> h_i>h_j .
> $$

**证明。** 由式 (22)，因 $s_i>0$ 有 $h_i=(1-\alpha)+\alpha s_i>1-\alpha$；又因 $s_j\leq1$ 有 $h_j=\alpha s_j\leq\alpha$。当 $\alpha\leq1/2$ 时 $1-\alpha\geq\alpha$，故 $h_i>h_j$。$\quad\blacksquare$

---

命题 1 表明，只要二元分支占据了至少一半的权重，式 (22) 就诱导出一个显式的两级次序：每个二元正例解都排在每个二元负例解之前，而连续分数在各类内部排序。该条件可以放宽。设

$$
\Delta_{01}=\max_{j:\ell_j=0}s_j-\min_{i:\ell_i=1}s_i
\tag{24}
$$

为连续分数的跨类跨度。只要

$$
\alpha<\frac{1}{1+\Delta_{01}}
\tag{25}
$$

成立，严格的跨类支配关系即被保持。由于 $s_i\in(0,1]$ 意味着 $\Delta_{01}\leq1$，从而 $1/(1+\Delta_{01})\geq1/2$，可见界 $\alpha\leq1/2$ 只是最坏情形：每当某一代的连续分数跨度较窄，二元类别成为排序键的时刻就早于 $\rho=1/2$，因此式 (21) 的调度在实践中把二元主导的区间延伸到了预算的一半之后。

---

> **注记 1（实际实现的权重范围）**
>
> 由于该模块首次被调用时初始设计已经完成求值，第一个实际权重并非 $\alpha=1$，而是
>
> $$
> \alpha_{\mathrm{first}}=1-\frac{N_{\mathrm{init}}}{B} .
> \tag{26}
> $$
>
> 在本文的协议下（$N_{\mathrm{init}}=100$、$B=500$），$\alpha_{\mathrm{first}}=0.8$，因此 $\alpha\leq1/2$ 这一充分条件自 $FE=250$ 起满足。名义调度与算法实际访问到的权重范围都将在第 4.4 节报告。
>
> 式 (25) 的放宽条件使实际转变点更早。由于 $\Delta_{01}$ 不超过 $s_i$ 的全域跨度，而后者在我们核验的合成前沿上为 $0.035$–$0.172$（$M=20$ 至 $M=5$），代入式 (25) 得二元分支成为排序键的时刻在 $\rho\approx0.03$–$0.15$，即在初始设计求值完毕后很快到来。**因此式 (21) 的调度在实践中不是"两个信号长期共同作用"，而是"连续分支只在预算最初的一小段内充当排序键，其后二元类别接管、连续分数退为组内决胜项"。**这一定量结论与第 3.2.3 节的定性描述必须一并阅读；第 4.4 节将在真实运行上报告 $\Delta_{01}$ 的分布与实测转变点。

---

算法 2 总结了分层模块。

> **算法 2**　混合 PBI 质量分层
>
> **输入**：种群 $\mathcal{P}$，进度 $\rho$，锚点容量 $k_{\mathrm{eff}}$，惩罚 $\theta$，正组比例 $r_g$
> **输出**：组标签 $\boldsymbol{c}$，融合分数 $\boldsymbol{h}$，锚点 $\mathcal{R}$
>
> 1. 构建 $\mathcal{V}$：若 $M\leq3$、$N_t<50$ 或第 3.2.1 节的回退条件成立，则用均匀向量；否则取非支配前沿的径向单位方向式 (7b)，并循环复制至 $N_v$ 个
> 2. $\mathbf{z}^{*}\gets$ 目标的按分量最小值
> 3. 按式 (8) 关联每个解，并按式 (9)–(11) 计算 $s_i$
> 4. $\mathcal{R}\gets$ 从 $\mathcal{P}$ 中径向网格选出 $k_{\mathrm{eff}}$ 个锚点
> 5. 在 $\delta\in[-20,20]$ 上二分，直到 $r(\delta)\in[0.3,0.7]$ 或区间小于 $10^{-1}$；按式 (19) 置 $\ell_i$
> 6. $\alpha\gets1-\rho$；$h_i\gets\alpha s_i+(1-\alpha)\ell_i$
> 7. 把 $h_i$ 最大的 $\lceil r_gN_t\rceil$ 个解标记为正组，其余全部标记为非正组
> 8. **return** $\boldsymbol{c},\boldsymbol{h},\mathcal{R}$

### 3.3 关系模型构建

式 (23) 的组标签定义了关系模型的监督目标。遵循 REMO<sup>[2]</sup> 的关系建模协议，设

$$
\mathcal{C}_1=\{\mathbf{x}_i\mid c_i=1\},
\qquad
\mathcal{C}_2=\{\mathbf{x}_i\mid c_i\neq1\}
\tag{27}
$$

分别为正组与非正组。每一个由不同解构成的有序对被转换为一个训练样本，其输入是拼接向量 $[\mathbf{x}_i,\mathbf{x}_j]\in\mathbb{R}^{2D}$，其标签

$$
y_{ij}=
\begin{cases}
+1, & \mathbf{x}_i\in\mathcal{C}_1,\ \mathbf{x}_j\in\mathcal{C}_2,\\
-1, & \mathbf{x}_i\in\mathcal{C}_2,\ \mathbf{x}_j\in\mathcal{C}_1,\\
0,  & \mathbf{x}_i\text{ 与 }\mathbf{x}_j\text{ 同组},
\end{cases}
\tag{28}
$$

记录的是**有序的组关系**，而非 Pareto 比较结果。自配对被移除。由于 $r_g=0.25$ 使非正组的规模是正组的三倍，两个同组族被向跨组族做下采样：以 $n_{\times}=\lceil|\mathcal{C}_1\times\mathcal{C}_2|/2\rceil$ 为目标，当"正–正"与"非正–非正"两族的样本量都超过该目标时，各自被随机缩减到 $n_{\times}$；当其中一族不足时，另一族吸收其缺额，使同组样本总数保持为 $2n_{\times}$。由此得到的标签分布是**由构造保证平衡**的，而不是靠对损失函数重新加权。

解对集合按分层抽样划分，$75\%$ 用于训练、$25\%$ 作为留出集 $\mathcal{T}$，使式 (28) 的三种标签在两部分中都有代表。需要注意的是，划分是在**解对**上而非在基础解上进行的，因此同一个解可能同时出现在划分的两侧。输入经 min–max 归一化，一个前馈模式网络（三个隐藏层的单元数分别为 $3D$、$2D$ 和 $D$，即输入维度 $2D$ 的 $1.5$、$1$ 与 $0.5$ 倍）把归一化后的解对映射到 softmax 输出

$$
\boldsymbol{\pi}(\mathbf{x}_a,\mathbf{x}_b)
=\bigl[\pi_{+1},\pi_0,\pi_{-1}\bigr],
\qquad
\pi_{+1}+\pi_0+\pi_{-1}=1 ,
\tag{29}
$$

其三个分量分别是"第一个解属于更高组""两者属于同组""第二个解属于更高组"的预测概率。留出集上的误分类率

$$
p_{\mathrm{err}}
=\frac{1}{|\mathcal{T}|}
\sum_{(a,b)\in\mathcal{T}}
\mathbb{I}\bigl[\hat y_{ab}\neq y_{ab}\bigr]
\tag{30}
$$

被保留下来，并在第 3.4.2 节中重新用于调节探索项；当留出集为空或该估计非有限时，它被置为 1。若某次迭代中解对集为空，则不训练模型，该次迭代仅执行环境选择，且不花费任何昂贵评价。

### 3.4 双模式候选解选择

关系网络能对大量未评价解进行排序，但其输出分数的分布会随问题、搜索阶段以及当前训练集而变化。若施加一个固定的绝对阈值，就会把这种尺度波动直接转移到每次迭代所花费的昂贵评价次数上。有两个事实使这一影响对本文所用的分数变得具体。第一，该分数在解析上有界，因此常规取值 $3.9$ 的阈值位于其理论最大值的 $97.5\%$ 处（第 3.4.1 节）。第二，在一项覆盖四个变体、五个问题、20 次独立运行的 400 次运行受控审计中，仅记录而不施加该阈值的诊断组显示通过比例存在 $5.1$ 倍的跨问题波动；若由该阈值来驱动批量大小，同样的 200 次额外评价将产生 $14.8$ 至 $46.2$ 次代理辅助迭代，相差 $3.1$ 倍。因此 HPDC-MaOEA 把**排序与开支分离**：分位数规则把任意尺度的分数转换为池内排名，而一个显式区间 $[n_{\min},n_{\max}]$ 约束批量大小（第 3.4.4 节）。

#### 3.4.1 成对关系分数与候选池

**分数。** 对一个未评价候选解 $\mathbf{x}$，针对式 (27) 的两个组构造四族有序比较，

$$
(\mathcal{C}_1,\mathbf{x}),\quad
(\mathbf{x},\mathcal{C}_1),\quad
(\mathcal{C}_2,\mathbf{x}),\quad
(\mathbf{x},\mathcal{C}_2),
\tag{31}
$$

这相当于每个候选解需要 $2(|\mathcal{C}_1|+|\mathcal{C}_2|)=2N_t$ 个网络输入。设 $\mathbf{a}(\mathbf{x})$、$\mathbf{b}(\mathbf{x})$、$\mathbf{c}(\mathbf{x})$ 与 $\mathbf{d}(\mathbf{x})$ 为式 (29) 的族内平均概率向量。把"$\mathbf{x}$ 不劣于正组"与"$\mathbf{x}$ 优于非正组"的证据聚合起来，再减去相反方向的证据，即得成对关系分数

$$
r(\mathbf{x})=2\bigl[
c_{-1}(\mathbf{x})+d_{+1}(\mathbf{x})-a_{+1}(\mathbf{x})-b_{-1}(\mathbf{x})
\bigr].
\tag{32}
$$

由于式 (29) 的每个概率向量之和为 1，括号中每一项都落在 $[0,1]$ 内，于是

$$
-4\leq r(\mathbf{x})\leq 4 ,
\tag{33}
$$

这正是前文引用的界。该分数是**相对于两个粗粒度质量组的启发式净证据**，不是 Pareto 胜率。

**候选池。** 候选解由关系引导的内层进化搜索产生。首先对当前种群与锚点的并集施加遗传变异，得到 $\mathcal{Q}^{(0)}$。在内层迭代 $\ell$，网络按式 (32) 为 $\mathcal{Q}^{(\ell)}$ 打分，保留其中最好的

$$
n_{\mathrm{parent}}=\min\bigl(|\mathcal{R}|,|\mathcal{Q}^{(\ell)}|\bigr)
\tag{34}
$$

个候选解，再对这些父代连同锚点施加变异产生 $\mathcal{Q}^{(\ell+1)}$。当累计生成的候选解数量达到上限 $g_{\max}$ 时循环停止，沿途生成的所有候选解被累积并去重，

$$
\mathcal{A}=\operatorname{unique}
\Bigl(\textstyle\bigcup_{\ell=0}^{L}\mathcal{Q}^{(\ell)}\Bigr).
\tag{35}
$$

两种选择模式都用各自的准则对式 (35) 所产生的池 $\mathcal{A}$ 排序。但该池**并非与模式无关**：模式在内层搜索开始之前就已抽定，而式 (34) 的父代保留使用当前模式对应的族内聚合方式——探索模式为尖锐度加权、指标模式为普通平均（见第 3.4.2 节）。因此内层轨迹随模式而异，实际得到的 $\mathcal{A}$ 也随之不同。两种模式共享的是池的**构造规则**式 (35) 与同一个批量界，而不是同一个已实现的候选集合。第 4.5 节通过在共享的冻结候选池上重跑两个准则，把排序准则与这一混杂因素分离开。

#### 3.4.2 关系引导的探索模式

探索模式把关系分数与分类器输出的模糊度、以及决策空间中的距离结合起来。

设 $\mathcal{O}(\mathbf{x})$ 汇集候选解 $\mathbf{x}$ 的式 (31) 中所有有序比较。平均分类模糊度为

$$
u(\mathbf{x})=1-\frac{1}{|\mathcal{O}(\mathbf{x})|}
\sum_{(\mathbf{x}_a,\mathbf{x}_b)\in\mathcal{O}(\mathbf{x})}
\max_{y\in\{-1,0,+1\}}\pi_y(\mathbf{x}_a,\mathbf{x}_b),
\tag{36}
$$

于是较大的 $u(\mathbf{x})$ 意味着网络在该候选解附近产生较平坦的类分布。式 (36) 描述的是 softmax 输出的集中程度，它**不是**一个经过校准的方差，也不是认知不确定性。在本模式中，同一个尖锐度 $\max_y\pi_y$ 还被用作进入式 (32) 的族内平均的权重，使更尖锐的解对对聚合分数贡献更多。该加权只改变族内部的聚合方式，不改变三个关系类的语义。

以 $\widetilde r$ 与 $\widetilde u$ 表示在池上做 min–max 归一化后的量，探索分数为

$$
a^{\mathrm{E}}(\mathbf{x})=\widetilde r(\mathbf{x})+\lambda_t\,\widetilde u(\mathbf{x}),
\tag{37}
$$

其中

$$
\lambda_t=\lambda_0\left(1-\frac{FE}{B}\right)
\max\!\left(0,\,1-\frac{p_{\mathrm{err}}}{0.45}\right)
\tag{38}
$$

且 $\lambda_0=0.35$。式 (38) 的两个因子把模糊度采样的强度与使其有意义的两个量绑定：剩余预算，以及"被采样模糊度的那个模型"的留出误差式 (30)。一旦 $p_{\mathrm{err}}\geq0.45$，该项即消失，因此一个表现糟糕的分类器无法通过它自己的平坦输出来操纵批次。

探索分数高于 $q_{\mathrm{keep}}$ 分位数的候选解构成预备集

$$
\mathcal{H}^{\mathrm{E}}=\Bigl\{\mathbf{x}\in\mathcal{A}\;\Bigm|\;
a^{\mathrm{E}}(\mathbf{x})\geq
Q_{q_{\mathrm{keep}}}\bigl(a^{\mathrm{E}}(\mathcal{A})\bigr)\Bigr\},
\tag{39}
$$

其中 $q_{\mathrm{keep}}=0.80$，大致保留池中最好的 $20\%$；若合格者少于 $n_{\min}$ 个，则用分数最高的候选解补足该集合。随后以贪心方式组装批次。第一个成员最大化 $a^{\mathrm{E}}$，其后每个成员最大化

$$
A(\mathbf{x}\mid\mathcal{S})
=0.75\,\widehat a^{\mathrm{E}}(\mathbf{x})+0.25\,\widehat d(\mathbf{x},\mathcal{S}),
\qquad
d(\mathbf{x},\mathcal{S})=\min_{\mathbf{z}\in\mathcal{S}}\|\mathbf{x}-\mathbf{z}\|_2 ,
\tag{40}
$$

其中 $\widehat a^{\mathrm{E}}$ 与 $\widehat d$ 在每一步对剩余候选解归一化。$0.75$–$0.25$ 的划分让关系质量保持为首要准则，同时防止一个批次坍缩到决策空间的单一区域。该规则促进的是**决策空间**中的分散，它本身并不保证目标空间中的分散。

#### 3.4.3 指标引导模式

指标引导模式用第二个准则对候选解重排序，该准则的训练目标不来自关系网络。它的适应度是基于移位密度估计（SDE）的适应度<sup>[5]</sup>，并使用 PIEA<sup>[4]</sup> 的广义 $L_p$ 前沿形状参数计算。

**前沿形状估计。** 把已评价种群的第一非支配前沿归一化到单位盒，对 $17$ 个候选指数 $p\in[0.27,6.5]$ 分别计算广义范数 $G_p(\bar{\mathbf{f}}_i)=(\sum_m\bar f_{i,m}^{\,p})^{1/p}$，用因子为 $1.5$ 的箱线图规则剔除异常值，并按其最大值缩放。取标准差最小的那个指数作为 $L_p$，因为匹配的指数使前沿成为该范数的一个近似等值面。若前沿包含的解少于 $20$ 个，则取 $L_p=1$。

**SDE 适应度。** 对归一化后的目标向量，移位最近邻距离为

$$
\delta_i=\min_{j\neq i}
\bigl\|\bar{\mathbf{f}}_i-\max(\bar{\mathbf{f}}_i,\bar{\mathbf{f}}_j)\bigr\|_2 ,
\tag{41}
$$

其中最大值按分量取，因此该距离仅当 $\mathbf{x}_j$ 在每个目标上都至少不差于 $\mathbf{x}_i$ 时才为零。这些值被重新缩放到 $[0,3]$；对于缩放后取值低于 $10^{-4}$ 的解，即密度估计无法区分的那些解，改为取到当前理想点的**负向缩放的 Minkowski-$L_p$ 距离**，使收敛性信息取代退化的密度值。再由一个 $\tanh$ 变换把结果映射到 $[-1,1]$，得到每个已评价解的适应度 $\phi_i$。

**重排序。** 由于 $\phi_i$ 只对已评价解有定义，需通过一个在已评价决策向量上拟合的 RBF-SVR 模型把它外推到候选池，

$$
\widehat\phi(\mathbf{x})=\operatorname{SVR}
\bigl(\mathbf{x};\mathcal{P},\boldsymbol{\phi}\bigr),
\tag{42}
$$

采用自动核尺度与标准化输入。选择随后分两个阶段进行：关系分数先保留池中前 $30\%$、且至少 $20$ 个候选解，此后式 (42) 对保留集重排序，不低于 $\widehat\phi$ 的 $70\%$ 分位数的候选解构成 $\mathcal{H}^{\mathrm{I}}$，同样在合格者少于 $n_{\min}$ 时用最好的候选解补足。批次即为该集合在 $\widehat\phi$ 下排名最高的 $n_t$ 个候选解。两阶段的先后顺序为各模型分配了它们各自被训练来完成的任务：关系模型排除明显低优先级的区域，SDE 代理则在缩减后的集合内部表达前沿形状与局部密度偏好。若 SVR 不可用或其预测非有限，本模式退回到关系分数。

#### 3.4.4 混合模式分配

设 $m_t\in\{\mathrm{E},\mathrm{I}\}$ 为外层迭代 $t$ 所用的模式。一个由运行序号播种、且与驱动变异和下采样的全局随机流相互独立的随机流产生 $\xi_t\sim U[0,1)$，并有

$$
m_t=
\begin{cases}
\mathrm{I}, & \text{若指标模型可用且 } \xi_t<p_{\mathrm{mix}},\\
\mathrm{E}, & \text{否则},
\end{cases}
\tag{43}
$$

其中 $p_{\mathrm{mix}}=0.5$。这样两个排序准则在不引入额外校准模型的前提下获得相等的先验曝光，而专用随机流使一次运行的模式序列可复现，且与迭代中其余部分消耗多少随机数无关。两个模式**不做数值融合**：每次迭代恰好使用一个排序准则，遵循同一个池构造规则式 (35)，并受同一个批量界约束。若无法拟合出指标模型，则使用探索模式。

无论抽到哪个模式，昂贵评价的次数均为

$$
n_t=\min\Bigl[n_{\max},\,
\max\bigl(n_{\min},|\mathcal{H}^{m_t}|\bigr)\Bigr],
\tag{44}
$$

并进一步被剩余预算 $B-FE$ 截断，其中 $n_{\min}=4$、$n_{\max}=6$。式 (44) 连同分位数规则 (39) 以及第 3.4.3 节的 $70\%$ 规则，完成了本节开头宣告的分离：代理分数决定一个批次**内部**候选解的优先级，而不再决定一次外层迭代消耗多少昂贵预算。若所选集合为空，则对种群与锚点做一轮遗传变异，提供至多 $n_{\min}$ 个候选解，从而使搜索循环永不停滞。

算法 3 总结了该模块。

> **算法 3**　双模式候选解选择
>
> **输入**：种群 $\mathcal{P}$，锚点 $\mathcal{R}$，关系网络，留出误差 $p_{\mathrm{err}}$，进度 $FE/B$，上限 $g_{\max}$，模式抽样值 $\xi$，参数 $q_{\mathrm{keep}},\lambda_0,p_{\mathrm{mix}},n_{\min},n_{\max}$
> **输出**：候选解批次 $\mathcal{S}$
>
> 1. $\mathcal{Q}^{(0)}\gets$ 对 $\mathcal{P}\cup\mathcal{R}$ 施加变异；$\mathcal{A}\gets\mathcal{Q}^{(0)}$；$\ell\gets0$
> 2. **while** 已生成候选解数量低于 $g_{\max}$ 且 $\mathcal{Q}^{(\ell)}\neq\emptyset$ **do**
> 3. 　按式 (32) 为 $\mathcal{Q}^{(\ell)}$ 打分，保留式 (34) 的最好 $n_{\mathrm{parent}}$ 个作为父代
> 4. 　$\mathcal{Q}^{(\ell+1)}\gets$ 对父代与 $\mathcal{R}$ 施加变异；$\mathcal{A}\gets\operatorname{unique}(\mathcal{A}\cup\mathcal{Q}^{(\ell+1)})$；$\ell\gets\ell+1$
> 5. **end while**
> 6. 按式 (43) 解析出模式 $m_t$
> 7. **if** $m_t=\mathrm{I}$ **then**
> 8. 　按式 (32) 保留 $\mathcal{A}$ 中前 $30\%$（至少 $20$ 个候选解）
> 9. 　按式 (42) 对其重排序，保留高于其 $70\%$ 分位数者作为 $\mathcal{H}^{\mathrm{I}}$
> 10. 　$\mathcal{S}\gets$ $\mathcal{H}^{\mathrm{I}}$ 中在 $\widehat\phi$ 下最好的 $n_t$ 个候选解
> 11. **else**
> 12. 　按式 (36)–(38) 计算 $a^{\mathrm{E}}$，并按式 (39) 构成 $\mathcal{H}^{\mathrm{E}}$
> 13. 　$\mathcal{S}\gets$ 按式 (40) 贪心选出的 $n_t$ 个候选解批次
> 14. **end if**
> 15. 用式 (44) 与剩余预算约束 $n_t$
> 16. **return** $\mathcal{S}$

### 3.5 计算复杂度

设 $N_t$ 为种群规模，$N_v=O(N_t)$ 为方向数量，$N_c$ 为去重后候选池的规模，$D$ 为决策变量数，$M$ 为目标数。

在分层模块中，方向关联与式 (8)–(11) 的连续 PBI 计算耗费 $O(N_tN_vM)$。方向场按式 (7b) 只需对 $n_{\mathrm{ND}}$ 个非支配向量做一次单位化，即 $O(n_{\mathrm{ND}}M)$；当前实现仍调用 $K$-means（$R=5$ 次重复、迭代上限 $I=100$），其代价为 $O(R\,I\,n_{\mathrm{ND}}K_vM)$，在 $K_v=n_{\mathrm{ND}}=O(N_t)$ 下即 $O(R\,I\,N_t^2M)$。这一项与本模块的主导项同阶但常数因子较大，属于可移除的实现开销而非方法的固有代价；第 4.6 节将单独报告它在总运行时间中的占比。二元分支的有界二分耗费 $O(B_\delta N_t k_{\mathrm{eff}} M)$，其中 $B_\delta$ 由区间 $[-20,20]$ 与容差 $10^{-1}$ 固定；锚点选择还额外执行非支配排序与雷达投影距离计算。在 $N_v=O(N_t)$、$k_{\mathrm{eff}}=O(N_t)$ 且聚类上限固定的条件下，该模块由 $O(N_t^2M)$ 主导；生成关系解对再增加 $O(N_t^2D)$。

在候选解模块中，为一个候选解打分需要 $2N_t$ 个维度为 $2D$ 的网络输入，因此整个池在数据构造与存储上耗费 $O(N_cN_tD)$，这一项主导了该模块。式 (41) 的 SDE 适应度耗费 $O(N_t^2M)$；指标模式额外增加一次在 $N_t$ 个已评价解上的 SVR 拟合，以及在预筛选后的候选解上的预测；式 (40) 的贪心构造耗费 $O(n_{\max}N_cD)$。总体而言，每次迭代的开销为 $O(N_cN_tD+N_t^2M)$。

两个模块都不消耗昂贵目标评价：无论模式序列如何，真实评价的总次数始终为 $B$。两个模块的实际运行时间占比将在第 4.6 节报告。

表 1 列出了上文引入的各参数。

**表 1**　HPDC-MaOEA 的参数及其取值。

| 符号                  | 含义                   |                  取值                  |
| :-------------------- | :--------------------- | :------------------------------------: |
| $\theta$            | 连续 PBI 值的惩罚参数  |                 $5$                 |
| $N_v$               | 方向数量               |         $N_{\mathrm{init}}$         |
| $r_g$               | 正组比例               |                $0.25$                |
| $\delta$            | 二元分支的类平衡参数   |         在$[-20,20]$ 内二分         |
| $k_{\mathrm{eff}}$  | 有效锚点容量           | $\min(N_p,\max(6,\lceil1.5M\rceil))$ |
| $\alpha$            | 连续分支的权重         |               $1-FE/B$               |
| $g_{\max}$          | 候选解生成上限         |                $3000$                |
| $q_{\mathrm{keep}}$ | 探索预筛选的分位数     |                $0.80$                |
| $\lambda_0$         | 初始探索强度           |                $0.35$                |
| $p_{\mathrm{mix}}$  | 采用指标引导模式的概率 |                $0.50$                |
| $n_{\min},n_{\max}$ | 评价批量的上下界       |                $4,6$                |

---

## 4 实验研究

### 4.1 实验设置

**[TODO：基准测试集，$M\in\{3,5,10,20\}$，$D$，$N_p$，预算 $B$，独立运行次数，指标（IGD／IGD$^+$／HV），带 Holm 校正的统计检验，以及平台。按"问题–机制–证据"笔记（混合 PBI）第 7 节的规划，每个实验恰好承担一项论证责任。]**

### 4.2 与先进算法的对比

**[TODO：在统一预算下与 REMO、PIEA、PC-SAEA、R2AEA、RSEA 以及更多强基线进行算法级性能对比。本小节只确立最终的性能差异；机制的隔离验证放在第 4.4 节与第 4.5 节。]**

### 4.3 消融实验

**[TODO：共享同一宿主算法与同一 $k_{\mathrm{eff}}$ 的各变体：仅连续分支、仅二元分支、完整混合分层；关系 top-$6$ 选择对比双模式选择。注意 $k_{\mathrm{eff}}$ 与标签构造之间的交互作用，并把锚点数量与式 (14) 的径向网格分辨率区分开来。]**

### 4.4 基于混合 PBI 的质量分层分析

**[TODO：三个机制问题，各自配备独立的度量。(i) 两个视图的非冗余性：250 次运行上平均 Jaccard 为 $0.2326$；经 Holm 校正后，40 个「问题–$M$–阶段」单元格中有 33 个支持双向独有的未来真正例；并集真正例中 $81.5\%$ 仅属于单一视图。(ii) 融合后正组的来源利用率：正组中 $32.2\%$ 来自仅 V 区域、$19.6\%$ 来自仅 A 区域，对应的未来真正例占比分别为 $36.0\%$ 与 $17.9\%$。(iii) 在共享的冻结候选池上，把预算感知调度与静态调度、反向调度作对比，并给出注记 1 中实际实现的 $\alpha$ 范围。]**

### 4.5 双模式候选解选择分析

**[TODO：阈值审计（400 次运行：通过比例 $5.1$ 倍波动、迭代次数 $3.1$ 倍波动），以及在四个 20 目标问题、每个 10 次运行上的候选解级探针：后期存活率从 $0.706$ 提升到 $0.770$（配对 Wilcoxon，$p=0.0085$），相对池内贪心参照的后期增益比从 $0.0861$ 提升到 $0.1048$（$p=0.0250$）。分别报告两个模式的批次分散度。]**

### 4.6 参数敏感性

**[TODO：对 $r_g$、$q_{\mathrm{keep}}$、$\lambda_0$、$p_{\mathrm{mix}}$ 以及 $[n_{\min},n_{\max}]$ 的敏感性，以及第 3.5 节承诺的两个模块的实际运行时间占比。]**

---

## 5 结论

**[TODO：结论。预留的记忆句：混合 PBI 分层在保留清晰的、基于锚点的边界的同时，恢复了被二元划分所压缩的组内次序；而双模式候选解选择把代理分数转换为一个有界的、对尺度不敏感的评价批次。]**

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

## 附录：术语中英对照

| 中文                    | 英文                                             |
| :---------------------- | :----------------------------------------------- |
| 混合 PBI 质量分层       | hybrid PBI quality stratification                |
| 双模式候选解选择        | dual-mode candidate selection                    |
| 昂贵超多目标优化        | expensive many-objective optimization            |
| 关系学习 / 关系模型     | relation learning / relation model               |
| 代理辅助进化算法        | surrogate-assisted evolutionary algorithm (SAEA) |
| 粒度压缩缺口            | granularity-compression gap                      |
| 阶段感知                | stage-aware                                      |
| 正组 / 非正组           | positive group / non-positive group              |
| 锚点                    | anchor                                           |
| 类平衡参数              | class-balance parameter                          |
| 退火调度                | annealing schedule                               |
| 留出集 / 留出误差       | held-out set / held-out error                    |
| 分层抽样                | stratified sampling                              |
| 移位密度估计            | shift-based density estimation (SDE)             |
| 前沿形状估计            | front-shape estimation                           |
| 分类模糊度              | classification ambiguity                         |
| 探索模式 / 指标引导模式 | exploratory mode / indicator-guided mode         |
| 候选池                  | candidate pool                                   |
| 预筛选                  | prefilter                                        |
| 代表解选择              | representative selection                         |
| 径向投影 / 雷达坐标     | radial projection / radar coordinates            |
| 环境选择                | environmental selection                          |
| 拉丁超立方设计          | Latin hypercube design                           |
| 非支配前沿              | nondominated front                               |
| 真正例                  | true positive                                    |
