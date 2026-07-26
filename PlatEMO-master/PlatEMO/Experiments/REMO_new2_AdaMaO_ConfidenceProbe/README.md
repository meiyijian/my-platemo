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

| Profile | 问题 | M | D | N | FE | Runs |
|---|---|---:|---:|---:|---:|---:|
| `smoke` | DTLZ2 | 3 | 3 | 20 | 36 | 1 |
| `pilot` | DTLZ2, DTLZ7, WFG3 | 10 | 30 | 100 | 500 | 3 |
| `screening` | DTLZ2, DTLZ4, DTLZ7, WFG3, WFG7 | 10 | 30 | 100 | 500 | 10 |
| `confirmation` | 同 screening | 20 | 30 | 100 | 500 | 10 |

WFG3 的请求维度是 30，按问题约束实际使用 `D=31`。种子由
`Problem/M/Run` 唯一确定；pilot 与 screening 的重合任务使用同一个种子。

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
