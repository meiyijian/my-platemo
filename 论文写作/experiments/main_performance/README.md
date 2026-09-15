# Weighted 主性能数据与复现

2026-09-15：本目录主表切换至 lambda_t=0.30 简化版。只读取 `lambdat030十目标.xlsx`、`lambdat030十五目标.xlsx`、`lambdat030二十目标.xlsx` 的 `IGD` 工作表。
2026-09-14：本目录主表曾切换至用户指定的 `C:\Users\lsx\Desktop\AdaMao实验表\参数简化版本`，读取 `pruned_weight*.xlsx`（旧版，可由 Git 历史复现）。
两版均只读取 `C:\Users\lsx\Desktop\AdaMao实验表\参数简化版本` 下的对应三张表，不混入 Pruned、Q080、Original 或 Lambda020。

- PACDIS对应 `REMO_UniformMix_Pruned_Weighted_Lambdat030`（2026-09-14 版对应 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted`）。
- M=20源表额外附带 `..._Pruned_Weighted` 与 `..._Original` 两列，本脚本按列名白名单忽略，不进入主表。
- 每档DTLZ1–7、WFG1–9，M=10/15/20，共48组、7算法、336个数据格。
- 六基线为REMO、PIEA、CSEA、PCSAEA_N100、KRVEA_100、MCEAD，全部来自同一批三张表。
- 保留全部源均值、标准差及统计符号。`+/-/=`表示该基线相对PACDIS更优/更差/未检出差异，不从均值推断显著性。
- `igd_snapshot.csv`记录源工作簿、工作表、单元格、原字符串及解析值；`source_manifest.json`记录SHA-256、列身份、元数据及源表汇总。
- 三表均不含N、FE、独立运行次数等完整元数据。N=100、maxFE=300延续用户确认的设置；本次用户确认参数不变。清单中缺失字段保留null，不伪装成Excel记录。
- 配置：gmax=3000、pMix=0.50、rGood=0.25、qKeep=0.70、nMax=6；内部常数w=0.75、qRel=0.30、theta=5；k_eff=min(N,max(6,ceil(1.5*M)))。
- D取自源表：WFG2/3在M=10/20为31，其余30。N_init=100与目标种群配置N=100分开说明。
- 独立运行次数、导出统计选项、IGD参考集、执行环境和基线逐次实际FE尚需补充核实。源表标记不是本次重新执行的检验；不声称所有基线均严格终止于300 FE。

| M | 六基线汇总 +/−/= | PACDIS最低均值数 | PIEA列 +/−/= |
|---|---|---|---|
| 10 | 18/60/18 | 3 | 7/5/4 |
| 15 | 22/56/18 | 3 | 6/6/4 |
| 20 | 19/57/20 | 4 | 6/7/3 |

最低均值及底纹按显示精度比较，不代表显著优于所有算法。PACDIS在WFG7/8三档均为最低均值，WFG1在M=10/20为最低均值，WFG6在M=15/20为最低均值。主要短板和PIEA对照按新数据重写。

重建：运行 `build_tables.py` 从已提交快照生成两张TeX表及summary.json；加 `--source-dir` 读取上述三张原表。脚本检查每题每算法身份、数值格式及逐列符号总数，不修改Excel。

修改前Original主表与方法保存在Git标签 `paper-original-params-20260914`，见论文目录 `VERSION_CHECKPOINTS.md`。旧版来源文档不作为本版主性能证据。
