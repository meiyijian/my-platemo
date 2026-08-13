# UniformMix-Original 科研架构图视觉规格

日期：2026-08-12  
用途：组会 PPT（16:9 横向）  
源码基线：`REMO_new2_AdaMaO_SDEOnly_UniformMix_Original`，当前独立目录版本（commit `838ae19`）

## 1. 交付范围

分别制作两张可独立放入 PPT 的科研架构图：

1. `混合PBI_科研架构图.drawio`：解释两路 PBI 信号如何生成、融合、排序并硬化为 `Catalog`。
2. `候选解模式_科研架构图.drawio`：解释共享候选池、UniformMix 随机门控、Explore/Indicator 两条选择分支、回退和档案反馈。

每张图同时交付高清 PNG 预览；若本机导出链支持，则额外交付 SVG。两张图采用统一视觉语法，但不合并为一张总图。

## 2. 共同视觉规范

- 画布：16:9，逻辑尺寸 1600 × 900；四周安全边距至少 56 px。
- 背景：近白色 `#FAFBFD`，不使用渐变、阴影堆叠或装饰性图片。
- 标题：微软雅黑/Arial，28–32 pt，深蓝黑 `#16324F`。
- 主节点：16–18 pt；公式与参数：14–16 pt；脚注：12–13 pt。
- 颜色语义：
  - 蓝色 `#2F6BFF`：方向场连续 PBI 或共享关系链。
  - 橙色 `#E8873A`：代表解锚点二值 PBI 或 Indicator 分支。
  - 青绿色 `#2A8F7A`：Explore 分支与多样性选择。
  - 紫色 `#7756C5`：融合、随机门控与分支汇合。
  - 灰色 `#687387`：回退、异常保护和非主路径说明。
- 实线箭头：正常数据/控制流；虚线箭头：回退或可选路径；回环箭头：真实评价后的 Archive/Population 更新。
- 所有颜色同时由形状、标题和线型区分，保证灰度投影下仍可读。
- 标签以中文为主，保留代码变量、函数名和公式；避免大段源码与泛化的软件工程术语。

## 3. 图一：混合 PBI 科研架构图

### 3.1 叙事目标

从同一当前种群出发，展示“方向场连续 PBI”与“代表解锚点二值 PBI”两路信号，经随进化进度变化的线性融合后，形成粗质量排序并硬化为正组/非正组。图末必须明确：连续信息没有直接作为关系网络的连续监督。

### 3.2 布局

- 左侧：当前种群 `Population`、目标矩阵 `PopObj`、进度 `ratio=FE/maxFE`。
- 中左上（蓝色通道）：方向场连续 PBI。
- 中左下（橙色通道）：代表解锚点二值 PBI。
- 中右（紫色汇合）：时间权重融合、排序、硬化。
- 最右（绿色小型下游区）：`Catalog → GetRelationPairs → 原始无权重关系网络`。
- 底部横向注释带：两路信号均由当前 `Population` 派生，不应画成彼此独立的外部先验。

### 3.3 蓝色通道：方向场连续 PBI

1. 参考方向生成：
   - `M ≤ 3` 或 `N < 50`：`UniformPoint(Nref,M,'ILD')`。
   - 否则：第一非支配前沿 → 归一化 → K-means 中心 → `AdaptiveReferenceVectors`。
   - NDSort、样本不足、零目标跨度或 K-means 失败时回退均匀方向。
2. 方向关联：使用原始 `PopObj` 与单位方向 `V` 的余弦相似度确定 `ref_idx`。
3. 相对理想点 `Zmin` 计算：
   - `d1`：沿关联方向的投影长度。
   - `d2`：到投影点的垂直距离。
4. 连续得分：`PBI_v=d1+θd2`，`θ=5`；`score_v=1/(1+PBI_v)`。

### 3.4 橙色通道：代表解锚点二值 PBI

1. `RefSelect(Population,k_eff)` 选择真实评价代表解，默认有效数量为 `k_eff=min(Problem.N,max(6,ceil(1.5M)))`。
2. 以原始 `PopObj` 与 `RefObj` 的余弦相似度分配锚点子区域。
3. 在每个子区域内计算 `g=d1+δd2`，再除以 `||Ref-Zmin||`。
4. 二分搜索 `δ∈[-20,20]`，使 `true` 标签比例尽量落入 `[0.3,0.7]`。
5. `g/||Ref-Zmin||≤1 → label_dyn=1`，否则为 0。

### 3.5 融合与硬化

1. `α=1-ratio`。
2. `score_hybrid=α·score_v+(1-α)·label_dyn`。
3. 早期偏重连续方向场，后期偏重二值锚点标签。
4. 按 `score_hybrid` 降序排序，前 `ceil(N·rGood)`（默认 `rGood=0.25`）置为 `Catalog=true`；其余全部为非正组。
5. 下游 `GetRelationPairs` 仅生成硬标签：同组为 0，正组→非正组为 +1，反向为 −1。
6. 原始训练路径为 3/4 分层训练、1/4 留出测试、普通 `patternnet`、无样本权重。

### 3.6 必须显式标注的边界

- `confidence=1-|score_v-label_dyn|` 只是双表征一致性，且当前主程序不使用该输出；不画成概率校准模块。
- 混合 PBI 改变排序与分组，但经过 top-`rGood` 硬化后，并未形成连续关系监督。
- 余弦分区使用未减 `Zmin` 的原始目标，而 PBI 投影使用 `PopObj-Zmin`；图中用小型“坐标注意”标记，不掩盖这一实现细节。
- 不画性能提升、IGD/HV 曲线或因果收益结论。

## 4. 图二：候选解模式科研架构图

### 4.1 叙事目标

展示候选解生成与关系代理是两种模式的共享基础；UniformMix 只在最终候选选择时，用独立随机流在 Explore 与 Indicator 之间仲裁。Indicator 不可用时确定性回退 Explore；两条分支最终都受评价预算和主程序回退保护。

### 4.2 布局

- 左侧上方：当前种群及原始无权重关系网络训练。
- 左侧下方：SDE 指标值与 RBF-SVR 指标代理构建。
- 中部上方：共享代理辅助 GA 候选池生成。
- 中央：`UniformMix` 门控菱形。
- 右上：Explore 分支（青绿色）。
- 右下：Indicator 分支（橙色）。
- 最右：候选汇合、预算裁剪、真实评价。
- 底部：Archive → `RefSelect` → 下一代 Population 的反馈回路；灰色虚线表示安全回退。

### 4.3 共享模型与候选池

1. `Catalog` 与决策变量生成四类关系对，标签为 `{0,+1,-1}`。
2. `DataProcess` 按类别进行 75%/25% 的关系对级划分；`mapminmax` 后训练三分类 `patternnet([ceil(3D),2D,D])`。
3. `p_err` 是关系对留出误差，只进入 Explore 的模糊度奖励系数，不作为 UniformMix 门控条件。
4. 指标代理：`Shape_Estimate` 估计 `Lp`；`calFitness_SDE` 计算 SDE，极小 SDE 值局部回退 Minkowski(`Lp`)；随后 `fitrsvm(dec,Fitness,'rbf')`。
5. 共享代理辅助 GA：从 `[Population.decs;Ref.decs]` 生成候选；每轮以关系网络 `model_select` 排序、保留 `|Ref|` 个，再生成新候选，累计至 `gmax`；汇总并稳定去重。

### 4.4 UniformMix 门控

- 使用与 MATLAB 全局 RNG 独立的 `RandStream`，每代预先抽取 `u∈[0,1)`。
- 若 `IndicatorModel` 有效且 `u<pMix`，进入 `indicator`；否则进入 `explore`。
- 默认 `pMix=0.50`。
- 图中明确写出：当前版本没有 `p_err`、coverage、degeneracy 或 confidence 门控。

### 4.5 Explore 分支

1. 关系网络针对每个候选构造 `[C1,Xi]`、`[Xi,C1]`、`[C2,Xi]`、`[Xi,C2]` 四类比较。
2. 用最大 softmax 类概率作为组内平均权重，得到关系净证据 `score_rel`。
3. `uncertainty=1-mean(max softmax probability)`；它是预测模糊度，不是认知不确定性。
4. `λ_t=lambda0(1-ratio)max(0,1-p_err/0.45)`；`score_aug=norm(score_rel)+λ_t·norm(uncertainty)`。
5. 保留不低于 `qKeep=0.80` 分位点的候选；不足 `nMin` 时补足。
6. 贪心批选择：`0.75·质量+0.25·决策空间距离`，输出 `nMin…nMax`（默认 4…6）个。

### 4.6 Indicator 分支

1. 用关系得分粗筛前 30%，至少保留 20 个。
2. RBF-SVR 对粗筛集合预测 SDE 指标值并重排序。
3. 若模型缺失、预测异常或调用失败，虚线回退关系得分。
4. 保留不低于指标得分 70% 分位点的候选，并按得分选出 `nMin…nMax` 个。

### 4.7 汇合、评价与回退

- 两分支汇合后按剩余 FE 裁剪，再执行真实 `Problem.Evaluation`，加入 `Archive`。
- 若 `AdaMaOSelection` 返回空且仍有预算，主程序直接用 `OperatorGA` 生成并选取至多 `nMin` 个候选。
- 若关系对为空，本代不训练代理、不选择新候选，直接用 `RefSelect(Archive,Problem.N)` 更新 Population 并进入下一代。
- 每轮末使用 `RefSelect(Archive,Problem.N)` 形成下一代 Population。

### 4.8 必须显式标注的边界

- 指标值是 SDE（带局部 Minkowski 回退），不是旧版 SDE/epsilon-plus/Minkowski 三指标轮盘。
- Indicator 模式仍先依赖关系得分粗筛，不能画成完全独立于关系网络的路径。
- `p_err` 不代表候选重排质量或真实改进；不画成“可信度门控”。
- Explore 的 softmax 模糊度与决策空间距离均是启发式项，不画成已证实的性能贡献。

## 5. 源码追踪表

| 图中机制 | 当前源码位置 |
|---|---|
| 主循环、进度、两种代理、门控、评价与 Archive 更新 | `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m:30–100` |
| 原始无权重关系网络 | `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m:148–168` |
| UniformMix 随机仲裁 | `ResolveUniformMixMode.m:1–22` |
| 双路 PBI、融合、排序与 Catalog | `private/HybridPBI_Classification.m:46–122` |
| 高维自适应方向与均匀方向回退 | `private/HybridPBI_Classification.m:147–224` |
| 锚点二值 PBI 与自适应 δ | `private/GetOutput_PBI.m:41–135` |
| 代表解和环境选择 | `private/RefSelect.m:31–141` |
| 硬关系对生成 | `private/GetRelationPairs.m:30–78` |
| 75%/25% 关系对级划分 | `private/DataProcess.m:26–66` |
| 共享 GA、Explore/Indicator、关系打分与多样性选择 | `private/AdaMaOSelection.m:52–470` |
| SDE 指标与 Lp 局部回退 | `private/IndicatorSelectorSDEOnly.m:9–21`; `private/calFitness_SDE.m:29–55`; `private/Shape_Estimate.m:26–61` |
| 独立候选模式随机流 | `private/CreateSDECandidateModeStream.m:1–15` |

## 6. 验收标准

- 两张图都能在 16:9 PPT 单页上独立阅读，100% 缩放下无截断或重叠。
- 每个箭头都能对应明确的数据或控制语义；回退路径全部使用灰色虚线。
- 图一能清楚回答“两路 PBI 分别是什么、怎样融合、在哪里丢失连续信息”。
- 图二能清楚回答“候选池如何生成、何时走哪一支、每支如何选、失效时如何回退”。
- 不混入旧版自适应门控、三指标轮盘、confidence 加权关系训练或未经代码支持的性能结论。
- `.drawio` XML 通过结构检查与视觉预检；每张图完成至少三轮画布截图审阅，并记录缺陷修复。

## 7. 2026-08-12 用户反馈后的简化规则

- 图一不再使用“双表征粗质量分组”这一抽象表述，统一改为“两路评分融合与关系分组”。
- 图一删除底部“同源性 / 坐标注意 / 证据边界”三个说明框，正文只保留可顺序讲述的主机制链。
- 图一把 `Top-rGood 硬化` 直写为“前 25% 为正组，其余为非正组”，但仍保留 `Catalog`、0/1 组别及后续硬关系标签，避免改变源码语义。
- 图二删除“当前不参与门控”的灰色框，并从底部证据说明中删去同类重复陈述；门控区只显示当前实际条件：`IndicatorModel` 有效且 `u &lt; pMix`。
- 两图利用删减后释放的空间增加节点间距、容器内边距和分支隔离带，不新增源码未支持的机制。
