# REMO_new2_PIEA 系列改进汇报

> **汇报时间**：2026/05/13 组会
> **汇报人**：梅亦健
> **主线**：把 PIEA(2024, Information Sciences) 的指标体系嫁接到 REMO_new2(关系学习, 2022 TEVC) 框架中，通过五个版本的探索定下"广度/深度双信号解耦"这一架构原则。

---

## 一、研究背景与问题

### 1.1 两类昂贵多目标代理模型

| 类别 | 代表工作 | 优势 | 局限 |
|---|---|---|---|
| **关系学习类** | REMO (2022 TEVC) | 学相对支配关系，对噪声鲁棒，适合超多目标 | 只有"方向/广度"信号，缺乏对解绝对质量的度量 |
| **指标驱动类** | PIEA (2024 Inf. Sci.) | 三指标轮盘 + Lp 自适应 + NDSort_SDR 反馈，对解打绝对分 | 单 SVR 代理，没有关系/方向信息 |

### 1.2 研究问题

> **能否在昂贵多目标优化中，让关系网络与指标 SVR 协同工作？两者究竟是"合并"还是"分工"？**

这就是 PIEA 系列五个版本想要回答的问题。

---

## 二、五个版本的演进逻辑

### 2.1 总体路线图

```
PIEA1 (单选最远点)          ─┐
PIEA2 (SVR-SDE 加权融合)    ─┼─► "加法式"集成（凭直觉拼）
PIEA3 (完整 PIEA 体系移植)  ─┘

PIEA4 (关系网+SVR 共享 Fitness 标签) ─► 故意尝试"合并"
        │
        ▼  实验否决（DTLZ7 多样性暴跌 62%）
PIEA5 (回滚标签合并，保留候选池修复) ─► 定下"分工而非合并"原则
```

### 2.2 版本对照表

| 版本 | 核心改动 | 设计动机 | 实验结果 |
|---|---|---|---|
| **PIEA1** | 把 `RSurrogateAssistedSelection` 的"top-k 候选"改成"决策空间最远点单选" | 想要更激进的多样性探索 | 太保守，每代只评估 1 个解，maxFE 用不完 |
| **PIEA2** | 引入 SDE 的 SVR 回归 + 与关系网络得分**加权融合** | 想把指标信号注入到选择中 | 加权耦合死板，量纲不一致，SDE 单指标在某些场景失效 |
| **PIEA3** | **完整 PIEA 体系**：三指标轮盘 (SDE/I_ε+/Minkowski) + Lp 形状自适应 + NDSort_SDR 反馈；用**两阶段筛选**(关系网粗筛 → SVR 精排)替代加权 | 用反馈让算法自适应挑指标；解耦广度/深度 | DTLZ 上有改善；候选池只有 12 个，SVR 精排发挥空间小 |
| **PIEA4** | (a) 保留 PIEA3 全体系；(b) **候选池累积扩大到数百个**；(c) **把关系网标签从 PBI 多方向 换成 Fitness top25%** | "共享目标"听起来更协同 | **DTLZ7 IGD 比 v3 还差 62%**，多样性崩溃 |
| **PIEA5** | **回滚 v4 的标签合并；保留 v4 的候选池扩大**。明确分工：关系网=PBI 多方向(广度)，SVR=轮盘 Fitness(深度) | 由 v4 失败反推出的架构原则 | 当前最稳定版本 |

### 2.3 v4 → v5 的关键转折（汇报重点）

v4 的失败给了一条非平凡的观察：

> **多方向分类标签（PBI Catalog）与单值指标值（Fitness）在同一个学习器里会互相破坏。**

具体机制：
- PBI 多方向标签鼓励**多个参考方向上**都保留好解（保多样性）；
- 单值 Fitness top25% 只保留**指标最高**的那几个（保收敛性，丢多样性）；
- 关系网用单值 Fitness 训练后，对"方向 A 好 vs 方向 B 好"这种比较失去了识别能力，下游 GA 候选退化成"集体冲一个角落"。

这条经验对应到 v5 的架构选择：**广度信号和深度信号必须由两个学习器分别承担，不能合并到同一目标上。**

---

## 三、当前 v5 算法流程（汇报伪代码）

```
输入：Problem (M 目标, D 维), maxFE
初始化：LHS 采样 N 个解, Archive = Population
初始化指标轮盘 indicator[1..3] = {SDE, I_ε+, Minkowski}, Pw=1/3

while FE < maxFE:
    ratio = FE / maxFE
    # Step 1: HPC 分类 → Catalog (PBI 多方向) + Ref
    Catalog, Ref ← HybridPBI_Classification(Population, ratio)

    # Step 2: 轮盘选指标 → Fitness (单值, 深度信号)
    Fitness, flag, Lp ← IndicatorSelector(Population, indicator)

    # Step 3: 关系网 (广度) — 用 Catalog 训练
    XXs, YYs ← GetRelationPairs(Population.decs, Catalog)
    net ← patternnet 训练

    # Step 4: SVR (深度) — 用 Fitness 训练
    IndicatorModel ← fitrsvm(Population.decs, Fitness)

    # Step 5: 两阶段筛选
    Candidates ← GA 候选池 (累积数百个)
    Coarse ← 关系网粗筛 (保留广度)
    Next ← SVR 精排 (深度排序, 取 top-k)

    # Step 6: 真实评估 + NDSort_SDR 反馈
    NewSols ← Problem.Evaluation(Next)
    score ← NDSort_SDR(NewSols, Archive)   # 0 / 1 / 2
    indicator ← UpdateInformation(flag, score, indicator)

    Archive ← Archive ∪ NewSols
    Population ← RefSelect(Archive, N)
```

---

## 四、当前实验结果（待补完整数据）

### 4.1 已有数据范围
- 测试集：DTLZ1-7, WFG1-9
- 目标数：M = 5 / 10 / 15 / 20
- 决策维：D = 30
- 预算：maxFE = 300
- 对比算法：REMO, REMO_new2, KRVEA, CSEA, MCEA/D（PIEA 适配版待补）

### 4.2 v5 vs 已有版本（IGD，越小越好，示意）

| 问题 | M | REMO_new2 | PIEA3 | PIEA4 | **PIEA5** |
|---|---|---|---|---|---|
| DTLZ2 | 10 | … | … | … | … |
| DTLZ7 | 10 | … | … | **暴跌** | … |
| WFG10 | 10 | … | … | … | … |

> *汇报时插入真实数据表+收敛曲线*

---

## 五、坦诚的自我评估（建议主动跟老师讲）

### 5.1 拼凑感来自哪里

- **v1/v2 是凭直觉拼**，没有 ablation 驱动；
- **v3 是 PIEA 整体平移**，架构没有真正改造；
- **v4/v5 才开始进入"消融驱动设计"**——这是目前最有价值的部分。

### 5.2 当前最像"机制创新"的点

> **"广度信号 / 深度信号 必须在代理模型层面解耦"**——由 v4 的失败实证支撑。

这条原则在 PIEA 原文里没有明说，在 REMO 原文里也没有。如果实验做扎实，是有原创性的。

### 5.3 距离能投出的论文还差什么

1. **完整 ablation**：拆掉三指标轮盘 / 拆掉 NDSort_SDR 反馈 / 把 v4(标签合并) 作为反例 baseline；
2. **Pw 曲线**：证明三指标轮盘**真的**在不同问题上倾向不同（否则三指标就是冗余）；
3. **PIEA 适配版作为 baseline**：把原 PIEA 移到昂贵设置当对比；
4. **超参敏感性**：tau、gmax、k 的 sensitivity；
5. **统计显著性**：Wilcoxon / Friedman。

### 5.4 投稿目标判断

| 期刊/会议 | 难度 | 备注 |
|---|---|---|
| IEEE TEVC | 偏难 | 需要更强的理论支撑或更显著的性能优势 |
| **Information Sciences** | **可冲** | PIEA 原刊；故事讲圆+实验扎实有机会 |
| **SWEVO** | **可冲** | 进化计算专刊，对工程性创新友好 |
| **ESWA** | **稳妥** | 工程性集成可接受 |

---

## 六、下一步工作计划

| 时间节点 | 任务 |
|---|---|
| 第 1-2 周 | 跑完 v5 在 DTLZ+WFG 全集、M={5,10,15,20} 的 IGD/HV，30 次独立运行 |
| 第 3 周 | 做完上述 5 项 ablation |
| 第 4 周 | 整理 Pw 曲线、收敛曲线、Wilcoxon 显著性表 |
| 第 5-6 周 | 撰写初稿，重点重写 motivation（围绕"广度/深度解耦"） |
| 第 7 周 | 老师审阅 + 投稿 |

---

## 七、想跟老师确认的几个问题

1. **故事主线**：是把"v5 作为新算法"投，还是把"v4 失败 → v5 解耦原则"作为论文核心叙事？后者更新颖但更难写。
2. **投稿目标**：Information Sciences vs SWEVO 哪个更合适？
3. **baseline 取舍**：PIEA 原算法是否需要适配到 expensive 场景作为对比？工作量较大。
4. **是否需要补理论分析**：广度/深度解耦能否给出一个简单的理论说明（例如从 VC 维或样本复杂度角度），还是纯实验驱动？

---

## 附录：文件结构

```
REMO_new2_PIEA/    PIEA1 - 单选最远点
REMO_new2_PIEA2/   PIEA2 - SVR-SDE 加权融合
REMO_new2_PIEA3/   PIEA3 - 完整 PIEA 体系 + 两阶段筛选
REMO_new2_PIEA4/   PIEA4 - 标签合并实验（反例）
REMO_new2_PIEA5/   PIEA5 - 当前主推版本
```

共享辅助文件：`HybridPBI_Classification.m`, `GetRelationPairs.m`, `IndicatorSelector.m`, `Shape_Estimate.m`, `NDSort_SDR.m`, `UpdateInformation.m`, `calFitness_*.m`
