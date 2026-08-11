# CascadeAudit Pilot 方向性筛查结论（2026-08-06）

> 协议：`Experiments/REMO_new2_AdaMaO_CascadeAudit/`
> 结果：`Experiments/REMO_new2_AdaMaO_CascadeAudit/results/pilot_fullref/`
> 状态：**STOP_INDICATOR_RESCUE_STORY（预注册停止条件触发）**

## 设置

- 6 问题 × M=10 × 2 runs，maxFE=300，gmax=500，D=30，N=100
- auditCheckpoints = [0.20 0.50 0.80]，full-reference 灵敏度开启
- 首轮 256 参考点触发 DTLZ2 run2 灵敏度 FAIL（晚代 oracle-top-K 重合 0）
  → 按计划改用**完整参考集（GetOptimum(10000)）重跑**，全部 12 run 灵敏度 PASS
- 12/12 job 完成，审计耗时每 job 约 0.2–0.5s（单独记录，不计入官方预算）

## 结果

| 指标 | 值 | 含义 |
|---|---|---|
| **H1 覆盖缺口** | **PASS** | MeanNormalizedBatchCoverageRegret=0.253（5/6 问题 >0，DTLZ7 例外=0）；MeanRecall@K=0.444（全部 <0.95，WFG4/6 低至 0.25–0.31） |
| **H2 分歧可识别** | **FAIL** | DTLZ 家族 Real−DiversityMatched = −0.0048（负）；WFG 家族 +0.0235 |
| H4 门控 | FAIL | AUROC=0.62 CI[0.589,0.656]，但 GatedNegativeRate 0.371 > Ungated 0.361；FavorableProblemFraction=0 |
| RealDisagreement | MeanGain = **−0.0015（负）** | 最大正分歧候选的平均固定替换净增益为负 |
| OracleRescue | MeanCapture = 0.917 | 拒绝集中确实存在大量可救援的有用候选（理论上限高） |
| Shuffled/Diversity/Reverse | capture 均 < Real | 但 Real 的绝对收益为负 |

## 解读（方向性，非最终统计证明）

1. **级联盲区故事（H1）成立**：关系 top-30% 粗筛确实系统性丢失 oracle-useful 候选，
   WFG 家族比 DTLZ 更严重；这是可发表的诊断发现（覆盖瓶颈命题的直接证据）。
2. **指标正分歧不能识别这些假阴性（H2 失败）**：DTLZ 家族上 DiversityMatchedRandom
   排他性对照失败——即使"正分歧"略有富集，也**不优于单纯的决策空间多样性**；
   WFG 家族方向为正但不一致（run 间符号翻转）。
3. **救援本身有害**：最大正分歧候选的平均替换净增益为负，说明在固定预算下
   替换基础批次最差指标候选**平均损害** IGD+；OracleRescue 的高上限表明问题
   不在"没有可救候选"，而在"分歧信号抓不住它们"。
4. 按预注册决策链（H1 pass → H2 fail → STOP_INDICATOR_RESCUE_STORY），
   **停止"关系拒绝—指标认可条件救援"这一机制主张**。

## 后续可选方向（需作者决策）

- **A. 放弃救援机制**，将论文贡献收窄为"级联覆盖损失的候选级反事实诊断"
  （H1 证据链完整），救援部分降级为负结果/补充材料。
- **B. 改"安全随机旁路"工程方案**：H1 通过说明粗筛确实漏；若随机旁路
  在无门控、固定单名额下不损害性能，可作为一个务实改进，但**不能**宣称
  指标条件补救（计划明示）。
- **C. 先不启动 screening**：screening（10 runs × M10/20）在 H2 已失败且
  救援收益为负的情况下，主要价值变成量化 H1 覆盖缺口的稳健性与目标数效应；
  若走 A/B 方向，screening 应相应调整（如加入 RandomRescue 对照或改为
  诊断聚焦）。
