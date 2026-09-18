# 巡检自动化记忆：M=20 noBatchDict 消融（noCDIS / noPAQC）

## 任务
只读巡检 `REMO_noBatchDict_noCDIS` 与 `REMO_noBatchDict_noPAQC`（M=20/D=30/N=100/maxFE=300，DTLZ1-7+WFG1-9 × 20 跑，各 320，共 640）。
数据：`D:\REMOandDREMO测试集\20目标\REMO_noBatchDict_{noCDIS,noPAQC}\`
框架：`PlatEMO-master\PlatEMO\Experiments\REMO_noBatchDict_Ablation_M20\`（driver.sh / run_*_M20.m / verify_*.m / missing_runs.py；logs/ 内含 driver.log、`noPAQC_partNN_rX-YY.log`、`noCDIS_partNN_*.log`、`_*_runlog_partNNof16.csv`）
verify 产出：`Experiments\REMO_noBatchDict_Ablation_M20\summary_REMO_noBatchDict_{noCDIS,noPAQC}_M20.csv`（脚本内 outDir = 脚本所在目录）

## 执行记录
### 2026-09-19 03:31–03:36 巡检 #1
- noCDIS 320/320（03:20:47 收尾，3 h 24 min，16/16 切片 ok、0 skipped）；noPAQC 56/320（02:16 起步）；整体 376/640；无 DRIVER_DONE。
- 12 组 worker 存活，自动补起 part 7/8，调度正常。
- 实测单跑 wall（12 路）：noCDIS 390.6 s、noPAQC 453.7 s（均高于设计预估 320/355）。
- ETA 预估 06:30–07:15（中位 ~07:00）。

### 2026-09-19 05:37 巡检 #2
- **noCDIS 320/320（确认逐题 20/20，0 字节文件 0）**；**noPAQC 246/320**；整体 **566/640**；driver.log 无 DRIVER_DONE、`attempt` 仍为 1。
- noPAQC 逐题：DTLZ1-7 与 WFG1 全部 20/20；WFG2 16、WFG3 16、WFG4 16、WFG5 16、WFG6 12、WFG7 10、**WFG8 0、WFG9 0**（后两题 = 尚未启动的 half-slice 15/16）。
- 切片进度：1–8 号（16 个 half-slice）全完；9a–12b 均 8/10；13a/13b 6/10；14a/14b 5/10 → 当前 12 路满负荷（全部 log 在 1–5 min 内写过）。
- 实测速度（最近 40 跑）：runtime 均值 **435.5 s**、wall 均值 **437.6 s**（比 #1 的 453.7 s 略降）。
- 异常扫描：无 fail/error/skipped；两目录 0 字节文件各 0。
- **ETA ≈ 07:05–07:15（剩余约 1.5 h）**：判据 = 9a–12b 这 8 条 lane 各剩 2 跑、约 05:52 释放 → driver 立刻起最后 4 个 half-slice（WFG8 ×2、WFG9 ×2）→ 各 10 跑 × 437 s ≈ 73 min → ~07:05；13/14 号 lane（剩 4/5 跑）约 06:06–06:13 结束，非关键路径。
- 未做动作：未重启 driver、未跑 MATLAB verify（依规则仅在 640 全齐 + DRIVER_DONE 后才跑）。

## 下次运行要点
1. 先数两个目录 .mat；再 `grep -c DRIVER_DONE logs/driver.log`。
2. 若 noPAQC=320 且出现 `DRIVER_DONE`：跑 `matlab -batch "addpath('...Experiments\REMO_noBatchDict_Ablation_M20'); verify_noBatchDict_Ablation_M20;"`，汇报 OK/BAD 与逐题 IGD 均值 + 两个 `summary_REMO_noBatchDict_*_M20.csv` 路径。
3. 若 noPAQC 未满：`grep -c '\[done\]' logs/noPAQC_part*.log` 计数，ETA 用 12 路 / ~437 s 估算（10 跑 half-slice ≈ 73 min/片）。
4. 若 driver.log 超 15 min 无新 "start" 且对应 lane log 也停止写入 → driver 可能已死，需 `bash driver.sh` 补缺（幂等，已存结果会跳过）。
5. **noCDIS 逐题 20 跑终态 IGD 均值（可作基线/对照）**：DTLZ1 76.98 / DTLZ2 1.230 / DTLZ3 347.70 / DTLZ4 1.031 / DTLZ5 0.277 / DTLZ6 6.167 / DTLZ7 23.71 / WFG1 5.600 / WFG2 5.871 / WFG3 2.779 / WFG4 25.25 / WFG5 23.80 / WFG6 19.39 / WFG7 21.08 / WFG8 20.70 / WFG9 25.30（来自 #1 前期汇总，本次未重算）。
6. 提示：`ps -W | grep -c 'bin\\bash.exe'` 在本环境返回 0（转义/路径分隔问题），判断存活请改用"lane log 的 mtime 距今分钟数"与 MATLAB 进程数（正常运行 = 24 个 matlab 进程 / 12 路）。
