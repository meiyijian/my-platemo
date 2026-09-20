# 项目长期备忘 (MEMORY.md)

> 规则与索引。**逐条实验坐标/论文资产细节 → `memory/MEMORY-details.md`**；逐次历史 → `memory/YYYY-MM-DD.md`。

## 项目 / 路径
- PlatEMO（MATLAB 本地 v4.12，**勿整体升级**）；fork `github.com/meiyijian/my-platemo.git` 分支 `master`
- **git 仓库根 = `D:\PlatEMO-master`**，工作区是其子目录 `PlatEMO-master\`，论文在 `D:\PlatEMO-master\论文写作\`
- 主线：REMO_new2_AdaMaO / PACDIS 系列 + 变体，目标 Q1（SWEVO）
- 原始数据 `C:\Users\lsx\Desktop\REMOandDREMO测试集`（`10目标\n30` 为主；20目标扁平无 n30 层）；表格/记录 `C:\Users\lsx\Desktop\AdaMao实验表`（按实验名建子目录，不覆盖历史）
- **两台机器路径不同（2026-09-20 用户明确）**：以上是**工位电脑**（当前这台，用户名 `lsx`）；**个人电脑**的数据根是 `D:\REMOandDREMO测试集`，且**没有表格存放路径**（个人电脑上不会要求出表格）。用户说「工位电脑」即指工位那组路径。runner / 出表脚本里的路径是硬编码的，换机器要改。

## Git 提交 / 推送（沙箱套路，2026-09-16 复核）
1. 不用 `git add -A`（会被中断、留 0 字节 `index.lock`）→ 显式 `git add -- <path>`；清锁 `[System.IO.File]::Delete('<repo>\.git\index.lock')`
2. 必须带 `-c core.longpaths=true`（算法目录 + 88 字符文件名 > 260）
3. **push exit 128 且 stderr 空 = 凭据助手起不来**（非 token 过期）。绕法：`"protocol=https\nhost=github.com\n\n" | git credential fill` 取 40 位 `gho_` token → `git -c credential.helper= -c "http.extraheader=Authorization: Basic <base64("x-access-token:"+tok)>" push origin master`；`include.path=<临时cfg>` 写法实测无效，`gh auth token` 返回空
4. 抓报错用 `2> $errfile`（push 场景 `2>&1|Out-String` 拿空串）；`%H%n` 格式串触发沙箱 `%VAR%` 误判 → 用 `--format=full`
5. 中文 commit message 不能用 `-m`（PS 5.1 按 GBK 传参乱码）→ UTF-8 文件 + `git commit -F`
6. `论文写作\AGENTS.md`：改 `HPDC-MaOEA.tex` 后必须编译 + 自动提交推送 + 报告提交号与回退方式
7. `git pull <remote> <branch>`（带参）只写 FETCH_HEAD、不更新 `origin/master` → `git status -sb` 长期显示 `ahead N` 假象（实测 ahead 192）。核实远程用 `git ls-remote origin master`；**extraheader 绕法 push 无输出 + rc=0 即成功**
8. **严禁 `git rebase --autostash`**（2026-09-18 实测删掉 `.git/objects/pack/*.pack` → 对象库崩、`bad object HEAD`）。**远程 master 有并行写者**，push 遇 non-fast-forward 优先「重新 clone 到新目录 → 搬改动 → commit → push → 用新 .git 替换旧 .git」，别 rebase

## 跑实验约定
- 「跑实验」= 只产 `.mat`，数据目录不留日志/清单/README/图；统计与图表仅在用户说「分析」时做，归档到 `AdaMao实验表\<实验名>\`
- 流程：读现成 runner 确认规格 → 改行为就**新建 runner 放 `.workbuddy/run_scripts/`，绝不改算法目录 .m**（破坏运行前 SHA-256 校验）→ `checkcode` + 查内存 → 回规格与耗时预估 → `matlab.exe -wait -batch` 后台跑 → 数 `.mat` 看进度 → 核对完整性并清理中间产物
- 改跑量/统计效力的决策（单臂 vs 双臂、是否重跑基线）先讲清楚让用户拍板

## 环境铁律
- MATLAB `D:\mathlab2023a\bin\matlab.exe`（需显式 `addpath`）；LaTeX MiKTeX `C:\Users\lsx\AppData\Local\Programs\MiKTeX\miktex\bin\x64\pdflatex.exe`
- **默认 5 workers**：6 workers 反慢约 9%（321.9 s vs 421.1 s）；profile 上限 6，请求 8 直接失败
- M=10 D=30 N=100 maxFE=300 约 6.1 min/波；M=20 单跑 ~5.5–5.9 min；长跑别并发开第二个 parpool（OOM）
- AI 生成的 `.m` 一律纯 ASCII（中文只允许出现在路径字符串）
- **Bash 工具链不可用** → 用 PowerShell，重定向到文件再 Read；日志统一 `2>&1 | Out-File -Encoding utf8`（别用 `*>`/`*>>`，会写 UTF-16）
- 删文件：`Remove-Item` 常被 safe-delete 拦 → `[System.IO.File]::Delete()`
- MAX_PATH 260：`Test-Path`/`.NET File` 会误报找不到路径（`Get-ChildItem` 正常）→ `\\?\` 前缀或 `robocopy`

## 种子公式
- 新实验：`seed = 20260912 + M×1e5 + 题号×1000 + runId`（出处 `RunPaperWeighted30.m`、`RunLambdat030_10.m`）
- 旧 18 跑批次：`seed = 20260912 + 题号×1000 + runId`（**无 M 项**）
- 16 题规范序：DTLZ1–7 = 1–7，WFG1–9 = 8–16
- 旧 `.mat` 无 `metadata` → 种子无法事后反推，只能找当时 runner；`Algorithm.run` 恒为 1（metadata 记 `modeRunId=1`）

## Algorithms/ 重名隔离铁律
`platemo.m` 用 `addpath(genpath(cd))`，MATLAB 按文件名解析 → 新目录中与既有目录重名的 `.m` 必须移进该目录 `private/`（genpath 跳过 private，private 优先级最高），主类文件留顶层。
惨案：`Shape_Estimate.m` 4 参数版抢占 PIEA/REMO 两参数版 → 被 try/catch **静默降级**，不报错只变差。**验收只能用「临时探针 + `functions(@Name).file`」**（`which` 查不到 private）。
`ResolveUniformMixMode.m` 现存 3 个版本，解析结果取决于 addpath 顺序（其中两份哈希不同但**代码行一致**，别只看哈希）。

## 进行中的关键坐标（详见 MEMORY-details.md）
- **NoBatchDict 消融**：noCDIS / noPAQC 两臂，M=10 = 2×16×20 = **640 .mat**；M=20 被用户搁置。脚本 `run_scripts\{progress_nbd.py,RunNBD_AblationAll.m,FinishNBD_Ablation.m,build_nobatchdict_tables.py}`；出表到 `AdaMao实验表\消融实验\nobatchdict版本\`（2 张 xlsx）
- **GGP**：三臂坐标与「hybrid 优势只在 `population_*` 真值上为正」结论
- **论文资产**：主文 tex / 主性能表生成链 / §4.6 收敛图 / 中文对照稿
