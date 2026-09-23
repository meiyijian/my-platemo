# 项目长期记忆（PlatEMO PACDIS / AdaMaO 研究）

> 本文件只留最高频、最致命的条目；完整细节（环境、坑位、实验框架、数据集、论文）在 `REFERENCE.md`，需要时先读它。

## 现在在哪（截至 2026-09-24 01:05）
- 🟢 **NoBatchDist 版 pMix 敏感性（重跑论文 pMix 表）—— 09-24 00:57 起 14 路跑，01:10 缩为四档**，后台任务 **`B8l4zX`**（原 `iKuQiI` 已停），预计 **≈5–6 h**。口径（用户逐项确认 + 01:10 修订）：**6 题**（DTLZ2/4/7、WFG1/3/8）× M=**10/20** × **4 档**（0/0.25/0.75/1.00）× **20 跑** = **960 跑**；**0.50 档不重跑**——直接采用 Full `..._NoBatchDist` 数据集的 240 行（用户 2026-09-24："050 版本十目标二十目标都不用跑了，我有他的原始数据"；依据 = 题集/种子/参数/线程数全同 ⇒ 按变体规则是同一臂）。N=100、D=30（WFG3 实际 31）、maxFE=300、SaveCount=30；SeedBase M10=**21260912** / M20=**22260912**（`base+1000*题号+run`）；threads=1；**在线同步算 IGD + IGDp**。落盘 `D:\REMOandDREMO测试集\{10目标\n30,20目标}\REMO_..._NoBatchDist_PMix{000,025,075,100}\`。框架 `PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_pMixSweep/`（**96 切片**×10 跑，14 路错峰 25 s）。**动机**：论文 `experiments/pmix_historical_table.tex` 标注 (batch-distance version; IGD)，是带批距旧版跑的，要用当前 Full 版本替换同一张表。巡检自动化 `c97ea7d7-54b3-4d8d-b446-8f6a60698f36`（每小时，有效到 09-24 14:00）。**已核对**：四变体与 Full 的 `private/` 同构、主类只差 pMix 硬编码；`ResolveUniformMixMode`/`PrunedIndicatorSelection` 在两处逐字节相同 ⇒ 变体不串味、且 PMix050 与 Full 逐位一致（这就是能用 Full 数据当 0.50 档的依据）。smoke 实证 PMix000/M20/DTLZ2/run1：IGD 1.43179→1.19075、IGDp 1.16504→0.83286、wall 262.7 s。**未使用**：`..._NoBatchDist_PMix_Sensitivity_M20`（更早铺的 **16 题×M20=1600 跑**版），口径不同，未启动。
- 🟢 **FE500 / M=20 / D=30 七算法全系列 —— 09-21 01:24 起 16 路跑**（用户 01:23："开最大进程跑吧，后台已清"），后台任务 `7CMxJT`，预计 **≈13–14 h**。顺序 `SSDE SAMOEA CSEA PCSAEA REMO PACDIS HES_EA`（便宜→贵；有卡死风险的 HES 放最后）。已完成 **SSDE 320/320**，`SAMOEATL2M 246/320`，总计 567/2240 起跑。规格：7 算法 × 16 题 × **20 跑** = 2240，maxFE=**500**、M=20、D=30（WFG2/3 实际 31）、N=100、每题算 IGDp；落盘 `D:\REMOandDREMO测试集\20目标\FE500\<算法>\`；种子 **22260912 + 1000×题号 + run**。**用户明确：PCSAEA / SAMOEATL2M / HES_EA 一律用原版类**。框架 `PlatEMO/Experiments/FE500_M20_SevenAlgs/`。**巡检自动化 `852747ad-1eec-4afc-a421-6ca505c29ed6`（每小时，有效到 09-21 20:00）**。⚠️ **实测：每 MATLAB 进程约 1.04 GB（SSDE 0.6、REMO 0.6）**（基线空闲 19.9 GB ⇒ 14 路约剩 5 GB，`MIN_FREE_MB=0` 关闭即可）。⚠️ **REMO/PACDIS 在 FE500/M=20 的单跑 wall ≈ 1200–1600 s（20–26 分钟）**，是 FE300（~420 s）的 3 倍以上——**别用旧数线性外推**；16 路对 patternnet 类有内存带宽竞争，**用户选定 14 路**（默认已改 14）。⚠️ **进程数少于 MAXJOBS 时先数"还剩几片"再怀疑节流/内存**——某算法剩余缺口少于 MAXJOBS 片时池子必然填不满（碎片化波尾）。实测单跑 wall：SSDE ≈2–5 s（DTLZ7 约 90–130 s）、SAMOEATL2M ≈110 s、HES_EA ≈628 s。
- 🔴 **FE500 的六个必知点（坑 ①–⑤ 都已修）**：① **末次 FE 严禁严格判等 maxFE**——按批评估的算法必超支（实测 SSDE 500–543），旧判据会让可重驱 driver 永久重算；harness 已加 `FESlack`（默认 0 = 旧行为不变）。② **固定种子下卡死的 run 重驱必定再卡**——已加"投毒"（`mark_poison.py` + `rc_part*.txt` + `poison.txt`；同一片被 timeout 124 杀 ≥2 次即把**列表里第一个没落盘的 run** 投毒并跳过）；`SLICE_TIMEOUT=14400s`。③ **启动节流不能用一个固定值**——`sleep 20` 是为防多进程**同时冷启动**触发 ntdll 堆损坏，但会把切片短于 20 s 的算法（SSDE）卡到只有 2–3 路在跑、CPU 12%；改为 `LAUNCH_GAP=20`（前 `COLD_STARTS=4` 次）+ `LAUNCH_GAP_WARM=5`。④ **内存闸 `MIN_FREE_MB` 默认 0=关闭**（12 路不需要；本机基线空闲仅 ~16.5 GB，14 路才有换页风险）。⑤ **DTLZ7 单跑 wall ~100 s 但 `metric.runtime` 只有 1.5 s**——它的 `GetOptimum` 用 `UniformPoint(N,M-1,'grid')`，M=20 给出 **2¹⁹=524288 参考点**，IGD/IGDp 全轨迹算下来就是 100 s；**看单跑成本必须看日志的 `wall`，不能看 `metric.runtime`**。⑥ 🔴 **算法键名 ≠ 类名**：`SAMOEA` 是 registry 键，**类名与目录名都是 `SAMOEATL2M`**。`driver.sh` 的 `case` 必须两个都收（否则 `exit 2` 会**带走整轮**）；且 python 侧拼 MAT 文件名**必须用类名**（`missing_runs.py` 的 `CLASSES`/`resolve()`），用键名会让整个算法看起来"全缺"。**未知键只跳过 + 末尾汇总，绝不 `exit`**。⚠️ 三个 `11D-1` 型算法（PCSAEA/HES_EA/SAMOEATL2M）初始就吃 329/500 FE，只剩 ~171 给搜索，**报数必须交代**。
- 🔴 **HES_EA_N100 @ M=10 —— 已停止（09-19 16:02 用户要求），94/320 数据有效，等修 bug 后续跑**。死因：**算法死循环**——`HES_EA_N100.m` 外层 `while NotTerminated` 在候选批 `NewArc` 为空时 FE 停滞 → 无限重复（CPU 满载空转、永不落盘）。卡死率 ≈12% 的 run（快速收敛题 DTLZ2/3/4/6 高发），12 槽全堵。**修复方案（待用户确认）**：NewArc 空则 GA 兜底耗完预算——对正常完成的 run 可证明无操作，已落盘 94 个 MAT 不受影响。修复后续跑：`cd Experiments/HES_EA_N100_M10 && bash driver.sh`（只补缺）→ `chain_to_M15.sh` 自动接 M15。
- **HES_EA_N100 @ M=15 —— 0/320，未启动**（框架/驱动/smoke 已就绪；DTLZ2 smoke 正常 285 s/跑，WFG3 smoke 同样卡死=再次佐证 bug）。数据 `D:\REMOandDREMO测试集\15目标\HES_EA_N100`。M15 口径：OutputRoot=`15目标`（无 n30 层）、SeedBase=**21760912**、16 题全 D=30。
- M=10 框架 `PlatEMO/Experiments/HES_EA_N100_M10/`（已入库 commit `b8dbafd`）。两阶段口径：16 题 × 20 跑 = 320，M=10或15/D=30/N=100/maxFE=300/SaveCount=30，MAT 含 `result`+`metric{runtime,IGD,IGDp}`，SeedBase M10=21260912 / M15=21760912（`base+1000*题号+run`）。巡检自动化 `80de3726` 已 PAUSED。git：本机领先 3 个记忆提交未推，远端领先对方 2 个提交（5687a4e），合并推迟到实验结束后。
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
- 🔴 **git commit 的 message 别手写中文引号**：`git commit -m "…"…"…"` 里的中文引号 `"…"` 不会截断（只有 ASCII `"` 会），但**半角双引号**出现在 `-m "…"` 里会提前闭合字符串、把后面当成 pathspec → commit 失败/错收文件。**改用 `git commit -F - <<'EOF'`（stdin heredoc）最稳**；注意 **`-F /tmp/xx.txt` 会报 `could not read log file`**（git.exe 走 Windows 路径翻译，读不到 MSYS 的 `/tmp`），所以 heredoc 用 stdin（`-F -`）而不是临时文件。
- 🔴 推送必须"先清空助手列表、只留 wincred"且在**沙箱外**执行：`GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c credential.helper=wincred push origin master`。
- ⚠️ **`refs/remotes/*` 写不进去**：fetch/update-ref 报成功但不落盘（`git status -sb` 恒 `[gone]`）。绕过 = 用文件写入工具把 `.git/refs/remotes/origin/master` 写一行远端 SHA，别反复重试 fetch。
- MATLAB `-batch` 退出偶发 `0xc0000374`（堆损坏）：崩前写盘的数据安全。**切片越短越容易崩**（2 跑/切片 20 片崩 6 片 vs 10 跑/切片 156 片全 exit=0）→ 长实验用长切片，当"重跑即可"的噪声。
- Edit 偶发报成功但未落盘 → 关键编辑后 Read/Grep 复核。
- 🔴 **绝不编辑正在运行的 bash 脚本**（bash 按字节偏移增量读取，中途改文件会错位解析）。
- 🔴 **切片表格式**：字段 tab 分隔 + `IFS=$'\t'` read，run 列表用 MATLAB 冒号语法（`1:4`）；空格分隔的 `[1 2 3 4]` 会被 `read` 拆散。长跑前先干跑核对字段。
- 🔴 **python 生成的切片表必须去 CR**（09-24 踩）：Windows 上 python stdout 默认 `\r\n`，bash `read` 会把 `\r` 带进最后一个字段（MATLAB 收到 `10\r`）。修法 = `sys.stdout.reconfigure(newline='\n')` **加上** driver 侧 `mapfile … < <("$PY" … | tr -d '\r')` 兜底。
- 🔴 **变体类名的大小写要照抄现有类，别按"命名惯例"推**（09-24 踩）：NoBatchDist 族是 `..._NoBatchDist_PMix000`（**大写 P**），旧带批距族是 `..._Lambdat030_pMix000`（小写 p）。NTFS 不区分大小写而 MATLAB 区分 → 写错时目录能建出来，但 harness 报 `Cannot find class`。**新实验一律先用 1 跑 smoke 验证类名与参数拼装**。
- 🔴 **Git Bash → MATLAB 传路径必须 `pwd -W`**（`pwd` 给 `/d/...`，MATLAB 静默失效）。
- `ALG` 的 outputFcn 只能传 `@(varargin)[]`（`@(v)[]` 报 `MATLAB:TooManyInputs`）。
- ⚠️ **patternnet 算法（REMO / PACDIS）不受"同种子+同线程"逐位复现保证**（同进程内第 1、2 次 Solve 会分岔），**跨进程同槽位才逐位一致** → 等价性断言必须固定槽位（每进程一跑）；20–30 跑统计比较不受影响。

## 记忆文件自动提交推送（09-16 用户授权，长期有效）
- 只要本轮改动了 `.workbuddy/memory/**`，**收尾自动提交推送、不再询问**：`git add -- .workbuddy/memory` → `git commit -m "chore(memory): <一句话>" -- .workbuddy/memory` → 沙箱外推送（写法见上）。
- **只用显式 pathspec `.workbuddy/memory`，绝不 `git add -A` / `git add .`**。`~/.workbuddy/*.md` 不在本仓库内、无远端可推。

## 常用口径
- 单跑 wall（M=20/D=30/N=100/maxFE=300，12 路 × threads=1）：DTLZ2≈420s、WFG1≈383s、WFG3≈377s、WFG8≈368s；**单跑成本几乎不随 M 变化**（M=10 ≈ 0.97×M=20）。
- **NoBatchDist 族**单跑 wall（maxFE=300、**在线含 IGDp**）：DTLZ2/M20 独占 262.7 s；池内 12 路实测 220–290 s ⇒ 1200 跑 / 14 路 ≈ **9–10 h**，120 切片 / 14 路 ≈ 每片 58 min。
- ⚠️ **沙箱内跑 MATLAB `-batch` 每次退出都崩**（`Access violation` 0xc0000005，栈在 `addons_registry_core → libxml2 → httpclient` = Add-On 联网检查）：**崩在 MAT 写盘与 CSV 之后**，数据安全，driver 不看退出码所以无害；`%TEMP%` 会累积 `matlab_crash_dump.*`。用户手动在终端跑（无沙箱）不一定复现。
- 进程池利用率≈98% → 总墙钟 ≈ 切片数 × 65 min / 12（1200 跑 = 120 切片 ≈ 10.5 h）。
- 进度探针 `logs/stdout_<切片>.log`，行格式 `[done] <prob> run k | IGD A -> B | runtime Xs | wall Ys | ok`。
- 数据文件命名取自**算法类名**（不是文件夹名）；09-16 起 Lambdat030 的 pMix 五档已各自建类（文件夹名 = 文件名前缀 = 类名），更早的是"同算法类不同参数、文件名相同、靠文件夹区分"。写统计脚本前先 `ls` 确认。
- LaTeX：MiKTeX 25.12 + Strawberry Perl 已装好；中文目录下命令行编译须 `env -u LC_ALL -u LANG latexmk ...`。
