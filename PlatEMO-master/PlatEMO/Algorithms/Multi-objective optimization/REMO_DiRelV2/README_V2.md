# REMO_DiRelV2 —— Difficulty-aware Relation Modeling for Expensive Many-objective Optimization (V2)

## 1. 文件清单

| 文件 | 角色 | 对应原始诊断 |
|---|---|---|
| `REMO_DiRelV2.m` | PlatEMO 算法主类 | 主循环全部重构 |
| `BuildPairBank_ParetoPBI.m` | 真实 pairwise Pareto + PBI fallback 标签 | P0-1，取代 `GetRelationPairsBudgeted` 的 Catalog 诱导 |
| `BuildDifficultySubsets.m` | 难度感知多子集 (S1,S2,Sfull) | P0-2，取代 `RefineEasySubset` 的单 easy subset |
| `BuildSubsetReferenceVectors.m` | 为每个 subset 生成单位参考向量 | 配合新 PBI 标签 |
| `DifficultyProfilerV2.m` | 5 分量难度估计 + EMA 平滑 | P0-4，取代 `DifficultyProfiler` |
| `TrainRelationExperts.m` | 多 expert bank 训练 (hidden 标量 + K_ens=5) | P1-1，取代 `TrainDualScaleNet` |
| `SelectRelationAnchors.m` | individual-level anchors (elite + diverse) | P1-2，取代 `ArbitratorScore::selectAnchors` |
| `ScoreCandidates_DiRel.m` | reliability-calibrated acquisition (R + U + Nov - Disagree) | P0-3，取代 `ArbitratorScore` 的 [0,4] min-max + 3.9 阈值 |
| `SelectTopDiverse.m` | top-q + 最小决策距离约束 | 配合新 acquisition |
| `LogDiagnostics_DiRel.m` | 每代诊断累积 | P1-3 |
| `PlotDiagnostics_DiRel.m` | 难度/标签/可靠性/分解四类基础图 | P1-3 |
| `run_smoke_DiRelV2.m` | 与 REMO / REMO_DiRel 对比 smoke test | 实验 |
| `run_ablation_DiRelV2.m` | 6 种核心 ablation 模式（env var 驱动） | 实验 |
| `collect_results_DiRelV2.m` | 聚合 csv 输出 median 表 | 实验 |

## 2. 部署到 PlatEMO

1. 把整个 `REMO_DiRelV2/` 文件夹放到 PlatEMO 的算法目录（已在路径里）:
   `PlatEMO/Algorithms/Multi-objective optimization/REMO_DiRelV2/`
2. 旧版 `REMO_DiRel/` **保留不动**，作为 ablation baseline A1。
3. 在 MATLAB 启动后用 `addpath(genpath(...PlatEMO...))`，PlatEMO 会自动识别新算法。

## 3. 最小可运行 smoke test

```matlab
% 在 PlatEMO 根目录下
addpath(genpath(pwd));
cd('Algorithms/Multi-objective optimization/REMO_DiRelV2');

% 0. 先跑单元测试，确认所有模块没有维度 / 语法错误（不依赖 PlatEMO solve）
test_units_DiRelV2();

% 1. 单次运行 V2 看是否能跑通
platemo('algorithm', @REMO_DiRelV2, 'problem', @DTLZ2, 'M', 5, 'D', 14, 'maxFE', 200);

% 2. 与 REMO / 旧 REMO_DiRel 三方对比
run_smoke_DiRelV2('seed', 1, 'M', 5, 'FE', 300, ...
                  'problems', {'DTLZ2'}, ...
                  'algorithms', {'REMO', 'REMO_DiRel', 'REMO_DiRelV2'}, ...
                  'nSeed', 3);
```

预期 smoke test 通过的最低标准：
- 三个算法都不报错跑完
- V2 的 IGD 至少和旧 REMO_DiRel **不更差** (median 相对差距 < 30%)
- 否则诊断需检查 expert validation error 和 label histogram

## 4. Ablation 模式

```matlab
% 跑核心 ablation
run_ablation_DiRelV2('modes', {'A0', 'A1', 'A2', 'A_noTransfer', ...
                               'A_singleSubset', 'A_noNovelty'}, ...
                     'problems', {'DTLZ2', 'WFG4'}, ...
                     'M', 5, 'FE', 300, 'nSeed', 3);
```

模式说明（驱动方式：环境变量 / 参数）：

| Mode | 含义 | 实现 |
|---|---|---|
| `A0`             | REMO baseline       | 直接调用 REMO |
| `A1`             | REMO_DiRel V1 baseline | 直接调用 REMO_DiRel |
| `A2`             | V2 full（默认）     | REMO_DiRelV2 默认参数 |
| `A_noTransfer`   | 关闭迁移初始化      | env `DIREL_USE_TRANSFER=0` |
| `A_singleSubset` | 只保留 Sfull        | env `DIREL_SINGLE_SUBSET=1` |
| `A_noFullExpert` | full expert 最低权重=0 | parameter minW_F=0 |
| `A_noNovelty`    | gamma=0             | env `DIREL_GAMMA=0` |
| `A_noDisagree`   | lambda=0            | env `DIREL_LAMBDA=0` |

需手动追加的 ablation（未自动化）：
- `A_oldLabels`：将 V2 中的 `BuildPairBank_ParetoPBI` 调用替换为旧 `GetRelationPairsBudgeted`（写一个 `REMO_DiRelV2_oldLabels.m` 变体即可）
- `A_oldDifficulty`：把 `DifficultyProfilerV2` 替换为旧 `DifficultyProfiler`

## 5. 调参建议

- `gmax=1000` 是 surrogate-screened 候选预算。M=5,D=14 通常够。M=10,D=19 可调到 2000。
- `K_ens=5` 是 expert 内集成大小。如果训练时间太长可降到 3，但方差估计会变差。
- `alpha_d=0.5` EMA 平滑因子。越小越平滑（保留更多历史）。
- `doKrig=0` 默认关闭 Kriging NRMSE（D_learn 用历史值或中性值）。M 大、FE 多时可开启 `doKrig=1, krigEvery=3`。
- `minW_F=0.30` 是 full expert 的最低权重份额。如果实验发现 V2 被 subset expert 带偏，可提高到 0.4。

## 6. 已知限制 / 后续工作

- **未实测**：本会话只交付代码，没有在 MATLAB 中实际运行。第一次跑通必看 expert valError 和 label histogram（在 Diag 里）。
- **D_sens 是轻量近似**：用随机 pair 估计标签翻转率，对 N<30 不稳定。可在 M 较大时增大 nPair。
- **未集成 RF expert**：P2 任务，暂不实现。
- **PBI fallback theta**：固定为 5，未做自适应。论文若拒掉此处可补一个 self-adaptive theta。

详细论文方法部分见 `论文方法部分草稿.md`。
诊断报告（旧版失败原因复盘 + V2 设计对应）见 `诊断报告_V2.md`。
