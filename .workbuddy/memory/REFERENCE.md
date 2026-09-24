# REFERENCE.md —— 项目细节归档（自 MEMORY.md 拆分，2026-09-15）

MEMORY.md 只留高频/致命条目，本文件保存完整细节。

## 本机环境硬事实
- Bash 每条命令首行：`export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"`。PowerShell 工具 stdout 不回显，别用。
- MATLAB R2021b `/d/software/mathlab/bin/matlab.exe`；`checkcode`/`pcode` 在 `-batch` 下可用；UTF-8 .m 中文字面量正常，中文路径不必转 GBK。
- **LaTeX 环境（09-15 建好）**：MiKTeX 25.12 在 `C:\Users\lsx\AppData\Local\Programs\MiKTeX\miktex\bin\x64\`（pdflatex/latexmk/kpsewhich/initexmf），已设 `[MPM]AutoInstall=1` 免弹窗；latexmk 需 Perl，补装 **Strawberry Perl 5.42** 在 `C:\Strawberry\`。`论文写作/HPDC-MaOEA.tex` 实测编译通过：11 页、0 错误/0 未解析引用（elsarticle `[final,5p,times,twocolumn]` + amsmath/booktabs/algorithm 等）。编译产物全在 `.gitignore` 覆盖范围内。
  - 🔴 bash 会话的 `LC_ALL=C.UTF-8` 会让 Strawberry Perl 在中文目录下写文件失败（`ERROR_NO_UNICODE_TRANSLATION`，latexmk 报 `Cannot write file '*.aux'`）→ 命令行编译必须 `env -u LC_ALL -u LANG latexmk ...`；VSCode 里构建不受影响，别误判为"perl 不支持中文路径"。
  - ⚠️ `HPDC-MaOEA.tex` 的 magic comment `% !TeX program = pdflatex` 使 LaTeX Workshop 只跑**单遍** pdflatex（recipe.js `createMagicTools` 在无 `% !BIB program` 时只返回 `[pdflatex]`）→ 干净重建时 `\ref`/`\cite` 全变 `??`。修法 = 换成 `% !LW recipe = latexmk`（须替换而非追加）。**待用户决定是否改**（改 .tex 会触发论文写作/AGENTS.md 的自动提交+推送）。
  - 诊断 TeX 编译问题最快路径：读 `%APPDATA%/Code/logs/<最新时间戳>/window*/exthost/output_logging_*/N-LaTeX Workshop.log`。
- MATLAB `-batch` 退出偶发 `0xc0000374 堆损坏`：发生在写盘后，数据安全；长跑须配"进程守护 + 断点续跑"。
- Edit 工具偶发报成功但未落盘 → 关键编辑后 Read/Grep 复核；.m 行级插入用 sed 更稳。
- 本仓 .m 是 CRLF；Write 产出 LF，需 `sed -i 's/$/\r/'` 补回。
- heredoc 里中文会丢：`python - <<'PY'` 走 stdin，Windows 按 GBK 解码 UTF-8 字节 → 含中文模式串必匹配失败（`AssertionError: 0`）。heredoc 内的匹配/替换模式串只用 ASCII，或 `open(...,'rb')` 二进制替换 / 改用 Edit。MATLAB 输出、`tasklist`、`wevtutil` 是 GBK，管道加 `iconv -f GBK -t UTF-8`。
- Python venv `C:/Users/lsx/.workbuddy/binaries/python/envs/default`（python.exe 在 `Scripts/`，已装 openpyxl）。
- ⚠️ `D:\PlatEMO-master\tmp\` 会被用户随时清空（明确要求"别乱放文件"）。09-15 曾因此让 10 路 MATLAB 分片全秒退（报 `未定义与 'double' 类型的输入参数相对应的函数 'xxx'` = 函数根本没解析到，不是参数问题）。**运行脚本/driver/日志一律放 `PlatEMO/Experiments/<实验名>/`（含 logs/）**，只有可随时丢弃的中间产物才放 tmp。
- 🔴 长跑必须防待机（09-15 事故吞掉 5.6 h）：本机是 **Modern Standby（S0）** 设备，"睡眠=永不"挡不住 —— 显示器空闲关闭（平衡计划 `VIDEOIDLE` 交流=600 s）即进 S0，所有 MATLAB 墙钟冻结。启动前 `powercfg /change monitor-timeout-ac 0` + `standby-timeout-ac 0`，不合盖。排查：Kernel-Power 事件 506/507，原因字段写 `AC/DC Display Burst`；`powercfg /lastwake` 佐证。**次生缺陷**：冻结窗口内那跑的 `metric.runtime` 被记成 ~21000 s（IGD/Pop 仍有效，终止按 maxFE 计）→ 校验时抓 `runtime > 600 s`。

## 关键坑（血泪）
- 固定种子不能 `rng()`+`platemo()`（本地 platemo.m 会 `rng('shuffle')`）；须直接构造 problem/algorithm，Solve 前 `rng(seed,'twister')`；模式流要传 `'run',r` 才独立（`10000000+runId`）。
- 加权前用欧氏距离，不能用平方距离。
- WFG 的 D 自动调整 `ceil((D-K)/2)*2+K`（K=M-1）：M=10/20 时 WFG2/3 D=31；M=15/M=5 保持 D30/D10；M=8 时 D=11。文件名用 Problem.D，别手工"纠正"。
- harness 里 Solve 后必须先 `ALG.CalMetric('IGD')` 再取 metric（struct 是值类型）。
- 🔴 `maxNumCompThreads` 不是行为中性的：对含 `patternnet`/`fitrsvm` 的算法，它只改浮点归约顺序，却被后续几十轮"模型驱动候选选择"混沌放大。实测该算法 WFG1/M=20/run1：threads=2 旧基线 vs threads=1 新跑，FE 列表与前 5/30 个 IGD 快照逐位相同，第 6 个起分岔，最终 IGD 差 4e-3~1e-1。**同一张对比表绝不能混用线程数**；跨线程数不期待逐位一致（差异是数值随机、非系统性偏置，20+ 种子的统计比较仍成立）；消融各臂必须同线程数。
- 数据文件命名取自**算法类名**，不是文件夹名：同算法类不同参数的多臂（如 pMix 五臂）文件名完全相同，靠文件夹区分；校验/统计脚本的模式串用类名。
- 三版本间无共同初始样本（仅 run 号对齐）→ 用 exact Wilcoxon 秩和；同种子同 run 号才用配对设计（参考 `compare_qkeep.py`）。
- 🔴 内层 PlatEMO 树整棵在 MATLAB path 上：harness 的 `addpath(genpath(PlatEMORoot))` 会加入 `D:\PlatEMO-master\PlatEMO-master\PlatEMO` 全树 701 个文件夹，**包括 `Experiments\**` 与 `logs\`**。辅助脚本若与内置函数同名（如 `diag.m`），`which` 会指向你的文件并每次刷中文警告。**实测是纯噪声、非数据污染**（`diag([1 2 3])` 仍返回内置正确结果）。修法=重命名（`logs/diag.m` → `logs/pmix_igddiag.m`）。**规矩：Experiments 下的辅助脚本一律加 `pmix_*` 前缀，不碰内置名。**
- WFG 长跑偶发"全体一起变慢"（09-15）：8 个进程各有一个 run 耗时 21000–21200 s（正常 330–480 s），值趋同 ±0.4%、起止几乎相同 → 像共同外部瓶颈（磁盘/内存/定时任务）；次日 09:06 补跑同批仅 39 min 完成、未重现。排期留余量，但别按"每 WFG 问题 +6 h"估。

## 排期口径（09-15 实测，必读）
- 🟡 **单跑成本几乎不随目标数 M 变化**：耗时由 patternnet/fitrsvm 训练主导，只取决于 D、N（各 M 下都是 D=30/N=100），M 只影响 RefSelect/IGD 零头。实测 M=10/M=20 代价比：REMO 各题 0.92–1.16（均值 1.01）、REMO_new2 0.85–1.02、REMO_new2_AdaMaO 1.19–1.28；同框架 M=10(n30) ≈376 s vs M=20 ≈392 s。**按 M=10 ≈ 0.97×M=20 估，别按 0.5–0.8 估。**
- 本算法（M=20/D=30/N=100/maxFE=300）12 路并行 × threads=1 实测单跑 wall：DTLZ2 ≈420 s、WFG1 ≈383 s、WFG3 ≈377 s、WFG8 ≈368 s；外推 DTLZ4 ≈430 s、DTLZ7 ≈320 s。**DTLZ 比 WFG 更贵**，与直觉相反。
- 进程池利用率 ≈98%（切片长 10 跑，启动开销 ~50 s/切片可忽略）→ 总墙钟 ≈ 切片数 × 65 min / 12，只需 +5% 余量。1200 跑（120 切片）≈ **10.5 h**，不是 8–9 h。
- 进度探针/日志行格式：切片日志 `logs/stdout_<切片>.log`，行为 `[done] <prob> run k | IGD first A -> final B | runtime Xs | wall Ys | ok`（是 `wall 361.4s`，**没有等号**）。

## 数据集与实验框架
- 数据根 `D:\REMOandDREMO测试集\<M>目标\n<D>\<算法名>\`，文件名 `<算法>_<问题>_M<M>_D<D>_<run>.mat`，内容 `result`（{FE,Pop} cell）+ `metric`（runtime/IGD，IGD 末位=最终值）。
- 标准模板：`PlatEMO/Experiments/<名字>/run_*.m`（4 分区轮转、断点续跑、.mat 带 metadata）+ `verify_*.py`（校验 seed/params/FE）+ `tmp/supervise_part.sh`（已泛化：`ALG/FOLDER/PARAMS/HARNESS/FUNC/OUTDIR/SCRATCHROOT`）。
- Weighted 论文种子 `20260912 + M*100000 + p*1000 + r`（p：DTLZ1-7→1..7，WFG1-9→8..16），modeRunId=1、save=30。
- 「参数变体复制」验收：旧类+旧参 / 旧类+新参 / 新类+新参 三组同种子；后两组须差 0 且与第一组不同。
- 共享 harness `Experiments\REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries\run_UniformMixPrunedFullSeries.m` 已加可选参数 `SummaryCsvDir`（向后兼容，默认空=写结果目录）。传 logs 目录可让数据目录保持 MAT-only，并避免同问题的并行切片互相覆盖 `_runlog_partNNof16.csv`；复用时优先传它。
- **pMix 只影响 `ResolveUniformMixMode` 的模式选择，不进入随机数流**（`u = rand(modeStream,1)` 每轮无条件抽取）→ 同 (问题, run) 改 pMix 不扰动随机序列，多臂共享随机数、差异纯来自准则选择；pMix/模式类消融可直接复用同种子做配对比较。
- pMix 扫描框架：`PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_pMixSweep\`（`run_pMixSweep.m` 单切片 / `driver_pMixSweep.sh` 120 切片进程池 / `progress_pMixSweep.sh` 进度探针 / `verify_pMixSweep.m` 校验+导出 `pMix_finalIGD.csv`）。规模 5 pMix × 6 题 × M=10/20 × 20 跑 = 1200；数据目录 `REMO_UniformMix_Pruned_Weighted_Lambdat030_pMix{000,025,050,075,100}`（M=10 在 `10目标\n30\`，M=20 在 `20目标\`）。切片名如 `pMix050_M20_p02_r1-10`（p02=DTLZ2，p08=WFG1、p10=WFG3、p15=WFG8）。
- **进程池驱动模板**：切片写进 bash 数组、重活优先排队、`while [ "$(jobs -rp|wc -l)" -ge $MAXPROC ]; do wait -n; done` 控并发，比 `xargs -P` 更可控；切片幂等（harness 自带跳过），驱动可随时重启续跑。

## 实验结论
- UniformMix 参数削减族：Pruned（五项同时删减）在 DTLZ2/5 退化；回填 0.75 质量+0.25 距离权重（Weighted）后缓解 → "持续质量约束"是第一嫌疑。qKeep 0.70 vs 0.80 消融 8 胜 8 负无系统差异，可排除。PIEAOnlySelection / FixedIndicatorAlways 在 DTLZ7 崩 2.35×，不可保留。
- Weighted WFG sweep（09-14）：M=15、M=8(D=10) 各 270/270 完成并 verify COMPLETE，per-run CSV 在各自数据目录；M=5(D=10) 停滞于 159/270，待重启续跑。
- PWGGP GoodGroupPrecision（09-14）：`run_TopFourPartition(k,8)` 8 分区×25=200，maxFE=500，单跑 wall ~715–820 s。输出在内层 `Experiments\REMO_new2_AdaMaO_PrunedWeighted_GoodGroupPrecision\results\`；`logs/partitionN_status.json` 含 Completed/Total/MeanWallSeconds（算 ETA 直接读）。⚠️ `RunPaperWeighted30.m` 原配 C 盘数据根已消失，D 盘老基线完好；重跑前删 `...Weighted/diagnostics/paper_30runs/RUNNING.lock`。

## 论文（PACDIS）
- 命名：HPDC-MaOEA→PACDIS，HPC→PAQC（PBI-Assisted Quality Classification），候选模块→CDIS；旧图标注需同步。
- 实现对应 REMO_UniformMix_Pruned_Weighted_Lambdat030；原始参数检查点 `paper-original-params-20260914`。
- `论文写作/HPDC-MaOEA_1param.tex`：探索分支 `A_k=R̃+β·E_k`，β→0 对应被否定的纯关系排序格，β 敏感性是必做 \TODO。
- 09-11 曾发生 论文写作/ 227 文件批量进回收站（非会话所为），已 git restore 恢复；origin/master 是离线安全网。

## RWMOP11 真实问题实验（2026-09-17 建，140/140 完成）
- 框架目录 `PlatEMO/Experiments/RWMOP11_WaterResource/`（**在 .gitignore 内，不受版本控制**）。主线算法目录改动 **0 处**：七个算法是 `algorithms/` 下的完整副本（类名后缀 `_CDP`，含 `private/`），`tools/apply_cdp_patches.py` 是补丁的唯一来源（幂等 + 断言 + 逐字符 diff 可核对）。
- CDP 落点（都是"对真实评价解做保留/替换决策"处）：`RefSelect` 的 `NDSort(PopObj,Population.cons,k)`（PACDIS/REMO/CSEA）；`ESCalFitness` 显式 CDP 支配比较（PC-SAEA）；`UpdataArchive` 训练档案可行优先填满 `NI-mu`（K-RVEA）；切比雪夫替换改字典序 `(CV,g)`（MCEA/D）；层次评价 `NDSort(A.objs,A.cons,1)`（PIEA，它没有定规模保留集）。
- 问题：`Problems/Multi-objective optimization/RWMOPs/RWMOP11.m`（M=5、D=3、7 约束、`GetOptimum` 给 HV 参考点）。**六个基线原本都不读 `.cons`**（全库 grep 可证），所以必须显式注入。
- 数据 `D:\REMOandDREMO测试集\5目标\n3\<算法>_CDP\`；种子 `20777912 + run`（= 论文式 `20260912+5*100000+17*1000+run`，RWMOP11 记为第 17 题）。切片表 `slices.txt`（20 片、重活优先）+ 驱动 `driver_RWMOP11.sh`（MAXPROC=12、错峰 25 s）。
- 关键口径：HV 用 PlatEMO 内置（`SOLUTION.best`=可行非支配，参考点 `GetOptimum`）；M=5 走 1e6 次 MC → **每次算指标前 `rng(987654321)`** 让所有跑共享随机数。Feasible_rate（PlatEMO 内置）= 算法报告的**整个档案**的可行比例（PACDIS/REMO/CSEA 末档 300、CSEA 303.5），初始设计可行比例 ~0.91 会稀释该项且稀释权重随初始规模不同。`runtime` 在 12 路池下比单跑口径膨胀约 2 倍（PACDIS 单跑 113 s → 池内 227.6 s），**不要跨口径比较耗时**。
- 复现：`matlab -batch "verify_RWMOP11WaterResource"` → `logs/RWMOP11_{runs,summary,pvalues_vs_reference}.csv`；`diagnose_rmwop11_init` → 初始化规模诊断（把"初始设计"与"搜索增益"拆开）；`python make_rmwop11_table.py` → `RESULTS.md` + `table_rmwop11.tex`（列序 = 六基线 + PACDIS，与主表一致）。等价性四重证据与诊断全文见框架目录 `VERIFICATION.md`。
- 初始化规模事实（D=3）：REMO/PACDIS 32（`11D-1`）、CSEA 32（`min(11D-1,109)`）、PIEA 100（`Problem.N`）、PC-SAEA `_100` 100、K-RVEA `_100` 100、MCEA/D 85–100。→ 真实问题上若要与论文主表口径一致，需要对齐初始样本数（待定，用户未点头前不要动）。

## 归档约定
- 算法级笔记/报告放对应算法目录 `notes/`，诊断放 `diagnostics/<主题>_<日期>/`；项目级周报告放 `D:\PlatEMO-master\docs\`；实验 xlsx 在 Desktop `AdaMao实验表/`。

## Git 环境红线（0914 事故）
- 本机 git 严禁 `pull --rebase`（could not mark as interactive 且清空 refs/objects）。恢复套路：备份零散对象 → ls-files 找缺失 blob → 工作树 hash-object -w 重建 → write-tree → 临时 GIT_INDEX_FILE 手工构造合并提交（模板 `tmp/git_rescue/plumbing_merge.py`）。
- 两台电脑并发操作同一 .git 会互相踩踏（引用消失、文件被删、index.lock），务必错开；一台 push 完另一台再 pull。
- SIGTERM 频发：重 git 操作（merge / reset --hard）易被中途杀死，改用 read-tree + checkout-index 分步对齐；残留 index.lock 确认无 git 进程后可直接删。
- 🔴 **推送（2026-09-16 实测可用路径）**：① 沙箱内无网络 → `git push`/`fetch` 被 SIGTERM **静默杀掉（连 echo 都不执行、无任何输出）**，必须在沙箱外（`dangerouslyDisableSandbox`）执行；② 默认助手 `helper-selector` 会拉起 GCM GUI 挂起（同上被 SIGTERM），且其 stdout 被 `tsf_oime.cpp`（输入法 DLL）日志污染 → git 报 `invalid credential line` + `could not read Username`；③ **可用助手是 `wincred`**（凭据已在 Windows 凭据管理器）：
  `git -c credential.helper=wincred push origin master`（配 `GIT_TERMINAL_PROMPT=0` 防挂起）。
- ⚠️ **`refs/remotes/**` 可能是空的**（`git status` 显示 `[gone]`，`git show-ref` 只剩 heads+tags）：此时 fetch 打印 `* [new branch] origin/master` 也**留不下引用**。恢复办法是 shell 直接写文件 `.git/refs/remotes/origin/<branch>`（内容为 40 位 sha）；**`git update-ref` 在沙箱内报 exit=0 但不落盘**，别被它骗了。

## HES_EA_N100 全系列扫描（2026-09-19 起）
- 目标：HES_EA_N100 在 DTLZ1-7 + WFG1-9（16 题）× 20 跑 = 320/阶段；**用户只跑 M=10 与 M=15**（M=20 暂不跑）。口径 M=10或15 / D=30 / N=100 / maxFE=300 / SaveCount=30；MAT 含 `result` + `metric{runtime, IGD, IGDp}`（IGDp 边跑边存，靠共享 harness 新增的可选参数 `ExtraMetrics`）。SeedBase：M10=21260912、M15=21760912（`base+1000*题号+run`，与既有 10 目标数据集逐跑配对）。
- 数据：`D:\REMOandDREMO测试集\10目标\n30\HES_EA_N100`、`D:\REMOandDREMO测试集\15目标\HES_EA_N100`。框架：`PlatEMO/Experiments/HES_EA_N100_M10/`（入库 commit `b8dbafd`）、`.../HES_EA_N100_M15/`。
- 框架可移植：`driver.sh` 自定位（BASH_SOURCE + `pwd -W`），`MP/PY/DATADIR/MAXJOBS/ROUNDS` 可覆盖；`missing_runs.py` 用 `HESEA_M10_DATA_DIR`；runner 用 `HESEA_M10_OUTPUT_ROOT`。**先停 driver 再杀 MATLAB**（反序会让补缺循环再拉起切片）。续跑 = `git pull` → `cd Experiments/HES_EA_N100_M10` → 防待机 powercfg → `bash driver.sh`（只补缺）。
- `.gitignore:8` 忽略整个 `Experiments/` → 需 `git add -f` 按文件加入（别加目录，会带进 logs/）。同 commit 把**共享 harness** `Experiments/REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries/run_UniformMixPrunedFullSeries.m`（含 ExtraMetrics）也入库了 —— 另一台机器必需。算法 `HES-EA/` 本就在库内。
- 🔴 超参必须传 `'Parameters',{}` 走论文默认 `{wmax,WN,KMeans}`=`{20,190,4}`；传 harness 默认 5 元组会把 KMeans 设成 0.25 直接报错。
- ⚠️ HES_EA_N100 第 75 行 `pdist2(...,'cosine')` 在 WFG3 这类问题上刷 `stats:pdist2:ZeroPoints` 警告，需在 runner 里压制（算法本身已有 clamp，警告本身无副作用）。
- 🔴 **harness `'Runs'` 只做 `isscalar` 判断，而 MATLAB 里 `isscalar([99])` 就是 `true`** → 单元素向量也会被展开成 `1:Runs`。**无法只跑一个 run**，最短请求是两元素向量（smoke 都用 `[7 8]` 之类）。
- **两阶段链式看门狗** `HES_EA_N100_M15/chain_to_M15.sh`：要求 `tasklist` 里 MATLAB.exe 计数 == 0，且（M10 driver.log 出现 `DRIVER_DONE` 或数据 320 个）**连续两次**才拉起 M15 driver。→ **任何 MATLAB 常驻进程都会永久阻塞链条**（2026-09-19 实证）。
- **实测节奏（健康时）**：单跑 wall 180–290 s（DTLZ1 M10 ≈ 264 s、DTLZ7 ≈ 180–280 s、WFG1 ≈ 190–225 s）；一个"10 跑/切片"约 2295–2787 s（38–47 min）；12 路并行。

### 🔴 2026-09-19 停滞事件（M10 94/320 卡死，未解决）
- 现象：`driver.log` 停在 12:18:46；数据目录最后一个 .mat 是 12:18:38；此后 2.5 h+ 零产出。12 个 worker 持续占满 12 个核。
- **判定为"卡死"而非"慢"**：采样 30 s 得每个 worker 进程 CPU 增量 ≈28.8–29.2 s（满核空转）；进程 CPU 总量 ≈13,200 s 与其 11:10–11:14 的启动时刻吻合（占空比 97%，**排除待机冻结**——若中途 S0 冻结，CPU 会明显小于墙钟）。对比健康切片 38–47 min，已超时 5–8 倍。
- 12 个卡死切片（`-logfile p{N}_a1.log`，命令行含 part 号与 run 列表）：part2 [4–15]、part2 [16–20]、part3 [3–14]、part5 [1–10]、part5 [11–20]、part6 [1–10]、part6 [11–20]、part8 [1–10]、part8 [11–20]、part9 [1–10]、part9 [11–20]、part10 [1–10]。涉及题：DTLZ2/3/5/6、WFG1/2/3；其中 **DTLZ5 与 WFG3 自启动起连一个 run 都没完成**（DTLZ5 卡 3h45m，WFG3 卡 2h39m）。
- 同一病理在 M15 复现：`smoke_HES_EA_N100_M15(10,[7 8],1)`（= WFG3）13:42 启动后无输出；而同批的 DTLZ2 smoke 正常（285 s + 264 s）。→ 疑似**运行级病态**（DTLZ3 slice [15–20] 正常完成、slice [3–14] 卡死），像是某些 run 触发死循环/超慢，而不是整题不可跑。嫌疑点：`HES_EA_N100` 第 75 行 `pdist2(...,'cosine')` 在退化种群上产生 NaN → KMeans 迭代不终止。
- 未采取的恢复动作（按巡检约定只读，未执行）：停 `chain_to_M15.sh`（PID 44472）与 M10 `driver.sh` → 杀 12 个卡死 MATLAB → 后台重启 M10 driver 补缺 → 再启链式看门狗。**在诊断出死循环根因前，盲跑会再次卡在同一批 run 上。**
- 诊断手法（只读，可复用）：本机 PowerShell 工具 stdout 不回显 → 把 `Get-Process`/`Get-CimInstance Win32_Process`（含 `CommandLine`）的采样结果 `Set-Content` 到临时文件，再用 Read 读；`CommandLine` 能直接暴露每个 worker 的 part 号与 run 列表。

## FE500 七算法全系列（2026-09-21 起）—— 六个必知坑（自 MEMORY.md 迁入归档）
- 框架 `PlatEMO/Experiments/FE500_M20_SevenAlgs/`，后台任务 `7CMxJT`（16 路），巡检自动化 `852747ad-1eec-4afc-a421-6ca505c29ed6`（已过期）。
- 范围：7 算法 × 16 题 × 20 跑 = 2240，maxFE=500、M=20、D=30（WFG2/3 为 31）、N=100、每题算 IGDp；落盘 `D:\REMOandDREMO测试集\20目标\FE500\<算法>\`；种子 `22260912 + 1000×题号 + run`。算法顺序 SSDE→SAMOEA→CSEA→PCSAEA→REMO→PACDIS→HES_EA（便宜→贵，卡死风险的 HES 放最后）。**PCSAEA/SAMOEATL2M/HES_EA 一律用原版类**。
- ① 末次 FE 严禁严格判等 `maxFE`（按批评估的算法必超支，实测 SSDE 500–543）→ harness 加 `FESlack`（默认 0 = 旧行为不变）。
- ② 固定种子下卡死的 run 重驱必定再卡 → `mark_poison.py` + `rc_part*.txt` + `poison.txt`（同一片被 timeout 124 杀 ≥2 次即把列表里第一个未落盘的 run 投毒并跳过）；`SLICE_TIMEOUT=14400 s`。
- ③ 启动节流不能用一个固定值：`LAUNCH_GAP=20`（前 `COLD_STARTS=4` 次）+ `LAUNCH_GAP_WARM=5`（固定 `sleep 20` 会把短切片算法 SSDE 卡到只有 2–3 路在跑、CPU 12%）。
- ④ 内存闸 `MIN_FREE_MB` 默认 0 = 关闭（本机基线空闲仅 ~16.5 GB；实测每 MATLAB 进程约 1.04 GB，SSDE/REMO 约 0.6 GB）。
- ⑤ DTLZ7 单跑 `wall` ~100 s 但 `metric.runtime` 只有 1.5 s：`GetOptimum` 用 `UniformPoint(N,M-1,'grid')`，M=20 给出 2¹⁹=524288 参考点 → **看单跑成本必须看日志 `wall`，不能看 `metric.runtime`**。
- ⑥ 🔴 **算法键名 ≠ 类名**：`SAMOEA` 是 registry 键，类名与目录名都是 `SAMOEATL2M`。`driver.sh` 的 `case` 必须两个都收（否则 `exit 2` 会带走整轮）；python 侧拼 MAT 文件名必须用类名（`missing_runs.py` 的 `CLASSES`/`resolve()`），用键名会让整个算法看起来"全缺"。**未知键只跳过 + 末尾汇总，绝不 `exit`**。
- ⚠️ 三个 `11D-1` 型算法（PCSAEA/HES_EA/SAMOEATL2M）初始就吃 329/500 FE，只剩 ~171 给搜索，**报数必须交代**。
- ⚠️ FE500/M=20 单跑 wall：REMO/PACDIS ≈1200–1600 s（是 FE300 的 3 倍以上，**别用旧数线性外推**）；实测 SSDE ≈2–5 s（DTLZ7 约 90–130 s）、SAMOEATL2M ≈110 s、HES_EA ≈628 s。
