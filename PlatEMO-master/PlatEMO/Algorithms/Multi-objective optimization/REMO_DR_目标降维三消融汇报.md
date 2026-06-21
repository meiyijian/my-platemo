# REMO 目标降维三消融汇报

## 研究动机

原始 REMO 在超多目标问题上会遇到目标维度过高、Pareto 支配关系稀疏、关系标签难学习的问题。`REMO_DiRel_LKC` 引入了结构感知目标分组和双尺度关系学习，但它同时包含难度感知 easy group 选择。为了单独验证“目标降维”本身是否能提升 REMO 在超多目标上的表现，本轮实现三个控制变量清晰的消融算法：

- `REMO_DR_RandFixed`
- `REMO_DR_LKCFixed`
- `REMO_DR_LKCDynamic`

三者都保留 `REMO_DiRel_LKC` 的全目标支线、子目标支线、双网络训练、full-first 仲裁和真实昂贵评估流程，只改变子目标空间的构造方式。三者都不调用 `DifficultyProfiler` 或 `BuildStructureAwareEasySet`。

## 三个算法的区别

| 算法 | 分组来源 | 是否固定 | 子目标语义 | 主要作用 |
| --- | --- | --- | --- | --- |
| `REMO_DR_RandFixed` | 随机把 M 个目标均衡分成 `k_red` 组 | 固定 | 从初始到结束保持不变 | 检验“随便降维”是否已经有效 |
| `REMO_DR_LKCFixed` | 第 `lockGen` 代用 LKC 结构相似性分组 | 锁定后固定 | warm-up 后保持不变 | 检验“结构感知分组本身”是否有效 |
| `REMO_DR_LKCDynamic` | 每代用 LKC 重新估计目标结构 | 动态 | 每代可能变化 | 检验“动态结构感知”是否带来额外收益 |

推荐论文消融解释顺序：

```text
RandFixed  -> 降维基线
LKCFixed   -> 结构分组价值
LKCDynamic -> 动态更新价值
```

## 动态与固定分组原理

`LKCDynamic` 每代根据当前已评估种群重新估计 LMVT 局部斜率特征，计算目标之间的 Pearson 结构相似性，然后用 correlation k-means 得到 `k_red` 个目标组。它的子网络每代都会重新训练，所以不存在“上一代代理模型预测这一代新分组”的直接错配；但如果目标分组频繁跳变，子目标关系标签会抖动，搜索信号可能不稳定。

`LKCFixed` 的目的就是把这个问题拆开。它在前若干代允许 LKC 根据当前样本估计结构，到 `lockGen` 时保存目标组和组内权重；之后每代只按锁定分组对当前目标值重新归一化和聚合，代理模型仍然每代重新训练。这样可以让子目标语义稳定，观察性能提升是否主要来自结构分组本身。

`RandFixed` 选择固定而不是每代随机，是为了构造更公平的随机降维基线。若每代随机更新，子目标语义完全无结构依据地变化，噪声过大，较难解释实验结果。固定随机分组能回答更干净的问题：随机压缩到 `k_red` 维是否已经足够。

## 参数说明

三个算法使用统一参数顺序：

```matlab
[k_red,tau_conf,k_ref,gmax,K_ens,nCells,scalarGap,lockGen] = ...
    Algorithm.ParameterSet(3,0.3,6,1000,3,5,0.05,3);
```

- `k_red`：降维后的目标组数，默认 3；建议额外测试 2。
- `tau_conf`：full-first 仲裁的不确定性阈值。
- `k_ref`：参考解数量，沿用 REMO 风格。
- `gmax`：每代代理筛选候选预算。
- `K_ens`：双关系网络集成规模。
- `nCells`：LKC 局部 LMVT 特征估计的网格数。
- `scalarGap`：非支配样本关系标签的均值差阈值。
- `lockGen`：`LKCFixed` 锁定 LKC 分组的代数，默认第 3 代。

当 `Problem.M <= k_red` 时，实际组数等于 `Problem.M`，即不做额外合并。

## 实验建议

第一轮建议只比较目标降维本身，不引入 APD 环境选择或新的 acquisition 项：

```text
REMO
REMO_DiRel
REMO_DiRel_LKC
REMO_DR_RandFixed
REMO_DR_LKCFixed
REMO_DR_LKCDynamic
```

推荐测试问题：

```text
DTLZ2, DTLZ3, WFG4, WFG9
M = 10, 15, 20
k_red = 3，补充 k_red = 2 消融
```

指标建议包括 IGD/IGD+、HV 或归一化 HV、真实评估次数、训练时间，以及每代 `Algorithm.metric.drDiag` 中的分组和仲裁诊断。

## 预期现象与风险

如果 `REMO_DR_LKCFixed` 明显优于 `REMO_DR_RandFixed`，说明 LKC 的结构分组确实比随机压缩更有信息价值。如果 `REMO_DR_LKCDynamic` 进一步优于 `LKCFixed`，说明动态结构感知能适应搜索阶段变化；如果动态版不如固定版，说明分组跳变可能带来了子目标语义抖动。

主要风险有三点：

- 样本过少时 LKC 结构估计不稳，`LKCFixed` 的锁定代数可能需要调到 4 或 5。
- `k_red=2` 降维过强，可能损失过多冲突信息；`k_red=3` 是更稳妥默认值。
- full-first 仲裁仍以全目标网络为主，子目标网络只在全目标不确定时提供 tie-break 信号；因此降维收益可能表现为稳定性提升，而不是每个问题上都大幅提高最终指标。
