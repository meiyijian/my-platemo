# CA_REMO 详细计划

## 1. 目标

设计并实现 `CA_REMO`：Confidence-Aware Relation Learning for Expensive Many-Objective Optimization。

算法定位是 REMO 的简单有效改进版，核心不是更换复杂神经网络，而是解决 REMO 中两个直接问题：

1. REMO 的 PBI 二分类标签并不总可靠，靠近 PBI 边界的样本会产生噪声关系对。
2. REMO 训练完关系模型后默认直接使用，缺少类似 PCSAEA 的可靠性管理机制。

因此，`CA_REMO` 保留 REMO 的框架，只在关系学习链条中加入三个轻量机制：

1. PBI-margin label confidence：用样本到 PBI 分类边界的距离估计标签置信度。
2. Confidence-balanced relation pair generation：优先使用高置信度样本构造关系对，并用置信度作为训练权重。
3. Reliability-aware surrogate management：用验证关系对决定关系模型正向使用、反向使用或弱化使用。

## 2. 文件结构计划

当前实现放在：

`PlatEMO/Algorithms/Multi-objective optimization/CA_REMO/`

文件职责如下：

| 文件 | 职责 |
|---|---|
| `CA_REMO.m` | PlatEMO 主算法入口，负责初始化、训练关系模型、调用候选筛选、真实评估和环境选择 |
| `CAPBIConfidence.m` | 基于 PBI 自适应分类，并输出每个样本的 margin confidence |
| `CARelationPairs.m` | 从高置信 good/bad 样本中构造三分类关系对，输出样本权重 |
| `CADataProcess.m` | 对关系对进行分层训练/验证划分 |
| `CAOneHot.m` | 三分类关系标签和 one-hot/probability 之间转换 |
| `CAReliability.m` | 计算验证准确率、反向准确率，并给出模型使用状态 |
| `CASurrogateSelection.m` | 可靠性感知的代理辅助候选解生成和筛选 |
| `CARefSelect.m` | REMO 风格参考解/环境选择，使用前缀避免路径冲突 |
| `CA_REMO_详细计划.md` | 本计划文档 |
| `CA_REMO_算法汇报.md` | 算法汇报、论文贡献点和实验方案 |

所有 MATLAB 辅助函数使用 `CA` 前缀，避免与 REMO、PCSAEA 目录中的 `DataProcess.m`、`RefSelect.m`、`GetOutput_PBI.m` 等函数发生路径冲突。

## 3. 算法流程计划

### 3.1 初始化

采用 REMO/PCSAEA 常用昂贵优化初始化方式：

1. 若 `Problem.D <= 10`，初始样本数为 `max(11D-1, Problem.N)`。
2. 否则初始样本数为 `max(100, Problem.N)`。
3. 使用 Latin hypercube sampling 采样初始决策变量。
4. 调用 `Problem.Evaluation` 获得真实目标值。
5. 所有真实评估样本进入 `Archive`。

### 3.2 每一代主循环

每代执行：

1. 使用 `CARefSelect(Population,k)` 选择参考解。
2. 使用 `CAPBIConfidence(Population.objs, Ref.objs)` 对样本进行 PBI 分类。
3. 对每个样本计算 `margin = |1 - g_pbi(x)|`。
4. 将 margin 归一化为 `confidence`。
5. 使用 `CARelationPairs` 从高置信 good/bad 样本构造三类关系对。
6. 使用 `CADataProcess` 划分训练集和验证集。
7. 训练轻量三分类 `patternnet` 关系模型。
8. 使用 `CAReliability` 判定模型状态：
   - `mode = 1`：验证准确率达到阈值，正向使用；
   - `mode = -1`：反向准确率达到阈值，反向使用；
   - `mode = 0`：模型不可靠，弱化关系分数，主要依赖多样性 fallback。
9. 使用 `CASurrogateSelection` 生成并筛选候选解。
10. 对筛出的候选解进行真实评估，加入 `Archive`。
11. 使用 `CARefSelect(Archive, Problem.N)` 更新下一代种群。

## 4. 核心设计细节

### 4.1 PBI-margin 置信度

REMO 用 PBI 判断样本是否属于参考解引导的优良区域：

`g_pbi(x) <= 1` 为 good 类，否则为 bad 类。

`CA_REMO` 进一步计算：

`margin(x) = |1 - g_pbi(x)|`

直觉：

- `margin` 越小，样本越接近分类边界，标签越不可靠。
- `margin` 越大，样本越远离分类边界，标签越可靠。

归一化方式：

`confidence(x) = min(1, margin(x) / Q75(margin))`

其中 `Q75` 用排序后的 75% 分位近似，避免依赖额外工具箱。

### 4.2 置信度筛选关系对

REMO 原始做法使用所有 good/bad 样本构造关系对。`CA_REMO` 改为：

1. 在 good 类中按 confidence 降序选前 `confRatio`。
2. 在 bad 类中按 confidence 降序选前 `confRatio`。
3. 用这些高置信样本构造：
   - good-good：标签 `0`
   - bad-bad：标签 `0`
   - good-bad：标签 `1`
   - bad-good：标签 `-1`
4. 同类样本如果过多，只保留权重最高的一部分。
5. 每个关系对的权重为两个样本 confidence 的较小值。

这样做的目的：

- 降低 PBI 边界噪声。
- 避免弱标签关系污染模型。
- 让训练样本边界更清晰，接近 PCSAEA 的 top/bottom pair 思路，但置信度来源仍然是 REMO 自身的 PBI 几何边界。

### 4.3 轻量关系模型与可靠性管理

由于高置信关系对应该比全样本关系对更容易区分，当前实现不使用 REMO 原始的大三层网络，而使用紧凑两层网络：

`[ceil(xDim/2), ceil(xDim/4)]`

并将训练轮数限制为 50。这样做的目的不是追求最大拟合能力，而是保持昂贵优化中的代理训练成本可控。如果后续实验发现欠拟合，可以在消融中加入更大网络作为对照。

训练集只用于拟合模型，验证集用于判断模型能否使用。

给定验证预测 `Pred` 和真实关系标签 `Truth`：

- 正向准确率：`acc = weighted mean(Pred == Truth)`
- 反向准确率：`reverseAcc = weighted mean(Pred == -Truth)`，只在非零关系对上计算

决策：

- 若 `acc >= delta`，正向使用模型。
- 若 `reverseAcc >= delta`，反向使用模型。
- 否则不信任模型，候选选择时将关系分数置零，只保留小权重多样性引导。

### 4.4 候选选择

`CASurrogateSelection` 延续 REMO 的内层代理搜索：

1. 使用 `OperatorGA` 生成候选解。
2. 候选解与高置信 good/bad anchors 构造成对比较。
3. 汇总关系预测概率得到 relation score。
4. 根据可靠性状态调整分数：
   - 正向模型：使用原始 relation score。
   - 反向模型：使用负 relation score。
   - 不可靠模型：relation score 置零。
5. 加入轻量决策空间多样性奖励：

`finalScore = reliability * relationScore + divWeight * diversityScore`

6. 每代最多选 4 个候选解进行真实评估，与 REMO 的昂贵评估节奏保持接近。

## 5. 参数计划

| 参数 | 默认值 | 含义 | 实验中建议测试 |
|---|---:|---|---|
| `k` | 6 | 参考解数量 | 6 作为主设置；敏感性测试 4/6/8/10 |
| `gmax` | 3000 | 内层代理搜索预算 | 与 REMO/PCSAEA 对齐 |
| `confRatio` | 0.35 | 每类保留的高置信样本比例 | 0.25/0.35/0.50/1.00 |
| `delta` | 0.65 | 可靠性使用阈值 | 0.55/0.65/0.75/0.85 |
| `divWeight` | 0.05 | 多样性奖励权重 | 0/0.02/0.05/0.10 |

## 6. 实现检查计划

静态检查：

1. 确认 `CA_REMO.m` 类名与文件名一致。
2. 确认目录内没有未前缀化的通用函数名。
3. 确认每个 `.m` 文件都能被文本扫描到函数定义。
4. 确认无明显 MATLAB 语法错误，例如缺少 `end`、类名不一致、错误的引号。

运行检查建议：

```matlab
platemo('algorithm',@CA_REMO,'problem',@DTLZ2,'M',3,'D',10,'N',50,'maxFE',120)
```

由于当前环境未确认 MATLAB 可用，运行验证应在 MATLAB/PlatEMO 环境中完成。

## 7. 后续实验计划

详见 `CA_REMO_算法汇报.md` 中的实验与发表预期部分。
