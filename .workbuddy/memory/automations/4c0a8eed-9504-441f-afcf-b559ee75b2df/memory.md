# 自动化执行记录：REMO_UniformMix_Pruned_Weighted_Lambdat030 M20 两阶段进度核对

## 任务性质
定时巡检 driver.sh 驱动的两阶段 MATLAB 批处理（阶段1 DTLZ1-7 补跑 / 阶段2 WFG1-9 全跑），
核对进度、清理数据目录内非 .mat 文件、必要时补跑缺失 run。只做进度核对，不做算法性能分析。

## 关键路径
- driver: `D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_M20\driver.sh`
- harness: 同目录 `run_Lambdat030_M20.m`（调用 `run_Lambdat030_M20(PART,[RUNS],STAGE)`）
- 日志: `<expdir>\logs\driver.log`、`partNN_*.log`、`stdout_s1_*.log`、`stdout_s2_*.log`
- 数据: `D:\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030`
- 注意：`_runlog_part*of16.csv` 由 harness 在**每个切片刻结束时**写在数据目录，
  driver.sh 仅在**全部结束后**统一 rm。巡检时若阶段1已完但阶段2在跑，part1-7 即为可安全移走的残留
  （已移到 `<expdir>\logs\runlog_s1\`，用 mv 不用 rm）。

## 执行历史

### 2026-09-15 02:30 — 第 1 次执行
- driver.log：阶段1 00:27:39 启动 → 01:35:07 结束（4048s）；阶段2 01:35:08 起、01:35:11 launched 10 slices。
- 阶段1 结果：DTLZ1-7 **各 20/20，run 1-20 齐全，无缺失 → 无需补跑**。
- 阶段2 进行中：WFG 合计 84/180；MATLAB 进程 20 条（10 组 launcher+engine，正好等于 10 个在跑切片），无孤儿进程。
- 清理：数据目录移出 7 个 `_runlog_part*of16.csv`，目录现仅含 224 个 .mat。
- 未启动任何新 MATLAB 进程（符合"仍有进程在跑只报告进度"规则）。
- 结论：两阶段过渡正常，阶段2 预计 ~03:35 前后全部完成（剩 96 跑 / 10 并行 × ~420s）。
