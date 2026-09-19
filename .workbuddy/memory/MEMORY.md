# 项目长期记忆（PlatEMO PACDIS / AdaMaO 研究）

> 本文件只留最高频、最致命的条目；完整细节（环境、坑位、实验框架、数据集、论文）已归档到同目录 `REFERENCE.md`，需要时先读它。

## 现在在哪（截至 2026-09-19 06:55）
- **M=20 新消融：REMO_noBatchDict_noCDIS / _noPAQC —— ✅ 完成 640/640**。两算法 × 16 题（DTLZ1-7+WFG1-9）× 20 跑，M=20/D=30/N=100/maxFE=300/SaveCount=30，种子同既有 20 目标数据集（SeedBase=22260912，`base+1000*题号+run`，**逐跑配对**）。数据 `D:\REMOandDREMO测试集\20目标\REMO_noBatchDict_{noCDIS,noPAQC}\`（各 320，全量校验 OK=320/BAD=0）。耗时 6 h 55 min 一次跑完。框架 `PlatEMO/Experiments/REMO_noBatchDict_Ablation_M20/`（driver/missing_runs/verify/probe_k/smoke/compare）。
  - **四臂配对结论（`compare_M20_ablation.csv`）**：**PAQC 与 CDIS 都不冗余** —— 去 PAQC 平均 gap +6.27（Fisher p=1.4e-8，142/320 胜）、去 CDIS +3.91（p=4.3e-9，132/320 胜），且 PAQC 比 CDIS 更关键（p=9.2e-15）；**去掉批次距离项反而略好**（−1.45，p=0.026）。逐题主输点：去 PAQC 输 DTLZ3/DTLZ7/WFG2，去 CDIS 输 DTLZ3/WFG9/WFG4/WFG5。
  - ⚠️ 报告口径：16 题平均被 DTLZ1/DTLZ3 主导，**主口径用逐题均值 + 配对胜负比 + 逐题 p**。
  - 🔴 `k` 已经是 1.5M，源码未改：`k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)))`，M=20 → k=30（实测 16/16 精确 1.5×M）。WFG2/WFG3 在 M=20 时**真实 D=31**。
  - 🔴 **harness `'Runs'` 只做 `isscalar` 判断，而 MATLAB 里 `isscalar([99])` 就是 `true`** → 单元素向量也会被展开成 `1:Runs`。**该 harness 无法只跑一个 run**，最短请求是两元素向量。单跑 runtime 实测：noCDIS ≈ 389 s、noPAQC ≈ 438 s（12 路并行）。

- **HES_EA_N100 @ M=10 —— 🔄 进行中（2026-09-19 10:03 启动，320 跑）**。用户要求只跑十目标（20 目标暂不跑），16 题 × 20 跑，M=10/D=30/N=100/maxFE=300/SaveCount=30，SeedBase=**21260912**（与 10 目标数据集逐跑配对）。数据 `D:\REMOandDREMO测试集\10目标\n30\HES_EA_N100\`，每个 MAT 含 `result` + `metric{runtime, IGD, IGDp}`（**IGDp 边跑边存**）。框架 `PlatEMO/Experiments/HES_EA_N100_M10/`（runner/driver/missing_runs/verify/smoke）。预计 2–3 h（单跑 ≈166 s）。
  - 🔴 超参必须传 `'Parameters',{}` 走论文默认 `{wmax,WN,KMeans}`=`{20,190,4}`；传 harness 默认 5 元组会把 KMeans 设成 0.25 直接报错。
  - 🔧 已给共享 harness 增加**可选**参数 `ExtraMetrics`（默认 `{}`，对既有实验零影响），用于把 IGDp 等附加指标在跑的同时写进 MAT（替代事后 merge 重算）。
  - ⚠️ HES_EA_N100 第 75 行 `pdist2(...,'cosine')` 在 WFG3 这类问题上会刷 `stats:pdist2:ZeroPoints` 警告，需在 runner 里压制（算法本身已有 clamp，警告无副作用）。

- **RWMOP11 真实问题实验（新增主线）：✅ 完成 140/140**。七个算法 = PACDIS + 论文六基线（REMO/PIEA/CSEA/PC-SAEA/K-RVEA/MCEA-D），**全部统一注入标准 feasibility-first 规则（CDP）**；M=5、D=3、N=100、maxFE=300、20 跑、threads=1。数据 `D:\REMOandDREMO测试集\5目标\n3\<算法>_CDP\`（`result`+`metric{HV,Feasible_rate,runtime}`）；框架在 `PlatEMO/Experiments/RWMOP11_WaterResource/`（**该目录在 .gitignore 内、不受版本控制**，与 pMixSweep 同例；含 README/VERIFICATION/RESULTS/LaTeX 表）。
  - **结果（20 跑均值）**：HV = CSEA 0.0986 > REMO 0.0973 > K-RVEA 0.0954 > PIEA 0.0952 > MCEA/D 0.0919 > PC-SAEA 0.0888 > **PACDIS 0.0878（垫底，与各基线秩和 p≤1e-5 或 0.29）**；可行率 = REMO 0.933 > MCEA/D 0.914 > PC-SAEA 0.904 > **PACDIS 0.864** > K-RVEA 0.846 > CSEA 0.816 > PIEA 0.670。
  - 🔴 **必须与初始规模一起读**：D=3 时 REMO 族（含 PACDIS）初始只有 32 点（`11D-1`），其余算法 100 点 → 初始 HV 起点差 27%（0.0578 vs 0.0730）；两组终态 HV 均值几乎相同（0.0946 vs 0.0928），但 32 点组搜索增益近两倍（+0.0368 vs +0.0198）。同起点组内 PACDIS 增益（+0.0300）仍低于 REMO（+0.0395）/CSEA（+0.0409）。
  - CDP 补丁**已证明零改动**：无约束 DTLZ2 上跨进程同槽位原版 vs CDP **逐位一致**（IGD 轨迹 max|Δ|=0、终态目标矩阵相同）；`NDSort(F,[],k)≡NDSort(F,k)` 160 组零差异。

- 主线：**pMix 敏感性扫描 —— ✅ 已完成 1200/1200**（09-15 16:28 起两轮，累计约 10 h 50 min；第二轮 09-16 01:24→08:19 补完 761 跑）。全量校验通过（缺失 0 / 失败 0 / MAT-only / 无待机污染），IGD 已导出 CSV。
- ✅ **已改为"一档一类"并归档推送**（commit `56dddd9`，已 push origin/master）：新增 5 个专用算法类 `REMO_UniformMix_Pruned_Weighted_Lambdat030_pMix{000,025,050,075,100}`（各 = 1 类文件 + 自带 `private/` 14 个文件，与 `_Lambdat050` 房规一致），**pMix 在类里写死，参数表由 5 个变 4 个** `{gmax,rGood,qKeep,nMax}` = `{3000,0.25,0.70,6}`。等价性**已逐位证明**（40/40，max|ΔIGD|=0，比对完整 30 快照 IGD 向量）→ 因此**没有重跑**，直接把 1200 个 `.mat` 改名归并（**文件夹名 = 文件名前缀 = 类名**，每组 240 = M10 120 + M20 120）。结论文档 `docs/2026-09-16-Lambdat030-pMix敏感性扫描结论.md`（**受 git 管理**）。
- **pMix 扫描的结论（可直接引用）**：pMix=0.50 是**最稳健的默认值**——12 个 (M,问题) 格中平均秩最低（2.621）、最差秩最小（3.00），合并 240 配对块 Friedman p<1e-6，且**显著优于 pMix=0.75（Holm p=0.030）与 pMix=1.00（Holm p=0.00036）**。**但不能说"处处最优"**：只在 2/12 格夺冠，且**与 pMix=0.25 无统计差异（Holm p=1.0）**。效应方向随问题翻转：DTLZ2/WFG3 偏好高 pMix，DTLZ7/WFG8 偏好低 pMix，**DTLZ7 最敏感（pMix=1 相对 0.5 差 +81%/+74%）**；pMix0 vs pMix1 合并 p=1.0（极端臂互补，故折中值平均秩占优）；**pMix=0 最危险**（DTLZ2 差 +30.9%）。完整表见该目录 `RESUME_STATUS.md` 第 9 节。
- 数据目录族 `D:\REMOandDREMO测试集\<M>目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030_pMix{000,025,050,075,100}`（M=20 无 n30 层）；巡检自动化 `87c95710-...` 已置 PAUSED（实验结束）。
- 固定参数序 `{gmax,pMix,rGood,qKeep,nMax}` = `{3000, 0.50, 0.25, 0.70, 6}`；默认 N=100、D=30、maxFE=300。
- 已完成：M=20 基线 320/320；Weighted WFG sweep M=15、M=8(D=10) 各 270/270。待办：Weighted M=5(D=10) 停在 159/270。
- 分工：**用户亲自跑重活，AI 负责开发/归档/自动化**；长任务先预估时长与排程间隔。

## 本机红线（违反就白跑/毁数据）
- Bash 每条命令首行必须：
  `export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"`
- **运行脚本/driver/日志一律放 `PlatEMO/Experiments/<实验名>/`（含 logs/）**；`tmp/` 会被用户随时清空（曾让 10 路 MATLAB 秒退）。
- **长跑前必须** `powercfg /change monitor-timeout-ac 0` + `standby-timeout-ac 0`，不合盖（本机 S0 Modern Standby，显示器关闭即冻结墙钟，09-15 吞掉 5.6 h）。
- 固定种子不能 `rng()`+`platemo()`（本地 platemo.m 会 `rng('shuffle')`）→ 直接构造 problem/algorithm，Solve 前 `rng(seed,'twister')`，模式流传 `'run',r`。
- **同一张对比表绝不能混用 maxNumCompThreads**（对 patternnet/fitrsvm 类算法非中性，会被模型驱动选择混沌放大）。
- Git：**严禁 `pull --rebase`**（0914 事故清空 refs/objects）；两台机器别并发操作同一 .git。
- 🔴 **推送必须用"先清空助手列表、只留 wincred"的写法**（09-16 实测：光加 `-c credential.helper=wincred` **不够**）：
  `git -c credential.helper= -c credential.helper=wincred push origin master`
  原因：`PortableGit/etc/gitconfig` 配了 `helper-selector`、`~/.gitconfig` 配了 `git-credential-manager.exe`，两者都会拉起 GUI 并**被 SIGTERM 杀掉**，且输入法 DLL 日志污染凭据协议输出 → git 报 `warning: invalid credential line: ... [tsf_oime.cpp:7276] DllGetClassObject ...`。**必须在沙箱外执行**（`dangerouslyDisableSandbox`），并加 `GIT_TERMINAL_PROMPT=0` 防交互；fetch/ls-remote 同法。
- ⚠️ **`refs/remotes/*` 写不进去（0914 后遗症+环境拦截）**：`git fetch` / `git update-ref` 对本仓库的 `refs/remotes` **报成功但不落盘**（`exit=0` 且打印 `[new branch] master -> origin/master`，随后 `git rev-parse origin/master` 就 `exit=128`），于是 `git status -sb` 恒显示 `[gone]`。已排除目录权限/原子 rename/外部清理（`echo`+`mv` 与手写文件都正常，`refs/heads` 也正常）。**绕过：用文件写入工具直接把 `.git/refs/remotes/origin/master` 写成一行远端 SHA**，git 立刻可读（`## master...origin/master`）。别反复重试 `git fetch`。
- MATLAB `-batch` 退出偶发 `0xc0000374`（堆损坏）：崩溃前写盘的数据安全；长跑配"守护+断点续跑"。**切片越短越容易崩**——等价性校验用"2 跑/切片"时 20 片崩 6 片，而主扫描"10 跑/切片"156 片**全部 exit=0**；已用**基类、同样配置的对照实验**证明与具体算法类无关（基类 6 片崩 5 片）。长实验优先用长切片，把堆损坏当"重跑即可"的噪声。
- Edit 偶发报成功但未落盘 → 关键编辑后 Read/Grep 复核。
- 🔴 **绝不编辑正在运行的 bash 脚本**（本次因此废掉 5 个等价性进程）：bash 按字节偏移增量读取脚本，中途改文件会让它从错位处继续解析（`line N: eep: command not found` + `syntax error near 'done'`）。要改就先停脚本。
- 🔴 **切片表格式**：字段用 **tab 分隔 + `IFS=$'\t'` read**，run 列表用 MATLAB 冒号语法（`1:4`）；用空格分隔的 `[1 2 3 4]` 会被 `read` 拆散成 `[1` + `2 3 4]`（本次空转 30 s）。长跑前先干跑一遍解析循环核对字段。
- 🔴 **Git Bash → MATLAB 传路径必须 `pwd -W`**（`pwd` 给 `/d/...`，MATLAB 静默失效或建到 `D:\d\...`）。
- `ALG` 的 outputFcn 只能传 `@(varargin)[]`（`@(v)[]` 会报 `MATLAB:TooManyInputs`，NotTerminated 传 2 参）。
- ⚠️ **patternnet 算法（REMO / PACDIS）不受"同种子 + 同线程"的逐位复现保证**：同一进程内第 1 次 Solve 与第 2 次 Solve 会分岔（实测同算法自身对照 max|ΔIGD| = 1.1e-1 / 1.4e-1，与"补丁 vs 原版"完全相同），而**跨进程同槽位逐位一致**。→ 凡"逐位复现/等价性"断言必须固定槽位（每进程一跑）；20–30 跑的统计比较不受影响。其余五算法（CSEA/PC-SAEA/K-RVEA/PIEA/MCEA-D）在本次对照中逐位可复现。

## 记忆文件自动提交推送（09-16 用户授权，长期有效）
- 只要本轮改动了 `.workbuddy/memory/**`（`MEMORY.md` / `REFERENCE.md` / `YYYY-MM-DD.md` / `automations/*/memory.md`），**收尾时自动提交并推送，不再询问用户**：
  `git add -- .workbuddy/memory` → `git commit -m "chore(memory): <一句话>" -- .workbuddy/memory` → 沙箱外 `GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c credential.helper=wincred push origin master`
- **只用显式 pathspec `.workbuddy/memory`，绝不 `git add -A` / `git add .`**（工作区有大量实验数据、未跟踪产物与 `agent-skills/`）。
- `~/.workbuddy/*.md`（用户级记忆）不在本仓库内、也无独立仓库，无法推送；本仓库只管工作区记忆。

## 常用口径
- 单跑 wall（M=20/D=30/N=100/maxFE=300，12 路 × threads=1）：DTLZ2≈420s、WFG1≈383s、WFG3≈377s、WFG8≈368s；**单跑成本几乎不随 M 变化**（M=10 ≈ 0.97×M=20）。
- 进程池利用率≈98% → 总墙钟 ≈ 切片数 × 65 min / 12（1200 跑 = 120 切片 ≈ 10.5 h）。
- 进度探针：`logs/stdout_<切片>.log`，行格式 `[done] <prob> run k | IGD A -> B | runtime Xs | wall Ys | ok`。
- 数据文件命名取自**算法类名**（不是文件夹名）。⚠️ 口径有两代：**09-16 起 Lambdat030 的 pMix 五档已各自建类，文件夹名 = 文件名前缀 = 类名**；更早的数据是"同一算法类、不同参数的多臂文件名完全相同、只靠文件夹区分"。写统计脚本前先 `ls` 确认，别硬编码。
- LaTeX：MiKTeX 25.12 + Strawberry Perl 已装好；中文目录下命令行编译须 `env -u LC_ALL -u LANG latexmk ...`（否则 Perl 写 .aux 失败）。详见 REFERENCE.md。
