---
name: paper-cn-mirror
description: 把 论文写作/HPDC-MaOEA.tex（英文主稿）逐节对译成中文 Markdown，输出并覆盖 论文写作/HPDC-MaOEA_中文版.md。当用户说「把 tex 翻译为中文版 md / 更新中文版 / 中英对照稿」时使用。表格数据必须脚本转换，不要手抄。
agent_created: true
---

# 论文中文对照稿（tex → HPDC-MaOEA_中文版.md）

**这是翻译任务，不改 tex。** 因此 `论文写作/AGENTS.md` 的「改完 tex 自动编译+提交+推送」约定**不触发**；
但产物落在论文目录里，完成后要问用户是否要提交（推送属对外动作，先问）。

## 0. 先读齐源料（别只看主 tex）

- `论文写作/HPDC-MaOEA.tex` 全文
- 它 `\input` 进来的**全部**浮动体（2026-09-17 版共 5 个）：`figures/figure_framework.tex`（图 1 的 caption
  只在浮动体文件里，主稿没有）、`experiments/main_performance/table_dtlz.tex`、`table_wfg.tex`、
  `experiments/ablation_original/table_full_dtlz_wfg.tex`（消融表）、`figures/figure_convergence.tex`（收敛图）
- 图 2 的 caption 在主稿内联（`\begin{figure}` … `paqc_reference_manifold`）；p_mix 灵敏度表（表 4）也内联在
  主稿的 `table*` 里。**每个 `\input{}` 都要点开**，否则会漏 caption 与表头结构；图件路径写进中文稿便于溯源

## 1. 溯源头

取 tex 的 `LastWriteTime` 与 SHA-256 写进 md 顶部说明块，和上一版对比可看出是哪次修订。
PowerShell 回显常为空 → `("size={0} mtime={1} sha256={2}" -f ...) | Out-File -Encoding utf8 <tmp>` 后再 `Read`。

## 2. 编号映射（**必须按源码出现顺序手数，不能猜**）

| 对象 | 编号规则 | 现状（2026-09-17 版） |
|---|---|---|
| 公式 | 按 `\begin{equation}` 出现顺序 | 式 1–18 |
| 公式引用 | `\eqref{a}--\eqref{b}` → `式 (n)–(m)` | — |
| 算法 | `\begin{algorithm}` 顺序 | 算法 1 PACDIS／2 PAQC／3 CDIS |
| 图 | `\begin{figure}`/`figure*`（含 `\input` 的浮动体）顺序 | 图 1 框架图、图 2 PAQC 几何、图 3 收敛（六面板） |
| 表 | `\begin{table}`/`table*`（含 `\input`）顺序 | 表 1 = table_dtlz、表 2 = table_wfg、表 3 = 消融表、表 4 = p_mix 灵敏度（**内联**） |
| 参考文献 | `thebibliography` 的 `\bibitem` 顺序 | [1]–[10]（旧版 8 条，已删 R2AEA） |

2026-09-17 版的关键式号（改动后极易错位，务必核对）：`eq:relscore`=9、`eq:prefilter-exp`=10、
`eq:ambiguity`=11、`eq:expscore`=12、`eq:greedy`=13、`eq:svr`=14、`eq:mode`=15、`eq:batch`=16、
`eq:keff`=17、`eq:ggp`=18。

**别靠肉眼数编号**：用一次性脚本按 `\\begin{equation}`/`\\label` 顺序打印（本机 PowerShell 传含 `\\` 的
`-c` 字符串会被二次转义，写成 `.py` 文件再跑才可靠）。

正文引用风格保持旧稿惯例：`<sup>[n]</sup>`。

## 3. 表格：脚本转换，禁止手抄

```bash
PY="C:/Users/lsx/.workbuddy/binaries/python/versions/3.13.12/python.exe"
cd "D:/PlatEMO-master"
"$PY" .workbuddy/run_scripts/tex_table_to_md.py "论文写作/experiments/main_performance/table_dtlz.tex" .workbuddy/_tmp_tbl_dtlz.md
"$PY" .workbuddy/run_scripts/tex_table_to_md.py "论文写作/experiments/main_performance/table_wfg.tex" .workbuddy/_tmp_tbl_wfg.md
```

（Bash 工具链在本机基本不可用，但「Bash + 受管 python 全路径 + 引号包中文路径」实测可行；
PowerShell 直接跑 python.exe 亦可。）

消融表（表 3）与内联的 p_mix 表（表 4）**不属于** `tex_table_to_md.py` 的格式（列数、分组方式都不同），
用 `.workbuddy/run_scripts/tex_ablation_pmix_to_md.py`：

```
"$PY" .workbuddy/run_scripts/tex_ablation_pmix_to_md.py ablation \
      "论文写作/experiments/ablation_original/table_full_dtlz_wfg.tex" .workbuddy/_tmp_tbl_abl.md
"$PY" .workbuddy/run_scripts/tex_ablation_pmix_to_md.py pmix \
      "论文写作/HPDC-MaOEA.tex" .workbuddy/_tmp_tbl_pmix.md
```

该脚本的坑（都踩过）：① p_mix 表的 `\label{tab:exp:pmix}` 在 `\begin{tabular*}` **之前**，
定位必须向后找 `\begin{tabular`；② 消融表用 `\mathbf{}` 而主表用 `\textbf{}`，剥离命令时要覆盖两者
（`$\mathbf{...}$` 去掉 `$` 后若只处理 `\textbf` 会残留 `mathbf{`）；③ 分组横幅行（`\multicolumn{N}{c}{...}`）
**不要**在后面补 `|---|` 分隔行，否则 Markdown 会把一张表切成两张；④ docstring 含 `\m` 时加 `r"""`，
否则 Python 报 `SyntaxWarning` 并让 PowerShell 把 rc 当成 1。

正文里先写占位符 `<!--TABLE_DTLZ-->` / `<!--TABLE_WFG-->`，写入后替换：

```bash
"$PY" .workbuddy/run_scripts/fill_table_placeholders.py "论文写作/HPDC-MaOEA_中文版.md" \
  "TABLE_DTLZ=.workbuddy/_tmp_tbl_dtlz.md" "TABLE_WFG=.workbuddy/_tmp_tbl_wfg.md"
```

替换完再补中文表题（脚本输出的是 `<!-- 英文 caption -->` 注释）与读表注（均值 (标准差) 符号、
加粗=行内最低均值、末行是 21/27 个组合的 `+/-/=` 计数）。

脚本要点：`\shortstack` 两行合并成「均值 (标准差) 符号」；`\cellcolor{black!25}+\textbf` → `**加粗**`；
题名在每组三行的中间行（M=15），需向下补齐整组；表头行 `Problem & $M$ & …` 要跳过。

## 4. 保留下来的体例（与旧稿一致，别自创）

- 摘要/关键词、`## 1 引言` 这种「数字+标题」的章节号
- TODO 原样保留并译成 `**[TODO：…]**`
- 算法用引用块：`> **算法 N**　名称` + `**输入**/**输出**` + 缩进步骤
- 图用引用块 `> **图 N**　…（图件源文件：`path`）`
- 公式 `$$ … \tag{n} $$`，命题/证明单独成块，`∎` 收尾
- 文末「参考文献」按 thebibliography 顺序列出，未定条目留 `**[TODO：…]**`
- 表格里的分组横幅与汇总行标签（`10-objective problems`、`Average rank`、`+/-/= vs. REMO` 等）对译成
  中文（`**10 目标问题**`、`**平均秩**`、`**相对 REMO 的 $+/-/=$**`），数值一律不动
- 表注写在表下方的 `> 注：…` 引用块里，说明加粗含义、符号含义与末行计数范围
- 生成后用一次性脚本校验每张表的列数恒定（分组横幅行与汇总行最容易破坏对齐）

## 5. 数字只核对，不改写

§4.2 的每个数字都派生自 `experiments/main_performance/summary.json`
（字段对照见 `paper-main-table-refresh` skill 的 §3）。翻译时**照抄英文稿**，
但要交叉核对一遍：若英文稿口误/漏述（例：2026-09-15 版称 MCEA/D 只在 15/20 目标上取得
DTLZ3 最低均值，实际 10 目标也是），**在汇报里点名，不擅自改中文稿**。

## 6. 文末附录

留一节交代：① 生成方式（哪些表是脚本转的）；② 相对上一版中文稿的变化清单
（新增章节/公式条数变化/算法改写/参考文献条数变化）；③ 旧版「复核说明」类临时章节
若其结论已被新 tex 吸收，用 3–4 行说明后不再保留，并把仍成立的源码审计结论留一句。

## 7. 收尾

- 临时文件落 `D:\PlatEMO-master\.workbuddy\`，用 `[System.IO.File]::Delete('<abs path>')` 删（`Remove-Item` 被拦）
- `present_files` 交付 md
- 追加当日 `.workbuddy/memory/YYYY-MM-DD.md`；问用户是否要 commit（推送先问）
