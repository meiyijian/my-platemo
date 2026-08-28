# Good-group Precision 实验说明

## 结论

原始版本不能作为正式机制证据，主要问题包括：

- 把 PlatEMO 的 `run=25` 误当成“重复 25 次”，实际只执行一个编号为 25 的 run；
- 使用 `maxFE=50000` 和随 M 变化的 D，与本项目冻结的 `D=30, maxFE=500` 协议不一致；由于融合权重依赖 `FE/maxFE`，这会直接改变算法；
- 原始结果写入目录与分析器读取目录不一致；
- 用目标值行匹配解，重复目标值可能造成身份误判；
- 对二值 `label_dyn` 强制取 Top-25%，大量并列最终由行号决定；
- 所谓 `igdgain` 只在当时的 snapshot 上计算，不是等待后得到的 ex-post 真值；
- 把所有阶段混合平均，并进行大量未校正检验；效应量也没有利用配对种子。

当前版本已经改为：复用通过搜索等价性验证的稳定 EvalID 审计轨迹，在运行结束后离线重建未来结果，并按每个独立 run 进行统计。

## 正式实验协议

| 项目 | 正式值 |
|---|---|
| 问题 | DTLZ2、DTLZ4、DTLZ7、WFG3、WFG7 |
| 目标数 | M=10、20 |
| 请求决策维数 | D=30 |
| WFG3 实际维数 | D=31，由问题 `Setting` 自动调整并校验 |
| 种群规模 | N=100 |
| 评价预算 | maxFE=500 |
| 独立运行 | 每个问题-M 组合 25 次 |
| 总 job 数 | 5×2×25=250 |
| 固定种子 | `problemIndex*10000 + M*100 + run` |
| 算法参数 | `gmax=3000, pMix=0.5, rGood=0.25, qKeep=0.8, lambda0=0.35, nMin=4, nMax=6` |

正式配置由 `GGPProtocol('formal')` 唯一定义。每个 run 单独保存，能够断点续跑；已有合法文件会跳过，已有损坏文件会阻止覆盖。

## 指标定义

### 1. 等规模 Top-25% 主比较

以下三个连续分数都选择同样数量的解：

- `score_v`：方向视图分数；
- `anchor_margin = 1 - normalizedG`：Anchor 二值标签阈值之前的连续裕量；
- `score_hybrid`：当前动态融合分数，也是生产算法真正使用的 Catalog。

报告：Precision@25%、Recall、真值 prevalence（chance）、Lift 和 tie-aware ROC-AUC。

### 2. 原始 `label_dyn` 辅助报告

`label_dyn` 是二值结果，其正类比例通常不是 25%。当前版本按其自然正类集合报告 `NativePrecision`、Recall、Retention Rate 和 AUC，不再用行号从并列标签中硬裁 25 个解。它保存在单独的 `GGP_LabelDynNative.csv` 中，不能与固定 Top-25% Precision 不加说明地直接比较。

### 3. Ex-post 真值

解身份使用稳定 `EvalID`，不使用目标向量近似匹配。每个 snapshot 对应六个未来真值：

- `population_h1`：下一个实际训练检查点仍在环境选择后的 Population；
- `population_h3`：第三个实际训练检查点仍在 Population；
- `population_final`：最终仍在 Population；
- `front_h1`、`front_h3`、`front_final`：相应未来时点在已评价 Archive 中非支配。

H1/H3 按实际训练检查点计数，fallback 循环不算一个 horizon。运行末端无法观察到的 H1/H3 记为 censored/NaN，而不是错误地记为 0。

### 4. 阶段与统计单位

阶段严格划分为：

- `[0,0.25]`
- `(0.25,0.50]`
- `(0.50,0.75]`
- `(0.75,1.00]`

分析先在“run × stage × view × truth”内部平均，再以独立 run 作为统计样本。输出包括：

- Wilcoxon signed-rank 原始 p 值；
- 同一问题-M-真值-指标 family 内的 Holm 校正 p 值；
- paired win probability；
- matched-pairs rank-biserial effect size；
- 按配对 run 计算的平均相对提升。

## 它能验证什么

如果 `score_hybrid` 在多个问题、种子和阶段上，相对 `score_v` 与 `anchor_margin` 有更高的 Precision/AUC/Lift，可以支持：

> 在 Hybrid 搜索轨迹下，动态融合分数与后续环境选择保留、后续非支配状态之间具有更强且可重复的预测关联。

阶段结果还可以检验“前期方向视图更有用、后期 Anchor 更有用”这一动态融合动机。只有结果确实出现相应阶段交替时，才能支持该说法。

## 它不能单独验证什么

本实验的未来结果来自 Hybrid 自己驱动的搜索轨迹，因此属于 on-policy 关联证据，不是反事实因果证明。它不能单独证明：

- Hybrid 相对其他算法最终 IGD+/HV 更好；
- 关系模型泛化准确率提高；
- 被真实评价的 candidate 成功率提高；
- 动态融合一定优于 fixed、V-only 或 Anchor-only。

这些结论仍需独立的算法消融、solution-disjoint 关系验证、candidate success rate 和最终 IGD+/HV 实验。

## 如何运行

在 MATLAB 中：

```matlab
experimentDir = ['D:', filesep, 'PlatEMO-master', filesep, ...
    'PlatEMO-master', filesep, 'PlatEMO', filesep, 'Experiments', filesep, ...
    'REMO_new2_AdaMaO_GoodGroupPrecision'];
cd(experimentDir);
```

先执行约 20 秒的代码与小预算集成测试：

```matlab
results = runtests(fullfile(experimentDir, 'tests', 'GoodGroupPrecisionTest.m'));
assertSuccess(results);
```

再执行 smoke 入口：

```matlab
run_GoodGroupPrecision('smoke');
analyze_GoodGroupPrecision('smoke');
```

建议先跑一个正式 job：

```matlab
run_GoodGroupPrecision('formal', ...
    'Problems', {'DTLZ2'}, 'Ms', 10, 'Runs', 1);
```

确认单 job 完成后，可以分批继续：

```matlab
run_GoodGroupPrecision('formal', ...
    'Problems', {'DTLZ2'}, 'Ms', 10, 'Runs', 1:5);
```

完整运行：

```matlab
run_GoodGroupPrecision('formal');
```

不同 MATLAB 进程可以运行互不重叠的 `Runs` 子集。原始结果按 run 独立写入，不共享追加式 CSV；各进程的 manifest 文件名也带时间和进程号。

全部或部分 job 完成后分析：

```matlab
outputs = analyze_GoodGroupPrecision('formal');
```

部分结果也可以分析，但 `GGP_Coverage.csv` 会明确列出缺失 run，不能当作完整正式结论。

## 输出文件

原始结果：

```text
results/raw/<profile>/<Problem>/M<M>/run_<NNN>.mat
```

分析结果：

- `GGP_CheckpointMetrics.csv`：所有 checkpoint-view-truth 明细；
- `GGP_PerRunStage.csv`：每个独立 run、阶段的汇总；
- `GGP_PairedComparisons.csv`：配对检验、Holm 校正与效应量；
- `GGP_LabelDynNative.csv`：二值 `label_dyn` 的自然集合结果；
- `GGP_Coverage.csv`：协议覆盖率与缺失 run。

`IGD` 和 `IGD+` 会随每个 MAT 保存，主要用于完整性检查和后续联表；本实验没有算法间对照，因此不能用这些单算法数值声称最终性能提升。

## 代码入口

- `run_GoodGroupPrecision.m`：正式运行入口；
- `analyze_GoodGroupPrecision.m`：正式分析入口；
- `GGPProtocol.m`：冻结协议；
- `GGPComputeRunMetrics.m`：稳定 EvalID 的 ex-post 指标；
- `GGPValidateRunFile.m`：结果契约校验；
- `tests/GoodGroupPrecisionTest.m`：自动验证。

`algorithms/REMO_GGP.m` 仅保留为兼容别名，继承已验证的 `LVUniformMixAudit_Hybrid`，不再维护一份可能漂移的重复搜索实现。旧 `algorithms/private/GGP_*` 在线 CSV 探针不属于正式入口。
