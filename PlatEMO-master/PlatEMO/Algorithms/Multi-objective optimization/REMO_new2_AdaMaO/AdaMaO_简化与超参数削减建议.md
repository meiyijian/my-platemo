# REMO_new2_AdaMaO 简化与超参数削减建议

> 分析对象：`REMO_new2_AdaMaO` 目录，重点阅读主版本、`NoIndicator`、`Lite`、`AdaMaOSelection`、`HybridPBI_Classification`、`GetOutput_PBI`、关系对生成与数据处理模块。
> 目标：在不牺牲当前性能基础上，降低 PIEA 痕迹、减少超参数、压缩臃肿模块，使论文主线更清晰。

## 1. 总体判断

建议以 `REMO_new2_AdaMaO_Lite` 作为论文主算法底座，而不是继续维护完整 `REMO_new2_AdaMaO`。

理由很直接：

- 指标子系统已经被你的消融结果证明贡献不稳定，且原创性风险高。目录中的 `AdaMao_指标模式_消融分析报告.md` 也明确倾向 `Lite`。
- 主算法真正有价值的部分不是 PIEA 指标，而是 `HybridPBI_Classification -> 关系对学习 -> 代理辅助候选选择` 这条链。
- 现在的复杂度主要来自两类东西：一类是已经可删除的 indicator 分支；另一类是剩余模块里的硬阈值和模式切换。

因此，建议论文主线从“多模块集成”改成“参数内生化的自适应关系学习框架”。也就是说，尽量让参数由 `Problem.N/M/D/maxFE/FE`、覆盖率、验证误差、候选池规模自动决定，而不是作为需要敏感性分析的超参数。

## 2. 当前算法链条

当前 `Lite` 版本保留下来的核心流程是：

1. 初始化种群与 Archive。
2. `HybridPBI_Classification` 对当前种群打好/坏标签，并返回置信度与参考解。
3. 根据 `prev_p_err`、`mean_conf`、`coverage` 切换关系对训练模式：
   - `curriculum`
   - `weighted`
   - `conservative`
4. 训练关系预测神经网络。
5. 根据 `p_err` 与 `coverage` 切换候选选择模式：
   - `conservative`
   - `explore`
6. `AdaMaOSelection` 内部用 GA 生成候选，用关系模型打分，再选择少量真实评估。
7. 将新评估解加入 Archive，并用 `RefSelect` 环境选择下一代 Population。

这条主链是完整的，删除 indicator 后并不会断。

## 3. 外部超参数现状

`REMO_new2_AdaMaO_Lite.m` 当前仍通过：

```matlab
[k,gmax,q_keep,lambda0,w_min,n_min,n_max,tau_err,~,debug] = ...
    Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6,0.35,1,0);
```

暴露了 10 个位置，其中 `use_indicator` 已被忽略，`debug` 不属于算法性能参数。真正还影响性能的是 8 个：

| 参数        | 当前作用                                                 | 建议                                                                  |
| ----------- | -------------------------------------------------------- | --------------------------------------------------------------------- |
| `k`       | HPC 内部`RefSelect` 的参考解数量基数                   | 删除，改为`k_eff = min(Problem.N, ceil(1.5*Problem.M))`             |
| `gmax`    | 代理辅助 GA 的候选生成上限                               | 删除外部参数，改成候选预算，如`Problem.N * ceil(log2(Problem.N+1))` |
| `q_keep`  | explore 分位数筛选阈值，也用于 curriculum 保留高置信样本 | 删除，改为直接选固定数量`n_eval`，不再先过分位数                    |
| `lambda0` | 不确定性项基础权重                                       | 删除，改为验证误差相对基线误差的自适应权重                            |
| `w_min`   | 关系样本权重下限                                         | 删除，改为软权重或数据分位数下限                                      |
| `n_min`   | 每代最少真实评估数                                       | 删除，按`Problem.N` 和剩余预算自动决定                              |
| `n_max`   | 每代最多真实评估数                                       | 删除，按 coverage gap 自适应扩张                                      |
| `tau_err` | 判断模型是否可信的固定误差阈值                           | 删除，改为与多数类基线或随机基线比较                                  |

目标版本最好只保留：

- `debug`：仅用于打印。
- 可选的 `screenBudgetFactor`：如果你担心候选池大小影响运行时间，可以保留一个计算预算参数；但论文中可以写成固定内部预算，不作为算法调参点。

## 4. 超参数内生化方案

### 4.1 删除 `k`

当前写法：

```matlab
k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));
```

这里 `k=6` 只是下限，真正起作用的是 `1.5*M`。建议直接写成：

```matlab
k_eff = min(Problem.N, ceil(1.5*Problem.M));
```

这样 `k` 不再需要分析。论文里可解释为：参考解数量随目标维度线性增长，以覆盖 many-objective 的局部方向。

如果担心低维时参考解太少，可改为：

```matlab
k_eff = min(Problem.N, max(ceil(1.5*Problem.M), ceil(sqrt(Problem.N))));
```

但这会引入一个略复杂的经验公式。优先建议第一个版本。

### 4.2 删除 `gmax`

`gmax=3000` 是代理模型内部筛选候选的计算预算，不是直接真实评估预算。审稿人通常不希望它成为一个需要敏感性分析的搜索参数。

建议改为：

```matlab
wmax = Problem.N * ceil(log2(Problem.N + 1));
```

好处：

- 随种群规模增长；
- 不随具体问题手动调；
- 比固定 3000 更容易解释；
- 对常见 `Problem.N=100`，候选规模约 700，能显著减小内部 GA 的臃肿。

如果担心性能下降，可以在实验里比较一次 `3000` 与该公式，但不要作为论文主参数。

### 4.3 删除 `q_keep`

`q_keep=0.80` 当前有两处作用：

- `select_explore` 中用 `quantile(score_aug,q_keep)` 先筛候选；
- `GetRelationPairs_curriculum` 中保留高置信样本。

这两个都不适合保留为外部参数。

建议：

- 在候选选择里，不做分位数筛选，直接按 acquisition score 与多样性选出 `n_eval` 个；
- 在 curriculum 里，优先删除整个 curriculum 模式，详见第 6 节。

这样 `q_keep` 可以完全消失。

### 4.4 删除 `lambda0`

当前不确定性权重：

```matlab
lambda_t = Smodel.lambda0 * (1 - Smodel.ratio) * max(0,1 - p_err/0.45);
```

问题是 `0.35` 和 `0.45` 都是硬阈值。建议改成数据驱动：

```matlab
p_base = 1 - max(class_counts) / sum(class_counts);
model_gain = max(0, (p_base - p_err) / max(p_base, eps));
lambda_t = (1 - ratio) * model_gain;
```

含义：

- 如果模型只是比多数类猜测还差，就不信任不确定性；
- 如果模型明显优于基线，则允许探索；
- 早期探索更强，后期自然收缩。

这样 `lambda0` 和 `0.45` 都可以删除。

### 4.5 删除 `w_min`

当前加权训练会把样本权重归一化后截断：

```matlab
EW = max(EW,w_min);
```

`w_min=0.30` 很难解释。建议改成软权重：

```matlab
W_pair = 0.5 + 0.5 * sqrt(conf_i * conf_j);
```

这样权重天然落在 `[0.5,1]`，不会出现极小权重，也不需要 `w_min`。如果你不想引入 `0.5` 这个常数，也可以采用分位数下限：

```matlab
EW = EW ./ mean(EW);
EW = max(EW, quantile(EW,0.10));
```

我更推荐软权重版本，叙述最简单。

### 4.6 删除 `n_min/n_max`

当前每代真实评估数是 4 到 6。建议改成由种群规模和覆盖率自动决定：

```matlab
n_base = max(1, ceil(Problem.N/25));
n_extra = ceil((1 - diagnostics.coverage) * Problem.N/50);
n_eval = min(remain, n_base + n_extra);
```

对 `Problem.N=100`，这基本等价于当前的 4 到 6，但不再是外部超参数：

- 覆盖好时少评估；
- 覆盖差时多评估；
- 真实评估数随种群规模自然变化。

论文里可以写成“evaluation batch size is determined by population scale and coverage gap”。

### 4.7 删除 `tau_err`

当前 `tau_err=0.35` 同时控制关系对训练模式和候选选择模式：

```matlab
if prev_p_err > tau_err
    relation_mode = 'curriculum';
elseif prev_p_err <= tau_err && mean_conf >= 0.55 && diagnostics.coverage < 0.60
    relation_mode = 'weighted';
end

if p_err <= tau_err && diagnostics.coverage < 0.60
    candidate_mode = 'explore';
end
```

建议不要再用固定误差阈值。替换为：

```matlab
p_base = majority_class_error(TestOut);
model_reliable = p_err < p_base;
```

进一步简化时，甚至不需要 `model_reliable` 这种硬变量，而是使用第 4.4 节的 `model_gain` 连续控制探索强度。

## 5. 隐藏超参数与建议

当前即使外部参数删掉，内部仍有不少硬编码常数。它们也会影响论文观感。

| 位置                  |                      当前常数 | 问题                               | 建议                                                                       |
| --------------------- | ----------------------------: | ---------------------------------- | -------------------------------------------------------------------------- |
| 关系模式切换          |         `mean_conf >= 0.55` | 人为阈值                           | 删除模式切换，始终用软置信权重                                             |
| 关系/候选模式切换     |           `coverage < 0.60` | 人为阈值                           | 改用`coverage_gap = 1 - coverage` 连续控制                               |
| explore 权重          |                `p_err/0.45` | 人为阈值                           | 改用多数类基线误差                                                         |
| diversity acquisition |                 `0.75/0.25` | 又一个权重                         | 可保留为固定内部选择准则；若要更干净，改成先按分数取池再 max-min diversity |
| Hybrid PBI            |                   `theta=5` | MOEA/D 风格固定惩罚                | 改为当前种群的尺度自校准                                                   |
| GetOutput_PBI         | `[-20,20]` 与 `[0.3,0.7]` | 为了凑标签比例，不一定提升标签质量 | 改成连续 local PBI score                                                   |
| Hybrid 分类           |                  `N/4` 好解 | 中间解被并入坏类                   | 建议中间解不参与强监督关系对，或改三类/软标签                              |
| K-means               | `MaxIter=100, Replicates=5` | 计算开销和随机性                   | 若保留，固定随机流；若简化，优先用均匀向量                                 |

## 6. 模块删除优先级

### 6.1 第一优先级：彻底删除 indicator 子系统

这部分已经有消融支撑，建议作为最终版本删除。

可删内容：

- `IndicatorSelector.m`
- `Shape_Estimate.m`
- `calFitness_SDE.m`
- `calFitness_epsilon.m`
- `calFitness_MD.m`
- `UpdateInformation.m`
- `NDSort_SDR.m`
- `AdaMaOSelection.m` 中的 `select_indicator`
- `REMO_new2_AdaMaO.m` 中的 `indicator` 初始化、`fitrsvm IndicatorModel`、indicator feedback
- `Smodel.IndicatorModel` 字段
- `use_indicator` 参数

论文叙述建议：

> We tested an external indicator-assisted selection component inspired by PIEA, but found no consistent improvement. Therefore, it is deliberately removed to keep the proposed framework focused on adaptive relation learning.

这不是弱点，反而是一个很好的消融故事。

### 6.2 第二优先级：删除 curriculum 模式

当前 `curriculum` 模式在 `prev_p_err > tau_err` 时触发，保留高置信度前 80% 样本。

问题：

- `tau_err` 与 `q_keep=0.80` 都是超参数；
- 第一代 `prev_p_err=1`，几乎必定进入 curriculum；
- 当样本本来就少时，丢掉 20% 可能让关系模型更不稳；
- 它和 confidence weighting 的目标重复，都是处理标签噪声。

建议：

- 删除 `GetRelationPairs_curriculum` 与 `KeepMostConfident`；
- 始终使用全体关系对；
- 用软置信权重降低低置信样本影响。

这样可以一次删掉 `q_keep`、`tau_err` 的一部分作用和一个模式分支。

### 6.3 第三优先级：把 weighted/conservative 合并

现在 `weighted` 与 `conservative` 是两条关系训练路径。

建议合并为一条：

```matlab
[XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);
[net,TrainIn_struct,p_err] = TrainRelationModel(XXs,YYs,WWs);
```

如果使用第 4.5 节的软权重，低置信度样本不会被完全压掉。这样不再需要：

- `relation_mode`
- `mean_conf >= 0.55`
- `coverage < 0.60` 触发 weighted
- `w_min`
- `DataProcess` 与 `DataProcess_confidence` 两套重复逻辑

风险：如果 confidence 本身不准，始终加权可能偏置模型。建议做一个单独消融：

- AllWeighted
- ConservativeOnly
- CurrentSwitch

若三者差异很小，选 AllWeighted，代码最干净。

### 6.4 第四优先级：简化 explore 选择

`select_explore` 当前包含：

- 关系得分；
- 不确定性；
- 分位数筛选；
- `n_min/n_max`；
- 贪心多样性；
- `0.75/0.25` 权重。

建议改为两步：

1. 算 acquisition：

```matlab
score_aug = score_n + (1 - ratio) * model_gain .* unc_n;
```

2. 直接选 `n_eval` 个候选：

```matlab
pool = topK(score_aug, max(5*n_eval, n_eval));
Next = maxMinDiversity(pool, n_eval);
```

这样删除：

- `q_keep`
- `lambda0`
- `n_min`
- `n_max`
- `0.45`

多样性部分可以保留，但不要再暴露权重。若想更简洁，直接 top `n_eval` 也可以作为消融版本。

### 6.5 第五优先级：删除 `RuntimeDiagnostics.degeneracy`

在 `Lite` 版本中，`degeneracy` 只用于 debug 输出，不再控制 indicator 触发。计算它需要 SVD。

建议删除：

- `diagnostics.degeneracy`
- `RuntimeDiagnostics` 中的 SVD、`rank90` 计算
- debug 中的 deg 输出

保留 `coverage` 即可，因为它仍能解释 explore 强度和 batch size。

### 6.6 第六优先级：重构 Hybrid PBI，而不是马上删除

`HybridPBI_Classification` 是当前算法的核心，不建议第一轮删除。但它确实臃肿，主要问题是：

- 一套全局参考向量 PBI；
- 一套动态参考解 PBI；
- 两套 PBI 公式不完全一致；
- `GetOutput_PBI` 用二分搜索强行把好解比例压到 `[0.3,0.7]`；
- `label_dyn` 是 0/1 硬标签，会压过连续 `score_v`；
- 最后又取 top `N/4` 为好类，中间解全部并入坏类。

建议下一步不是删掉 Hybrid PBI，而是改成“连续双信号评分”：

```matlab
score_global = 1 ./ (1 + normalized_PBI_global);
score_local  = 1 ./ (1 + normalized_PBI_local);
alpha = 1 - ratio;
score_hybrid = alpha * score_global + (1-alpha) * score_local;
confidence = 1 - abs(score_global - score_local);
```

然后按 `score_hybrid` 取 top 与 bottom 构造关系对。这样可以删除 `GetOutput_PBI` 里的 `delt` 二分搜索，同时保留全局/局部融合思想。

### 6.7 第七优先级：K-means 自适应参考向量

`AdaptiveReferenceVectors` 用 K-means 聚类非支配解生成参考向量，这个设计有一定创新性，但也带来：

- 随机性；
- 计算开销；
- `MaxIter=100, Replicates=5`；
- 当种群已退化时可能产生正反馈。

建议不是马上删除，而是做一个消融：

- UniformOnly：始终 `UniformPoint`
- AdaptiveKMeans：当前版本

如果 UniformOnly 性能不掉，删掉 K-means，算法会清爽很多。若 AdaptiveKMeans 明显有贡献，则保留，但固定随机种子，并在论文中明确它不是待调参数。

## 7. 推荐最终版本：AdaMaO-S

建议最终论文版本命名为：

`REMO_new2_AdaMaO_Simple` 或 `REMO_new2_AdaMaO_S`

保留模块：

- Hybrid PBI 分类，但优先改成连续双信号评分；
- 关系对学习；
- 置信度软加权；
- 关系模型候选筛选；
- coverage-aware exploration；
- `RefSelect` 环境选择。

删除模块：

- 全部 indicator 子系统；
- curriculum 模式；
- relation mode 硬切换；
- candidate mode 硬切换；
- `degeneracy` 诊断；
- 重复的 ablation algorithm class；
- 重复的数据处理函数。

外部参数建议变成：

```matlab
[debug] = Algorithm.ParameterSet(0);
```

如果 PlatEMO 风格要求保留多个参数位置，也建议只保留：

```matlab
[screenBudgetFactor,debug] = Algorithm.ParameterSet([],0);
```

其中 `screenBudgetFactor=[]` 表示自动。

## 8. 建议消融顺序

为了稳，不建议一次全删。推荐按下面顺序做：

1. `Lite` 作为 baseline。
2. `Lite-NoDeg`：删 `degeneracy` 计算。预期无性能变化。
3. `Lite-NoCurriculum`：删 curriculum，保留 conservative/weighted。观察是否影响。
4. `Lite-AllWeighted`：始终使用软置信权重。若不掉性能，删除 relation mode。
5. `Lite-AutoEval`：删除 `n_min/n_max`，改 coverage-aware batch size。
6. `Lite-AutoAcq`：删除 `q_keep/lambda0/tau_err`，改 `model_gain` acquisition。
7. `Lite-ContinuousHPC`：删除 `GetOutput_PBI` 二分标签，改连续 local PBI。
8. `Lite-UniformRef`：测试是否能删除 K-means adaptive reference vectors。

每一步只改一个主要机制，便于写论文消融表。

## 9. 可写进论文的方法贡献

删完后，论文贡献可以更集中：

1. 提出一种 hybrid PBI relation labeling，将高维目标空间中的候选解转化为偏好关系样本。
2. 提出 confidence-weighted relation learning，用双信号一致性抑制噪声标签。
3. 提出 validation-aware surrogate screening，用模型相对误差自适应控制探索强度。
4. 提出 coverage-aware evaluation allocation，在参考方向覆盖不足时自动增加真实评估批量。

这四点比“又加 PIEA 指标、又加 SVR、又加 SDR 反馈”更像一个干净的原创框架。

## 10. 最终建议摘要

最优先做：

- 用 `Lite` 作为主算法；
- 删除完整 indicator 子系统；
- 删除 `use_indicator`、`IndicatorModel`、`select_indicator`；
- 删除 `degeneracy` 诊断；
- 把 `k/gmax/n_min/n_max` 改成由问题规模和覆盖率决定。

第二阶段做：

- 删除 curriculum；
- 合并 weighted/conservative；
- 用 `model_gain` 替代 `tau_err/lambda0/0.45`；
- 删除 `q_keep`。

第三阶段做：

- 连续化 Hybrid PBI，替换 `GetOutput_PBI` 的二分硬标签；
- 测试是否可以删除 K-means adaptive reference vectors。

如果这些都完成，算法从“10 个外部参数 + 多个隐藏阈值 + PIEA 子系统”会变成“基本无外部调参、机制自洽、可解释性强”的版本，论文叙事会干净很多。
