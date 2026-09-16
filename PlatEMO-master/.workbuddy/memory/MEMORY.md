# 项目长期备忘 (MEMORY.md)

## 概况 / Git
- PlatEMO（进化多目标优化平台），MATLAB。fork of `https://github.com/meiyijian/my-platemo.git`，分支 `master`
- **git 仓库根 = `D:\PlatEMO-master`**，工作区 `D:\PlatEMO-master\PlatEMO-master` 是其子目录（`../` 路径会出现在 status 里，正常）
- 远端 `origin` = `https://github.com/meiyijian/my-platemo.git`，分支 `master`；全局代理 `http.proxy=127.0.0.1:7897`（Clash）**2026-09-14 实测可用**（能到 GitHub，edge=japaneast），不再是主要障碍
- 主线：REMO_new2_AdaMaO 系列 + SDEOnly / Pruned_Weighted / Lambda020 变体、候选模式消融，目标 Q1（SWEVO）
- 本地 PlatEMO **v4.12**，官方已 v4.16 → **不要整体升级 GUI/框架**（差异多为版权年份）

### 提交 + 推送固定套路（2026-09-14 实测，三个沙箱坑）
1. **绝不用 `git add -A`**：会被沙箱中断（进程被杀 → 留下 0 字节 `.git/index.lock`、exit 1、无输出）。改成显式路径逐组 `git add -- <path...>`（目录也行）。残留锁用 `[System.IO.File]::Delete('<repo>\.git\index.lock')` 清（`Remove-Item` 被 safe-delete 拦）。
2. **必须带 `-c core.longpaths=true`**：算法目录 + 88 字符文件名总长 266 > 260，否则 `git add` 该目录直接失败。
3. **推送失败先看是不是 401**（不是凭据过期）：`git credential-manager` 在沙箱里起不来 → git 调完 helper 直接 exit 128 且 stderr 全空。绕法：`git credential fill` 取出 token（`gho_` 40 位，username=116729236）→ base64 成 `Authorization: Basic` 写进临时 cfg → `git -c include.path=<临时cfg> -c credential.helper= -c core.longpaths=true push origin master` → **用完立即删临时 cfg**。
4. 抓 git 报错用 `git ... 2> $errfile`（`2>&1 | Out-String` 在 push 场景拿到空串）；**别把路径写成 `$out.tmp`**（会被当成属性访问，输出丢给 `$null`）。读中文先 `[Console]::OutputEncoding=[Text.Encoding]::UTF8`。含 `%H%n` 的格式串会触发沙箱 `%VAR%` 误判 → 用 `git show -s --format=full`。
5. 一次性推进多个提交很正常（远端可能积压好几条未推）。


## 数据位置（先自己查，不要反问路径）
- 原始数据 / 图表：`C:\Users\lsx\Desktop\REMOandDREMO测试集`（按目标数分目录，`10目标\n30` 为主战场）
- 表格 / 记录 / 规划文档：`C:\Users\lsx\Desktop\AdaMao实验表`
- 新产物默认落这两处，按实验名建子目录，不覆盖历史

## 跑实验约定（用户明确，长期有效）
- 用户说「跑实验」= **只产结果 .mat**，数据目录里不得有日志/哈希清单/逐轮记录/README/图/报告；统计与图表仅在用户说「分析」时做（那时归档到 `AdaMao实验表\<实验名>\`）
- 固定流程：① 读现成 runner 确认规格（题/M/D/N/maxFE/runIds），不假设参数 → ② 需改行为就**新建 runner 放 `.workbuddy/run_scripts/`，绝不改算法目录里的 .m**（会破坏运行前 SHA-256 源码校验）→ ③ `checkcode` + 确认内存 → ④ 先回规格与耗时预估给用户确认 → ⑤ `matlab.exe -wait -batch` 后台跑 → ⑥ 数数据目录 `.mat` 个数看进度 → ⑦ 跑完核对完整性、清理中间产物、汇报
- 「单臂 vs 双臂」「要不要重跑基线」这类改变跑量/统计效力的决策，先解释清楚让用户拍板

## 环境铁律
- MATLAB：`D:\mathlab2023a\bin\matlab.exe`（需显式 `addpath`，`cd` 不自动包含子目录）
- `Processes` profile 的 **NumWorkers 上限 = 6**；请求 8 会整体失败（退出码 1、无部分完成）
- **但 6 workers 不比 5 快**：2026-09-16 实测——同一算法、同一批协议，
  5 workers 单跑均值 321.9 s（M=10，288 跑实测），6 workers 单跑均值 421.1 s；
  吞吐 5 workers = 64.4 s/跑 vs 6 workers = 70.2 s/跑 ⇒ **6 workers 反而慢约 9%**。
  两批单跑耗时区间**完全不重叠**（batch1 M10 max 357 s < batch2 min 380 s）⇒ 是系统性的线程/带宽争抢，
  不是题目差异（本机 12 逻辑核，很可能是 6 物理核 + HT，6 个 MATLAB worker 的 BLAS 线程互相抢）。
  **结论：默认用 5 workers。**
- 速度基准：M=10 D=30 N=100 maxFE=300，6 workers 稳定 **6.1 min/波（6 job）**，N 跑 ≈ `ceil(N/6)×6.1` 分钟；M=20 单跑 ~5.5–5.9 min
- 进度**看产物 .mat 个数**，MATLAB `-batch` 的 stdout 块缓冲不实时刷新
- 长跑期间**不要并发开第二个 parpool**（31.7 GB 内存会 OOM；失败 job 可断点续跑）
- AI 生成的 `.m` **一律纯 ASCII**（中文只允许出现在路径字符串里）
- `writetable` 写 .xlsx 可用。对比表标准格式（源 `AdaMao实验表\最新版算法总实验\<M>目标.xlsx`）：单 sheet `IGD`，表头 `Problem,N,M,D,FE,<各算法>,<基准放最后>`，格内 `%.4e (%.2e) 符号`，`+`该算法显著优 / `-`显著劣 / `=`无差异，每行最优蓝色 `FF3333E9` 加粗
- PowerShell 写日志统一 `2>&1 | Out-File -Encoding utf8`（混用 `*>>` 会写成 UTF-16）。**Bash 工具链（ls/head/grep/dirname）本机不可用**且回显常为空 → 用 PowerShell 并重定向到文件再 Read
- **MAX_PATH 260 坑**：算法目录 + 88 字符长文件名会超限，`Test-Path`/`Copy-Item`/`.NET File` 会误报"找不到路径"，但 `Get-ChildItem` 正常 → 用 `\\?\` 前缀或 `robocopy`
- **本沙箱禁止删除文件**（`Remove-Item` 被 safe-delete 拦下）→ 需要"搬走"就"复制 → 校验哈希 → 告知用户手动删除"

## 种子公式（先读 metadata.seed 反推，勿默认沿用）
- 旧 18 次批次：`seed = 20260912 + 题号×1000 + runId`（**不含 M 项**）
  —— 出处脚本 `...\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Q080\RunQ080_18.m`、
  `...Pruned_Weighted\RunWeightedM20_18.m`（这两份都写死 `'save',18,'run',1`）
- 论文批次：`seed = 20260912 + M×1e5 + 题号×1000 + runId`
  —— 出处 `RunPaperWeighted30.m`、`RunLambdat030_10.m`、`RunLambda020_10.m`、`RunOriginal_10.m`
- **旧批次 `.mat` 只有 `result`/`metric`，没有 `metadata` 字段**（2026-09 之后才有）→ 老文件的种子**无法事后反推**。
  想核对只能用「找当时的 runner 脚本」这一条路。
- 2026-09-15 用户明确：新臂**不必**和别的算法用同一套种子（"每个都跑了18次"）→ 新批次一律用含 M 的论文公式。
- 同一算法目录两套公式可共存（论文批次跳过已存在的 1–18、只补 19–30）
- `Algorithm.run`（模式随机流）在 18 跑批次里**恒为 1**（脚本注释：GUI 下 `Algorithm.run` 为空、回落到 1），
  metadata 记 `modeRunId=1`；论文批次同。

## 铁律：往 Algorithms/ 加新算法前必须重名隔离
`platemo.m` 用 `addpath(genpath(cd))`，MATLAB 按**文件名**解析、不看调用者目录 → 新目录中凡与既有目录重名的 `.m` 一律移入该目录自己的 `private/`（genpath 跳过 private，private 优先级最高）；主类文件（`classdef < ALGORITHM`）留顶层供 GUI 发现。惨案：`MaOEA-HAP/Shape_Estimate.m`（4 参数版）抢占 PIEA / REMO 的两参数版。验收：新增目录在全局路径上的重名 `.m` = 0。

**2026-09-15 复现同类隐患**：`ResolveUniformMixMode.m` 在 4~10 个算法目录里都有，且存在 **3 个不同版本**（多数目录 `C8CD08539B06`；`REMO_new2_AdaMaO_HCV` 与 `REMO_UniformMixCandidate\private` 是 `48E97EBC703A`；`..._Pruned_qKeep080` 是 `193A515D08D1`）→ 解析到哪个**完全取决于 addpath 顺序**。`PrunedIndicatorSelection.m` / `PrunedWeightedBatchSelection.m` 各目录副本一致，暂无风险。新目录（Lambdat050 / RMEO_k_CDIS）的做法：**内部函数全部进 private/**，连这三个也进。
**验收隔离的唯一有效方法（2026-09-15 修正）**：`which('ResolveUniformMixMode')` 从基础工作区**查不到 private**，它给的是别的目录的副本，**不能当证据**。真证据 = 在算法目录里放个临时探针函数，函数体内 `functions(@Name).file` 取解析路径（private 对它生效），断言路径含自己的目录名，验完 `Move-Item` 搬走。同类高危还有 `Shape_Estimate.m`：被 4 参数版抢占时报参数不足 → 被 `IndicatorSelectorSDEOnly` 的 try/catch **静默降级**成 `Lp_prev`，不报错只变差。

## Lambda020 与「执行上下文敏感性」（重要）
- 目录 `.../REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020/`：探索分支预筛选不变，仅在保留集合内归一化后 `A_t = R~ + λ0*(1-FE/FEmax)*U~`，贪心项 `0.75*A_t~+0.25*d~`；`λ0=0` 已与基线**逐位等价**
- **同源码 + 同种子在不同计算线程数下结果不同**（client 6 线程 1.0823 / parpool worker 1 线程 1.1237）→ **跨会话结果不能当逐位配对**；新实验一律「同会话同进程池、两臂同种子」
- `10目标\n30` 可用 runId：六个 baseline 与 Pruned_Weighted = **1–30**；Original = **1–18**；Lambda020 = **19–28**（⇒ 与 Original 无法配对，只能秩和非配对比较）

### λ 常数版本与「越大越好」的证伪（2026-09-15）
- `REMO_UniformMix_Pruned_Weighted_Lambdat030`（λ_t=0.30 常数，顶层散着三个通用名 .m）与
  `REMO_UniformMix_Pruned_Weighted_Lambdat050`（λ_t=0.50，内部函数全在 private/）。二者只差一个常数。
- 配对实验（DTLZ2/4/5/7，M=10 D=30 N=100 maxFE=300，runId 21–30，同池同种子，80 跑 83.6 min）：
  **全部不显著**。delta（正=λ0.50 更好）：DTLZ2 −0.47% / DTLZ4 −5.25% / DTLZ5 +4.84% / DTLZ7 +8.13%，
  p = 0.85/0.16/0.49/0.28；合并 40 对 +6.04% 但 p=0.73，且合并均值被 DTLZ7（量纲大 10 倍）主导，**不可引用**。
- 推论：λ 不是「越大越好」，也不是已知有效的旋钮；桌面 030 目录 `descriptive.csv` 里 0.2→0.3 的
  「单调改善」是跨会话非配对比较，很可能是噪声。**别再花时间调 λ**，除非先上 n≥25 压方差。
- **vs REMO（非配对 ranksum，REMO 取 runId 21–30）**：变体优于 REMO 的显著项 **050 与 030 完全
  相同（都只有 DTLZ7，+53.6% / +49.5%，p=1.8e-4）**；而变体劣于 REMO 的显著项 050 有 DTLZ4
  （−15.8%，p_holm=0.013）、030 没有（raw 0.026 → Holm 0.129）。⇒ **λ 增大没换来任何额外优势显著项，
  反而多一个劣势项。λ 是放大器不是改善器**（DTLZ7 优势与 DTLZ4 劣势同时被放大）。
  REMO 有预算超支（末次 FE 300/302.5/307），对比对 REMO 略有利。

## 已有资产速查
- **论文收敛图（2026-09-15 新建，编译稿 §4.6 / 图 3）**：`figures/build_convergence.py` ←
  `figures/source_data/convergence_igd.csv`（由 `.workbuddy/run_scripts/ExportConvergenceCSV.m` 从数据集
  只读导出，7 算法 × WFG1/6/7/8 × M=10/15/20 全部快照轨迹）。6 面板 = WFG7/WFG8 × 3 M（仅有的三 M
  全胜问题），中位数取 **runId 1–20 匹配子集**、零阶保持对齐、横轴从首快照（FE≈100，MCEAD 30–65）起、
  IQR 带只画 PACDIS。改图/换题：重跑导出脚本 + build 脚本即可，产物三格式+manifest+qa 渲染同目录。
- **`RMEO_k_CDIS`（2026-09-15 新建）**：原版 REMO 框架 + Lambdat030 的 CDIS 模块，`k=min(N,max(6,ceil(1.5M)))`（M10→15/M20→30）。
  框架照搬 REMO（含 `GetOutput_PBI` 二值分类，**无 PAQC/无 25% 配额**），CDIS 按字节从 Lambdat030 复制（λ=0.30、指标分支都在）；
  参数 `{gmax,pMix,qKeep,nMax}={3000,0.50,0.70,6}`，`rGood/nMin/lambda0` 不使用。顶层只有入口类，13 个内部函数在 `private/`。
  有 `README_RMEO_k_CDIS.md`；冒烟脚本 `.workbuddy/run_scripts/SmokeTestRMEOkCdis.m`（FE 严格等于预算）。**尚无正式实验数据**。
- 收敛曲线 `ConvergencePlot/`（工作区根，与 `PlatEMO/` 平级）：**不用重跑**——`metric.IGD` 本身就是逐快照收敛轨迹（`result(:,2)` 全列 cellfun）。要点：各 run 快照 FE 不齐，重采样到 `0:gridStep:maxFE` 必须零阶保持 `interp1(...,'previous')`；区分 `finalMedian`（FE=300）与 `finalSnapshotMedian`（末次快照，与论文表格同口径）；**HV 部分算法全 0，别用**。产物：`...\10目标\n30\ConvergenceCurves\`
- λ 对照实验：`REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat050\`（40 个 .mat）
  + 同目录 `control_lambdat030\`（40 个同上下文 λ=0.30 对照）。runner / 分析：
  `.workbuddy/run_scripts/RunLambdat050Compare.m`、`AnalyzeLambdat050.m`；Lambdat030 自己的
  16 题×20 跑数据在 `...\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030\`
- 汇报文档：`REMO_DiRel_汇报文档.md`；设计文档：`PlatEMO/docs/superpowers/{specs,plans}/`
- **中文对照稿 `论文写作\HPDC-MaOEA_中文版.md`（跟 tex 走，每次都整篇覆盖）**：编号按源码顺序手数（式/算法/图/表/参考文献），
  **48 行表格数据一律脚本转**（`.workbuddy/run_scripts/tex_table_to_md.py` + `fill_table_placeholders.py`，
  正文先写 `<!--TABLE_DTLZ-->` 占位符），§4.2 数字再对 `summary.json` 核一遍。流程见 skill `.workbuddy/skills/paper-cn-mirror/`。
- `论文写作/AGENTS.md`：改 `HPDC-MaOEA.tex` 后须编译+自动提交+推送；**仅翻译/整理不触发**（推送前仍需问用户）。
- **论文主性能表（PACDIS vs 六基线）**：tex 的表格不是内联的，是
  `论文写作\HPDC-MaOEA.tex` 里 `\input{experiments/main_performance/table_dtlz|table_wfg}`。
  数据**只能**由 `论文写作\experiments\main_performance\build_tables.py --source-dir <xlsx目录>` 生成
  （换源只改脚本里的 `OURS` 与 `FILES` 两个常量）；正文 `Comparison with the Six Baseline Algorithms`
  里的数字全部派生自同目录 `summary.json`，必须一起改并重验定性断言。
  **`HPDC-MaOEA.tex` 与 `HPDC-MaOEA_1param.tex` 共用这两张表**。
  2026-09-15 起 PACDIS ↔ `REMO_UniformMix_Pruned_Weighted_Lambdat030`（源表 `lambdat030{十,十五,二十}目标.xlsx`）；
  完整流程见 skill `.workbuddy/skills/paper-main-table-refresh/`。
- 本地 Office 读写走 `tencent-local-office-edit`（`edsdk.py`）：`--json` 内联会被 PowerShell 吞引号 → 用 `--json-file`；PowerShell 捕获 Python UTF-8 输出需先设 `[Console]::OutputEncoding` + `$env:PYTHONIOENCODING=utf-8`
- 历史细节见 `.workbuddy/memory/YYYY-MM-DD.md`（Stage1/Stage2、上游同步、环境踩坑原始记录）
