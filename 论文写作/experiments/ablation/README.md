# 以 Full 为参照的 IGD+ 消融表

2026-10-13 按用户提供的两份工作簿更新消融表。论文只展示 `Full`、`w/o CDIS`、`w/o PAQC`，不展示 REMO 性能列。两种消融配置及其机制描述沿用此前版本；本次更新数据、统计参照和样本数，不修改 MATLAB 算法。

`build_full_reference.py` 从以下归档工作簿生成 `table_ablation_igdp.tex`，并可同步中文对照稿的表 3。归档为原始文件的逐字节副本，源文件名不用于推断协议；协议以 `IGDp` 和 `核对` 页实际内容为准。

| 归档文件 | M | SHA-256 |
| --- | --- | --- |
| `sources/ablation_full_reference_m10_igdp.xlsx` | 10 | `20cfbae4a67ddde67b5fa5d3e31156e21b8a9498049bba19ac2b3e20c5a6dac2` |
| `sources/ablation_full_reference_m20_igdp.xlsx` | 20 | `db5fa53b0453ce82d0895bce2e997bc34a2ed6dc45ffa01532076ee99c362f3c` |

原始文件位于 `C:\Users\lsx\Desktop\AdaMao实验表\消融实验\nobatchdict版本\`：

- M=10：`nobatchdict以full为基准十目标IGDp_full去后5run其他去最好5run_NoCDISREMOSelection.xlsx`
- M=20：`nobatchdict以full为基准二十目标IGDp_full去后5run其他去最好5run_NoCDISREMOSelection.xlsx`

## 数据与统计口径

- DTLZ1–7、WFG1–9，M=10/20，共 32 个问题–目标数组合；N=100、FE=300，WFG2/3 的 D=31，其余 D=30。FE=300 是工作簿配置口径，本次不重新执行算法或核查实际 FE。
- 每个单元统计 **15 次结果**，括号内为样本标准差。核对页同时保留原始 20 次运行值：Full 使用 run 1–15；两个对照各剔除自身 IGD+ 最低的 5 次，保留其余 15 次。正文和表注明确此取样方式，不将所选样本写成未经筛选的 15 次独立运行。
- 工作簿符号以 Full 为参照：`+` 表示该对照更优、`-` 表示该对照更差、`=` 表示未检测到差异。核对页说明双侧非配对秩和检验、p<0.05；未记录多重比较校正。保留导出符号，不从均值和标准差重建 p 值。
- Full 为参照列，不附符号；汇总为 w/o CDIS `2/19/11`、w/o PAQC `2/21/9`。M=10 分别为 `1/10/5`、`1/10/5`；M=20 分别为 `1/9/6`、`1/11/4`。
- 行内最低显示均值以浅灰标识，中文对照稿使用加粗。Full 在 28/32 行具有最低均值；w/o CDIS 在两个目标数的 DTLZ6 上优于 Full，w/o PAQC 在两个目标数的 WFG3 上优于 Full。各臂取样规则不同，因此结果解释限定于所选样本，不能把差异全部归因于模块。

## 配置身份

- Full：PACDIS，当前 NoBatchDist 配置。
- w/o PAQC：采用 REMO 基于代表解、正组规模可变的 PBI 分类；保留指标模型与准则切换。
- w/o CDIS：沿用 `REMO_NoCDIS_REMOSelection`，保留 PAQC 与 Full 宿主，用本地 REMO 原始关系引导候选模块替换整个 CDIS；批量上限和剩余预算截断沿用 Full。

源工作簿中的 REMO 列仅作为原始归档内容保留，生成表不使用该列参与行内最优值或统计计数。此前 REMO 参照工作簿及旧表资产保留为历史材料，当前论文仅引用 `table_ablation_igdp.tex`。

## 生成与核对

在带有 `openpyxl` 的 Python 环境中运行：

```text
python build_full_reference.py --sync-cn
python build_full_reference.py --check
```

检查覆盖 32 行、96 个结果单元、配置字段、符号参照、汇总计数、每臂 15 个唯一 run ID、取样规则、导出精度下的样本均值/标准差，以及英文表和中文表的一致性。原始桌面工作簿保持不变。
