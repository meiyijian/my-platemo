# 巡检任务执行记录

任务：守护 Pruned 全系列实验（288 文件）跑到完成。

## 关键路径
- 目标目录：`D:\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned`
- 分区进程日志：`D:\PlatEMO-master\tmp\pruned_fullseries\part{1..4}of4_stdout.log`
- 分区运行日志：`<目标目录>\_runlog_part{1..4}of4.txt`
- 守护脚本：`/d/PlatEMO-master/tmp/supervise_part.sh <分区号> 4 200`（支持断点续跑）
- 校验脚本：`D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries\verify_pruned_run.py`

## 执行历史

### 2026-09-12 00:43（首次巡检）
- 文件数 50/288（DTLZ1=13, DTLZ2=12, DTLZ3=12, DTLZ4=13，其余 0）。
- 4 分区全部正常运行中，均处于各自第 1 个问题（DTLZ1/2/3/4）的第 12–13 次运行。
- part2/part3 各在 23:48、23:49 发生过一次 0xc0000374 堆损坏崩溃，守护脚本已自动 attempt 2 重启并成功 skip 已写盘结果 —— 属预期行为，无需干预。
- 4 个 MATLAB 工作进程存活（各约 1.16 GB）。
- 单次运行 wall ≈ 4.3–5.4 min。剩余约 4.5 h，预计 05:10–05:30 完成。
- 未重启任何分区，无文件删除。

### 2026-09-12 01:45（第 2 次巡检）
- 文件数 108/288。分布：DTLZ1–DTLZ4 各 18（已满）；DTLZ5/6/7、WFG1 各 9。
- 4 分区进度（均处于各自第 2 个问题的第 10 次运行附近）：
  - part1 → DTLZ5 9/18（DTLZ1 已完成 18/18）
  - part2 → DTLZ6 9/18（DTLZ2 18/18）
  - part3 → DTLZ7 9/18（DTLZ3 18/18）
  - part4 → WFG1 9/18（DTLZ4 18/18）
- 四个 stdout 日志 mtime 均在 01:41–01:44（新鲜），无新的 "exited rc="；23:48/23:49 的两次崩溃仍是 attempt 1 的遗留记录，attempt 2 一直在跑。
- 4 个 MATLAB.exe 主进程存活（PID 62980 / 48756 / 67824 / 16796，内存 1.1–2.5 GB + 4 个 launcher stub）。
- 吞吐：50→108 共 58 文件 / 61 min ≈ 0.95 文件/min；单次运行 wall ≈ 4.0–4.5 min。
- 每分区剩 45 文件，合计剩 180。预计还需 ≈3.1 h，ETA 约 04:50–05:00。
- 未重启任何分区，无文件删除，未运行校验脚本（未达 288）。

### 2026-09-12 02:45（第 3 次巡检）
- 文件数 164/288。分布：DTLZ1–DTLZ7 + WFG1 各 18（8 题已满）；WFG2/3/4/5 各 5。
- 4 分区完全同步推进，均处于各自第 3 个问题的第 5 次运行：
  - part1 → WFG2 5/18（DTLZ1、DTLZ5 各 18/18）
  - part2 → WFG3 5/18（DTLZ2、DTLZ6 各 18/18）
  - part3 → WFG4 5/18（DTLZ3、DTLZ7 各 18/18）
  - part4 → WFG5 5/18（DTLZ4、WFG1 各 18/18）
  - 各分区各 41/72 完成，剩余 31 文件/分区。
- 无分区中断：4 个 stdout mtime 均在 02:41–02:45（新鲜）；"exited rc=" 仅存在于 part2/part3 第 9 行的 23:48/23:49 历史记录（attempt 1，rc=127），attempt 2 持续运行未再崩。
- 4 个 MATLAB.exe 主进程存活且 PID 与上次一致（62980/48756/67824/16796，内存 1.1–2.3 GB），另有 4 个 8 MB launcher stub。
- 吞吐：00:43→01:45 为 0.94 文件/min，01:45→02:45 为 0.93 文件/min，非常稳定。单次 wall ≈ 4.2–4.5 min。
- 预计还需 ≈2.2–2.4 h，ETA 约 04:55–05:10。
- 未重启任何分区，无文件删除，未运行校验脚本（未达 288）。

### 2026-09-12 03:47（第 4 次巡检）
- 文件数 221/288。分布：DTLZ1–DTLZ7 + WFG1–WFG5 共 12 题各 18（已满）；WFG6=1、WFG7=2、WFG8=1、WFG9=1。
- 4 分区全部进入各自第 4 个（最后一个）问题，且均已开始出结果：
  - part1 → WFG6 1/18（前 3 题各 18/18）
  - part2 → WFG7 2/18（前 3 题各 18/18）
  - part3 → WFG8 1/18（前 3 题各 18/18）
  - part4 → WFG9 1/18（前 3 题各 18/18）
- 无分区中断：4 个 stdout mtime 均 03:43–03:45（新鲜）；part2/part3 的 `exited rc=` 位于第 9 行（共 75/74 行）的历史记录，紧随 attempt 2 启动，attempt 2 已连跑约 4 h 未再崩。
- 4 个 MATLAB.exe 主进程存活，PID 与上次完全一致（62980/48756/67824/16796），内存 1.1–2.3 GB。
- 吞吐：01:45→02:45 为 0.93 文件/min，02:45→03:45 为 0.95 文件/min，依旧稳定。
- 剩余 67 文件（每分区 16–17）。预计还需 ≈70–75 min，ETA 约 05:00–05:05。下次巡检建议 04:45 左右，届时可能刚好收尾并触发 288 校验。
- 未重启任何分区，无文件删除，未运行校验脚本（未达 288）。

### 2026-09-12 04:58（第 5 次巡检 · 收官）
- 文件数 288/288，全部 16 题各 18 份。4 分区 runlog 均含 `part N/4 done`，stdout 末尾 `part N COMPLETE`。
- 分区耗时约 5.1–5.3 h；part2/part3 各 1 skipped（早期崩溃断点跳过），part1/part4 各 0 skipped。
- 已运行校验脚本 `verify_pruned_run.py --runs 18 --expect-fe 300` → mat 288 / valid 288 / missing 0 → **RESULT: COMPLETE**。
- 已在结果目录生成 `_verify_runs.csv`；已向用户汇报 16 题最终 IGD 均值/标准差表，并提示可删除本巡检任务。
- 未重启任何分区，无文件删除，未修改算法源码。**任务结束，本自动化后续无需再执行。**
