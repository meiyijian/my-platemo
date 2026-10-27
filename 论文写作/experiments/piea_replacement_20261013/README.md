# 第一篇论文 PIEA 替换记录

## 本次范围与最终结果

用户指定三份 FE500 IGD⁺ 工作簿，要求以 PIEA 替换 SAMOEA-TL2M，相关说明和收敛图同步更新，保持格式风格。已修改 `HPDC-MaOEA.tex`、中文稿、两张主表及论文实际引用的五幅十目标收敛图：DTLZ1、DTLZ6、WFG2、WFG7、WFG3。未修改算法实现，未重新运行优化。

- 48 个 PIEA 表格单元逐格保留源均值、标准差和符号；其余六个算法共 288 格保持不变。
- 表格仍为七算法布局，原第四基线位置改为 PIEA。行内浅灰标记和底部符号合计从保留的七算法重新计算。PACDIS 的最低均值数由 7/4/4 更新为 5/3/3，总数从 15 改为 11。
- PIEA 的 `+/-/=` 为 4/9/3、3/11/2、3/9/4（M=10/15/20）；在三档 DTLZ6、WFG3 上均为最低均值。
- 英文摘要、引言、实验设置、比较说明和结论中的对应叙述已更新；算法说明引用既有 PIEA 文献，删除旧 SAMOEA-TL2M 文献项。中文稿同步表格、算法说明和数值，并调整后续文献编号。

## 数据来源与口径

主表直接读取 `C:\Users\lsx\Desktop\AdaMao实验表\FE500含PIEA\最差20` 三份 `*IGDp.xlsx` 的 `IGDp` 工作表。按用户指示将其视为正常最终数据，未依据目录名重新筛选、删除或重算运行。三个源表的未修改副本已归档至 `../main_performance/sources/`；源 SHA-256 和单元格地址记录于该目录清单与快照。

曲线保持原来的 run 1–20、单位 FE 网格和最近快照保持法，使用十目标原始 `10目标/n30/FE500/PIEA` 数据。初始化包含在预算内，PIEA 从 FE100 开始，每轮增加一个真实评价；FE500 之后的指标值不进入曲线。主表最终汇总和曲线原始 run 1–20 分开记载；正文不将两者声称为完全相同的运行子集。

十五、二十目标的原始 PIEA 数据目录也已确认，分别为 `{15,20}目标/FE500/PIEA`。每个目标数目录均有 640 个 MAT 文件。当前论文五幅活动曲线均为十目标，未扩展到未引用的历史图件。

72 个十目标 PIEA 文件缺少完整的 IGD⁺ 轨迹。`../fe500_convergence/export_piea_metric_cache.m` 从已保存种群重建这些指标，将源文件哈希、FE 坐标和 FE 计数保存在专用缓存，不写回原始 MAT。重建对各题首末快照与原生 `IGDp` 比较，并对一条完整保存轨迹逐点比较，误差均为零；问题 FE 始终保持 0。

曲线 FE500 均值：

| 问题 | PACDIS | PIEA |
| --- | ---: | ---: |
| DTLZ1 | 137.229053 | 179.984353 |
| DTLZ6 | 13.320764 | 5.640573 |
| WFG2 | 1.368622 | 1.773978 |
| WFG7 | 3.127175 | 5.545035 |
| WFG3 | 1.438662 | 0.945635 |

## 验证证据

- `validation.json`：336 个单元与源表一致，其余算法 288 格和 600 条原始运行轨迹保持不变。绘图的尺寸、字体、颜色、标记、线宽、图例、刻度参数和实现函数逐项对照基线提交 `9c2c4d6`；仅旧算法身份映射换为 PIEA。
- `../fe500_convergence/validation.json` 与 `../fe500_convergence_wfg3/validation.json`：从 700 个原始 MAT 文件独立重建 35 条均值曲线，所有绘制点均含 20 次运行，FE 上限 500，最大均值误差约 1.14e-13。
- `style_audit.json`：新增正文按 paper-writing 的机械规则扫描。破折号、被动语态、修辞对举、夸张词、空泛开头等新增命中为 0；唯一 `pairwise` 命中属于标准比较术语，已有明确豁免。
- `review.md`：按独立审稿视角检查数据一致性、术语、证据边界和可读性。
- `compile_validation.json`：最终修改后使用独立作业名 `HPDC-MaOEA-PIEA` 连续编译两遍，避免主目录旧辅助文件污染引用。最终为 16 页，未解析引用及溢出版面为 0；PIEA/CSEA/HES-EA 文献编号为 10/15/16。
- 最终 PDF 的第 1、8、9、10、11、12、15 页已渲染检查。两张主表无裁切、遮挡；五张曲线仍共用原图页布局，普通图中文字不低于 7.5 pt，字体嵌入，PDF 为矢量、PNG 为 600 dpi。

保留原有作者和单位占位、PAQC 示意图 PDF 版本提示及部分行间空白提示。本任务未擅自补充作者信息，也未据此扩展修改范围。

## 复现与回退

从 `论文写作/` 运行：

```text
python experiments/main_performance/build_tables.py
python experiments/main_performance/sync_cn_tables.py
python figures/build_convergence_fe500.py
python figures/build_convergence_wfg3_fe500.py
python experiments/piea_replacement_20261013/validate_replacement.py
python experiments/piea_replacement_20261013/mechanical_style_audit.py
python experiments/fe500_convergence/validate_convergence_fe500.py
python experiments/fe500_convergence_wfg3/validate.py
```

需要从原始数据重新导出时，先运行 MATLAB 指标缓存脚本，再运行四图目录的 `export_convergence_fe500.py`，WFG3 绘图脚本加 `--export`。这些路径都保存在清单中；源数据读取要求本地原始目录存在。

本次改动独立提交，回退使用 `git revert <本次提交编号>`，然后重新编译 PDF。最终提交编号及推送结果见聊天完成消息。
