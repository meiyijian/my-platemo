# HPDC-MaOEA 论文配图

本文按“两处接口、两个机制、对应证据”组织，建议正文使用 5 张图。图数是针对当前稿件的编辑判断，不是期刊硬性要求。另提供主性能总览作为补充图；主性能的准确均值和标准差继续以正文表格为准。

| 文件 | 要回答的问题 | 图形与证据 | 建议位置 |
|---|---|---|---|
| fig_framework | 两个贡献在算法的什么位置发挥作用？ | 整体闭环；突出分组接口与评估分配接口 | Overall Framework |
| fig_hybrid_grouping | 连续 PBI 和二值标签怎样共同形成正组？ | 两种 PBI 几何与由公式计算的排序例子 | Hybrid PBI-Based Quality Grouping |
| fig_candidate_selection | 每轮如何由大量候选得到少量真实评估？ | 模式先抽取、模式相关内循环、两条筛选路径、统一批次上限 | Dual-Mode Candidate Selection |
| fig_group_evidence | 分组后的集合与未来保留有什么联系？ | 原五问题研究；阶段 precision 与配对差值 | Analysis of Hybrid PBI-Based Quality Grouping |
| fig_candidate_evidence | 批量约束和两种准则产生什么可观察变化？ | 候选探针批次大小、分散性、接纳率、池内增益与逐问题最终 IGD 比值 | Analysis of Dual-Mode Candidate Selection |
| fig_performance_overview | 优势与例外分布在哪些问题及对手上？ | 10/20 目标全部 16 问题、7 基线的均值 IGD 比值 | 可选补充材料；与正文性能表二选一展示 |

## 绘制约定

- 使用已保存的 Python 绘图偏好。所有图形、PDF/SVG/PNG 导出及渲染检查均在 Python 中完成。
- 正文是英文稿，所以图内使用英文，文件说明使用中文。输出宽度 180 mm，白底，PDF 嵌入字体，SVG 保留文字，PNG 为 600 dpi 预览。未指定最终期刊，因此这是适配现有双栏稿的通用版本。
- 理论图使用明确标注的解析示例，不含实验测量。示例仅解释公式；不把二维示意图说成高维 Pareto 前沿。
- 分组证据限定原 5 问题 × 2 目标数 × 25 次运行，最终种群成员为真值，三个视图均取 top 25%。先在运行内平均检查点，再对配置和运行等权汇总。配对来自同一条已记录轨迹，不构成改换分组策略的因果实验。
- 候选证据使用全部 4 问题 × 5 策略 × 10 次运行。各策略有各自的闭环候选池。V0 是探针宿主中的 REMO 筛选规则。接纳率、池内增益使用后半程；批次大小和分散性使用完整轨迹。最终 IGD 与批次诊断分开解释。
- 不由汇总均值和标准差重造显著性。主性能总览展示均值比值，未添加检验星号。完整原表包含待核查重复数值，图中保留并标记。
- 暂不绘制最终实现的参数敏感性、收敛曲线或耗时图：目前可确认的数据不足以支撑这些图。不得用插值、旧变体或虚构数据补齐。

## 每张图的论点与风险检查

| 图 | 核心论点 | 类型 | 需要防止的误读 |
|---|---|---|---|
| 1 | 分组生成监督信息，候选模块控制昂贵评估的分配 | schematic-led composite | 指标模型使用当前已评价种群；真实评估之后才更新存档 |
| 2 | 连续分数细分同标签顺序，二值标签在后半程取得组间优先权 | schematic-led composite | 标签不是 Pareto 优劣；t=1 仅剩二值标签；代表边界示例固定正 delta，实际 delta 可有正负 |
| 3 | 一轮执行一种完整准则，并由保留集合和预算约束批量 | schematic-led composite | 模式会影响内循环评分；并非先建立固定共同池再并行选取；探索距离是决策空间原始欧氏距离 |
| 4 | 混合分组的平均保留关联有阶段差异 | quantitative grid | 250 条轨迹是独立运行单位，检查点不是独立重复；不能由关联推断最终 IGD 增益 |
| 5 | 批次诊断呈现不同侧重点，最终质量还需逐问题检查 | quantitative grid | 接纳率高不等于最终 IGD 最佳；不同问题不共用 IGD 原始尺度 |
| S1 | 主性能呈现明确的逐问题异质性 | quantitative grid | 均值比值不是显著性；标准差和统计符号仍以原表为准 |

## 导出参考

采用颜色配合形状、线型和直接文字标注；参考 [Elsevier artwork guidance](https://www.elsevier.com/about/policies-and-standards/author/artwork-and-media-instructions)（2026-09-06 查阅）。最终投稿前仍需按目标期刊作者指南核对尺寸和文件格式。

## 已交付内容

- `HPDC-MaOEA_figure_collection.pdf`：六张图的独立矢量图集，可先整体浏览。
- `figure_gallery.png`：六图总览。
- 六组 `fig_*.pdf/.svg/.png`：PDF 供 LaTeX 插图，SVG 保留可编辑文本，PNG 供预览。
- `figure_*.tex`：五张正文图和一张可选补充图的英文图注、插图代码。
- `build_figures.py`：绘图与数据汇总脚本；`requirements-figures.txt` 固定本次使用的包版本。
- `source_data/`：实际入图的数据、配对值、汇总与置信区间，以及解析示例输入。
- `manifest.json`：输入文件 SHA-256、实际包版本、尺寸、PDF 最小字形、数据筛选与汇总规则。
- `QA_验收说明.md`：数值、来源与逐面板图面检查记录。

五张正文图已经通过 `\input{figures/figure_*.tex}` 插入 `HPDC-MaOEA.tex`，并加入正文交叉引用。补充图没有加入正文。原有算法源码和实验数据未修改；主文修改前的备份保存在 `.figure_work/HPDC-MaOEA.before_figures.tex`。

## 复现

在仓库根目录执行：

```powershell
uv run --with-requirements '论文写作/figures/requirements-figures.txt' python -X utf8 '论文写作/figures/build_figures.py'
```

脚本读取已有的正式 CSV 和主性能工作簿，重建当前目录的六张图及数据包，不调用优化算法。输入工作簿若移动，可修改脚本中 `performance()` 的工作簿目录。需要检查确切文件身份时，查看 `manifest.json`。

LaTeX 编译在 `论文写作` 目录执行两次 `pdflatex -interaction=nonstopmode -halt-on-error HPDC-MaOEA.tex`。图中的 bootstrap 是对保存的运行级记录做重采样，不是重新运行算法；随机种子固定为 20260906。

## 配套阅读说明

图 2 最适合讲清楚第一项贡献：先看两个几何定义，再看下排 C、E 等二值正标签解如何进入正组。图 3 适合讲清楚第二项贡献：一轮选择一种准则，两条路径各有自己的内循环与筛选，最后都受批次上限约束。

图 4 应结合实验中的“未来最终种群保留率”定义阅读。新增五问题已存在于当前 CSV，但本图按原五问题协议筛选，确保与论文现有表格一致。图 5 中上排解释批次行为，下排给出相同问题、相同种子的最终 IGD 比值；例如 DTLZ7 的结果应与其接纳率一起解释。

后续若必须压缩篇幅，可将图 2 或图 3 放入补充材料；主性能总览与两张性能表之间也可择一保留。不要为了增加图数再把已有每张表都转换成柱状图。
