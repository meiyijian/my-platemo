# REMO_new2_WFG10 超参数削减建议

> 分析对象：`REMO_new2_WFG10` 目录。重点阅读 `REMO_new2_WFG10.m`、`RSurrogateAssistedSelection.m`、`HybridPBI_Classification.m`、`GetOutput_PBI.m`、`GetRelationPairs_confidence.m`、`DataProcess_confidence.m`、`RefSelect.m` 以及已有算法详解文档。  
> 目标：在保留该算法当前简洁性和性能优势的前提下，尽量减少外部超参数，并指出哪些内部常数应避免在论文中作为待调参数出现。

## 1. 总体判断

`REMO_new2_WFG10` 比 `REMO_new2_AdaMaO` 干净很多。它没有 PIEA indicator 分支，没有多模式切换，也没有额外的 runtime diagnostics。当前核心链条是：

```text
Hybrid PBI 分类 -> 置信度加权关系对 -> 加权关系模型 -> 不确定性/多样性候选选择 -> 真实评估 -> RefSelect 环境选择
```

这个算法的臃肿点不在模块数量，而在候选选择器里额外暴露了 5 个新增参数：

```matlab
[k,gmax,q_keep,lambda0,w_min,n_min,n_max] = ...
    Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6);
```

其中 `q_keep/lambda0/w_min/n_min/n_max` 是 WFG10 版本相对原 REMO_new2 新增的主要超参数。它们确实提升了候选筛选的稳定性，但如果写论文，需要解释和分析的成本偏高。

建议目标：把外部性能参数从 7 个压缩到 0 到 1 个。  
最理想版本不暴露任何需要调参的参数；如果保留一个，也只保留“候选筛选预算系数”，而不是影响算法逻辑的阈值。

## 2. 当前外部参数与削减建议

| 参数 | 当前默认值 | 作用 | 削减建议 | 优先级 |
|---|---:|---|---|---|
| `k` | 6 | 参考解数量基数 | 删除，直接由目标数决定 | 高 |
| `gmax` | 3000 | 代理辅助 GA 的内部候选生成预算 | 建议内生化；若担心性能，最后再动 | 中 |
| `q_keep` | 0.80 | 分位数筛选阈值 | 删除，改成按 `n_eval` 直接选择 | 高 |
| `lambda0` | 0.35 | 不确定性奖励基础权重 | 删除，改成基于模型相对误差的权重 | 高 |
| `w_min` | 0.30 | 样本训练权重下限 | 删除，改成天然有下限的软权重 | 高 |
| `n_min` | 4 | 每代最少真实评估数 | 删除，改成参考解数量驱动 | 高 |
| `n_max` | 6 | 每代最多真实评估数 | 删除，改成参考解数量驱动 | 高 |

建议优先保留算法的主体设计，不建议像 AdaMaO 那样大规模拆模块。WFG10 版本的问题是“参数多于机制本身所需”，不是“模块严重堆叠”。

## 3. 参数削减优先级

### P1：删除 `k`

当前代码：

```matlab
k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));
```

在 WFG10 的典型 10 目标场景下：

```matlab
ceil(1.5*Problem.M) = 15
```

因此默认 `k=6` 实际只是在低目标数场景下起下限作用。既然该算法定位是 WFG10 / many-objective，建议直接写成：

```matlab
k_eff = min(Problem.N, ceil(1.5*Problem.M));
```

这样 `k` 可以完全删除。

原因：

- 该参数已经被 `1.5*M` 主导；
- 删除后不改变 WFG10/M=10 的默认行为；
- 论文里更容易解释：参考解数量随目标维度线性增长。

风险：低维问题上可能少几个参考解。  
风险很低，因为该算法本身就是 WFG10 many-objective 变体。

### P2：删除 `w_min`

当前加权训练流程是：

```matlab
EW = TrainW(:)';
EW = EW ./ mean(EW);
EW = max(EW,w_min);
```

`w_min=0.30` 是一个典型难解释参数。它的作用只是避免低置信关系对权重太小，导致训练不稳定。

建议把 `GetRelationPairs_confidence` 中的权重直接改成有天然下限的软权重：

```matlab
W_pair = 0.5 + 0.5 * sqrt(conf_i * conf_j);
```

或在训练前做：

```matlab
EW = 0.5 + 0.5 * norm01(EW);
```

这样权重天然落在 `[0.5,1]`，不再需要 `w_min`。

原因：

- `w_min` 不贡献新机制，只是数值保护；
- 软权重更容易解释：所有样本都保留，高置信关系更重要；
- 删除后不会改变“置信度加权关系学习”这个核心贡献。

优先级高，建议先做。

### P3：删除 `lambda0`

当前不确定性权重：

```matlab
lambda_t = Smodel.lambda0 * (1 - Smodel.ratio) * max(0,1 - p_err/0.45);
```

这里其实有两个需要解释的数：

- `lambda0=0.35`
- `0.45`

建议改成基于“模型是否优于基线”的自适应权重：

```matlab
p_base = 1 - max(class_count) / sum(class_count);
model_gain = max(0, (p_base - p_err) / max(p_base, eps));
lambda_t = (1 - ratio) * model_gain;
```

含义：

- 如果关系模型没有超过多数类基线，就不额外奖励不确定性；
- 如果模型明显优于基线，就允许它去探索高不确定区域；
- 随着 `ratio` 增大，探索自动减弱。

这样可以同时删除 `lambda0` 和隐藏阈值 `0.45`。

原因：

- `lambda0` 是真正会被审稿人追问的参数；
- 用 `model_gain` 后，探索强度来自当前训练质量，不是人为指定；
- 机制叙述更自然：validation-aware uncertainty exploration。

风险：需要在训练后保存 `p_base`，例如加入 `Smodel.p_base`。  
风险中低，建议做一次消融。

### P4：删除 `q_keep`

当前候选选择：

```matlab
threshold = quantile(score_aug,q_keep);
cand_idx  = find(score_aug >= threshold);
```

默认 `q_keep=0.80` 的含义是只保留增强得分最高的 20% 候选。这个参数会显得像手工调出来的筛选比例。

建议改成“固定候选池 + 多样性选择”，例如：

```matlab
n_eval = AutoEvalNum(Ref, remain);
pool_size = max(length(Ref), n_eval);
pool_idx = topK(score_aug, pool_size);
selected = maxMinDiversity(pool_idx, n_eval);
```

这样不再需要分位数阈值。候选池大小由参考解数量决定，而参考解数量又由 `M` 决定。

原因：

- `q_keep` 与 `n_min/n_max` 同时存在，逻辑重复；
- 最终真实评估数才是关键，分位数筛选只是中间步骤；
- 删除后候选选择逻辑更短。

风险：候选池太小可能降低多样性。  
建议先设 `pool_size = length(Ref)`，若性能下降，再考虑 `pool_size = max(length(Ref), 2*n_eval)`，但不要把倍数暴露成外部参数。

### P5：合并并删除 `n_min/n_max`

当前每代真实评估数限定在 `[4,6]`：

```matlab
n_eval = min(n_max,max(n_min,numel(cand_idx)));
```

这两个参数强烈依赖评估预算和种群规模。对 WFG10 当前设置可能合理，但论文中分析 `4` 和 `6` 会很麻烦。

建议用参考解数量自动决定：

```matlab
n_eval = min(remain, max(1, ceil(sqrt(length(Ref)))));
```

在 WFG10/M=10 时，`length(Ref)` 约为 15，则：

```matlab
ceil(sqrt(15)) = 4
```

接近当前 `n_min=4`。如果希望略接近 4 到 6 的当前范围，也可以用：

```matlab
n_eval = min(remain, max(1, ceil(length(Ref)/3)));
```

在 `length(Ref)=15` 时得到 5。  
我更推荐 `sqrt(length(Ref))`，因为它没有新的比例系数，参数感更弱。

原因：

- `n_min/n_max` 可以合并为一个自动 batch size；
- many-objective 下参考解数量本来就代表前沿覆盖需求；
- 真实评估数随目标数自适应，比固定 4/6 更好写。

风险：如果 `M` 很高，`sqrt(length(Ref))` 增长较慢；如果希望高维时多评估，可用 `ceil(length(Ref)/3)`，但论文要解释比例。

### P6：内生化 `gmax`

`gmax=3000` 控制代理辅助 GA 内部候选生成量，不直接消耗真实评估，但影响运行时间和候选质量。

这项建议优先级低于前面几个，因为它可能影响性能较明显。

可选方案：

方案 A：按种群规模和决策维度决定

```matlab
wmax = Problem.N * Problem.D;
```

优点：没有新的经验系数；WFG 常见 `N=100,D=30` 时接近当前 3000。  
缺点：如果 D 很大，内部计算会膨胀。

方案 B：按种群规模的对数预算决定

```matlab
wmax = Problem.N * ceil(log2(Problem.N + 1));
```

优点：计算更省；与种群规模相关。  
缺点：对当前 WFG10 可能比 3000 小很多，可能影响性能。

方案 C：保留为唯一外部预算参数

```matlab
[screenBudget,debug] = Algorithm.ParameterSet([],0);
```

如果 `screenBudget=[]`，则自动；如果用户给值，才覆盖。  
这是最稳妥的论文策略：不把它当算法敏感参数，只当计算预算。

建议：先用方案 A 做实验。如果性能不掉，就删除 `gmax`；如果性能下降明显，保留一个内部默认预算，不建议让它参与超参数敏感性分析。

## 4. 隐藏常数处理建议

除了外部 7 个参数，代码里还有一些隐藏常数。它们不一定都要删除，但论文中要避免把它们描述成可调超参数。

| 位置 | 当前常数 | 建议 |
|---|---:|---|
| `HybridPBI_Classification` | `theta=5` | 保留为经典 PBI 惩罚系数，作为固定内部设置 |
| `HybridPBI_Classification` | `N/4` 好类比例 | 可暂时保留；后续可改成 top/bottom 双端关系对，不把中间解并入坏类 |
| `GetOutput_PBI` | delta 搜索 `[-20,20]` | 暂时保留；若进一步简化，可改成连续 local PBI score |
| `GetOutput_PBI` | 好解比例 `[0.3,0.7]` | 不建议作为论文超参数，最好描述为防止标签极端失衡的内部保护 |
| `DataProcess_confidence` | 训练集比例 `3/4` | 保留为标准 holdout，不做敏感性分析 |
| `RSurrogateAssistedSelection` | `0.75/0.25` 多样性权重 | 可删除，改成 top pool 后纯 max-min diversity |
| `OperatorGA` | `{1,15,1,5}` | PlatEMO 常规 GA 算子参数，保留 |
| `AdaptiveReferenceVectors` | K-means `MaxIter=100, Replicates=5` | 保留为内部实现；若写可复现性，固定随机流 |

## 5. 最推荐的简化版本

建议最终版本外部参数写成：

```matlab
[] = Algorithm.ParameterSet();
```

如果 PlatEMO 需要保留调试或预算入口：

```matlab
[screenBudget,debug] = Algorithm.ParameterSet([],0);
```

内部规则建议如下：

```matlab
k_eff = min(Problem.N, ceil(1.5*Problem.M));

% 关系样本软权重
W_pair = 0.5 + 0.5 * sqrt(conf_i * conf_j);

% 模型可靠度
p_base = 1 - max(class_count) / sum(class_count);
model_gain = max(0, (p_base - p_err) / max(p_base, eps));
lambda_t = (1 - ratio) * model_gain;

% 真实评估数
n_eval = min(remain, max(1, ceil(sqrt(length(Ref)))));

% 候选池
pool_size = max(length(Ref), n_eval);
pool_idx = topK(score_aug, pool_size);
Next = maxMinDiversity(pool_idx, n_eval);
```

这样可以删除：

- `k`
- `q_keep`
- `lambda0`
- `w_min`
- `n_min`
- `n_max`

`gmax` 视实验决定是否完全删除。

## 6. 可删除或移出主目录的模块

当前主流程没有调用：

- `GetRelationPairs.m`
- `DataProcess.m`
- `Delequalsamples.m`

建议：

- 如果这些函数用于历史版本或消融实验，移动到 `archive` 或 `ablation` 子目录；
- 如果最终论文代码只保留 WFG10 主版本，可以从主算法目录删除；
- 不建议在论文主算法目录里同时放“无权重旧版”和“加权新版”，容易让审稿人觉得方法边界不清。

这一步不影响算法性能，但能减少工程噪声。

## 7. 消融实验优先级

为了稳，不建议一次性改完。推荐消融顺序：

1. `NoK`：删除 `k`，使用 `ceil(1.5*M)`。预期几乎无影响。
2. `SoftWeight`：删除 `w_min`，使用 `[0.5,1]` 软权重。预期影响很小。
3. `AutoLambda`：删除 `lambda0` 和 `0.45`，使用 `model_gain`。这是最重要的参数削减实验。
4. `AutoEval`：删除 `n_min/n_max`，使用 `sqrt(length(Ref))`。观察真实评估节奏是否稳定。
5. `NoQkeep`：删除 `q_keep`，改 top pool + max-min diversity。
6. `AutoGmax`：把 `gmax` 改成 `Problem.N*Problem.D` 或保留为内部预算。
7. `NoLegacyFiles`：移除未调用的旧版函数，只做代码清理，不做性能实验。

如果前 5 个都不掉性能，论文里的参数敏感性分析就会轻很多。

## 8. 建议论文叙事

可以把 WFG10 版本描述为一个“低参数化”的关系学习框架：

1. 参考解数量由目标维度决定，而不是手动指定；
2. 样本权重由双信号置信度自然产生；
3. 探索强度由模型相对验证误差自动控制；
4. 每代评估数由参考解规模自动决定；
5. 候选多样性通过 max-min 选择保证，不引入额外调参权重。

这样的叙述比“设置了 `q_keep=0.80`、`lambda0=0.35`、`w_min=0.30`、`n_min=4`、`n_max=6`”更有说服力。

## 9. 最终建议摘要

最高优先级：

- 删除 `k`；
- 删除 `w_min`；
- 删除 `lambda0`；
- 删除 `q_keep`；
- 合并 `n_min/n_max` 为自动 `n_eval`。

中等优先级：

- 将 `gmax` 内生化为内部筛选预算；
- 删除 `0.75/0.25` 多样性权重，改成 top pool 后纯 max-min diversity；
- 移出未调用的旧版函数。

低优先级：

- 连续化 `GetOutput_PBI`，减少 `[0.3,0.7]` 和 delta 搜索；
- 检查 K-means 自适应参考向量是否必要；
- 调整 `theta=5`，但不建议优先动它。

结论：`REMO_new2_WFG10` 的结构已经比较适合发文，不建议大拆。最值得做的是把候选选择器中的 5 个新增超参数转化为“模型误差、参考解数量、种群规模”驱动的内部规则。这样既保留现有性能来源，也能显著降低论文中超参数分析的负担。
