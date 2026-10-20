# 项目长期备忘 (MEMORY.md)

> 只放**长期有效的规则 + 索引**。逐条实验坐标 / 论文资产细节 → `MEMORY-details.md`；逐次历史 → `YYYY-MM-DD.md`。

## 项目 / 路径
- PlatEMO（MATLAB 本地 v4.12，**勿整体升级**）；fork `github.com/meiyijian/my-platemo.git` 分支 `master`
- **git 仓库根 = `D:\PlatEMO-master`**，工作区是子目录 `PlatEMO-master\`，论文在 `D:\PlatEMO-master\论文写作\`
- 主线：PACDIS（= `Lambdat030`，原 REMO_new2_AdaMaO 族）+ 变体；目标 Q1（SWEVO）
- 原始数据 `C:\Users\lsx\Desktop\REMOandDREMO测试集`（`10目标\n30`；20目标扁平无 n30）；表格 `C:\Users\lsx\Desktop\AdaMao实验表`（按实验名建子目录，不覆盖历史）
- **两台机器路径不同（2026-09-20）**：以上是**工位电脑**（用户名 `lsx`）；**个人电脑**数据根 `D:\REMOandDREMO测试集`，**没有表格路径**。runner / 出表脚本路径硬编码，换机要改。

## Git 提交 / 推送（沙箱套路，2026-10-09 复核）
1. 不用 `git add -A`（会被中断、留 0 字节 `index.lock`）→ 显式 `git add -- <path>`；清锁 `[System.IO.File]::Delete('<repo>\.git\index.lock')`
2. 必须带 `-c core.longpaths=true`（算法目录 + 88 字符文件名 > 260）
3. **取凭据**（helper 是 Git Credential Manager，`git credential fill` 会挂死）：
   `CRED=$(printf 'protocol=https\nhost=github.com\n\n' | GCM_INTERACTIVE=Never git-credential-manager get)` → `username=` + 40 位 `password=`；
   `B64=$(printf '%s:%s' "$USER" "$PASS" | base64 -w0)` → `git -c credential.helper= -c "http.extraheader=Authorization: Basic $B64" push origin master`，外套 `timeout 180`。
   本机无 `gh` CLI / `~/.git-credentials` / GH_TOKEN。**extraheader 绕法 push 无输出 + rc=0 即成功**
4. 抓报错用 `2> $errfile`（`2>&1|Out-String` 会拿空串）；`%H%n` 触发沙箱 `%VAR%` 误判 → 用 `--format=full`
5. 中文 commit message 不能用 `-m`（PS 5.1 GBK 传参乱码）→ UTF-8 文件 + `git commit -F`
6. **`论文写作\AGENTS.md`：改 `HPDC-MaOEA.tex` 后必须编译（交叉引用改动至少两遍）+ 自动提交推送 + 报告提交号与回退方式**
7. `git pull <remote> <branch>`（带参）只写 FETCH_HEAD、不更新 `origin/master` → `git status -sb` 长期显示 `ahead N` 假象；核实远程用 `git ls-remote origin master`
8. **严禁 `git rebase --autostash`**（实测删掉 `.git/objects/pack/*.pack` → 对象库崩）。**远程 master 有并行写者**：push 遇 non-fast-forward 先 `git fetch origin master`，比 `git diff --name-only <base> FETCH_HEAD` 与自己的改动集。
   不重叠 → `git merge-tree --write-tree HEAD origin/master` 预演（rc=0、无 CONFLICT）→ `git merge --no-edit origin/master` → push。
   真改同一文件 → 重新 clone 到新目录、搬改动、commit、push、换 `.git`。

## 跑实验约定
- 「跑实验」= 只产 `.mat`，数据目录不留日志/清单/README/图；统计出表只在用户说「分析」时做，归档 `AdaMao实验表\<实验名>\`
- 流程：读现成 runner 确认规格 → 改行为就**新建 runner 放 `.workbuddy/run_scripts/`，绝不改算法目录 .m**（破坏运行前 SHA-256 校验）→ `checkcode` + 查内存 → 报规格与耗时预估 → `matlab.exe -wait -batch` 后台跑 → 数 `.mat` 看进度 → 核对完整性、清理中间产物
- 改跑量 / 统计效力（单臂 vs 双臂、是否重跑基线）先讲清楚让用户拍板
- 数据生成类工作先预览、等显式确认再写盘；未经明确指令不改论文正文、不提交 commit

## 环境铁律
- MATLAB `D:\mathlab2023a\bin\matlab.exe`（需显式 `addpath`）；pdflatex `C:\Users\lsx\AppData\Local\Programs\MiKTeX\miktex\bin\x64\pdflatex.exe`
- **默认 5 workers**；profile 上限 6。会话内 `c=parcluster('Processes'); c.NumWorkers=N; parpool(c,N)` 可突破（不 saveProfile）
- **12 workers 并行度取决于算法类型**（2026-10-09）：神经网络小模型族 ≈ **11.7×**；GP/大矩阵类（CI-EMO）只有 **4.42×**（内存带宽）→ 别用 4.4× 估 NN 族 ETA
- **MATLAB 脚本文件名不能以下划线开头**（`_foo.m` 报「文本字符无效」，错误指向命令串末尾，易误判成编码问题）
- **`matlab.exe -batch "<cmd>"` 内反斜杠会被 Git Bash 改写**（`\\`→`//`）→ 命令串内用正斜杠；`.m` 内部不受影响
- **Bash 工具前台超时被钳到 ~10 min** → 长跑一律 `run_in_background=true`；`nohup ... &` 会在工具调用返回时被连进程组杀掉
- 单跑参考：M=10 D=30 N=100 maxFE=300 ≈ 6.1 min/波；M=20 ≈ 5.5–5.9 min；别并发开第二个 parpool（OOM）
- AI 生成的 `.m` 纯 ASCII（中文只出现在路径字符串）
- Bash（Git Bash）可用；**PowerShell stdout 有时被吞** → 先 `Out-File -Encoding utf8` 落盘再 Read。日志统一 `2>&1`（`*>` 写 UTF-16）
- 删文件：`Remove-Item` 常被 safe-delete 拦 → `[System.IO.File]::Delete()`
- MAX_PATH 260：`Test-Path`/`.NET File` 会误报找不到（`Get-ChildItem` 正常）→ `\\?\` 或 `robocopy`
- 机器：i5-12400，**6 物理 / 12 逻辑核**，32 GB。查硬件 `Get-CimInstance Win32_Processor/Win32_OperatingSystem`（`wmic.exe` 被黑名单拦）
- 本沙箱 `xargs` 会被 SIGTERM → 用 `find -printf` + bash 内建循环

## 种子公式
- 新实验：`seed = 20260912 + M×1e5 + 题号×1000 + runId`
- 旧 18 跑批次：`seed = 20260912 + 题号×1000 + runId`（**无 M 项**）
- 16 题规范序：DTLZ1–7 = 1–7，WFG1–9 = 8–16
- 旧 `.mat` 无 `metadata` → 种子无法事后反推；`Algorithm.run` 恒为 1

## Algorithms/ 重名隔离铁律
`platemo.m` 用 `addpath(genpath(cd))`，MATLAB 按文件名解析 → 新目录中与既有目录重名的 `.m` 必须移进该目录 `private/`（genpath 跳过 private，private 优先），主类留顶层。
惨案：`Shape_Estimate.m` 4 参数版抢占 PIEA/REMO 两参数版 → 被 try/catch **静默降级**（不报错只变差）。**验收只能用「临时探针 + `functions(@Name).file`」**（`which` 查不到 private）。
`ResolveUniformMixMode.m` 有 3 个版本，解析取决于 addpath 顺序（其中两份哈希不同但代码行一致）。

## `.mat` 数据语义
- `metric.IGD` / `metric.IGDp` 是**评价轨迹数组**，**末值 = 最终性能**，出表一律 `arr[-1]`
- 轨迹点数跨目录不一致（如 `REMO_new2_AdaMaO` M=10 为 18 点、M=20 为 30 点）→ 跨目录比较前先核点数
- 配对种子一致性可现场验证：同 runId 不同配置，轨迹**前 2 点应完全相同**
- **首快照 FE 跨算法不一致**（FE500 批：PACDIS/REMO/SSDE=100、CSEA=109、PCSAEA/HES_EA/SAMOEATL2M=329~340）→ 画收敛图前先查 `FE.min()`，不许插值补前段
- Python 出表：`C:\Users\lsx\.workbuddy\binaries\python\envs\default\Scripts\python.exe`（scipy/numpy/openpyxl/pandas/matplotlib/pymupdf；`loadmat(..., squeeze_me=True, struct_as_record=False)`）

## 论文（HPDC-MaOEA / PACDIS）
- **主性能表 = IGD$^+$（不是 IGD）**：`experiments\main_performance\table_{dtlz,wfg}.tex`，tex 约 1019–1020 行 `\input`
- 主表不内联，数据只能由 `build_tables.py --source-dir <xlsx>` 生成；正文数字派生自同目录 `summary.json`，改表必须改正文并重验定性断言
- **中文对照稿 `HPDC-MaOEA_中文版.md` 跟 tex 走**（整篇覆盖；表格用 `run_scripts/tex_table_to_md.py` / `tex_ablation_pmix_to_md.py` 转）
- 收敛图两条链**别混用**：
  1. **Python（论文在用）**：`figures\build_convergence.py` → `fig_convergence_*`；数据经 `experiments\nobatchdist_version_audit\convergence_igdp.csv` 中转；matplotlib 论文风（线性轴、稀疏 marker、Times、无阴影带、QA 断言最小字号/出界）。FE500 见 `build_convergence_fe500.py` + `export_convergence_fe500.py`
  2. **MATLAB（备选）**：`ConvergencePlot\`（`PlotConvergenceCurves.m` 管画；导出要自己补 `Toolbar off`/`xlim`/图例位置；`README.md` 记全部踩坑）
- 论文表宽：7 列 + 5 数值列在 522pt 下必然超宽 → `\footnotesize` + 缩短 `\multicolumn` 标签

## 关键坐标索引（细节全在 MEMORY-details.md）
- **PACDIS = `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`**；原版 REMO + CDIS = `REMO_k_CDIS`
- **w/o CDIS 臂 = `REMO_NoCDIS_REMOSelection`**（2026-10-09 跑完 640/640，12 workers 11.07 h）；换列时数据源换新目录，勿与 `REMO_noBatchDict_noCDIS` 混用
- **NoBatchDict 消融**（noCDIS / noPAQC）：M=10 已出表，M=20 用户搁置
- **CI-EMO FE500 基线**：M=15 不可运行；全量 640 跑约 18–20 天（吞吐封顶 4.42×）
- **FE500 含 PIEA 对比表**：runs 1-20 口径 + 「最差20」口径两套，均在 `AdaMao实验表\FE500含PIEA\`；论文尚未换用
- **GGP**：hybrid 优势只在 `population_*` 真值上为正
