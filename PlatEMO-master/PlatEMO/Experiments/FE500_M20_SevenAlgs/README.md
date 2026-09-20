# FE500 / 20 目标 / D=30 —— 七算法全系列扫描

`D:\REMOandDREMO测试集\20目标\FE500\<算法>\` 的跑量与归档说明。
建立在 `PlatEMO/Experiments/REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries/`
这个共享 harness 上（见 `PlatEMO-master/.workbuddy/pipelines/algorithm_full_series/README.md`
的六阶段流程）。

---

## 一、固定口径

| 项 | 值 |
|---|---|
| 问题集 | DTLZ1–DTLZ7 + WFG1–WFG9（16 题，DTLZ 在前） |
| 目标数 M | 20 |
| 决策维 D | 请求 30 ⇒ **WFG2 / WFG3 实际 D=31**，其余 14 题 D=30 |
| 初始规模 N | 100（`PCSAEA` / `HES_EA` / `SAMOEA` 例外，见第三节） |
| 评价预算 maxFE | **500** |
| 快照数 | 30（`SaveCount`）；末快照 = 终止前最后一次存档 ⇒ **末次 FE ≥ 500** |
| 跑数 | runs 1–20 |
| 种子 | `22260912 + 1000*题号 + run`，`rng(seed,'twister')` 在构造 problem **之前** |
| 指标 | `metric.runtime` / `metric.IGD` / `metric.IGDp`，后两者各 30 个快照的**轨迹**，末值才是 final |
| 落盘 | `<算法>_<题>_M20_D<30\|31>_<run>.mat`，含 `result`(≤30×2 cell) + `metric` |
| 输出根 | `D:\REMOandDREMO测试集\20目标\FE500\<算法>\`（数据集目录只放 `.mat`） |
| 日志 | 本目录 `logs/`（`logs/<KEY>/` 为分算法日志，`logs/_*.csv` 为逐切片汇总） |

`22260912 = 20260912 + 20*100000`，与 `20目标` 下既有 FE300 批次**同一套种子**
⇒ FE300 与 FE500 可以**逐跑配对**做 Wilcoxon 符号秩检验。

## 二、七个算法

键名 / 类名 / 参数见 `fe500_m20_registry.m`（唯一真源）。

| KEY | 类名 | 输出目录 | 参数 |
|---|---|---|---|
| REMO | `REMO` | `REMO` | 类默认 `{k,gmax}={6,3000}` |
| PCSAEA | `PCSAEA` | `PCSAEA` | 类默认 `{delta,gmax}={0.8,3000}` |
| CSEA | `CSEA` | `CSEA` | 类默认 `{k,gmax}={6,3000}` |
| HES_EA | `HES_EA` | `HES_EA` | 类默认 `{wmax,WN,KMeans}={20,190,4}` |
| SSDE | `SSDE` | `SSDE` | 类默认 `{num_nodes,eta0,sigma0}={N,0.2,N}` |
| SAMOEA | `SAMOEATL2M` | `SAMOEATL2M` | 类默认 `{G,KE,alpha}={20,5,0.4}` |
| PACDIS | `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist` | 同名 | `{3000,0.50,0.25,0.70,6}` |

**基线一律传空参数 `{}`**（走类的 published 默认）。把本项目的五元组
`{3000,0.50,...}` 传给它们会静默把 `k`/`delta`/`wmax` 等设成 3000，必须避免。

## 三、⚠️ 预算分配不等 —— 报数时必须交代
`PCSAEA` / `HES_EA` / `SAMOEATL2M` 的初始设计是 `NI = 11*D-1 = 329`，
在 maxFE=500 下**吃掉 66% 的预算**，只剩 ~171 次真评估给搜索主循环；
而 `REMO` / `CSEA` / `SSDE` / `PACDIS` 从 100–109 起步，有 ~400 次给搜索。

`verify_FE500_M20.m` 会打印每题的 **FirstFE**（即初始设计规模），
`summary_FE500_M20_<KEY>.csv` 里也有这一列。**直接比末值 IGD 是不公平的**，
论文里要么说明，要么把这 3 个算法单独分组。

> 补充：在旧的 maxFE=300 口径下，`PCSAEA` 的 `329 > 300` ⇒ 主循环一次都不进，
> 存下来的 run 是**纯初始种群**（本机 `20目标\PCSAEA`、`20目标\KRVEA` 就有 480 个
> 这样的文件，只有 1 个快照、FE=329）。FE500 下它们才真正跑起来。

### ⚠️ DTLZ7 单跑 wall 被指标计算主导（约 100 s/跑）
实测 SSDE（算法本身 **1.5 s**）：DTLZ2/DTLZ1/WFG9 的单跑 wall 是 2.5–5 s，
而 **DTLZ7 是 86–130 s**。差别不在算法，在 `metric`：
DTLZ7 的 `GetOptimum` 用的是 `UniformPoint(N, M-1, 'grid')`，
M=20 时给出 **2¹⁹ = 524288 个参考点**（其它题是 `UniformPoint(10000, M-1)` 的 10000 点）。
于是每个快照的 IGD/IGDp 都要算 `524288 × |存档|` 的距离，30 个快照 × 2 个指标 ≈ 100 s。
⇒ 这是"要 IGDp 全轨迹"的必然代价（旧笔记里"DTLZ7/M=20 参考集 524288 点、进池会崩"
就是同一件事）。对 REMO/PACDIS/HES 这种单跑几百秒的算法可以忽略；
对 SSDE 这种秒级算法，DTLZ7 会明显拖尾（20 跑 ≈ 33 min）。
**注意 `metric.runtime` 是不含指标计算的**，看单跑成本要看日志里的 `wall`。

## 四、⚠️ `HES_EA` 可能死循环

`HES_EA`（以及 `HES_EA_N100`、guard 版）共有一段聚类赋值代码。当随机投影出的两个
目标共用同一个极小解时（**DTLZ2、DTLZ4** 就是这样），该解归一化后是零对，
`pdist2(...,'cosine')` 返回 NaN，该行可能拿不到簇标签（`Cluster == 0`）；
随后 `CSS` 被要求选 N 行，却永远选不到未赋值的行，`while` 空转且 FE 不前进。
本项目在 M=20 实测过：约 12% 的 run 会卡死，且会把整个 12 槽进程池堵死。

因此：

- `driver.sh` 带 **`SLICE_TIMEOUT`**（默认 14400 s = 4 h），任何切片超时会被杀掉，
  进程池不会被永久堵住；被杀的切片会在下一轮被重新驱动。
- **投毒（`mark_poison.py`）**：种子固定 ⇒ **卡死的 run 重驱必定再卡**，一个卡死 run
  会在一轮轮重驱里反复烧满 `SLICE_TIMEOUT`，扫描永不收敛。所以同一片被 `timeout` 杀
  （退出码 124）**≥ `MAX_SLICE_FAILS`（默认 2）次**后，把该切片 run 列表里
  **第一个磁盘上没有 `.mat` 的 run**（切片按序执行且完成的 run 都原子落盘，所以第一个
  缺的就是卡死的那个，其后只是没轮到）写进 `logs/<KEY>/poison.txt`，以后不再重驱。
  要求"2 次"是为了不把**只是慢**的 run 误判成卡死；被跳过的缺口验收脚本会报成 MISSING。
- 逃生口：`ALGS="HES_EA" FE500_CLS_HES_EA=HES_EA_N100_guard bash driver.sh`
  切到「原版 + 唯一的孤儿簇兜底」的 guard 副本（它也是本项目**唯一**跑完过
  M=20 全系列的版本）。用了哪个版本**必须在论文里写明**。

## 五、怎么跑

```bash
cd PlatEMO/Experiments/FE500_M20_SevenAlgs

# 0) 阶段 1：路径体检（跑任何东西之前先做）
matlab -batch "addpath('<本目录>'); probe_FE500_M20"

# 1) 阶段 2：小规模预热 + 测速（16 题 × 2 跑，同时是真实的 run 19/20 数据）
ALGS="SSDE SAMOEA CSEA PCSAEA REMO PACDIS" RUNS=19,20 ROUNDS=1 SKIP_VERIFY=1 bash driver.sh

# 2) 阶段 3：全量（幂等，已存在的 .mat 自动跳过；只补缺口）
ALGS="SSDE SAMOEA CSEA PCSAEA REMO HES_EA PACDIS" bash driver.sh

# 3) 阶段 4：验收
matlab -batch "addpath('<本目录>'); verify_FE500_M20"
```

常用环境变量：`ALGS` / `RUNS` / `CHUNK` / `MAXJOBS` / `ROUNDS` / `SLICE_TIMEOUT` /
`MAX_SLICE_FAILS` / `LAUNCH_GAP` / `COLD_STARTS` / `LAUNCH_GAP_WARM` / `MIN_FREE_MB` /
`SKIP_VERIFY` / `MP` / `PY` / `FE500_M20_OUTPUT_ROOT` / `FE500_CLS_<KEY>`。

### 并发与启动节流（都是实测调出来的，别随便改）
- **`MAXJOBS` 默认 12**。本机 16 逻辑核 / 31.3 GB 内存，但 OS+应用已占约 16 GB、
  **基线空闲仅 ~16.5 GB**；12 路是这台机器一直在用的值（CPU ≈98% 利用率、内存有余量）。
  14 路虽然能把 CPU 再压一点，但只剩 ~2 GB，REMO/PACDIS/HES 这类
  patternnet/dacefit 算法（单 worker 0.6–1.2 GB）有换页风险。
- **`LAUNCH_GAP=20` 只用在每轮的前 `COLD_STARTS=4` 次启动，之后用 `LAUNCH_GAP_WARM=5`**。
  本机多进程**同时冷启动**会触发 ntdll 堆损坏，所以启动必须错峰；但危险的是冷启动而不是稳态。
  早期版本用一个固定 `sleep 20`，结果**切片比 20 s 短的算法（SSDE 一片约 25 s）被卡到
  只有 2–3 路在跑、CPU 仅 12%**。改成冷/热分段后启动间隔 22 s → ~8 s。
- **`MIN_FREE_MB` 默认 0 = 内存闸关闭**（12 路不需要）。它的历史作用是在
  `MAXJOBS=14` 那种紧配置下，每次启动前查空闲内存、不够就等一个切片结束，
  让池子自动缩容。若哪天想开更多 worker，把它设成正数（如 3000）即可。

进度看 `logs/driver.log` 与 `logs/<KEY>/p<NN>_a<N>.log`
（行格式 `[done] <题> run k | IGD a -> b | runtime Xs | wall Ys | ok`）。
长跑前记得关掉显示器休眠（driver 里已 `powercfg` 设过了），否则本机
S0 Modern Standby 会让墙钟冻结。

## 六、本实验对共享 harness 的唯一改动

`run_UniformMixPrunedFullSeries.m` 新增 `FESlack`（默认 0 = 旧行为逐字不变）。
原因：`REMO` / `CSEA` / `SSDE` 等按批评估的算法末次 FE 会**超过** maxFE
（实测 REMO 301–305、CSEA 301、SSDE 最多 336、D=31 的 `11D-1` 型为 340）。
旧的严格判等 `feList(end) == maxFE` 会把这些文件一律判为无效，导致
可重驱的 driver **每一轮都重算**、永不收敛。新判据：
`maxFE <= 末次 FE <= maxFE + FESlack`（本实验取 100）。
