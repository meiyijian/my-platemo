# 巡检自动化记忆：M=20 noBatchDict 消融（noCDIS / noPAQC）

## 任务
只读巡检 `REMO_noBatchDict_noCDIS` 与 `REMO_noBatchDict_noPAQC`（M=20/D=30/N=100/maxFE=300，DTLZ1-7+WFG1-9 × 20 跑，各 320，共 640）。
数据：`D:\REMOandDREMO测试集\20目标\REMO_noBatchDict_{noCDIS,noPAQC}\`
框架：`PlatEMO-master\PlatEMO\Experiments\REMO_noBatchDict_Ablation_M20\`（driver.sh / run_*_M20.m / verify_*.m / missing_runs.py；logs/ 内含 driver.log、`noPAQC_partNN_rX-YY.log`、`noCDIS_partNN_*.log`、`_*_runlog_partNNof16.csv`）

## 执行记录
### 2026-09-19 03:31–03:36 巡检 #1（第 1 次运行）
- 结果：**noCDIS 320/320 已完成**（03:20:47 收尾，耗时 3 h 24 min，16/16 切片全 `ok`、`0 skipped`）；**noPAQC 56/320**（02:16 起步），整体 **376/640**，未结束，driver 无 DRIVER_DONE。
- driver 存活已核实：12 组 MATLAB worker + driver bash 在跑；切片 1/2 结束后 03:32–03:34 自动补起 part 7/8 → 调度正常。
- 实测单跑 wall（12 路并行，**比设计预估高**）：noCDIS 390.6 s（原估 320 s）、noPAQC 453.7 s（原估 355 s）。
- ETA：noPAQC 剩余 264 跑，按 12 路 ≈ 2.8 h 流量估算，考虑 10 跑/切片的波次量化 → **约 06:30–07:15 结束（中位 ~07:00）**，全会话约 7 h（在原 6.5–7.5 h 预估内）。
- 数据完整性抽查：两目录均无 0 字节文件、无 tmp 残留；noCDIS 逐题 20/20。
- 未做动作：未重启 driver、未跑 MATLAB verify（依规则仅在 640 全齐 + DRIVER_DONE 后才跑）。

## 下次运行要点
1. 先数两个目录 .mat；再 `tail -30 logs/driver.log` 找 `attempt` / `DRIVER_DONE`。
2. 若 noPAQC=320 且出现 `DRIVER_DONE`：跑 `verify_noBatchDict_Ablation_M20`，汇报 OK/BAD 与逐题 IGD 均值 + 两个 `summary_*.csv` 路径。
3. 若 noPAQC 未满：用 `grep -c '\[done\]' noPAQC_part*.log` 计数，ETA 用 12 路 / 454 s 估算（10 跑切片 ≈ 76 min/片）。
4. 若 driver.log 长时间（>15 min）无新 "start" 且 MATLAB count < 12 → driver 可能已死，需 `bash driver.sh` 补缺（幂等，已存结果会跳过）。
5. noCDIS 逐题 20 跑终态 IGD 均值可作基线：DTLZ1 76.98 / DTLZ2 1.230 / DTLZ3 347.70 / DTLZ4 1.031 / DTLZ5 0.277 / DTLZ6 6.167 / DTLZ7 23.71 / WFG1 5.600 / WFG2 5.871 / WFG3 2.779 / WFG4 25.25 / WFG5 23.80 / WFG6 19.39 / WFG7 21.08 / WFG8 20.70 / WFG9 25.30。
