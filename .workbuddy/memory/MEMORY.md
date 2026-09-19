# 项目长期记忆（PlatEMO PACDIS / AdaMaO 研究）

> 本文件只留最高频、最致命的条目；完整细节（环境、坑位、实验框架、数据集、论文）在 `REFERENCE.md`，需要时先读它。

## 现在在哪（截至 2026-09-19 15:00）
- 🔴 **HES_EA_N100 @ M=10 —— 停滞（94/320，需人工介入）**。12 个切片进程自 11:10–12:18 启动后**从未退出**，CPU 满载空转 2.7–3.8 h、零产出（健康切片 ≈38–47 min/10 跑）。卡住的题：DTLZ2/3/5/6、WFG1/2/3。**连带 M15 被卡死**：`chain_to_M15.sh` 要求 `matlab_procs==0` 才拉起，M15 smoke 的 WFG3 也从 13:42 卡到现在。详见 REFERENCE.md「HES_EA_N100 扫描」。
- **HES_EA_N100 @ M=15 —— 0/320，未启动**（框架/驱动/smoke 已就绪；DTLZ2 smoke 正常 285 s/跑）。数据 `D:\REMOandDREMO测试集\15目标\HES_EA_N100`（目录尚未创建）。
- M=10 框架 `PlatEMO/Experiments/HES_EA_N100_M10/`（已入库 commit `b8dbafd`）。两阶段口径：16 题 × 20 跑 = 320，M=10或15/D=30/N=100/maxFE=300/SaveCount=30，MAT 含 `result`+`metric{runtime,IGD,IGDp}`，SeedBase M10=21260912 / M15=21760912（`base+1000*题号+run`）。
- ✅ **M=20 消融 REMO_noBatchDict_{noCDIS,noPAQC}：完成 640/640**（各 320，OK=320/BAD=0）。结论：PAQC 与 CDIS 都不冗余（去 PAQC 平均 gap +6.27、p=1.4e-8；去 CDIS +3.91、p=4.3e-9；PAQC 更关键 p=9.2e-15）；去掉批次距离项反而略好（−1.45，p=0.026）。`k_eff=min(N,max(6,ceil(1.5M)))`，M=20→k=30。
- ✅ **RWMOP11 真实问题实验：完成 140/140**（七算法全注入 CDP；HV 垫底 PACDIS 0.0878，但 D=3 时 REMO 族初始仅 32 点 vs 基线 100 点，必须与初始规模一起读）。
- ✅ **pMix 敏感性扫描：完成 1200/1200**，已"一档一类"归档推送（commit `56dddd9`）。结论：**pMix=0.50 最稳健**（平均秩最低、显著优于 0.75/1.00），但非处处最优、与 0.25 无统计差异；pMix=0 最危险。
- 其余已完成：M=20 基线 320/320；Weighted WFG sweep M=15、M=8(D=10) 各 270/270。待办：Weighted M=5(D=10) 停在 159/270。
- 分工：**用户亲自跑重活，AI 负责开发/归档/自动化**；长任务先预估时长与排程间隔。

## 本机红线（违反就白跑/毁数据）
- Bash 每条命令首行必须：`export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"`。
- **PowerShell 工具 stdout 不回显**（连 `"hello"` 都空）→ 需要 PowerShell 时把结果 `Set-Content` 到临时文件再用 Read 读。
- **运行脚本/driver/日志一律放 `PlatEMO/Experiments/<实验名>/`（含 logs/）**；`tmp/` 会被用户随时清空（曾让 10 路 MATLAB 秒退）。
- **长跑前必须** `powercfg /change monitor-timeout-ac 0` + `standby-timeout-ac 0`，不合盖（本机 S0 Modern Standby，显示器关闭即冻结墙钟，09-15 吞掉 5.6 h）。
- 固定种子不能 `rng()`+`platemo()`（本地 platemo.m 会 `rng('shuffle')`）→ 直接构造 problem/algorithm，Solve 前 `rng(seed,'twister')`，模式流传 `'run',r`。
- **同一张对比表绝不能混用 maxNumCompThreads**（对 patternnet/fitrsvm 类非中性，会被模型驱动选择混沌放大）。
- Git：**严禁 `pull --rebase`**；两台机器别并发操作同一 .git；🔴 **长实验运行期间禁止在本机做 git merge / pull**（09-19 事故删掉工作区 905 文件）。恢复：确认无 git 进程 → `rm .git/index.lock` → `git reset --hard HEAD`；然后**先停 driver 再杀 MATLAB**，重启 driver 必须用后台任务方式（前台 `nohup &` 会被工具调用结束连带杀掉）。
- 🔴 推送必须"先清空助手列表、只留 wincred"且在**沙箱外**执行：`GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c credential.helper=wincred push origin master`。
- ⚠️ **`refs/remotes/*` 写不进去**：fetch/update-ref 报成功但不落盘（`git status -sb` 恒 `[gone]`）。绕过 = 用文件写入工具把 `.git/refs/remotes/origin/master` 写一行远端 SHA，别反复重试 fetch。
- MATLAB `-batch` 退出偶发 `0xc0000374`（堆损坏）：崩前写盘的数据安全。**切片越短越容易崩**（2 跑/切片 20 片崩 6 片 vs 10 跑/切片 156 片全 exit=0）→ 长实验用长切片，当"重跑即可"的噪声。
- Edit 偶发报成功但未落盘 → 关键编辑后 Read/Grep 复核。
- 🔴 **绝不编辑正在运行的 bash 脚本**（bash 按字节偏移增量读取，中途改文件会错位解析）。
- 🔴 **切片表格式**：字段 tab 分隔 + `IFS=$'\t'` read，run 列表用 MATLAB 冒号语法（`1:4`）；空格分隔的 `[1 2 3 4]` 会被 `read` 拆散。长跑前先干跑核对字段。
- 🔴 **Git Bash → MATLAB 传路径必须 `pwd -W`**（`pwd` 给 `/d/...`，MATLAB 静默失效）。
- `ALG` 的 outputFcn 只能传 `@(varargin)[]`（`@(v)[]` 报 `MATLAB:TooManyInputs`）。
- ⚠️ **patternnet 算法（REMO / PACDIS）不受"同种子+同线程"逐位复现保证**（同进程内第 1、2 次 Solve 会分岔），**跨进程同槽位才逐位一致** → 等价性断言必须固定槽位（每进程一跑）；20–30 跑统计比较不受影响。

## 记忆文件自动提交推送（09-16 用户授权，长期有效）
- 只要本轮改动了 `.workbuddy/memory/**`，**收尾自动提交推送、不再询问**：`git add -- .workbuddy/memory` → `git commit -m "chore(memory): <一句话>" -- .workbuddy/memory` → 沙箱外推送（写法见上）。
- **只用显式 pathspec `.workbuddy/memory`，绝不 `git add -A` / `git add .`**。`~/.workbuddy/*.md` 不在本仓库内、无远端可推。

## 常用口径
- 单跑 wall（M=20/D=30/N=100/maxFE=300，12 路 × threads=1）：DTLZ2≈420s、WFG1≈383s、WFG3≈377s、WFG8≈368s；**单跑成本几乎不随 M 变化**（M=10 ≈ 0.97×M=20）。
- 进程池利用率≈98% → 总墙钟 ≈ 切片数 × 65 min / 12（1200 跑 = 120 切片 ≈ 10.5 h）。
- 进度探针 `logs/stdout_<切片>.log`，行格式 `[done] <prob> run k | IGD A -> B | runtime Xs | wall Ys | ok`。
- 数据文件命名取自**算法类名**（不是文件夹名）；09-16 起 Lambdat030 的 pMix 五档已各自建类（文件夹名 = 文件名前缀 = 类名），更早的是"同算法类不同参数、文件名相同、靠文件夹区分"。写统计脚本前先 `ls` 确认。
- LaTeX：MiKTeX 25.12 + Strawberry Perl 已装好；中文目录下命令行编译须 `env -u LC_ALL -u LANG latexmk ...`。
