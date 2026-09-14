# 项目长期备忘 (MEMORY.md)

## 项目概况

- PlatEMO 项目（进化多目标优化平台），fork 自 https://github.com/meiyijian/my-platemo.git
- 主要开发语言：MATLAB
- 工作目录：`D:\PlatEMO-master\PlatEMO-master`
- 当前主要工作：REMO_new2_AdaMaO 系列算法及其 SDE-only 变体、候选模式消融实验

## 数据存放位置（桌面，2026-09-14 用户指定）

**约定：涉及「有没有数据 / 去看结果 / 找某个实验」时，先直接去下面两个目录查，不要先问用户路径。**

- **实验原始数据（.mat 结果 + 图表产物）：`C:\Users\lsx\Desktop\REMOandDREMO测试集`**
  - 按目标数分：`2目标 / 3目标 / 5目标 / 8目标 / 10目标 / 12目标 / 15目标 / 20目标 / 30目标 / n=10`
  - 10 目标下另有 k 值对比：`10目标k=100的对比实验 / 10目标k=50的对比实验 / 10目标k=15的对比实验`
  - 主实验（RunPaperWeighted30）落在 `{10目标n30,15目标,20目标}/<算法>/`，收敛曲线产物在 `10目标\n30\ConvergenceCurves\`
- **表格 / 实验记录 / 规划文档：`C:\Users\lsx\Desktop\AdaMao实验表`**
  - 子目录：`Stage1_UniformMix_LabelValidation / Stage2_LabelCausalAblation / Stage3_IndependentUtilityValidation / 消融实验 / 混合PBI / 参数简化版本 / 最新版算法总实验 / 其他 / 新建文件夹`
  - 含规划与总结 md：`AdaMao_未做实验总规划.md`、`AdaMaO_一区投稿补做实验_REMO_PIEA源码对照.md`
- 新实验/新图表产物**默认也落到这两个目录下**（原始数据进「测试集」，表格与文档进「AdaMao实验表」），按实验名建子文件夹，不覆盖历史

## 论文主实验 RunPaperWeighted30（2026-09-12 启动）

- 脚本：`PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted/RunPaperWeighted30.m`；先读 README_30runs.md
- 规格：7 算法（REMO/PIEA/CSEA/PCSAEA_N100/KRVEA_100/MCEAD/Weighted）× 16 题（DTLZ1-7/WFG1-9）× M=10/15/20 × 30 runs = 10080；N=100、D=30、maxFE=300；Weighted 参数 {3000,0.50,0.25,0.70,6}
- 启动方式：`matlab -wait -batch "...addpath(...); RunPaperWeighted30('run',2);"`，parpool Processes 2 workers；`'check'` 只盘点、`'verify'` 验 worker、`'run',2` 断点续填缺 runs
- 数据落盘：`C:/Users/lsx/Desktop/REMOandDREMO测试集/{10目标n30,15目标,20目标}/<算法>/<alg>_<prob>_M<m>_D<d>_<run>.mat`；日志与清单：算法目录 `diagnostics/paper_30runs/`（inventory_latest.csv、run_*.log、RUNNING.lock）
- 健壮性设计：历史结果绝不覆盖、源码 SHA-256 manifest 校验、结果原子写入（temp→validate→movefile）、RUNNING.lock 防双开、种子公式 20260912+M*1e5+pi*1e3+ri
- 9-12 23:05 首次启动（'run',2，2 workers），9-13 20:49 死于 896/2208（原因不明）；当晚用户侧补救：DTLZonly 定向补跑 ~420 个 + 脚本改为支持 workers='max'；9-13 22:25 起 ('run','max') 6 workers 接管剩余，实测 ~135 job/h（夜间疑似睡眠拖慢至 55/h）

## Lambda020 变体与新发现的「执行上下文敏感性」（2026-09-14）

- 新目录：`PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020/`（克隆 pruned_weight，**未改动原版一个字节**）。核心差异：探索分支质量预筛选不变（R 的 qKeep=0.70），仅在**保留集合内**归一化 R、U 后 `A_t = R~ + 0.20*(1-FE/FE_max)*U~`；批次首位取 argmax A_t，贪心项 `0.75*A_t~+0.25*d~`；**不恢复** p_err 门控 / nMin / 指标二次筛选。第 6 参数 `lambda0`（默认 0.20）。详见该目录 `README_Lambda020.md`
- **铁律：`.m` 里新增注释/函数可以，但实验进行中不要改任何已在源文件清单里的 `.m`** —— runner 每次跑前逐文件校验 SHA-256，改了会让后续 job 全部失败
- **`lambda0=0` 等价性已验证**：① 选择器级 120 组随机用例 0 处不一致；② 整跑级同上下文下与基线**逐位相同**（DTLZ2 M10 D30 三跑 IGD 全为 1.123668809672717）
- **执行上下文敏感性（重要）**：同一份源码 + 同一个种子（21262931，DTLZ2 M10 D30）在不同上下文给出不同轨迹：
  - client，6 计算线程 → **1.0823481784157407**（跨会话复现一致）
  - parpool worker，1 线程（2 或 3 worker 池）→ **1.123668809672717**（多次复现一致）
  - 论文数据集存盘对照 → **1.2768012367242776**（2026-09-13 00:14 的 2-worker 会话），今天三种上下文**都无法复现**
  - 已排除源码漂移（5 份历史 `sources_*.mat` 清单与当前 pruned_weight 源码逐文件匹配）与 RNG 差异（`rngBeforeSolve` 一致）→ 决定因素是**计算线程数**
  - 推论：**跨会话/跨上下文的结果不能当逐位配对**；新实验一律「同会话同进程池、两臂同种子」跑对照
- 实测单跑耗时：client（6 线程）**4.8 min**；pool worker（1 线程）**7.2 min**；6 workers ≈ **0.83 run/min**（80 跑 ≈ 90 min）
- 坑：6-worker 主跑期间并发再开一个 MATLAB 进程池（哪怕只有 2 workers）会触发**内存不足**（本机 31.7 GB / 12 逻辑核），失败 job 会被逐跑记录并可断点续跑；长跑期间不要并发额外池
- 诊断/验证脚本都在 `diagnostics/lambda020_10runs/`：`verify0_context.m`（上下文隔离）、`verify_context2.m`（2-worker 复现）、`compare_first_snapshot.m`（快照级定位分歧起点）、`source_hash_check.m`（历史清单 vs 当前源码）、`check_control_metadata.m`（存盘对照元数据核验）、`RunOriginal_10.m`（Original 臂）
- **产物落盘（2026-09-14 18:28 起）**：全部实验产物统一放在数据集内的算法文件夹
  `C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020\`
  （`*.mat` = λ0=0.20 臂；`control_in_session\` = 同会话 baseline；`diagnostics\` = 记录/日志/验证证据；内含 `_README_实验产物说明.md`）。
  `RunLambda020_10.m` 与 `analyze_lambda020.m` 的 `cfg.logs`/`cfg.controlInSessionFolder`/`cfg.recordsFolder` 已指向该处，续跑自动跳过已完成 job（2026-09-14 18:28 状态：80 计划 / 6 已存在 / 74 待跑）。
  Original 参数版本**不重跑**，直接用 `..\REMO_new2_AdaMaO_SDEOnly_UniformMix_Original\` 的现成 18 次；种子批次不同 → 与它只能做非配对（秩和）比较。
- **环境坑：MAX_PATH（260）**。本项目的算法目录 + 88 字符长文件名会让完整路径达 263 字符，此时 `Test-Path`/`Copy-Item`/`.NET File` 全部报"找不到路径（的一部分）"，但 `Get-ChildItem` 列目录仍正常——**极易误判成文件不存在**。解法：`\\?\` 长路径前缀，或 `robocopy`（原生支持长路径，rc=1 = 成功复制）。
- **本沙箱禁止删除文件**：`Remove-Item` 一律被 `[safe-delete][SAFE_DELETE_FAIL_CLOSED]`（trash-failed）拦下（个别文件侥幸成功，多数失败）。需要"搬走"文件时按"复制 → 哈希校验 → 告知用户手动删除"处理，不要用 .NET 直删绕过。

## Git / 网络配置备忘

- 远程仓库：`origin` → https://github.com/meiyijian/my-platemo.git（HTTPS 协议）
- 默认分支：`master`
- **代理陷阱**：git 全局配置了代理 `http://127.0.0.1:7897`（Clash 端口），但该代理常未运行，会导致 `git pull/push/fetch` 报 TLS 错误
  - 临时绕过：`git -c http.proxy= -c https.proxy= pull origin master`
  - 彻底解决：`git config --global --unset http.proxy && git config --global --unset https.proxy`
- 2026-08-11 实测：直连 GitHub 与走代理（7897）均在 TLS 握手阶段失败（error:0A000126 / schannel failed to receive handshake），疑似 Clash 节点失效或被墙；git 同步需在能正常联网的终端进行（当前沙箱环境无法连通）
- `git pull` 即使 fetch 成功也可能返回非零退出码，需检查 `git status`，必要时手动 `git merge --ff-only origin/master`

## 目录结构要点

- 算法代码：`PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/`
- 设计文档：`PlatEMO/docs/superpowers/specs/`、`PlatEMO/docs/superpowers/plans/`
- 汇报文档：`REMO_DiRel_汇报文档.md`（项目根目录）
- `Algorithms/NeuroEA/`：2026-08-29 从官方 v4.16 同步进来的新分类（9 文件，与本地 `Algorithms/Blocks` 重名，已隔离到 private）

## PlatEMO 版本与上游同步（2026-08-29）

- 本地为 PlatEMO **v4.12**（GUI.m 中写死），官方 BIMK/PlatEMO 已到 **v4.16**；框架文件差异多为版权年份，**不要整体升级 GUI/框架**
- 已同步官方新增 35 个多目标算法 + NeuroEA + 单目标 MiSACO/SSIO-RL；多目标目录 358 → 393
- `ESBCEO` = 官方 `ESB-CEO`（官方改名），本地保留原名，勿重复引入

### 铁律：往 Algorithms/ 加新算法前必须做重名隔离

- `platemo.m` 用 `addpath(genpath(cd))`，MATLAB 按**文件名**解析、且不看调用者目录 → 字典序靠前的目录会遮蔽后面所有同名 .m
- 新增目录中凡与既有目录重名的 .m，一律移入该目录自己的 `private/`（genpath 跳过 private，private 对父目录优先级最高）
- 惨痛案例：`MaOEA-HAP/Shape_Estimate.m` 是 4 参数版，会抢占 PIEA / REMO_new2_AdaMaO 等的两参数版调用，直接报错
- 验收标准：隔离后「新增目录在全局路径上的重名 .m 文件数 = 0」，且主类文件（classdef < ALGORITHM）必须留在顶层以便 GUI 发现
- 完整流程与踩坑记录见 `.workbuddy/memory/2026-08-29.md`

## Stage1 标签机制审计实验状态（2026-08-12 更新）

- 实验根目录：`PlatEMO/Experiments/REMO_new2_AdaMaO_UniformMix_LabelValidation/`
- 进度检查：`check_Stage1Progress('screening')`；聚合/分析：`run_LabelMechanismSnapshotAudit` / `analyze_LabelMechanismSnapshotAudit`
- **screening（100 作业）已完成并分析：Decision = PASS_TO_STAGE2**（100 valid、等价性 PASS、自适应覆盖≥50%）
  - 方向来源：KMEANS 自适应主导（≥90%，多数 100%）；仅 DTLZ4 M20（OBJECTIVE_RANGE_LT_1E12）与 DTLZ7 M10 Hybrid（FRONT1_LT_THRESHOLD）有少量回退
  - 候选模式：fallback=0，indicator/explore 约对半；每代 ~5.97 评估
  - 结果与汇总报告：`results/stage1/screening/analysis/`（含 Stage1_screening_summary.md）
- 遗留提醒：分析器曾修 bug（方向来源汇总列宽不匹配，已修复）；用户可归档实验到桌面「AdaMao实验表」文件夹；Stage1 通过后可启动 Stage2

## 收敛曲线绘制 ConvergencePlot（2026-09-14）

- `ConvergencePlot/`（工作区根，与 `PlatEMO/` 平级）：`PlotConvergenceCurves.m`（单题多算法，median + IQR 带）、`PlotConvergenceGrid.m`（多题拼图 + 每题单图）、`demo_Convergence_10obj.m`（10 目标 16 题入口）、`README.md`
- **不用重跑**：`save`>0 时 `result(:,1)`=快照 FE、`result(:,2)`=快照种群；`CalMetric('IGD')` 对 `result(:,2)` 全列 cellfun → **`metric.IGD` 即逐快照收敛轨迹**。主实验已存好（REMO 30 点 / Weighted 18 点，1044 文件 0 不可用）
- 三个要点：① 各 run 快照 FE 不齐（REMO 到 303、Weighted 到 300），重采样到 `0:gridStep:maxFE` 必须用 **零阶保持** `interp1(...,'previous')`；② 分位数逐列丢 NaN；③ 终值区分 `finalMedian`（FE=300 处）与 `finalSnapshotMedian`（各自末次快照，与论文表格口径一致）
- 图表产物目录：`C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\ConvergenceCurves\`
- 数据口径：`metric.HV` 部分算法全 0，**别用 HV**；PlatEMO `IGD.m` 算 `Population.best.objs`（best-so-far 档案）而非末代种群

## 环境与工具铁律

- **AI 生成的 `.m` 一律纯 ASCII**（代码与注释）：MATLAB 2023a 在 zh-CN 下读某些非 ASCII 无 BOM 的 .m 会报「文本字符无效」；中文只允许出现在路径字符串里（UTF-8 无 BOM / 带 BOM / GBK 三种编码读中文路径均验证通过）
- `matfile` 读 `-v7` 文件中的对象 cell 会报 `MATLAB:MatFile:OlderFormat` 且不支持部分加载；本项目结果文件仅 ~95KB，`load(file,'result')` 约 5ms，更快更干净（`metric` 是纯 struct，可用 matfile 部分加载）
- 本机 MATLAB：`D:\mathlab2023a\bin\matlab.exe`；调用需显式给函数所在目录 `addpath`，`cd` 到根目录并不会自动包含子目录
- 本机 Python 3.13.12 **无 numpy/scipy**；Bash 工具链（ls/head/grep）在本沙箱不可用——用 PowerShell 且把输出**重定向到文件再 Read**（该工具的回显经常为空）

