# 候选解模块术语核查与 EA 化替换

> 核查对象：`方法节_候选解模块_中英文初稿.md`。  
> 核查原则：名称只描述源码实际执行的操作；不把普通组合策略命名为新范式，不把分类器输出解释为校准不确定性，不把贪心参照解释为全局最优。

## 一、核查结论

原稿中有 11 类术语需要收紧。其中风险最高的是 `scale-adaptive`、`front-shape-aware indicator`、`predictive uncertainty`、`independent ranking signal` 和 `greedy oracle`。这些表述分别暗示了在线尺度适应、前沿形状建模、校准不确定性、统计独立性和全局最优参照，而当前实现并不承担这些含义。

修订稿统一使用 EA 和代理辅助优化中常见的操作性术语：

- pairwise quality relation / 成对质量关系；
- candidate selection 或 infill selection / 候选选择或加点选择；
- quantile filtering / 分位筛选；
- bounded evaluation batch / 有界真实评价批次；
- classification ambiguity / 分类模糊度；
- decision-space distance / 决策空间距离；
- shift-based density estimation (SDE) fitness / SDE 适应度；
- surrogate-based reranking / 基于代理的重排序；
- environmental selection / 环境选择；
- within-pool greedy reference / 同池贪心参考。

## 二、逐项替换

| 原术语 | 风险 | 采用的 EA 术语 | 处理说明 |
|---|---|---|---|
| 尺度自适应 / scale-adaptive | 容易被理解为算法在线学习分数标定或尺度参数 | 基于分位筛选 / quantile filtering | 当前实现使用池内分位数，没有训练尺度校准模型 |
| 双路机制 / dual-route mechanism | 容易把普通的二选一策略包装成独立机制名 | 两种选择策略 / two selection strategies | 源码每轮在两个已定义选择策略间随机切换；不把“两策略”作为新的算法类别名称 |
| 前沿形状感知指标路径 / front-shape-aware indicator route | `indicator` 在 EMO 中通常指 HV、IGD、R2 等性能指标；SDE 是密度估计方法 | 基于 SDE 适应度代理的候选重排序 / candidate reranking using an SDE-fitness surrogate | 准确反映“计算 SDE 适应度—训练 SVR—重排序”的调用链 |
| 关系净证据 / net relation evidence | `evidence` 容易带出贝叶斯证据或统计证据含义 | 成对关系评分 / pairwise relation score | $r(\mathbf{x})$ 是四组成对分类输出的代数组合 |
| 预测不确定性 / predictive uncertainty | 最大类别输出不是校准方差、置信区间或认知不确定性 | 分类模糊度 / classification ambiguity | $1-\max_y\pi_y$ 只描述类别输出的集中程度 |
| 独立重排序信号 / independent ranking signal | SDE-SVR 策略仍先经过关系评分预筛选，不具备过程独立性 | 第二排序依据 / second ranking criterion | 只说明 SDE 适应度的训练目标不同，不主张统计或流程独立 |
| 候选偏好 / candidate preference | `preference` 在 EMO 中容易被理解为决策者偏好 | 选择策略或排序准则 / selection strategy or ranking criterion | 本模块没有决策者偏好信息 |
| 贪心 oracle / greedy oracle | `oracle` 容易被理解为候选池上的精确最优集合 | 同池贪心参考 / within-pool greedy reference | 实验值来自贪心构造，不是组合优化的全局最优解 |
| 可达收益 / attainable gain | 暗示已求得候选池最大可达收益 | 贪心参考收益 / gain produced by the greedy reference | 与实际计算过程保持一致 |
| 同一候选池比较 / same candidate pool comparison | 不同闭环算法运行中的具体候选池会随历史选择分化 | 相同累积池构造 / same accumulated-pool construction | 只主张两组采用同一种池构造规则；每个 run 内的 GainRatio 才使用对应候选池 |
| 直接证实、证明 / directly confirm, prove | 候选级结果覆盖四个 $M=20$ 问题，不能扩展成一般性定理 | 结果显示、数值提高 / showed, increased | 将结论限定在报告的实验设置和指标上 |

## 三、可直接保留的术语

以下术语与源码和 EA 文献语义一致，可直接使用：

- surrogate-assisted evolutionary search；
- expensive function evaluation 和 evaluation budget；
- pairwise relation model；
- accumulated candidate pool；
- quantile filtering；
- batch size；
- decision-space diversity；
- RBF-SVR；
- first nondominated front；
- shift-based density estimation (SDE)；
- convergence and distribution information；
- environmental selection；
- paired Wilcoxon signed-rank test。

`exploration strategy` 可以保留，但正文应明确它的操作来源是分类模糊度项和决策空间距离项，不把它扩大为“保证全局探索”或“发现未知 Pareto 区域”。

## 四、建议避免的命名

以下名称不建议用于标题、摘要或贡献列表：

- adaptive intelligence、self-adaptive intelligence；
- uncertainty-aware learning（除非增加不确定性校准）；
- Pareto-front-aware selection；
- optimal batch selection；
- oracle-guided selection；
- robust candidate selection（除非有扰动、分布变化或重复实验下的稳健性定义）；
- universal、general-purpose、problem-independent；
- novel indicator（当前没有提出新的 EMO 性能指标）。

## 五、文献术语锚点

这些文献只用于核对领域术语，不表示本文方法与其完全相同：

1. Li, Yang, and Liu 将 SDE 定义为 **shift-based density estimation**，并说明其同时包含解的分布与收敛信息。因此正文使用“SDE 适应度”和“收敛性与分布信息”，不使用“前沿形状感知指标”。DOI: [10.1109/TEVC.2013.2262178](https://doi.org/10.1109/TEVC.2013.2262178)。
2. Pairwise-comparison SAEA 文献使用 **pairwise comparison**、**surrogate model**、**candidate solution selection** 和 **model management strategy** 等术语。本文相应使用“成对质量关系”“关系模型”和“候选选择”。DOI: [10.1016/j.swevo.2023.101323](https://doi.org/10.1016/j.swevo.2023.101323)。
3. 代理辅助多目标优化文献通常将选择少量候选进行真实评价称为 **infill selection** 或使用 **infill criteria**。正文保留“候选选择”，如需要与相关工作对齐，可在首次出现时写作“candidate (infill) selection”。

## 六、本轮对正文的实际修改

- 节标题由“尺度自适应双路候选选择”改为“基于分位筛选和有界批量的候选选择”；
- `relation evidence` 全部改为 `pairwise relation score`；
- `predictive ambiguity/uncertainty` 限定为 `classification ambiguity`；
- “指标路径”改为“SDE 适应度代理重排序策略”；
- `dual-route` 改为 `two-strategy`；
- `greedy oracle` 和 `attainable gain` 改为 `within-pool greedy reference` 及其产生的收益；
- 将“同一候选池”收紧为“相同累积池构造”；
- 将“直接证实”改为限定于四个 20 目标问题的实验观察。
