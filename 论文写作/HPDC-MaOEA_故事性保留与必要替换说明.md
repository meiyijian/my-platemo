# HPDC-MaOEA：故事性保留与必要替换说明

日期：2026-09-06  
修改对象：[HPDC-MaOEA.tex](/D:/PlatEMO-master/论文写作/HPDC-MaOEA.tex)  
修改原则：优先保留有解释力的故事、设计动机和两项贡献，只替换与公式、比较对象或已完成证据明显冲突的表述。

本轮基于修改开始时的工作区版本作局部替换，保留此前已有编辑。没有重跑实验，没有改动算法实现、核心公式、参数取值或实验数据。原稿的摘要、引言开场、实验和结论仍有 TODO；这些位置本轮调整的是写作提纲，不表示已完成全文或正式统计审查。原有《HPDC-MaOEA_改动说明.md》保留为历史记录，本文件说明此次新增替换。

## 一、保留的故事主线

关系学习用于昂贵多目标优化时，有两个关键环节：用哪些已评价解构造训练关系，以及选择哪些候选接受真实评价。HPDC-MaOEA 在这两个环节分别提出混合 PBI 分组与双模式候选选择。前者结合连续质量排序与代表解边界，后者在关系引导的搜索基础上，利用探索和指标两种准则构造数量受限的评价批次。整算法比较展示优化表现，机制分析解释训练组与候选批次如何发生变化。

保留原题目、HPDC-MaOEA 名称和“两项贡献”的引言段落。没有把论文改成负结果报告，也没有将候选模块从贡献列表中删除。

| 有意保留的说法或设计 | 保留理由 | 正文采用的落点 |
|---|---|---|
| 连续细排与二值边界结合 | 两者在公式中确有不同职责，是第一项设计的记忆点 | 细化优质组成员的选择 |
| 前后期侧重变化 | 权重与评价进度关联，排序性质可以直接解释 | 前段允许跨标签排序，后段形成二值优先、连续细排 |
| 代表解随目标数增加 | 可以作为覆盖不同区域的设计意图 | 用于提供更细的区域覆盖，不写成覆盖效果的保证 |
| 排序与预算控制分开 | 相对阈值和显式批量上界分别承担不同职责 | 分数负责优先级，上界限制每轮支出 |
| 探索模式与指标模式 | 两种准则有明确且不同的选择语义 | 分别强调批次分散与指标重排序 |
| 以 0.5 概率切换模式 | 可以作为简洁的路由设计保留 | 指标模型可用时，两种模式具有相同选择概率 |
| 模糊度奖励、误差门控、贪婪距离项 | 属于已有算法设计，当前请求不要求删除这些实现选择 | 保留其作用方式，不另行宣称每项都已有独立性能增益 |
| 高目标数下的优化表现 | 已有总实验支持以 10、20 目标配置作为结果重点 | 报告具体配置上的表现，不宣称纯粹由 M 增加造成优势 |

## 二、正文中的必要替换

下表的英文为原句及新句节选；相邻句的完整上下文见修改后的 TeX。

| 位置 | 原句或原说法 | 无法原样保留的原因 | 替换后的表述 |
|---|---|---|---|
| 整体框架 | “All expensive evaluations are consumed in step (v)” | 初始化设计也消耗真实评价，原句遗漏初始化 | “All expensive evaluations after initialisation are consumed in step (v)” |
| 二值标签动机 | “The continuous score orders the population but does not provide a class boundary.” | 连续得分通过阈值或分位数也能分组；不能以连续分数无法分组作为动机 | “The continuous score supplies a fine-grained ordering, while the binary label adds a representative-relative quality boundary.” |
| 代表解数量 | “thereby raising the radial-grid resolution and preserving regional coverage” | 代表解数量与网格分辨率不是同一变量；增加数量也不自动保证覆盖 | “Their number increases with the objective dimension to provide finer regional coverage” |
| 混合分数解释 | “Early in the search, the continuous score has a larger influence on group formation.” | 权重较大不等于实际选择影响一定更大，影响还取决于分数尺度和分布 | “The budget-dependent weighting connects fine-grained quality ranking with representative-based group priority.” |
| 类内排序条件 | “S_i continues to rank solutions assigned the same label.” | 当 FE 达到总预算时，连续项权重为零，类内细排不再由混合分数保留 | “S_i refines the within-label order at each training step with FE < FE_max.” |
| 命题后的调度叙事 | “the continuous score has more influence early ... the binary ... receives more influence as the budget is consumed” | 原句没有说明后半程已经固定为组间二值优先的排序结构，容易被理解为权重仍持续改变选择 | “For t < 1/2, the continuous score can affect ordering across the binary boundary; for 1/2 ≤ t < 1, binary-positive solutions take priority and the continuous score refines the order within each label.” |
| 调度实验交叉引用 | “tests whether this schedule improves ... relative to ... alternative-schedule variants” | 未找到能够兑现该性能比较承诺的完整结果；已有离线分析还记录了 SCHEDULE_REDUNDANT | “examines the resulting group composition and its association with subsequent solution retention” |
| 排序与预算 | “scores ... no longer decide how much of the budget one iteration consumes” | 批量公式仍依赖保留集合大小；有上界不等于批量完全与分数无关 | “Scores determine candidate priority within this bound; the retained-set size and remaining budget determine the feasible batch size.” |
| 分位数筛选 | “quantile rules convert scores of any scale into within-pool ranks” | 分位数机制本质上是相对阈值，不能消除上游加权、并列值等所有尺度问题 | “quantile rules define thresholds relative to the current score distribution” |
| 共享冻结池实验 | “additionally uses a shared frozen pool to isolate the ranking contribution” | 当前 CMC 结果目录未找到完整阶段科学判定，不能把计划写成已开展的证据 | “examines how the two criteria change the selected batches and the resulting search performance” |
| 随机流实现说明 | “drawn from a stream seeded from the run index and independent of ... variation and subsampling” | 不属于两项贡献的叙事信息，且会引入版本实现细节 | 仅保留 “With u drawn uniformly from [0,1)” 的数学定义 |
| 等概率切换 | “giving them equal prior exposure without an additional calibration layer” | 指标模型不可用时执行探索模式，整体执行比例不保证相等；校准层的说法也不够具体 | “giving them equal selection probability when the indicator surrogate is available, without requiring their scores to be combined into a single ranking” |

### 一个随文修正的证明端点

原证明用 `H_i = (1-alpha) + alpha*S_i > 1-alpha` 覆盖所有 `alpha ≤ 1/2`，但这一步严格不等式在 `alpha=0` 不成立。命题结论本身仍成立。本轮补上 `alpha=0` 时 `H_i=1>0=H_j`，再对 `0<alpha≤1/2` 使用原证明。没有改变混合公式或算法行为。

后期排序性质只针对同一快照讨论：固定 S、L 后，在 `0<alpha≤1/2` 内改变权重不会改变该快照的排序。搜索继续进行时 S、L 和种群可以变化，因此不能把这一性质写成“后半程的优质组恒定”。正文保留前后期排序结构的正面解释，没有扩展成算法失败叙事。

## 三、摘要、引言与实验提纲的替换

| 位置 | 原提纲重点 | 本轮替换 | 写作收益 |
|---|---|---|---|
| 摘要 | 先列分组精度、候选成功率，再用 IGD 收束 | 问题与两项设计保持在前；结果先给最强且已核实的整算法比较，再给一句机制发现 | 将最能体现优化算法价值的证据放在前面 |
| 引言开场 | 二值关系标签不能区分同标签解 | 明确是优质组构造缺少类内排序信息 | 保留“粗粒度信息不足”的动机，同时不承诺网络能学习最终同组解之间的排序 |
| 实验设置 | 固定写 M={3,5,10,20}、IGD/IGD+/HV 和 Holm | 根据最终保留数据填写维数、预算、指标及检验；明确 FE=300 候选探针与 FE=500 分组实验 | 不把尚未统一的结果写成同一套协议，不提前承诺未核实指标 |
| 整算法比较 | 预列 REMO、PIEA、PC-SAEA、R2AEA、RSEA 等算法 | 以实际有合格结果的基线为准；突出 10、20 目标，跨 M 比较采用共同基线 | 保留高目标数定位，避免把基线集合和 D 变化包装成 M 的因果效应 |
| 双模块消融 | 预列同宿主同 k 的完整比较 | 使用现有匹配对照；缺臂明确标注；区分组件移除与交互检验 | 保留双贡献设计，不把不完整因子组合说成已证实协同增益 |
| 分组主比较 | binary-only、continuous-only、hybrid 直接比较 Precision | 等配额比较明确为 score_hybrid、score_v、anchor_margin；自然二值组单独报告 | 防止把自然正类比例与固定 Top-25% 混作同一比较 |
| 分组实验叙事 | 33/40 独有信息结果解释融合价值 | 保留 33/40；增加总体 Precision，并同时交代严格同时优于两个视图为 1/40 | 保留信息来源差异的故事，不把它升级为普遍融合性能优势 |
| 分组调度 | 要求动态与固定、反向调度进行比较 | 调度首先用排序命题解释；性能比较待有对应结果再加入 | 设计动机仍成立，不虚构实验已经支持调度更优 |
| 候选实验 | 主要列存活率、增益比的正结果 | 保留这两项正向观察，加入批次分散度、V4/V0 与 V4/V1 的分别解释，以及分问题最终结果 | 不让存活率代替优化质量，也不因 V4/V1 未显著而把整个模块直接判为无用 |
| 阈值审计与反事实 | 400 runs、5.1 倍、3.1 倍及共享冻结池实验 | 当前提纲暂不沿用这三个数；保留固定阈值动机，待匹配完整结果表后填入 | 保留故事，不将未找到来源的数字写成已确认结果 |
| 结论 | “two main findings”并强调直接机制改善 | “two design contributions”，接整算法主要结果，再关联组构成和批次行为 | 两项贡献保持突出，不强求两者都被独立证明提升最终性能 |

## 四、已有结论如何进入论文

### 1. 可以保留的正向结果

- 以已有 10、20 目标整算法比较组织主要结果；最终数字仍需与所写算法版本及协议对应。
- 原五问题 250-run PBI 补充结论报告的总体 `population_final` Precision@25%：Hybrid 0.28698、方向得分 0.27748、Anchor margin 0.27617。
- 33/40 个预设单元支持双向独有未来真阳性信息。正文提纲仍保留该结果，但与严格融合优势 1/40 一并解释。
- CVP 报告 V4 对 V0 的配对 IGD p 值为 0.008；保留这一整体选择策略比较，不将 V0 称为完整原版 REMO 算法。
- CVP 中 V4/V1 的后期保留率为 0.770/0.706，后期增益比约为 0.105/0.086，均保留为批次层面的观察。

### 2. 没有采纳的过度负面解释

没有沿用“p=0.375 所以净效应为零”“探索分支没用”“混合只是稀释危害”“CSR 已被彻底证伪”“WFG3 已确定由 RSEA 投影造成”等结论文档措辞。没有确认优势与已经证明无效不同；相关现象也不等于已经完成原因归属。

本文继续将两种模式写成具有不同选择职责的设计。V4/V1 的最终 IGD 未确认总体优势这一结果应保留在相应实验解释中，但不据此删除候选模块的设计贡献。

### 3. 数值来源与使用范围

本次采用的是已存在的结论和汇总，没有重新计算原始轨迹或统计检验。CVP 中引用的 0.008、0.375 是结论文档报告的配对检验值，本轮未将其标成 Holm 校正后的结果。GGP 主协议虽已扩展到十问题，本文引用的互补性数字仍限定为原五问题、250 次运行。

## 五、参考的本地材料

- [总实验结论](/C:/Users/lsx/Desktop/AdaMao实验表/最新版算法总实验/总实验结论.md)
- [双模块消融表及其待核实标注](/C:/Users/lsx/Desktop/AdaMao实验表/消融实验/两个模块的消融实验/ablation_tables.tex)
- [PBI 补充实验结论](/D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_GoodGroupPrecision/DualPBI_Complementarity/results/analysis/formal/DPC_CSV_Analysis_Conclusion_CN.md)
- [GoodGroupPrecision 指标说明](/D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_GoodGroupPrecision/README.md)
- [候选价值探针结论](/D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_CandidateValueProbe/docs/实验结论.md)
- [CandidateModeContribution 说明](/D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_CandidateModeContribution/README.md)
- [标签调度分析决策](/C:/Users/lsx/Desktop/AdaMao实验表/Stage2_LabelCausalAblation/screening/analysis/Stage2_decision.csv)

## 六、验证记录

- 最终版本通过两轮 `pdflatex -interaction=nonstopmode -halt-on-error` 编译，生成 6 页 PDF。
- 编译日志没有越界行（Overfull）、未定义引用或 LaTeX Warning；仍有双栏排版的欠满行提示，未将编译成功解释为视觉逐页审查。
- `git diff --check` 通过；Git 的 LF/CRLF 提示不属于内容或空白错误。
- 对照本轮修改前快照，16 个编号公式、1 个不编号公式、2 个算法及其伪代码、1 个命题的内容保持一致；命题证明仅修正零权重端点。
- 引言的两项贡献段落逐字保留；中文稿及原有改动说明没有在本轮被修改。
- [更新后的 PDF](/D:/PlatEMO-master/论文写作/HPDC-MaOEA.pdf) 仍含原稿的 TODO 占位，本轮交付为故事性保留与必要替换后的草稿。
