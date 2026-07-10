# REMO_new2_AdaMaO_Simple 变更说明

> 本算法基于完整版 `REMO_new2_AdaMaO`（含 PIEA 指标子系统）生成，**不动原版本任何文件**。
> 目标：在保持核心框架不变的前提下，**大幅削减可调超参数**，使论文主线更干净、无需做大量超参数敏感性分析。
> 削减依据：`AdaMaO_简化与超参数削减建议.md`（同一目录下）。

---

## 1. 最终暴露的参数（从 10 个 → 2 个）

```matlab
[use_indicator, debug] = Algorithm.ParameterSet(1, 0);
```

| 参数 | 默认 | 说明 |
|---|---|---|
| `use_indicator` | 1 | 是否启用 PIEA 指标辅助选择（保留开关，便于以后做开/关消融） |
| `debug` | 0 | 是否打印调试信息 |

完整版原 10 个位置 `[k, gmax, q_keep, lambda0, w_min, n_min, n_max, tau_err, use_indicator, debug]` 中，前 8 个已全部**内生化**（见第 2、3 节）。

---

## 2. 8 个外部超参的内生化（对应文档第 4 章）

| 原参数 | 原作用 | 新做法（自动决定，不再暴露） |
|---|---|---|
| `k` | 参考解数量基数 | `k_eff = min(N, ceil(1.5*M))` —— 随目标维度线性增长 |
| `gmax` | 代理 GA 候选预算 | `wmax = N * ceil(log2(N+1))` —— 随种群规模增长（N=100 约 700） |
| `q_keep` | 探索分位数筛选 | 删除分位数筛选，直接由多样性选择取 `n_eval` 个 |
| `lambda0` | 不确定性基础权重 | 改为 `model_gain`（多数类基线相对增益）连续控制 |
| `w_min` | 样本权重下限 | 删除；权重由 `GetRelationPairs_confidence` 输出为 `0.5+0.5*sqrt(conf_i*conf_j) ∈ [0.5,1]` |
| `n_min` / `n_max` | 每代真实评估数 | `n_eval = max(1,ceil(N/25)) + ceil((1-coverage)*N/50)` —— 覆盖差时多评、覆盖好时少评 |
| `tau_err` | 模型误差硬阈值 | 改为 `model_reliable = (model_gain > 0)`，即模型优于多数类基线才信任 |

---

## 3. 第五章前四个隐藏参数的改动（按用户指定，只改前四个）

### 3.1 关系模式切换 `mean_conf >= 0.55` → 始终软置信权重

**原（完整版）**：在 `curriculum` / `weighted` / `conservative` 三模式间硬切换。
```matlab
relation_mode = 'conservative';
if prev_p_err > tau_err
    relation_mode = 'curriculum';
elseif prev_p_err <= tau_err && mean_conf >= 0.55 && diagnostics.coverage < 0.60
    relation_mode = 'weighted';
end
switch relation_mode
    case 'weighted'  [XXs,YYs,WWs] = GetRelationPairs_confidence(...);
    case 'curriculum'[XXs,YYs] = GetRelationPairs_curriculum(...); WWs=[];
    otherwise        [XXs,YYs] = GetRelationPairs(...); WWs=[];
end
```

**新（Simple）**：删除模式切换，关系对训练**始终使用软置信权重**。
```matlab
[XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);
if isempty(XXs)            % 仅防御性回退
    [XXs,YYs] = GetRelationPairs(Input,Catalog); WWs = [];
end
```
> 同时删除原 `GetRelationPairs_curriculum` / `KeepMostConfident` 两个无用局部函数。

### 3.2 关系/候选模式切换 `coverage < 0.60` → `coverage_gap = 1 - coverage` 连续控制

**原**：硬阈值 `coverage < 0.60` 触发 explore；`coverage < 0.60` 也参与 weighted 触发。
**新**：不再有硬阈值。`coverage_gap` 在 `select_explore` 中作为探索强度的连续乘子：
```matlab
lambda_t = (1 - ratio) * model_gain * coverage_gap .* unc_n;   % coverage_gap = 1 - coverage
```
覆盖率越低 → `coverage_gap` 越大 → 探索加成越强；覆盖已满 → 加成趋零（自动退化为保守）。

### 3.3 explore 权重 `p_err / 0.45` → 多数类基线误差

**原**：
```matlab
lambda_t = lambda0 * (1 - ratio) * max(0, 1 - p_err/0.45);
```
**新**（在 `TrainRelationModel` 中计算 `model_gain`，替代 `tau_err / 0.45`）：
```matlab
counts  = histcounts(TestOut, [-1.5,-0.5,0.5,1.5]);  % 统计 -1/0/+1 三类
p_base  = 1 - max(counts)/sum(counts);               % 多数类基线错误率
model_gain = max(0, (p_base - p_err) / max(p_base, eps));
```
含义：模型仅比"总是猜多数类"更好时 `model_gain > 0`（才探索）；否则为 0（不信任）。

### 3.4 diversity acquisition `0.75 / 0.25` → 保留为固定内部准则（按用户选择）

用户决定**保留** `0.75*得分 + 0.25*距离` 的贪心多样性准则，仅去掉它对 `n_min/n_max` 的依赖：
```matlab
acq = 0.75 .* norm01(score_aug(remain)) + 0.25 .* div_n;   % 内部固定，不暴露为超参
```
> 备选方案（未采用）：先按分数取池 `max(5*n_eval, n_eval)` 再纯 max-min 多样性。

---

## 4. 明确保留、未改动的部分（按用户决定）

- **指标子系统**：`use_indicator` 默认开启；PIEA 轮盘选择、`fitrsvm` 指标模型、`IndicatorSelector` / `UpdateInformation` / `NDSort_SDR` 反馈全部保留。
- **指标触发阈值** `degeneracy >= 0.45`：**原样保留**（不在第五章前四削减范围内）。
- **其余四个隐藏常数**（第五章后四行，未要求改）：`HybridPBI` 的 `theta=5`、`GetOutput_PBI` 的 `[-20,20]` 与 `[0.3,0.7]`、`N/4` 好解划分、K-means `MaxIter=100, Replicates=5` —— 均不动。
- **种群规模 `N`**：沿用完整版写法（`D<=10` 用 `11D-1`，否则 `100`），与已跑的 M=10/M=20 实验保持一致，便于公平对比。

---

## 5. 与完整版的语义差异速查

| 机制 | 完整版 | Simple |
|---|---|---|
| 关系对训练 | curriculum/weighted/conservative 三模式切换 | **始终软置信权重** |
| 样本权重 | `max(EW, w_min=0.30)` | `0.5+0.5*sqrt(conf_i*conf_j)` ∈ [0.5,1] |
| 探索触发 | `p_err<=tau_err && coverage<0.60` | `model_gain>0`（连续，无硬阈值） |
| 探索强度 | `lambda0*(1-ratio)*max(0,1-p_err/0.45)` | `(1-ratio)*model_gain*coverage_gap` |
| 每代评估数 | `n_min..n_max`（4~6） | `n_base+n_extra`（覆盖感知） |
| 候选 GA 预算 | `gmax=3000` | `N*ceil(log2(N+1))` |
| 参考解数 | `min(N,max(k,1.5M))` | `min(N,1.5M)` |
| 暴露参数 | 10 个 | **2 个** `[use_indicator, debug]` |

---

## 6. 运行与对比建议

- 在 PlatEMO 中直接选择 `REMO_new2_AdaMaO_Simple` 即可运行；默认 `use_indicator=1` 等价于完整版的指标开启状态。
- 与完整版对比时，建议把 M=10 / M=20 两组实验重跑一遍 Simple，确认"削减超参后性能不退化"（这本身就是论文里一个干净的贡献点：*参数内生化的自适应关系学习框架*）。
- 可顺带做一组 `use_indicator=0` 的消融，验证在 Simple 框架下指标子系统仍如之前结论那样可被移除而不显著掉点。
