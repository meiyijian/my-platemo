# 八子图收敛分析更新记录（2026-10-21）

## 范围与交付

将 WFG7 与 WFG2 的10/15/20目标结果、十目标 DTLZ1 与 WFG3 组成四列两行的图3，共用图例并按(a)至(h)编号。对应英文第4.2节、中文对照稿与图注同步更新。PIEA 沿用用户指定数据，没有修改算法、预算或主表。

图件保留预览中实际观测区间内的数值，只移除十目标预览在首个观测之前的向前外推。56条曲线的冻结均值、来源哈希及绘图脚本位于 figures/convergence_eight 与 build_convergence_eight.py；默认执行脚本从冻结均值复现图件，--refresh才读取本机原始数据。

## 排版与验证

- 八张矢量PDF嵌入跨双栏浮动图，图3位于第10页上半部。
- 结论页增加一行空间，消除孤立末行；参考文献在第13页连续排布。
- 最终两遍 pdflatex 编译成功，共13页。未定义引用、重复标签、Overfull均为0；原有Underfull及作者/单位占位保留。
- 56条曲线全部Runs=20，无重复配置/算法/FE键；起始FE与终点全部匹配manifest。
- WFG7三种目标数FE150低于REMO/SSDE/CSEA，FE329至500最低均值；WFG2三种目标数FE340至500最低均值。WFG2的HES-EA终点均为次低。
- DTLZ1终点137.23/155.90；WFG3终点1.4387/1.2630/1.0013。所述数值与区间比较均据means.csv核验。
- 英文机械门禁15组实际检查均为0：破折号0、对偶修辞0、被动语态0、夸饰词0，其余见mechanical_gate.json。
- 独立审查最终CLOSED：0 CRITICAL / 0 MAJOR。已删除全局唯一性断言、改正两处标题，并确认英中同步及aux刷新。
- 已查看最终第10、12页及实验部分联系表，无重叠、裁切或孤立末行。

## 中文修改前（完整替换范围，基于b628ecd）

**四个有利案例的收敛表现。** 图 3–6 考察十目标 DTLZ1、DTLZ4、WFG2 和 WFG7。PACDIS 在这四个选定问题上取得最低终点平均 IGD$^+$；下文的 WFG3 则展示一个落后案例。曲线在单位 FE 网格上对原始运行 1–20 求平均，表格报告最终工作簿均值。在相邻检查点之间，各次运行沿用最近一次保存的指标值。各基线的 FE 起点不同：PC-SAEA 和 HES-EA 在 $D=30$ 时从 $FE=329$ 开始，在 $D=31$ 时从 $FE=340$ 开始；PIEA 从 $FE=100$ 开始，每轮评价一个新解。

在 DTLZ1 上，PACDIS 在整个记录区间持续改进，REMO 提供最接近的终点对照。在 DTLZ4 上，PIEA 在搜索前期取得更低均值，但 PACDIS 持续改进，并在后期超过 PIEA。在 $FE=500$ 时，PACDIS、REMO 和 PIEA 的均值分别为 0.61326、0.63471 和 0.81982。主表的秩和检验未检测到 PACDIS 与 REMO 之间的差异。在 WFG2 和 WFG7 上，到 $FE=150$ 时，PACDIS 已与 REMO、SSDE 和 CSEA 拉开差距。在这两个 WFG 案例中，全部七种算法开始搜索后，PACDIS 仍保持更低均值。HES-EA 在两个 WFG 问题上均在后期取得改进，但 PACDIS 保持最低终点均值。

![图 3：DTLZ1 十目标平均 IGD+ 收敛曲线](D:/PlatEMO-master/论文写作/figures/fig_convergence_fe500_dtlz1_m10.png)

**图 3　DTLZ1 上的平均 IGD$^+$ 收敛曲线（$M=10$，20 次运行）。**

![图 4：DTLZ4 十目标平均 IGD+ 收敛曲线](D:/PlatEMO-master/论文写作/figures/fig_convergence_fe500_dtlz4_m10.png)

**图 4　DTLZ4 上的平均 IGD$^+$ 收敛曲线（$M=10$，20 次运行）。**

![图 5：WFG2 十目标平均 IGD+ 收敛曲线](D:/PlatEMO-master/论文写作/figures/fig_convergence_fe500_wfg2_m10.png)

**图 5　WFG2 上的平均 IGD$^+$ 收敛曲线（$M=10$，20 次运行）。**

![图 6：WFG7 十目标平均 IGD+ 收敛曲线](D:/PlatEMO-master/论文写作/figures/fig_convergence_fe500_wfg7_m10.png)

**图 6　WFG7 上的平均 IGD$^+$ 收敛曲线（$M=10$，20 次运行）。**

**WFG3 上的表现。** 图 7 展示相同绘图口径下的十目标 WFG3（$D=31$）。PACDIS 的平均 IGD$^+$ 持续下降，但 REMO 在 $FE=340$–500 全程保持更低均值。PIEA 从 $FE=100$ 开始，终点低于 PACDIS。在 $FE=500$ 时，PACDIS、REMO 和 PIEA 的均值分别为 1.4387、1.2630 和 0.94564。PIEA 在与 PACDIS 相同的初始化数量和配置评价预算下取得更低终点值。

质量筛选可能降低区域覆盖程度，但 WFG3 的轨迹未分离出这一效应；该机制留待后续工作。

![图 7：WFG3 十目标平均 IGD+ 收敛曲线](D:/PlatEMO-master/论文写作/figures/fig_convergence_fe500_wfg3_m10.png)

**图 7　WFG3 上的平均 IGD$^+$ 收敛曲线（$M=10$，$D=31$，20 次运行）。**

## 中文修改后（完整替换范围）

**PACDIS 在 WFG7 与 WFG2 上领先。** 图 3 比较七个算法在八个配置上的平均 IGD$^+$ 轨迹。（a）–（f）为 WFG7 与 WFG2 在 $M=10$、15、20 下的结果，（g）为 DTLZ1（$M=10$），（h）为 WFG3（$M=10$）。这些选定案例同时展示 PACDIS 在 WFG7、WFG2 和 DTLZ1 上较低的终点均值，以及在 WFG3 上较弱的表现。曲线在单位 FE 网格上对每个算法的 20 次运行求平均，表格报告最终工作簿均值。在相邻检查点之间，各次运行沿用最近一次保存的指标值，并排除 $FE=500$ 之后的快照。每条曲线从全部 20 次运行均有观测值时开始。PC-SAEA 和 HES-EA 在 $D=30$ 时从 $FE=329$ 开始，在 $D=31$ 时从 $FE=340$ 开始；PIEA 从 $FE=100$ 开始，每轮评价一个新解。

在图 3（a）–（f）中，PACDIS 在三个目标数下的 WFG7 和 WFG2 上均取得最低终点均值。在 WFG7 上，到 $FE=150$ 时，其均值已低于 REMO、SSDE 和 CSEA；在全部七个算法均有观测值之后，仍保持最低均值。在 WFG2 上，PACDIS 同样在前期取得改进，并在各目标数下的 $FE=340$–500 区间保持最低均值。HES-EA 在两个 WFG 问题上均在后期取得改进，尤其是在 WFG2 上，它在三个目标数下都提供最接近的终点对照。PACDIS 在子图（g）的十目标 DTLZ1 上也持续改进，终点为 137.23，REMO 为 155.90。这些轨迹表明，在选定的 WFG 案例中，目标数从 10 增至 20 时，PACDIS 仍保持优势。

![图 3：七个算法在八个配置上的平均 IGD+ 收敛曲线](D:/PlatEMO-master/论文写作/figures/convergence_eight/convergence_eight.png)

**图 3　七个算法的平均 IGD$^+$ 收敛曲线。**（a）–（c）WFG7 与（d）–（f）WFG2 分别对应 $M=10$、15、20；（g）DTLZ1（$M=10$）；（h）WFG3（$M=10$）。每条曲线在单位 FE 网格上对 20 次运行求平均，各 FE 处采用不晚于该 FE 的最近一次保存值。数值越小表示性能越好。

**PACDIS 落后于 REMO 和 PIEA。** 图 3（h）展示相同绘图口径下的十目标 WFG3（$D=31$）。PACDIS 的平均 IGD$^+$ 持续下降，但 REMO 在 $FE=340$–500 全程保持更低均值。在 $FE=500$ 时，PACDIS、REMO 和 PIEA 的均值分别为 1.4387、1.2630 和 1.0013。PIEA 在与 PACDIS 相同的初始化数量和配置评价预算下取得更低终点值。

质量筛选可能降低区域覆盖程度，但 WFG3 的轨迹未分离出这一效应；该机制留待后续工作。
