# REMO 参照的 IGD+ 消融表

2026-10-07 用户决定取消“必须补Full与两组删除对照直接检验”的待办。现有均值比较用于讨论模块删除的表现变化，表内检验符号仍只相对REMO；未补造Full-versus-control的p值。下方关于直接检验的说明是证据边界，不再作为必做实验计划。

`table_ablation_igdp.tex` 由 `build_remo_reference.py` 根据 `sources/` 中两份原始工作簿生成。工作簿来自 `C:\Users\lsx\Desktop\AdaMao实验表\消融实验\nobatchdict版本\`，分别覆盖 M=10 和 M=20 的 DTLZ1--7、WFG1--9。源文件名保留了原来的 `RMEO` 拼写。

| 源文件 | SHA-256 |
| --- | --- |
| `nobatchdict以RMEO为基准十目标IGDp.xlsx` | `0437aab41205c5224c214e0a941c37c085aa6777d78050becd5376535034992f` |
| `nobatchdict以RMEO为基准二十目标IGDp.xlsx` | `13cab8e27a4f1af87c83e017d834aa95aac3971548c8eabd8c77a092c60bc580` |

工作簿的四列身份是 `Full`、`w/o CDIS`、`w/o PAQC`、`REMO`。后两项删减对照没有被重命名为 `REMO+CDIS`、`REMO+PAQC`。表内每个问题族只汇总一行，跨 M=10 和 M=20。

## 2026-10-09：w/o CDIS 臂换血

本轮把 w/o CDIS 这一列的数据源从 `REMO_noBatchDict_noCDIS` 换成本次新跑的
`REMO_NoCDIS_REMOSelection`（16 题 × M=10/20 × 20 跑、N=100、D=30（WFG2/3 实际 31）、
maxFE=300、save=30，种子与旧臂同一套 `20260912 + M*1e5 + 1000*题号 + run`）。

- 上表两份工作簿已换成同名的新版（`..._NoCDISREMOSelection.xlsx` 的副本），因此哈希变了。
- **换臂只影响 w/o CDIS 一列**；`Full`、`w/o PAQC`、`REMO` 三列数值与符号逐格未动，
  两张表的 `Full`（`28/2/2`）与 `w/o PAQC`（`20/1/11`）计数复现原先的论文数字，可作为管线自校验。
- 新的 `+/-/=`（相对 REMO，跨 M=10 与 M=20）：`Full` 为 `28/2/2`，**w/o CDIS 为 `18/1/13`**
  （M=10 = 8/0/8、M=20 = 10/1/5），`w/o PAQC` 为 `20/1/11`。此前的 w/o CDIS 数值是 `19/2/11`。

### 新臂的机制与先前记录不同，正文已同步

旧的 w/o CDIS 只删掉指标模型、指标准则与模式切换，仍保留模糊性奖励准则。
新臂 `REMO_NoCDIS_REMOSelection` 把**整个 CDIS 换成本地 REMO 原始候选模块**
（私有副本 `RSurrogateAssistedSelection.m` SHA-256 `43d7d142…`，与本地 REMO 源文件逐字节一致），
PAQC 与优化宿主沿用 Full，并沿用 Full 的批量上限与剩余预算截断。
`HPDC-MaOEA.tex` 的 §4.3 描述段与表注已按此改写。

**需要保留的实现细节（如实交代）**：恢复的原始模块未作修正，其私有副本带有原文件的两个既有实现特征——
评分矩阵 `scores=zeros(Next_num,2)` 只用第一列，以及 `Xi–C2` 累积项使用 `pre_XiC1(1)`。
这是对**本地原始实现**的替换消融，不声称复现经索引修正后的关系公式。

### 证据边界

工作簿给出配置 FE=300、汇总值和导出符号，但没有逐次运行数据、检验设置或多重比较调整记录。
REMO 的历史运行可能超过 300 次真实评估，因此正文将其作为背景参照。相对 REMO 的符号不能代替
Full 与两组删减对照之间的直接检验，也不能据此分别归因 PAQC 和 CDIS。

在带有 `openpyxl` 的 Python 环境运行 `python build_remo_reference.py --check`，可校验生成表与两份工作簿一致。
