# FE500 七算法巡检（每小时）— 执行记录

## 巡检要点（固定口径，供后续复用）
- 数据根：`D:\REMOandDREMO测试集\20目标\FE500\<算法目录>\`；**子目录是算法跑起来才创建**，未启动的算法目录不存在（不是异常）。
- 日志根：`PlatEMO/Experiments/FE500_M20_SevenAlgs/logs/`；`<KEY>/driver.log` 记切片启动，根目录 `<KEY>_part<NN>_r*.log` 记单跑 `[done]` 行。
- 切片口径：`part NN/16` 的 NN **就是题目序号**（1-7=DTLZ1-7，8-16=WFG1-9），每个 part 两个 chunk（runs 1-10 / 11-20），共 32 切片；**切片内部 run 严格串行**。
- 🔴 **DTLZ7 的 wall 是"每跑"级别的开销，不是一次性**：SSDE 与 SAMOEA 的 DTLZ7 连续多跑 wall 都稳定在 105–540 s，而 `metric.runtime` 仅 1–126 s。推算 DTLZ7 单切片 ≈ 10 跑串行。

## 巡检补充要点
- 🔴 **rc 文件是边跑边追加的**：第一波切片未结束时查 `rc_part*.txt` 会因竞态只读到一部分（05:00 那次误判"rc 全 0"，实际 06:04 全部变成 124）。**必须在切片收尾后（或巡检时重复一次）再判定**。
- 🔴 **CHUNK=10 与 SLICE_TIMEOUT=14400s 在 FE500/REMO 上系统性冲突**：单跑 wall ~1500–1680 s × 10 跑 ≈ 4.2–4.7 h > 4 h，第一波每片必然在第 10 跑前被 timeout 杀（rc=124）。非致命（round 2 只补缺的 1–2 跑），但每片丢最后一个 run 的工作 ≈ 10% 浪费。**后续同类实验建议 CHUNK=5 或 SLICE_TIMEOUT=21600**。
- MAT 命名是 `<CLASS>_<PROB>_M20_D30_<run>.mat`（前缀是类名，不能按 `<题名>_*` 通配）。
- driver 每轮用 `missing_runs.py` 重算缺口 → 重驱只跑缺的 run，不会死循环；poison 需同片被 124 杀 ≥2 次才触发，所以"每片只被杀一次"是安全的。

## 巡检补充要点
- 🔴 **10:11 用户重驱了一版 driver（`maxjobs=14`、memory gate off）**：判断"当前在跑哪个算法"要以**各 `logs/<KEY>/driver.log` 的 mtime** 为准，不能只看根 `driver.log`（根日志 02:04 那条是旧版 maxjobs=16，已作废）。重驱会先跑完 REMO 尾巴再进下一个算法。
- **PACDIS 明显比 REMO 快**：FE500/M=20 单跑 wall ≈ 743→826 s（12–14 min），只有 REMO（1200–1400 s）的 ~60%。⇒ 10 跑/切片 ≈ 2.2 h < 4 h 超时线，**PACDIS 不会再出 rc=124**。
- 一个算法的波次结构 = 30 切片 / MAXJOBS(14) = 3 波（14+14+2），**单波时长 = 10 跑 × 单跑 wall**，总时长 ≈ 3 × 单波。

## 巡检补充要点（13:58 换全局队列版后）
- 🔴 **13:58 用户第三次重驱，换成 `driver (global queue)` 版**：`ALGS=REMO PACDIS HES_EA CSEA PCSAEA SAMOEA SSDE`、**maxjobs=16**、SKIP_PARTS=7、pacing `gap=20s 前 4 次→5s`、memory gate off。一次性 `attempt 1: 106 slices` 混合排队，池子 16 填满后按 KEY 顺序出片（REMO 已满 ⇒ **先全是 PACDIS**）。
- 判断"现在在跑谁"：**只看根 `driver.log` 最后一段** `[KEY] start part ...`（各 `logs/<KEY>/driver.log` 是旧版遗留、mtime 停更，不可信）。
- 重驱会杀掉旧波次未收的切片，但**已落盘的 run 不丢**（新片只补 `runs [3..10]/[13..20]` 这种缺口）。
- PACDIS 单跑 wall 从 14 路时的 ~800 s 涨到 16 路 **1000–1040 s**（≈17 min），稳态吞吐 ≈56 跑/h（16/1020s）。

## 巡检补充要点（15:50 补）
- 🔴 **MAT 前缀是完整类名，不是算法键名**：PACDIS 目录里文件名前缀是 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_`，按 `PACDIS_<题>_*` 通配会**全部数成 0**（15:50 踩过）。统计 per-problem 必须先用 `ls <目录>/*.mat | head` 确认真实前缀。
- 判"某算法还剩多少"的快法：per-problem 计数求和，比数 `[done]` 行可靠（`[done]` 行会被后续 slice 追加、且日志互相交错导致一行塞多条）。

## 巡检补充要点（16:34 补）
- 🔴 **全局队列换算法时会有 ~1 h 的"交接空档"**：PACDIS 波尾只剩几片时池子填不满，而下一个 KEY（HES_EA）要等 driver 走完一轮 attempt 才切片起跑（15:50 后仅 14 片在飞，16:14 才启 HES_EA）。⇒ **波尾实测吞吐会掉到 ~23 跑/h，绝不能拿它外推**，要等到新算法 16 片满池再采样。
- 判"某 chunk 还剩几跑"的可靠法：`tail` 该 chunk 日志的最新 `run k` + 该 chunk 的 run 列表（如 `r11-20` 则剩 `20-k`）；MAT 缺号 = 在飞或待补，不一定是异常。
- **HES_EA 在 FE500/M=20 尚无实测单跑 wall**（起跑 20 min 内 0 条 `[done]`）→ 只能按 1200–1800 s 给区间；且它带已知"NewArc 空则死循环"bug（M=10 时 ~12% run 卡死），**M=20 首小时内要盯是否出现 poison / 长时间无 `[done]`**。

## 巡检补充要点（17:41 补）
- 🔴 **HES_EA 在 FE500/M=20 单跑 wall ≈ 2630–2775 s（44–46 分钟！）**，是 PACDIS（~1000 s）的 2.7 倍、REMO（~1300 s）的 2 倍。**这是目前最慢的算法**，吞吐仅 ≈16/2710s ≈ **21 跑/h**。
- 🟡 **HES_EA 与 `CHUNK=10` + `SLICE_TIMEOUT=14400s` 严重冲突**：10 跑 × 45 min ≈ 7.5 h ≫ 4 h，第一波每片必然在 ~5 跑处被 124 杀（≈20:15–20:24）。非致命（round 2 只剩 ~5 跑 ≈ 3.5 h < 4 h，安全，不会触发 poison），但有 ~10% 重复计算浪费。**下次同类实验对 HES_EA 用 `CHUNK=4` 或 `SLICE_TIMEOUT=25200`**。
- 逐题计数必须用 `cd <dir> && ls *.mat | awk -F_ '{print $3}'`（**不能在 ls 里带目录路径**，目录名 `HES_EA` 的下划线会把字段挤到 `EA`，17:41 踩过）。
- 全局队列"交接空档"再次验证：PACDIS 波尾 17:37 收完，HES_EA 的 part9 17:36 才补位，**16:24→17:36 整整 72 min 池子没补满新片**。

## 巡检补充要点（18:48 补）
- 🔴 **HES_EA 单跑 wall 在满池下继续上涨到 ≈2790–3093 s（46–52 min，均 ~2990 s）**，比 17:41 采样（2630–2775 s）再涨 ~10%，是 16 路内存带宽竞争的直接体现。**别用非满池期的 wall 外推**。
- HES_EA 稳态吞吐实测 ≈**19–21 跑/h**（16/2990s 理论 19.3，17:41→18:48 实测 23 跑/67 min = 20.6，吻合）。
- 判"每 chunk 做到第几跑"最快法：`for f in <KEY>_part*.log; do grep -c "\[done\]" $f; done`（每 chunk 满额 10）。**别用 `grep -h ... | tail`**：多进程并发写同一日志导致行内交错截断，输出脏但计数可靠。
- HES_EA 第一波 16:14–16:24 起 + 4 h → **20:14–20:24 必然触发 rc=124**，每片做完 ~5/10 跑；round2 剩 5 跑 ≈ 4.2 h，仍略超 4 h，可能再杀一次但**不会触发 poison**（需同片被杀 ≥2 次才投毒，边界需盯）。

## 巡检补充要点（19:54 补）
- 🔴 **判定"driver 死了"要三源交叉**：`ps -W | grep -ci matlab` + `tasklist | grep -ci matlab` + 根 `driver.log` 的 mtime。仅 `ps -W` 在沙箱里可能漏读，`tasklist | wc -l`（≈355）能证明命令本身有效，避免把"命令失效"误判成"进程为 0"。
- 🔴 **driver 被杀 ≠ 切片超时**：本次 0 进程发生在 19:18（最后一颗 MAT）之后、20:14 的 4 h 超时线之前，且 HES_EA **完全没有 rc 文件**（rc_total=0）⇒ 是**父 bash/driver 进程整体消失**，不是 `timeout 124`。区分法：rc=124 会留 rc 文件；driver 暴毙则 rc 文件为 0 或停在上一次。
- 重启 driver 仍须按既有红线走**后台任务方式**（前台 `nohup &` 会被工具调用结束连带杀掉）。

## 巡检补充要点（20:57 补）
- 🔴 **driver 死亡已连续 2 次巡检确认（19:54、20:57），累计停机 ≥1 h 39 min**。三源交叉判据稳定有效：`ps -W | grep -ci MATLAB` = 0 且 `tasklist | grep -ci MATLAB` = 0（同时 `tasklist | wc -l`≈342 证明命令本身有效）+ 根 `driver.log` mtime 停在 17:39 + 最后一颗 MAT 停在 19:18 + **MAT 总数跨巡检不变（1287→1287）**。⇒ **"总数跨小时零增长"是最硬的死亡证据**，比进程数还可靠。
- 空闲态基线：driver 死后 MemFree 回到 **16.56 GB**（对比满池时 3.9–4.5 GB），可作为"确实没在跑"的旁证。
- `ps -W | grep -ciE "bash.exe|driver"` = 5 **不能证明 driver 还活着**（沙箱自身的 bash 也会命中），别拿它当存活依据。

## 巡检补充要点（21:59 补）
- 🔴 **HES_EA 逐题缺口可直接当"重驱后该补什么"的清单**：DTLZ1 8 / DTLZ2 7 / DTLZ3 8 / DTLZ4 6 / DTLZ5 6 / DTLZ6 6 / WFG1 6 / WFG2 2（WFG3-9 全 0）。driver 幂等重驱会按 `missing_runs.py` 自动补，无需手工指定。
- `tasklist | wc -l`≈339 且 `grep -ci MATLAB`=0 ⇒ 进程查询命令有效、确为 0 进程（三源交叉判据第三次验证有效）。
- 空闲态 MemFree 基线这次读到 **15.96 GB**（此前记 16.56 GB，属同一量级波动），都能旁证"没在跑"。

## 巡检补充要点（23:03 补）
- 🔴 **driver 死亡判据收敛为「MAT 总数跨巡检零增长 + tasklist/ps 双 0 + driver.log mtime 冻结」三连**，本次第四小时验证有效。19:54 / 20:57 / 21:59 / 23:03 四次巡检总数恒为 1287，**跨 4 小时零增长**。
- 空闲态 MemFree 基线本次 **13.45 GB**（此前记 16.56 / 15.96 GB），**波动区间大（13–17 GB），只能作旁证，不能当主判据**。
- `tasklist | wc -l`≈355（证明查询命令有效）+ `grep -ci MATLAB`=0，三源交叉判据第四次成立。

## 巡检补充要点（09-22 00:56 补）
- 🔴 **driver 已于 09-21 23:52 由用户重启（第五版：`RUNS=1-10`、不再跳过 DTLZ7）**：目标文件数改为 SSDE 320 / SAMOEA 318 / REMO·PACDIS 310 / HES_EA·CSEA·PCSAEA 各 160 ≈ 1738。判"是否恢复"最快法 = 根 `driver.log` 出现新的 `attempt 1: 53 slices to launch` + `[KEY] start part` 时间戳跳到 23:5x。
- 全局队列这一波 16 片 = **HES_EA 12 + PACDIS 2 + REMO 2**（REMO/PACDIS 只剩 DTLZ7 两个 chunk）。剩余 37 片待启 = CSEA 16 + PCSAEA 16 + HES_EA parts13-16 等。
- **DTLZ7 单跑 wall 实测远大于普通题**：HES_EA DTLZ7 wall 3363 s（runtime 仅 2371 s ⇒ ~990 s 是 2^19 参考集的指标开销）；PACDIS DTLZ7 wall 2379–2424 s。⇒ **首跑落地要等 40–56 min，别用"20 min 没动静"判卡死**。
- 恢复后首小时只 +14 跑（1287→1301）**不可外推**——前 40 min 全在等首跑落地；稳态要看首波落地之后（00:32→00:51 落 12 跑）。

## 巡检补充要点（09-22 02:10 补）
- 🔴 **REMO 的 DTLZ7 慢到离谱：单跑 wall 4707 s（≈78 min）**，runtime 4031 s + ~675 s 指标开销，是 PACDIS DTLZ7（2391–2488 s）的 ~2 倍、HES_EA DTLZ7（3363 s）的 1.4 倍。⇒ REMO 的 DTLZ7 两个 chunk（各 5 跑串行）尾部长达 **5+ h**，会长期占着 2 个槽位拖慢全局吞吐，估算 HES_EA/CSEA/PCSAEA 时要把 16 槽按 14 有效槽折算。
- HES_EA 在 16 路满池下单跑 wall **2275–2369 s（≈38–39 min）**，比 17:41（2630–2775）和 18:48（2790–3093）都低 ⇒ 实测吞吐回升到 **~20 跑/h**（00:56→02:04 实测 +23 跑/68 min）。**别再用 2990 s 外推**。
- 统计 `.mat` 用 `ls <dir>/*.mat | wc -l` 在数据盘上很慢（7 个目录耗时 2m43s，会触发自动转后台）；**tmp.mat 检查改用 `find -maxdepth 1 -name "*.tmp.mat"`（6 s 完成）**。

## 巡检补充要点（09-22 03:17 补）
- **PACDIS 已收官 310/310**（02:10 的 306 → 03:16 的 310，DTLZ7 两个 chunk 补齐），本阶段目标达成。
- 数 `.mat` 用 `find <dir> -maxdepth 1 -name "*.mat" | wc -l`（**7 个目录 12 s 完成**），彻底替代会跑 2m43s 的 `ls <dir>/*.mat | wc -l`；tmp.mat 用同命令换 `-name "*.tmp.mat"`，一次循环同时拿两个数。
- HES_EA 单跑 wall 在 16 路满池下稳定在 **2230–2350 s（≈38 min）**，与 02:10 采样一致 ⇒ 稳态可按 ~2300 s 外推。
- HES_EA 旧波日志（`_r1-10.log` / `_r11-20.log`）与本波（`_r4-10` / `_r5-10` / `_r2-10`）**同名前缀混在目录里**，数 `[done]` 前先确认哪个是本波（本波起跑 23:53）。

## 巡检补充要点（09-22 04:23 补）
- 🔴 **CSEA 极快：单跑 wall ≈348–355 s（≈6 min）**，只有 HES_EA 的 1/3、PACDIS 的 1/3。03:52 起跑 12 片，04:23 已 done 54 跑 ⇒ 实测 **≈105–130 跑/h**。CSEA 160 跑 ≈ **1.5 h** 即可收完，别再用 REMO/HES_EA 的量级外推。
- 🔴 **HES_EA 单跑 wall 随并发数大幅变化**：16 路满池时 2230–3093 s，降到 **4 路并发时骤降到 1011–1078 s（≈17 min）**。⇒ 波尾/混池期**不能复用满池 wall**，吞吐量实测比 wall 反推更靠谱。
- 判"某 KEY 已做几跑"用 `grep -h "\[done\]" <KEY>/*.log | wc -l`（日志在 `logs/<KEY>/p<NN>.log`，本波起 CSEA 用的是 `<KEY>/*.log` 通配即可）。
- ⚠️ `tasklist` 在本机耗时 ~2m40s（会触发自动转后台），**能省则省**；`ps -W | grep -c MATLAB.exe` 快且够用，仅在怀疑 driver 死亡时才加 tasklist 交叉验证。

## 巡检补充要点（09-22 08:34 收官补）
- 🔴 **收官判据要用 per-problem 计数，不能只看目录总数**：HES_EA 总数 184 > 目标 160，但多出的是早期 20 跑轮次的残留，必须逐题确认「每题 ≥10」才算达标（实测逐题 10–14）。
- 收官态特征：**MATLAB 进程 0 + MemFree 回到 17.8 GB + driver.log mtime 停在 06:59（最后一次启 SSDE parts 1-16 的补缺轮）**，这是「跑完了」而非「driver 死了」——区分点就是总数/逐题是否已达标。
- rc=124 累计 19 个文件（REMO 9 + HES_EA 10 历史遗留），**全程 0 个 poison**，最终全部靠 round2 补缺补齐 ⇒ CHUNK=10 + 4 h 超时的浪费是真实存在但可自愈的。

## 巡检补充要点（09-22 09:42 补）
- 🔴 **达标后 driver 会进入"空转收尾"循环，不是异常**：attempt 2(06:35)/3(08:56)/4(09:13)/5(09:29) 各启 96 片，但 harness 逐条 `[skip] ... (valid, final IGD ...)`，`part N/16 done: 10 runs (10 skipped) in 1.4 s` ⇒ 每片 1–2 s 退出、MATLAB 进程在两次采样间为 0、MemFree 回到 14 GB。**判据**：`p*.log` 尾行是 `10 runs (10 skipped)` 且 MAT 总数不变 ⇒ 在空转而非卡死/死亡。ROUNDS=8 跑完（约 10:20）driver 自行退出，无需干预。
- 根因：python 侧 `missing_runs.py` 只按文件名判存在，不做 harness 的 valid 校验 ⇒ 每轮都把已有 run 当缺口重新下发；harness 侧再全 skip。**这属于幂等自愈设计，不产生重复计算**。
- 收官后再巡检：只需 `find <dir> -maxdepth 1 -name "*.mat" | wc -l` 七个数 + `ps -W | grep -c MATLAB.exe`，10 s 内可判完。

## 执行历史

### 2026-09-22 09:42 — 第二十六次执行（✅ 维持达标，driver 空转收尾）
- 七算法文件数维持达标：SSDE 320 / SAMOEATL2M 319 / REMO 310 / PACDIS 310 / HES_EA 185 / CSEA 160 / PCSAEA 160（合计 1764）。本小时仅 HES_EA +1（DTLZ7 run10）。
- MATLAB 进程 0–3 波动、MemFree 14.07 GB；driver.log 活跃（09:42 仍在起 SAMOEA part13），但切片全部 skip ⇒ 属收尾空转，非死亡。按约定只回一句收官结论。

### 2026-09-22 08:34 — 第二十五次执行（🎉 本阶段全部达标）
- 七算法全部达到/超过期望文件数：SSDE 320、SAMOEATL2M 319(≥318)、REMO 310、PACDIS 310、HES_EA 184(≥160，逐题 10–14)、CSEA 160、PCSAEA 160，合计 1763（目标 1738）。
- 进程 0 / MemFree 17.8 GB / driver.log 停 06:59 ⇒ driver 已完成退出（非死亡）。异常：poison 0、tmp.mat 0、unknown key 0；rc=124 仅历史 19 条。已按约定只回一句收官结论。

### 2026-09-22 04:23 — 第二十四次执行（✅ 正常推进，CSEA 起跑）
- 总进度 **1425 / 1738**（82.0%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、PACDIS 310 ✅、REMO 306/310、HES_EA **125/160**、**CSEA 46/160（03:52 刚起跑）**、PCSAEA 0/160（目录未创建）。
- 16 个 MATLAB 进程（满池），MemFree **2.28 GB**（16 路满池常态低位，闸已关），根 driver.log mtime 03:56 ⇒ driver 存活；本小时 **+66 跑**（03:17 的 1359 → 1425）。
- 槽位分配 = HES_EA parts 13-16（4 片，03:12–03:36 起）+ CSEA parts 1-12（12 片，03:52–03:56 起）= 16。
- 异常**全部无**：poison 无、tmp.mat 全 0、unknown key 0；rc=124 = REMO 9 文件（历史）+ **HES_EA 10/12（03:53 超时线命中，非致命，round2 补缺，未触发 poison）**。
- ETA：CSEA ≈05:15、HES_EA 尾 + PCSAEA 160 + REMO DTLZ7 4 跑 ≈ **07:00–08:30 全部收官**。

### 2026-09-22 03:17 — 第二十三次执行（✅ 正常推进）
- 总进度 **1359 / 1738**（78.2%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、**PACDIS 310 ✅（收官）**、REMO 304/310、HES_EA **107/160**、CSEA/PCSAEA 目录尚未创建（0/160）。
- 16 个 MATLAB 进程（满池，ps=16 / tasklist 命中 32），MemFree **7.80 GB**，根 driver.log mtime 03:12（HES_EA part13 刚补位）⇒ driver 存活；本小时 +29 跑（HES_EA +23、REMO +2、PACDIS +4）。
- 异常**全部无**：poison 无、tmp.mat 全 0、unknown key 0；rc=124 仍仅 REMO 历史 8 个 part（parts 1-6/8/9），HES_EA rc_files=0（本波未到 4 h 线）。
- 已知非致命风险：HES_EA 本波 23:53 起 + 4 h ⇒ **03:53 前后会被 rc=124 杀**，round2 补缺（不会触发 poison）。

### 2026-09-22 02:10 — 第二十二次执行（✅ 正常推进）
- 总进度 **1330 / 1738**（76.5%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 302/310、PACDIS 306/310、HES_EA **84/160**、CSEA/PCSAEA 目录尚未创建（0/160）。
- 16 个 MATLAB 进程（满池，ps=16 / tasklist 命中 32 ≈ 16×2），MemFree **6.98 GB** ⇒ driver 存活，本小时 +29 跑（HES_EA +23、REMO +2、PACDIS +4）。
- 当前在跑：根 driver.log 最后一段 = HES_EA parts 1-12 共 16 片（23:53–23:55 起），外加 REMO/PACDIS 的 part7(DTLZ7) 各 2 片占据部分槽位。
- 异常**全部无**：poison 无、tmp.mat 全 0、unknown key 0；rc=124 仍仅 REMO 历史 8 条，HES_EA rc_files=0（本波未收尾，符合预期）。
- 已知非致命风险：HES_EA 本波 23:53 起 + 4 h ⇒ **03:53 前后会被 rc=124 杀**，每片约完成 6/10 跑，round2 补缺（不会触发 poison）。

### 2026-09-22 00:56 — 第二十一次执行（✅ driver 已恢复）
- 总进度 **1301 / 1738**（74.9%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300/310（DTLZ7 在飞）、PACDIS 302/310、HES_EA **61/160**、CSEA/PCSAEA 未启动。
- 16 个 MATLAB 进程（满池），MemFree 6.91 GB ⇒ driver 存活，恢复后已跑 64 min、+14 跑。
- 异常：poison 无、tmp.mat 无、unknown key 无；rc=124 仍仅 REMO 历史 8 条，**HES_EA rc_files=0**。
- HES_EA 逐题：DTLZ1 9/2 8/3 9/4 7/5 7/6 7/7 1/WFG1 7/WFG2 3/WFG3 1/WFG4 1/WFG5 1，WFG6-9 全 0。
- 已知非致命风险：HES_EA 10 跑切片 × ~2400 s ≈ 6.7 h ≫ 4 h 超时线 ⇒ **03:53 前后会被 124 杀**，round2 补缺。

### 2026-09-21 23:03 — 第二十次执行（🚨 driver 死亡第四小时确认，仍零进展）
- 总进度 **1287 / 2240**（与 19:54、20:57、21:59 **连续四次完全相同，本小时 +0 跑**）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、PACDIS 300 ✅、HES_EA **49/300**、CSEA/PCSAEA 未启动。
- MATLAB 进程 0（ps + tasklist 双向确认，tasklist 总数 355 证明命令有效），MemFree 13.45 GB（空闲基线）⇒ **driver 仍死，累计停机 ≥3 h 45 min**（最后 MAT 19:18）/ ≥5 h 24 min（driver.log 17:39）。已再次给出幂等恢复命令但**未执行**。
- 异常：poison 无、tmp.mat 无、unknown key 无；rc=124 仍仅 REMO 历史 8 条，**HES_EA rc_files=0**（第四次印证 driver 暴毙而非切片超时）。
- HES_EA 逐题：DTLZ1 8 / DTLZ2 7 / DTLZ3 8 / DTLZ4 6 / DTLZ5 6 / DTLZ6 6 / WFG1 6 / WFG2 2（WFG3-9 全 0）。
- 剩余 851 跑（HES_EA 251 + CSEA 300 + PCSAEA 300）；重启后按 HES_EA ~20 跑/h ⇒ HES_EA 还需 ~13 h，大头收完 **≈ 9/23 下午–9/24**（且随停机时长继续顺延）。

### 2026-09-21 21:59 — 第十九次执行（🚨 driver 死亡第三小时确认，零进展）
- 总进度 **1287 / 2240**（与 19:54、20:57 **连续三次完全相同，本小时 +0 跑**）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、PACDIS 300 ✅、HES_EA **49/300**、CSEA/PCSAEA 未启动。
- MATLAB 进程 0（ps + tasklist 双向确认，tasklist 总数 339 证明命令有效），MemFree 15.96 GB（空闲基线）⇒ **driver 仍死，累计停机 ≥2 h 41 min**。最后 MAT 19:18、driver.log 停在 17:39。已给出幂等恢复命令但**未执行**。
- 异常：poison 无、tmp.mat 无、unknown key 无；rc=124 仍仅 REMO 历史 16 条，**HES_EA rc_files=0**（第三次印证 driver 暴毙而非切片超时）。
- HES_EA 逐题：DTLZ1 8 / DTLZ2 7 / DTLZ3 8 / DTLZ4 6 / DTLZ5 6 / DTLZ6 6 / WFG1 6 / WFG2 2（WFG3-9 全 0）。
- 剩余 851 跑（HES_EA 251 + CSEA 300 + PCSAEA 300）；重启后按 HES_EA ~20 跑/h ⇒ HES_EA 还需 ~13 h，大头收完 **≈ 9/23 上午–9/24**（CSEA/PCSAEA 速率未实测）。

### 2026-09-21 20:57 — 第十八次执行（🚨 driver 死亡持续，零进展）
- 总进度 **1287 / 2240**（与 19:54 完全相同，**本小时 +0 跑**）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、PACDIS 300 ✅、HES_EA **49/300**、CSEA/PCSAEA 未启动。
- MATLAB 进程 0（ps + tasklist 双向确认），MemFree 16.56 GB（空闲基线）⇒ **driver 仍死**，最后 MAT 19:18、driver.log 停在 17:39，已停机 ≥1 h 39 min。已再次给出幂等恢复命令但**未执行**。
- 异常：poison 无、tmp.mat 无、unknown key 无；rc=124 仍仅 REMO 历史 8 个 part（各 2 条），**HES_EA rc_total 仍为 0**（再次印证是 driver 暴毙而非切片超时）。
- HES_EA 逐题：DTLZ1 8 / DTLZ2 7 / DTLZ3 8 / DTLZ4 6 / DTLZ5 6 / DTLZ6 6 / WFG1 6 / WFG2 2。

### 2026-09-21 19:54 — 第十七次执行（🚨 driver 死亡报警）
- 总进度 **1287 / 2240**（57.5%；本阶段满额 2138，占 60.2%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、PACDIS 300 ✅、HES_EA **49/300**、CSEA/PCSAEA 未启动。
- **MATLAB 进程 0（tasklist 与 ps 双向确认），MemFree 12.62 GB（空闲）⇒ driver 已死**，最后一颗 MAT 19:18、根 driver.log 停在 17:39。已给出幂等恢复命令但**未执行**。
- 异常：poison 无、tmp.mat 无、unknown key 无；rc=124 仍仅 REMO 历史 8 条，**HES_EA rc_total=0**（印证是 driver 暴毙而非切片超时）。

### 2026-09-21 18:48 — 第十六次执行
- 总进度 **1283 / 2240**（57.3%；本阶段满额 2138，占 60.0%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、PACDIS 300 ✅、HES_EA **45/300**（16:14 起跑）；CSEA/PCSAEA 未启动（目录不存在）。
- 16 个 MATLAB 进程（满池，HES_EA parts 1-6/8/9 共 16 片），MemFree **4.52 GB**。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仍仅 REMO 历史 8 条，HES_EA 尚无 rc 文件（在飞中）。
- HES_EA 单跑 wall 2790–3093 s（≈50 min）→ 剩 255 跑 ≈ **13–15 h（含超时浪费）→ 9/22 09:00–10:00**；其后 CSEA+PCSAEA 600 跑 → 大头收完 **≈ 9/22 11:00（乐观）– 9/23 00:00（悲观）**，中性 9/22 18:00。
- 实测时段吞吐 **+23 跑 / 67 min ≈ 20.6 跑/h**（满池稳态，可外推）。

### 2026-09-21 17:41 — 第十五次执行
- 总进度 **1260 / 2240**（56.3%；本阶段满额 2138，占 58.9%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、**PACDIS 300 ✅（17:37 收官）**、HES_EA **22/300**（16:15 起跑）；CSEA/PCSAEA 未启动。
- 16 个 MATLAB 进程（满池，part9 17:36 刚补位），MemFree **3.90 GB**（闸关闭）。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仍仅 REMO 历史 8 个文件。
- HES_ETA：HES_EA 剩 278 跑 ≈ **15–16 h（含超时浪费）→ 9/22 07:00–09:00**；其后 CSEA+PCSAEA 600 跑 → 大头收完 **≈ 9/22 21:00（乐观 56 跑/h）– 9/23 12:00（悲观 21 跑/h）**。
- 实测时段吞吐 **+25 跑 / 67 min ≈ 22.4 跑/h**（交接空档期，不可外推）。

### 2026-09-21 16:34 — 第十四次执行
- 总进度 **1235 / 2240**（55.1%；本阶段满额 2138，占 57.8%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、**PACDIS 296/300**（DTLZ1-6+WFG1-8 全满 20，仅 WFG9=16；缺的 9/10/19/20 全在飞，非丢失）、HES_EA 1（pilot）；CSEA/PCSAEA 未启动。
- 16 个 MATLAB 进程（= 14 片 HES_EA + 2 片 PACDIS），MemFree **3.89 GB**（较 15:50 的 7.69 GB 下降，闸本就关闭）。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仍仅 REMO 历史 8 个文件（parts 1-6/8/9），PACDIS 无新增。
- **PACDIS 16:14 让位，HES_EA 16:15–16:24 起跑 parts 1-6,8 共 14 片**（全局队列正常混排）。PACDIS 收尾 = WFG9 两 chunk 各剩 2 跑 × ~1150 s → **ETA ≈ 17:05–17:15**。
- PACDIS 16 路下单跑 wall 涨到 **1048–1217 s**（14 路时 ~800 s），内存带宽竞争明显。
- 波尾实测吞吐 **+32 跑 / 84 min ≈ 22.9 跑/h**（碎片化+交接空档，不可外推）。剩余 903 跑（含 PACDIS 4）→ 大头收完 **≈ 9/22 09:00（55 跑/h）– 9/22 15:00（40 跑/h）**。

### 2026-09-21 15:50 — 第十三次执行
- 总进度 **1203 / 2240**（53.7%；本阶段满额 2138，占 56.3%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、**PACDIS 264/300**（DTLZ1-6+WFG1 满 20；WFG2-8 各 16；WFG9 12），HES_EA 1（pilot）；CSEA/PCSAEA 未启动。
- 16 个 MATLAB 进程（满池），MemFree **7.69 GB**（较 14:27 的 4.91 GB 回升，闸本就关闭）。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仍仅 REMO 历史 16 条，PACDIS 14 个 rc 全 0。
- 实测吞吐 **+80 跑 / 81 min ≈ 59.3 跑/h**（14:27→15:48）。PACDIS 单跑 wall **1016–1101 s（≈17–18 min）**，16 路下比 14 路（~800 s）略慢，符合带宽竞争预期。
- 在飞 16 片全是 PACDIS parts 9-16（14:00-14:01 起）。瓶颈 = part16/WFG9（起跑时 0/20，两 chunk 各还需 4 跑 ≈ 70 min）→ **PACDIS ETA ≈ 今天 17:00**。
- 剩余 HES_EA/CSEA/PCSAEA 共 899 跑 → 大头收完 **≈ 9/22 09:00（55 跑/h）– 9/22 15:00（45 跑/h）**。

### 2026-09-21 14:27 — 第十二次执行
- 总进度 **1123 / 2240**（50.1%；本阶段满额 2138，占 52.5%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、PACDIS **184/300**、HES_EA 1（pilot）；CSEA/PCSAEA 未启动。
- 16 个 MATLAB 进程（新 driver maxjobs=16 满池），MemFree 4.91 GB。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仍仅 REMO 历史 16 条，PACDIS 14 个 rc 全 0。
- 当前 16 片全是 PACDIS（parts 9-16 补缺，14:01 起，单跑 wall 1000–1037 s）→ PACDIS ETA ≈ **今天 17:00–17:20**。
- 剩余 HES_EA/CSEA/PCSAEA 共 899 跑 → 大头收完 **≈ 9/22 03:00（按 96 跑/h 乐观）– 9/22 09:00（按 57 跑/h 保守）**。

### 2026-09-21 13:22 — 第十一次执行
- 总进度 **1077 / 2240**（48.1%；本阶段满额 2138，占 50.4%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、**PACDIS 138/300**（DTLZ1-6 六题 20/20 全收，WFG1=part8 18/20），HES_EA 1（pilot）；CSEA/PCSAEA 未启动。
- 14 个 MATLAB 进程（满池），MemFree **2.24 GB**（比 12:17 的 9.17 GB 明显下降，但 `MIN_FREE_MB=0` 闸已关，不影响）。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仅 REMO 历史 16 条；PACDIS 13 个 rc 全 0（**波1 12 片全部正常退出，未触发 4h 超时**，印证 PACDIS 比 REMO 快 ~40%）。
- 实测吞吐 **+68 跑 / 65 min ≈ 62.8 跑/h**（理论 14/850s≈59/h，吻合）。PACDIS 单跑 wall **788–879 s（≈14 min）**。
- 切片池其实是**滚动**的（不是死板的 14+14+2）：波1 = parts 1-6 + part8 共 14 片，10:58 起 → 13:17~13:23 陆续收；空出的槽立刻启 parts 9-14（13:14-13:21），part8 收完再启 part15；**part16 要等波2 某片 ~15:40 收才启**，故 **PACDIS ETA ≈ 今天 18:00**（波尾 2 片并行度低，别用稳态速率线性外推）。
- 剩余 HES_EA/CSEA/PCSAEA 共 900 跑 → 大头收完 **≈ 9/22 09:00（60 跑/h）– 9/22 17:00（40 跑/h）**。
- 复用要点：判"某算法还剩几片没启"= 数 `logs/<KEY>/driver.log` 里 `start part` 的行数 vs 该算法总切片数（跳过 DTLZ7 时 = 30）；滚动池下"已启未收"的片数应恒等于进程数（上限 MAXJOBS）。

### 2026-09-21 12:17 — 第十次执行
- 总进度 **1009 / 2240**（45.0%；本阶段满额 2138，占 47.2%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO 300 ✅、**PACDIS 70/300**（第一波 14 chunk 各 5–6/10）、HES_EA 1（pilot）；CSEA/PCSAEA 未启动。
- 14 个 MATLAB 进程（满池），MemFree **9.17 GB**。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仅 REMO 历史 16 条（已补齐）；PACDIS 尚无 rc 文件（第一波未收尾，符合预期）。
- PACDIS 单跑 wall **789–869 s（≈13–14 min）**，确认比 REMO（1200–1400 s）快约 40%。三波结构 14+14+2：波1 11:00→13:20、波2 →15:40、波3 →**18:00 收官**。实测吞吐 ≈53–60 跑/h。
- 剩余 HES_EA/CSEA/PCSAEA 共 900 跑 → 大头收完 **≈ 9/22 09:00（按 PACDIS 60 跑/h）– 9/22 16:30（按 REMO 40 跑/h）**。
- 复用要点：波3 只有 2 个切片并发（并行度掉到 2），**最后 20 跑也要 ~2.3 h**，别用稳态速率线性外推整个算法。

### 2026-09-21 11:14 — 第九次执行
- 总进度 **951 / 2240**（42.5%；本阶段满额 2138，占 44.5%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、**REMO 300 ✅（10:58 收官）**、PACDIS **12/300**（10:58 起跑，第一波 14 片满池）、HES_EA 1（pilot）；CSEA/PCSAEA 未启动。
- 14 个 MATLAB 进程（满池），MemFree **7.72 GB**。异常**全部无**：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仅 REMO 历史 16 条（已被 round3 补齐，不影响）。
- PACDIS ETA ≈ **今天 17:45–18:15**（3 波 × 2.2 h）；剩余 HES_EA/CSEA/PCSAEA 共 900 跑 → 大头收完 **≈ 9/22 08:00（乐观，按 PACDIS 63 跑/h）– 9/22 20:00（悲观，按 REMO 40 跑/h）**。
- 复用要点：判"重驱后当前算法"= `ls -t logs/<KEY>/driver.log`；`REMO done: present=300/320` 这种行说明该算法本阶段已收满（缺 20 是 DTLZ7 预期留空）。

### 2026-09-21 09:26 — 第八次执行
- 总进度 **899 / 2240**（40.1%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO **260/300**、HES_EA 1（pilot）；CSEA/PCSAEA/PACDIS 未启动（目录不存在，非异常）。
- 14 个 MATLAB 进程（第二波 parts 10-16 × 2 chunk 仍全在跑），MemFree **10.84 GB**（比 08:15 的 4.32 GB 大幅回升，闸未触发）。
- 实测吞吐 **≈40.6 跑/h**（08:15→09:26 实测 +48 跑/71 min）。REMO 单跑 wall 稳定 **1195–1304 s**（≈20-21 min，比第一波 1420–1760 s 更快）。
- 第二波每 chunk 已做完 **8–9/10**，剩 2 跑 ≈ 42 min → 约 **10:05–10:12** 收，紧贴 10:04–10:07 的 4 h 超时线，**大概率再出一批 rc=124**（非致命，round 3 补缺）。
- REMO 缺口精确 = 40 跑（10 个 part 各缺 2 + 5 个 part 各缺 4）→ round 3 两波 ≈ 85 min，**REMO ETA ≈ 今天 11:30–12:00**。剩余 4 算法共 1200 跑，按 35 跑/h → 大头收完 **≈ 9/22 22:00 – 9/23 04:00**。
- 异常：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仍为已知 16 条（REMO parts 1-6/8/9 两 chunk），**本小时无新增**。
- 复用要点：判"某 part 还剩几跑"= 看该 part 两个 chunk 日志里最新的 run 号（chunk A 跑 1-10、chunk B 跑 11-20），`剩余 = 10 - (run号 mod 10)`。

### 2026-09-21 08:15 — 第七次执行
- 总进度 **851 / 2240**（38.0%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO **212/300**、HES_EA 1（pilot）；CSEA/PCSAEA/PACDIS 未启动（目录不存在，非异常）。
- 14 个 MATLAB 进程（= 第二波 7 part × 2 chunk = 14 片，满池），MemFree 4.32 GB（闸未触发）。
- 实测吞吐回升到 **≈40.6 跑/h**（07:13→08:15 实测 +42 跑/62 min）。REMO 单跑 wall 1233–1374 s（≈21 min，比第一波略快）。
- 第二波 06:07 起，每 chunk 已做完 5–6/10 跑 → 预计 09:45–10:05 收，**紧贴 10:07 的 4 h 超时线，大概率再出一批 rc=124**（非致命，round 3 补缺）。REMO ETA ≈ **今天 10:45–11:00**（含 round 3 补 ~18 个缺跑）。
- 异常：poison 无、tmp.mat 无、unknown key 无、[mem] 刹车无；rc=124 仍为已知 16 条（REMO parts 1-6/8/9 两 chunk），**本小时无新增**。
- 剩余 4 算法（PACDIS/HES_EA/CSEA/PCSAEA）共 1200 跑，大头收完 ≈ 9/22 06:00（乐观）– 9/22 18:00（悲观，全按 REMO 速率）。
- 复用要点：判第二波进度用 `grep -h "\[done\]" <KEY>_part<NN>_r*.log | wc -l`，**每 part 满额 20（两 chunk 各 10）**；进程数应等于在跑 chunk 数（part 数 × 2）。

### 2026-09-21 07:13 — 第六次执行
- 总进度 **809 / 2240**（36.1%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO **170/300**（第二波 parts 10-16 = WFG3-9 在跑，14 片）、HES_EA 1（pilot）；CSEA/PCSAEA/PACDIS 未启动（目录不存在，非异常）。
- 14 个 MATLAB 进程（= 第二波 14 片，满池），MemFree 3.88 GB（> 2000 MB 闸值，未触发）。
- 🟡 **rc=124 修正为 16 条**：第一波 8 个 part（1-6/8/9）× 2 chunk **全部**被 4 h 超时杀（06:10 那次只数到 11 条是写入竞态）。但每片仍落盘 8–9 个 .mat（DTLZ1-6/WFG1 各 18、WFG2 16），非致命；round 3 补 ~20 个缺跑即可。
- REMO 单跑 wall 稳定 1260–1430 s（≈21 min）。稳态吞吐 ≈ 35–40 跑/h。**REMO ETA ≈ 今天 10:45–11:00**；剩余 4 算法（PACDIS/HES_EA/CSEA/PCSAEA）各 300 跑 → 大头收完 **≈ 9/22 晚 – 9/23 凌晨**。
- 其余异常无（poison / tmp.mat / unknown key / [mem] 刹车全无）。
- 复用要点：判"第二波是否会被超时杀"= 起跑时刻 + 10 跑 × 单跑 wall；06:05 起 + 3.6 h ≈ 09:40 < 10:05 超时线，本波安全。

### 2026-09-21 06:10 — 第五次执行
- 总进度 **781 / 2240**（34.9%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO **142/300**（第二波 parts 10-16 = WFG3-9 于 06:04–06:07 已全部起跑）、HES_EA 1（pilot）；CSEA/PCSAEA/PACDIS 目录未创建（未启动，非异常）。
- 14–16 个 MATLAB 进程，MemFree 7.9 GB（比 05:00 的 6.67 GB 更宽裕，因第一波被杀释放）。
- 🟡 **首次发现真实异常：REMO rc=124 共 11 条**（parts 1-6 两 chunk + part8 一 chunk），全部因 4 h 切片超时。已确认非致命并给出 ETA；poison/tmp.mat/unknown key/mem 闸均无。
- 实测吞吐下修到 **≈30–33 跑/h**（05:00→06:10 实测 35 跑/70 min）。REMO ETA **≈ 今天 11:00–11:30**；剩余 4 算法各 ~9 h → 大头收完 **≈ 9/22 23:00 – 9/23 03:00**。

### 2026-09-21 05:00 — 第四次执行
- 总进度 **746 / 2240**（33.3%）：SSDE 320 ✅、SAMOEATL2M 318 ✅、REMO **107/300**（02:05 起跑，第一波 16 片跑完 67%）、HES_EA 1（pilot）；CSEA/PCSAEA/PACDIS 目录未创建（未启动，非异常）。
- 16 个 MATLAB 进程（满池），MemFree 6.67 GB。异常**全部无**（无 poison / rc 31 个全 `|0` / 无 tmp.mat / 无 unknown key / 无 [mem] 刹车）。
- 实测吞吐 **43 跑 / 67 min ≈ 38.5 跑/小时**，与理论 16 并发 ÷ 1500 s 完全吻合 → 以后直接用「38.5 跑/h」外推，不用再算切片。
- REMO wall 稳定 1420–1760 s（≈25 min）；第一波 ~06:30 收，第二波（parts 10-16，14 片）→ **REMO ETA ≈ 今天 10:40**。
- 剩余 4 算法（PACDIS/HES_EA/CSEA/PCSAEA）各 300 跑，若同量级则各 ~8.3 h → 大头全完 **≈ 9/22 20:00 – 9/23 02:00**。
- 复用要点：`rc_*.txt` **在各 `logs/<KEY>/` 子目录下**，不是 logs 根目录（首次巡检误判为"无 rc 文件"）。

### 2026-09-21 03:55 — 第三次执行
- 总进度 **703 / 2240**（31.4%）：SSDE 320 ✅、SAMOEATL2M 318 ✅（本阶段满额）、REMO 64/300、HES_EA 1（pilot）；CSEA/PCSAEA/PACDIS 目录未创建（未启动，非异常）。
- 16 个 MATLAB 进程（满池），MemFree 5.09 GB。异常**全部无**（无 poison / rc 全 0 / 无 tmp.mat / 无 unknown key / 无 [mem] 刹车）。
- 当前算法 REMO（02:06 起跑）。**第一波 = 16 切片 = parts 1-6,8,9（DTLZ1-6 + WFG1-2），每个 part 的两个 chunk 并行**；故一个 part（20 跑）耗时 ≈ 10 跑串行 × ~1580 s ≈ 4.4 h，第一波 06:29 收，第二波（parts 10-16）06:29→10:48。**REMO ETA ≈ 今天 10:45**。
- ⚠️ **排程预警**：REMO 单跑 wall 实测 1525–1755 s（≈26 min），若 PACDIS/HES_EA/CSEA/PCSAEA 同量级，剩余 1200 跑 ≈ 32 h，整体要到 **9/23** 才能收完大头。已向用户明确外推口径。
- 复用要点：本阶段一个算法 = 30 切片（16 part×2 − 跳过 part7），**part 号 = 题号**；吞吐速算 = 16 并发 / 单跑 wall ≈ 每 100 s 出一个 .mat。

### 2026-09-21 02:53 — 第二次执行
- 总进度 **655 / 2240**（29.2%）：SSDE 320/320 ✅、SAMOEATL2M 318/318 ✅（本阶段满额）、REMO 16/300（02:04 起跑）、HES_EA 1（pilot）；CSEA/PCSAEA/PACDIS 目录尚未创建（未启动，非异常）。
- 16 个 MATLAB 进程（= MAXJOBS=16 满池），MemFree 3.46 GB（>MIN_FREE_MB=2000，闸未触发）。
- 异常：**全部无** —— 无 poison.txt、rc 全部 `|0`（无 124）、无 *.tmp.mat、无 unknown key、无 [mem] 刹车。
- 🔴 **关键发现：REMO 单跑 wall ≈ 1387–1628 s（均 ~1520 s ≈ 25 min）**，远高于历史 maxFE=300 时的 ~420 s（约 3.8×）。runtime≈wall，说明是真实求解开销不是指标计算。据此 REMO 300 跑 ≈ 8 h，ETA ≈ 今天 10:00–10:30；PACDIS 同类另需 ~8 h。**原「13–14 h 全跑完」的估算已被击穿，实际约 25–35 h。**
- 写法坑：`[done]` 行**带时间戳前缀** `[YYYY-MM-DD HH:MM:SS] [done] ...`，`grep "^\[done\]"` 会漏匹配，必须用 `grep "\[done\]"`。

### 2026-09-21 01:09 — 首次执行
- 总进度 **494 / 2240**（22.1%）：SSDE 320/320 ✅、SAMOEATL2M 173、HES_EA 1（23:41 pilot，配置一致有效）。
- 当前算法：SAMOEATL2M，第二波 slice 7-12 在跑，最新 slice 12/16 = WFG5。
- 12 个 MATLAB 进程（= MAXJOBS=12），MemFree 6.58 GB。
- 异常：**全部无** —— 无 poison.txt、rc 全 0（无 124）、无 *.tmp.mat、driver.log 无 unknown key。
- 关键发现：SAMOEA 的 DTLZ7 单跑 **wall ≈ 535 s**（runtime 仅 126 s，参考集 2^19 全局轨迹开销）。DTLZ7 两切片各剩 9 跑串行 → **SAMOEA 的真正瓶颈是 DTLZ7，ETA ≈ 02:30**，而非 WFG 波次。
- 写法坑：`bc` 在本机 Git Bash **不存在**（exit 127），脚本里别用。
