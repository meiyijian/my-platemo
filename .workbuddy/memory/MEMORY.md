# 项目长期记忆（PlatEMO AdaMaO 研究）

## 算法家族与去向决策
- `REMO_new2_AdaMaO`（完整版 Full）：保留。指标子系统 use_indicator 默认开、degeneracy>=0.45 触发。M=10 与 Lite 持平，M=20 反超全场（11算法排名登顶）。
- `REMO_new2_AdaMaO_Lite`：删指标子系统。
- `REMO_new2_AdaMaO_NoIndicator`：关指标候选模式。
- `REMO_new2_AdaMaO_PIEAOnlySelection`：仅用借来 PIEA 指标（删自适应关系学习）→ DTLZ7 断开PF 崩 2.35×，不可保留。
- `REMO_new2_AdaMaO_FixedIndicatorAlways`：指标 always-on → 同崩，不可保留。
- `REMO_new2_AdaMaO_Simple`：超参削减版（外部参数 10→2：[use_indicator,debug]）。M=10 显著差于 Full（gmax 砍 4.3× + 删关系模式切换 为元凶）。
- `REMO_new2_AdaMaO_SimpleA`：Simple 仅恢复 gmax=3000 的消融变体，验 gmax 是否元凶。

## 实验设计参数（默认）
- N=100（昂贵多目标标准，固定跨 M 使维度效应干净），D=30，maxFE=300。
- maxFE=300 是昂贵 MOEA 标准预算；gmax 是代理内部 GA 迭代上限（与总预算不同）。
- N 绑 D 是概念小问题（应绑 M），但 D=30 固定时落到 100 巧合正确，不急改。

## 笔记/文档归档约定
- 分析笔记、评估报告、热力图等**统一放进对应算法文件夹下的 `notes/` 子目录**，不要放 PlatEMO 总目录（D:\PlatEMO-master 根）。
- 实验数据表（xlsx）在用户 Desktop：`AdaMao实验表/消融实验/指标模式/`（M=10、M=20）、`简化参数/`（Simple 结果）。

## 常用脚本/工具
- Python venv：`C:/Users/lsx/.workbuddy/binaries/python/envs/default`（装了 openpyxl），解析 xlsx 用。
- MATLAB：`/d/software/mathlab/bin/matlab`，pcode 可纯语法校验 .m（checkcode 在此沙箱因 Java 编辑器服务故障不可用）。
- checkcode 实际可用（`-batch` 下正常），之前"不可用"的说法已过时。

## CascadeAudit Stage 0（2026-08-06 完成）
- 只读反事实审计：`REMO_new2_AdaMaO_SDEOnly_CascadeAudit` + `private/AdaMaOSelectionCascadeAudit`（配对 UniformMix_Original，零 RNG/FE 扰动）。
- Experiments harness：`Experiments/REMO_new2_AdaMaO_CascadeAudit/`（被 gitignore 忽略，提交需强制跟踪 source/tests/README）。
- 决策逻辑：H1 fail→STOP_CASCADE_BLIND_SPOT_STORY；H2 fail→STOP_INDICATOR_RESCUE_STORY；H4 fail→CONTINUE_UNGATED_ONLY；全过→CONTINUE_GATED_RESCUE_PROTOTYPE；<5 run 或灵敏度 FAIL→INSUFFICIENT_DATA。
- smoke 只验证 instrumentation，不构成 H1/H2/H4 证据。

## Pilot 结果（2026-08-06 晚）：STOP_INDICATOR_RESCUE_STORY
- H1 PASS：粗筛覆盖缺口真实（normalized greedy-batch regret 5/6 问题>0，Recall@K 0.25–0.81）；H2 FAIL（DTLZ 家族 Real−DiversityMatched 为负）；H4 FAIL（门控不降负替换率）。
- 最大正分歧候选平均替换净增益为负（救援有害），但 OracleRescue 上限高 → 信号抓不住，机制主张停止。
- pilot 需完整参考集（referenceRequest=10000）才过灵敏度；256 参考在晚代 top-K 判定不稳。
- 完整结论：`REMO_new2_AdaMaO_SDEOnly/notes/2026-08-06-cascade-pilot-conclusion.md`。

## UniformMix 参数削减族（2026-09-11）
- `..._UniformMix_Maximin`：探索分支选"离完整历史档案最远"的候选（距离对象=历史档案）。
- `..._UniformMix_Pruned`：五项同时删减（指标 0.70 分位、nMin=4、lambda0 与 0.45 门控+模糊度奖励、指标粗筛最少 20、权重 0.75/0.25）。**组合版，非单因素**。
- `..._UniformMix_Pruned_Weighted`：Pruned 基础上**只回填 0.75 质量 + 0.25 距离权重**。
- M=10 九次（N=100/D=30/maxFE=300）结论：Pruned 在 DTLZ2/5 退化 +11.7%/+31.1%；回填权重后降到 +7.7%/+23.9%，DTLZ7 继续改善 −25.4% → **"持续质量约束"是第一嫌疑**，qKeep/模糊度奖励次之。
- 统计口径：DTLZ7 相对 Original/Pruned raw p=0.031，六问题 Holm 校正后 0.189 → 不能说显著。
- 部署：都自带 README+tests+validation.log，Pruned_Weighted 另有 SHA256 冻结清单与校验报告（这套冻结做法应沿用）。

## 关键坑（血泪）
- **固定种子不能 `rng()` + `platemo(...)`**：本地 `platemo.m` 会执行 `rng('shuffle')`。必须直接构造 problem/algorithm，在 `Solve` 前 `rng(seed,'twister')`。
- 加权前必须用**欧氏距离**，不能用平方距离（归一化后数值不等价）。
- WFG2/WFG3 原版数据实际 **D=31**，其余 D=30；不要为统一文件名改回 30。
- Pruned 源码默认 qKeep=0.80，正式实验是配置覆盖为 0.70 跑的；两入口比较要显式都传 `{3000,0.50,0.25,0.70,6}`。
- 三版本间**无共同初始样本**（仅运行编号对齐）→ 用 exact Wilcoxon 秩和（独立样本），不能用配对符号秩。

## 论文（PACDIS）
- 稿件改名：`HPDC-MaOEA → PACDIS`，`HPC → PAQC`（PBI-Assisted Quality Classification）、候选模块 → `CDIS`。旧图里 HPDC/HPC 标注需同步。
- 09-11 新增单参数变体 `论文写作/HPDC-MaOEA_1param.tex`：探索分支 `A_k=R̃+β·E_k`（模糊度+批次距离合成单一 bonus）。**β→0 对应被 Pruned 实验否定的"纯关系排序"格，β 取值与敏感性分析是必做项**（草稿已留 \TODO）。
- ⚠️ 2026-09-11 22:27:10–22:27:22 本地 `论文写作/` 227 个已跟踪文件被批量删除（进回收站），**非本次审查会话所为**（会话 22:28:23 才开始，首个动作是只读 git log）。已用 `git restore --source=HEAD --staged --worktree -- 论文写作` 恢复至 231 文件。`origin/master` 同样含 231 个文件，是离线安全网；本地 HEAD == origin/master。
- 取证方法：解析 `X:\$Recycle.Bin\<SID>\$I*`（8B 版本+8B 大小+8B FILETIME+4B 路径长+UTF-16 路径），本环境的 `rm` 走"安全删除"shim 会进回收站，可事后定位删除时间与清单。COM `Shell.Application` 被安全策略拦截，不可用。

## 归档约定补充
- 项目级周审查报告放 `D:\PlatEMO-master\docs\`；算法级诊断放对应算法目录 `diagnostics/<主题>_<日期>/`。
- 长任务前先预估运行时长与排程间隔；用户亲自跑重活，AI 负责开发/归档/自动化。

## 本机环境硬事实（2026-09-11 实测）
- **Bash 工具可用**：根因是注入的 PATH 缺 coreutils，每条命令前加
  `export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"`
  即可（ls/find/grep/wc/tasklist 全能）。PowerShell 工具在本环境 **stdout 不回显**，尽量别用。
- MATLAB：`/d/software/mathlab/bin/matlab.exe`，**R2021b**。`checkcode` 在 `-batch` 下可用。
- MATLAB 读 **UTF-8 的 .m 中文字面量正常**（`DefaultCharacterSet` 报 GBK 是遗留项，不影响文件解码），中文路径不必转 GBK。
- MATLAB R2021b 在 `-batch` 退出阶段偶发 `0xc0000374 堆损坏`：**发生在写盘之后**，数据安全；长跑务必配"进程守护 + 断点续跑"，别指望单次进程跑完。
- 机器 8 物理核 / 16 逻辑核 / 32 GB 内存；并行跑 MATLAB 时每进程 `maxNumCompThreads(4)` 较合适。

## 数据集命名与口径（REMOandDREMO测试集）
- 根目录 `D:\REMOandDREMO测试集\<M>目标\n<D>\<算法名>\`，每个算法一个文件夹。
- 文件名约定 `<算法>_<问题>_M<M>_D<D>_<run>.mat`，**D 用 Problem.D**，所以 WFG2/WFG3 是 `_M10_D31_`（不是笔误，别统一改回 30）。
- 文件内容：`result`（N×2 cell，{FE, Population}）+ `metric`（含 `runtime` 与 `IGD`）。旧数据用 `save=18`，即 18 个快照，FE 序列 100,106,…,300，**IGD 末位就是最终 IGD**。
- 旧基线数据由 **PlatEMO GUI 实验模块**产出（`Setting.mat` 可还原算法/问题/参数列表）；IGD 是事后在 GUI 表格里点出来的（GUI 的 `GetMetricValue` 会回写 .mat）。批处理复现时显式 `ALG.CalMetric('IGD')` 更省事。

## 可复用实验框架
- `PlatEMO/Experiments/<名字>/run_*.m` + 同级 `verify_*.py` + `D:\PlatEMO-master\tmp\supervise_part.sh`（进程守护/崩溃自愈）这套组合已跑通，新算法全系列实验可直接照搬。
- **框架实战已验收（2026-09-12）**：Pruned 全系列 288 跑（16 题 × 18 跑，M=10/D=30/maxFE=300，参数 `{3000,0.50,0.25,0.70,6}`）4 分区并行，总 wall ≈5.3 h，吞吐稳定 0.93–0.95 文件/min，期间 2 次堆崩被守护脚本自动断点续跑，最终 `verify_pruned_run.py --runs 18 --expect-fe 300` 报 `RESULT: COMPLETE`（288/288，missing 0）。结果目录：`D:\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned\`，含 `_verify_runs.csv` 与 `_runlog_part{1..4}of4.csv`。→ 该"4 分区 + supervise_part.sh + verify"模板可直接用于后续算法全系列。
- 固定种子 + 传 `'run',r`（CDIS/模式流的 `CreateSDECandidateModeStream` 用 `10000000+runId`）才能让各次运行的模式随机流独立；不传则所有运行共用同一序列。

## qKeep=0.80 变体与参数变体验收标准（2026-09-12）
- **源码默认本来就是 qKeep=0.80**；上次"Pruned 正式实验"是**配置覆盖成 0.70** 跑的。两批数据需要不同类名区分，否则数据会互相覆盖。
- 新算法 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080` = Pruned 的**源码同构副本**：`private/` 11 个模块 + 根级 3 个 .m 全部字节一致，主文件仅有 2 处差异（classdef 行、头部 5 行说明注释）。未复制 `diagnostics/`（旧产物引用旧路径会误导），另建 `source_provenance.json`。
- 数据目录 `D:\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080\`，16 题 × 18 次，参数 `{3000,0.50,0.25,0.80,6}`，其余口径（N/D/M/maxFE/种子/`run` 分流）与 0.70 组**完全一致** → 两组可直接配对比较。
- **「参数变体复制」验收标准（务必沿用）**：同种子同问题跑三组 —— 旧类+旧参数 / 旧类+新参数 / 新类+新参数；要求**后两者结果完全相同（差 0）**且**与第一组不同**。前者证明克隆忠实，后者证明该参数真的起作用。本变体已通过（DTLZ2, maxFE=106, 差 0 vs 差 6.15e-3）。
- 本仓 .m 文件是 **CRLF**；Write 工具产出 LF，需 `sed -i 's/$/\r/'` 补回。
- `tmp/supervise_part.sh` 已泛化，支持 `ALG`/`FOLDER`/`PARAMS`/`HARNESS` 环境变量覆盖，日志按 FOLDER 分目录。
- **qKeep 消融结论（2026-09-12，16 题 × 18 次全系列）**：qKeep=0.70 与 0.80 **8 胜 8 负、无系统性差异**；Holm 校正后唯一显著是 WFG6（0.80 好 2.0%，p_holm=0.031）。DTLZ5 q080 好 7.0%（p=0.108 未过校正）、WFG9 差 5.2%（p=0.067）。→ **可排除 qKeep 是 Pruned 退化的主因**，与"持续质量约束（0.75/0.25 权重）才是第一嫌疑"的判断互洽。
- 可复用脚本 `Experiments/REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries/compare_qkeep.py`：**配对** Wilcoxon + Holm + 胜负计数；两组同种子同 run 号时必须用配对设计（比独立样本秩和更有效）。
