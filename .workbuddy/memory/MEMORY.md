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
