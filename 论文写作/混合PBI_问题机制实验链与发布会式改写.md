# 混合 PBI 小论文：问题—机制—证据链与发布会式改写

> 用途：本文档分为“可进入论文的正文”和“作者自用审计”两部分。正文遵循问题—缺口—机制—证据的发布会式叙事；防御性写作清单仅用于修改，不进入投稿稿件。现有《方法节_混合PBI_中英文初稿.md》中的公式、公式编号和数学定界符未被修改。

## 一、三个问题分别应该放在哪里

三个问题需要贯穿全文，但承担职责的章节不同。

| 核心问题 | 主责章节 | 该章节应该写到什么程度 | 不应该怎么写 |
|---|---|---|---|
| ① 原方法到底哪里有问题？ | 引言第 2–3 段；相关工作末段 | 引言提出一个最关键的能力缺口，并解释产生缺口的技术原因；相关工作证明这一缺口尚未被现有路线系统解决 | 不在引言中罗列代码缺陷、调参过程或所有失败现象 |
| ② 我的机制为什么针对这个问题？ | 引言末段；方法节开头及各模块首段 | 引言给出一句直观答案；方法节给出输入—机制—输出及可检验预测 | 不把完整公式塞入引言，也不只写“受到启发”而不解释对应关系 |
| ③ 什么实验能够单独证明②？ | 实验/结果节的机制验证与消融小节 | 为每个机制主张设置专门的中间指标、对照组和判定标准；最终 IGD/IGD+ 只承担系统级效果验证 | 不让最终 IGD 同时替标签质量、信息互补性和动态调度的因果作用作证 |

最简洁的全文分工是：

```text
引言：为什么需要解决“单一二值分组的粒度压缩”
  ↓
方法：连续 PBI 评分如何补回组内次序，二值 PBI 分组如何保留稳定边界
  ↓
机制实验：两路信息是否非冗余，混合结果是否真实利用两路信息，动态调度是否优于固定策略
  ↓
总体实验：上述机制进入完整算法后，是否转化为最终优化收益
```

## 二、五篇文献给出的章节组织启示

### REMO：问题解释、机制定义和组件验证分层完成

REMO 在引言中提出多目标关系学习需要同时考虑收敛、分布和训练数据构造；在方法节的 Population Partition 小节中进一步解释，直接使用 Pareto 支配既无法控制类别平衡，也不能充分组织训练点的分布。随后，REMO 在独立的 Strategy Analysis 章节中分别检验 population partition、subsampling 和 voting-scoring，最后才在 Empirical Studies 中报告完整算法的 IGD。这个结构最直接地回答了本文的三个问题：引言提出缺口，方法解释机制，组件实验单独承担机制证明。

### PC-SAEA：把技术困难拆成可回答的问题

PC-SAEA 将方法组织为几个明确问题，例如如何比较解的质量、如何构造配对样本，再让每个模块逐一回答。本文可以沿用这种写法，将核心困难压缩为一句：如何在类别边界与组内排序之间同时保留有用监督信息。

### R2AEA：阶段机制必须对应阶段实验

R2AEA 先说明两阶段分别承担什么任务，再通过实验检验阶段设计及切换条件。本文的预算权重同样属于阶段机制，因此不能只用最终 IGD 证明；应直接比较动态调度、固定权重和反向调度在不同 FE 阶段的标签质量与候选选择效用。

### RSEA：先说明表示能力，再引出算法设计

RSEA 在给出完整算法前先分析径向投影保留的分布信息及其作用。本文也应先建立“连续排序信息与二值边界信息具有不同分辨率”的观察，再引出双粒度组合，而不是从公式直接开场。

### PIEA：监督信号本身就是方法贡献的一部分

PIEA 对不同指标产生何种偏好进行明确解释，并通过相应实验检验指标选择。本文应把 PBI 标签看作关系学习的监督接口，而不是算法中的一个普通中间变量；实验指标也应直接评价这个接口能否识别未来优质组。

## 三、建议锁定的发布会主线

### 3.1 一句话主张

REMO 式二值 PBI 分组通过清晰边界组织关系样本，但会把同组内具有不同 PBI 质量的解压缩为同一类别；本文以连续 PBI 排序补充组内分辨率，并保留基于参考解的二值边界，通过预算感知组合形成双粒度监督，使关系学习同时获得细粒度次序和粗粒度分组信息。

### 3.2 这条主线为什么是当前最强主线

现有 GoodGroupPrecision 与 DualPBI_Complementarity 正式实验已经提供三层直接证据：

1. **两路信息并非重复副本。** 在 250 次独立运行、10 个 Problem–M 配置和 40 个 Problem–M–Stage 单元上，方向视图与参考解视图的平均 Jaccard 为 0.2326。
2. **两路信息都包含独有优质解。** 33/40 个单元在 Holm 校正后支持双向独有未来真阳性；在两个视图并集覆盖的未来真阳性中，平均 81.5% 只被其中一个视图识别。
3. **混合输出实际使用了两个来源。** Hybrid Top-25% 中，平均 32.2% 来自 V-only 区域，19.6% 来自 A-only 区域；对应未来真阳性来源分别为 36.0% 和 17.9%。

因此，现阶段可以主动、明确地把优势写成：**双粒度监督发现并利用了单一视图无法覆盖的非冗余优质解信息。** 这比笼统宣称“混合一定优于所有单视图”更具体，也与现有正式证据完全对齐。

### 3.3 术语表

| 中文术语 | 英文术语 | 论文中的职责 |
|---|---|---|
| 连续 PBI 评分 | continuous PBI score | 保留当前种群的细粒度排序 |
| 基于参考解的 PBI 二值分组 | reference-solution-based binary PBI partition | 建立粗粒度分类边界 |
| 双粒度 PBI 监督 | dual-granularity PBI supervision | 两路信息的总体方法定位 |
| 预算感知融合 | budget-aware fusion | 随真实评价进度调节两路贡献 |
| 优质组识别 | good-group identification | 机制实验的直接评价任务 |
| 未来留存真值 | future-retention truth | GoodGroupPrecision 的 ex-post 标签 |

---

## 四、可直接使用的中文引言核心段落

### 第 1 段：任务与重要性

昂贵多目标优化需要在极少量真实函数评价下同时逼近 Pareto 前沿并维持解集分布。代理辅助进化算法通常利用已评价解建立回归或分类模型，以减少对昂贵目标函数的调用。与直接预测多个目标值相比，关系学习通过判断解对之间的相对质量筛选候选解，为高维目标空间提供了更轻量的监督形式。然而，关系模型最终能够学到什么，首先取决于当前种群如何被转换为训练标签。

### 第 2 段：已有路线与核心缺口

REMO 采用参考解和自适应 PBI 判据将当前种群划分为两个子群，并据此构造三类关系样本，从而将类别平衡和分布信息引入关系学习 `[REMO]`。这种分组为分类器提供了清晰边界，但同一子群中的所有个体被赋予相同的组级语义：两个 PBI 质量明显不同、却位于同一边界侧的个体，在关系标签中不再具有可区分的组内次序。随着目标数增加和种群覆盖区域持续变化，单一二值粒度难以同时承担类别边界与细粒度优质解识别两项职责。由此产生的关键问题不是如何重新设计一个 PBI 标量化函数，而是如何在保留稳定分组边界的同时恢复被二值化压缩的排序信息。

### 第 3 段：方法与问题的一一对应

为解决这一粒度压缩问题，本文提出双粒度 PBI 监督机制。该机制首先利用种群派生方向计算连续 PBI 评分，以保留个体在当前方向结构下的细粒度次序；随后沿用基于参考解的 PBI 二值分组，以形成适合关系分类的粗粒度边界；最后根据真实评价进度组合两路信号，并通过面向目标数的参考解规模调节二值分支的代表容量。连续评分与二值分组分别承担组内排序和组间分界，二者共同生成关系模型使用的优质组标签。

### 第 4 段：最强证据与贡献

机制分析覆盖 5 个问题、10 和 20 个目标以及 250 次独立运行。方向视图与参考解视图的平均 Jaccard 为 0.2326，且 33/40 个预设 Problem–M–Stage 单元在多重校正后表现出双向独有未来真阳性；在两个视图并集覆盖的未来真阳性中，81.5% 只由其中一个视图识别。进一步的来源分解表明，混合优质组同时吸收了 V-only 与 A-only 区域的候选及未来真阳性。这些结果确立了双粒度设计的经验基础：连续排序与参考解分组提供非冗余的优质解信息，统一监督接口能够将两类信息同时传递给关系学习。

本文的主要贡献如下：

1. 揭示 REMO 式二值 PBI 分组中的粒度压缩问题，将关系标签的组内分辨率明确为昂贵多目标关系学习的关键监督瓶颈。
2. 提出双粒度 PBI 监督机制，以连续 PBI 评分保留组内次序，以基于参考解的 PBI 二值分组建立组间边界，并通过预算感知融合生成最终优质组。
3. 建立面向机制的验证协议，从视图非冗余性、独有未来真阳性和混合来源利用三个层面直接检验双粒度机制，并将其与完整算法的最终性能评价分开报告。

## 五、English introduction draft

Expensive multi-objective optimization aims to approximate the Pareto front while maintaining a well-distributed solution set under a severely limited budget of real function evaluations. Surrogate-assisted evolutionary algorithms reduce this cost by learning from previously evaluated solutions. Relation learning provides a particularly lightweight alternative to multi-output regression because it screens candidates through pairwise quality relations. The usefulness of a relation model, however, is determined first by how the current population is converted into supervision labels.

REMO partitions the current population into two subpopulations using reference solutions and an adaptive PBI criterion, and then constructs three-class relation samples from this partition `[REMO]`. This design introduces distribution awareness and class balancing into relation learning, but assigns the same group-level semantics to all solutions on the same side of the partition boundary. Consequently, solutions with substantially different PBI quality become indistinguishable once they enter the same subpopulation. As the number of objectives and the population coverage change, a single binary granularity must simultaneously provide a class boundary and identify fine-grained high-quality solutions. The central challenge is therefore to recover the ordering information compressed by binary partitioning while retaining its clear relation-learning boundary.

We address this challenge with dual-granularity PBI supervision. A population-derived continuous PBI score first preserves fine-grained ordering over the current direction structure. A reference-solution-based binary PBI partition then provides a coarse boundary for relation classification. The two signals are combined according to the progress of real function evaluations, while an objective-aware reference-solution set adjusts the representative capacity of the binary branch. The continuous and binary components thus serve complementary roles: within-group ranking and between-group partitioning.

Our mechanism analysis covers five problems, 10- and 20-objective settings, and 250 independent runs. The direction-based and reference-solution-based views attain a mean Jaccard index of 0.2326, and 33 of 40 predefined Problem–M–Stage cells exhibit bidirectional unique future true positives after multiplicity correction. Among the future true positives covered by the union of the two views, 81.5% are identified by only one view. Source decomposition further shows that the hybrid good group incorporates candidates and future true positives from both the V-only and A-only regions. These results establish the empirical basis of the proposed design: continuous ranking and reference-solution-based partitioning provide non-redundant information that can be delivered jointly to relation learning.

The main contributions are threefold:

1. We identify granularity compression in binary PBI partitioning as a supervision bottleneck for relation-based expensive multi-objective optimization.
2. We introduce dual-granularity PBI supervision that combines continuous within-group ranking, reference-solution-based between-group partitioning, and budget-aware fusion.
3. We develop a mechanism-aligned evaluation protocol that separately tests view non-redundancy, unique future true positives, and source utilization before assessing complete-algorithm performance.

---

## 六、方法节应该新增的“问题—机制”衔接段

### 中文，可放在当前第 3 节开头

REMO 的 PBI 分组以一个自适应边界将当前种群划分为两个子群，为关系样本提供清晰且相对平衡的类别结构。该边界同时也把每个子群内部的 PBI 差异压缩为同一组级语义，使关系模型无法从标签中直接恢复组内质量次序。双粒度 PBI 监督将这两项职责拆分：连续 PBI 评分负责保留组内排序，基于参考解的 PBI 二值分组负责建立组间边界，预算感知融合则把两种分辨率组织为统一优质组。该设计产生三个可直接检验的预测：两路视图应选择不同的候选集合；两个视图应分别包含独有未来优质解；最终混合组应同时吸收两种来源。

### English, for the beginning of Section 3

REMO uses an adaptive PBI boundary to divide the current population into two relatively balanced subpopulations for relation-sample construction. The same boundary also compresses PBI differences within each subpopulation into a single group-level meaning, preventing the relation labels from expressing within-group quality order. Dual-granularity PBI supervision separates these two roles: the continuous PBI score preserves within-group ordering, the reference-solution-based binary PBI partition establishes the between-group boundary, and budget-aware fusion organizes both resolutions into a unified good group. This design yields three directly testable predictions: the two views should select different candidate sets, each view should contain unique future high-quality solutions, and the final hybrid group should draw useful solutions from both sources.

这段文字只增加方法动机和可检验预测，不需要改动现有任何公式。

---

## 七、实验章节：每个实验只承担一个论证职责

## 4 Experimental studies / 实验研究

### 4.1 Experimental setup / 实验设置

职责：说明问题集、目标数、决策维数、评价预算、独立运行数、随机种子、主指标和统计检验。GoodGroupPrecision 正式协议可直接提供 5 个问题、M=10/20、D=30、N=100、maxFE=500、每配置 25 次独立运行及 Holm 校正等信息。

### 4.2 Overall optimization performance / 总体优化性能

**研究问题：** 双粒度监督进入完整算法后，是否改善有限评价预算下的最终解集质量？

**论证职责：** 只证明算法级最终效果。建议预先指定 IGD+ 或 IGD 为一个主指标，另一个作为辅助指标；与 REMO、PIEA、PC-SAEA、R2AEA、RSEA 及必要的强基线采用同一评价预算和独立运行协议。

**写作模板：**

> 在统一的真实评价预算下，DG-PBI 在 `[问题数量]` 个测试单元中取得 `[待填：统计结果]`，表明双粒度监督能够在完整搜索过程中转化为稳定的解集质量收益。该比较回答算法最终表现问题；后续实验进一步分离收益来自何种监督机制。

这一小节不承担“连续视图和二值视图为什么互补”的证明。

### 4.3 Do the two PBI views contain non-redundant good-solution information? / 两路 PBI 是否包含非冗余优质解信息？

**研究问题：** 连续方向视图与基于参考解的分组视图是否只是同一排序的轻微变体？

**数据：** 现有 GoodGroupPrecision 和 DualPBI_Complementarity 正式结果。

**主指标：**

- Top-25% 集合 Jaccard；
- V-only 与 A-only 候选数；
- 双向 unique true-positive run success；
- UniqueTPShare；
- 40 个预设单元上的 IUT 与 Holm 校正。

**现有结果，可直接写入正文：**

> Across 250 independent runs, the two views showed a mean Jaccard index of 0.2326. Bidirectional unique future true positives were supported in 33 of 40 predefined Problem–M–Stage cells after Holm correction. Moreover, 81.5% of the future true positives covered by the union of the two views were unique to one view. These results show that continuous direction-based ranking and reference-solution-based partitioning expose substantially different high-quality regions of the current population.

**该实验唯一负责的结论：** 两路监督信息具有可重复的非冗余性。这是机制成立的第一环，不与最终 IGD 混写。

### 4.4 Does the hybrid group actually use both sources? / 混合优质组是否真实利用两种来源？

**研究问题：** 融合公式是否真正改变最终优质组来源，而不是形式上加入一个权重？

**主指标：** 将 Hybrid Top-25% 分解为 V∩A、V-only、A-only 和 neither 四类，同时报告候选占比与未来真阳性占比。

**现有结果，可直接写入正文：**

> Source decomposition showed that 32.2% of the hybrid good group came from the V-only region and 19.6% from the A-only region. The corresponding shares among future true positives were 36.0% and 17.9%, respectively. The hybrid group therefore incorporated high-quality solutions that were uniquely exposed by each PBI view, rather than reproducing either single-view selection.

**该实验唯一负责的结论：** 混合输出确实吸收了两种视图的独有信息。它不需要用最终 IGD 作替代证据。

### 4.5 Does budget-aware scheduling outperform static supervision? / 预算调度是否优于静态监督？

这是当前证据链中需要单独补齐的实验，也是最直接回答问题③的实验。

#### 对照组

在相同代码路径下设置：

1. V-only；
2. binary-only；
3. fixed-0.25；
4. fixed-0.50；
5. fixed-0.75；
6. 当前 dynamic schedule；
7. reverse schedule。

除融合权重外，必须锁定种群状态、候选池、DataProcess、归一化、关系模型、回退路径、随机种子和每轮真实评价数量。

#### 最强的隔离验证方式：共享候选池的一步效用实验

在冻结的真实种群快照上，用同一随机种子生成完全相同的候选池。每种监督策略只负责给候选排序；实验离线评价各策略选中候选的并集，并在同一 archive/population 状态下计算一步真实效用：

- Top-q oracle hit rate；
- 进入下一次环境选择种群的 candidate success rate；
- 加入候选后的单步 IGD+ 改善；
- 不同 FE 阶段的配对 win probability 与效应量。

该设计把“产生什么候选”和“如何给候选排序”分开，使所有策略面对同一输入、同一候选和同一真实结果。若 dynamic schedule 在预设主指标上同时优于最佳固定权重和两个单分支，就可以把优势归因于预算调度，而不是搜索轨迹或候选池变化。

#### 独立轨迹消融

共享候选池实验负责局部因果机制，独立完整轨迹负责长期累积效果。随后使用完全相同的 seed 和预算运行上述七个变体，报告最终 IGD/IGD+。两个实验分别回答“单步选择为何更好”和“局部优势能否累积为最终性能”，不能互相替代。

### 4.6 Is the objective-aware reference-solution size necessary? / 面向目标数的参考解规模是否必要？

**研究问题：** 随目标数增长的参考解规模是否改善高维目标空间中的代表覆盖？

**对照：** 固定 k=6、仅改变参考解数、仅改变径向网格分辨率、二者联合改变。由于当前实现中 k 同时影响参考解数量与网格分辨率，必须将这两个因素拆开。

**机制指标：** 参考解覆盖、二值正例率、优质组 Precision/Lift、关系分类 balanced accuracy；最终 IGD+ 作为算法级结果。

### 4.7 Computational cost / 计算成本

职责：报告 DG-PBI 的运行时间占比和不增加真实函数评价这一成本特征。渐近复杂度放在方法节，真实墙钟占比放在实验节。该小节不承担性能证明。

---

## 八、现有 GoodGroupPrecision 结果在论文中的位置

| 现有结果 | 建议位置 | 正文职责 |
|---|---|---|
| 250/250 replay 完整、搜索等价 | 实验设置或补充材料 | 建立数据可信度，不作为方法优势标题 |
| Jaccard=0.2326 | 机制实验 4.3 主文 | 证明两个视图选择区域不同 |
| UniqueSupported=33/40 | 机制实验 4.3 主文 | 证明两个方向都含独有未来真阳性 |
| UniqueTPShare=0.815 | 机制实验 4.3 主文/主图 | 量化非冗余优质信息的强度 |
| Hybrid 来源分解 | 机制实验 4.4 主文 | 证明融合结果实际使用两个来源 |
| 六种 future truth、完整 40 单元表 | 补充材料 | 稳健性和可追溯性 |
| fixed/dynamic 对照缺失 | 新实验 4.5 | 直接检验预算调度，不用最终 IGD 代替 |

建议主图只传达一个消息：左侧显示 V/A 集合低重叠与大量独有真阳性，右侧显示 Hybrid 从 V-only 和 A-only 同时吸收候选与真阳性。完整统计表放入补充材料。

---

## 九、当前文档中的防御性写作：逐处审计与改法

### 9.1 先做文档层面的切分

《方法节_混合PBI_中英文初稿.md》的“骨架评估”“定稿前需要补齐”“建议的实验主张边界”属于作者工作记录，不应与可投稿的方法正文放在同一最终稿中。它们并非科学内容错误，但会让论文呈现为审计报告。建议投稿时只保留中英文方法正文，把这些内容移入作者备忘录。

### 9.2 正文逐处修改

| 位置 | 当前防御性表达 | 发布会式改法 | 处理方式 |
|---|---|---|---|
| 中文 79 / 英文 343 | “需要强调的是，本文不提出新的 PBI 标量化函数” / “DG-PBI does not introduce…” | “本文以常规 PBI 距离和 REMO 参考解分组为基础，提出预算感知的双粒度监督机制，将组内排序与组间边界组织为统一标签。” | 用正面贡献开场，继承关系放在后半句 |
| 中文 91 / 英文 355 | “不意味着二者在统计或几何意义上相互独立” | “双粒度专指监督分辨率：连续分支表达组内次序，二值分支表达组间边界；两者共享当前种群和 PBI 几何。” | 从否定澄清改成角色定义 |
| 中文 103 / 英文 367 | “避免在样本不足时估计不稳定方向” | “在低目标数或小种群状态下采用均匀参考向量，在其余状态下由非支配种群自适应生成方向。” | 强调自适应切换能力 |
| 中文 105 / 英文 369 | “继承覆盖偏差”“不假设提供全局几何” | “种群派生方向聚焦当前已覆盖区域，为连续评分提供随搜索状态更新的局部方向表征。” | 主文保留功能；自关联诊断放补充材料 |
| 中文 149 / 英文 415 | 大段说明“非平移不变”“改变原点可能改变排序” | “方向关联在原始目标空间完成，PBI 距离在理想点平移后的空间计算；全部实验统一采用该坐标约定。” | 主文只写可复现约定；坐标敏感性另设消融或补充材料 |
| 中文 198 / 英文 466 | “不是新的 PBI 参数主张”“不作数学保证” | “参数 δ 作为有符号类别平衡变量，在有界区间内通过二分搜索调节正例比例，并在达到目标区间或搜索容差时终止。” | 直接描述算法行为 |
| 中文 200 / 英文 468 | “只表示……不再区分……不是替代品” | “该信号提供粗粒度组间边界，连续评分进一步确定每个组内的相对次序。” | 用互补职责替代否定 |
| 中文 236 / 英文 504 | “不预先断言”“是否优于需要验证” | “该调度在预算前段强调组内次序，在预算后段强化组间边界；第 4.5 节通过动态、固定和反向调度的受控比较检验这一设计。” | 主动提出机制与验证接口 |
| 中文 277 / 英文 551 | “需要注意，首个权重不是 α=1” | “由于初始种群已消耗 N_init 次评价，实际调度从 α_first=1−N_init/B 开始；实验报告算法实际访问的完整权重区间。” | 保留事实，删除提醒口吻 |
| 中文 303 / 英文 571 | “不把更多参考解必然更好作为结论” | “该耦合设计随目标数同步调整参考解容量和径向网格分辨率，第 4.6 节分别检验两项因素及其交互。” | 从自我限制改成设计—实验闭环 |
| 中文 327 / 英文 595 | “墙钟时间仍应报告”“rather than assumed negligible” | “DG-PBI 不消耗额外真实函数评价；其运行时间占比在第 4.7 节报告。” | 把审稿提醒改成成本优势与证据指针 |
| 中文 3.7 / 英文 3.7 | “方法边界与可验证主张”“只能支持”“需要……才可以” | 投稿正文删除该作者审计段；改为一段“机制预测”，指向非冗余性、来源利用和调度消融三个实验 | 证据边界留在作者 claim–evidence 表，不对读者自我设限 |
| 中文 333 / 英文 601 | 主动列出退化前沿、覆盖不均和方向失真等风险 | “当非支配集合不足或目标范围退化时，算法切换到均匀参考向量，并通过有界类别平衡维持可用监督。” | 在方法中突出回退设计；经实验确认的适用边界再放讨论 |

### 9.3 不能用“发布会原则”掩盖的证据问题

发布会式写作改变的是主线和表达顺序，不改变证据含义。当前最有力的做法不是隐藏不占优的比较，而是把论文主张收敛到真正赢得证据支持的评价维度：非冗余信息、独有未来真阳性和混合来源利用。动态调度是否形成因果增益由第 4.5 节直接测试；在该实验完成前，不把“普遍优于固定权重”设置为摘要和引言的核心比赛项目。

运行内“事后最佳单视图”利用未来真值选择每个 run-stage 的较优视图，属于 oracle 参照，不是可部署算法，因此适合作为诊断上界而非主基线。Anchor margin 也不是生产 Hybrid 的二值输入本身，适合用于视图互补性分析，不宜被写成完全同构的融合消融。这样调整比较口径具有明确的方法学理由，而不是回避结果。

---

## 十、摘要与结论的发布会式记忆点

### 摘要中的一句核心结果

> 在 250 次独立运行和 40 个预设 Problem–M–Stage 单元上，两路 PBI 视图呈现低集合重叠，并在 33 个单元中提供双向独有未来真阳性；81.5% 的并集真阳性仅由其中一个视图识别，表明双粒度监督能够暴露单一分组无法覆盖的优质解信息。

### 结论中的一句记忆点

> 双粒度 PBI 的核心价值在于把二值分组压缩掉的组内次序重新带回关系学习，同时保留参考解边界的清晰类别结构；机制实验表明，这两种分辨率提供了广泛且可重复的非冗余优质解信息。

### English memory sentence

> Dual-granularity PBI supervision restores the within-group ordering compressed by binary partitioning while retaining a clear reference-solution-based boundary; mechanism analysis shows that the two resolutions expose broad and reproducible non-redundant information about future high-quality solutions.

