# PACDIS 命名修改说明

修改日期：2026-09-07。

修改前基准提交：`437597b425e14c337f0703ea29b3a42d3ee9376a`。

## 论文

目标文件仍为 `HPDC-MaOEA.tex`；文件名保持不变，文中的整体算法名称由 HPDC-MaOEA 统一为 **PACDIS**。

标题改为：

> PBI-Assisted Quality Classification and Criterion-Diversified Infill Selection for Expensive Many-Objective Optimization

| 原名称 | 新名称 | 涉及位置 |
|---|---|---|
| HPDC-MaOEA | PACDIS | 方法总述、框架说明、算法 1、复杂度相关叙述、配套图件 |
| Hybrid PBI-Based Quality Grouping / HPC | PBI-Assisted Quality Classification（PAQC） | 贡献段、方法小节、正文模块引用、图注及框架图 |
| Dual-Mode Candidate Selection | Criterion-Diversified Infill Selection（CDIS） | 贡献段、方法小节、正文模块引用、图注及框架图 |
| HybridGroup | PBIQualityClassification | 算法 1 调用、算法 2 标题 |
| DualModeSelect | DiversifiedInfillSelection | 算法 1 调用、算法 3 标题 |

子过程使用 `ContinuousPBIQualityAssessment`、`RepresentativeBasedClassification`、`ExplorationBasedInfill` 和 `IndicatorBasedInfill`；正文将名称嵌入原有机制说明，伪代码保留可复现的计算步骤。

更新了 PAQC/CDIS 对应的内部交叉引用。描述融合得分的 `hybrid score`、数学公式、算法步骤及已有实验结论保持原意。摘要、相关工作、结论等原有 TODO 保留。

图件使用已有脚本重新生成：框架图标记 PAQC/CDIS，候选证据图的 V4 显示为 CDIS，性能图的算法显示名改为 PACDIS。既有图件文件名和源数据字段名保留；源数据 CSV 无改动。

## 源码

目标目录：`PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original`。

| 原函数或文件 | 新函数或文件 |
|---|---|
| `private/HybridPBI_Classification.m` | `private/PBIQualityClassification.m` |
| 连续 PBI 得分的内联计算 | `PBIQualityClassification.m` 内部的 `ContinuousPBIQualityAssessment` |
| `private/GetOutput_PBI.m` | `private/RepresentativeBasedClassification.m` |
| `private/AdaMaOSelection.m` | `private/DiversifiedInfillSelection.m` |
| `select_explore` | `ExplorationBasedInfill` |
| `select_indicator` | `IndicatorBasedInfill` |

主入口及 `_k6` 入口调用同步修改，相关注释和现有测试的文件引用同步更新。选择模块中原先描述诊断阈值路由的过时注释，改为当前实际采用的 `pMix` 概率选择与指标模型可用性说明。

两个算法入口的 `classdef`、主文件名、目录名、参数顺序、默认值、错误标识、模式字符串和随机数调用保持不变。历史实验数据、实验算法标识及实验目录中的冻结副本均未修改。

## 验证

- 14 个运行源码文件：逆向替换名称并内联新提取的连续 PBI 子过程后，可执行语句与修改前逐行一致。
- 六组固定随机种子的前后对照：主入口覆盖 M=3/10 与 pMix=0/1，`_k6` 入口覆盖 M=3 与 pMix=0/1。最终解的决策值、目标值、约束值、真实评价次数以及随机数状态完全一致。
- 现有独立运行测试：8 项全部通过。
- LaTeX 连续编译两遍成功，输出 6 页；无 Overfull 文字越界，已检查页面排版和框架图。
- 当前原稿尚无实验章节，原有三处未定义标签继续保留：`sec:exp:paqc`（原为 `sec:exp:hpc`）、`sec:exp:candidate`、`sec:exp:sensitivity`。没有新增缺失引用。
- CVP/CDR 的冻结副本检查在改名前已与主程序的分类文件不一致。本次未修改其历史冻结副本或放宽校验；这些旧实验脚本若要重新运行，需要单独处理对应版本的源码校验。本次未重跑正式实验。

MATLAB 连接工具未能连接已有会话，因此验证使用本机 MATLAB R2023a 批处理完成。

## 提交与回退

论文、图件和对应源码在同一次提交中保存。通过该文件的 Git 历史可定位本次命名提交；向用户交付时同时报告提交编号。

若需撤销本次更名，优先对该提交执行 `git revert <本次提交编号>`，再正常推送；该方式新增撤销提交，保留已有历史。不要仅回退主程序调用或仅回退私有函数文件，否则会产生名称不匹配。

`论文写作/AGENTS.md` 已记录用户要求：以后每次修改 `HPDC-MaOEA.tex` 后，完成检查、自动提交推送，并报告改动和提交编号。
