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

## 四、⚠️ `HES_EA` 可能死循环

`HES_EA`（以及 `HES_EA_N100`、guard 版）共有一段聚类赋值代码。当随机投影出的两个
目标共用同一个极小解时（**DTLZ2、DTLZ4** 就是这样），该解归一化后是零对，
`pdist2(...,'cosine')` 返回 NaN，该行可能拿不到簇标签（`Cluster == 0`）；
随后 `CSS` 被要求选 N 行，却永远选不到未赋值的行，`while` 空转且 FE 不前进。
本项目在 M=20 实测过：约 12% 的 run 会卡死，且会把整个 12 槽进程池堵死。

因此：

- `driver.sh` 带 **`SLICE_TIMEOUT`**（默认 10800 s），任何切片超时会被杀掉，
  进程池不会被永久堵住；被杀的切片会在下一轮被重新驱动。
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
`SKIP_VERIFY` / `MP` / `PY` / `FE500_M20_OUTPUT_ROOT` / `FE500_CLS_<KEY>`。

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
