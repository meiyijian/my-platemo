# Weighted 主性能数据与复现

2026-09-22：本目录主表切换至 **FE=500 / runs 1--10 的七算法导出**。只读取
`C:\Users\lsx\Desktop\AdaMao实验表\nobatchdict版本\nobatchdict以PACDIS为基准十目标IGDp.xlsx`、
`nobatchdict以PACDIS为基准十五目标IGDp.xlsx`、`nobatchdict以PACDIS为基准二十目标IGDp.xlsx`
的 `IGDp` 工作表；六基线改为 REMO、SSDE、PC-SAEA、SAMOEA-TL2M、CSEA、HES-EA，提出的算法列
在源表里已直接标为 PACDIS（对应 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`）。
⚠️ 该批为 **maxFE=500、每题 10 跑**，与 2026-09-18 那版（FE=300、20 跑）**预算与跑数都不同**：
换源后正文里的实验协议表述、run 标识、"最低均值题数"等派生数字必须一起核对，不能只换表。
2026-09-18：本目录主表曾切换至 IGD$^+$ 指标与 NoBatchDist 变体，读取 `lambdat030版本\lambdat030nobatch{十,十五,二十}目标IGDp.xlsx`。
2026-09-15：本目录主表曾切换至 lambda_t=0.30 简化版，读取 `lambdat030{十,十五,二十}目标.xlsx` 的 `IGD` 工作表。
2026-09-14：本目录主表曾切换至用户指定的 `参数简化版本\pruned_weight*.xlsx`（旧版，可由 Git 历史复现）。

- PACDIS 对应 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`。当前源表把它直接命名为 `PACDIS`；
  2026-09-18 版源表列名是完整实现名，2026-09-14 版对应 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted`。
- 当前源表只带七列表格列（Problem/M/D + 六基线 + PACDIS），不再附带 `..._Lambdat030` 等历史列；
  脚本仍保留白名单机制，白名单外的列一律忽略。
- 每档 DTLZ1–7、WFG1–9，M=10/15/20，共 48 组、7 算法、336 个数据格。
- 六基线为 REMO、SSDE、PC-SAEA、SAMOEA-TL2M、CSEA、HES-EA（`SSDE.m` = 2024 SWEVO 91:101703；
  `SAMOEATL2M.m` = IEEE TSMC 2025 55(11):8166-8180；`HES_EA.m` = IEEE TEVC 2024, DOI 10.1109/TEVC.2024.3440354）。
  这三个算法当前**尚未进入正文的参考文献表**（`HPDC-MaOEA.tex` 的 `thebibliography` 里没有对应条目）。
- 保留全部源均值、标准差及统计符号。`+/-/=` 表示该基线相对 PACDIS 更优/更差/未检出差异，不从均值推断显著性。
- **当前三个目标数一律取 run 1–10**（2026-09-18 版为 run 1–20）。三张源表由
  `.workbuddy/run_scripts/BuildFE500IGDTable(runs,metric,M)` 从 `REMOandDREMO测试集\{M}目标[\\n30]\FE500\<算法>\`
  的末快照取出，符号用 MATLAB `ranksum`（p<0.05），锚点为末列 PACDIS。
  跑数覆盖度由 `.workbuddy/run_scripts/audit_fe500_coverage.py` 核对：336 格全部 n=10，无"某格跑数不足导致均值口径悄悄变窄"。
- `igd_snapshot.csv` 记录源工作簿、工作表、单元格、原字符串及解析值；`source_manifest.json` 记录 SHA-256、列身份、元数据及源表汇总。
- 源表不含 N、FE、独立运行次数等完整元数据。N=100、maxFE=500 由实验批次确定。清单中缺失字段保留 null，不伪装成 Excel 记录。
- 配置：gmax=3000、pMix=0.50、rGood=0.25、qKeep=0.70、nMax=6；内部常数 lambda=0.30、qRel=0.30、theta=5；
  k_eff=min(N,max(6,ceil(1.5*M)))。NoBatchDist 不再使用批次距离权重 w。
- D 取自源表：WFG2/3 在 M=10/20 为 31，M=15 全部为 30。N_init=100 与目标种群配置 N=100 分开说明。
- IGD$^+$ 参考集、执行环境、以及"各算法是否严格终止于 500 FE"尚需补充核实；源表标记不是本次重新执行的检验。

| M | 六基线汇总 +/−/= | PACDIS 最低均值数 | HES-EA 列 +/−/= |
|---|---|---|---|
| 10 | 9/69/18 | 6 | 6/7/3 |
| 15 | 7/68/21 | 4 | 4/7/5 |
| 20 | 7/69/20 | 5 | 2/7/7 |

最低均值及加粗按显示精度比较，不代表显著优于所有算法。PACDIS 当前在 **DTLZ4、DTLZ6、WFG2、WFG7**
三档均为最低均值，此外 DTLZ2 在 M=10/20、DTLZ1 在 M=10 最低；HES-EA 三档各拿 6 题最低均值，
是本批唯一在部分题（DTLZ5、DTLZ7、WFG5/6/8/9 一档或多档）显著压过 PACDIS 的基线。
主要短板叙述需按新数据重写；WFG3 仍是 PACDIS 的全面溃败题。

重建：运行 `build_tables.py` 从已提交快照生成两张 TeX 表及 summary.json；加 `--source-dir` 读取上述三张原表。
脚本检查每题每算法身份、数值格式及逐列符号总数，不修改 Excel。

修改前 Original 主表与方法保存在 Git 标签 `paper-original-params-20260914`，见论文目录 `VERSION_CHECKPOINTS.md`。
旧版来源文档不作为本版主性能证据。
