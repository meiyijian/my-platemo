# PACDIS 引言修订与证据核验

日期：2026-10-03。范围：`../HPDC-MaOEA.tex` 第 1 节 Introduction。
使用 paper-writing 技能的引言结构清单、机械与语义检查、独立审读流程，并用 PDF 技能检查排版。

## 写法参照

重新阅读了上一轮已核验文献的引言。新增引用均复用当前书目，没有为了增加文献数量而继续扩张检索。

| 原文 | 本次实际阅读 | 采用的组织方式 |
|---|---|---|
| [PC-SAEA，Swarm and Evolutionary Computation 2023](https://doi.org/10.1016/j.swevo.2023.101323) | 作者稿第 1–2 页 Introduction | 从昂贵评估约束推进到模型输出及模型使用，把两个设计问题分别连接到贡献。本文以监督构造与评估分配组织动机，保留 REMO 的既有关系模型。 |
| [GCS-PSO，TEVC 2024](https://doi.org/10.1109/TEVC.2023.3340678) | 正式页码 1867–1869 的 Introduction | 先说明代理预测目标，再指出目标保留哪些选择信息。本稿只写代表方向可能覆盖不足，不照搬“分类方法普遍忽略多样性”的广泛批评。 |
| [EMMOEA，TEVC 2023](https://doi.org/10.1109/TEVC.2023.3237605) | 作者稿前 1–3 页的 Introduction | 将候选搜索与真实 infill 分开论证，明确评估点究竟依据什么量选择。本稿承认已有指标 EI 和多准则 infill，不把这些概念本身当作创新。 |

原文访问入口及上一轮文献元数据见 [相关工作核验说明](related-work-revision-2026-10-02.md)。借鉴的是论证顺序，没有翻译或复用原文段落。此次写作质量判断落在问题具体、近邻比较准确、贡献与证据对应、语言可读四项上，不将期刊名称当作可自动认证的质量分数。

## 引言的论证顺序

| 段落职责 | 修改要点 |
|---|---|
| 应用与问题 | 用近期 TEVC 文献中的翼型设计、电力电子电路优化说明昂贵评估约束，再解释多目标数对选择的影响。移除“100 个体只能再跑四代”的预算算例，避免用本文配置代替领域背景。 |
| 研究现状 | 用预测目标概括逐目标回归、指标、网格标签和成对比较；细分综述保留在 Related Work。 |
| 最近框架 | 交代 REMO 的组、训练对和候选分数，并引用 2026 年关系模型框架，承认数据准备、训练与使用这一分解已有先例。 |
| PAQC 动机 | 少量代表方向可能缺少对当前非支配方向的单独质量评价；同一代表标签内仍可能存在方向质量差别。该动机不等同于已证明的性能损失。 |
| CDIS 动机 | 区分预测质量、分类概率的明确程度及另一种指标评价，说明为何在关系质量筛选后使用不同准则。 |
| 方法直觉 | 一个段落介绍 PAQC/CDIS 及固定概率切换，与框架图对应；不加入公式、阈值或候选累积细节。 |
| 贡献 | 保留两项方法贡献，去掉“Comprehensive experimental validation”等笼统措辞。实验覆盖与结果预告单独陈述。 |
| 结果与路线图 | 提供主表中能复核的平均值结果，再指向完整变体比较、模式概率实验与后续章节。 |

## 源码与结果核验

- 当前实现仍为 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`。本次只读其主入口和私有函数，没有修改算法或评估逻辑。
- `PBIQualityClassification.m` 将连续方向评分与代表标签按评估进度融合，再确定正组。非支配方向不可用时有均匀方向回退，所以正文限定为可构造时使用。
- 原 REMO 的 `RSurrogateAssistedSelection.m` 聚合关系概率并按分数阈值或排名选候选；没有单独的分类模糊性奖励或另一指标准则。引言将缺口限定于这一用法，不断言所有关系模型缺少不确定性处理。
- CDIS 的两种模式均先筛关系质量；模式概率固定，指标模型不可用时回退。分类模糊性仅表示预测不明确，没有将其写成经校准的认知不确定性或保证的信息增益。
- 重新读取 `experiments/main_performance/igd_snapshot.csv`：48 个问题—目标数配置，每个配置 7 个算法。按十进制原始均值重新取行内最小值，PACDIS 在 10/15/20 目标下分别有 **7/5/4** 个最低均值，合计 **16/48**。DTLZ4、DTLZ6、WFG2、WFG7 在三个目标数下均符合。
- 该结果是当前表格的描述性均值比较，不表示 16 个经多重比较校正的显著胜出。主文已说明部分基线的有效运行数不同；引言没有声称统一完成 20 次运行。
- 500 次是主比较的配置预算，实际终止 FE 仍以实验部分的核验边界为准。变体对照实验使用另一个配置预算；引言将其表述为单独实验，没有据此宣称已确认两个模块的独立因果贡献。独立审读指出，名为 w/o CDIS 的控制仍保留模糊性准则，实际删除指标模型、指标准则及切换，因此引言改用 algorithm variants，避免暗示完整删除整个 CDIS。

## 检查记录

- 最终引言从 627 个词调整为 767 个词（去除引用键及排版命令后计数，含结果数字）；新增篇幅用于最近框架定位、两项动机的衔接和可核实的结果预告。平均句长 16.3 词，最长句 29 词。
- 最终版本连续编译两遍通过，PDF 14 页；6 个实际参与编译的 TeX 文件无未解析引用、重复标签或重复书目键。编译日志无错误、未解析引用或 overfull 警告；18 种 PDF 字体全部嵌入。
- 引言 0 个 TODO；整稿原有 6 个 TODO 保留。没有修改作者、摘要、方法、实验或上一轮的相关工作正文。
- 最终 PDF 第 1–3 页已渲染检查：引言、贡献列表与相关工作衔接正常，无文字裁切。前轮还检查了第 4–6 页图文排版；最终框架图仍位于第 5 页。
- 独立审读状态 CLOSED/CLEAN：本次引言范围内 0 CRITICAL、0 MAJOR、0 存留 MINOR。审读核对的源文件 SHA256 为 `F8CE2310B659C2798EB79B41ACBF2C08BA1A2D0E7BC2F28912D8392E25D7219B`。
- F1 已关闭：将完整 CDIS 删除对照的暗示改为算法变体比较；F2 已关闭：首次出现时展开 RSEA。新增桥接句说明同组关系标签与方向质量差异的联系；将后续 PBI 比较句的主体明确写为 REMO，关闭指代问题。结论仅覆盖此次引言修订，不代表全文既有实验 TODO 已完成。

### 作者机械扫描原始结果（最终稿）

```text
M1 dashes: 0
M11 passive: 0
M2 antithesis: 2
  168: not d
  174: not a
M3 M4 M8 M9 rhetoric: 0
M6 openers: 0
M5 M16 words: 3
  195: ambiguity-oriented
  196: indicator-oriented
  199: ambiguity-oriented
M10 vague verbs: 0
M17 fancy verbs: 0
M18 empty openers: 0
M12 wordiness: 0
M13 qualifiers: 0
M14 adverbs: 2
  139: pairwise
  199: otherwise
M15 punctuation: 0
Part B precision: 0
S9 cardinality: 0
Wrapped-line passive: []
```

两处否定句分别陈述训练目标与评估分配的具体机制边界，均已核对源码；两个 `-oriented` 模式名遵循全文既有术语；`pairwise` 和 `otherwise` 是正常词语的后缀匹配。逐项说明命中原因，不将正则命中数直接当作写作质量结论。

### 独立审读者机械扫描原始结果（最终稿）

审读者直接从技能文件提取 Part C 正则，对最终引言第 118–231 行独立执行，命中行与上方作者扫描一致。

```text
M1-ascii             matches=0; lines=0
M1-unicode           matches=0; lines=0
M1-spaced-extra      matches=0; lines=0
M11                  matches=0; lines=0
M2                   matches=2; lines=2
M3/M4/M8/M9           matches=0; lines=0
M6                   matches=0; lines=0
M5/M16               matches=3; lines=3
M10                  matches=0; lines=0
M17                  matches=0; lines=0
M18                  matches=0; lines=0
M12                  matches=0; lines=0
M13                  matches=0; lines=0
M14                  matches=2; lines=2
M15                  matches=0; lines=0
Part B               matches=0; lines=0
Decomposition        matches=0; lines=0
```
