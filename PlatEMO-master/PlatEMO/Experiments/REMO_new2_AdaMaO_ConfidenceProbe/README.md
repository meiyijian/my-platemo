# AdaMaO Confidence 判别能力实验（方案 A）

本实验只回答一个问题：`HybridPBI_Classification` 的
`PBIConfidence` 越高时，原始软硬 PBI 对真实目标关系的判定是否更可靠。
它不比较关系对模式，也不把关系网络的 `NetworkConfidence` 当作 PBI
confidence 的证据。

主判据只使用 `PairType=3`（Catalog-good 对 Catalog-rest）的 PBI
关系对：

1. 高置信度 Q5 相对低置信度 Q1 的严格 Pareto 方向错误率是否下降；
2. confidence 区分“预测正确/错误”的 AUROC 是否高于 0.5；
3. 上述方向是否至少在 5 个问题中的 4 个成立。

网络关系对、候选真实改进和解的后续存活会单独输出为辅助诊断，不会并入
PBI 主判据。Pareto 不可比关系（真值为 0）不进入正确率或错误率分母。

## 实验矩阵

| Profile | 问题 | M | D | N | Initial FE | FE | Runs |
|---|---|---:|---:|---:|---:|---:|---:|
| `smoke` | DTLZ2 | 3 | 3 | 20 | 32 | 36 | 1 |
| `pilot` | DTLZ2, DTLZ7, WFG3 | 10 | 30 | 100 | 100 | 500 | 3 |
| `screening` | DTLZ2, DTLZ4, DTLZ7, WFG3, WFG7 | 10 | 30 | 100 | 100 | 500 | 10 |
| `confirmation` | 同 screening | 20 | 30 | 100 | 100 | 500 | 10 |

WFG3 的请求维度是 30，按问题约束实际使用 `D=31`。种子由
`Problem/M/Run` 唯一确定；pilot 与 screening 的重合任务使用同一个种子。
`smoke` 的 PlatEMO `N=20`，但原 UniformMix 初始化规则在 `D=3` 时真实
评估 `11D-1=32` 个初始解；因此协议与 metadata 中的 `initialFE` 是 32，
不能由 `Problem.N` 误写成 20。

## 运行命令

以下命令假设 PlatEMO 位于
`D:\PlatEMO-master\PlatEMO-master\PlatEMO`，结果写到
`D:\AdaMaO_ConfidenceProbe_Results`。PowerShell 中逐条执行即可。

先运行只做语法和链路检查的 smoke：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); run_ConfidenceProbe_experiment('smoke','D:/AdaMaO_ConfidenceProbe_Results');"
```

小规模 pilot：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); run_ConfidenceProbe_experiment('pilot','D:/AdaMaO_ConfidenceProbe_Results');"
```

正式的 M=10 screening：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); run_ConfidenceProbe_experiment('screening','D:/AdaMaO_ConfidenceProbe_Results');"
```

screening 完成后生成统计表：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); analyze_ConfidenceProbe('D:/AdaMaO_ConfidenceProbe_Results/screening');"
```

只有 `Confidence_decision.csv` 中 M=10 的主门槛通过后，再运行 M=20
confirmation：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); run_ConfidenceProbe_experiment('confirmation','D:/AdaMaO_ConfidenceProbe_Results');"
```

confirmation 分析：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); analyze_ConfidenceProbe('D:/AdaMaO_ConfidenceProbe_Results/confirmation');"
```

## 中断后续跑

重新执行同一个 profile 的原命令即可。runner 会逐个校验已有
`run_XXX.mat`：

- 完整且与当前 job 匹配：`SKIP`；
- 已存在但不完整、损坏或元数据不匹配：`BLOCK`，不会覆盖；
- 不存在：正常运行并通过同目录临时 MAT 原子写入。

例如续跑 screening：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); run_ConfidenceProbe_experiment('screening','D:/AdaMaO_ConfidenceProbe_Results');"
```

若出现 `BLOCK`，请保留原文件用于排查，确认无用后手工移动到备份目录，再重跑；
脚本不会擅自覆盖它。

## 输出文件

每个 run 保存：

- `metadata`
- `confidenceProbe`
- `finalPopulation`
- `IGD`
- `IGDp`
- `runtime`

分析脚本生成且只生成以下七张 CSV：

- `Confidence_PBI_pair_bins.csv`
- `Confidence_PBI_solution_bins.csv`
- `Confidence_network_pair_bins.csv`
- `Confidence_candidate_bins.csv`
- `Confidence_summary_by_problem.csv`
- `Confidence_summary_by_M.csv`
- `Confidence_decision.csv`

同时保存 `Confidence_analysis.mat`。分箱在每个 run 内按预先规定的
generation/类型层进行稳定五等频划分；先得到 run 级统计，再汇总到问题级。
跨问题结果对问题等权，并采用“问题 -> 问题内 run”的分层 Bootstrap；
M=10 与 M=20 始终分开。

分析前会按 `metadata.profile` 重建冻结的 protocol，并对每个 MAT 调用与
续跑相同的完整 validator。混合 profile、重复 job、找不到唯一 job、未完成
FE、EvalID 不连续、非法概率或终局字段都会带文件名终止，不能进入主门槛。
validator 还会逐代核对四张表的 Generation/FE 覆盖、候选评价 ID、完整的
candidate×anchor 网络矩形、网络聚合 confidence、可由真实目标重建的 PBI
关系对、跨表 H1/H3/FinalND，以及最终档案的真实非支配前沿。H3 严格复现
运行时更新语义：仅当同一结果中存在 `Generation+2` 的审计代时，该代 H3
必须为 0/1；否则必须保留为右删失 NaN。因此 Generation 编号跳跃时，不能
用“最后两次审计代”代替这个判定。
`summary_by_problem` 和 `summary_by_M` 会同时报告：

- PBI-Pareto 主判据的联合有效 run 数、Q5-Q1、AUROC 与区间；
- PBI-SDE 和 network Pareto/SDE 的方向错误差、AUROC 与区间；
- candidate 的真实 IGD 改进、H1/H3、下一档案前沿和最终前沿；
- Catalog-good/rest 解各自的 H1/H3/最终前沿差值与区间。

后三类始终是辅助诊断，不参与 PBI-Pareto 的冻结主门槛。如果任一预期 run
缺失，或者同一 run 的 Q1、Q5、差值、AUROC 不能同时计算，
`PrimaryDataComplete=false`。因此 screening 必须具有完整的
`5 problems × 10 runs = 50` 个联合有效 run，才允许进入主门槛判断。

判断代码含义：

- `INSUFFICIENT_PROBLEMS`：不足 5 个问题，不下结论；
- `INSUFFICIENT_DATA`：预期 run 缺失或主判据联合有效数据不完整；
- `NO_DISCRIMINATIVE_EVIDENCE`：冻结的主门槛未通过；
- `WEAK_DISCRIMINATIVE_INFORMATION`：主门槛通过，但绝对错误率下降不足 5 个百分点；
- `GATE_DEVELOPMENT_VALUE`：主门槛通过，且绝对错误率下降至少 5 个百分点。

完成 screening 后，把上述七张 CSV（优先全部发送）交给 Codex，即可继续做
方向一致性、置信区间、异常问题和是否值得开发门控的分析。

## 方案 B：SDE 主判据复跑（v2 冻结协议）

方案 A 的 M=10/M=20 结果均为 `INSUFFICIENT_DATA`：严格 Pareto 可比的
PairType=3 关系对在高维下几乎不存在（WFG3/WFG7 全部 run 为 0 对）。
v2 协议把主判据真值换成按构造可测的 SDE 一致性，并使用全新种子，
使其成为真正的验证性实验而不是对已看过数据的事后分析。

冻结内容：

1. **主真值 = SDE 一致性**（`SDERelation`）。仍只用 PairType=3 关系对，
   分箱、门槛结构（Q5−Q1 差值 CI 上界 <0、AUROC CI 下界 >0.5、
   ≥4/5 问题方向为负、≥5pp 判 `GATE_DEVELOPMENT_VALUE`）与方案 A
   完全一致，只有真值列不同。
2. **辅助真值**：严格 Pareto（与方案 A 衔接）和 ε-支配。ε-支配在每个
   run 的全部已评估目标上做 min-max 归一化后取加性
   ε ∈ {0.05, 0.10}；互相 ε-支配或互不 ε-支配都记 0 并排除出分母。
   ε 真值由 `finalPopulation` 重建的 EvalID 有序目标矩阵计算。
3. **全新种子**：`_sde` profile 的种子在原公式上加 50
   （run 1–10 映射到种子尾数 51–60），与方案 A 的任何 run 都不重合。
4. 问题矩阵、FE 预算、run 数与方案 A 的同名档位完全相同：
   `smoke_sde`、`screening_sde`（M=10）、`confirmation_sde`（M=20）。
   仍要求 `screening_sde` 主门槛通过后再跑 `confirmation_sde`。

运行命令（先 smoke 验链路，再正式 screening）：

```powershell
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); run_ConfidenceProbe_experiment('smoke_sde','D:/AdaMaO_ConfidenceProbe_Results');"
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); run_ConfidenceProbe_experiment('screening_sde','D:/AdaMaO_ConfidenceProbe_Results');"
& 'D:\software\mathlab\bin\matlab.exe' -batch "cd('D:/PlatEMO-master/PlatEMO-master/PlatEMO'); addpath(genpath(pwd)); analyze_ConfidenceProbe_SDE('D:/AdaMaO_ConfidenceProbe_Results/screening_sde');"
```

中断续跑与方案 A 相同：重复执行同一条 run 命令即可（SKIP/BLOCK 语义
不变）。runner 与 validator 复用方案 A 的实现，未做任何修改。

`analyze_ConfidenceProbe_SDE` 只接受 `_sde` profile，生成且只生成：

- `ConfidenceSDE_PBI_pair_bins.csv`（含 SDE/Pareto/ε 两档的分箱错误率）
- `ConfidenceSDE_PBI_solution_bins.csv`
- `ConfidenceSDE_network_pair_bins.csv`
- `ConfidenceSDE_candidate_bins.csv`
- `ConfidenceSDE_summary_by_problem.csv`
- `ConfidenceSDE_summary_by_M.csv`
- `ConfidenceSDE_decision.csv`

以及 `ConfidenceSDE_analysis.mat`。summary 中主判据列
（Q1/Q5/Q5MinusQ1/AUROC/ComparablePairN）均基于 SDE 真值；
`PBIPareto*`、`Eps005*`、`Eps010*` 为辅助诊断列，不参与主门槛。
方案 A 的 `analyze_ConfidenceProbe` 与旧 CSV 命名保持原样，两套结果
不会互相覆盖。
