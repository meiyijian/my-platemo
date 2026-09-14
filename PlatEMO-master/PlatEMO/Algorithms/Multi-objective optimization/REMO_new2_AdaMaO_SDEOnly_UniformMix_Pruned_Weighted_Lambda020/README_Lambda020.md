# Lambda020：质量筛选后的时间衰减奖励变体

独立于 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted`（下称 pruned_weight）的新变体。
**不改动 pruned_weight 的任何源码或参数，不覆盖任何既有结果。**

## 1. 一句话定位

在 pruned_weight 的**质量预筛选之后**、**批次构造之前**，对通过筛选的候选加入一项随时间衰减的预测模糊度奖励：

```
A_t(x) = R~(x) + lambda0 * (1 - FE/FE_max) * U~(x),   lambda0 = 0.20
U(x)   = 1 - mean( max(类别概率) )        % 与 Original 完全一致的定义
```

这是"质量筛选后加奖励"的新组合，**不是**恢复完整原版：`p_err` 门控、`nMin` 补足、指标二次筛选都没有恢复。

## 2. 与两个既有版本的差异

| 环节 | Original | pruned_weight | **Lambda020（本变体）** |
|---|---|---|---|
| 候选生成（关系引导 GA + gmax=3000 累积） | 同 | 同 | 同（未改） |
| PAQC 分组（rGood=0.25, theta=5, k_eff） | 同 | 同 | 同（未改） |
| 探索分支筛选 | 对 `A_exp` 取 q_keep 分位点 | **对 `R` 取 qKeep=0.70 分位点** | **对 `R` 取 qKeep=0.70 分位点（不变）** |
| 奖励项 | `lambda0*(1-ratio)*max(0,1-p_err/0.45)`，lambda0=0.35 | 无 | `0.20*(1-ratio)`，**无 p_err 门控** |
| 奖励作用范围 | 全候选池归一化后参与筛选 | — | **仅在保留集合内**归一化后参与批次构造 |
| 批次首位 | `A_exp` 最大者 | `R` 最大者 | **`A_t` 最大者** |
| 贪心项 | `0.75*A~ + 0.25*d~` | `0.75*R~ + 0.25*d~` | **`0.75*A_t~ + 0.25*d~`**，每步对剩余候选重新归一化 |
| 最少补足 nMin | 4 | 无 | **无（不恢复）** |
| 批次上限 | n_max=6 | nMax=6 | nMax=6（不变） |
| 指标准则分支 | 指标二次筛选 | 前 30% 关系候选 + SVR 直接排序 | 同（未改） |
| pMix | 0.50 | 0.50 | 0.50（不变） |

代码级等价保证：`lambda0 = 0` 时 `A_t` 是 `R` 的单调递增仿射像，而 min-max 归一化对仿射变换不变，
因此批次与 pruned_weight **逐位相同**（第 4 节给出实测证据）。

## 3. 文件清单

| 文件 | 说明 |
|---|---|
| `REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020.m` | 主类。新增第 6 个参数 `lambda0`（默认 0.20），初始化全局诊断收集器（只记数、不取随机数） |
| `LambdaWeightedBatchSelection.m` | **新批次选择器**：R 分位筛选 → 保留集内归一化 R/U → `A_t` → 首位取 argmax `A_t` → `0.75*A_t~+0.25*d~` 贪心；内部同时计算"关闭奖励"的批次用于对比 |
| `private/DiversifiedInfillSelection.m` | 自 pruned_weight 复制；`model_select` 增补 `uncertainty` 第三输出（照抄 Original 的 `1-mean(max(pi))`）；探索分支改调新选择器并记录诊断 |
| `PrunedIndicatorSelection.m`、`PrunedWeightedBatchSelection.m`、`ResolveUniformMixMode.m` | 自 pruned_weight **逐字节复制**，未改动 |
| `private/` 其余 10 个文件 | 自 pruned_weight **逐字节复制**，未改动 |
| `RunLambda020_10.m` | 双臂运行脚本：`check` / `verify0` / `run`；含源文件 SHA-256 清单、逐跑校验、原子写入、断点续跑 |
| `analyze_lambda020.m` | 配对统计与报告生成（精确符号检验 + 精确 Wilcoxon，不依赖统计工具箱） |
| `tests/Lambda020Test.m` | 单元测试：静态检查、`lambda0=0` 等价性（120 组随机用例）、重名遮蔽审计、拷贝一致性证据 |
| `diagnostics/lambda020_10runs/` | 全部验证证据与分析产物（见第 6 节） |

## 4. 验证阶梯（已完成部分）

### 4.1 选择器级等价（`tests/Lambda020Test.log`）
120 组随机候选（含大量并列、退化分数区间、批次大于保留集）：
- `LambdaWeightedBatchSelection(...,lambda0=0,...)` 与 `PrunedWeightedBatchSelection(...)` **0 处不一致**；
- 同一批用例中 `lambda0=0.20` 有 **59/120 组改变了批次** → 奖励确实在起作用。

### 4.2 整跑级等价（`diagnostics/lambda020_10runs/verify0_context/`）
同一个种子（21262931）、同一个问题（DTLZ2 M10 D30）、同一份源码，四跑对照：

| 运行 | 上下文 | IGD |
|---|---|---|
| J1 baseline | client，6 计算线程 | 1.0823481784157407 |
| J2 baseline | process worker，1 线程 | 1.123668809672717 |
| J4 baseline（重复） | process worker，1 线程 | 1.123668809672717 |
| **J3 Lambda020，lambda0=0** | process worker，1 线程 | **1.123668809672717** |

**结论：同上下文下 `lambda0=0` 与基线逐位相同（J2=J3=J4），等价性成立。**

### 4.3 执行上下文敏感性（重要）
同一份源码、同一个种子在不同上下文给出**不同**轨迹（见上表 J1 vs J2）。
补充实验 `verify_context2/` 显示 2-worker 池与 3-worker 池同为 1 线程、结果一致（1.123668809672717），
说明决定因素是**计算线程数**而非池大小。

而论文数据集里存盘的对照（DTLZ2 run 19，创建于 2026-09-13 00:14，当时的 2-worker 会话）
为 **1.2768012367242776**，在今天的 client、2-worker、3-worker 三种上下文中**都无法复现**。
已排除源码漂移：`source_hash_check.txt` 显示 5 份历史 `sources_*.mat` 清单与当前 pruned_weight
源码**逐一匹配**（每份 15 个文件，0 处不一致）；`rngBeforeSolve` 也与对照完全一致。

**因此本变体的实验改为"同会话、同进程池、同种子的双臂配对"**，而不是与存盘结果配对。

## 5. 运行方式

```matlab
addpath(genpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO'));
addpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020');
RunLambda020_10('check');      % 只清点，不跑
RunLambda020_10('run',4);      % 80 次双臂运行；内存紧张时把并发降到 3~4
analyze_lambda020;             % 生成配对比较报告
```

也可直接双击 `StartLambda020_10.cmd`（内含验证 + 正式跑两步）。
**并发建议**：本机 12 逻辑核 / 31.7 GB，6 个 worker 同时训练关系网络会出现内存不足；
在本机同时还有交互式 MATLAB 占用内存时，用 `'run',4` 更稳；
主跑期间不要并发再开别的 MATLAB 进程池（会叠加内存压力，实测触发过内存不足）。
**断点续跑**：`RunLambda020_10('run',W)` 只补缺失的 job；2026-09-14 18:28 的状态为
「80 计划 / 6 已存在 / 74 待跑」。产物统一落在数据集内的算法文件夹（见第 6 节）。
**Original（原始参数版本）不重跑**：直接使用 `..\REMO_new2_AdaMaO_SDEOnly_UniformMix_Original\`
中 DTLZ2/4/5/7 的 M10 D30 现成 18 次结果；因种子批次不同，与它只能做非配对（秩和）比较。

## 6. 实验规格与落盘

- 问题：DTLZ2、DTLZ4、DTLZ5、DTLZ7；M=10、D=30、N=100、maxFE=300；每题 10 次、两臂共 80 跑。
- 运行编号 **19–28**，种子 `20260912 + M*1e5 + pi*1e3 + runId`（pi：DTLZ2=2、DTLZ4=4、DTLZ5=5、DTLZ7=7），**两臂完全一致**。
- 结果落盘（2026-09-14 18:28 起**全部产物统一放在数据集内的算法文件夹**，见该目录 `_README_实验产物说明.md`）：
  - Lambda020 臂：`C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020\<alg>_<prob>_M10_D30_<run>.mat`
  - baseline 臂（同会话重跑）：同目录 `control_in_session\`（**不覆盖任何既有文件**）
  - 日志、记录、验证证据：同目录 `diagnostics\`（`cfg.logs` 已指向此处）
- 诊断目录内容：
  - `sources_*.json` 两臂源文件 SHA-256 清单，逐跑校验
  - `records/<alg>_<prob>_run<NN>_records.csv` 每轮记录：FE、候选数、保留数、目标批次、`lambdaT`、平均奖励、首位是否改变、集合是否改变、重叠率、平均秩位移
  - `verify0_context/`、`verify_context2/`、`first_snapshot_check.txt`、`source_hash_check.txt`、`control_metadata_check.txt` 验证证据
  - `analysis/` 配对统计报告、`runs.csv`、`problem_summary.csv`、`problem_summary_vs_stored.csv`、`analysis.json`
- 源码目录 `diagnostics/lambda020_10runs/` 保留：验证脚本（`.m`）+ 搬迁前的一份历史副本（本环境删除机制被安全策略拦下，无法由脚本清理；已哈希校验与数据集内副本一致，可手动删除）。
- 续跑不会重复已完成的工作：`RunLambda020_10('check')` 应报「80 计划 / 6 已存在 / 74 待跑」。

## 7. 诊断口径

- **有效奖励权重**：`lambdaT = 0.20*(1-FE/300)`，逐轮记录，报告按 FE 四分段汇总。
- **奖励导致的选点变化**：选择器内部用同一套贪心逻辑再算一次"关闭奖励"（`A_t = R`）的批次，
  逐轮比较首位/集合是否改变、重叠率与平均秩位移 → 不需要额外对照组即可回答"奖励是否真的改变了选点"。
- **最终 IGD**：与同会话同种子对照做配对差值；符号检验与精确 Wilcoxon 均不依赖统计工具箱。

## 8. 结果

见 `diagnostics/lambda020_10runs/analysis/Lambda020_M10_10runs_分析报告.md`。
