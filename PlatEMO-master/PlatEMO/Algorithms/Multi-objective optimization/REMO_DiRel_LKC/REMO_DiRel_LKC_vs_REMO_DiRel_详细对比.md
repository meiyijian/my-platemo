# REMO_DiRel_LKC 与 REMO_DiRel 详细对比

本文档对 `REMO_DiRel_LKC` 和原始 `REMO_DiRel` 的当前实现进行代码级对比，重点说明 LKC 版本的改动点、改动动机，以及这些改动带来的优缺点。

## 1. 总体结论

`REMO_DiRel` 的核心思路是：用目标难度排序选出“易目标子集”，训练“全目标关系网络 + 易目标子网络”，再用逐候选的逆方差仲裁融合两个网络的预测。

`REMO_DiRel_LKC` 保留了这条主线，但将“易目标子集”从原来的原始目标列集合，升级为“结构相关目标组的聚合空间”。也就是说，LKC 版本不再简单地说“第 1、3、5 个目标比较容易，所以拿它们训练子网络”，而是先判断目标之间的结构相似性，把正相关且可靠的目标聚成组，再在组层面选择容易建模的聚合目标来训练子网络。

一句话概括：

> `REMO_DiRel_LKC = REMO_DiRel 主循环 + LKC 结构感知目标分组 + 组级易目标选择 + Pareto-first 关系标签 + 全目标优先仲裁`

## 2. 文件级变化概览

| 模块 | REMO_DiRel | REMO_DiRel_LKC | 变化类型 |
|---|---|---|---|
| 算法入口 | `REMO_DiRel.m` | `REMO_DiRel_LKC.m` | 主流程重写，加入结构分组与诊断 |
| 难度估计 | `DifficultyProfiler.m` | `DifficultyProfiler.m` | 基本沿用 |
| 冲突度 | `ConflictDegree.m` | `ConflictDegree.m` | 基本沿用 |
| 易目标冗余修正 | `RefineEasySubset.m` | `RefineEasySubset.m` | 基本沿用，但 LKC 外层又做组级选择 |
| 双网络训练 | `TrainDualScaleNet.m` | `TrainDualScaleNet.m` | 基本沿用 |
| 迁移初始化 | `TransferFineTune.m` | `TransferFineTune.m` | 基本沿用 |
| 关系对构造 | `GetRelationPairsBudgeted.m` | `GetRelationPairsBudgeted_LKC.m` | 标签语义明显改变 |
| 仲裁选择 | `ArbitratedSelection.m` | `ArbitratedSelection_LKC.m` | 保留 GA 框架，评分阈值和返回诊断改变 |
| 仲裁评分 | `ArbitratorScore.m` | `ArbitratorScore_LKC.m` | 从逆方差混合改为全目标优先、子空间补充 |
| 结构分组 | 无 | `BuildObjectiveStructure_LKC.m` | 新增核心模块 |
| 组级易目标 | 无 | `BuildStructureAwareEasySet.m` | 新增核心模块 |
| 目标聚合 | 无 | `AggregateObjectives_LKC.m` | 新增工具模块 |
| 测试 | 无独立 LKC 测试 | `test_units_LKC.m`, `run_smoke_LKC.m` | 新增轻量测试 |

## 3. 主流程对比

### 3.1 REMO_DiRel 主流程

原始 `REMO_DiRel.m` 每代主要执行：

1. 选择参考解 `RefSelect(Population, k)`。
2. 用 `DifficultyProfiler` 给每个原始目标计算难度 `d_score`。
3. 按难度选出原始易目标索引 `S_easy`。
4. 全目标空间：用 `GetOutput_PBI(PopObj, RefObj)` 生成 PBI 类别，再用 `GetRelationPairsBudgeted` 构造关系对。
5. 易目标子空间：取 `PopObj(:, S_easy)`，生成子空间参考向量，再用 PBI 类别构造关系对。
6. 用 `TrainDualScaleNet` 训练全目标网络 `nets_F` 和易目标网络 `nets_S`。
7. 用 `ArbitratedSelection` 生成候选解并仲裁筛选。
8. 真实评估候选解，更新 archive 和 population。

### 3.2 REMO_DiRel_LKC 主流程

`REMO_DiRel_LKC.m` 每代主要执行：

1. 选择参考解 `RefSelect(Population, k)`。
2. 提取当前 `Input = Population.decs` 和 `PopObj = Population.objs`。
3. 调用 `BuildObjectiveStructure_LKC(Input, PopObj, structCfg)` 构建目标结构：
   - 基于已评估样本估计局部斜率特征 `Gamma`；
   - 用 Pearson 相关构造目标结构相似度 `Sim`；
   - 用相关距离 K-means 聚类目标；
   - 对不可靠或负相关组进行拆分；
   - 得到目标组 `Groups` 和聚合目标 `AggregatedObj`。
4. 调用 `BuildStructureAwareEasySet`：
   - 仍然用原始 `DifficultyProfiler` 计算每个目标的 `d_score`；
   - 将原始目标难度提升到组级难度；
   - 选择可靠且容易建模的目标组；
   - 输出 `EasyAggObj`，即易目标组的聚合目标值。
5. 全目标空间：用 `GetRelationPairsBudgeted_LKC(Input, PopObj, pairMax, RefObj, scalarGap)` 构造关系对。
6. 易聚合空间：用 `GetRelationPairsBudgeted_LKC(Input, EasyAggObj, pairMax, Ref_S_obj, scalarGap)` 构造关系对。
7. 用原来的 `TrainDualScaleNet` 训练双网络。
8. 构造更丰富的 `Smodel`，加入结构状态、仲裁阈值、惩罚系数和诊断字段。
9. 用 `ArbitratedSelection_LKC` 进行候选生成和评分。
10. 保存 `Algorithm.metric.lkcDiag{gen,1}`，记录分组、可靠性、难度和仲裁统计。
11. 真实评估候选解，更新 archive 和 population。

核心区别在第 3-6 步：LKC 版本把“子网络学什么”从原始易目标，改成了结构分组后的易聚合目标。

## 4. 关键改动一：新增 LKC 结构感知目标分组

对应文件：`BuildObjectiveStructure_LKC.m`

### 4.1 原始做法

`REMO_DiRel` 不显式建立目标结构。它只根据每个原始目标的难度分数排序，直接选出 `S_easy`。目标之间的关系只通过 `ConflictDegree` 和 `RefineEasySubset` 间接影响选择。

这种做法简单，但存在两个问题：

1. 容易目标可能高度冗余，例如多个目标本质上表达同一趋势。
2. 仅按单目标难度选择，可能忽略“目标之间是否应该放在一起建模”。

### 4.2 LKC 做法

LKC 版本新增结构构建步骤：

1. 对决策变量 `PopDec` 和目标值 `PopObj` 做安全 min-max 归一化。
2. 按 `nCells` 将决策空间的对角方向划分成若干局部 cell。
3. 在每个 cell 和每个决策维度上，选择两个已评估样本近似局部端点。
4. 用目标差分除以决策差分，形成局部斜率特征矩阵 `Gamma`。
5. 对 `Gamma` 的行计算 Pearson 相关，得到目标间结构相似度 `Sim`。
6. 用相关距离 K-means 对目标聚类，并用 silhouette 分数选择聚类数。
7. 对聚类结果进行修复：
   - 若组内出现非正相关，则按正相关连通分量拆分；
   - 若组内平均相似度低于 `minGroupReliability`，则拆成单目标组。
8. 对每个可靠目标组进行聚合，生成 `AggregatedObj`。

### 4.3 改动动机

这个改动的动机是：在多/超多目标优化中，目标之间并不只是“难或易”，还存在结构相似、冗余、冲突和负相关。直接在原始目标列上选子集，可能选到一组容易但信息重复的目标，也可能把结构冲突的目标混在子网络中。

LKC 分组希望把“目标选择”提升为“结构选择”：

- 正相关且局部变化模式相似的目标可以合成一个更稳定的组；
- 强负相关目标不应因为 `abs(corr)` 高就被合并；
- 子网络看到的是可靠结构组，而不是零散目标列。

### 4.4 优点

- 能降低子网络目标空间维度，缓解超多目标下关系学习困难。
- 能显式处理目标冗余，避免易目标子集被相似目标占满。
- 能避免强负相关目标被错误合并，减少聚合后的语义冲突。
- 只使用已评估样本估计结构，不额外增加昂贵真实评估。
- 有 fallback 机制：结构特征不足时退化为单目标组，不会强行聚类。

### 4.5 缺点和风险

- 每代都要构建 `Gamma`、计算相似度和聚类，有额外运行开销。
- 早期样本较少时，局部斜率估计可能不稳定，分组质量依赖初始采样覆盖。
- `nCells`、`minGroupReliability` 会影响分组粒度，参数过严会退化为单目标组，过松会合并不可靠目标。
- 目标聚合会损失组内个别目标的信息，可能掩盖某些目标的局部极端行为。
- 如果真实问题的目标关系高度非线性或阶段性变化，基于当前 population 的结构估计可能滞后。

## 5. 关键改动二：易目标选择从“原始目标级”变为“结构组级”

对应文件：`BuildStructureAwareEasySet.m`

### 5.1 原始做法

`REMO_DiRel` 直接调用：

```matlab
[d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy);
```

其中 `S_easy` 是原始目标索引，例如 `[1, 3, 5]`。随后子网络在 `PopObj(:, S_easy)` 上构造关系标签。

### 5.2 LKC 做法

LKC 仍然先计算原始目标难度：

```matlab
[d_score, H, S_easy_orig] = DifficultyProfiler(Population, H, gen, alpha, k_easy);
```

但它不直接使用 `S_easy_orig` 作为子网络目标，而是把原始难度提升到目标组：

```matlab
groupDifficulty(g) = mean(d_score(C)) + eta * std(d_score(C));
```

其中 `C` 是第 `g` 个目标组内的原始目标集合，默认 `eta = 0.5`。也就是说，一个组不仅要平均难度低，还要组内目标难度差异不能太大。

然后根据可靠性过滤：

```matlab
valid = isfinite(groupDifficulty) & reliability >= minRel;
```

再用组级分数排序：

```matlab
groupScore = groupDifficulty ./ max(reliability, eps) - lambdaRel * reliability;
```

最后选择若干个易组，直到覆盖的原始目标数量达到 `k_easy`。

### 5.3 改动动机

原始 `DifficultyProfiler` 判断的是“单个目标是否容易建模”，但子网络真正需要的是“一个低维子空间是否值得学习”。如果几个目标单独看都容易，但彼此结构不一致，直接组合成子网络仍然可能让关系标签混乱。

LKC 的组级选择把两个标准结合起来：

- 难度低：这个组容易被代理模型学习；
- 可靠性高：组内目标结构相似，聚合后的语义更稳。

### 5.4 优点

- 子网络训练目标更一致，减少原始易目标组合带来的内部冲突。
- `mean + eta * std` 能惩罚组内难度不均衡，避免一个困难目标拖累整个组。
- 可靠性过滤可以防止低质量聚类被用于子网络。
- 保留原始 `DifficultyProfiler`，所以改动没有完全推翻原始 DiRel 的难度机制。

### 5.5 缺点和风险

- 如果可靠组数量不足，会 fallback 到原始易目标逻辑，LKC 优势会减弱。
- 组级选择可能使实际选中的原始目标数量超过 `k_easy`，子网络维度不一定严格等于原始设定。
- 对 `minRel` 较敏感：高阈值更保守但可能过度拆分，低阈值更激进但可能引入不可靠组。
- 组内聚合后，某些单个目标的难度信息只通过组难度间接体现。

## 6. 关键改动三：子网络训练空间从原始易目标变为易聚合目标

对应文件：`REMO_DiRel_LKC.m`, `AggregateObjectives_LKC.m`, `BuildObjectiveStructure_LKC.m`

### 6.1 原始做法

原始 `REMO_DiRel` 的子网络目标值为：

```matlab
PopObjSub = PopObj(:, S_easy);
```

子网络学习的是原始目标子集上的关系。

### 6.2 LKC 做法

LKC 子网络目标值为：

```matlab
EasyAggObj = StructState.AggregatedObj(:, selected);
```

每个聚合目标来自一个目标组。组内聚合权重通过结构特征中心距离确定：

```matlab
w = exp(-dist);
w = w ./ sum(w);
AggregatedObj(:, g) = F(:, C) * w(:);
```

其中 `F` 是归一化后的目标值，`C` 是组内目标索引。越接近组中心的目标权重越大。

### 6.3 改动动机

原始子网络的输入标签来自若干原始目标列，这些目标之间可能有冗余或冲突。LKC 希望子网络学习“结构稳定的低维视角”，而不是“若干单目标拼接视角”。

这种设计的本质是把子网络从 raw-objective subspace 改为 structure-aware aggregated subspace。

### 6.4 优点

- 子空间维度可能更低，关系学习更容易。
- 聚合目标可吸收组内多个相似目标的信息，比单独挑一个目标更稳。
- 对冗余目标友好，能把多个相似目标合成一个代表信号。
- 子网络的预测更适合当作“补充证据”，而不是和全目标网络完全对等。

### 6.5 缺点和风险

- 聚合目标不再是原始优化问题中的真实目标，语义解释需要更谨慎。
- 聚合会平滑掉组内差异，可能让某些目标的约束性变弱。
- 如果分组错误，聚合目标会把不该合并的目标混在一起，影响子网络标签质量。
- 子网络与全目标网络的目标语义差异变大，因此后续仲裁必须更保守。

## 7. 关键改动四：关系对标签从 PBI 类别关系改为 Pareto-first 目标空间关系

对应文件：`GetRelationPairsBudgeted.m`, `GetRelationPairsBudgeted_LKC.m`

### 7.1 原始做法

原始 `GetRelationPairsBudgeted` 接收的是 `Catalog`，而不是目标值本身。`Catalog` 通常来自 `GetOutput_PBI`：

- `Catalog == 1` 视为正类；
- `Catalog ~= 1` 视为负类；
- 正类对负类构造 `+1`；
- 负类对正类构造 `-1`；
- 同类内部构造 `0`。

这种标签更接近“PBI 分类下的相对关系”，不是真正逐对 Pareto 支配判断。

### 7.2 LKC 做法

`GetRelationPairsBudgeted_LKC` 直接接收目标值 `Obj`：

```matlab
[XXs, Ls, Catalog] = GetRelationPairsBudgeted_LKC(Input, Obj, pairMax, RefObj, scalarGap);
```

它先在传入的目标空间中做归一化，然后对每对解进行比较：

1. 如果 `i` Pareto 支配 `j`，标签为 `+1`。
2. 如果 `j` Pareto 支配 `i`，标签为 `-1`。
3. 如果互不支配，则比较归一化目标均值差：
   - `mean(fi) - mean(fj) < -scalarGap`，标签为 `+1`；
   - `mean(fi) - mean(fj) > scalarGap`，标签为 `-1`；
   - 否则标签为 `0`。
4. 如果完全没有 `+1/-1` 标签，则退回 PBI-like catalog 采样。

返回的 `Catalog` 仍用于后续 anchor 选择，但主要训练标签来自 objective-space pairwise comparison。

### 7.3 改动动机

LKC 子网络的目标空间是聚合目标空间，不再是原始目标列。继续使用原始 PBI 类别关系，可能会让标签语义和聚合空间不一致。

因此 LKC 改成“目标空间内直接比较”：

- 全目标网络在全目标空间中比较；
- 子网络在易聚合目标空间中比较；
- 两者的标签都由各自目标空间的目标值直接产生。

### 7.4 优点

- 标签语义更接近 Pareto 优劣关系，而不仅是参考向量类别。
- 同一个函数可用于全目标空间和聚合目标空间，接口更统一。
- `scalarGap` 给互不支配样本提供弱偏好标签，避免标签 0 过多。
- 仍保留 PBI fallback，防止极端情况下训练样本全为 0。

### 7.5 缺点和风险

- 互不支配样本用目标均值差做弱偏好，本质上引入了加权和式标量化偏好，可能偏向均衡解。
- `scalarGap` 设置过小会把大量互不支配关系强行分成 `+1/-1`，过大则会产生太多 `0`。
- 代码仍枚举 `N*(N-1)` 有向关系后再采样，`pairMax` 限制的是训练集规模，不完全限制构造开销。
- 聚合空间中的 Pareto 关系不等价于原始全目标 Pareto 关系，因此子网络输出不能被解释为全局支配判断。

## 8. 关键改动五：仲裁策略从“逆方差融合”改为“全目标优先 + 子空间补充”

对应文件：`ArbitratorScore.m`, `ArbitratorScore_LKC.m`, `ArbitratedSelection.m`, `ArbitratedSelection_LKC.m`

### 8.1 原始仲裁

原始 `ArbitratorScore` 对每个候选解分别得到：

- 全目标网络均值和方差：`mu_F`, `sigma2_F`
- 子目标网络均值和方差：`mu_S`, `sigma2_S`

然后用逐候选逆方差权重融合：

```matlab
w_F = (1 / sigma2_F) / (1 / sigma2_F + 1 / sigma2_S)
score = w_F * score_F + (1 - w_F) * score_S
```

如果两个模型冲突：

- 两边都不确定时弃权；
- 子目标确定而全目标不确定时，给多样性奖励。

这种设计默认全目标网络和子目标网络是相对对等的两个证据源。

### 8.2 LKC 仲裁

LKC 版本更加保守。它认为：

> 子网络只在易聚合目标空间内有效，不能直接覆盖全目标网络。

因此 `ArbitratorScore_LKC` 采用全目标优先：

```matlab
highF = abs(mu_F) >= marginF & sigma2_F <= uncF;
highS = abs(mu_S) >= marginS & sigma2_S <= uncS;
fullUncertain = ~highF;
triggerSub = fullUncertain & highS;
```

最终得分为：

```matlab
scores = baseFull
       + tieWeight * triggerSub * subPreference
       - betaUncertainty * uncertaintyPenalty
       - lambdaDisagreement * disagreement
       + gammaNovelty * novelty;
```

其中：

- `baseFull = 2 + 2 * tanh(mu_F)`，主分数来自全目标网络；
- `subPreference = max(0, tanh(mu_S))`，子网络只提供正向补充；
- `triggerSub` 要求全目标不确定且子网络高置信；
- `disagreement` 会触发惩罚；
- `novelty` 衡量候选解到已有训练样本的距离。

最终筛选阈值也从原始的 `3.9` 改为 `Smodel.scoreThreshold`，默认 `3.4`。

### 8.3 改动动机

由于 LKC 子网络学习的是“易聚合目标空间”的关系，不是全目标关系，它的预测语义更窄。如果继续像原始 DiRel 一样用逆方差把全目标和子目标近似对等融合，就可能出现一种风险：子空间很确定但全目标上实际不好，导致错误推荐。

所以 LKC 仲裁改成：

- 全目标网络负责主判断；
- 子网络只在全目标不确定时做 tie-break；
- 如果子网络与全目标信号冲突，要惩罚而不是奖励；
- 新颖性奖励保留，但权重更小。

### 8.4 优点

- 降低子空间误导全局选择的风险。
- 更符合 LKC 子网络的语义边界：它是补充证据，不是全局支配判断。
- 增加诊断信息，可观察 full uncertain ratio、sub triggered ratio、disagreement ratio 等。
- 阈值从 `3.9` 放宽到 `3.4`，在更保守的评分公式下避免候选过少。

### 8.5 缺点和风险

- 子网络影响力被削弱，若全目标网络长期不准，LKC 子网络的优势可能发挥不出来。
- 新增多个内部系数：`margin_F`, `margin_S`, `tieWeight`, `betaUncertainty`, `lambdaDisagreement`, `gammaNovelty`, `scoreThreshold`，需要实验确认稳定性。
- `baseFull = 2 + 2*tanh(mu_F)` 使分数主要由全目标网络控制，可能降低探索性。
- 当前 novelty 是候选到训练 archive 的最小距离，与原始候选间 novelty 不同，更偏向远离已评估区域，可能增加探索但也可能浪费昂贵评估。

## 9. 参数变化

### 9.1 原始参数

`REMO_DiRel` 的公开参数为：

```matlab
k_easy, tau_conf, alpha, k, gmax, K_ens, win_K
```

默认值：

```matlab
-1, 0.3, 0.6, 6, 1000, 3, 3
```

### 9.2 LKC 新增参数

`REMO_DiRel_LKC` 保持前 7 个参数兼容，并新增：

```matlab
nCells, minRel, scalarGap
```

默认值：

```matlab
5, 0.65, 0.05
```

含义如下：

| 参数 | 默认 | 作用 | 调大影响 | 调小影响 |
|---|---:|---|---|---|
| `nCells` | `5` | LMVT 局部斜率估计的 cell 数 | 结构特征更细，但更依赖样本密度 | 更稳更粗，但可能看不出局部结构 |
| `minRel` | `0.65` | 目标组合并的最低可靠性 | 分组更保守，更多 singleton | 分组更激进，错误合并风险上升 |
| `scalarGap` | `0.05` | 非支配样本转偏好标签的均值差阈值 | 更多标签为 0，更保守 | 更多 `+1/-1`，但标量化偏差更强 |

LKC 还在 `Smodel` 内部固定了若干仲裁参数：

| 字段 | 默认 | 作用 |
|---|---:|---|
| `margin_F` | `0.15` | 全目标网络高置信均值边界 |
| `margin_S` | `0.15` | 子网络高置信均值边界 |
| `uncertainty_F` | `tau_conf^2` | 全目标方差阈值 |
| `uncertainty_S` | `tau_conf^2` | 子网络方差阈值 |
| `tieWeight` | `0.5` | 子网络 tie-break 加分权重 |
| `betaUncertainty` | `0.25` | 全目标不确定性惩罚权重 |
| `lambdaDisagreement` | `0.75` | 全/子网络冲突惩罚 |
| `gammaNovelty` | `0.25` | novelty 奖励 |
| `scoreThreshold` | `3.4` | 最终候选筛选阈值 |

这些参数目前是代码内固定值，适合作为后续敏感性分析或消融实验对象。

## 10. 保留不变的设计

LKC 版本没有全面推翻 `REMO_DiRel`，以下部分基本沿用：

1. 初始采样策略：`D <= 10` 时 `N = 11D - 1`，否则 `N = 100`。
2. 参考解选择：仍使用 `RefSelect(Population, k)`。
3. 原始目标难度估计：仍使用 `DifficultyProfiler`。
4. 冲突度计算：仍使用 `ConflictDegree`。
5. 双尺度网络训练：仍使用 `TrainDualScaleNet`。
6. 子网络迁移初始化：仍使用 `TransferFineTune`。
7. GA 候选生成框架：仍使用 `OperatorGA`。
8. 候选清理：仍做边界裁剪、去重、去已评估解、按剩余预算截断。

这说明 LKC 的核心贡献集中在“子网络目标空间”和“仲裁语义”上，而不是重新设计整个昂贵优化框架。

## 11. 改动后的整体优缺点

### 11.1 主要优点

1. 子网络语义更稳  
   原始子网络只看若干易目标列，LKC 子网络看结构可靠的聚合目标组，内部一致性更强。

2. 更适合超多目标冗余场景  
   当 M 较大且存在多个相似目标时，LKC 能把相似目标合并，降低关系学习压力。

3. 避免负相关误合并  
   LKC 明确使用正结构相似性，负相关目标会被拆开，不会因为绝对相关高而被合并。

4. 仲裁更符合子空间语义  
   子网络只在全目标不确定时发挥作用，降低局部视角误导全局选择的风险。

5. 诊断能力更强  
   新增 `lkcDiag`，可以观察分组结果、可靠性、组难度和仲裁触发比例。

### 11.2 主要缺点

1. 计算更复杂  
   每代增加结构估计、聚类、组修复和聚合，运行时间会高于原始 `REMO_DiRel`。

2. 参数更多  
   新增 `nCells`, `minRel`, `scalarGap`，内部还有若干仲裁系数，调参和解释成本上升。

3. 早期不稳定风险  
   初期样本较少时，局部斜率和结构相似性可能不可靠。

4. 聚合损失信息  
   目标组聚合会压缩原始目标信息，可能削弱某些目标的极端约束作用。

5. 子网络影响可能偏弱  
   全目标优先仲裁更安全，但可能让 LKC 子网络的积极作用不如原始逆方差融合明显。

## 12. 哪些场景更适合 LKC 版本

更适合 `REMO_DiRel_LKC` 的场景：

- 目标数较多，例如 10、15、20 目标。
- 多个目标之间存在明显冗余或相似变化趋势。
- 原始 `REMO_DiRel` 的 `S_easy` 经常选到高度相似目标，子网络贡献不稳定。
- 希望保守使用子空间模型，避免子网络覆盖全目标判断。
- 需要更多诊断信息分析算法行为。

更适合保留原始 `REMO_DiRel` 的场景：

- 目标数较少，结构分组收益不明显。
- 目标之间关系很弱或高度动态，聚合目标难以稳定。
- 运行时间预算很紧，需要尽量减少每代额外计算。
- 希望子网络和全目标网络以更对等方式融合。

## 13. 建议的实验与消融

为了验证 LKC 改动是否真正有效，建议至少做以下对比：

### 13.1 与原始算法直接对比

对比算法：

- `REMO_DiRel`
- `REMO_DiRel_LKC`

推荐指标：

- IGD 或 IGD+
- HV
- Runtime
- 每代真实评估候选数
- `DualNet.p_err_F`, `DualNet.p_err_S`

推荐问题：

- DTLZ2、DTLZ3、DTLZ4、DTLZ7
- WFG1、WFG4、WFG6、WFG9
- MaF 系列中目标冗余或冲突较明显的问题

目标数建议：

- `M = 5, 10, 15, 20`

### 13.2 LKC 内部消融

建议设计以下变体：

| 变体 | 目的 |
|---|---|
| 不做结构分组，全部 singleton | 验证 LKC 分组本身是否有效 |
| 做分组但不用聚合，仍选 raw objectives | 验证聚合目标是否有效 |
| 使用旧版逆方差仲裁 | 验证全目标优先仲裁是否必要 |
| 关闭组修复 `repairGroupsBySimilarity` | 验证正相关和可靠性约束是否必要 |
| `scalarGap = 0` 或很大 | 验证弱偏好标签对训练的影响 |
| 固定 `minRel` 多档扫描 | 分析分组保守程度对结果的影响 |

### 13.3 重点诊断字段

`REMO_DiRel_LKC.m` 中写入：

```matlab
Algorithm.metric.lkcDiag{gen, 1}
```

建议观察：

- `Groups`：目标分组是否符合问题结构。
- `GroupReliability`：可靠组比例是否足够。
- `groupDifficulty`：选中的组是否确实难度较低。
- `easyGroups`：子网络每代使用哪些组。
- `fullUncertainRatio`：全目标网络不确定比例。
- `subTriggeredRatio`：子网络实际参与仲裁比例。
- `disagreementRatio`：全/子网络冲突比例。
- `subTieBreakDominatedRatio`：子网络 tie-break 起正向作用的比例。

如果 `subTriggeredRatio` 长期接近 0，说明 LKC 子网络几乎没有参与决策；如果 `disagreementRatio` 很高，说明分组或子空间标签可能与全目标目标空间冲突较大。

## 14. 后续可改进方向

1. 缓存或低频更新结构分组  
   不一定每代都重新构建 `StructState`，可以每隔若干代更新一次，降低开销。

2. 自适应 `minRel`  
   初期样本少时提高保守性，中后期样本充分后允许更细致分组。

3. 改进非支配样本弱标签  
   当前用目标均值差和 `scalarGap`，可尝试 PBI 距离、参考向量角度、R2 指标或局部密度作为弱偏好。

4. 让仲裁参数可配置  
   当前 `margin_F`, `lambdaDisagreement`, `scoreThreshold` 等写在主流程中，后续可加入 `ParameterSet` 便于实验。

5. 引入组稳定性诊断  
   记录相邻代分组变化，若目标组频繁震荡，可触发更保守的 singleton fallback。

6. 子网络训练质量门控  
   当 `DualNet.p_err_S` 过高时，自动降低 `tieWeight` 或禁用子网络 tie-break。

## 15. 总结

`REMO_DiRel_LKC` 的主要贡献不是替换原始 DiRel 的全部机制，而是针对原始算法中“易目标子集过于依赖原始目标列”的问题，引入结构感知目标分组与聚合，使子网络学习更可靠、更低维的目标结构。

它的改动逻辑可以概括为：

1. 用 LKC 结构分析识别目标间正相关结构。
2. 在组层面选择可靠且易建模的目标结构。
3. 用聚合目标训练子网络。
4. 用 Pareto-first 标签增强关系语义。
5. 用全目标优先仲裁限制子网络的决策边界。

因此，LKC 版本更适合目标冗余明显、目标数较高、需要谨慎利用子空间模型的昂贵多目标优化场景。它的代价是更高的实现复杂度、更多参数和额外运行开销。后续实验应重点验证：结构分组是否提升了子网络质量，以及更保守的仲裁是否在保持安全性的同时仍能带来性能增益。
