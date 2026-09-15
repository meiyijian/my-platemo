# Automation memory — pMix 敏感性扫描巡检

实验：`REMO_UniformMix_Pruned_Weighted_Lambdat030` pMix sweep（5 pMix × 6 题 × M=10/20 × 20 跑 = 1200 跑）
驱动：`Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_pMixSweep\driver_pMixSweep.sh`（MAXPROC=12, THREADS=1，启动 09-15 16:27:55）

## 执行历史

### 2026-09-15 18:01（第 1 次巡检）
- 正常运行，未干预。完成 168/1200，24 个 matlab.exe。runtime>600 s：0 条。
- 修正 ETA 至 09-16 约 03:00（原估 01:00–02:00 偏早，因 M=20 DTLZ 实为 ~390 s、M=10 成本≈M=20）。

### 2026-09-15 19:05（第 2 次巡检）
- 状态：**正常运行，未做任何干预**。完成 290/1200（24%），24 个 matlab.exe（12 路满负荷），驱动存活；已派发 36/120 切片、24 片完成退出。
- 停滞检查：12 个活跃切片最近 `[done]` 均在 4.5 min 内 → 无异常。**注意**：`find -mmin +40` 列出的 17:31–17:33 那批日志是已完成切片，不要误报为停滞。
- runtime/wall > 600 s：**0 条**；全量 wall 顶部 430–450 s，正常。
- 防待机：AC VIDEOIDLE / STANDBYIDLE 均 0x0，`powercfg /lastwake` 唤醒源 0 → 无 S0 事件。已再次下发 `monitor-timeout-ac 0` + `standby-timeout-ac 0`。
- 进度分布：M=10 全 0/600（未开始）；M=20 = pMix000 68 / pMix025 68 / pMix050 58 / pMix075 48 / pMix100 48。WFG1、WFG3 五臂全清，WFG8 部分，DTLZ2 部分（各 8/20），DTLZ4/DTLZ7 未开始。
- 速率：1.85–1.91 跑/min → 剩 910 跑 ≈7.9 h → **ETA 09-16 约 03:00（02:45–03:30）**。
- 工具坑（已记入项目 MEMORY）：切片日志墙钟字段是 `wall 361.4s`，**没有等号**；用 `wall=[0-9]+` 扫描会得假阴性。
- 报告落盘：`...logs/progress_report_20260915_1905.md`（已交付给用户）。
- 附带维护：项目 `MEMORY.md` 超限，已从 13998 B 压缩至 ~11 KB（合并重复排期结论，精简 PWGGP / Git 段落）。

### 2026-09-15 20:08（第 3 次巡检）
- 状态：**正常运行，未做任何干预**。完成 419/1200（34.9%），24 个 matlab.exe（12 路满负荷），驱动存活（queued 48/120, running=12）；已派发 48 切片、36 片完成退出。
- 停滞检查：12 个活跃切片最近 `[done]` 均在 5 min 内 → 无异常。
- runtime/wall > 600 s：**0 条**（max runtime 447.9 s，max wall 450.3 s）。
- 防待机：AC VIDEOIDLE / STANDBYIDLE 均 0x0，已再次下发 `monitor-timeout-ac 0` + `standby-timeout-ac 0`。
- 进度：M=10 全 0/600；M=20 = pMix000 90 / pMix025 90 / pMix050 90 / pMix075 79 / pMix100 70。
- **已判定「M=10 全 0」与「DTLZ7 全 0」均属排队正常**：driver 队列顺序 `for M in 20 10; do for grp in WFG DTLZ`，组内 parts 顺序为 p02→p04→p07，故 M=20 的 DTLZ7（队尾）与全部 M=10 尚未派发。**后续巡检不要再报为异常，只需在 M=20 全清后再看 M=10 是否启动。**
- **单切片时长 ≈ 10 run 串行 × 380 s ≈ 63 min**，故 driver.log 出现 30–60 min 无 `exit=0` 属正常（批次完成间隔 58–63 min）。判断停滞只看活跃切片日志内 `[done]` 的时间戳，不看 driver.log。
- 速率：全程序均 1.90 跑/min（分段 1.80 → 1.91 → 2.08，略升）→ 剩 781 跑 ≈6.4–6.9 h → **ETA 09-16 约 02:30–03:00**。
- 报告落盘：`...logs/progress_report_20260915_2008.md`（已交付给用户）。
