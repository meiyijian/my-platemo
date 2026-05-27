# REMO_DiRel_DualNetProbe 实验 CSV 指标说明文档

本文档说明 [output/](.) 目录下 4 个 CSV 文件中每个字段的含义、计算来源和典型取值范围。所有字段的定义都来自 [compute_dualnet_metrics.m](../compute_dualnet_metrics.m) 与 [analyze_dualnet_results.m](../analyze_dualnet_results.m)。

## 背景：实验概念速览

- **双网络（Dual Network）**:
  - **F 网络（Full-objective net）**: 学习全部 M 个目标的 Pareto 支配关系打分器。
  - **S 网络（Sub-objective net）**: 只学习易子目标集合 `S_easy`（自动挑选的若干个目标）上的支配关系打分器。
- **打分含义**: 对每个候选解 x，每个网络输出 `mu`（点估计，>0 倾向于"x 更优"，<0 倾向于"x 更差"）和 `sigma2`（集成方差，反映不确定性）。
- **冲突标签**:
  - `agree`: F、S 同号（一致预测）
  - `conflict`: F、S 异号但未触发弃权或子目标主导
  - `abstain`: 异号且双方都很不确定（`n_F > τ` 且 `n_S > τ`），融合分置零
  - `subwin`: 异号、S 看好且 F 不确定（S 主导）
- **真实质量 `true_quality`**: 旁路调用 `Problem.CalObj` 获取真实目标值后，与当前种群做 Pareto 支配判定。-1=被种群支配，+1=支配某成员或互不支配。这是评估两网络对错的"金标准"。
- **NN baseline**: 用决策空间最近邻代替真实评估的对比基线（量化 NN 假冒 ground truth 的误差）。

---

## 1. per_generation_summary.csv —— 逐代汇总统计

每一行对应一次 run 的某一代。来源：[analyze_dualnet_results.m:112-115](../analyze_dualnet_results.m#L112-L115)。

| 字段 | 含义 | 取值/单位 |
|---|---|---|
| `problem` | 测试问题名（DTLZ2 / DTLZ3） | 字符串 |
| `M` | 目标数（5 / 10 / 15） | 整数 |
| `run` | 独立运行编号（1–10） | 整数 |
| `gen` | 当前代数（generation） | 整数，从 1 开始 |
| `FE` | 当前累计真实评估次数（Function Evaluations） | 整数 |
| `N` | 种群规模 | 整数（通常 100） |
| `M_total` | 总目标数（= M，冗余字段，便于核对） | 整数 |
| `p_err_F` | F 网络在训练/验证集上的支配关系判错率 | [0,1]，越小越好 |
| `p_err_S` | S 网络在训练/验证集上的支配关系判错率 | [0,1]，越小越好 |
| `k_easy` | 当前识别为"易子目标"的目标数 \|S_easy\| | 整数 |
| `S_easy` | 易子目标索引集合（字符串形式存储） | 如 `[9 8 1 5 2]` |

> 用法：观察 `p_err_F`/`p_err_S` 随 `gen` 的变化曲线，判断哪个网络学得更稳；用 `S_easy` 列追踪易子目标随代数是否漂移。

---

## 2. per_candidate_detail.csv —— 逐候选详细数据

每一行对应一个候选解在某一代被双网络评分的完整记录。来源：[analyze_dualnet_results.m:121-130](../analyze_dualnet_results.m#L121-L130)。

| 字段 | 含义 | 取值/解释 |
|---|---|---|
| `problem`, `M`, `run`, `gen` | 同上，定位用 | — |
| `cand_idx` | 该代内候选索引（1..nCand） | 整数 |
| `mu_F` | F 网络对该候选的预测均值（集成平均） | 实数，>0 表示"更优" |
| `sigma2_F` | F 网络集成方差（不确定性） | ≥0，越大越不确定 |
| `tildeS_F` | F 网络得分的 min-max 归一化×4，用于融合 | [0,4] |
| `mu_S` | S 网络预测均值 | 实数 |
| `sigma2_S` | S 网络集成方差 | ≥0 |
| `tildeS_S` | S 网络归一化得分 | [0,4] |
| `w_F` | 逆方差融合权重 `1/σ_F²÷(1/σ_F²+1/σ_S²)` | [0,1]，`w_S = 1 - w_F` |
| `base_score` | 融合得分 `w_F·tildeS_F + w_S·tildeS_S`，弃权时置 0 | [0,4] |
| `sign_F` | `sign(mu_F)` | {-1, 0, 1} |
| `sign_S` | `sign(mu_S)` | {-1, 0, 1} |
| `true_quality` | 真实 Pareto 判定结果（与种群比较，基于 `Problem.CalObj` 旁路评估） | -1（被支配）/ +1（不被支配） |
| `dominated_by_pop` | 该候选是否被种群至少一个解严格支配 | 0/1 |
| `dominates_pop` | 该候选是否严格支配种群至少一个解 | 0/1 |
| `catalog_F` | 在全 M 目标空间下的 PBI 分类标签 | 0/1（1=保留，0=剔除） |
| `catalog_S` | 在 `S_easy` 子目标空间下的 PBI 分类标签 | 0/1 |
| `conflict_type` | 冲突类型 | `agree` / `conflict` / `abstain` / `subwin` |
| `true_quality_nn` | 用 NN baseline（决策空间最近邻代替真实评估）算出的真实质量 | -1/+1，与 `true_quality` 比较即可量化 NN 偏差 |
| `has_real_obj` | 是否成功用 `Problem.CalObj` 旁路评估（否则回退到 NN） | 0/1 |

> 用法：这是最原始、最细的表，可用于做散点图（`mu_F` vs `mu_S`）、回归分析（`w_F` vs `true_quality`）、按 `conflict_type` 切片比较准确率等。

---

## 3. cross_problem_summary.csv —— 跨问题汇总对比

每一行对应一个 `(problem, M)` 组合，把所有 run × gen × 候选 聚合成单一行。来源：[analyze_dualnet_results.m:199-337](../analyze_dualnet_results.m#L199-L337)。

| 字段 | 含义 |
|---|---|
| `problem`, `M` | 问题与目标数 |
| `n_runs` | 独立运行数（10） |
| `n_generations` | 该组合下出现过的不同代数总数 |
| `n_candidates` | 候选总条数（所有 run × gen × nCand 累加） |
| `agree_sign_mean` / `agree_sign_std` | 两网络符号一致的比例的均值/方差（`mean(sign(mu_F)==sign(mu_S))`） |
| `conflict_rate_mean` / `_std` | 异号比例（`agree` 之外的合计：`conflict+abstain+subwin`），= 1 - `agree_sign_mean` |
| `abstain_rate_mean` / `_std` | 标记为 `abstain` 的比例 |
| `subwin_rate_mean` / `_std` | 标记为 `subwin`（S 主导）的比例 |
| `w_F_mean` / `w_F_std` | 融合权重 `w_F` 的均值和方差，反映 F 网络的"话语权" |
| `acc_F_mean` / `acc_F_std` | F 网络 sign 与 `true_quality` 匹配的平均准确率（std 在脚本里强制写 0，因为是按全样本聚合而非按 run） |
| `acc_S_mean` / `acc_S_std` | S 网络平均准确率（同上） |
| `acc_F_conflict_mean` / `acc_S_conflict_mean` | **仅在 `conflict_type ≠ agree` 子集**上各自的准确率，反映冲突时谁更可信 |
| `p_err_F_mean` / `p_err_S_mean` | 训练侧 `p_err`（来自 per_generation_summary）按问题平均 |
| `sel_overlap_FS_mean` | 两网络都选中（`tildeS_F > 3.9 且 tildeS_S > 3.9`）的比例 |
| `sel_only_F_mean` | 仅 F 选中的比例 |
| `sel_only_S_mean` | 仅 S 选中的比例 |
| `acc_F_nn_mean` / `acc_S_nn_mean` | 用 NN baseline 代替真值时算出的准确率 |
| `label_agree_real_nn_mean` | NN baseline 标签与真实标签的一致率，越接近 1 说明 NN 越能"假冒"真值 |
| `has_real_obj_pct` | 实际成功用真实 CalObj 评估的样本占比（应该是 100%） |

> 阈值 3.9：候选融合得分超过该值被视为"被网络选中"（脚本里硬编码，见 [analyze_dualnet_results.m:298](../analyze_dualnet_results.m#L298)）。

> 用法：直接看哪个问题/M 组合下 conflict_rate 最高、acc_F 与 acc_S 差距最大，定位双网络价值最大的场景。

---

## 4. conflict_analysis.csv —— 按冲突类型细分

每个 `(problem, M)` 组合各产生 4 行，分别统计 `agree/conflict/abstain/subwin` 四种类型下的指标。来源：[analyze_dualnet_results.m:340-423](../analyze_dualnet_results.m#L340-L423)。

| 字段 | 含义 |
|---|---|
| `problem`, `M` | 问题与目标数 |
| `conflict_type` | 子集类型：`agree`/`conflict`/`abstain`/`subwin` |
| `count` | 该子集的样本数 |
| `pct` | 该子集在该 `(problem, M)` 下的占比（百分比） |
| `mean_w_F` | 该子集下 `w_F` 的均值 |
| `mean_mu_F` | 该子集下 `mu_F` 的均值 |
| `mean_mu_S` | 该子集下 `mu_S` 的均值 |
| `acc_F` | 该子集下 F 网络的准确率（`sign(mu_F)==true_quality`） |
| `acc_S` | 该子集下 S 网络的准确率 |
| `acc_winner` | `F`/`S`/`tie`，准确率更高的一方 |
| `mean_true_quality` | 该子集真实质量均值，越接近 +1 表示候选越优 |
| `pct_dominated` | 该子集中被种群支配的候选百分比 |

> 用法：检验 arbitrator 的"冲突路由"是否真的把决策权交对了人。例如 `subwin` 行如果 `acc_winner = S` 且 `acc_S` 显著高于 `acc_F`，说明 S 主导逻辑有效。

---

## 关键阈值与常数（容易忽视）

| 名称 | 值 | 出处 | 作用 |
|---|---|---|---|
| `tau_conf` | `Smodel.tau_conf` | [compute_dualnet_metrics.m:74](../compute_dualnet_metrics.m#L74) | 不确定度阈值，决定 abstain/subwin 触发 |
| `threshold` | 3.9 | [compute_dualnet_metrics.m:214](../compute_dualnet_metrics.m#L214), [analyze_dualnet_results.m:298](../analyze_dualnet_results.m#L298) | 融合分超过此值才算"被选中" |
| `eps_v` | 1e-6 | [compute_dualnet_metrics.m:66](../compute_dualnet_metrics.m#L66) | 逆方差融合的数值稳定项 |
| `k` (Ref) | `min(6, N)` | [compute_dualnet_metrics.m:117](../compute_dualnet_metrics.m#L117) | PBI 分类的参考解数 |

---

## 常见分析配方

1. **判断 F、S 谁更准**：看 `cross_problem_summary.csv` 的 `acc_F_mean` vs `acc_S_mean`；冲突时对比 `acc_F_conflict_mean` vs `acc_S_conflict_mean`。
2. **arbitrator 有没有用**：看 `conflict_analysis.csv` 中 `subwin` 行的 `acc_winner` 是否为 `S` 且 `acc_S - acc_F` 明显为正——若是则说明 S 主导分流正确；同样地 `conflict` 行 `acc_winner = F` 也是预期。
3. **NN baseline 误差有多大**：用 `1 - label_agree_real_nn_mean`，越大说明 NN 假冒 ground truth 越失真，越说明此实验必须做真实评估旁路。
4. **诊断单代异常**：从 `per_generation_summary.csv` 拉曲线 `p_err_S` vs `gen`，找跳变点；再到 `per_candidate_detail.csv` 锁定同 `(run, gen)` 的候选明细。
