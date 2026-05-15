# REMO_DiRel — Difficulty-Aware Dual-Scale Relation Learning

## Runtime update

This implementation has been refactored for stable runtime while keeping the DiRel idea intact:

- Difficulty ranking no longer runs Kriging cross-validation by default. It uses objective span, recent best-value improvement, and Spearman conflict.
- Relation-pair construction is capped by `GetRelationPairsBudgeted.m` (`pairMax = 6000`) with balanced `1/0/-1` labels.
- Defaults are now `gmax = 1000`, `K_ens = 3`, and `win_K = 3`.
- Candidate arbitration uses at most `30` anchors per class for each model.
- `KrigingNRMSE.m` is retained only for diagnostics or future experiments.
针对昂贵超多目标优化（5 ≤ M ≤ 20）的关系学习代理算法。基于 REMO baseline 的双尺度扩展。

## 算法定位（一句话）

以 **目标跨度/改进停滞 + Spearman 冲突度** 联合度量在线排序目标，构造 **"全目标 + 易子集"双关系网络**（共享 backbone + 迁移初始化），通过 **逐候选解的逆方差仲裁** 融合两模型预测。

## 三个超参数（仅有）

| 名称 | 默认 | 含义 |
|---|---|---|
| `k_easy` | `-1` (= ⌈M/2⌉) | 易目标子集大小，`-1` 表示自动取 ⌈M/2⌉，∈ [2, M-1] |
| `tau_conf` | `0.3` | 仲裁器判定"高/低置信"的归一化方差阈值 |
| `alpha` | `0.6` | 难度公式中轻量建模难度项的权重，(1-alpha) 给冲突度项 |

其它参数默认值为 k=6, gmax=1000, K_ens=3, win_K=3；可通过完整参数列表覆盖。

## 用法

### 单次运行

```matlab
% 基础调用
platemo('algorithm', @REMO_DiRel, 'problem', @DTLZ2, 'M', 10, 'D', 10, 'maxFE', 309)

% 自定义超参（按上表顺序）
platemo('algorithm', {@REMO_DiRel, -1, 0.3, 0.6}, 'problem', @DTLZ2, 'M', 10, 'D', 10, 'maxFE', 309)

% 跑指标
Algo = platemo('algorithm', @REMO_DiRel, 'problem', @DTLZ2, 'M', 10, 'D', 10, 'maxFE', 309, 'save', 0);
IGD  = Algo.metric('IGD');
HV   = Algo.metric('HV');
```

### 与 REMO 家族对比

| 算法 | 关键差异 |
|---|---|
| `REMO`（baseline） | 单一全目标模型 |
| `Subproblem_REMO` | 静态相邻分组、独立分类器堆 |
| `REMO_SRMaO` | bagging 集成方差做全局采集函数权重 |
| `REMO_new2_AdaMaO` | PIEA 指标轮盘 + 10+ 超参 + 4 魔数阈值 |
| **`REMO_DiRel`** | **动态难度排序 + 双尺度共享 backbone + 逐候选解逆方差仲裁** |

## 三个核心模块

### 模块 ① `DifficultyProfiler.m`
- 输入：种群、近 win_K 代历史、当前代号、α、k_easy
- 两个难度指标：
  1. **轻量建模难度** —— 由目标值跨度和连续代最好值改进停滞组成
  2. **Spearman 冲突度**（`ConflictDegree.m`）—— 与其它目标的平均 (1 - |ρ|)
- 联合难度：`d_j = α·ModelDifficulty_j + (1-α)·(1 - Conf_j)`，min-max 归一化后 K=3 代滑动平均
- 反向冗余检查（`RefineEasySubset.m`）：若候选子集内任意两目标 |ρ| > 0.95，剔除难度分更大者并补入次易目标

### 模块 ② `TrainDualScaleNet.m`
- patternnet 拓扑：`Input(2D) → budgeted hidden layers (max 24 nodes/layer) → softmax(3)`
- 训练流程：
  1. 全目标支线训 3 个 bagging patternnet（70% 采样，约 60 epochs）→ `nets_F`
  2. 子目标支线训 3 个 bagging patternnet，**每个 bag 用 `nets_F` 对应 bag 的权重做迁移初始化**（约 30 epochs）→ `nets_S`
- patternnet 不原生支持冻结层，故用"权重初始化迁移"替代严格的冻结-微调

### 模块 ③ `ArbitratedSelection.m` + `ArbitratorScore.m`
- 对每个候选 x：
  - `mu_F, σ_F²` ← `nets_F` 集成均值/方差
  - `mu_S, σ_S²` ← `nets_S` 集成均值/方差
  - **逐候选逆方差权重**：`w_F(x) = (1/σ_F²(x)) / (1/σ_F²(x) + 1/σ_S²(x))`
  - 基础得分：`s(x) = w_F(x)·s̃_F(x) + w_S(x)·s̃_S(x)`
- 冲突分支（在归一化 σ 上用 tau_conf=0.3 判定大/小）：
  - 一致同意 → 用基础得分
  - 完全打架且两边都不确定 → 弃权（得分 0）
  - 子目标主导冲突（mu_S>0, mu_F<0, σ_F>>σ_S）→ 加多样性奖励（鼓励发现稀缺空间）
- GA 内循环、阈值筛选（score>3.9 取 ≥4 个）与 REMO 保持一致

## 依赖与本地 helper

REMO_DiRel 直接调用以下 PlatEMO 内已有文件：

| 文件 | 用途 |
|---|---|
| `REMO/RefSelect.m` | 参考解选择（雷达网格） |
| `REMO/GetOutput_PBI.m` | PBI 自适应分类 |

以下逻辑已改成本目录本地版本，避免同名函数路径冲突并控制运行预算：

| 文件/逻辑 | 用途 |
|---|---|
| `GetRelationPairsBudgeted.m` | 有上限的平衡关系对构造 |
| `TrainDualScaleNet.m` 内部 helper | 训练/测试集划分和 one-hot 编码转换 |
| `KrigingNRMSE.m` | 仅保留为诊断或后续实验，不进入默认主路径 |

## 5 个消融变体

| 变体目录 | 改动 | 用途 |
|---|---|---|
| `REMO_DiRel_noDi/` | 难度排序 → 随机选目标 | 证明难度量化机制必要 |
| `REMO_DiRel_noSub/` | 删除 net_S，仲裁器退化为 net_F 单源 | 证明子目标建模必要 |
| `REMO_DiRel_noTrans/` | net_S 不做迁移初始化、独立训练 | 证明权重迁移有效 |
| `REMO_DiRel_AvgArb/` | 仲裁权重换成固定 0.5/0.5 | 证明逆方差权重 > 简单平均 |
| `REMO_DiRel_FullArb/` | 仲裁权重换成全局标量（SRMaO 风格） | 证明逐候选权重 > 全局权重 |

每个变体目录内自包含修改后的辅助函数（不污染主算法），可直接 `platemo('algorithm', @REMO_DiRel_<variant>, ...)` 运行。

## 实验配置建议

- **Benchmark**：DTLZ {1,2,3,4,7} ∪ WFG {1,4,6,9} ∪ MaF {1,7,13} = 12 函数
- **目标维度**：M ∈ {5, 10, 15, 20}
- **预算**：初始 11D-1（D ≤ 10）或 100（D > 10），总 maxFE = 11D-1 + 200
- **对比算法**：REMO、REMO_SRMaO、REMO_new2_AdaMaO、Subproblem_REMO、K-RVEA、CSEA
- **指标**：IGD+（主）、HV、runtime
- **统计检验**：Wilcoxon rank-sum test（α=0.05），30 次独立运行

## 性能与诊断字段

`DualNet.p_err_F` 和 `DualNet.p_err_S` 分别记录全/子目标模型在测试集上的分类错误率，可用于诊断"网络是否退化"。若某代 `p_err_S > 0.7`，提示该代易子集质量差（可能 PopObj 退化），可观察 `H.d_score` 历史定位原因。

## 故障排查

| 症状 | 可能原因 | 修复 |
|---|---|---|
| 需要复现旧版 GP 难度 | 默认主路径已不使用 Kriging | 可单独调用 `KrigingNRMSE.m` 做诊断或实验 |
| patternnet train 失败 | 样本太少或类别不平衡 | trainBagEnsemble 内已兜底（用 patternnet 默认参数重训一次） |
| `Population.objs(:, S_easy)` 报错 | PlatEMO SOLUTION 类的方法调用解析问题 | 已在主算法中先存 `PopObj = Population.objs` 再切片 |
| 子目标 PBI 失效（Catalog_S 全 true 或全 false） | Ref_S_obj 未在子目标空间内 | 主算法已用 PopObj_sub 范围缩放参考向量 |
