# 项目指引与技能整理（2026-09-13）

## 范围与结论

检查了项目指引、项目自有技能、个人安装技能的入口体量及部分相关正文。重点修正四项有明确问题的技能；没有逐行审计所有科研套件、第三方克隆及插件，也没有检查所有技能的上游最新版。“未改动”不等于已证明最新或无问题。

原项目只有 `论文写作/AGENTS.md`；根目录缺少项目入口指引。全局 `C:/Users/lsx/.codex/AGENTS.md` 为空。

## 已完成

| 文件/技能 | 问题与处理 |
|---|---|
| 根目录 `AGENTS.md` | 新增简短目录定位、证据边界、FE 核对和技能按需使用指引；不固化历史实验结论。 |
| `论文写作/AGENTS.md` | 原文精简且仍有效，保留修改 TeX 后自动检查、提交、推送的约定；明确仅整理指引不触发。 |
| `using-superpowers` | 删除“1% 相关就必须加载”、强制所有对话走流程及未提供工具的假设；约 92 行缩至 15 行。 |
| `literature-review` | 删除强制 AI 配图、固定 CLI、无关技能清单、重复筛选段落和默认 PDF 交付；保留检索记录、筛选、质量评价与引用核验。约 264 行缩至 52 行。旧参考文件保留，入口明确其中特定服务与配图流程为可选示例。 |
| `gpt-image` | 解决“只能 CLI”和宿主生图的冲突；缩窄触发范围，图库按需读取，更新 UI 提示。CLI 依赖移到对应正文，避免误用于宿主生图。 |
| `platemo-algo-port` | 约 86 行缩至 32 行。删除机械真实评估替换、错误工具箱归因和未经验证的 no-op 保证；修正 kmeans 默认值，保留源码核对与 FE 验证。 |

个人技能位于 `C:/Users/lsx/.codex/skills/`，影响其他项目且不受本项目 Git 管理。项目适配技能位于 `PlatEMO-master/.workbuddy/skills/platemo-algo-port/`；本次没有将它另行安装到 Codex 技能目录。

## 保留与使用分工

| 任务 | 优先选择 | 边界 |
|---|---|---|
| 完整研究到论文的多阶段工作 | `academic-research-suite` | 入口约 413 行，确实偏长，但包含工作流与运行适配；本次保留，按阶段读取，不给普通修文叠加完整流水线。 |
| 找论文、核引用、查引用关系 | `nature-academic-search` | 单篇查询无需启动系统综述。 |
| 多文献综述与证据综合 | `literature-review` | 先区分叙述性和系统性综述；不预设配图数量。 |
| 研究方向探索 | `scientific-brainstorming` | 保留假设与证据分离；入口提及的其他技能须确认可用，不因名称出现就假定已安装。 |
| 正文起草 / 润色 / 审稿 / 回复 | 对应 `nature-writing`、`nature-polishing`、`nature-reviewer`、`nature-response` | 按实际请求选，不默认全部串联。 |
| 统计报告 / 数据可用性 | `nature-statistics` / `nature-data` | 对应专项需求时启用。 |
| 常规科学图 / 指定 Nature 风格交付 | `scientific-visualization` / `nature-figure` | 两者重叠但侧重点不同。后者另有后端选择及严格交付流程；保留，不作为每次小改图的默认入口。 |
| 中文论文组会 PPT / 通用幻灯片 | `nature-paper2ppt` / `presentations` | 前者负责论文叙事，后者负责幻灯片文件交付；需要时衔接。 |
| 普通生图 / 图库和 CLI | 宿主生图能力 / `gpt-image` | 科研数值图依照真实数据与绘图工具生成。 |
| MATLAB 专项工作 | 对应 MATLAB 技能 | 按调试、性能、测试等任务调用；Simulink 技能并不因同属 MathWorks 就与本项目相关。 |

`agent-skills/` 已由 `.gitignore` 排除，是第三方仓库集合。磁盘上的副本不等于当前会话全部加载；本次未删除这些仓库，也未修改系统技能和插件缓存。后续若要减少磁盘占用，应另查实际引用与安装来源。

## 核对依据与验证

- 直接核对了本 checkout 的 `SOLUTION.m`、`PROBLEM.m`、`OperatorGA.m` 和 `ALGORITHM.m`：FE 增量、矩阵/对象算子分支以及路径处理与新版技能描述一致。
- [MathWorks kmeans 文档](https://www.mathworks.com/help/stats/kmeans.html)列出当前 `EmptyAction` 默认为 `singleton`；实际运行仍核对本机版本及同名函数。
- 参考 [OpenAI 技能文档](https://learn.chatgpt.com/docs/build-skills)和 [AGENTS.md 文档](https://learn.chatgpt.com/docs/agent-configuration/agents-md)，采用简短入口和按需加载。
- 校验使用 UTF-8 Python 和临时 uv 环境中的 PyYAML；不使用 WindowsApps 的 Python 占位程序。检查技能前置元数据、Markdown 本地链接、UI YAML 和 Git 空白差异。
- 本次仅修改指导文档，未运行 MATLAB 实验、论文编译、生图或真实文献综述；格式校验不能证明后续所有任务中的行为效果。

## 备份与回退

原文备份：`D:/PlatEMO-master/.codex_work/instruction-cleanup-20260913/`。`manifest.json` 记录备份文件到原路径的映射，包含三个个人技能入口、GPT Image UI 元数据及两个项目原文件。

回退时先检查这些文件是否有后续修改，再按 manifest 逐文件恢复；不要覆盖后续工作。根 `AGENTS.md` 和本报告是新增文件，备份中无对应旧版本。备份位于本地 Git 忽略目录，需在其他机器回退时单独保留。

本次未修改 TeX，因此未触发论文目录的自动提交/推送约定；改动留在工作区供查看。
