# RMEO_k_CDIS

原版 REMO 关系学习框架 + `REMO_UniformMix_Pruned_Weighted_Lambdat030` 的 CDIS 候选选择模块；参考解数量随目标数缩放，不再固定为论文的 6。

## 组成来源

| 部分 | 来源 | 处理 |
|---|---|---|
| 初始化（LHS + 真实评价）、`RefSelect`、`GetOutput_PBI` 分类、关系对构造、关系网络训练、环境选择 | `Algorithms/Multi-objective optimization/REMO` | 逐行照搬 |
| `ResolveUniformMixMode`、`DiversifiedInfillSelection`、`Lambdat030WeightedBatchSelection`、`PrunedIndicatorSelection`、`IndicatorSelectorSDEOnly` 及其依赖 | `REMO_UniformMix_Pruned_Weighted_Lambdat030` | **按字节复制**，未改一个字符（奖励权重固定 0.30） |

## 与 REMO 的差异（只有两处）

1. **参考解数量**：`k = min(Problem.N, max(6, ceil(1.5*Problem.M)))`，M=10 → 15，M=20 → 30；原版固定 `k = 6`。
2. **候选选择**：`RSurrogateAssistedSelection` 整体换成 CDIS 模块（每轮 `ResolveUniformMixMode` 抽一种完整准则：探索用 `Lambdat030WeightedBatchSelection`，指标用 `PrunedIndicatorSelection`）。

## 与 Lambdat030 的差异

不使用 PAQC。正组直接由参考解 PBI 二值分类（REMO 的 `GetOutput_PBI`）给出，**不受 25% 配额约束**，`k` 也不经 PAQC 决定。CDIS 内部行为（奖励权重 0.30、0.70 分位筛选、0.75/0.25 贪心、指标分支、批次上限）与 Lambdat030 完全一致。

主循环尾部保留了 Lambdat030 的两条保护（空候选由 GA 补齐、按剩余 FE 截断），因此真实评价严格停在预算上限，不像原版 REMO 会超支。

## 参数

`{gmax, pMix, qKeep, nMax} = {3000, 0.50, 0.70, 6}`。

`rGood` / `nMin` / `lambda0` 在本版本中**不再使用**：没有 PAQC 配额，也没有最低批量补齐；奖励权重写在 `Lambdat030WeightedBatchSelection` 里，不是入参。

## 重名隔离

顶层只有入口类 `RMEO_k_CDIS.m`；**13 个内部函数全部在 `private/`**（含 `ResolveUniformMixMode` 这种在多个目录存在 3 个不同版本的高危名字）。新目录在全局路径上的重名 `.m` = 0。

已用探针实测（在算法目录内放临时函数，用 `functions(@Name)` 取解析路径）：13 个内部函数**全部**解析到本目录 `private/`，private 优先级确认生效。

## 验证

`SmokeTestRMEOkCdis`（`.workbuddy/run_scripts/`）三项通过：

| 问题 | M | D | maxFE | run | 解析 k | 实际 FE | IGD |
|---|---|---|---|---|---|---|---|
| DTLZ2 | 10 | 30 | 130 | 1 | 15 | 130 | 1.55211 |
| DTLZ7 | 10 | 30 | 130 | 2 | 15 | 130 | 24.0287 |
| DTLZ2 | 20 | 30 | 140 | 3 | 30 | 140 | 1.28596 |

预算严格相等、IGD 有限。冒烟预算（130/140）远小于正式 300，`t=FE/maxFE` 不同，**结果不得当作正式数据**。

## 实验批次（2026-09-16 全部完成）

三批共 **576 跑，0 失败**，覆盖 **16 题全系列 × M=10/20 × 18 次**：D=30（WFG2/WFG3 实际 31）、N=100、maxFE=300、save=30。

| 批次 | 题目 | 跑量 | 说明 |
|---|---|---|---|
| 1 | DTLZ1/2/5/7、WFG1/3/6/8 | 288 | 5 workers，323.9 min，17:18:47→22:42:54 |
| 2a | DTLZ3/4/6、WFG2（WFG2 未完） | 60 | 6 workers，74.2 min，后被用户暂停 |
| 2b | 续跑剩余 | 228 | 5 workers，254.5 min，01:15→05:30 |

- 落位：`REMOandDREMO测试集\10目标\n30\RMEO_k_CDIS\`（各 288）、`\20目标\RMEO_k_CDIS\`（各 288），**只有 .mat**。
- 种子：`20260912 + M*1e5 + 题号*1000 + runId`（题号按 16 题规范序 1–16）；`Algorithm.run=1`（modeRunId=1）。
- runner：`.workbuddy/run_scripts/RunRMEOkCdis.m`（批次 1）与 `RunRMEOkCdisRest.m`（批次 2），均可断点续跑、拒覆盖。
- 独立完整性核验：**576 文件、0 异常**（algorithm 名 / M / actualFE=300 / k=15 或 30 / 末次快照 FE=300 / IGD 有限）。

### 性能注意

6 workers **不比 5 快**：同协议下 5 workers 单跑均值 321.9 s（M=10），6 workers 421.1 s，
吞吐 64.4 s/跑 vs 70.2 s/跑 ⇒ 6 workers 反而慢约 9%。默认用 5。

## 未做

未做参数敏感性、未跑第二组种子、未补 PAQC 臂或旧选择模块的 k=1.5M 臂（见项目备忘的待建清单）。
