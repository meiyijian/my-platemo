# REMO_DiRel — Difficulty-Aware Dual-Scale Relation Learning

针对昂贵超多目标优化（5 ≤ M ≤ 20）的关系学习代理算法。基于 REMO baseline 的双尺度扩展。

## 算法定位（一句话）

以 **GP-NRMSE + Spearman 冲突度** 联合度量在线排序目标，构造 **"全目标 + 易子集"双关系网络**（共享 backbone + 迁移微调），通过 **逐候选解的逆方差贝叶斯仲裁** 融合两模型预测。

## 三个超参数（仅有）

| 名称 | 默认 | 含义 |
|---|---|---|
| `k_easy` | `-1` (= ⌈M/2⌉) | 易目标子集大小，`-1` 表示自动取 ⌈M/2⌉，∈ [2, M-1] |
| `tau_conf` | `0.3` | 仲裁器判定"高/低置信"的归一化方差阈值 |
| `alpha` | `0.6` | 难度公式中 NRMSE 项的权重，(1-alpha) 给冲突度项 |

其它参数（k=6, gmax=3000, K_ens=5, win_K=3）沿用 REMO/SRMaO 同款默认值，不建议改动。

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
  1. **GP K-fold NRMSE**（`KrigingNRMSE.m`）—— 可建模度，跨目标可比，与归一化无关
  2. **Spearman 冲突度**（`ConflictDegree.m`）—— 与其它目标的平均 (1 - |ρ|)
- 联合难度：`d_j = α·NRMSE_n + (1-α)·(1 - Conf_n)`，min-max 归一化后 K=3 代滑动平均
- 反向冗余检查（`RefineEasySubset.m`）：若候选子集内任意两目标 |ρ| > 0.95，剔除 NRMSE 大者补入次易目标

### 模块 ② `TrainDualScaleNet.m`
- patternnet 拓扑：`Input(2D) → FC(1.5D) → FC(D) → FC(0.5D) → softmax(3)`
- 训练流程：
  1. 全目标支线训 5 个 bagging patternnet（70% 采样）→ `nets_F`
  2. 子目标支线训 5 个 bagging patternnet，**每个 bag 用 `nets_F` 对应 bag 的权重做迁移初始化**（`TransferFineTune.m`）→ `nets_S`
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

## 跨目录依赖

REMO_DiRel 直接调用以下 PlatEMO 内已有文件（无需复制）：

| 文件 | 用途 |
|---|---|
| `REMO/RefSelect.m` | 参考解选择（雷达网格） |
| `REMO/GetOutput_PBI.m` | PBI 自适应分类 |
| `REMO/GetRelationPairs.m` | 关系对构造 + 类别平衡 |
| `REMO/DataProcess.m` | 训练/测试集划分 |
| `REMO/onehotconv.m` | one-hot 编码转换 |
| `K-RVEA/dacefit.m` + `predictor.m` | Kriging 拟合（用于 NRMSE） |

PlatEMO 启动时 `addpath(genpath(cd))` 已把所有目录加入 path，跨目录调用直接可用。

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
| GP NRMSE 抛出"theta out of bounds" | DACE 数值不稳定 | KrigingNRMSE 内已 try/catch，跳过该 fold 不报错 |
| patternnet train 失败 | 样本太少或类别不平衡 | trainBagEnsemble 内已兜底（用 patternnet 默认参数重训一次） |
| `Population.objs(:, S_easy)` 报错 | PlatEMO SOLUTION 类的方法调用解析问题 | 已在主算法中先存 `PopObj = Population.objs` 再切片 |
| 子目标 PBI 失效（Catalog_S 全 true 或全 false） | Ref_S_obj 未在子目标空间内 | 主算法已用 PopObj_sub 范围缩放参考向量 |
