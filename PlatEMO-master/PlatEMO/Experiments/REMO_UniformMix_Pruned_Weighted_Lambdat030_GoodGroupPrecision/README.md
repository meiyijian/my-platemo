# Lambdat030 GoodGroupPrecision 实验

对 `REMO_UniformMix_Pruned_Weighted_Lambdat030`（λ_t = 0.30）复刻 PWGGP（λ_t = 0.50）的 Good-group Precision 审计协议。选题依据见 `SELECTED_PROBLEMS.md`（结论：DTLZ2 / DTLZ4 / DTLZ5 × M10/M20 × 25 跑 = 150 跑）。

## 文件规划（本目录只放本实验需要的文件）

| 位置 | 内容 |
|---|---|
| `README.md` / `SELECTED_PROBLEMS.md` | 设计与选题文档 |
| `algorithms/LTGGPAudit.m` | 审计类：Lambdat030 生产路径 + 稳定 EvalID/快照/轨迹记录，与生产类轨迹逐位等价（verify_LTGGP 把关） |
| `algorithms/private/`（16 文件） | 冻结的生产 private（11 个）+ `Lambdat030WeightedBatchSelection.m`、`PrunedIndicatorSelection.m`（选择器与指标分支）+ PWGGP 审计版 `LV*`/`PWRepresentativeAudit`（3 个） |
| `LTGGPProtocol/StableSeed/SetupPaths/ResultPath/ValidateRunFile/StageBin/BinaryMetrics/ComputeRunMetrics/ComparePaired/HolmAdjust.m` | 协议与指标框架（LTGGP 前缀，避免与 GGP*/PWGGP* 撞名） |
| `verify_LTGGP.m` | 生产/审计轨迹等价（3 例小预算），通过才写 `equivalence_passed.txt` |
| `run_Lambdat030GoodGroupPrecision.m` | 可续跑主入口（smoke/pilot/formal；formal 限定 ≤3 题） |
| `analyze_Lambdat030GoodGroupPrecision.m` | 聚合成 LTGGP_*.csv（PerRunStage / PairedComparisons / Coverage 等） |
| `compare_LTGGP_vs_PWGGP.m` | λ0.30 vs λ0.50 跨臂种子配对比较（IGD + score_hybrid 精度；确认性口径） |
| `run_LTGGPPartition.m` / `Start-GGP-Lambdat030.ps1` / `finish_LTGGP.m` | 8 分区并行 + 防待机 + 3 次重试 + 收尾全量校验与分析 |
| `equivalence_passed.txt` | 等价门禁产物（verify 写出，run 入口强制检查） |
| `results/raw\|analysis\|manifests\|logs` | 产物目录 |

## 正式协议（formal）

- 算法：Lambdat030，参数 `{gmax,pMix,rGood,qKeep,nMax} = {3000,0.50,0.25,0.70,6}`，λ_t=0.30 写死在 `Lambdat030WeightedBatchSelection.m`。
- 问题：DTLZ2、DTLZ4、DTLZ5（索引 1/2/7，与 PWGGP 相同）；M=10/20；25 跑；N=100、请求 D=30、maxFE=500。
- 种子：`problemIndex*10000 + M*100 + run`，与 PWGGP 完全一致 → DTLZ2/DTLZ4 与 PWGGP formal 严格种子配对。
- 统计口径同 PWGGP：快照（H1/H3/FINAL × 保留/非支配真值 6 种）× 4 视图（score_v / anchor_margin / score_hybrid 定配额 Top25% + label_dyn 原生），run 内按 FE 四阶段先聚合、run 为独立统计单位。

## 入口

```matlab
addpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision');
verify_LTGGP;                                      % 等价门禁（先跑）
run_Lambdat030GoodGroupPrecision('smoke');         % 工程冒烟
analyze_Lambdat030GoodGroupPrecision('smoke');
% 正式（本机 PowerShell 一键，等价验证会自动先跑一轮 smoke 已过即可直接启动）：
%   Start-GGP-Lambdat030.ps1   → 150 跑 + finish_LTGGP 全量校验 + 分析 + FORMAL_COMPLETE.txt
% 跨臂配对（完成后）：
% compare_LTGGP_vs_PWGGP;
```

## 审计类的关键差异（相对 PWGGP）

1. 探索分支走 Lambdat030 的选择器：分位保留后 `A_t = R~ + 0.30*U~` 奖励 + 0.75/0.25 贪心批构造；指标分支不变（`PrunedIndicatorSelection`）。
2. **不初始化** `ADAMAO_LAMBDAT030_DIAG` 全局量：`recordLambdaDiagnostics` 只写记录、不碰随机流，审计侧留空（守卫早退）即可保证轨迹等价，也省去跨跑残留。
3. 其余冻结结构与 PWGGP 审计类逐行一致（PAQC 由 `LVComputeLabelViews` 等价替换、RefSelect 由 `LVRefSelectWithIndex` 等价替换）。

## 不变量（照抄 PWGGP 房规）

- 结果逐跑独立 `.mat`，临时文件 + 写后校验 + 原子改名；有效文件跳过，非法文件报错不覆盖；同身份并发写冲突即报错。
- 分析只在全量校验通过后生成；`results/FORMAL_COMPLETE.txt` 是唯一完成标志，没有它不得宣称完成。
- smoke 仅工程校验，不进正式排名或结论。
- `maxNumCompThreads` 统一为 1（12 分区并行 = 本机已验证的最大进程口径，pMix 扫描同款 ~98% 利用率；全表同线程数，不得混用）。
- 长跑前防待机已内置在 `Start-GGP-Lambdat030.ps1`（monitor/standby AC = 0）；长跑期间勿合盖。

## 状态

- 2026-09-16→17：框架搭建完成、等价验证 **3/3 PASS**（生产/审计最终档案与 RNG 状态逐位一致：WFG3 M2、DTLZ2 M10、DTLZ2 M20），WFG3 M2 冒烟通过。
- **正式 150 跑已完成**（09-17 00:32）：`results/FORMAL_COMPLETE.txt`（150/150 校验通过、6/6 配置齐），分析产物在 `results/analysis/formal/`，跨臂（λ0.30 vs λ0.50）种子配对表在 `results/analysis/crossArm/LTGGP_vs_PWGGP_Paired.csv`。
- ⚠️ **运行环境警告（当晚实测）**：MATLAB R2021b 在 09-16 夜间出现高发 `0xc0000374` 堆损坏（事件日志故障模块 ntdll.dll、固定偏移），每进程约 10–12 分钟必崩，与并发数、沙箱、启动方式均无关，**崩前已完成的跑次落盘有效**。补救路径：`run_LTGGPRemaining.m`（只切缺失 job）+ 循环重启（"磨盘"）直至缺口归零；若机器重启后环境恢复，直接 `Start-GGP-Lambdat030.ps1` 一次跑齐即可。
