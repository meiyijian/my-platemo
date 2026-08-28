# Dual-PBI Complementarity Supplement

这是 `REMO_new2_AdaMaO_GoodGroupPrecision` 的隔离补充实验，用于检验：

1. 方向 PBI Top-25% 与 Anchor-PBI margin Top-25% 是否各自提供独有的未来真阳性；
2. 生产 Hybrid Top-25% 是否在相同快照和相同种子下同时优于两个单视图。

本目录不修改原 Good-Group Precision 结果，也不修改冻结搜索算法。

## 一次启动全部正式实验

在 MATLAB Command Window 中执行：

```matlab
experimentDir = fullfile('D:', 'PlatEMO-master', 'PlatEMO-master', ...
    'PlatEMO', 'Experiments', ...
    'REMO_new2_AdaMaO_GoodGroupPrecision', ...
    'DualPBI_Complementarity');
cd(experimentDir);
outputs = run_DualPBIComplementarity("formal");
```

该命令依次完成全部 250 个审计重放、统计分析、最终 gate 和图形导出。
程序不会因为效果不显著而停止，也不会自动重试失败任务。运行中断后再次执行同一命令，会跳过已经通过验证的结果并继续缺失任务。

## 命令行启动

在 PowerShell 中执行：

```powershell
& 'D:\mathlab2023a\bin\matlab.exe' -batch "cd('D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_GoodGroupPrecision\DualPBI_Complementarity'); outputs=run_DualPBIComplementarity('formal'); disp(outputs.FinalGate);"
```

## 最终 gate

唯一 gate 为 `FINAL_INTEGRITY_GATE`。只有以下数据完整性条件全部满足时为 `PASS`：

- 10/10 Problem-M 配置完整；
- 250/250 replay 文件通过 schema 验证；
- 250/250 最终 Population、FE、IGD 和 IGD+ 与原始运行等价；
- 40/40 primary Problem-M-Stage 统计单元完整，且每个单元都有 25 个有效配对 run；
- 所有集合分解满足守恒关系。

科学结果是否支持互补性单独保存在 `GGP_ComplementarityDecision.csv`，不影响最终完整性 gate。

## 结果目录

```text
results/
  raw/formal/<Problem>/M<M>/run_<NNN>.mat
  manifests/
  analysis/formal/tables/
  analysis/formal/figures/
  logs/
```

详细设计、统计规则、字段和结论边界见 [EXPERIMENT_PROTOCOL.md](EXPERIMENT_PROTOCOL.md)。

## 运行依赖

- MATLAB R2023a；
- Statistics and Machine Learning Toolbox；
- Deep Learning Toolbox；
- 原 `GoodGroupPrecision/results/raw/formal` 的 250 个有效 MAT；
- 原 `GoodGroupPrecision/results/analysis/formal/GGP_PerRunStage.csv`。

正式命令会在开始时检查关键代码与冻结搜索等价性证据。任何任务失败都会写入 manifest，剩余任务仍继续运行，最后统一由唯一完整性 gate 汇总。

## 只重新分析已有补充结果

```matlab
outputs = analyze_DualPBIComplementarity("formal");
```

这不会重新运行算法。

## 运行测试

```matlab
results = runtests(fullfile(pwd, "tests"), "Strict", true);
disp(results);
assertSuccess(results);
```

测试不会启动正式 250-run 实验。
