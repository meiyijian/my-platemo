# HPDC-MaOEA 伪代码规范性审查

审查日期：2026-09-07。对象：`HPDC-MaOEA.tex` 当前工作区版本。本文仅审查伪代码及其直接相关的正文、公式和实现，不构成整篇论文的投稿质量评审；未修改原 TeX。

## 1. 结论

**基本排版形式合格，但目前不能认为两段伪代码已经完全规范。最应修正的是执行顺序、计数语义和模块接口，而不是更换 LaTeX 宏包。**

- Algorithm 1：总体步骤清楚，但 FE 初始化与递增缺失，初始化规模与后续种群规模的关系不清，子过程调用缺少模型输入。
- Algorithm 2：存在先使用后确定批量大小的问题；生成计数与集合大小混用；正文中的最小批量补齐未写入；空池返回与父代保留数量不完整。
- 表达层面：主算法与正文的模式抽取顺序不一致；指标模型训练数据范围需要明确；可以增设简短的 HybridGroup 算法框，使两个贡献都能被直接追踪。
- 实际 PDF：算法框没有明显裁切或跨栏重叠，但 Algorithm 1 的两处章节注释断到下一行，影响阅读。

## 2. 参照文献与使用边界

这里将用户所说的 “swarm” 理解为 **Swarm and Evolutionary Computation**。以下依据是已发表论文的算法表达惯例，不将其描述为期刊对宏包、字号、行数或算法数量的强制规范；本次未核验特定年份的中科院/JCR分区。

| 文献 | 本次核查位置 | 对本稿有用的写法 |
|---|---|---|
| Ye Tian et al., *A pairwise comparison based surrogate-assisted evolutionary algorithm for expensive multi-objective optimization*, 80 (2023), 101323 | 作者公开全文 PDF 第4页 Algorithm 1、第7页 Algorithms 5–6 | 显式初始化和递增 FE；主算法将模型传入生成子过程；生成步骤写出父代保留数量。最接近本稿的代理辅助关系比较框架。 |
| Raunak Sengupta et al., *NAEMO: Neighborhood-sensitive archived evolutionary many-objective optimization algorithm*, 46 (2019), 201–218 | 期刊页206（PDF第6页）Algorithm 1及其模块引用 | 主框架结合公式引用和独立子算法，明确迭代、档案更新与模块职责。与本稿的高维多目标、档案和模式切换表达相关。 |

来源：

- [PC-SAEA 出版社页面与 DOI](https://www.sciencedirect.com/science/article/pii/S2210650223000962)
- [PC-SAEA 作者公开全文](https://www.researchgate.net/profile/Ye-Tian-84/publication/370230896_A_pairwise_comparison_based_surrogate-assisted_evolutionary_algorithm_for_expensive_multi-objective_optimization/links/644799f68ac1946c7a4d0beb/A-pairwise-comparison-based-surrogate-assisted-evolutionary-algorithm-for-expensive-multi-objective-optimization.pdf)
- [NAEMO 作者所在机构公开全文](https://me.iitp.ac.in/~sriparna/papers/naemo.pdf)

PC-SAEA 的公开稿自身也有不够严密的计数表述，不能把其中所有条件机械移植到本稿。尤其本稿强调严格昂贵评估预算，应保留自己的剩余预算截断机制。

另检索到 SA-PPS（2024, 91, 101728），但全文读取失败，因此未把它的算法细节作为本次判断依据。期刊作者指南页面也未成功读取，本文不声称验证过期刊专门的伪代码格式条款。

## 3. 必须优先处理的问题

以下“源行”均指本次检查的 TeX 行号；“算法行”指 PDF 算法框内的行号。

### A1. FE 在循环前未赋值，真实评估后未递增

- 位置：Algorithm 1 算法行1–4、17–19；源行210–215、238–241。
- 现状：直接使用 `while FE < FE_max` 和 `t = FE/FE_max`，但算法框没有 FE 初始化及更新。
- 问题：即使读者知道 FE 是累计评价数，独立阅读该算法也只能依赖未声明的隐式副作用。特别是进度 t 同时控制两个核心机制，更新不可含糊。
- 建议：初始化评估后写 `FE ← N_init`；每次实际评估后写 `FE ← FE + |S|`，此处 S 必须是预算截断后的批次。
- 源码边界：PlatEMO 的 `Problem.Evaluation` 管理计数。这是论文伪代码的缺项，不能据此声称 MATLAB 程序没有更新 FE。

### A2. n_b 先使用、后确定

- 位置：Algorithm 2 算法行11、14、16；源行635–643。
- 现状：两分支先选取 n_b 个解，最后才写 “Bound n_b …”。
- 问题：n_b 未在选择前赋值；事后修改 n_b 并不等于已经修改返回批次 S。Algorithm 1 的最终截断可以保护整体昂贵预算，却不能补全 Algorithm 2 自身的程序语义。
- 建议顺序：**形成 H → 不足时补齐 → 计算 n_b → 选择 S → 返回 S**。
- 推荐职责划分：与当前实现一致，让子过程计算 `n_b ← min(n_max, |H|)`，由主算法在真实评估前统一执行剩余预算截断。删去子过程末尾的预算限制语句。
- 如果选择在子过程内部截断，则必须将剩余预算作为输入，并在选择 S 之前使用；两种写法不要混用。

### A3. 用集合大小控制累计生成数，语义与源码不一致

- 位置：Algorithm 2 算法行1–7；源行621–629；正文源行489–491。
- 现状：循环条件为 `|A| < g_max`，池更新为 `A ← A ∪ Q`，循环后又对 A 去重。
- 问题：数学集合的并集已经不保留重复项，因此 |A| 统计的是不同候选数；正文和源码控制的却是累计生成数量。候选反复重复时，集合不增长不能保证循环退出。循环内最后生成的 Q 也可能在下一次条件检查时被排除在池外，造成额外且未入池的一批生成。
- 源码事实：`private/AdaMaOSelection.m` 第55–80行先保存初始后代，用 `i = i + size(Next,1)` 累计生成数，将每批新后代立即追加到列表，最后统一去重。
- 建议：用独立计数器 c 记录生成数；用列表 B 暂存所有候选；结束后令 A = Unique(B)。若每批整批生成，g_max 是停止阈值，最后一批可以越过阈值，不能额外声称严格不超过 g_max。

### A4. 正文中的最小批量补齐未进入伪代码

- 位置：Algorithm 2 算法行10–14；源行633–641。对应正文源行543、578–579、607–608。
- 现状：正文规定不足 n_min 时补齐，算法框直接用分位筛选后的集合选批次。
- 问题：这会改变每轮评估数量，是本文批量控制机制的一部分，不宜从伪代码中省去。
- 建议：两个分支分别形成 H 后，写明按各自得分补足至 `min(n_min, 可用候选数)`。指标模式的可用候选应来自关系粗筛后的子集；探索模式来自完整候选池。
- 源码对应：选择器第165–176、230–243行确实先补齐，再确定数量，再挑选。

### A5. 空池返回必须先于分位数与贪心计算

- 位置：Algorithm 2 源行629–638；Algorithm 1 源行234–237。
- 现状：主算法有 `S = ∅` 后备操作，子过程没有 `A = ∅` 时直接返回空集的分支。
- 问题：子过程会先进入分位数、排序或贪心计算，未保证能返回主算法预期的空集。
- 建议：去重后立即加入 `if A = ∅ then return ∅`。保留主算法已有的直接变异后备步骤。
- 源码对应：选择器第75–77行已经有空池提前返回。

### A6. 子过程输入与调用不一致

- 位置：Algorithm 1 源行226–233；Algorithm 2 输入源行618–619。
- 现状：Algorithm 2 声明需要关系和指标代理，但 Algorithm 1 调用只传 P、R、m、t、e_r；关系模型还依赖训练组及预处理信息。
- 问题：读者无法由调用明确知道训练后的模型和参考组如何到达选择模块。
- 建议：用简短统一的模型记号，例如 M_R、M_I。注明 M_R 包含预测所需的分组参考数据及预处理，再把二者显式传入调用。也可以使用一个定义清楚的代理状态对象，但不要暗中依赖全局变量。
- 其他参数：N_init 应作为输入或由明确初始化规则得出；g_max、n_min、n_max 等可在算法输入或紧邻文字中统一声明。无需为此恢复庞大的超参数表。

## 4. 正文与实现的一致性问题

### B1. N_init 与 N 未区分完整

源行208–213引入 N 和 N_init，却未定义后者的取值；源行179–180又把当前种群描述成固定大小 N。所查实现初始化大小依赖 D，后续通过 `RefSelect(Archive, Problem.N)` 控制种群，两者不必相同。

建议明确初始化规则，并将迭代中的实际种群大小记为 `N_t = |P|`，或说明方法小节里的 N 表示当前 |P|。不要仅为对齐文字就在初始化后新增环境选择，这会改变首轮训练数据。

### B2. “keep the best of them”没有给出保留数量

源行625–626仅说保留最好的父代。源码保留 `min(|R|, |Q|)` 个候选（选择器第63–67行）。这决定后续内循环规模，应直接写出，且不需要引入新调参项。

### B3. 模式抽取与候选生成的先后顺序不一致

总体正文源行187–188的自然阅读顺序是“先积累候选池，再抽取模式”，但 Algorithm 1 源行230–232以及当前源码都是先决定模式，再调用内搜索。源行491–493又明确模式相关的关系聚合会影响池构造。

建议将总体正文改为“先抽取模式，再执行该模式下的关系引导内搜索并选择批次”。同一池构建规则不表示两种模式在独立闭环运行中得到完全相同的具体候选池。

### B4. 指标模型究竟用 P 还是全部档案训练

总体正文源行185写 “every evaluated solution”，Algorithm 1 源行228写 “on the evaluated solutions”，容易被理解为整个 A_rc。式(14)仅有 N 个训练样本，当前源码第53–60行实际使用 Population 的决策变量和适应度。

建议把训练步骤改为明确的“在当前已评估种群 P 上计算指标并训练 M_I”；不要未经源码核对写成使用全部累计档案。

### B5. 指标模式分位规则不够准确，另有小池规则遗漏

源行634的 “keep its top quantile” 没写出 q_ind，也不清楚指最高多少比例。建议显式定义关系粗筛集合 B_ind，并写：

`H_ind = {x ∈ B_ind : I_hat(x) ≥ Q_q_ind(I_hat(B_ind))}`。

这样避免把分位点0.7误读成保留前70%；在无并列等通常情况下，它对应保留约最高30%。

另外，源码第210–211行的关系粗筛保留量是 `min(|A|, max(20, ceil(0.30|A|)))`，正文与算法只写比例。小候选池时两者不同。可用一句“with a minimum retained-set size when available”交代机制，在复现设置注明常数，不必把所有常数堆进主算法输入。

### B6. 无关系对时 continue 没有给出进展保证

源行221–224在没有训练对时，仅从不变档案重新选择 P，然后 continue；FE和档案均不变。如果相同无效状态持续出现，可能反复跳过真实评估。

所查源码也保留这个分支，因此不能把它直接归为“论文误抄”。正常规模和有效分组下是否会进入该分支，本次未运行实验验证。建议在论文中明确有效输入/非空训练集前提；若希望覆盖异常情况，应在实现与论文中同步采用能推进或明确终止的后备规则。不能只修改论文就宣称程序已解决此问题。

## 5. 排版与组织建议

已检查现有 PDF 第2页和第5页的完整页面：

1. `algorithm + algpseudocode`、置顶标题、Input/Output、连续行号、赋值箭头及结构缩进可以保留。数学符号配合简短英语动作也符合所读同刊论文的常见表达方式。
2. Algorithm 1 算法行10–11的 `\Comment{Section...}` 将三角注释标记留在右端，章节名挤到下一行。建议将章节引用放到正文或缩短动作行；不建议继续整体缩小字号。
3. Algorithm 2 的“模型重排、分位筛选、集合赋值”挤在同一长行，可以拆为两行以提高可读性。
4. 主算法只声明 Output 但没有显式 Return，并非必然错误；末尾加 `Return A_rc` 可以与子算法统一。
5. 当前实际只有两个算法框。建议增加一个约8–12个逻辑步骤的 **Hybrid PBI-based quality grouping**，展示“方向与代表解 → 连续分数与二值标签 → 融合 → 排序分组”，已有公式继续引用即可。**这是突出贡献与便于复现的建议，不是期刊必须要求三段伪代码。**
6. 用 `Algorithm~\ref{...}`、`\eqref{...}` 和短小的过程名保持交叉引用；无需统一强制每行加分号，关键是全文一致。

已有编译日志未发现 Overfull 提示，但存在实验小节 `sec:exp:hpc`、`sec:exp:candidate`、`sec:exp:sensitivity` 的未定义引用。这些不是两段伪代码的标签错误，正式交稿时仍需修复。本次没有重新编译或覆盖现有 PDF。

## 6. 最小修改的顺序示意

下列是修改指导，不是已写回论文或已运行验证的替换算法。

### 主算法关键位置

```text
Evaluate the initial design
FE ← N_init
Archive ← initial evaluated population
while FE < FE_max do
    t ← FE / FE_max
    Form the hybrid groups and representatives
    Train M_R and obtain e_r
    Train M_I on the current evaluated population P
    Draw mode m according to Eq. (15)
    S ← DualModeSelection(P, R, M_R, M_I, m, t, e_r)
    If S is empty, apply the existing variation fallback
    Keep at most FE_max − FE candidates in S
    Evaluate S and append the evaluated solutions to Archive
    FE ← FE + |S|
    Update P by environmental selection
end while
return Archive
```

这里的 `DualModeSelection` 仍需在输入或相邻文字中声明 g_max 和批量控制参数。无训练对的异常策略应按 B6 处理，不能把上面的常规流程当作已经覆盖所有边界条件。

### 候选生成与批次选择关键位置

```text
Q ← Variation(P, R)
B ← Q                         // B is a list, preserving duplicates
c ← |Q|                       // cumulative number generated
while c < g_max and Q ≠ ∅ do
    Score Q with the mode-specific relation aggregation
    Parents ← best min(|R|, |Q|) candidates in Q
    Q ← Variation(Parents, R)
    Append Q to B
    c ← c + |Q|
end while
A ← Unique(B)
if A = ∅ then return ∅

if m = ind then
    Form the relation-screened subset
    Form H using the q_ind quantile of predicted indicator values
    Complete H to n_min from that subset when possible
    n_b ← min(n_max, |H|)
    S ← the n_b highest-indicator candidates in H
else
    Compute A_exp and form H using the q_keep quantile
    Complete H to n_min from A when possible
    n_b ← min(n_max, |H|)
    Select the first candidate by maximum A_exp
    Add the remaining candidates greedily by Eq. (13)
end if
return S
```

本示意将剩余昂贵预算截断统一留在主算法；空代表集等异常前提仍需由方法定义或实现后备规则保证。若要求与当前实现细节完全一致，还应保留指标粗筛的最小保留量，以及候选数不超过批量上限时直接按得分输出的既有分支。

## 7. 实际核查的源码身份与范围

本稿没有在正文完整固定实现版本。本次通过 `figures/build_figures.py` 第29行确认其当前图件构建所指向的算法目录，并以该目录为实现参照：

`D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/`

核查文件：

- `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m`：初始化、模型训练、模式选择、预算截断、档案更新。
- `private/AdaMaOSelection.m`：累计生成、去重、补齐、分位筛选、批量大小、贪心选择。
- `private/HybridPBI_Classification.m`、`private/GetRelationPairs.m`：分组和训练对相关上下文。

因此，报告中的“源码一致/不一致”限定于这一已定位版本；本次没有重新审计全部实验的版本归属，也没有开展算法性能实验。伪代码逻辑问题已通过当前 TeX、正文公式及相应控制流程逐项核对。
