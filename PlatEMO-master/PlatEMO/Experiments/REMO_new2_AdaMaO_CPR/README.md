# REMO_new2_AdaMaO CPR 可复现实验入口

本目录只负责实验协议、运行和筛选统计，不修改算法实现。四个主变体与当前基线的含义固定如下：

| 标签 | 评分源 | 关系目标 | MATLAB 类 |
|---|---|---|---|
| U0 | 当前基线 | 当前基线 | `REMO_new2_AdaMaO_SDEOnly_UniformMix` |
| F00 | 旧评分源 | 单一硬关系 | `REMO_new2_AdaMaO_CPR_F00` |
| F10 | 连续双视角 | 单一硬关系 | `REMO_new2_AdaMaO_CPR_F10` |
| F01 | 旧评分源 | 软关系 | `REMO_new2_AdaMaO_CPR_F01` |
| F11 | 连续双视角 | 软关系 | `REMO_new2_AdaMaO_CPR_F11` |

## 四个 profile

- `screening`：DTLZ2/4/7、WFG2/3/5/7/8，M=10/20，FE=500，10 个配对种子，算法为 U0+F00/F10/F01/F11。
- `formal`：DTLZ1--7、WFG1--9，M=10/20，FE=500，30 个配对种子。默认包含 U0、四个因子变体，以及 REMO、PIEA、PCSAEA 三个正式对照，共 7680 个 job。REMO 覆盖原始算法基线，PIEA 覆盖性能指标代理对照，PCSAEA 覆盖关系学习对照；三者只进入 formal，不污染 screening、extreme 或 micro。
- `extreme`：与开发筛选矩阵相同，但 FE=300，并写入独立的 `FE300/extreme` 目录。它不能与 FE=500 数据合并，也不能把 FE=300 运行继续到 500。
- `micro`：仅 F11、F11_HardVote、F11_Regression，在 DTLZ2、DTLZ7、WFG3、WFG7 上做轻量机制辨识。协议允许先引用尚未落盘的微消融类；实际运行前会进行类存在性检查。

所有 profile 请求 D=30；WFG2 和 WFG3 按问题定义自动使用 D=31，其他问题仍为 D=30。协议中的正式实验不会自动启动，只有显式调用运行函数才会执行。

## 使用方式

在 PlatEMO 根目录启动 MATLAB：

```matlab
addpath('Experiments/REMO_new2_AdaMaO_CPR');

% 只检查矩阵，不启动算法
protocol = CPRExperimentProtocol('screening');
disp(protocol.jobs(1:10,:));

% 开发筛选；省略 outputDir 时写到本目录的 results
manifest = run_CPR_experiment('screening','D:/AdaMaO_CPR_results');

% 显式启动正式实验（规模很大，请确认机器与时间后再运行）
% manifest = run_CPR_experiment('formal','D:/AdaMaO_CPR_results');

% 分析 FE=500 screening 目录
analysis = analyze_CPR_screening( ...
    'D:/AdaMaO_CPR_results/FE500/screening');

% 完整 30 次正式运行结束后再执行正式统计
formalAnalysis = analyze_CPR_formal( ...
    'D:/AdaMaO_CPR_results/FE500/formal');
```

每个结果文件保存：最终 `SOLUTION` population、IGD、IGDp（论文中的 IGD+）、墙钟运行时间，以及 problem、M、请求/实际 D、FE、run、配对 seed、算法类等元数据。已有 `run_XXX.mat` 只有在文件可读、五类输出完整、指标有限，且 profile/problem/M/D/FE/run/seed/算法标签与类全部匹配当前 job 时才会跳过。损坏或旧协议文件会在 manifest 中标记为 `invalid-existing` 并保留原文件，不会被静默覆盖；归档该文件后即可重跑。算法以 `save=0` 和空输出函数直接调用 `Algorithm.Solve(Problem)`，不会调用 `platemo`；随机种子设置语句紧邻 `Solve`，保证同一 problem--M--run 的不同算法使用完全相同的初始随机流。

结果目录按预算硬隔离：

```text
<outputDir>/
  FE500/screening/<problem>/M10/<algorithm>/run_001.mat
  FE500/formal/...
  FE500/micro/...
  FE300/extreme/...
```

## 筛选统计规则

`analyze_CPR_screening` 只读取元数据标记为 `screening` 且 FE=500 的完整结果。它以 problem、M、run、seed 精确匹配每个变体与 U0，计算配对 `log(IGD_variant/IGD_U0)` 和几何均值比。M=10 与 M=20 始终分别统计，不会混池。

置信区间使用固定、独立的分析随机流：单问题表在配对 run 内 bootstrap；DTLZ/WFG 分族表采用分层 bootstrap，每次先在每个抽中的问题内重采样配对 seed，再对问题重采样并等权平均。这样既保留 seed 内不确定性，又不会让某个问题因记录更多而获得额外权重。非劣门槛为 95% CI 上界不超过 1.05；同时每族中 IGD 几何均值退化超过 20% 的问题不得达到两个。缺少协议问题或任一问题未满 10 对时不会判定通过。

分析会生成：

- `CPR_screening_per_problem.csv`：每个 M--问题--变体的配对比值和 CI；
- `CPR_screening_by_family.csv`：每个 M 下 DTLZ/WFG 分族门槛；
- `CPR_screening_decision.csv`：F01/F11 的保留决策；
- `CPR_screening_analysis.mat`：以上表格和分析设置的完整 MATLAB 结构。

IGD 是主指标，IGDp 作为确认指标保存但不替代主筛选规则。正式实验的配对 Wilcoxon、Holm 校正和配对 log-IGD 置信区间只能在 30 次完整运行后由正式分析器执行；不得用筛选阶段的 10 次运行代替正式统计证据。

## 正式统计规则

`analyze_CPR_formal` 只读取 `profile=formal` 且 FE=500 的记录，M=10 与 M=20 完全分开。输出固定保留每个 M 下全部 16×7 个“算法对 U0”计划比较；只有 problem--algorithm 的 30 个预定 run/seed 全部配齐且指标有效时，才计算配对 log-IGD 几何均值比、bootstrap 95% CI 与双侧 `signrank`。IGDp 使用相同规则作为确认列。每个 M 内，IGD 和 IGDp 分别对全部计划的 problem×algorithm 假设做 Holm 校正；缺失比较保持 NaN，不会缩小多重比较族或生成伪完整结论。

F00/F10/F01/F11 的 2×2 交互在每个 problem--M--run 的共同 seed 上计算：

```text
(log(F11)-log(F10)) - (log(F01)-log(F00))
```

交互表报告 30 个 seed 级差分中的差分的均值、bootstrap 95% CI 和双侧 `signrank`，IGDp 同步给出确认列，且绝不跨 M 混池。正式分析生成 `CPR_formal_pairwise.csv`、`CPR_formal_interaction.csv`、`CPR_formal_completeness.csv` 和 `CPR_formal_analysis.mat`。

## 轻量验证

```matlab
results = runtests( ...
    'Experiments/REMO_new2_AdaMaO_CPR/tests/test_CPRExperimentHarness.m');
assertSuccess(results);
```

该测试只验证协议矩阵、D 映射、跨算法配对 seed、FE300/500 隔离和合成筛选统计，不会启动任何优化算法。
