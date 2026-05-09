# REMO_new2_PIEA3 算法步骤详解

> 在 REMO_new2 的关系学习框架基础上集成 PIEA 性能指标体系（轮盘选择 + Lp 形状自适应 + NDSort_SDR 反馈），通过**两阶段筛选**机制将关系网络与指标 SVR 解耦协作。
>
> **适用场景**：昂贵超多目标优化（M = 5~20），高维决策空间（D = 30），评估预算紧张（maxFE = 300）。

---

## 目录

1. [设计动机](#1-设计动机)
2. [整体框架](#2-整体框架)
3. [关键数据结构](#3-关键数据结构)
4. [主算法步骤（伪代码）](#4-主算法步骤伪代码)
5. [核心模块详解](#5-核心模块详解)
6. [与已有版本对比](#6-与已有版本对比)
7. [关键设计抉择的理由](#7-关键设计抉择的理由)
8. [文件组织](#8-文件组织)
9. [推荐运行与调试](#9-推荐运行与调试)

---

## 1. 设计动机

### 1.1 已知事实

| 算法 | 性能定位 | 关键缺陷 |
|---|---|---|
| REMO（2022, IEEE TEVC） | 关系学习开创工作 | PBI 在 M ≥ 5 失效；雷达图丢信息 |
| REMO_new2 | REMO 的有效改进，性能更好 | 仍依赖 PBI 分类 |
| PIEA（2024, Information Sciences）| 超多目标 SAEA 的代表性高性能算法 | 单代理 SVR 直接预测 fitness，关系信息缺失 |
| REMO_new2_PIEA | 加"决策空间最远点单选" | 每代仅 1 解，maxFE 用不完 |
| REMO_new2_PIEA2 | 加 SVR 回归 SDE，加权融合 | **SDE 单独不够好**；阈值 `>3.9` 仍未修复 |

### 1.2 关键洞察

- **关系网络 vs 性能指标，本质不同**：关系网络做"两两比较"（粗排），对噪声鲁棒；指标 SVR 做"绝对打分"（精排），数值精度高。两者**互补**而非冗余。
- **单一指标会失效**：用户实测 SDE 在某些场景表现不佳；PIEA 的精髓是**三指标轮盘 + Lp 自适应 + 反馈机制**，缺一不可。
- **两阶段筛选优于加权混合**：加权混合中两种得分量纲、动态范围不一致，权重 α 难调；两阶段则各司其职。

### 1.3 设计目标

> 把 PIEA 的**完整性能指标体系**（不只是 SDE）作为关系网络的协作组件，让二者在不同阶段发挥各自优势。

---

## 2. 整体框架

```
┌──────────────────────────────────────────────────────────────┐
│                      REMO_new2_PIEA3                         │
│                                                              │
│   Population ──┬──→ HybridPBI_Classification → Catalog, Ref  │
│                ├──→ GetRelationPairs        → 关系对          │
│                │       └─→ patternnet (REMO 原有关系代理)     │
│                │                                              │
│                └──→ IndicatorSelector ─[轮盘]→ Fitness, flag │
│                        └─→ fitrsvm (PIEA 风格指标代理)        │
│                                                              │
│                         ↓                                    │
│              RSurrogateAssistedSelection                     │
│                  ① 关系网络驱动 GA 内循环                      │
│                  ② 关系粗筛 top-30%                           │
│                  ③ 指标 SVR 精排                              │
│                  ④ quantile(0.7) → 取 5~8 个                  │
│                         ↓                                    │
│              Problem.Evaluation (真实评估)                    │
│                         ↓                                    │
│              NDSort + NDSort_SDR → score ∈ {0,1,2}           │
│                         ↓                                    │
│              UpdateInformation → 更新轮盘 Pw                  │
│                         ↓                                    │
│              RefSelect → 下一代 Population                    │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. 关键数据结构

### 3.0 三种"标签 / 类别"概念辨析（避免混淆）

| 名称 | 取值 | 维度 | 含义 | 出处 |
|------|------|------|------|------|
| **Catalog** | `{false, true}` | 单个解 | **二元**：好 / 非好（中间解归入非好） | `HybridPBI_Classification.m` |
| **关系对标签 Ls** | `{-1, 0, +1}` | 解对 (pair) | **三元**：同类 / 好胜非好 / 非好败好 | `GetRelationPairs.m` |
| **轮盘反馈 score** | `{0, 1, 2}` | 当代指标选择 | **三级**：差 / 中 / 极优（评估指标质量） | `REMO_new2_PIEA3.m` Step 7 |

**关键认识**：本算法中**解的分类始终是二元的**（好 vs 非好）。三元 / 三级出现在"关系对"和"反馈信号"上，而不是解本身。

### 3.1 indicator（轮盘状态）

```matlab
indicator(1) = struct(
    'method',        'SDE',
    'Choose_record', ones(1, tau),    % 滑动窗口：最近 tau 步是否被选中
    'Win_record',    ones(1, tau),    % 滑动窗口：被选后真实评估的成功度
    'Pw',            1/3              % 当前被选概率
);
indicator(2) = struct('method', 'I_epsilon+', ...);
indicator(3) = struct('method', 'Minkowski',  ...);
```

`Pw` 的更新规则（每代）：

$$
P_w^{(i)} = \frac{\sum \text{Win}^{(i)} + \epsilon}{\sum \text{Choose}^{(i)} + \epsilon},\quad
P_w^{(i)} \leftarrow \frac{P_w^{(i)}}{\sum_j P_w^{(j)}}
$$

### 3.2 Smodel（代理模型包）

```matlab
Smodel.X              % N×D，训练样本（决策变量）
Smodel.Y              % N×1，Catalog（boolean: true=好解 / false=非好解，二分类）
Smodel.mp_struct      % mapminmax 归一化参数
Smodel.net            % patternnet 关系网络
Smodel.p_err          % 关系网络测试错误率
Smodel.IndicatorModel % fitrsvm 训练的指标 SVR
Smodel.Lp             % 当代估计的 PF 形状参数
Smodel.flag           % 当代轮盘选中的指标编号 (1/2/3)
```

---

## 4. 主算法步骤（伪代码）

```
算法 REMO_new2_PIEA3
输入: Problem (问题对象), maxFE (评估预算)
参数: k=6 (参考解数), gmax=3000 (代理评估上限), tau=20 (轮盘窗口)

────────────────────────────────────────────────────────────
Step 0: 初始化
────────────────────────────────────────────────────────────
  N = (D ≤ 10) ? 11D-1 : 100
  PopDec ← UniformPoint(N, D, 'Latin')                    # LHS 采样
  Population ← Problem.Evaluation(scale(PopDec))
  Archive ← Population
  indicator ← {SDE: Pw=1/3, I_eps+: Pw=1/3, MD: Pw=1/3}
  Lp ← 1

────────────────────────────────────────────────────────────
主循环 while NotTerminated(Archive):
────────────────────────────────────────────────────────────

  ratio ← FE / maxFE                                       # 进化比例

  ── Step 1: 关系学习数据准备 ──────────────────────────
  [Catalog, Ref] ← HybridPBI_Classification(Population, ratio)
        # 输出二元 Catalog ∈ {false, true}：非好 / 好
        # 中间解被归入"非好"类（与原始 REMO 一致，无中间解类别）
        # Ref：分类得分前 k 个解（用于代理辅助 GA 注入）
  [XXs, YYs] ← GetRelationPairs(Population.decs, Catalog)
        # 关系对（pair）的标签 ∈ {-1, 0, +1}：
        #   0  = 同类对（好-好 或 非好-非好）
        #   +1 = (好, 非好) 顺序对
        #   -1 = (非好, 好) 顺序对
        # 注意：这是"两个解之间的关系"标签，不是单个解的分类标签
  [TrainIn, TrainOut, TestIn, TestOut] ← DataProcess(XXs, YYs, ratio=3/4)

  ── Step 2: 训练关系网络 (REMO 原有) ──────────────────
  [TrainIn_nor, mp_struct] ← mapminmax(TrainIn)
  TrainOut_onehot ← onehotconv(TrainOut, 1)
        # 对关系对标签 {-1, 0, +1} 做三类 one-hot
        # 这是"关系对"的三类，不是"解"的三类（解只有二分类）
  net ← patternnet([⌈1.5·xDim⌉, xDim, ⌈xDim/2⌉])
  net ← train(net, TrainIn_nor, TrainOut_onehot)
  p_err ← test_error(net, TestIn, TestOut)

  ── Step 3: PIEA 指标轮盘 + SVR 代理 ──────────────────
  [Fitness, flag, Lp] ← IndicatorSelector(Population, indicator, Lp)
        # 内部：
        #   Lp ← Shape_Estimate(Population, N)
        #   r ← rand
        #   if r < Pw[1]:           Fitness ← calFitness_SDE(PopObj, Lp)
        #   elif r < Pw[1]+Pw[2]:   Fitness ← calFitness_epsilon(PopObj, 0.05)
        #   else:                   Fitness ← calFitness_MD(PopObj, Lp)
  IndicatorModel ← fitrsvm(
        Population.decs, Fitness,
        'KernelFunction', 'rbf',
        'KernelScale', 'auto',
        'Standardize', true)

  ── Step 4: 打包代理模型 ──────────────────────────────
  Smodel ← {X, Y=Catalog, mp_struct, net, p_err,
            IndicatorModel, Lp, flag}

  ── Step 5: 两阶段筛选生成候选解 ──────────────────────
  ArchiveSizeBefore ← length(Archive)
  Next ← RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel)
        # 内部:
        #   ① GA 内循环（关系网络驱动），共 ≤ gmax 次代理评估
        #   ② scores_rel ← model_select_relation(Smodel, Next)
        #      coarse_keep ← argsort_top_30%(scores_rel)
        #   ③ scores_ind ← predict(IndicatorModel, coarse_keep)
        #   ④ q70 ← quantile(scores_ind, 0.7)
        #      keep ← scores_ind > q70  (至少保留 5 个)
        #      取 keep 中 score_ind 最高的 5~8 个

  ── Step 6: 真实评估 ──────────────────────────────────
  if Next 非空:
      NewSols ← Problem.Evaluation(Next)
      Archive ← [Archive, NewSols]
  else:
      NewSols ← []

  ── Step 7: PIEA 反馈机制（核心创新）──────────────────
  score ← 0
  if NewSols 非空:
      FrontNo_all ← NDSort(Archive.objs, 1)
      new_idx ← ArchiveSizeBefore + (1 : length(NewSols))
      if 任意 new_idx 进入 NDSort 第一层:
          score ← 1
          F1_subset ← Archive(FrontNo_all == 1)
          FrontNo_SDR ← NDSort_SDR(F1_subset, 1)            # 强支配排序
          if 任意新解仍在 NDSort_SDR 第一层:
              score ← 2

  indicator ← UpdateInformation(flag, score, indicator)
        # 滑动 Choose_record / Win_record，重新计算 Pw

  ── Step 8: 环境选择 ──────────────────────────────────
  Population ← RefSelect(Archive, Problem.N)
                # REMO_new2 原有的雷达网格选择

End while
返回: Archive 中的非支配解
```

---

## 5. 核心模块详解

### 5.1 IndicatorSelector — 轮盘选择 + Lp 自适应

**输入**：当前种群 `Population`，轮盘状态 `indicator`，上代 `Lp_prev`
**输出**：`Fitness`（N×1，越大越好），`flag` ∈ {1,2,3}，新 `Lp`

#### 子步骤

1. **PF 形状估计（Shape_Estimate）**
   - 取 NDSort 第一层（非支配解）
   - 若解数 < 20：直接 Lp = 1
   - 否则在 17 个候选 Lp ∈ [0.27, 6.5] 中，选使 `std(Gp/max(Gp))` 最小的
   - $G_p^{(i)} = \left( \sum_j (\text{PopObj}_{ij})^p \right)^{1/p}$
   - 用箱线图剔除 `Q3 + 1.5*(Q3-Q1)` 以上的离群点

2. **轮盘选择**
   ```
   r = rand
   if   r < P_w(1):                    Fitness = SDE
   elif r < P_w(1) + P_w(2):           Fitness = I_epsilon+
   else:                               Fitness = Minkowski(Lp)
   ```

3. **NaN/Inf 兜底**：失败时回退到 SDE

### 5.2 三个性能指标公式

#### (1) calFitness_SDE — 移位密度估计 + Minkowski 退化

$$
\text{SDE}_i = \min_{j \neq i} \| F_i - \max(F_i, F_j) \|_2
$$

归一化到 `[0, 3]`，当 SDE < 1e-4（解相互聚集失去区分度）时，**自动退化**为：

$$
\text{Fitness}_i = -\| F_i - F_{\min} \|_{L_p}
$$

最后 `Fitness = tansig(Fitness)` 缩放到 `[-1, 1]`。

#### (2) calFitness_epsilon — I_epsilon+ 不可加性

$$
I_{\epsilon}^+(F_i, F_j) = \max_m (F_{i,m} - F_{j,m})
$$

$$
\text{Fitness}_i = \sum_{j \neq i} -\exp\left( -\frac{I_{\epsilon}^+(F_i, F_j)}{C \cdot \kappa} \right) + 1
$$

其中 $C = \max_j |I_{\epsilon}^+(\cdot, j)|$，$\kappa = 0.05$。

#### (3) calFitness_MD — Lp 距离至理想点

$$
\text{Fitness}_i = -\| F_i - F_{\min} \|_{L_p}
$$

- $L_p = 1$ 适合线性 PF
- $L_p = 2$ 适合凸 PF
- $L_p < 1$ 适合凹 PF

### 5.3 RSurrogateAssistedSelection — 两阶段筛选

#### Stage A：GA 内循环（关系网络驱动）

```
Next ← OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5})
i ← 0
while i < gmax:
    sorted_idx ← model_select_relation(Smodel, Next)
    Input_new ← Next(sorted_idx[1:length(Ref)], :)
    Next ← OperatorGA(Problem, [Input_new; Ref.decs], {1,15,1,5})
    i ← i + size(Next)
```

#### Stage B：粗筛（关系网络）

```
[~, scores_rel] ← model_select_relation(Smodel, Next)
n_keep ← ⌈0.3 · |Next|⌉
coarse_keep ← argsort_descend(scores_rel)[1 : n_keep]
coarse_set ← Next[coarse_keep]
```

#### Stage C：精排（指标 SVR）

```
scores_ind ← predict(IndicatorModel, coarse_set)
                # SVR 失败时回退到 scores_rel
```

#### Stage D：分位数阈值

```
q70 ← quantile(scores_ind, 0.7)
keep ← scores_ind > q70
if sum(keep) < 5:
    keep ← top-5 by scores_ind                       # 兜底
order ← argsort_descend(scores_ind[keep])
n_eval ← min(8, max(5, sum(keep)))
Next ← coarse_set[ keep[order[1:n_eval]] ]
```

**为什么这样设计**：
- Stage A 用关系网络做 GA 选择：关系比较对噪声鲁棒
- Stage B 用关系网络粗筛：保留"有潜力"的方向
- Stage C 用指标 SVR 精排：指标值是数值化打分，能区分细微差异
- Stage D 用分位数：替代原 `>3.9` 死阈值，确保始终能选出 5~8 个

### 5.4 NDSort_SDR — 强支配关系（PIEA 反馈用）

普通 NDSort 在 M ≥ 5 时几乎所有解互不支配，无区分度。SDR 引入**角度阈值** $\Theta_{ij}$：

$$
\Theta_{ij} = \max\left(1, \frac{\angle(F_i, F_j)}{\theta_{\min}}\right)
$$

新支配关系：

$$
F_i \prec_{\text{SDR}} F_j \iff \|F_i\|_{1} \cdot \Theta_{ij} < \|F_j\|_{1}
$$

其中 $\theta_{\min}$ 取种群中所有最近邻角度的中位数。这等价于"$F_i$ 不仅范数小，方向也得在 $F_j$ 附近"才算支配。

### 5.5 UpdateInformation — 滑动窗口轮盘

每代结束时：

1. **滑动 Choose_record**（窗口宽 tau）：当代选中的指标对应位置 ← 1，其余 ← 0
2. **滑动 Win_record**：
   - score = 0 → 全部 ← 0
   - score = 1 → 选中指标 ← 0.5
   - score = 2 → 选中指标 ← 1.0
3. **重新归一化 Pw**：`Pw[i] = (sum Win[i] + ε) / (sum Choose[i] + ε)`，再 sum to 1

**含义**：某指标长期"被选后真实评估出在 NDSort_SDR 第一层"，下代被选概率上升；反之下降。

---

## 6. 与已有版本对比

| 维度 | REMO_new2 | REMO_new2_PIEA | REMO_new2_PIEA2 | **REMO_new2_PIEA3** |
|---|---|---|---|---|
| 关系网络 | ✅ patternnet | ✅ | ✅ | ✅ |
| 指标代理 | ❌ | ❌ | ✅ 仅 SDE 回归 | ✅ **三指标轮盘 SVR** |
| Lp 形状感知 | ❌ | ❌ | 部分（只 SDE 用）| ✅ **每代自适应** |
| NDSort_SDR 反馈 | ❌ | ❌ | ❌ | ✅ |
| 关系/指标融合 | — | — | 加权 α·rel + (1-α)·ind | ✅ **两阶段筛选** |
| 末尾筛选 | `>3.9` | top-1 远点 | `>3.9`（未修） | ✅ **quantile + 5~8 个** |
| 每代真实评估数 | 4~8 | 1 | 4~8 | 5~8 |
| onehot 编码 | 三类 | 三类 | 三类 | 三类（未改，**无 bug**） |

> 注：所有版本均对**关系对**做三类 one-hot（标签 {-1, 0, +1}）。解本身仍是二分类（好/非好）。

### 关键差异说明

- **vs REMO_new2_PIEA**：避免每代仅 1 解的保守性
- **vs REMO_new2_PIEA2**：
  1. 不再单一依赖 SDE（用户实测不好），改为三指标轮盘
  2. 不再加权融合（避免量纲冲突），改为两阶段筛选
  3. 修复 `>3.9` 阈值
  4. 新增 NDSort_SDR 反馈，让算法**自动学习**哪个指标在当前问题上更优

---

## 7. 关键设计抉择的理由

### 7.1 为什么保留 REMO_new2 的关系对 onehot 三类编码？

`REMO_new2` 用 `GetRelationPairs` 构造**关系对**，每个关系对的标签 ∈ {-1, 0, +1}，**包含同类对（C1C1, C2C2 → 0）**。原 onehot 三类编码（[1,0,0]/[0,1,0]/[0,0,1]）与训练数据完全一致，**没有 bug**。我之前对 `REMO_new2_clean` 的诊断只对那个版本有效，对 `REMO_new2` 不成立。

> **重要区分**：解（individual）的分类是**二元**的（Catalog ∈ {false, true}）；关系对（pair）的标签是**三元**的（Ls ∈ {-1, 0, +1}）。两者不要混淆。

### 7.2 为什么不引入 RVEA APD / Dropout 集成？

K-RVEA、ABSAEA 等基于 Kriging + APD 的算法在超多目标 SAEA 上表现不优于 REMO 系列。盲目借鉴流行算法容易"换掉好部件"。本设计**只借鉴有验证证据**的 PIEA（IS 2024）核心机制。

### 7.3 为什么用两阶段筛选而非加权混合？

- 关系网络打分量纲：约 [-4, +4]（C_SCORE 差值）
- 指标 SVR 打分量纲：取决于具体指标（SDE 用 tansig 在 [-1,1]，I_eps+ 在负值域，MD 在负距离）
- 加权混合需精细调权重 α，且不同指标量纲不一致 → 难调
- 两阶段则让两者各管一段：粗筛只看相对排序（关系网络优势），精排看绝对值（指标优势）

### 7.4 为什么 quantile 阈值 = 0.7 不是 0.9？

经过粗筛后只剩 30% 的候选解（n_keep = ⌈0.3·|Next|⌉）。在已经"高潜力"的子集中再用 0.9 会导致选不出足够的解；0.7 留出更宽容的余量，配合 5~8 个的硬性下限。

### 7.5 为什么每代评估 5~8 个解？

- maxFE = 300，初始 N = 100 → 剩余 200 次评估
- 若每代 1 个：进化 200 代，但每代代理训练开销大
- 若每代 8 个：进化 25 代，可能不够
- 5~8 个：进化 25~40 代，平衡进化代数与代理训练开销

### 7.6 为什么 NDSort_SDR 反馈用 score ∈ {0, 1, 2}？

直接采用 PIEA 原作设计：
- 0 = 新解被支配（差）
- 1 = 在 NDSort F1（中）
- 2 = 在 NDSort_SDR F1（极优，因为 SDR 更严格）

对应 Win_record 增量 = score / 2 ∈ {0, 0.5, 1.0}，平滑过渡。

> **注意**：score 是用来评估**当代选中的指标好不好**（输入到 UpdateInformation 更新轮盘 Pw），**不是解的分类标签**。本算法中**解的分类始终是二元的**（好 vs 非好）。

---

## 8. 文件组织

```
REMO_new2_PIEA3/
│
├── REMO_new2_PIEA3.m            # 主算法（含 PIEA 反馈循环）
│
├── ── 复用自 REMO_new2（未改）─────────────────────────
├── DataProcess.m                # 训练/测试集划分（3:1）
├── Delequalsamples.m            # 删除标签为 0 的样本（未实际调用）
├── GetOutput_PBI.m              # PBI 二元分类
├── GetRelationPairs.m           # 构造关系对（含 0 标签）
├── HybridPBI_Classification.m   # 混合 PBI 分类（输出二元 Catalog: false/true）
├── onehotconv.m                 # 关系对标签 {-1,0,+1} 的三类 onehot 编解码
├── RefSelect.m                  # 雷达网格环境选择
│
├── ── 新增 PIEA 风格组件 ────────────────────────────
├── Shape_Estimate.m             # PF 形状参数 Lp 估计
├── calFitness_SDE.m             # SDE + Minkowski 退化
├── calFitness_epsilon.m         # I_epsilon+ 不可加性
├── calFitness_MD.m              # Minkowski(Lp) 距离
├── NDSort_SDR.m                 # 强支配关系排序
├── UpdateInformation.m          # 滑动窗口 + 轮盘 Pw 更新
│
└── ── 核心改进文件 ──────────────────────────────────
    ├── IndicatorSelector.m          # 轮盘选 + Lp 自适应
    └── RSurrogateAssistedSelection.m # 两阶段筛选 + quantile
```

---

## 9. 推荐运行与调试

### 9.1 冒烟测试

```matlab
cd d:\PlatEMO-master\PlatEMO-master\PlatEMO
platemo('algorithm', @REMO_new2_PIEA3, ...
        'problem', @DTLZ2, ...
        'M', 5, 'D', 30, 'maxFE', 300)
```

预期：能跑完无报错，IGD 收敛曲线下降。

### 9.2 与 REMO_new2 对比

```matlab
% baseline
platemo('algorithm', @REMO_new2, 'problem', @DTLZ2, 'M', 10, 'D', 30, 'maxFE', 300, 'run', 5)

% 新算法
platemo('algorithm', @REMO_new2_PIEA3, 'problem', @DTLZ2, 'M', 10, 'D', 30, 'maxFE', 300, 'run', 5)
```

验收标准：5 次平均 IGD 优于 REMO_new2。

### 9.3 观察轮盘行为

在 `UpdateInformation.m` 末尾临时添加调试打印：

```matlab
fprintf('Pw = [SDE=%.3f, I_eps+=%.3f, MD=%.3f]\n', p(1), p(2), p(3));
```

预期现象：
- DTLZ2 (concave PF, Lp ≈ 0.5)：MD 概率上升（Lp 距离形状匹配）
- DTLZ1 (linear PF, Lp ≈ 1)：三者较均衡
- DTLZ7 (disconnected)：SDE 概率上升（密度估计擅长断裂区域）

### 9.4 关键消融实验

| 消融项 | 修改方式 | 预期效果 |
|---|---|---|
| 仅关系网络 | 注释掉 Stage C（指标 SVR 精排） | 退化为 REMO_new2 + quantile |
| 仅指标 SVR | 跳过 Stage A/B（直接 GA 后用 SVR 排） | 退化为 PIEA 风格 |
| 固定 SDE | `flag` 强制 = 1 | 退化为 REMO_new2_PIEA2 风格 |
| 不反馈 | 注释掉 Step 7 | 轮盘退化为均匀 |

### 9.5 调参建议

| 参数 | 默认值 | 调节建议 |
|---|---|---|
| `k` | 6 | 一般不动；超多目标可增至 10 |
| `gmax` | 3000 | 可降到 1000~2000 节省时间 |
| `tau` | 20 | 窗口越大越稳定但学得越慢；M 大可调到 30 |
| Stage B 比例 | 0.3 | 过小导致精排集太少；M 越大可放大到 0.4 |
| Stage D 分位数 | 0.7 | 阈值越严选解越少；可调到 0.6~0.8 |
| 每代评估数 | 5~8 | maxFE 充裕可降到 3~5（更多代数） |

---

## 参考文献

1. **REMO**：H. Hao, A. Zhou, H. Qian, and H. Zhang. "Expensive multiobjective optimization by relation learning and prediction." *IEEE Transactions on Evolutionary Computation*, 2022, 26(5): 1157-1170.

2. **PIEA**：Y. Li, W. Li, S. Li, and Y. Zhao. "A performance indicator-based evolutionary algorithm for expensive high-dimensional multi-/many-objective optimization." *Information Sciences*, 2024.

3. **SDE**：M. Li, S. Yang, and X. Liu. "Shift-based density estimation for Pareto-based algorithms in many-objective optimization." *IEEE Transactions on Evolutionary Computation*, 2014.

4. **NDSort_SDR**：原作来源同 PIEA，借鉴 SPEA-R 系列的强支配关系思想。

5. **PlatEMO**：Y. Tian, R. Cheng, X. Zhang, and Y. Jin. "PlatEMO: A MATLAB platform for evolutionary multi-objective optimization." *IEEE Computational Intelligence Magazine*, 2017, 12(4): 73-87.
