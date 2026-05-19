# REMO_DiRel 双网络一致性实验设计

日期：2026-05-19
作者：与用户共同设计
目标算法：[REMO_DiRel.m](PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/REMO_DiRel.m)

## 1. 实验动机

REMO_DiRel 在 [ArbitratorScore.m](PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/ArbitratorScore.m) 中用全目标网络 `nets_F` 和子目标网络 `nets_S` 对候选解打分，再用逆方差权重融合。我们怀疑这两个网络可能各自不够准、且彼此判定差异较大，最终拖累了候选解选择质量。

本实验回答：**对同一个种群，子目标网络和全目标网络在多大程度上认为同一个解属于同一类？** 一致性越低，融合策略的边际收益越小，越说明应该重新权衡两支网络的权重，甚至放弃其中一支。

## 2. 一致性的三层定义

算法内"网络是否一致"在不同抽象层有不同含义。我们同时测量三层：

| 层 | 比较对象 | 输入 | 计算 |
|---|---|---|---|
| **L1 PBI 标签层** | `Catalog_F` vs `Catalog_S`（训练标签） | 当前种群 N 个解 | `mean(Catalog_F == Catalog_S)`；伴随 2×2 混淆矩阵（+1 / 非+1） |
| **L2 网络打分层** | `mu_F` vs `mu_S`（ArbitratorScore 中两网络输出的集成均值） | 当前种群整体作为"候选输入" | `mean(sign(mu_F) == sign(mu_S))`；伴随 2×2 混淆矩阵 |
| **L3 关系对预测层** | nets_F 与 nets_S 对**同一对** (x_i, x_j) 的逐对预测 | 共享子集 `XX_shared`（决策对天然对齐） | `mean(yhat_F == yhat_S)`；伴随 3×3 混淆矩阵（+1/0/-1） |

L3 注意点：XX_F 和 XX_S 都是关系对 `[x_i, x_j]` 的决策变量拼接，对应同一对解。预测时必须用各自训练时保留的 `mp_struct_F` / `mp_struct_S` 做归一化，分别送入对应网络。

三层放在一起，能区分问题来源：
- L1 低 → PBI 标签本身在两种目标视角下就矛盾，标签质量问题
- L1 高但 L3 低 → 标签一致，是网络拟合误差导致的分歧
- L2 低 → 候选解排序口径差异大，融合策略边际收益小

## 3. 采集设计

### 3.1 探针位置

在 [REMO_DiRel.m](PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/REMO_DiRel.m) 的主循环里 `TrainDualScaleNet` 调用之后插入探针块。**只在指定代触发**，避免拖慢算法。

为不污染原算法，做一份独立副本 `REMO_DiRel_probed.m`，探针只嵌入副本中。原算法零改动。

### 3.2 采样代数

5 个采样点按 maxFE 进度比定义（不绑定具体代数，问题间可比）：

- 进度 ≈ 4%（首代必采）
- 进度 ≈ 20%
- 进度 ≈ 40%
- 进度 ≈ 60%
- 进度 ≈ 80%

每代用 `Problem.FE / Problem.maxFE` 判定是否落入触发窗口，落入则触发一次。

### 3.3 每次触发记录的字段

```
gen, FE
% L1
agree_L1            : 标量
confmat_L1          : 2x2
% L2
agree_L2            : 标量
confmat_L2          : 2x2
mu_F, mu_S          : N x 1
% L3
agree_L3            : 标量
confmat_L3          : 3x3
yhat_F, yhat_S      : nPairs x 1
% 散点图用
PopObj              : N x M
label_F, label_S    : N x 1   各自的 PBI 标签或 sign(mu) 标签
```

每个 (问题, run) 输出一个 `.mat` 文件，命名 `probe_<Problem>_M<M>_run<r>.mat`。

## 4. 实验规模

固定 `maxFE = 300`，统一所有问题。

| 问题 | M | D | run 数 | 采样代 | 总采样次数 |
|---|---|---|---|---|---|
| DTLZ2 | 3 | 10 | 10 | 5 | 50 |
| DTLZ2 | 5 | 10 | 10 | 5 | 50 |
| MaF1 | 5 | 10 | 10 | 5 | 50 |
| MaF3 | 8 | 10 | 10 | 5 | 50 |

共 40 次完整算法运行，200 个数据点/层。

## 5. 可视化（3 张图）

### 图 1：一致性 vs 代数（折线带误差带）
- 2×2 子图，每个子图对应一个问题
- 每个子图三条线（L1 / L2 / L3）
- 每条线在 5 个采样点处展示 10 次 run 的均值，阴影为 ±1 标准差
- 横轴：进度比（4% / 20% / 40% / 60% / 80%）

### 图 2：末代一致性箱线图
- 横轴：(问题 × 层) 的组合（共 4×3=12 组）
- 纵轴：末代（进度 80% 那一代）的一致率
- 每组 10 个点（10 次 run）
- 配合按层分组上色

### 图 3：目标空间散点图
- 选一个代表问题：DTLZ2 M=3（直接可视）和 MaF3 M=8（用平行坐标图）
- 各取 1 次 run 的末代采样
- 用 4 种标记区分：
  - F+S+：两网络都判 +1（正类）
  - F-S-：两网络都判非+1
  - F+S-：F 判 +1、S 判非+1
  - F-S+：F 判非+1、S 判 +1
- 标签用 L1 层的 PBI 标签（信息量更明确）

## 6. 文件结构

```
PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/
├── run_probe_experiment.m        % 入口脚本：循环 4 问题 × 10 run
├── REMO_DiRel_probed.m           % 加了探针的算法副本
├── compute_agreement.m           % 三层一致性计算与记录（探针调用此函数）
├── plot_line_over_gens.m         % 图 1
├── plot_boxplot.m                % 图 2
├── plot_objective_scatter.m      % 图 3
└── results/
    └── probe_<Problem>_M<M>_run<r>.mat
```

## 7. 关键实现细节

### 7.1 L1 — PBI 标签一致性

在探针块里已经有 `Catalog_F` 和 `Catalog_S`（已计算）。直接：

```matlab
agree_L1 = mean(Catalog_F(:) == Catalog_S(:));
confmat_L1 = confusionmat(Catalog_F==1, Catalog_S==1);
```

### 7.2 L2 — 网络打分一致性

把当前种群本身作为候选送入 ArbitratorScore 的内部评分函数 `scoreAllByEnsemble`，得到 `mu_F`、`mu_S`：

```matlab
% 复用 ArbitratorScore.m 内部逻辑（提取为可独立调用的函数）
[mu_F, ~] = scoreAllByEnsemble(Input, Catalog_F, DualNet.nets_F, DualNet.mp_struct_F, Input, anchorMax);
[mu_S, ~] = scoreAllByEnsemble(Input, Catalog_S, DualNet.nets_S, DualNet.mp_struct_S, Input, anchorMax);
agree_L2 = mean(sign(mu_F) == sign(mu_S));
```

由于 `scoreAllByEnsemble` 当前是 [ArbitratorScore.m](PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/ArbitratorScore.m) 的私有局部函数，需要在 probed 包内**复制一份**为公共函数（不动原文件）。

### 7.3 L3 — 关系对预测一致性

XX_F 和 XX_S 行数可能不同（GetRelationPairsBudgeted 内做了平衡截断）。为得到对齐的对，重新构造一份**公共关系对集合 XX_shared**：

```matlab
% 从全种群对中均匀取 nPairsProbe = min(2000, N*(N-1)/2) 个对
pairs_ij = nchoosek(1:N, 2);
sel = randperm(size(pairs_ij,1), min(2000, size(pairs_ij,1)));
pairs_ij = pairs_ij(sel, :);
XX_shared = [Input(pairs_ij(:,1),:), Input(pairs_ij(:,2),:)];

% 分别归一化、前向
yhat_F = ensemblePredict(DualNet.nets_F, mapminmax('apply', XX_shared', DualNet.mp_struct_F)');
yhat_S = ensemblePredict(DualNet.nets_S, mapminmax('apply', XX_shared', DualNet.mp_struct_S)');
agree_L3 = mean(yhat_F == yhat_S);
confmat_L3 = confusionmat(yhat_F, yhat_S, 'Order', [1 0 -1]);
```

同样，`ensemblePredict` 是 [TrainDualScaleNet.m](PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/TrainDualScaleNet.m) 的私有局部函数，复制一份到 probed 包。

### 7.4 触发判定

```matlab
checkpoints = [0.04, 0.20, 0.40, 0.60, 0.80];
progress = Problem.FE / Problem.maxFE;
hit = find(progress >= checkpoints & ~probeFired);
if ~isempty(hit)
    probeFired(hit) = true;
    compute_agreement(...);
end
```

`probeFired` 在算法启动时初始化为全 false。

## 8. 成功标准

实验完成时应得到：
- 40 个 `.mat` 结果文件
- 3 张可视化图（PNG + FIG）
- 一句话结论：基于 L1/L2/L3 末代均值，是否支持/否定"两网络分歧大"的假设

## 9. YAGNI 边界

明确**不做**的：
- 不在原 [REMO_DiRel.m](PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/REMO_DiRel.m) 上加任何开关
- 不做实时可视化
- 不做超参数（tau_conf、alpha 等）扫描
- 不做与 baseline 算法（如 KRVEA、CSEA）的对比，本实验只关心 DiRel 内部两支网络的一致性
- 不做 t-test 等显著性检验，箱线图直观即可
