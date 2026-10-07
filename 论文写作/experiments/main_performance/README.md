# Weighted 主性能数据与复现

## 2026-10-07 当前口径（覆盖下方历史记录）

- 用户明确确认最终主表每格为20次，并要求暂按完整数据口径写入，不因本机原始归档缺口补跑。正文按该确认报告20次独立运行；这不是本次逐文件证实了全部原始运行。
- 已从桌面 `nobatchdict版本` 三份最新工作簿刷新336格快照、源哈希、两张主表和汇总。M=15 REMO有14格更新，其中DTLZ5符号从 `=` 变为 `-`，DTLZ4最低均值转为REMO。PACDIS最低均值数为7/4/4，共15格；REMO在M=15的 `+/-/=` 为2/10/4。
- 本机FE500目录中，M=10/15各算法各题均有run 1–20。M=20仅DTLZ7四个基线目录缺9个文件：REMO缺15/20，PCSAEA和HES_EA缺18/19/20，CSEA缺20。该缺口属于原始归档覆盖记录，不据此改写作者确认的最终主表口径，也未补造结果或重新计算源表p值。
- 旧导出脚本在样本不足时截取较短长度；在双方均20次时不会截掉样本。此次保留最新工作簿符号，未修改实验或统计导出脚本。多重比较政策仍待明确。
- 参考集沿用PlatEMO默认问题的 `GetOptimum(10000)`，10000是请求规模，不是保证实际返回点数。当前 `IGDp.m` 在原始目标空间计算，不额外归一化。
- 用户说明大部分实验在本机、六个并行worker执行；本机核验为MATLAB R2023a Update 2、Intel Core i5-12400、约32 GB RAM。该配置不扩展为所有历史运行均使用相同机器。
- 取消“Full-versus-control直接检验必须补做”的待办。正文保留Full与删除对照均值的模块作用讨论；表内符号仍明确相对REMO，不写成Full直接比较的显著性。
- 不把少量终端FE超出列为必须重跑事项；保留配置预算500、主表末次值、曲线FE≤500的口径说明。官方期刊指南访问受限，尚不能认证不存在严格FE条款，详见 `../../实验TODO处理说明_20261007.md`。

## 历史记录

2026-09-23：本目录主表更新为 **FE=500 / 请求 runs 1--20 的七算法导出**。只读取
`C:\Users\lsx\Desktop\AdaMao实验表\nobatchdict版本\nobatchdict以PACDIS为基准十目标IGDp.xlsx`、
`nobatchdict以PACDIS为基准十五目标IGDp.xlsx`、`nobatchdict以PACDIS为基准二十目标IGDp.xlsx`
的 `IGDp` 工作表；六基线改为 REMO、SSDE、PC-SAEA、SAMOEA-TL2M、CSEA、HES-EA，提出的算法列
在源表里已直接标为 PACDIS（对应 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`）。
该批为 **maxFE=500、run ID 1--20**，与 2026-09-18 那版（FE=300、20 跑）预算不同；
部分基线单元格未满 20 跑，详情见下文。2026-09-22 的同名表曾为 FE=500 / 10 跑。
2026-09-18：本目录主表曾切换至 IGD$^+$ 指标与 NoBatchDist 变体，读取 `lambdat030版本\lambdat030nobatch{十,十五,二十}目标IGDp.xlsx`。
2026-09-15：本目录主表曾切换至 lambda_t=0.30 简化版，读取 `lambdat030{十,十五,二十}目标.xlsx` 的 `IGD` 工作表。
2026-09-14：本目录主表曾切换至用户指定的 `参数简化版本\pruned_weight*.xlsx`（旧版，可由 Git 历史复现）。

- PACDIS 对应 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`。当前源表把它直接命名为 `PACDIS`；
  2026-09-18 版源表列名是完整实现名，2026-09-14 版对应 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted`。
- 当前源表只带七列表格列（Problem/M/D + 六基线 + PACDIS），不再附带 `..._Lambdat030` 等历史列；
  脚本仍保留白名单机制，白名单外的列一律忽略。
- 每档 DTLZ1–7、WFG1–9，M=10/15/20，共 48 组、7 算法、336 个数据格。
- 六基线为 REMO、SSDE、PC-SAEA、SAMOEA-TL2M、CSEA、HES-EA；正文已补后三个新增算法的参考文献。
- 保留全部源均值、标准差及统计符号。`+/-/=` 表示该基线相对 PACDIS 更优/更差/未检出差异，不从均值推断显著性。
- **当前三个目标数请求 run 1–20，但并非每个单元格都满 20 跑**。三张源表由
  `.workbuddy/run_scripts/BuildFE500IGDTable(runs,metric,M)` 从 `REMOandDREMO测试集\{M}目标[\\n30]\FE500\<算法>\`
  的末快照取出，符号用 MATLAB `ranksum`（p<0.05），锚点为末列 PACDIS。
  覆盖核对：M=10 全部 20 跑；M=15 的 REMO 为每题 10–20 跑，其余满 20；
  M=20 的 REMO、PC-SAEA、CSEA、HES-EA 分别为每题 18–20、17–20、19–20、17–20 跑，
  其余满 20。当前导出脚本对每对比较取较短样本量做 rank-sum，而均值用该算法可用的全部样本。
  这些差异需要在最终统计复核中处理。
- `igd_snapshot.csv` 记录源工作簿、工作表、单元格、原字符串及解析值；`source_manifest.json` 记录 SHA-256、列身份、元数据及源表汇总。
- 源表不含 N、FE、独立运行次数等完整元数据。N=100、maxFE=500 由实验批次确定。清单中缺失字段保留 null，不伪装成 Excel 记录。
- 配置：gmax=3000、pMix=0.50、rGood=0.25、qKeep=0.70、nMax=6；内部常数 lambda=0.30、qRel=0.30、theta=5；
  k_eff=min(N,max(6,ceil(1.5*M)))。NoBatchDist 不再使用批次距离权重 w。
- D 取自源表：WFG2/3 在 M=10/20 为 31，M=15 全部为 30。N_init=100 与目标种群配置 N=100 分开说明。
- IGD$^+$ 参考集、执行环境、以及"各算法是否严格终止于 500 FE"尚需补充核实；源表标记不是本次重新执行的检验。

| M | 六基线汇总 +/−/= | PACDIS 最低均值数 | HES-EA 列 +/−/= |
|---|---|---|---|
| 10 | 10/76/10 | 7 | 6/8/2 |
| 15 | 11/73/12 | 5 | 5/8/3 |
| 20 | 12/71/13 | 4 | 5/7/4 |

最低均值及加粗按显示精度比较，不代表显著优于所有算法。PACDIS 当前在 **DTLZ4、DTLZ6、WFG2、WFG7**
三档均为最低均值，此外 DTLZ2 在 M=10/15、DTLZ1 与 WFG1 在 M=10 最低；
HES-EA 在 M=10/15/20 分别拿 6/6/7 题最低均值，在 DTLZ5、DTLZ7、WFG8 三档均优于 PACDIS。
主要短板叙述需按新数据重写；WFG3 仍是 PACDIS 的全面溃败题。

重建：运行 `build_tables.py` 从已提交快照生成两张 TeX 表及 summary.json；加 `--source-dir` 读取上述三张原表。
脚本检查每题每算法身份、数值格式及逐列符号总数，不修改 Excel。

修改前 Original 主表与方法保存在 Git 标签 `paper-original-params-20260914`，见论文目录 `VERSION_CHECKPOINTS.md`。
旧版来源文档不作为本版主性能证据。
