# 项目长期记忆（PlatEMO PACDIS / AdaMaO 研究）

> 只留最高频、最致命的条目；环境/坑位细节、数据集、论文、FE500 六坑、HES_EA 停滞事件全部归档在 `REFERENCE.md`，需要时先读它。

## 现在在哪（截至 2026-09-24 02:54）
- 🟢 **NoBatchDist 版 pMix 敏感性（重跑论文 pMix 表）—— 后台 `B8l4zX`，14 路 / threads=1 / gap 25 s / 96 切片**。口径：6 题（DTLZ2/4/7、WFG1/3/8）× M=10/20 × 4 档（0/0.25/0.75/1.00）× 20 跑 = **960 跑**；**PMix050 不跑**，复用 Full `..._NoBatchDist` 数据（该目录 320 文件 = 16 题全系列，**不计入**本实验）。N=100、D=30（WFG3 为 31）、maxFE=300、SaveCount=30；SeedBase M10=**21260912** / M20=**22260912**（`base+1000×题号+run`）；在线同步算 IGD+IGDp。落盘 `D:\REMOandDREMO测试集\{10目标\n30,20目标}\REMO_..._NoBatchDist_PMix{000,025,075,100}\`；框架 `PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_pMixSweep/`；巡检 `c97ea7d7`。**已核对**：四变体与 Full 的 `private/` 同构、主类只差 pMix 硬编码 ⇒ 不串味、PMix050 与 Full 逐位一致。**未使用**：`..._NoBatchDist_PMix_Sensitivity_M20`（16 题×1600 跑版，口径不同）。
  - ⚠️ 实测**单跑 wall ≈493 s（440–550，n=86）、每切片 10 跑 ≈1.39 h**，远高于旧假设 220–290 s（14 路对 12 核超订 ~1.9×），但池效率仍 ~95% ⇒ **不要改 MAXJOBS**。观测吞吐 ~99 跑/h。
- 🟢 **FE500 / M=20 七算法全系列 —— 后台 `7CMxJT`，16 路**；范围、六个坑、单跑 wall 见 `REFERENCE.md`。要点：7 算法×16 题×20 跑=2240、maxFE=500、落盘 `20目标\FE500\<算法>\`；**PCSAEA/SAMOEATL2M/HES_EA 用原版类**；键名≠类名（`SAMOEA` 的类/目录是 `SAMOEATL2M`）。
- 🔴 **HES_EA_N100**：M=10 **停在 94/320**（09-19 16:02 用户要求停）。死因 = `NewArc` 为空时外层 `while NotTerminated` 死循环（FE 停滞、CPU 空转、永不落盘；卡死率 ~12%，快速收敛题高发）。修复方案（待用户确认）：NewArc 空则 GA 兜底耗完预算——对正常完成的 run 可证明无操作，已落盘 94 个不受影响。恢复：`cd Experiments/HES_EA_N100_M10 && bash driver.sh` → `chain_to_M15.sh` 自动接 M15。**M=15 未启动**（0/320，框架就绪）：OutputRoot=`15目标`、SeedBase=**21760912**、16 题 D=30。巡检 `80de3726` 已 PAUSED。
- ✅ 已完成：M=20 消融 `REMO_noBatchDict_{noCDIS,noPAQC}` 640/640（PAQC 与 CDIS 都不冗余：去 PAQC +6.27/p=1.4e-8、去 CDIS +3.91/p=4.3e-9、PAQC 更关键；去批距项反而略好 −1.45，p=0.026）；`k_eff=min(N,max(6,ceil(1.5M)))`。RWMOP11 140/140（HV 垫底，但 D=3 时 REMO 族初始仅 32 点 vs 基线 100 点，须连初始规模一起读）。pMix 敏感性 1200/1200，结论 **pMix=0.50 最稳健**（显著优于 0.75/1.00，与 0.25 无统计差异；pMix=0 最危险）。M=20 基线 320/320；Weighted WFG M=15、M=8(D=10) 各 270/270。待办：Weighted M=5(D=10) 停在 159/270。
- 分工：**用户亲自跑重活，AI 负责开发/归档/自动化**；长任务先预估时长与排程间隔。

## 本机红线（违反就白跑/毁数据）
- Bash 每条命令首行必须 `export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"`（否则 ls/wc/tail/cat 全 not found；再补 `/c/Windows/System32` 后 `tasklist` 可用）。
- 运行脚本/driver/日志一律放 `PlatEMO/Experiments/<实验名>/`（含 logs/）；`tmp/` 会被用户随时清空（曾让 10 路 MATLAB 秒退）。
- 长跑前 `powercfg /change monitor-timeout-ac 0` + `standby-timeout-ac 0`，不合盖（S0 Modern Standby：关显示器即冻结墙钟，09-15 吞掉 5.6 h）。
- 固定种子不能 `rng()`+`platemo()`（本地 platemo.m 会 `rng('shuffle')`）→ 直接构造 problem/algorithm，Solve 前 `rng(seed,'twister')`，模式流传 `'run',r`。`ALG` 的 outputFcn 只能传 `@(varargin)[]`。
- **同一张对比表绝不能混用 maxNumCompThreads**（对 patternnet/fitrsvm 类非中性，会被模型驱动选择混沌放大）。
- Git：**严禁 `pull --rebase`**；两台机器别并发操作同一 .git；🔴 **长实验运行期间禁止在本机 merge/pull**（09-19 事故删掉工作区 905 文件）。恢复：确认无 git 进程 → `rm .git/index.lock` → `git reset --hard HEAD`；然后**先停 driver 再杀 MATLAB**；重启 driver 必须用后台任务方式（前台 `nohup &` 会被工具调用结束连带杀掉）。
- Git push 必须沙箱外 + 清空助手列表：`GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c credential.helper=wincred push origin master`。⚠️ `refs/remotes/*` 写不进去（fetch 报成功但不落盘）→ 直接写 `.git/refs/remotes/origin/master` 一行 SHA，别反复重试 fetch。
- commit message 里的**半角双引号**会提前闭合 `-m "…"` → 用 `git commit -F - <<'EOF'`（`-F /tmp/x` 读不到）。
- MATLAB `-batch` 退出偶发 `0xc0000374` / Access violation（addons 联网检查）：**崩在写盘与 CSV 之后，数据安全**，driver 不看退出码。**切片越短越容易崩** → 长实验用长切片（10 跑/片，156 片全 exit=0）。
- 🔴 **绝不编辑正在运行的 bash 脚本**（bash 按字节偏移增量读取，中途改会错位解析）。
- 🔴 **切片表**：字段 tab 分隔 + `IFS=$'\t'` read，run 用 MATLAB 冒号语法（`1:4`）；python 生成的切片表必须去 CR（`newline='\n'` + 管道 `tr -d '\r'` 兜底）。
- 🔴 **变体类名大小写照抄现有类**：NoBatchDist 族是 `..._NoBatchDist_PMix000`（**大写 P**），旧带批距族是 `..._Lambdat030_pMix000`（小写 p）。写错时 NTFS 能建目录但 MATLAB 报 `Cannot find class` → **新实验先跑 1 跑 smoke 验证类名与参数拼装**。
- 🔴 Git Bash → MATLAB 传路径必须 `pwd -W`（`pwd` 给 `/d/...`，MATLAB 静默失效）。
- ⚠️ **patternnet 算法（REMO/PACDIS）不受"同种子+同线程"逐位复现保证**（同进程内第 1、2 次 Solve 会分岔）→ 等价性断言必须固定槽位（每进程一跑）；20–30 跑统计比较不受影响。
- ⚠️ PowerShell 工具 stdout 不回显 → 结果 `Set-Content` 到临时文件再用 Read 读。
- Edit 偶发报成功但未落盘 → 关键编辑后 Read/Grep 复核。

## 常用口径
- 单跑 wall（M=20/D=30/N=100/maxFE=300，12 路 × threads=1）：DTLZ2≈420 s、WFG1≈383 s、WFG3≈377 s、WFG8≈368 s；**单跑成本几乎不随 M 变化**（M=10 ≈ 0.97×M=20）。
- **NoBatchDist 族**（在线含 IGDp）：独占 M20/DTLZ2 262.7 s；池内 14 路实测 **440–550 s、均值 493 s**（2026-09-24，n=86）⇒ 切片 = 10 跑 ≈ 1.39 h，96 切片 / 14 路 ≈ 9.5 h。
- 进度探针 = 切片日志 `logs/partNN_rX-Y.log`（+ 镜像 `pN_rX-Y_a1.log`），行格式 `[done] <prob> run k | IGD first A -> final B | runtime Xs | wall Ys | ok`；**每跑写两份镜像 ⇒ `[done]` 行数 = 真实跑数 ×2**。`driver.log` 只在切片启动时写行（`[done]` 不进它）。
- 数据文件名取自**算法类名**（不是文件夹名）；NoBatchDist 四档"文件夹名 = 文件前缀 = 类名"。写统计脚本前先 `ls` 确认。
- LaTeX：MiKTeX 25.12 + Strawberry Perl 已装；中文目录下命令行编译须 `env -u LC_ALL -u LANG latexmk ...`。
