# REMO 参照的 IGD+ 消融表

`table_ablation_igdp.tex` 由 `build_remo_reference.py` 根据 `sources/` 中两份原始工作簿生成。工作簿来自 `C:\Users\lsx\Desktop\AdaMao实验表\消融实验\nobatchdict版本\`，分别覆盖 M=10 和 M=20 的 DTLZ1--7、WFG1--9。源文件名保留了原来的 `RMEO` 拼写。

| 源文件 | SHA-256 |
| --- | --- |
| `nobatchdict以RMEO为基准十目标IGDp.xlsx` | `a39e45eafb192af544b012bcfddbf77a83b08dd262de4d7820fbc08ba20184b3` |
| `nobatchdict以RMEO为基准二十目标IGDp.xlsx` | `5611dc068bc1267476db101efd3d7c6ffdb74f690a112d268c22bab30d31d9c4` |

工作簿的四列身份是 `Full`、`w/o CDIS`、`w/o PAQC`、`REMO`。后两项删减对照没有被重命名为 `REMO+CDIS`、`REMO+PAQC`。32 个问题—目标数组合的 128 组均值/标准差与替换前的论文表逐格一致；这次替换的是统计符号的参照对象。新表所有 `+/-/=` 都相对 REMO：Full 为 `28/2/2`，w/o CDIS 为 `19/2/11`，w/o PAQC 为 `20/1/11`。表内每个问题族只汇总一行，跨 M=10 和 M=20。

工作簿给出配置 FE=300、汇总值和导出符号，但没有逐次运行数据、检验设置或多重比较调整记录。REMO 的历史运行可能超过 300 次真实评估，因此正文将其作为背景参照。相对 REMO 的符号不能代替 Full 与两组删减对照之间的直接检验，也不能据此分别归因 PAQC 和 CDIS。

在带有 `openpyxl` 的 Python 环境运行 `python build_remo_reference.py --check`，可校验生成表与两份工作簿一致。
