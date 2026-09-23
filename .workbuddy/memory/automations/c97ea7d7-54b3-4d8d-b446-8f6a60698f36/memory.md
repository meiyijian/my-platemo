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
