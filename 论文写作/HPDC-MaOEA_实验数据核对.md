# HPDC-MaOEA 实验部分数据核对

本次仅修改 `HPDC-MaOEA.tex` 的 Experimental Studies 部分。方法、引言、摘要、结论和参考文献均与本次修改前逐字节一致。已有实验结果未被修改，也未重新运行优化实验。

## 正文与数据对应

主要输入目录：`C:\Users\lsx\Desktop\AdaMao实验表`。

| 论文内容 | 数据来源 | 使用方式 |
|---|---|---|
| 表 1，实验设置 | 总实验及模块消融工作簿的 N/M/D/FE 列；分阶段归档；对应实验协议 | 缺失的运行次数和设置留空；WFG3 按实际记录区分 D=31 或 D=11 |
| 表 2、3，主性能比较 | `最新版算法总实验\10目标.xlsx`、`20目标.xlsx`，IGD 工作表 | 纳入每档全部 16 个问题和该表已有的全部基线，保留均值、标准差及源表符号 |
| 表 4，其他目标数 | `最新版算法总实验` 中 3/5/8/10/12/20 目标工作簿 | 共同基线为 REMO、PIEA、MCEAD、KRVEA；12 目标仅有 WFG1–9，单独标识 |
| 表 5、6，两个模块消融 | `消融实验\两个模块的消融实验\full_10.xlsx`、`full_20.xlsx` | 只采用能够识别的 6 个配置；完整算法均值、标准差已逐行与主性能表比对 |
| 分组成员差异、调度、删点稳定性 | `Stage1_UniformMix_LabelValidation\screening\analysis`、`Stage2_LabelCausalAblation\screening\analysis` | Stage1 100 条轨迹；Stage2 在相同快照上离线比较，各行为分别汇总 50 条轨迹 |
| 表 7，未来保留率 | 仓库 GoodGroupPrecision 原始五问题正式 CSV 及 DualPBI_Complementarity 正式 CSV | 根据论文原占位和桌面规划所引用的原实验补查；未混入新增问题协议 |
| 表 8，候选价值探针 | 仓库 CandidateValueProbe 的 `docs\data\runs.csv`、`generations.csv` 及协议/指标实现 | 200 条已完成记录，4 问题 × 5 臂 × 10 次，均为 M=20、FE=300 |
| 表 9，候选路由 | `消融实验\候选解模块` 下根目录、`二十目标`、`IGDp` 的 `Ada_Mao_SDEonly_UniformMix.xlsx` | 分别为 M10 IGD、M20 IGD、M20 IGD+；与最终 Original 版本分开报告 |
| FE=500 补充比较 | `FE500\候选解模块改动最终版\十目标.xlsx` | 仅作该 UniformMix 版本的同预算比较，不与 Original 版本作预算归因 |

仓库补查目录：

- `D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_GoodGroupPrecision`
- `D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_CandidateValueProbe`
- `D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_UniformMix_LabelValidation`

## 已复算的关键结果

- 主性能：M10 为 73/18/21，M20 为 70/21/21，均是本算法视角的胜/平/负，每档 112 个问题–基线对比。
- 共同基线中位相对 IGD 改进：M10 为 10.49%，M20 为 9.73%；均值分别为 3.37%、−0.17%。未使用旧报告中将不同问题–基线配对混为独立重复的目标数趋势检验。
- M20 模块消融剔除错误目标数的 WFG4 后，完整方法对 REMO、REMO(k=30)、HPC(k=6)、HPC(k=30)、candidate(k=6) 的胜/平/负为 7/6/2、10/4/1、7/4/4、3/11/1、8/4/3。没有照抄源表含 16 行的汇总。
- GoodGroupPrecision：覆盖表为原 5 问题 × 2 个目标数 × 25 次，共 250 次；等配额最终种群保留 precision 为 Hybrid 0.28698、方向 0.27748、margin 0.27617。双向独有未来真阳性通过 33/40，严格同时融合优越性通过 1/40。
- 候选探针：200/200 条记录为 M20、FE=300；V1–V4 的全部 5,280 个非末尾裁剪迭代批量均为 6，末尾批量为 2。
- V4 与 V1 的晚期保留率为 0.77017/0.70600，晚期池内贪心参考增益比为 0.10478/0.08606。最终 IGD 按问题报告，保留 DTLZ7 中 V4 均值高于 V1 的结果。

## 保留的空缺与未纳入项

1. **工作簿运行次数和统计协议不完整。** 未将旧 `ablation_tables.tex` 中明确标注为 assumed 的 30 次运行写成事实。工作簿符号仅按已有结果报告，未由均值和标准差重造 p 值。最终检验方法、阈值和多重比较设置仍需回查运行记录。
2. **M10 DTLZ1 的 PCSAEA 与 KRVEA 均值、标准差相同。** 源值保留，并加 dagger 和 TODO；不凭推测修改。相关计数目前仍是源表报告的计数。
3. **M20 模块消融的 WFG4 行实际标注 M10。** 表内留空，只对其余 15 行计数；没有拿主性能表的 WFG4 代替消融数据。
4. **匿名 `full` 列身份不明。** 未直接认定为 k=6 的完整方法。当前 k 下 candidate-only 对照缺失，因此不把 candidate(k=6) 与 full(k=15/30) 的差异全部归因于分组模块，也不写联合协同结论。
5. **总实验与旧路由实验版本不同。** `UniformMix_Original`、`UniformMix` 的均值不同，正文分开呈现；旧路由数据不充当最终版本的四臂受控消融。
6. **Stage3 和 confidence 数据未通过相应有效性门槛。** Stage3 为 `INSUFFICIENT_REFERENCE_STABILITY`，confidence confirmation 为 `INSUFFICIENT_DATA`。未写作机制效用或概率校准已成立的证据。
7. **其他关系对、连续双 PBI、简化参数旧表** 涉及不同算法变体，未作为当前论文定义的正式受控消融。相应新版缺失项继续留空。
8. **最终版本的参数敏感性、完整预算曲线和模块耗时占比** 尚缺有效数据；正文保留 TODO。原文其他章节中的占位与论断未改动。

## 验证

- 表格由源工作簿/CSV 生成；总数和关键均值重新计算。
- 修改范围检查通过，实验之外内容逐字节不变。
- 完成两次最终 LaTeX 编译，PDF 共 12 页；无未定义引用、重复标签、表格超高或 overfull 提示。
- 实验页已渲染检查，全部实验表格位于结论之前。

本次修改前的 TeX 备份与复算记录保存在同目录 `.experiment_work` 中。
