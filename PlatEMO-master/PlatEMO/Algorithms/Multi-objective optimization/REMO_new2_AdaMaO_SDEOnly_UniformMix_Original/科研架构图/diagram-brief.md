# Diagram Brief

## User Goal

- Output: 两张相互独立、可编辑、适合 16:9 组会 PPT 的科研架构图，并配套高清 PNG 预览。
- Audience: 熟悉多目标优化、代理辅助进化优化和 PlatEMO 的导师与课题组成员。
- Must communicate: 当前独立版本的混合 PBI 双路信号、硬化边界、共享关系代理、UniformMix 随机门控、Explore/Indicator 两支及其回退、真实评价与档案反馈。
- Must not do: 不混入旧版 confidence/coverage/degeneracy 门控、三指标轮盘、加权关系训练或未经实验支持的性能结论。

## Source Inventory

| id | source | type | role | priority | notes |
|---|---|---|---|---|---|
| S1 | `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m` | 源码 | 内容、结构 | 必须 | 主循环、两个代理、路由、评价、回退 |
| S2 | `private/HybridPBI_Classification.m` | 源码 | 内容、结构 | 必须 | 双路 PBI、融合、硬化、方向回退 |
| S3 | `private/GetOutput_PBI.m` | 源码 | 内容、结构 | 必须 | 锚点 PBI、自适应 δ、二值标签 |
| S4 | `private/GetRelationPairs.m`; `private/DataProcess.m` | 源码 | 内容、结构 | 必须 | 硬关系对与 75%/25% 划分 |
| S5 | `private/AdaMaOSelection.m` | 源码 | 内容、结构 | 必须 | 共享 GA、两种候选选择、关系打分 |
| S6 | `private/IndicatorSelectorSDEOnly.m`; `calFitness_SDE.m`; `Shape_Estimate.m` | 源码 | 内容、结构 | 必须 | SDE、Lp 与局部 Minkowski 回退 |
| S7 | `ResolveUniformMixMode.m`; `private/CreateSDECandidateModeStream.m` | 源码 | 内容、结构 | 必须 | 精确随机门控与独立随机流 |
| S8 | `visual-spec.md` | 已批准设计 | 布局、样式、验收 | 必须 | 用户确认的 PPT 视觉方案 |
| S9 | `topconf-memory-routing.png` | 本地参考图 | 样式、密度 | 应该 | 仅参考低饱和容器、强层级和反馈箭头，不复制内容 |

## Requirement Traceability

| id | requirement | source evidence | level | planned visual encoding |
|---|---|---|---|---|
| R1 | 两张分图而非总图 | 用户确认；S8 | 必须 | 两个独立 1600×900 页面文件 |
| R2 | 混合 PBI 为双路结构 | S2:48–101 | 必须 | 蓝色连续方向场通道 + 橙色锚点二值通道 |
| R3 | 低维/高维方向分支与回退 | S2:48–56,147–224 | 必须 | 菱形决策、蓝色主路、灰色虚线回退 |
| R4 | 显示 PBI 公式和 θ=5 | S2:72–89 | 必须 | 公式节点紧邻 `d1,d2` 节点 |
| R5 | 显示自适应 δ 与二值阈值 | S3:52–75,94–134 | 必须 | δ 二分搜索节点 + `g≤1` 二值标签节点 |
| R6 | 显示随 FE 变化的融合 | S2:95–101 | 必须 | 紫色融合节点与早/后期权重刻度 |
| R7 | 显示 top-rGood 硬化及信息损失 | S2:108–122; S4 | 必须 | 排名漏斗、Catalog、红灰色边界注释 |
| R8 | 候选模式共享关系代理与 GA 池 | S1:41–86; S5:52–80 | 必须 | 两分支前的共享蓝色主干 |
| R9 | 门控仅由模型可用性、u 和 pMix 决定 | S1:30–34,67–68; S7 | 必须 | 中央紫色菱形 + “非门控条件”注释 |
| R10 | Explore 的模糊度、分位筛选和多样性 | S5:123–186,252–445 | 必须 | 青绿阶段链和 0.75/0.25 公式 |
| R11 | Indicator 的关系粗筛、SVR 与回退 | S5:188–250 | 必须 | 橙色阶段链 + 灰色虚线回退 |
| R12 | 真实评价、FE 裁剪和 Archive 反馈 | S1:88–100 | 必须 | 右侧真实评价节点 + 底部回环 |
| R13 | 关系对为空和 Next 为空的安全路径 | S1:43–45,88–93 | 应该 | 底部灰色虚线保护路径 |
| R14 | PPT 投影可读、中文主标签 | 用户选择 PPT；S8 | 必须 | 14–32 pt 层级、微软雅黑、短标签 |
| R15 | 不出现性能曲线或因果结论 | S8 | 必须 | 全图仅机制与实现边界 |

## Semantic Model

| id | entity or relationship | direction / hierarchy / cardinality | visual encoding | uncertainty |
|---|---|---|---|---|
| C1 | `Population → {direction PBI, anchor PBI}` | 一对二数据 fan-out | 两条实线箭头 | 无 |
| C2 | `UniformPoint/AdaptiveReferenceVectors → V` | 二选一控制汇合 | 菱形 + 汇合箭头 | 无 |
| C3 | `V + PopObj → score_v` | 多输入计算 | 蓝色实线链 | 无 |
| C4 | `RefSelect + PopObj → label_dyn` | 多输入计算 | 橙色实线链 | 无 |
| C5 | `{score_v,label_dyn,ratio} → score_hybrid` | 三输入 fan-in | 紫色汇合节点 | 无 |
| C6 | `score_hybrid → Catalog → hard relation pairs` | 排序、选择、监督构造 | 漏斗 + 绿色下游 | 无 |
| C7 | `Catalog/Population.decs → patternnet` | 训练数据流 | 蓝色模型准备链 | 无 |
| C8 | `Population.objs → SDE → RBF-SVR` | 指标代理训练流 | 橙色模型准备链 | 无 |
| C9 | `relation model → shared GA loop` | 代理排序控制 | 蓝色实线箭头与回环 | 无 |
| C10 | `{IndicatorModel available,u,pMix} → mode` | 二值控制分支 | 紫色菱形 | 无 |
| C11 | `shared pool → Explore/Indicator` | 一对二候选数据 fan-out | 两条实线箭头 | 无 |
| C12 | `Indicator SVR failure → relation score` | 异常回退 | 灰色虚线 | 无 |
| C13 | `{Explore,Indicator} → true evaluation` | 二对一选择汇合 | 紫色合流 | 无 |
| C14 | `true evaluation → Archive → Population` | 更新反馈回路 | 底部深灰回环箭头 | 无 |
| C15 | `empty relation pairs/empty Next → safe fallback` | 条件保护 | 灰色虚线旁路 | 无 |

## Style Contract

| id | font | palette | stroke | icon style | layout density | reference source |
|---|---|---|---|---|---|---|
| ST1 | 微软雅黑；Arial 作为公式后备 | 背景 `#FAFBFD`；深色文字 `#16324F` | 主框/主箭头 2 px | 不使用图片图标；全部为可编辑几何元件 | 中高密度但保留 24–40 px 组间留白 | S8、S9 |
| ST2 | 标题 30 pt；区标题 20 pt；节点 15–17 pt；脚注 12–13 pt | 蓝 `#2F6BFF/#E8F2FF`；橙 `#E8873A/#FFF0E3`；青绿 `#2A8F7A/#E7F6F2`；紫 `#7756C5/#F0EAFE`；灰 `#687387/#F1F3F6` | 圆角 12–16；回退线 `dashPattern=6 4` | 决策菱形、分组容器、漏斗、反馈回环 | 单页 5–7 个主区，每区 2–5 个步骤 | S8、S9 |

## Open Assumptions

| assumption | risk | how to verify |
|---|---|---|
| 微软雅黑在本机 Chrome/draw.io 中可正确渲染中文 | 字体回退会改变换行和盒宽 | 第一轮截图逐框检查，必要时改为更宽盒或 Arial/Noto Sans CJK |
| diagrams.net 的 `ui=atlas` 预览能在 1920×1200 视口中显示完整 16:9 页面 | 页面缩放不当会使截图包含过多 UI 或裁边 | 先全屏截图定位页面，再用 iframe/画布裁剪；图内容必须占 ≥80% |
| PNG 截图足以作为 PPT 预览，SVG 仅在本地导出工具可靠时提供 | 浏览器截图可能比原生 SVG 略软 | 使用 ≥1920 px 宽画布并检查文字；如有 draw.io CLI，再导出并对照 |
| 不需要算法/机构 logo 或外部图标 | 过度简化可能降低视觉层次 | 用区标题、编号、线型和公式承担层次，不添加无语义装饰 |

