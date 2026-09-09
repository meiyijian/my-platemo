# 混合 PBI 纠正漏判：图意与核验说明

本图展示一个明确构造的情形：在给定参考解的分类任务中，原先位于已知 Pareto 前沿、却被标为负类的 A，经加入方向 PBI 信息后进入正组；原先标为正类的 B 位于前沿外侧，混合分组不再选入 B。

## 查看与使用

- `paqc_correction_cn.pdf` / `.svg` / `.png`：中文讨论版。
- `paqc_correction_en.pdf` / `.svg` / `.png`：英文论文版。
- 两版均为 180 mm × 95 mm；PDF 和 SVG 为矢量图，PNG 为 600 dpi。
- `figure_paqc_correction.tex`：英文论文插图代码及完整图注；建议插入 PAQC 动机段之后。
- `figure_paqc_correction_cn.tex`：中文图注及插图代码，需要中文 LaTeX 环境。
- `numerical_records.json`：MATLAB 输出的全精度参数、方向、标签、排名和核验信息；`numerical_records.csv` 为便于查看的表格。
- `source_provenance.json` 和 `source_snapshot/`：源文件哈希、分类函数副本和连续评分局部函数的原样提取。
- `qa/`：PDF 渲染、灰度检查图、自动检查报告及视觉检查记录。

SVG 保留可编辑文字；中文依赖 Microsoft YaHei，英文依赖 Arial。PDF 嵌入字体，适合直接插入论文。当前交付采用通用论文尺寸，不声称已符合某一期刊的全部投稿要求。

## 已知前沿为什么可作为独立判断依据

定义可行目标区域为第一象限中满足 `f1^2 + f2^2 >= 1` 的点，两个目标均最小化。单位圆弧上的点互不支配；任一圆弧外点沿径向缩至单位圆弧后，各目标均不增且至少一个目标严格减小。因此，单位圆弧正是该构造问题的 Pareto 前沿。

A 位于圆弧上；B 到圆弧的最短欧氏距离为 2.5。该前沿及距离没有输入参考解分类或连续评分。这里“纠错”的含义限定为：本例中分组更符合上述预先定义的前沿成员身份。正组选择本身仍是固定配额排序，不是完整的 Pareto 成员识别器。

## 固定的构造与实际结果

八个解依次为 A=(3/sqrt(10),1/sqrt(10))，R=(1,0)，B=(0,3.5)，C=(0,4)，D=(0,4.5)，E=(0,5)，F=(0,6)，G=(2,0)。理想点为 (0,0)。给定唯一参考解 R；固定 delta=0.234375、theta=5、t=0.20。UniformPoint(8,2,'ILD') 实际产生 9 个方向，按生产代码单位化，保留其数值下限。

| 解 | 参考解归一化 PBI | 原始标签 L | 连续得分 S | 融合得分 H | 混合排名 | 混合正组 |
|---|---:|---:|---:|---:|---:|---|
| A | 1.022799 | 0 | 0.500000 | 0.400000 | 1 | 是 |
| R | 1.000330 | 0 | 0.499999 | 0.399999 | 2 | 是 |
| B | 0.820309 | 1 | 0.222221 | 0.377777 | 3 | 否 |
| C | 0.937496 | 1 | 0.199999 | 0.359999 | 4 | 否 |
| D | 1.054683 | 0 | 0.181817 | 0.145454 | 6 | 否 |
| E | 1.171870 | 0 | 0.166666 | 0.133333 | 7 | 否 |
| F | 1.406244 | 0 | 0.142857 | 0.114285 | 8 | 否 |
| G | 2.000661 | 0 | 0.333332 | 0.266666 | 5 | 否 |

原始正类为 {B,C}，混合正组为 {A,R}。原始正类数在这个构造中恰好为 2，未对原始二值标签强行裁取 Top-25%。混合分组按八个解取前两个。第二名与第三名相差 0.02222191358，入选成员不依赖并列排序；A 与 R 虽在三位小数显示时同为 0.400，也不会影响二者一起入选。

对 A 与 B，有 H_A > H_B 当且仅当 t < (S_A-S_B)/(1+S_A-S_B)，本例约为 0.217392。因此 t=0.20 下确实发生修正，但不能把“早期”写成整个 t<0.5 都会纠正这两个解。t>=0.5 时，二值正类优先；核验已检查 t=0.5、0.75、1 时 A 不入选。

## 与当前实现的对应和边界

1. MATLAB 直接执行当前 `RepresentativeBasedClassification` 的完整副本、`UniformPoint` 的完整副本，以及 `PBIQualityClassification` 内连续评分局部函数的原样提取。融合公式和 Top-25% 规则按当前生产函数计算，另行重构中间值并交叉核对。
2. **本图固定给定参考解 R，没有运行 RefSelect。** 这是为了隔离分类与融合步骤的教学简化，不能称为完整 REMO 或完整 PACDIS 在该构造问题上的优化运行结果，也不证明生产参考解选择必然产生该状态。
3. **保留当前代码的边界数值处理。** 参考解分类在余弦上减去 1e-6，因此边界点 R 的归一化值为约 1.000330，被当前实现标为 0；图中左侧 R 使用空心菱形，与实现一致。不能把 R 的该标签变化作为新增方向信息的科学优势。
4. A、B 是本图的解释对象。额外去掉上述余弦调整后，R 恢复为原始正类，A 仍为负类、B 仍为正类，混合正组仍为 {A,R}。因此**A 的漏判修正及 B 的移除不依赖 R 的数值边界现象**。这个控制只用于核验，不修改生产代码。
5. 图中虚线边界按包含余弦调整的真实阈值方程逐点计算，未直接手画直线。右图保留它用于定位原分类边界；它不代表混合方法另有一条几何分界线。混合方法根据全体八个解的 H 排名选组。
6. 两幅主图共享点位、坐标范围与等比例尺度；两幅放大窗共享相同局部范围。放大窗只为看清 A 与边界的细小间隔。未移动、抖动、投影或隐藏任何构造点。

## 中文图注

**方向信息对参考解 PBI 分组的修正示例。** 两幅图采用同一组八个构造目标向量，考虑 f1,f2≥0、f1²+f2²≥1 上的二维最小化问题。单位圆弧为已知 Pareto 前沿，仅用于评价图中判定，不参与两种方法的评分。(a) 给定参考解 R=(1,0) 和 delta=0.234375，参考解分类得到 L_A=0、L_B=1，其中 A=(3/√10,1/√10) 位于前沿，B=(0,3.5) 位于前沿外侧。虚线为计算得到的参考解分类边界。(b) 取 theta=5、预算进度 t=0.20，按 H=0.8S+0.2L 融合，八个解中排名前两位的 A、R 进入正组，B 未入选。点线表示 A、B 关联的参考方向；相同范围的放大窗显示 A 附近的判定变化。实心与空心分别表示进入和未进入对应正组，菱形表示参考解。下表给出关键解的实际计算得分。标签遵循当前数值实现，包括其对分类边界点的处理。本图是给定参考解与参数的分类机制示例，不是实验结果，也不验证参考解选择过程；所示修正发生在预算早期，不能推广为整个预算阶段均能跨标签纠错。

## English caption

**Illustration of directional information correcting representative-based grouping.** The same eight constructed objective vectors are shown in both panels for minimization over f1,f2≥0 and f1²+f2²≥1. The unit quarter-circle is the known Pareto front and is used only to assess the illustrated decisions; it is not supplied to either scoring rule. (a) Given the reference R=(1,0) and delta=0.234375, the representative-based classifier assigns L_A=0 and L_B=1, although A=(3/√10,1/√10) lies on the front and B=(0,3.5) lies outside it. The dashed curve is the computed reference classification boundary. (b) With theta=5 and budget progress t=0.20, directional scores enter H=0.8S+0.2L. The top two of eight scores select A and R, excluding B. Dotted lines show the directions associated with A and B; matched insets enlarge the neighborhood of A. Filled and open markers denote membership and non-membership in the respective positive groups; the diamond denotes the reference. The bottom table reports the focal scores. All labels follow the current numerical implementation, including its treatment of points on the classification boundary. This is a classification example with a prescribed reference and parameters, not an experimental result or a validation of reference selection. It illustrates an early-stage correction; cross-label reversal is not guaranteed throughout the budget.

## 重建

在仓库内的本目录准备来源快照，再执行 MATLAB 核验，最后运行绘图。需要 MATLAB、Statistics and Machine Learning Toolbox，以及本目录 `requirements.txt` 中的绘图库。

```powershell
uv run --with-requirements requirements.txt python build_correction_figure.py --prepare-only
matlab -batch "addpath(pwd); verify_paqc_example"
uv run --with-requirements requirements.txt python build_correction_figure.py
```

来源文件的哈希如有变化，绘图会中止，要求重新准备来源和完成 MATLAB 核验。源码保持不变时，也应在修改构造数据后重新执行核验。绘图只读取 MATLAB 数值结果，不手填 A、B 的判定。

## 简短替代文字

两幅具有相同目标坐标的散点图比较参考解 PBI 与混合 PBI 的正组。单位圆弧上的蓝色 A 在左图为空心、右图为实心；圆弧外橙色 B 在左图为实心、右图为空心。对应放大窗显示 A 位于已知前沿，却处于参考解分类边界的负侧；右侧加入方向评分后 A 入选。底部数值表显示 A、B 的融合得分分别约为 0.400 和 0.378。
