# 项目工作指引

- MATLAB/PlatEMO 主目录：`PlatEMO-master/PlatEMO/`；论文：`论文写作/`。编辑前确认实际入口、私有辅助函数和当前 Git 差异。
- 修改 `论文写作/HPDC-MaOEA.tex` 时遵循该目录的 `AGENTS.md`；其中的自动提交和推送约定仍有效。
- 算法判断从源码、调用路径、真实评估计数和对应实验输入出发。区分机制解释、描述性关联、因果归因和最终 IGD/HV 性能。
- 保留与既有实验数据关联的类名、入口、参数和结果标识。历史协议中的预算、目标数、模式和结果不能默认代表当前任务；先核对对应源码与数据。
- 修改评估或候选生成逻辑时检查 `Problem.Evaluation` 的实际调用与 FE 增量；先做针对性小预算验证，再决定是否需要完整实验。
- 技能按当前交付物选择：普通修文、查代码或解释公式不默认启动完整科研流水线。技能选择与维护记录见 `docs/agent-skill-audit-2026-09-13.md`，仅在整理技能时阅读。
- `agent-skills/` 是被 Git 忽略的第三方技能仓库集合；不要把其中每份 `SKILL.md` 当成本项目常驻指令。系统和插件缓存由其安装机制维护。

## 实验流水线资产

- **给单个算法跑十目标全系列 + 出 IGD/IGDp 对比表**的完整流程，已打包在
  `PlatEMO-master/.workbuddy/pipelines/algorithm_full_series/`（README + 11 个脚本模板）。
  六个阶段：**路径体检 → 测速 → 跑全系列 → 补 IGDp → 出对比表 → 校验**。
  换算法只需改算法名、目录和 manifest 清单；固定口径（16 題 × runs 1–20、
  `N=100 M=10 D=30 maxFE=300`、种子 `20260912 + M*1e5 + 题号*1000 + runId`、
  符号用 MATLAB `ranksum`、蓝标 = 行内最低均值）与踩坑清单都写在包内 README 里。
- 外部/移植算法**动手前必做路径体检**（包内 `Probe*.m`）：全库同名 helper 会静默抢占；
  若算法初始设计就超预算（如 `NI = 11*D-1`）或每轮只加 1 个真评估点，要先测速再决定跑量。
- 相关技能：`platemo-variant-ablation`（变体派生与统计检验）、`paper-main-table-refresh`
  （论文主表数据刷新）、`platemo-algo-port`（算法移植）、`paper-cn-mirror`（中文对照稿）。

