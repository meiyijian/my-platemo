# 科研架构图缺陷与修复日志

本文件在首次截图后保持追加式记录；不删除或重写既有审阅结果。

## 混合 PBI — Screenshot Review Cycle 1

截图：`混合PBI_cycle1.png`（1600×900，画布内容占比超过 90%）。  
预检：0 FAIL；1 WARN（输入 fan-out 所在 200×200 网格有 9 条线段，需结合截图判断）。

### P0 — Blockers

未发现缺失核心机制、错误箭头方向、文本截断或箭头穿越节点等 P0。

### P1 — Visible Defects

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| MP1-01 | Z2 箭头 | `edge_popobj_to_assoc`, `edge_ratio_alpha` | 两条长距离输入线几乎共用页面上方走廊，`PopObj` 与 `ratio` 标签相邻，难以快速追踪 | cycle1 顶部蓝色容器上沿 | OPEN |
| MP1-02 | Z2 箭头 | 输入 fan-out | 多条输入线在左侧同一网格汇出，印证预检 edge-density WARN | cycle1 左中部 x≈200–300 | OPEN |
| MP1-03 | Z1 文本 | 多数 edge labels | 12 pt 标签在 1600×900 PPT 截图中偏小 | cycle1 全图 | OPEN |
| MP1-04 | Z1 文本 | `edge_uniform_to_v`, `edge_adaptive_to_v`, `edge_fallback_uniform` | “均匀 V / 数据依赖 V / 异常回退”在狭窄汇合区堆叠 | cycle1 通道 A 中央 | OPEN |
| MP1-05 | Z2 箭头 | `edge_fallback_uniform` | 回退线与两个主 fan-in 连接过近，主/回退层级不够清楚 | cycle1 通道 A 中央 | OPEN |
| MP1-06 | Z1 文本 | `vector_field` | “Nref 个单位方向”被拆成“方/向”，破坏术语完整性 | cycle1 通道 A 的 V 节点 | OPEN |
| MP1-07 | Z1 文本 | `uniform_vectors` | “单位化”出现不自然换行 | cycle1 通道 A 均匀方向节点 | OPEN |
| MP1-08 | Z1 文本 | `direction_fallback_note` | 失败条件说明过长、字号小、对比度低，抢占局部空间 | cycle1 通道 A 右下 | OPEN |
| MP1-09 | Z7 语义 | `continuous_pbi` | 计算框未就地写明投影使用 `PopObj−Zmin`，需依赖底部脚注才能消除歧义 | cycle1 通道 A 最右 | OPEN |
| MP1-10 | Z3 盒体 | `binary_pbi` | 宽度仅 130 px，四行公式与标签显得拥挤 | cycle1 通道 B 最右 | OPEN |
| MP1-11 | Z1 文本 | `anchor_semantic_note` | 12 pt 斜体注释对 PPT 投影偏小 | cycle1 通道 B 底部 | OPEN |
| MP1-12 | Z1 文本 | `edge_ref_to_anchor`, `edge_anchor_to_delta`, `edge_delta_to_binary` | 短边上的 `RefObj/子区域/δ` 标签紧贴框边 | cycle1 通道 B 中部 | OPEN |
| MP1-13 | Z1 文本 | `edge_label_hybrid`, `edge_hybrid_rank` | `label_dyn` 与“融合值”在混合得分下方走廊形成视觉竞争 | cycle1 紫色容器左/中 | OPEN |
| MP1-14 | Z1 文本 | `edge_catalog_pairs` | “硬组别”标签压在紫色容器右边界附近 | cycle1 紫绿容器之间 | OPEN |
| MP1-15 | Z1 文本 | `hardening_note` | 关键边界说明在窄框中断成两行，最后一个字孤立 | cycle1 紫色容器底部 | OPEN |
| MP1-16 | Z4 间距 | `hardening_note` | 与 `catalog_box`、容器底边间距过紧 | cycle1 紫色容器底部 | OPEN |
| MP1-17 | Z6 字体 | 三个底部证据框 | 13 pt 长句在投影场景中略小 | cycle1 底部 | OPEN |
| MP1-18 | Z3 盒体 | `params_box` | `k_eff` 公式换行较碎，第三行密度明显高于其他输入框 | cycle1 左下输入栏 | OPEN |
| MP1-19 | Z7 构图 | 输入到两通道的长线 | 上方与左侧线路使信息流略像电路图，弱化“两个科学表征”的主叙事 | cycle1 左半页 | OPEN |
| MP1-20 | Z6 字体 | `direction_fallback_note`, `anchor_semantic_note`, `hardening_note` | 三类同级边界注释字号/字重不一致 | cycle1 三个主区域 | OPEN |

### P2 — Polish

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| MP1-21 | Z4 间距 | 通道 A 内部节点 | 决策、双分支、V 与得分框的水平间距节奏不完全一致 | cycle1 蓝色容器 | DEFER |
| MP1-22 | Z4 间距 | 通道 B 四节点 | 最后一个框明显窄于前三个框 | cycle1 橙色容器 | OPEN |
| MP1-23 | Z3 盒体 | `continuous_pbi` | 四行内容略紧，可增加内部留白 | cycle1 蓝色得分框 | OPEN |
| MP1-24 | Z4 间距 | 三个底部注释框 | 宽度 482/474/490 不完全一致 | cycle1 底部 | DEFER |
| MP1-25 | Z5 色彩 | `hardening_note` | 红色警示仅出现一次，需确认其语义价值大于新增色彩成本 | cycle1 紫色容器底部 | ACCEPT（信息边界专用） |
| MP1-26 | Z6 字体 | `edge_decision_uniform`, `edge_decision_adaptive` | “是/否”靠近菱形尖角，略显拥挤 | cycle1 决策菱形右侧 | OPEN |
| MP1-27 | Z7 构图 | 绿色下游容器 | 容器底边高于紫色容器底边，整体基线不齐 | cycle1 右侧 | ACCEPT（下游步骤更少） |
| MP1-28 | Z7 构图 | 图一整体 | 没有显式阶段编号，讲解时主要依赖颜色和箭头顺序 | cycle1 全图 | DEFER（避免增加噪声） |
| MP1-29 | Z8 图标 | 全图 | 未使用图标；当前由公式、容器与箭头承担语义 | cycle1 全图 | ACCEPT（规格要求无装饰） |
| MP1-30 | Z9 一致性 | 全图 | 容器风格统一，但密集 edge labels 使局部仍偏工程流程图 | cycle1 全图 | OPEN |
| MP1-31 | Z1 文本 | `delta_search` | `[0.3,0.7]` 前后的行距略显挤 | cycle1 橙色 δ 节点 | OPEN |
| MP1-32 | Z1 文本 | `catalog_box` | Top-rGood 与 3/4 分组信息在 88 px 高度内稍密 | cycle1 紫色 Catalog 节点 | OPEN |
| MP1-33 | Z2 箭头 | `edge_catalog_pairs` | 外绕折线语义正确，但路径较长 | cycle1 紫绿容器之间 | ACCEPT（避免穿越其他框） |
| MP1-34 | Z9 一致性 | 中英文混排 | `score_v`、`label_dyn`、函数名与中文的基线略有差异 | cycle1 全图 | ACCEPT（保留代码可追踪性） |

## 混合 PBI — Screenshot Review Cycle 2

截图：`混合PBI_cycle2.png`。  
预检：0 FAIL；1 WARN（左侧输入 fan-out 仍为 8 条线段，已从 9 降到 8）。

### Cycle 1 Fix Verification

| defect ids | fix | cycle2 evidence | status |
|---|---|---|---|
| MP1-03,06,07,11,17,18,20 | 放大标签/脚注，重写 V、UniformPoint 和参数文本 | 术语不再断字，底部脚注可直接阅读 | FIXED |
| MP1-08,09,23 | 缩短回退说明；PBI 框就地写入 `PopObj−Zmin` | 通道 A 最右和右下 | FIXED |
| MP1-10,22,31 | 扩宽二值框并精简 δ 文本 | 通道 B 最右 | PARTIAL：二值归一化公式仍断行不佳 |
| MP1-13,14,15,16 | 缩短融合/下游边标签和硬化注释 | 紫色区的文字竞争明显减少 | FIXED |
| MP1-04,05,12,26,30 | 缩短局部 edge labels 并统一为 13 pt | 两个通道的局部标签更清楚 | PARTIAL：部分短边标签仍无必要地挤在框间 |
| MP1-01,19 | 将 ratio 从顶部走廊移出 | 顶部只剩 PopObj 线 | REGRESSION：ratio 形成醒目的外框式长路径 |
| MP1-02 | 分离 ratio 线路 | 预检热点 9→8 | PARTIAL：输入 fan-out 仍为唯一 WARN |

### P0 — Blockers

未发现 P0。

### P1 — Visible Defects

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| MP2-01 | Z2 箭头 | `edge_ratio_alpha` | 新路线沿主图左、下、右三侧形成紫色“外框”，比原问题更抢眼 | cycle2 主图外围 | OPEN |
| MP2-02 | Z1 文本 | `edge_ratio_alpha` | `ratio` 标签孤立在底部中间，远离源与目标 | cycle2 注释带上方 | OPEN |
| MP2-03 | Z1 文本 | `binary_pbi` | `g/‖Ref−Zmin‖≤1` 仍在窄框中不自然断行 | cycle2 通道 B 最右 | OPEN |
| MP2-04 | Z1 文本 | `edge_uniform_to_v`, `edge_adaptive_to_v` | “均匀/自适应”可由源节点直接推知，保留标签反而增加汇合区密度 | cycle2 通道 A 中央 | OPEN |
| MP2-05 | Z1 文本 | `edge_ref_to_anchor`, `edge_anchor_to_delta`, `edge_delta_to_binary` | `Ref/区域/δ` 位于很短的框间距内，仍贴近边界 | cycle2 通道 B 中央 | OPEN |
| MP2-06 | Z2 箭头 | 左侧输入 fan-out | 预检仍报 8 线段热点；截图中输入与两通道的汇出区偏密 | cycle2 x≈200–300 | OPEN |
| MP2-07 | Z9 一致性 | 通道 A 中央 | 主连接、回退连接和说明文字同时存在，层级仍略拥挤 | cycle2 V 周围 | OPEN |
| MP2-08 | Z6 字体 | `direction_fallback_note` | 斜体灰注释可读但对比度略低于橙色通道的同级说明 | cycle2 通道 A 右下 | OPEN |

### P2 — Polish

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| MP2-09 | Z4 间距 | `continuous_pbi` | 公式框上下内边距仍稍紧 | cycle2 通道 A 最右 | OPEN |
| MP2-10 | Z4 间距 | 三个底部说明框 | 左/中/右框内文本分别为 2/2/3 行，视觉密度不等 | cycle2 底部 | DEFER |
| MP2-11 | Z5 色彩 | `edge_ratio_alpha` | 大面积紫线使门控色在图一中权重过大 | cycle2 外围 | 随 MP2-01 修复 |
| MP2-12 | Z7 构图 | `relation_container` | 右侧下游区较窄且纵向空白略多 | cycle2 右侧 | ACCEPT（强调其为下游） |
| MP2-13 | Z8 图标 | 全图 | 无图标，语义依赖公式与流程框 | cycle2 全图 | ACCEPT |
| MP2-14 | Z9 一致性 | 英文变量 | `Nref` 与其他变量的上下标风格不完全一致 | cycle2 蓝色 V 节点 | OPEN |
| MP2-15 | Z1 文本 | `edge_pop_to_decision` | `N、M` 位于输入容器与菱形之间，略靠近容器边线 | cycle2 左上 | DEFER |

## 混合 PBI — Screenshot Review Cycle 3

截图：`混合PBI_cycle3.png`。  
预检：0 FAIL，1 WARN；WARN 仍为左侧多源输入的局部线段密度，结合截图逐条核验。

### Cycle 2 Fix Verification

| defect ids | fix | cycle3 evidence | status |
|---|---|---|---|
| MP2-01,02,11 | 将 ratio 线移入上下通道间的内部走廊 | 紫色外框消失，主图边界恢复干净 | FIXED |
| MP2-03 | 将二值 PBI 写成四行：`g`、`ĝ`、阈值 1、否则 0 | 公式不再在窄框中异常断行 | FIXED |
| MP2-04,05 | 删除可由源/目标框推断的短边标签 | 两个通道的局部拥挤显著下降 | FIXED |
| MP2-08 | 提高方向回退注释的颜色与字重 | 蓝色通道右下说明可直接阅读 | FIXED |
| MP2-06 | 保留源码真实的多源 fan-out，并逐条核对颜色与端点 | 无交叉穿框、无错误箭头；仅工具密度告警 | ACCEPT WITH EVIDENCE |

### P0 — Blockers

未发现 P0。

### P1 — Visible Defects

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| MP3-01 | Z2 箭头 | `edge_ratio_alpha` | 内部走廊仍贴住橙色虚线顶边，局部看似容器轮廓 | cycle3 上下通道交界 | FIXED：上移至 y=416 并删除冗余“进度”标签 |

### P2 — Polish

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| MP3-02 | Z2 箭头 | 左侧输入 fan-out | 预检持续报告 8 线段热点 | cycle3 左侧 x≈200–300 | ACCEPT：截图中端点、颜色与路径均可区分，无穿框或歧义 |
| MP3-03 | Z1 文本 | `edge_pop_to_decision` | `N、M` 标签贴近输入框边缘且信息可由判定菱形推知 | cycle3 左上 | FIXED：删除标签 |
| MP3-04 | Z9 一致性 | `vector_field` | `Nref` 与其他下划线变量风格不一致 | cycle3 通道 A | FIXED：改为 `N_ref` |
| MP3-05 | Z4 间距 | `continuous_pbi` | 数学内容密度高于相邻节点 | cycle3 通道 A 右侧 | ACCEPT：四条公式均为理解连续 PBI 的必要最小集合 |
| MP3-06 | Z4 间距 | 三个底部证据框 | 右框三行、其余两行，密度略不均 | cycle3 底部 | ACCEPT：保留三项不同证据边界，不人为删减 |
| MP3-07 | Z5 色彩 | `anchor_semantic_note` | 橙红色注释比蓝色回退注释更醒目 | cycle3 通道 B 底部 | ACCEPT：该句明确“非 Pareto 好/坏”，属于关键语义警示 |
| MP3-08 | Z6 字体 | 二值 PBI 的变量行 | `ĝ` 与中文阈值说明字号较小 | cycle3 通道 B 右侧 | ACCEPT：PPT 原尺寸可读，扩大将挤压流程间距 |
| MP3-09 | Z7 构图 | `hardening_note` | 红色硬化边界在紫色容器中权重较高 | cycle3 融合区底部 | ACCEPT：这是连续信号转硬标签的核心证据边界 |
| MP3-10 | Z1 文本 | `edge_popobj_to_assoc` | 顶部 `PopObj` 标签距离主标题副标题较近 | cycle3 通道 A 上沿 | ACCEPT：仍有明确留白，且保留跨通道输入可追溯性 |

最终复核：`混合PBI_final.png` 中 MP3-01、MP3-03、MP3-04 均已消失；无新 P0/P1，ratio 线位于两通道留白且未与虚线边界重叠。

## 混合 PBI — Red-Team Audit

红队从“是否可能让论文读者得出错误机制结论”出发，逐项反查源码语义。

| id | challenge | evidence checked | resolution |
|---|---|---|---|
| MRT-01 | `score_v` 是否误画成理想点距离 | 图中明确 `d1/d2` 与 `d1+θd2` | PASS |
| MRT-02 | 方向关联和投影是否混用了坐标 | 关联框写 raw `PopObj`，投影框写 `PopObj−Zmin` | PASS |
| MRT-03 | 高维方向是否遗漏第一前沿与 K-means | 自适应方向框完整标示两步 | PASS |
| MRT-04 | 自适应方向失败后是否有回退 | 蓝色通道保留回退至 `UniformPoint` 的注释与虚线 | PASS |
| MRT-05 | 二值通道是否被误称真实 Pareto 标签 | 橙色语义注释明确“并非真实 Pareto 好/坏” | PASS |
| MRT-06 | `δ` 是否被画成固定常数 | 图中标示二分搜索 `[-20,20]` 与目标 true 比例 | PASS |
| MRT-07 | 融合权重方向是否反了 | `α=1−ratio`，并写明早期连续场、后期锚点标签 | PASS |
| MRT-08 | 连续融合是否被误画成连续监督 | Catalog 框与红色边界明确 Top-rGood 硬化 | PASS |
| MRT-09 | relation pair 标签是否遗漏反向样本 | `0/+1/−1` 三类与正反向均标出 | PASS |
| MRT-10 | `DataProcess` 是否误称解级独立划分 | 仅写“按标签分层 75%/25%”，未扩张为解级无泄漏 | PASS |
| MRT-11 | patternnet 是否误加权或校准 | 图中明确普通、无样本权重，并只输出 `p_err` | PASS |
| MRT-12 | confidence 是否被误称概率或主流程门控 | 底部证据框明确仅为表征一致性且主程序未使用 | PASS |

红队结论：0 P0、0 P1；12 项高风险语义均可由图中文字直接判定，无需依赖口头补充。

## 混合 PBI — Self-Score

| dimension | score / 10 | rationale |
|---|---:|---|
| 源码语义忠实度 | 10 | 两路 PBI、坐标差异、融合、硬化与关系训练均可追溯 |
| 信息层级 | 9 | 输入—双通道—融合—监督主链明确；少量跨区输入线不可避免 |
| PPT 可读性 | 9 | 1600×900 下主节点与公式可读，最小正文约 13 pt |
| 视觉一致性 | 9 | 蓝/橙/紫/绿语义稳定，圆角、线宽和字体统一 |
| 证据边界与可讲述性 | 10 | 显式标出非 Pareto 标签、硬监督及未使用 confidence |
| **总分** | **47 / 50** | 每项均 ≥ 6，满足交付门槛 |

## 候选解模式 — Screenshot Review Cycle 1

截图：`候选解模式_cycle1.png`。  
预检：0 FAIL，6 WARN；4 项为跨分区对齐导致的间距统计，1 项为空反馈容器，1 项为 GA/门控交界的线段密度。均需结合截图复核。

### P0 — Blockers

未发现缺失主分支、错误门控条件、箭头反向或文本截断到不可读的 P0。

### P1 — Visible Defects

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| CM1-01 | Z1 文本 | `relation_inputs` | “决策变量”在窄框内断成“决策变/量” | cycle1 左上 | OPEN |
| CM1-02 | Z2 箭头 | `edge_gate_explore` | “否则/模型无效”与菱形、绿色折线同时竞争 | cycle1 门控右上 | OPEN |
| CM1-03 | Z2 箭头 | `edge_gate_indicator` | “有效且 u&lt;pMix”贴近菱形下角与橙色容器标题 | cycle1 门控右下 | OPEN |
| CM1-04 | Z1 文本 | `mode_gate` | 菱形条件三行可读，但左右出边标签使中心显得拥堵 | cycle1 中央 | OPEN |
| CM1-05 | Z2 箭头 | `edge_svr_port` | IndicatorModel 可用性线跨越整张图下沿，视觉权重过高 | cycle1 左下到中央 | OPEN |
| CM1-06 | Z1 文本 | `edge_svr_port` | “可用性”标签压在主区与反馈带之间的狭窄缝隙 | cycle1 x≈770,y≈738 | OPEN |
| CM1-07 | Z7 语义 | `explore_evidence` | 未显式写明 uncertainty 是预测模糊度、不是认知不确定性 | cycle1 Explore 第二节点 | OPEN |
| CM1-08 | Z3 盒体 | `explore_select` | 48 px 高度承载两条长规则，投影下偏挤 | cycle1 Explore 底部 | OPEN |
| CM1-09 | Z1 文本 | `explore_lambda` | 两条长公式行距紧，与上下箭头距离不足 | cycle1 Explore 第三节点 | OPEN |
| CM1-10 | Z1 文本 | `edge_indicator_fallback` | 长回退标签横压在 RBF-SVR 节点右侧和虚线之间 | cycle1 Indicator 中部 | OPEN |
| CM1-11 | Z2 箭头 | `edge_indicator_fallback` | 回退线绕到容器最右边，与分支输出线靠得过近 | cycle1 Indicator 右边界 | OPEN |
| CM1-12 | Z1 文本 | `edge_explore_merge` | “Explore 输出”挤在分支框与评价栏的 26 px 缝隙 | cycle1 右上 | OPEN |
| CM1-13 | Z1 文本 | `edge_indicator_merge` | “Indicator 输出”覆盖真实评价节点左侧文字区 | cycle1 右中 | OPEN |
| CM1-14 | Z3 盒体 | `true_eval` | 122 px 宽度使 `Problem.Evaluation` 与 Archive 说明过密 | cycle1 评价栏 | OPEN |
| CM1-15 | Z3 盒体 | `empty_next_fallback` | 126 px 宽度造成 OperatorGA 与 nMin 说明碎裂 | cycle1 评价栏底部 | OPEN |
| CM1-16 | Z2 箭头 | `edge_empty_next_clip` | 外绕灰虚线贴近右页边，形成“被裁切”观感 | cycle1 最右 | OPEN |
| CM1-17 | Z1 文本 | `edge_merge_clip` | `Next` 与上下两个紫色节点距离均过近 | cycle1 评价栏上部 | OPEN |
| CM1-18 | Z2 箭头 | `edge_empty_pairs_refselect` | 灰色安全旁路与反馈容器顶边几乎重合，难分辨 | cycle1 底部 | OPEN |
| CM1-19 | Z2 箭头 | `edge_ga_loop` | `g&lt;gmax` 标签、GA 回环和候选池入门控线在 x≈800 聚集 | cycle1 GA/门控交界 | OPEN |
| CM1-20 | Z1 文本 | `edge_pool_gate` | “同一候选池”重复候选池节点已表达的信息，并增加局部拥挤 | cycle1 中下 | OPEN |

### P2 — Polish

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| CM1-21 | Z1 文本 | `edge_net_ga` | `relation model` 可由源/目标节点推断 | cycle1 左中 | OPEN |
| CM1-22 | Z2 箭头 | `edge_perr_lambda` | 辅助参数 p_err 使用实线且横跨顶部，易被误认成主数据流 | cycle1 主区上沿 | OPEN |
| CM1-23 | Z1 文本 | `edge_perr_lambda` | 标签接近副标题和两个容器上边界 | cycle1 y≈114 | OPEN |
| CM1-24 | Z4 间距 | `sde_boundary` | 两行橙色边界注释离容器底边较近 | cycle1 左下 | ACCEPT：仍有 8 px 留白且可读 |
| CM1-25 | Z4 间距 | `indicator_inputs`,`sde_block` | 同一行宽度不同、中央间距只有 18 px | cycle1 左下 | ACCEPT：形成输入→计算的紧凑关系 |
| CM1-26 | Z7 构图 | 评价栏 | 无外框，仅标题与节点形成窄列，层级稍弱 | cycle1 最右 | ACCEPT：避免窄容器被误检为普通节点，紫色节点已成列 |
| CM1-27 | Z4 间距 | Explore/Indicator 两容器 | 中间 20 px 空白明显小于其他主区间距 | cycle1 右侧 | ACCEPT：上下分支使用独立虚线边界 |
| CM1-28 | Z6 字体 | `evidence_boundary` | 底部长句为 13 pt，信息密度高 | cycle1 底部第二框 | OPEN |
| CM1-29 | Z7 语义 | `evidence_boundary` | 尚未直接写出 `score_rel` 不是 Pareto 胜率 | cycle1 底部 | OPEN |
| CM1-30 | Z2 箭头 | `edge_clip_eval` | `≤ budget_left` 位于窄竖向边上，略显拥挤 | cycle1 评价栏 | DEFER |
| CM1-31 | Z8 图标 | 全图 | 未使用图标，依靠颜色、容器、公式和箭头编码 | cycle1 全图 | ACCEPT：视觉规范明确不使用装饰性图标 |
| CM1-32 | Z9 一致性 | 中英文变量 | `qKeep/nMin/nMax` 与代码一致，但中英文基线略不齐 | cycle1 两分支 | ACCEPT：保留源码可追溯性 |
| CM1-33 | Z5 色彩 | 左侧双代理 | 蓝/橙对比清楚，但颜色也重复用于 Explore/Indicator | cycle1 全图 | ACCEPT：相同颜色表达相近语义族，标题与形状继续区分 |
| CM1-34 | Z7 构图 | 下一代反馈 | 通过 Archive→RefSelect→Population 表示循环，没有再画长回环到页面左上 | cycle1 底部 | ACCEPT：避免形成外框式长连线 |

## 候选解模式 — Screenshot Review Cycle 2

截图：`候选解模式_cycle2.png`。  
预检：0 FAIL，7 WARN；其中 4 项是跨独立分区的全局间距统计，2 项为真实局部线密度，1 项为空反馈容器。

### Cycle 1 Fix Verification

| defect ids | fix | cycle2 evidence | status |
|---|---|---|---|
| CM1-01 | 将输入改为 `Catalog + decs / 硬关系标签` | “决策变量”不再断字 | FIXED |
| CM1-02,03,04 | 出边标签缩为 Explore / Indicator | 菱形周围文字竞争明显下降 | PARTIAL：多条线仍从菱形中心穿出 |
| CM1-05,06 | 删除“可用性”标签、上移长线 | 标签冲突消失 | PARTIAL：长橙线仍像 GA 外框 |
| CM1-07 | 节点内补“预测模糊度，非认知不确定性” | 语义边界已显式 | FIXED |
| CM1-08,09 | 重排 Explore 四节点高度与间距 | 公式和选择规则可读 | FIXED |
| CM1-10,11 | 回退说明移入输出框、虚线无长标签 | SVR 节点不再被文字压住 | FIXED |
| CM1-12,13 | 删除两条分支输出边标签 | 分支—评价缝隙恢复干净 | FIXED |
| CM1-14,15,17 | 评价节点加宽，缩短节点/边文字 | 评价列可完整阅读 | FIXED |
| CM1-18 | 删除与反馈顶边重合的长旁路线 | 反馈带上方不再有双重灰虚线 | FIXED |
| CM1-19,20,21 | 删除 GA 回环、候选池和关系模型的冗余边标签 | x≈800 拥堵降低 | PARTIAL：门控输入线仍多 |
| CM1-22,23 | p_err 改为细虚线并缩短标签 | 主次层级改善 | PARTIAL：顶部仍像额外容器框 |
| CM1-28,29 | 底部补 `score_rel ≠ Pareto 胜率` | 证据边界更完整 | PARTIAL：末字孤立换行 |

### P0 — Blockers

未发现 P0。

### P1 — Visible Defects

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| CM2-01 | Z2 箭头 | `edge_perr_lambda` | 蓝色虚线沿主区顶部和 GA 左边形成“外框”，仍可能被误读为主流程 | cycle2 上沿 | OPEN |
| CM2-02 | Z2 箭头 | `edge_svr_port` | 橙线沿 GA 左、下、右三边绕行，形成第二个“外框” | cycle2 中左/底部 | OPEN |
| CM2-03 | Z7 构图 | `indicator_port` | 单独的 IndicatorModel 可用性框与菱形条件重复 | cycle2 中央 | OPEN |
| CM2-04 | Z2 箭头 | `edge_stream_gate` | 随机流线从右侧进入菱形，与模式出边争抢同一区域 | cycle2 门控右侧 | OPEN |
| CM2-05 | Z2 箭头 | `edge_gate_explore`,`edge_gate_indicator` | 两条出边从菱形中心水平穿出，削弱决策形状 | cycle2 中央 | OPEN |
| CM2-06 | Z1 文本 | `edge_stream_gate` | `u` 标签与橙色 IndicatorModel 框邻近，来源辨识不够快 | cycle2 门控上部 | OPEN |
| CM2-07 | Z2 箭头 | `edge_empty_next_clip` | “主程序回退”标签悬在评价节点右侧，局部拥挤 | cycle2 最右 | OPEN |
| CM2-08 | Z1 文本 | `edge_eval_archive` | “真实评价解”标签与 Indicator 输出、保护线处于同一高度 | cycle2 右下 | OPEN |
| CM2-09 | Z1 文本 | `evidence_boundary` | 长句末尾“量”孤立换到第三行 | cycle2 底部第二框 | OPEN |
| CM2-10 | Z3 盒体 | `feedback_container` | 容器没有区标题，预检报 orphan-empty-box | cycle2 底部 | OPEN |

### P2 — Polish

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| CM2-11 | Z1 文本 | `edge_refselect_population` | “下一代”标签与两个已自解释节点重复 | cycle2 底部 | OPEN |
| CM2-12 | Z1 文本 | `explore_evidence` | 四行 13 pt 文本略密，但无截断 | cycle2 Explore | ACCEPT：四行均为必要证据边界 |
| CM2-13 | Z2 箭头 | `edge_indicator_fallback` | 右侧虚线与主竖向 SDE 预测边形成并行双线 | cycle2 Indicator | ACCEPT：实线/虚线明确区分正常与回退 |
| CM2-14 | Z2 箭头 | GA/门控边界 | 预检仍报 x≈800 线段热点 | cycle2 中央偏左 | OPEN |
| CM2-15 | Z2 箭头 | Indicator 中心 | 预检报 x≈1200 线段热点 | cycle2 Indicator | ACCEPT：顺序主链与右侧回退在截图中可分辨 |
| CM2-16 | Z7 语义 | `empty_pairs_safe` | 安全旁路改为节点内“→直接 RefSelect”，没有跨页连线 | cycle2 底部左 | ACCEPT：语义完整且避免假反馈线 |
| CM2-17 | Z7 构图 | 反馈带 | 只画 Archive→RefSelect→Population，不再回环至左上 | cycle2 底部 | ACCEPT：节点文字“进入下一轮代理构建”闭合循环 |
| CM2-18 | Z5 色彩 | p_err 虚线 | 蓝色辅助线仍与关系主干同色 | cycle2 上沿 | 随 CM2-01 删除 |

## 候选解模式 — Screenshot Review Cycle 3

截图：`候选解模式_cycle3.png`。  
预检：0 FAIL，5 WARN；4 项来自彼此独立列/行被全局统计，1 项为 Indicator 主链与回退线的局部密度。

### Cycle 2 Fix Verification

| defect ids | fix | cycle3 evidence | status |
|---|---|---|---|
| CM2-01 | 删除跨页 p_err 辅助线，保留左侧注释与 Explore 公式 | 顶部不再形成蓝色外框 | FIXED |
| CM2-02,03 | 删除长橙色可用性线与重复端口框 | GA 周围外框消失，门控条件仍完整 | FIXED |
| CM2-07,08,11 | 删除评价区冗余边标签 | 评价列文字竞争显著下降 | FIXED |
| CM2-09 | 缩短证据边界措辞 | 不再出现孤立末字 | FIXED |
| CM2-10 | 为底部容器增加“安全边界与档案反馈”标题 | orphan-empty-box 告警消失 | FIXED |
| CM2-14 | 移除三条跨区输入线 | x≈800 热点告警消失 | FIXED |

### P0 — Blockers

未发现 P0。

### P1 — Visible Defects

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| CM3-01 | Z2 箭头 | `edge_pool_gate` | 候选池输入线进入菱形中心后横穿图形 | cycle3 中央菱形 | FIXED：指定左下入口点 |
| CM3-02 | Z2 箭头 | `edge_stream_gate` | 随机流从右侧长折线进入，弱化“上方输入”关系 | cycle3 门控区 | FIXED：改为底部→菱形顶部的短竖线 |
| CM3-03 | Z2 箭头 | `edge_gate_explore`,`edge_gate_indicator` | 两条输出从中心重叠后分叉，箭头层级不清 | cycle3 菱形右侧 | FIXED：分别指定右上/右下出口点 |
| CM3-04 | Z7 语义 | 门控结果 | 删除长边标签后，“条件成立/否则”的映射未显式写出 | cycle3 门控区 | FIXED：新增 `成立→Indicator；否则→Explore` |
| CM3-05 | Z7 语义 | `svr_model` | 左侧模型尚未显示代码变量名 `IndicatorModel`，与门控条件连接较弱 | cycle3 左下/中央 | FIXED：模型框加入 `IndicatorModel` |

### P2 — Polish

| id | zone | element | description | evidence | status |
|---|---|---|---|---|---|
| CM3-06 | Z1 文本 | `edge_stream_gate` | `u` 标签与随机流节点正文重复 | cycle3 门控区 | FIXED：删除边标签 |
| CM3-07 | Z2 箭头 | Indicator 主链/回退 | 预检报告 x≈1200,y≈600 线段热点 | cycle3 Indicator | ACCEPT：主路径实线竖直、回退虚线外绕，截图可逐条追踪 |
| CM3-08 | Z4 间距 | Explore 与 Indicator 内部 | 预检将上下两个独立容器作为同列统计，间距差异较大 | cycle3 右侧 | ACCEPT：各容器内部节奏一致，中间 74 px 是分支隔离带 |
| CM3-09 | Z4 间距 | 跨主区同 y 节点 | 预检报告三处横向间距不一致 | cycle3 全图 | ACCEPT：节点属于不同功能列，按功能宽度分配而非同一网格行 |
| CM3-10 | Z1 文本 | `nongate_note` | 四个非门控条件占据较大灰框 | cycle3 门控下部 | ACCEPT：防止混入旧版本逻辑，是本图关键边界 |
| CM3-11 | Z7 构图 | 底部反馈 | “关系对为空”未画跨页箭头到 RefSelect | cycle3 底部 | ACCEPT：节点内明确 `→直接 RefSelect`，避免假主流程 |
| CM3-12 | Z6 字体 | `evidence_boundary` | 13 pt 长句在单页中仍偏密 | cycle3 底部 | ACCEPT：两行完整可读，且不增加主图节点密度 |

最终复核图将在以上五项 P1 修复后重新生成。

最终复核：`候选解模式_final.png` 中 CM3-01—CM3-06 均已消失；四个门控连接口彼此独立，成立/否则映射可直接阅读，无新 P0/P1。

## 候选解模式 — Red-Team Audit

红队从“读者是否会把当前 UniformMix-Original 误解成旧版自适应门控或独立指标路径”出发反查。

| id | challenge | evidence checked | resolution |
|---|---|---|---|
| CRT-01 | 两种模式是否错误地各自产生候选池 | 共享 GA 与 `all_candidates` 位于门控之前 | PASS |
| CRT-02 | 候选池是否脱离关系网络 | `model_select` 明确位于 GA 循环并标注关系网络贯穿生成 | PASS |
| CRT-03 | Indicator 是否被画成完全独立于关系网络 | Indicator 第一节点明确“关系得分粗筛” | PASS |
| CRT-04 | 门控是否错误加入 p_err/confidence 等诊断量 | 菱形只含模型有效性与 `u&lt;pMix`，灰框列出不参与项 | PASS |
| CRT-05 | 随机数是否被误画成 MATLAB 全局 RNG | 上方节点明确“独立 RandStream、每代预先抽取” | PASS |
| CRT-06 | p_err 是否被误称门控可信度 | 左侧注释和底部证据框均明确其为关系对留出误差 | PASS |
| CRT-07 | Explore 是否遗漏四类双向比较 | 四类 `[C1,Xi]` 等全部列出 | PASS |
| CRT-08 | uncertainty 是否被误称认知不确定性 | 节点明确“预测模糊度，非认知不确定性” | PASS |
| CRT-09 | Explore 的时间系数方向是否画反 | `λ_t=λ0(1−ratio)max(...)` 完整呈现 | PASS |
| CRT-10 | 多样性项是否被夸大为主要目标 | 贪心式明确 0.75 质量 + 0.25 决策距离 | PASS |
| CRT-11 | Indicator 是否遗漏前 30%/至少 20 个粗筛 | 第一节点完整标示 | PASS |
| CRT-12 | SVR 异常是否错误终止选择 | 输出节点与灰虚线明确回退关系分数 | PASS |
| CRT-13 | 指标是否误画为三指标轮盘 | 左下边界明确 SDE-only 与局部 Minkowski 回退 | PASS |
| CRT-14 | 空 Next 与空关系对是否被混为同一保护 | 最右与底部左分别展示两种条件 | PASS |
| CRT-15 | 真评估和 Archive/Population 更新是否闭合 | FE 裁剪→真实评价→Archive→RefSelect→下一代完整 | PASS |

红队结论：0 P0、0 P1；15 项高风险误读均被图内文字或结构直接排除。

## 候选解模式 — Self-Score

| dimension | score / 10 | rationale |
|---|---:|---|
| 源码语义忠实度 | 10 | 共享 GA、精确门控、两分支、两类保护与反馈均可追溯 |
| 信息层级 | 9 | 双代理→共享池→门控→双分支→评价的阅读顺序稳定 |
| PPT 可读性 | 9 | 1600×900 下完整可读；高密度公式限制在 Explore 局部 |
| 视觉一致性 | 9 | 颜色语义、虚实线、圆角与字体同图一一致 |
| 证据边界与可讲述性 | 10 | 显式排除旧门控、三指标轮盘及概率/性能误读 |
| **总分** | **47 / 50** | 每项均 ≥ 6，满足交付门槛 |

## Remaining Gaps

- `混合PBI` 视觉预检保留 1 个线段密度 WARN：源于左侧真实输入 fan-out；最终截图无穿框、错向或难以辨认的交叉。
- `候选解模式` 视觉预检保留 5 个 WARN：4 个是不同功能区被全局行/列统计合并，1 个是 Indicator 实线主链与外绕虚线回退的必要局部密度；最终截图已逐项人工核验。
- 两个 `.drawio` 均通过严格结构校验（0 error，0 warning）；PPT 两页渲染及画布溢出检查通过。

## 2026-08-12 用户反馈修订

### P1 — 用户可见问题

| id | 图 | 问题 | 修订 | 复核结果 |
|---|---|---|---|---|
| UR-01 | 混合 PBI | “双表征粗质量分组”含义抽象、讲述成本高 | 标题改为“混合 PBI：两路评分融合与关系分组”；副标题直接写明连续评分、二值标签、前 25% 正组 | PASS：标题与主链可顺序直读 |
| UR-02 | 混合 PBI | 底部三个说明框增加密度 | 删除 `note_shared_source`、`note_coordinate`、`note_confidence`，将释放高度分配给四个主区 | PASS：三个节点在 XML 中不存在，主流程纵向间距增加 |
| UR-03 | 候选解模式 | “当前不参与门控”灰框不应出现在当前机制图 | 删除 `nongate_note`，并删除底部证据框中重复的非门控说明 | PASS：图中仅保留 `IndicatorModel` 有效且 `u&lt;pMix` 的实际选择条件 |
| UR-04 | 候选解模式 | 门控标题换行、Explore 与 Indicator 贴近 | 栏目名缩短为“UniformMix 选择”，两分支容器之间增加隔离带 | PASS：最终 PPT 渲染无意外换行或容器贴边 |
| UR-05 | 候选解模式 | 下移反馈区后，大容器造成预检重叠误报 | 将“安全边界与档案反馈”改为独立文本标题，保留五个反馈节点的开放式横排 | PASS：视觉预检 0 FAIL |

### 最终验收

- 两份 `.drawio` 严格结构检查均为 0 error、0 warning。
- 两张最终 PNG 均为 1600×900，并逐张全尺寸复核。
- 两页 PPT 重新渲染后，无裁切、无越界；`slides_test.py` 返回 `Test passed. No overflow detected.`
- 图一删除内容、图二门控内容均通过 XML 关键词反查。
