# 自动化记忆：Pruned_qKeep080 实验巡检（id aba96248-1d1f-4533-85a7-fc74de36a8cc）

监控对象：`D:\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080`，288 文件（16 题 × 18 跑），4 分区并行。

## 巡检日志
### 2026-09-12 07:51（首次巡检）
- 进度 46/288，约 64 min 已用。4 分区全部存活，**无中断** → 未触发重启。
- 各分区仍在第 1 个问题（DTLZ1/DTLZ2/DTLZ3/DTLZ4），run 编号连续无缺口，无 tmp 残留。
- part1/part4 零崩溃；part2 已重启 7 次、part3 重启 5 次（均为写盘后 0xc0000374 堆崩，skip 逻辑正常）。
- 全局吞吐 ≈0.72 文件/min；预计 13:00–14:30 收尾（part2 为瓶颈）。
- 尚未触发完整性核对（未达 288）。

### 2026-09-12 08:53（第二次巡检）
- 进度 102/288（35.4%），已用 126.4 min（06:47:24 起）。4 分区全部存活，**无中断** → 未触发重启。
- 各分区进度：part1 DTLZ1 完成(18)+DTLZ5 9/18；part2 DTLZ2 完成+DTLZ6 5/18；part3 DTLZ3 完成+DTLZ7 7/18；part4 DTLZ4 完成+WFG1 9/18。
- 崩溃累计：part1=0、part2=8、part3=5、part4=0（均写盘后堆崩，守护脚本续跑正常）。无 fail/error 行，无 tmp 残留。
- 全局吞吐 0.807 文件/min（较首次巡检 0.72 略升）。预计 **12:24–13:25 收尾，瓶颈 part2（DTLZ6，IGD 收敛慢）**。
- 尚未触发完整性核对（未达 288）。

### 2026-09-12 10:04（第三次巡检）
- 进度 164/288（56.9%），已用 196.6 min（06:47:24 起）。4 分区全部存活，**无中断** → 未触发重启。
- 各分区进度：part1 DTLZ1/DTLZ5 完成 + WFG2 6/18；part2 DTLZ2/DTLZ6 完成 + WFG3 4/18；part3 DTLZ3/DTLZ7 完成 + WFG4 4/18；part4 DTLZ4/WFG1 完成 + WFG5 6/18。
- 崩溃累计：part1=0、part2=8、part3=5、part4=0（旧 rc=127 记录均已过去，非末行）。无 tmp 残留，无 fail 行。
- 近期吞吐 0.873 文件/min（较上次 0.807 再升）。预计 **12:10–13:00 全部收尾**（四分区剩余 30/32/32/30 跑，基本均衡；长尾为 WFG6/7/8，难度未知）。
- 尚未触发完整性核对（未达 288）。

### 2026-09-12 11:05（第四次巡检）
- 进度 215/288（74.7%），已用 257.6 min（06:47:24 起）。4 分区全部存活，**无中断** → 未触发重启。
- 各分区进度：part1 DTLZ1/DTLZ5/WFG2 完成(54) + WFG6 刚起跑 0/18；part2 DTLZ2/DTLZ6 完成 + WFG3 17/18（还差 1 跑即转 WFG7）；part3 DTLZ3/DTLZ7 完成 + WFG4 17/18（转 WFG8）；part4 DTLZ4/WFG1/WFG5 完成(54) + WFG9 1/18。
- 崩溃累计：part1=0、part2=8、part3=5、part4=0（与上次巡检持平，10:04 以来零新增崩溃）。无 fail/error 行，无 tmp 残留，无 0 字节文件。
- 运行号全部连续无缺口（已完成问题均为 1..18，半程问题为 1..N 前缀）。
- 近期吞吐 0.836 文件/min（164→215，61 min）。剩余 73 跑（18/19/19/17），单跑 wall ≈4.5–5.1 min。
- 预计 **12:15–12:50 全部收尾**，瓶颈 part1（WFG6 整题 18 跑未动，难度未知）。
- 尚未触发完整性核对（未达 288）。

## 下次执行要点
- 重启判据（严格）：**仅当** stdout 末行为 `exited rc=` **且** runlog 无 `part N/4 done` 时才重启该分区；
  命令：先 `export PATH=/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:$PATH`，`cd /d/PlatEMO-master/tmp`，再后台 `bash supervise_part.sh <N> 4 200`。
- 达 288 时跑 verify（--runs 18 --expect-fe 300 --xlsx _verify_summary.xlsx），并排对比 qKeep=0.70 目录，然后提醒用户可删除本巡检任务。
- 绝不动目标目录 .mat、绝不改算法源码。
