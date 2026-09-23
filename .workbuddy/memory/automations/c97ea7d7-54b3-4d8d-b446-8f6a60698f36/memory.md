# 巡检自动化记忆 —— NoBatchDist 版 pMix 敏感性（目标 960 跑）

只读巡检；不碰数据、不重启进程。每次巡检后在此追加一行摘要（不放全文）。

## 固定口径（复核用）
- 4 档变体目录前缀：`REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_PMix{000,025,075,100}`
  （**大写 P**），位于 `D:\REMOandDREMO测试集\10目标\n30\` 与 `...\20目标\`。
- 每变体 M=10 120 跑 + M=20 120 跑 ⇒ 4×240 = 960。**PMix050 不跑**，0.50 档复用 Full
  目录 `..._NoBatchDist\`（320 文件是全系列，**不计入**本实验进度）。
- 框架 `PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_pMixSweep/`，
  driver `B8l4zX`（01:07 起，14 路 / threads=1 / gap 25 s / 96 切片）。
- 判定"有效 run"：文件存在且 >10240 B（与 `missing_runs.py` 的 MIN_BYTES 一致），D30/D31 两名皆查。

## 判读要点（避免误报）
- 每跑写**两份镜像切片日志**（`..._partNN_rX-Y.log` 与 `..._pN_rX-Y_a1.log`）⇒ `[done]` 行
  数是真实完成跑数的 2 倍。
- `driver.log` 只在"切片启动"与"整池跑完"时写行；`[done]` 只进切片日志 ⇒ 它长时间不动
  是**正常**的，下一条通常是 `attempt N: pool finished`。
- `missing_runs.py` 每块只打印首/末 run，区间内部有洞 ⇒ 估剩余跑数要自己按文件数算。
- MATLAB `-batch` 退出时 Access violation（addons 联网检查）是噪声，数据已落盘，不报警。

## 历次巡检

- **2026-09-24 01:53** — 进度 **69/960（7.2%）**：PMix000 M10 60、PMix025 M10 8、
  PMix000 M20 1（来自 00:51 预热 smoke，种子一致 ⇒ 有效）；PMix075/100 均 0（未轮到）。
  健康：最新 .mat 01:52（15 min 内 +25 跑，吞吐 ≈100 跑/h）；MATLAB 14 活跃 + 14 个 CPU=0
  stub；无 .tmp.mat / not ok / error / DRIVER_DONE。🔴 **单跑 wall 实测 448–505 s（均值
  ~480 s），远高于原假设 220–290 s**（14 路对 12 核超订 ~1.9×）⇒ ETA 修正为 ≈9–11 h，
  即 09-24 10:30–13:30（中位 ~12:00）。第一波 14 切片约 02:31–02:36 收尾。
  提示（未执行）：MAXJOBS 14→12 可能反而提高聚合吞吐。

- **2026-09-24 02:54** — 进度 **170/960（17.7%）**：**PMix000 M10 120/120 完成**、PMix025 M10 43
  （20/7/4/4/4/4）、PMix075 M10 7、PMix000 M20 1；PMix100 目录未建、M20 整体未开始。
  近 60 min +98 跑 ⇒ 吞吐 ≈99 跑/h（≈01:53 时持平）。健康：最新 .mat 1.6 min 前（02:52:52）；
  MATLAB 14 活跃 + 14 stub；无 .tmp.mat / not ok / error / timeout / DRIVER_DONE /
  rc_part* / poison.txt；2 条 `[skip]`（旧尝试留下的有效文件，正常）。完成切片 14–15/96。
  **实测单跑 wall n=86：mean 493 s（min 262.7=M20 smoke，max 550）**，确认 220–290 s 假设偏低；
  每片 10 跑 ≈1.39 h。**ETA ≈ 09-24 11:00–11:30**（M10 约 06:15 完，再切 M20）。
  池效率 ~95%（理想 14/493 s = 102 跑/h）⇒ 无需调整并发。
  补充经验：`ls -lt` 只能看 mtime；判断"能否有产出"要看 `driver.log` 的最后一条 `start`
  与最新切片日志 mtime 之差（本机每 ~30 s 启动 1 片，14 槽满则停发新 start）。
  同轮顺带把 MEMORY.md 从 14.1 kB 压到 7.5 kB（超注入上限被截断），FE500 六坑迁入 REFERENCE.md。

- **2026-09-24 04:00** — 进度 **280/960（29.2%）**：**PMix000 M10 120/120、PMix025 M10 120/120
  （03:58:17 收尾）**、PMix075 M10 39（DTLZ2 18 / DTLZ4 18 / DTLZ7 3）、PMix100 M10 0
  （03:57:48 刚发片）、M20 仅 PMix000 1（预热 smoke，有效）。近 66 min +110 ⇒ 吞吐 100 跑/h。
  健康：最新 .mat 03:58:58（1.5 min 前）；MATLAB 14 活跃（687 MB–2.38 GB）+ 14 个 ~10 MB stub；
  `[done]` 560 行 = 280 跑 ×2 镜像（与文件数互证）；无 .tmp.mat / not ok / error / timeout /
  poison / rc_part* / DRIVER_DONE；`[skip]` 仍为 2（历史遗留）。driver.log 末行 03:58:29
  `start PMix100 M10 part 2 runs 11-20` ⇒ driver 存活、仍在派片。
  **在飞 14 片**＝PMix075 M10 全部 12 片（parts 2/4 已 18/20，parts 7/8/10/15 刚起步）＋
  PMix100 M10 part 2 两片 ⇒ 已满槽，新片须等空位。
  **ETA ≈ 09-24 10:30–11:30**（剩 680 跑 ÷100 跑/h ≈ 6.8 h ⇒ 中位 ~10:50）。速度与 02:54 巡检持平，
  无需调整 MAXJOBS。经验：`find` 在本机非 ASCII 路径下 `-name` 匹配会静默返回 0，统计一律走
  `ls -1 ... | wc -l`（本轮两次踩到，勿信 find 结果）。
