---
name: paper-main-table-refresh
description: 把 PlatEMO 实验导出的三张 xlsx 主表（M=10/15/20）数据写进论文 LaTeX 主性能表，并同步正文里由数据派生的统计数字。当用户给出「参数简化版本」下的 xlsx 并说"把这三张表的数据写进 xxx.tex，排版已经弄好了，只需要改数据"时使用。
---

# 论文主表数据刷新（xlsx → LaTeX）

**先别手改表格。** 这个仓库有权威生成流水线，手改会丢溯源、必出错。

## 0. 定位：先确认 tex 是 `\input` 还是内联

`论文写作/HPDC-MaOEA.tex` 的正文表格是 **`\input{experiments/main_performance/table_dtlz}`
+ `table_wfg`**，数据不在 tex 里。改数据 = 改这两个被 include 的文件。

**注意：`HPDC-MaOEA.tex` 与 `HPDC-MaOEA_1param.tex` 共用同一对表格文件。**
改一个会同时影响两个 tex → 正文数字要对两边都检查（1param 的那份本身可能与表格不同步，属历史遗留，先报告别擅自改）。

## 1. 权威流水线（`论文写作/experiments/main_performance/`）

```
build_tables.py --source-dir <xlsx 所在目录>   # 读 xlsx → 写 igd_snapshot.csv → 重建两张 tex + summary.json
build_tables.py                                # 只从已提交的 igd_snapshot.csv 重建
```

同目录产物：`igd_snapshot.csv`（每条记录的源工作簿/工作表/单元格/原字符串/解析值）、
`source_manifest.json`（SHA-256 + 列身份 + 元数据）、`summary.json`（派生统计）、
`table_dtlz.tex`、`table_wfg.tex`、`README.md`。

脚本内置断言（**跑不过就说明源表有问题，别绕过**）：
- 每档 16 题顺序必须是 DTLZ1–7 + WFG1–9，且 `M` 列等于该档；
- 每格必须匹配 `^\s*([\d.]+e[+-]\d+)\s*\(([\d.]+e[+-]\d+)\)\s*([+=-])?\s*$`；
- **有符号 ⟺ 不是 OURS 列**（我们自己那列不能带符号）；
- 第 18 行导出的 `+/-/=` 汇总必须等于逐格符号计数 → 反向校验源表没被手改过；
- 总记录数 = 3×16×7 = 336。

## 2. 换源只改两个常量

```python
OURS  = "<xlsx 里我们自己那列的表头全名>"
FILES = {10: "xxx十目标.xlsx", 15: "xxx十五目标.xlsx", 20: "xxx二十目标.xlsx"}
```

- **先读表头再改**：三张表的列顺序**互不相同**（M=15 的 `KRVEA_100`/`PCSAEA_N100` 与 M=10 反序），
  脚本按列名匹配所以无所谓，但你核对时要按名字对。
- **列白名单机制**：M=20 的表常额外附带历史列（如 `..._Pruned_Weighted`、`..._Original`），
  以及缺 `N`/`FE` 列。不在 `ALIASES` 里的列会被静默跳过，元数据缺失字段记 `null`——这是设计如此，不要为此改脚本。
- 算法目录名要在 `PlatEMO/Algorithms/Multi-objective optimization/` 下真实存在，避免把不存在的实现写进论文。

## 3. 正文数字是派生的，必须一起改

`\subsection{Comparison with the Six Baseline Algorithms}` 里的数字**全部来自 `summary.json`**，
换数据后必查（对照 `summary.json` 的 `by_objectives` / `by_suite`）：

| 正文说法 | 来源字段 |
|---|---|
| "PACDIS has the lowest mean IGD on a, b and c of the 16 problems" | `by_objectives[m].best_mean_counts.PACDIS` |
| "These best means occur on ..." | `by_objectives[m].best_mean_problems_PACDIS` |
| "The REMO columns have `+/-/=` counts of ..." | `by_objectives[m].baseline_plus_minus_equal.REMO` |
| "PIEA ... its corresponding counts are ..." | `by_objectives[m].baseline_plus_minus_equal.PIEA` |

**必须逐条重验的定性断言**（它们不来自脚本字段，换数据后可能变假）：
- "CSEA, PC-SAEA, K-RVEA and MCEA/D also have more reported losses than wins ... in each objective setting"
  → 看每档 `baseline_plus_minus_equal` 的 `+` 是否都 < `-`；
- "PIEA has a lower mean IGD than PACDIS on DTLZ5 and DTLZ6 at all three objective counts"；
- "MCEA/D has the lowest mean on DTLZ3 at 15 and 20 objectives"；
- "WFG3 ... REMO, PIEA, CSEA, PC-SAEA and MCEA/D all have lower means than PACDIS in the three settings"；
- "K-RVEA remains stronger on DTLZ7"；
- "they do not establish overall superiority to PIEA"（看 by_suite 里 PIEA 的胜负是否仍分裂）。
任一条变假 → 改措辞，并在汇报里点名。**别只改数字不改句子。**

## 4. 溯源字符串也要同步

换实现后，这些地方仍写着旧实现名，属论文内部自相矛盾，必须改：
- tex 头部注释 `%  Implementation: <旧目录名>.`
- `\paragraph{Compared algorithms.}` 末句
  `\texttt{REMO\_\allowbreak new2\_\allowbreak AdaMaO\_\allowbreak ...\_\allowbreak Weighted}.`
  → 换成新目录名，保持 `\_\allowbreak` 断行风格（双栏窄栏会 overfull）。
- `main_performance/README.md`：追加一行带日期的切换记录（保留旧日期那行，Git 历史可回溯），
  更新 PACDIS↔实现名映射、汇总表、最低均值说明。

**待确认的坑**：`\paragraph{PACDIS parameters.}` 的参数列表（gmax/pMix/rGood/qKeep/nMax）里
不一定列出了新变体引入的常数（如 `lambda_t=0.30`）。这属正文内容而非"数据"，**默认不改，但要在汇报里问用户**。

## 5. 环境（本机实测）

- `Bash` 工具链不可用（`dirname: command not found`），**一律用 PowerShell**；
  PowerShell 工具的回显经常为空 → 命令 `| Out-File -Encoding utf8 <临时文件>` 后用 `Read` 读文件。
- openpyxl 不在受管 Python 里，装一次即可：
  `C:\Users\lsx\.workbuddy\binaries\python\envs\default\Scripts\python.exe -m pip install openpyxl`
- 跑 Python 前设 `$env:PYTHONIOENCODING="utf-8"` 和 `[Console]::OutputEncoding=[Text.Encoding]::UTF8`。
- 临时文件别落在 `论文写作/experiments/` 里；要落就落 `.workbuddy/`，收尾用
  `[System.IO.File]::Delete()` 删（`Remove-Item` 被 safe-delete 拦）。

## 6. 提交

- **绝不用 `git add -A`**（沙箱会中断并留下 0 字节 `.git/index.lock`）→ `git add -- <显式路径>`。
- 必须 `-c core.longpaths=true`（仓库里有超长路径）。
- 中文路径 status 显示成八进制转义属正常。
- 提交信息写到 UTF-8 文件，用 `git commit -F <file>`，避免 PowerShell 引号/编码问题；提交后删掉该文件。
- 提交范围限定在 `论文写作/`，别把 `.workbuddy/` 的其他改动卷进去。
- **推送前先问用户**（对外动作）。

## 7. 汇报口径

给用户四件事：① 改了哪 8 个文件（tex / 表 ×2 / summary / snapshot / manifest / 脚本 / README）；
② 新旧数字对照表（最低均值数、REMO 与 PIEA 的 `+/-/=`）；③ 哪些定性断言重验后仍成立、哪些改了口径；
④ 提交哈希 + 需要用户拍板的遗留问题（实现名、参数段、1param tex）。
