# K-RVEA 算法详解

> **作者**：李盛薪
> **日期**：2026-05-14
> **算法定位**：P0 必读 / 钢印级（你 REMO 论文最重要的对照基线之一）
> **论文**：Chugh, Jin, Miettinen, Hakanen, Sindhya. *A Surrogate-Assisted Reference Vector Guided Evolutionary Algorithm for Computationally Expensive Many-Objective Optimization*. **IEEE TEVC**, 2018, 22(1): 129-142.
> **配套文件**：`KRVEA.m` / `KEnvironmentalSelection.m` / `KrigingSelect.m` / `NoActive.m` / `UpdataArchive.m` (均已加详细中文注释)

---

## 目录

1. [一句话定位](#1-一句话定位)
2. [研究动机：它要解决什么问题](#2-研究动机它要解决什么问题)
3. [核心思想三句话](#3-核心思想三句话)
4. [整体流程图](#4-整体流程图)
5. [关键模块逐一拆解](#5-关键模块逐一拆解)
6. [⭐ 论文真正的创新：自适应模型管理](#6--论文真正的创新自适应模型管理)
7. [关键公式：APD（必须能默写）](#7-关键公式apd必须能默写)
8. [超参速查表](#8-超参速查表)
9. [跑一次的 PlatEMO 命令](#9-跑一次的-platemo-命令)
10. [K-RVEA vs REMO：你论文里要写的对比](#10-k-rvea-vs-remo你论文里要写的对比)
11. [它在 M=10/15/20 上的失败模式（你的攻击点）](#11-它在-m101520-上的失败模式你的攻击点)
12. [自测题（验证 L0 是否到位）](#12-自测题验证-l0-是否到位)

---

## 1. 一句话定位

> **K-RVEA = Kriging（高斯过程代理） + RVEA（参考向量进化框架） + 自适应模型管理（不活跃参考向量数驱动 explore/exploit 切换）。**

它是 2018 年第一个把 Kriging 真正用进**超多目标 (M ≥ 4)** 的代表作。在你三月攻坚计划里，它被列为**「最强对照算法」**——你的论文 90% 概率要跟它在 DTLZ / WFG / MaF 上的 M=5,8,10 比一比。

---

## 2. 研究动机：它要解决什么问题

把它放进 SAEA 的发展线里看就清楚了：

| 时期 | 代表作 | 痛点 |
|---|---|---|
| 2006-2010 | ParEGO / MOEA-D-EGO | 每代只产 1-5 解，超多目标 (M≥4) 性能崩塌 |
| 2016 | RVEA | 用参考向量 + APD 解决了 M≥4 的多样性，但**不带代理**——昂贵问题用不起 |
| **2018 K-RVEA** | **把 Kriging 嵌进 RVEA**，用自适应模型管理决定何时偏收敛 / 何时偏探索 | —— |

**它要解决的核心矛盾**：
- 真实评价昂贵 ⇒ 必须用代理
- 代理在超多目标下精度差 ⇒ 必须有"知道何时不该信代理"的机制

K-RVEA 的回答是：**让"不活跃参考向量数量"做这个开关**。

---

## 3. 核心思想三句话

1. **代理**：每个目标训一个 Kriging（输出预测均值 μ + 方差 σ²），共 M 个；
2. **进化**：内部用 RVEA 跑 wmax=20 代，全部用代理评估（不消耗真实 FE）；
3. **筛选**：每外层迭代只挑 mu=5 个解送真实评价，挑选时用「不活跃参考向量数变化量」决定走 APD 收敛模式还是 MSE 探索模式。

---

## 4. 整体流程图

```
┌──────────────────────────────────────────────────────────────┐
│ 初始化：LHS 采 NI=11D-1 个解 → 全部真实评价 → A1 = A2         │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ 主循环 (NotTerminated)                                        │
│                                                                │
│  阶段 A：用 A1 训练 M 个 Kriging (warm-start THETA)            │
│            ↓                                                   │
│  阶段 B：内部 RVEA 跑 wmax 代                                  │
│           ├ B1) GA 算子产子代                                  │
│           ├ B2) Kriging 预测均值 + MSE                         │
│           ├ B3) KEnvironmentalSelection (APD 选 1/参考向量)    │
│           └ B4) 每 wmax/10 代自适应一次 V                      │
│            ↓                                                   │
│  阶段 C：KrigingSelect 挑 mu 个真实评价                        │
│           ├ 算 NumV2 = 当前不活跃参考向量数                    │
│           ├ Flag = NumV2 - NumV1                               │
│           ├ Flag ≤ delta → 走 APD 最小 (收敛)                  │
│           └ Flag >  delta → 走 MSE 最大 (探索)                 │
│            ↓                                                   │
│  阶段 D：UpdataArchive (保留 NI 个，K-means 保多样性)          │
│            ↓                                                   │
│  回到阶段 A                                                    │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. 关键模块逐一拆解

### 5.1 `KRVEA.m` —— 主入口

| 行号 | 关键代码 | 含义 |
|---|---|---|
| 27 | `[alpha,wmax,mu] = Algorithm.ParameterSet(2,20,5);` | 三个超参，默认值 alpha=2 / wmax=20 / mu=5 |
| 30 | `UniformPoint(Problem.N,Problem.M)` | 生成 Das-Dennis 均匀参考向量 V0 |
| 32-34 | `NI=11*D-1; LHS; Evaluation` | SAEA 经典初始预算：拉丁超立方采 11D-1 个点全部真实评价 |
| 36 | `THETA = 5.*ones(M,D)` | Kriging 核宽度初值，每代 warm-start |
| 49 | `dacefit(...)` | DACE 工具箱训练 Kriging（第三方代码，看不懂没关系） |
| 57 | `OperatorGA(Problem,PopDec)` | SBX + 多项式变异产子代 |
| 64 | `[PopObj(i,j),~,MSE(i,j)] = predictor(...)` | Kriging 预测：均值 + 方差 |
| 67 | `KEnvironmentalSelection(...,(w/wmax)^alpha)` | RVEA 选每参考向量 1 解 |
| 71-73 | `if ~mod(w,ceil(wmax*0.1))` | 每 wmax/10 代自适应 V |
| 78-79 | `NoActive + KrigingSelect` | ⭐ 模型管理核心 |
| 80-82 | `Evaluation + 档案更新` | 真实 FE 在这里花 |

### 5.2 `KEnvironmentalSelection.m` —— RVEA 经典环境选择

- **作用**：把内部种群按"参考向量"分区，每个参考向量只留 APD 最小的 1 个。
- **关键三步**：
  1. `cosine = 1 - pdist2(V,V,'cosine')` → 算参考向量之间的夹角，得到 gamma；
  2. `Angle = acos(1-pdist2(PopObj,V,'cosine'))` → 解 × 向量 的夹角矩阵；
  3. `[~,associate] = min(Angle,[],2)` → 每个解关联到最近向量，再按 APD 选最优。

### 5.3 `KrigingSelect.m` —— ⭐ K-RVEA 真正的创新所在 ⭐

这一部分**必须读懂**，因为论文 70% 的贡献都在这里。详见下一节。

### 5.4 `NoActive.m` —— 多样性度量器

- **输出 num** = 没有解关联的参考向量数 → 数值越大说明种群越偏科 / 多样性越差。
- 这个函数被 `KrigingSelect` 和 `UpdataArchive` 反复调用。

### 5.5 `UpdataArchive.m` —— Kriging 训练档案管理

- **目标**：档案大小恒为 NI，避免 Kriging O(N³) 训练失控。
- **策略**：mu 个新解必保留 + 老解里按 K-means 聚类挑 NI-mu 个保多样性。

---

## 6. ⭐ 论文真正的创新：自适应模型管理

这是 K-RVEA 区别于"K-MOEA/D-EGO 等 Kriging+EA 拼接"的关键。论文 Section IV-B 的核心。

### 6.1 信号定义

```
NumV1 = 上一轮档案 A1 的不活跃参考向量数  (来自 NoActive(A1Obj, V0))
NumV2 = 本轮内部种群的不活跃参考向量数    (来自 NoActive(PopObj, V0))
Flag  = NumV2 - NumV1                      (变化量)
delta = 0.05 * Problem.N                   (切换阈值)
```

### 6.2 切换规则

| 条件 | 含义 | 策略 | 公式 |
|---|---|---|---|
| `Flag ≤ delta` | 不活跃数没显著增加 → 多样性已稳 | **收敛模式 (exploit)** | 选 APD 最小的解 (信任代理均值) |
| `Flag > delta` | 不活跃数显著增加 → 多样性变差，部分参考向量被浪费 | **多样性 / 探索模式 (explore)** | 选 MSE 最大的解 (Kriging 不确定度高 → 去陌生区域) |

### 6.3 为什么这个设计聪明

- 它**不依赖任何外部信号**（不是按代数硬切换、不是按概率随机），完全数据驱动；
- 它把 Kriging 的方差 σ² 真正用上了——这正是 K-RVEA 比 RVEA + 任意代理更强的根本原因；
- 它**回答了 SAEA 的根本问题**：什么时候该信代理？答：种群多样性还在涨时信，开始衰退时反着信（去探索）。

### 6.4 你必须把这一段写进自己论文的 Related Work

模板示例：

> *Among existing surrogate-assisted reference vector based methods, K-RVEA [Chugh et al., 2018] employed an adaptive model management strategy that switches between APD-based convergence-driven selection and MSE-based diversity-driven selection according to the change of inactive reference vector count. However, this mechanism is fundamentally tied to the availability of Kriging's predictive variance σ², which is not naturally available in relation-learning surrogates such as REMO [Hao et al., 2022] and the proposed method.*

---

## 7. 关键公式：APD（必须能默写）

$$
\mathrm{APD}(\mathbf{x}, \mathbf{w}_r) = \left(1 + M \cdot \theta \cdot \frac{\angle(\mathbf{x}, \mathbf{w}_r)}{\gamma_r}\right) \cdot \|\mathbf{F}(\mathbf{x}) - \mathbf{z}^*\|
$$

| 符号 | 含义 | 实现 (KEnvironmentalSelection.m) |
|---|---|---|
| $\|\mathbf{F}(\mathbf{x}) - \mathbf{z}^*\|$ | **收敛距离**（到理想点） | `sqrt(sum(PopObj.^2,2))` (已平移) |
| $\angle(\mathbf{x}, \mathbf{w}_r)$ | 解到关联参考向量的夹角 | `Angle(current,i)` |
| $\gamma_r$ | $\mathbf{w}_r$ 到最近邻参考向量的夹角（归一化用） | `gamma(i)` |
| $\theta$ | **时变惩罚** = $(t/t_{\max})^\alpha$ | `(w/wmax)^alpha` |
| $M$ | 目标维 | `Problem.M` |

**直觉**：早期 t 小 → 惩罚轻 → 鼓励探索；后期 t 大 → 惩罚重 → 强制贴参考向量收敛。这就是 RVEA "动态压力"的来源。

---

## 8. 超参速查表

| 超参 | 默认值 | 含义 | 调小的影响 | 调大的影响 |
|---|---|---|---|---|
| `alpha` | 2 | APD 时变惩罚的指数 | 早期更鼓励探索 | 后期更强制收敛 |
| `wmax` | 20 | 内部 RVEA 跑多少代 | 代理利用不充分，浪费 FE | 容易"信代理过头"被误导 |
| `mu` | 5 | 每外层迭代真实评价数 | 代价低但收敛慢 | 收敛快但 FE 浪费 |
| `delta` | 0.05·N | 模型管理切换阈值 (硬编码在 KRVEA.m line 79) | 更频繁走探索模式 | 几乎一直走收敛模式 |
| `NI` | 11D-1 | Kriging 训练样本数 | 代理欠拟合 | 训练慢 (O(N³)) |
| `THETA0` | 5 | Kriging 核宽度初值 | 局部敏感 | 全局平滑 |

---

## 9. 跑一次的 PlatEMO 命令

```matlab
% DTLZ2, M=5, D=10, 预算 300 FE, 跑 1 次
platemo('algorithm', @KRVEA, 'problem', @DTLZ2, 'M', 5, 'D', 10, 'maxFE', 300);

% MaF7 (不连通 PF), M=8, D=10, 跑 20 次取平均
platemo('algorithm', @KRVEA, 'problem', @MaF7, 'M', 8, 'D', 10, 'maxFE', 300, 'run', 20, 'save', 5);

% 改超参 (举例：把 wmax 改成 30)
platemo('algorithm', {@KRVEA, 2, 30, 5}, 'problem', @DTLZ4, 'M', 10, 'D', 12, 'maxFE', 400);
```

---

## 10. K-RVEA vs REMO：你论文里要写的对比

| 维度 | K-RVEA (2018) | REMO (2022) | 你的优势点（潜在） |
|---|---|---|---|
| 代理类型 | Kriging（回归） | FNN（关系分类） | 关系学习对噪声/超多目标更鲁棒 |
| 训练目标 | 学 $f(\mathbf{x})$ 的精确值 | 学 $f(\mathbf{x}_i)$ vs $f(\mathbf{x}_j)$ 的相对优劣 | 不需精确值就能选解 |
| 不确定度 | **天然有 σ²** | **没有 σ²**（这是 REMO 的痛点 P0-13） | 你可以用 Bootstrap Ensemble 补上 |
| 选择准则 | APD（角度+距离） | 关系投票（赢的次数） | 你可以混合 APD 和投票 |
| 模型管理 | **NumV 变化量驱动 explore/exploit 切换** | 没有自动切换机制 | **可借鉴：用 NumV 切换关系预测 vs 不确定度采样** |
| 训练复杂度 | O(N³)（D≥30 慢） | O(N²) 配对 + NN 训练 | NN 在 D 大时更可扩展 |
| 超多目标支持 | M ≤ 10 实测良好 | M ≤ 10，更高维退化 | 都还需进一步突破 |

**论文叙事样板**：
> *While K-RVEA [Chugh 2018] pioneered the integration of Kriging surrogate and reference vector framework with an adaptive model management mechanism, it inherently relies on the predictive variance $\sigma^2$ of Gaussian processes, which is unavailable in relation-learning surrogates. To inherit K-RVEA's adaptive switching capability while exploiting the noise robustness of pairwise comparisons, we propose ...*

---

## 11. 它在 M=10/15/20 上的失败模式（你的攻击点）

> **看一个对照算法的"失败模式"，比看它的"成功故事"更有论文价值。**

| 失败模式 | 触发条件 | 根本原因 | 你能怎么打 |
|---|---|---|---|
| **Kriging 训练失败** | D ≥ 30 | NI=11D-1 解训练 D 维高斯过程协方差矩阵奇异 | 用 NN/RBF 替代 |
| **APD 多样性不足** | M ≥ 10, 退化 PF (DTLZ5/6) | 参考向量在退化流形上大量浪费 | 加自适应参考向量增强（DISK 风格分布信息） |
| **模型管理失灵** | M ≥ 10 | 大部分参考向量都不活跃，NumV 变化对 delta 敏感度过高 | 把 delta 改自适应 |
| **DTLZ7 不连通** | 任意 M | RVEA 在不连通 PF 上参考向量被切到无效区 | 关系学习 + 子区域聚类 |
| **DTLZ4 偏置** | 任意 M | 初始 LHS 偏差被 Kriging 放大 | 增加 LHS 重采样 |

**强烈建议**：在你 W4-W5 痛点定位时，**手动跑 K-RVEA 在这 5 个失败场景上**，记录 IGD/HV 退化数据——这是你论文 Introduction "动机" 章节的关键证据。

---

## 12. 自测题（验证 L0 是否到位）

合上 md，限时 30 分钟答完：

1. K-RVEA 的三个超参分别是什么？默认值各是多少？各调大有什么影响？
2. 闭眼写出 APD 公式（要素：M, theta, angle, gamma, ‖F-z*‖）
3. 为什么早期 (w 小) APD 偏向探索？后期 (w 大) 偏向收敛？解释 alpha 的作用。
4. NoActive 函数返回什么？为什么 K-RVEA 要反复调它？
5. KrigingSelect 里 Flag = NumV2 - NumV1 > delta 时走哪条路径？为什么？
6. 在 M=10、DTLZ7 上 K-RVEA 大概率失败，你能给出 2 个机制层面的原因吗？
7. K-RVEA 用 Kriging，REMO 用 FNN——本质区别是什么？（不是"模型不同"这种废话）
8. 如果让你只改 K-RVEA 一处代码使它适配 M=15，你改哪？为什么？
9. 自适应参考向量 V 是什么时候更新的？更新公式是？
10. NI = 11D-1 这个公式从哪来？为什么不是 100 或 1000？

**评分**：
- 9/10 以上 → L0 到位
- 6-8 → 把 KrigingSelect 和 KEnvironmentalSelection 再读一遍
- ≤5 → 重读本文 + 跑一次 platemo 看输出

---

## 附录：本目录文件功能速查

| 文件 | 作用 | 是否需要 L0 |
|---|---|---|
| `KRVEA.m` | 主入口 + 外层循环 | ✅ |
| `KEnvironmentalSelection.m` | RVEA 经典 APD 选择 | ✅ |
| `KrigingSelect.m` | ⭐ 模型管理 + 真实评价候选挑选（核心创新） | ✅ |
| `NoActive.m` | 不活跃参考向量计数（多样性度量） | ✅ |
| `UpdataArchive.m` | 训练档案管理 | L1 即可 |
| `dacefit.m` | DACE 工具箱：Kriging 训练（第三方） | 跳过，知道是"训练 GP" |
| `predictor.m` | DACE 工具箱：Kriging 预测（第三方） | 跳过，知道是"GP 预测均值+方差" |

---

## 参考文献

1. Chugh, T., Jin, Y., Miettinen, K., Hakanen, J., Sindhya, K. (2018). A Surrogate-Assisted Reference Vector Guided Evolutionary Algorithm for Computationally Expensive Many-Objective Optimization. *IEEE Trans. Evol. Comput.*, 22(1), 129-142.
2. Cheng, R., Jin, Y., Olhofer, M., Sendhoff, B. (2016). A Reference Vector Guided Evolutionary Algorithm for Many-Objective Optimization. *IEEE Trans. Evol. Comput.*, 20(5), 773-791. (RVEA 本体)
3. Lophaven, S. N., Nielsen, H. B., Søndergaard, J. (2002). DACE: A Matlab Kriging Toolbox. (dacefit/predictor 来源)
4. Hao, H., Zhou, A., Qian, H., Zhang, H. (2022). Expensive Multiobjective Optimization by Relation Learning and Prediction. *IEEE Trans. Evol. Comput.*, 26(5), 1157-1170. (你的 baseline，用于对比)

---

**写在最后**：

K-RVEA 在你论文里有三种用法——

1. **作为对照基线**：在你的实验表里报它的 IGD/HV，证明你的方法更好；
2. **作为"机制借鉴"的引用源**：你的"自适应切换"思想可以追溯到它（说"沿袭 K-RVEA 的思路"是合规的，不算抄袭）；
3. **作为反例**：在 Introduction 里指出它的痛点（Kriging 不可扩展、依赖 σ² 等）→ 引出你的方法。

把 KrigingSelect.m 那个 `if Flag<=delta ... else ...` 的 if-else 块**钉在脑子里**——这是 K-RVEA 整篇论文的灵魂。
