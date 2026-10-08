# PACDIS 相关工作修订与文献核验

文献检索与初稿日期：2026-10-02；最终检查：2026-10-03。正文：`../HPDC-MaOEA.tex` 的第 2 节。

## 修订范围与筛选口径

将原有三个待补小节写成“代理学习目标 → 监督构造 → 真实评估选择”。这一顺序先解释已有方法保留什么质量信息，再定位 PAQC 与 CDIS 的具体修改。相关工作共引用 14 篇文献；新增 6 篇，其中 5 篇 TEVC、1 篇 TCYB，正式卷期年份覆盖 2021–2026。较早的 K-RVEA、CSEA、RSEA、SDE 等用于交代直接技术来源。

新增文献全部满足指定期刊要求。对保留的其他期刊文献，本次按 **JCR Q1** 核对，不将其等同于中科院一区：Swarm and Evolutionary Computation 的 Q1 信息见[聊城大学论文报道](https://cs.lcu.edu.cn/xyxw/xwdt/644944.htm)；Information Sciences 见[大学图书馆的 JCR 2024 列表](https://kniznica.umb.sk/app/cmsSiteBoxAttachment.php?ID=6178&cmsDataID=0)；Applied Soft Computing 见[武汉大学图书馆期刊记录](https://topj.lib.whu.edu.cn/show.asp?cat=sci&id=4511)。

## 实际阅读的写法参照

下列三篇取得了原文相应段落。文献综述有时位于 Introduction，不能仅按是否有 Related Work 标题判断。

1. **GCS-PSO，TEVC 2024**：阅读 Introduction 与随后预备知识部分，尤其第 1867–1869 页。作者先按回归与分类划分代理方法，再细分排序与关系预测，以学习目标的信息差别引出网格分类。本稿据此先讨论模型究竟预测什么，再讨论标签构造，避免仅按年份列举算法。[作者上传全文](https://www.researchgate.net/publication/376368251_Grid_Classification-Based_Surrogate-Assisted_Particle_Swarm_Optimization_for_Expensive_Multiobjective_Optimization)
2. **EMMOEA，TEVC 2023**：阅读作者稿前 1–3 页的引言综述和 Section II-A。文章先区分目标、标量化量及支配关系等预测目标，再集中解释 infill 准则的选择问题，并用例图说明多个目标的 EI 可能产生冲突。本稿借鉴“学习目标”和“昂贵评估准则”分开讨论的结构；同时准确保留其“目标 GP 生成候选、指标 GP 的 EI 选择评估点”的机制。[作者上传全文](https://www.researchgate.net/publication/367231369_A_Performance_Indicator_Based_Infill_Criterion_for_Expensive_Multi-Many-objective_Optimization)
3. **PC-SAEA，Swarm and Evolutionary Computation 2023**：阅读第 2–4 页 Section 2.1–2.2。其 Related Work and Motivation 从模型输入输出比较回归、分类和成对比较，再把标签构造与预测可靠性连接到自己的设计。本稿以它作为直接的 Swarm 写作参照：每条综述都连接 PAQC 或 CDIS 的设计选择，同时承认它已经联合考虑收敛性和多样性。[作者上传全文](https://www.researchgate.net/profile/Ye-Tian-84/publication/370230896_A_pairwise_comparison_based_surrogate-assisted_evolutionary_algorithm_for_expensive_multi-objective_optimization/links/644799f68ac1946c7a4d0beb/A-pairwise-comparison-based-surrogate-assisted-evolutionary-algorithm-for-expensive-multi-objective-optimization.pdf)

以上借鉴的是论证组织方式；正文没有翻译或复用其段落。期刊参照也不意味着可以据此保证录用，算法贡献与实验完整性仍须独立评估。

## 逐项证据与使用边界

| 文献与正式年份 | 本次证据 | 正文使用的事实 |
|---|---|---|
| [KTA2, TEVC 2021](https://doi.org/10.1109/TEVC.2021.3073648) | [Surrey 作者机构库摘要](https://openresearch.surrey.ac.uk/esploro/outputs/journalArticle/A-Kriging-Assisted-Two-Archive-Evolutionary-Algorithm-for/99771837702346)，并查本地作者算法代码；未通读全文 | 逐目标建模；收敛与多样性档案；按当前需要调整 infill |
| [Dominance Prediction, TEVC 2022](https://doi.org/10.1109/TEVC.2021.3098257) | [作者托管论文](https://www.cs.mun.ca/~banzhaf/papers/expensive2021.pdf)的可检索摘要；本地下载不完整，未按完整全文使用 | Pareto 与 θ 支配分类器、两阶段预选择 |
| [EMMOEA, TEVC 2023](https://doi.org/10.1109/TEVC.2023.3237605) | 上述全文相关段落及 [Surrey 摘要](https://openresearch.surrey.ac.uk/esploro/outputs/journalArticle/A-Performance-Indicator-Based-Infill-Criterion/99771842102346) | 指标模型的期望改进；保留用于搜索的逐目标 GP |
| [GCS-PSO, TEVC 2024](https://doi.org/10.1109/TEVC.2023.3340678) | 上述作者全文、[作者主页](https://qiteyang.github.io/) | 预测网格位置，由此保留收敛与分布信息 |
| [AIEA, TCYB 2025](https://doi.org/10.1109/TCYB.2024.3501360) | [PubMed 摘要](https://pubmed.ncbi.nlm.nih.gov/40030415/)；未取得相关工作全文 | 不同目标评估延迟下的异步选择；影响度与最不确定目标优先。仅作评估设置的边界对照 |
| [Expensive Optimization via Relation, TEVC 2026](https://doi.org/10.1109/TEVC.2025.3542303) | [作者代码库](https://github.com/hhyqhh/Relation/blob/main/README.md)、预印本可检索片段和 [IEEE CIS 卷期目录](https://ieee-cis.blogspot.com/2026/02/)；未通读正式全文 | 已明确区分数据准备、模型训练与使用，不能把这一分解作为 PACDIS 的新框架 |
| [HES-EA, TEVC 2025](https://doi.org/10.1109/TEVC.2024.3440354) | [作者机构库摘要](https://erica.scholarworks.kr/item/8dff53a8-e8da-494b-b263-c41de358720d)、作者主页，以及独立审读时核对的本地 HES_EA.m；未取得全文 | 聚类框架内的成对收敛与多样性模型；不能简化成全算法只有两个模型，也不能把代理搜索内层顺序筛选混同于最终真实评估选择 |
| [PC-SAEA, Swarm 2023](https://doi.org/10.1016/j.swevo.2023.101323) | 上述作者全文 | 标签考虑收敛与多样性；模型验证决定直接、反向或暂停使用预测 |
| [PIEA, Information Sciences 2024](https://doi.org/10.1016/j.ins.2024.121045) | [出版方摘要与引言预览](https://www.sciencedirect.com/science/article/pii/S0020025524009599)，既有本地实现 | 指标学习与分布信息选择；本文指标的既有技术来源 |

新增六篇的题名、作者、卷期、页码和 DOI 已用出版方提交到 Crossref 的元数据核对，快照在 `related-work-sources-2026-10-02.json`。GCS-PSO、HES-EA、关系框架的 online-first 年份分别为 2023、2024、2025；正文使用正式卷期的 2024、2025、2026。

## 创新定位与源码一致性

- PAQC 的定位是融合两类方向质量信息来构造关系训练组。PBI、关系分类器和“数据准备—训练—使用”结构均有直接先例。
- RSEA 的投影用于选代表解；REMO 后续 PBI 比较使用代表解的原目标向量。因此正文只提出代表方向覆盖可能有限，不声称 PBI 在二维投影空间计算，也不宣称已证明投影造成最终性能损失。
- KTA2 已有多因素自适应采样，EMMOEA 已有指标 EI。CDIS 的区别落在关系质量筛选之后的两种评估规则，不能笼统宣称首创指标选择或多准则选择。
- 代码中的模式概率固定，仅在指标模型不可用时回退。正文不称其为基于在线效果的自适应切换。
- 分类概率的模糊性、模型验证可靠性、GP 指标 EI 分别反映不同量，不能互换称为同一种不确定性。
- 核对的当前实现为 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist` 及私有辅助函数。本次没有修改算法或新增实验，也没有据此扩大 IGD/HV 因果结论。

## 验证记录

- 2026-10-03 对最终正文连续编译两遍，均成功，得到 14 页 PDF；没有未定义引用、重复书目键或 Overfull 警告。`git diff --check` 通过。
- 相关工作引用键 14 个，全部在书目中；该节 0 个 TODO。整稿仍有 6 个既有 TODO（作者、摘要、实验协议、收敛图、GGP、结论），本次没有替代未完成实验或补写统计结论。
- 逐页检查新增正文所在第 2–3 页、框架图衔接第 4 页与参考文献第 13–14 页；抽查因分页变化影响的第 5–8 页，并查看后续表格页面。未见本次引入的文字遮挡、截断或引用溢出。
- PDF 的第 11 页存在原有的段间大幅留白。另编译修改前版本，确认原第 10 页已有相同现象；本次保留既有实验排版。日志中的 Underfull 提示不等于没有任何排版待完善项。PDF 解析器的重复 `/Group` 提示也出现在修改前版本，渲染正常。
- 独立审读提出两点：S11/S21，不能把 HES-EA 代理搜索内层筛选写成真实 infill 准则；S3，正文单次出现的 EMMOEA 缩写未展开。已删除前一分句，并将后者改为作者叙述。
- 独立复核通过：上述两项均关闭，本次 Related Work 和新增书目的机械与语义检查零存留问题。核验源文件 SHA256：`B376B36AE4574BF5BD27A2A822836A7DCD73A743EF2697701C61CDCD3E223595`。此结论仅覆盖本次修改，不表示整稿完成投稿准备。

### 作者机械检查原始结果（最终正文）

```text
M1 dashes: 0
M11 passive: 0
M2 antithesis: 0
M3 M4 M8 M9 rhetoric: 0
M6 openers: 0
M5 M16 words: 3
  314: ambiguity-oriented
  315: indicator-oriented
  319: ambiguity-oriented
M10 vague verbs: 0
M17 fancy verbs: 0
M18 empty openers: 0
M12 wordiness: 0
M13 qualifiers: 0
M14 adverbs: 2
  253: pairwise
  319: otherwise
M15 punctuation: 0
Part B precision: 0
S9 cardinality: 0
Wrapped-line passive: []
```

3 个 `-oriented` 命中是全文既有模式名，保留术语一致性；`pairwise` 和 `otherwise` 是正则后缀匹配产生的正常词语命中。未以零命中代替逐项判断。

### 独立复核机械检查原始结果

```text
                           RelatedWork 204-324  NewBibliography 1161-1201
M1-ascii                   0                   0
M1-unicode                 0                   0
M11                        0                   0
M2                         0                   0
M3-M4-M8-M9                 0                   0
M6                         0                   0
M5-M16                     3                   0
M10                        0                   0
M17                        0                   0
M18                        0                   0
M12                        0                   0
M13                        0                   0
M14                        2                   0
M15                        0                   0
Part-B                     0                   0
Decomposition              0                   0

M5-M16 hits:
314:ambiguity-oriented
315:indicator-oriented
319:ambiguity-oriented

M14 hits:
253:pairwise
319:otherwise

Additional checks:
M1-space-dash: COUNT=0
M4-additional: COUNT=0
M11-crossline: COUNT=0
EMMOEA-in-body: COUNT=0
```
