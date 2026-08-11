# UniformMix-OriginalRelation 独立算法设计规格

## 目标

将现有 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original` 从多个关系模式共用的实验目录中整理为一个可独立运行的 PlatEMO 算法目录，同时保持原有算法名称，保留该版本真正使用的可调参数，并删除课程学习、加权关系和自适应关系路由遗留内容。

目标目录和主类名称保持完全一致：

```text
Algorithms/Multi-objective optimization/
└── REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/
    └── REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m
```

## 已确定的接口

主类直接继承 `ALGORITHM`，不再继承旧的 `REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase`。PlatEMO GUI 只显示以下 7 个参数，顺序必须与 `ParameterSet` 顺序一致：

| 参数 | 默认值 | 作用 |
|---|---:|---|
| `gmax` | `3000` | 关系模型/代理选择的最大训练代数或迭代上限 |
| `pMix` | `0.50` | UniformMix 选择 indicator 分支的概率 |
| `rGood` | `0.25` | HybridPBI 中正组占种群的比例 |
| `qKeep` | `0.80` | 探索候选筛选中保留的候选比例 |
| `lambda0` | `0.35` | 探索强度初始系数 |
| `nMin` | `4` | 每代候选解数量下限 |
| `nMax` | `6` | 每代候选解数量上限 |

入口使用如下形式，保证 GUI 参数能够覆盖默认值：

```matlab
[gmax,pMix,rGood,qKeep,lambda0,nMin,nMax] = ...
    Algorithm.ParameterSet(3000,0.50,0.25,0.80,0.35,4,6);
```

参数约束在主程序开始处显式检查：

- `gmax`、`nMin`、`nMax` 为正整数；
- `nMin <= nMax`；
- `pMix`、`qKeep` 位于 `[0,1]`；
- `rGood` 位于 `(0,0.5]`；
- `lambda0 >= 0`。

## 删除和固定的内容

以下内容不进入新算法的 GUI，也不保留对应运行分支：

- `w_min`：只用于加权关系训练；OriginalRelation 使用普通无权训练。
- `tau_err`：只用于自适应关系模式路由。
- `use_indicator`：本算法固定训练并尝试使用 indicator 模型，不提供关闭核心机制的开关。
- `debug`：只控制打印，不属于算法参数。
- 课程学习模式中按置信度保留前 `80%` 样本的逻辑及其辅助函数。
- 加权关系模式、confidence 关系对、相关数据处理函数。
- `RuntimeDiagnostics`、`prev_p_err` 和固定关系模式回调；它们只服务于旧的自适应关系路由。

以下结构常量保留在内部，不开放为 GUI 参数：

- PBI 惩罚系数 `theta=5`；
- 当前关系模型错误率对探索强度的固定归一化阈值 `0.45`；
- 代表解数量采用当前等价规则：

  ```matlab
  k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
  ```

这里删除 GUI 中的 `k` 不会改变默认实验轨迹；它当前默认值为 `6`，且实际调用使用的是 `k_eff`。固定该规则可以避免在不同目标维数下暴露一个容易被自适应下限覆盖的冗余参数。

需要区分两个原本都可能出现的 `0.80`：课程学习的置信度筛选比例删除；`qKeep=0.80` 保留，因为它仍然参与探索候选选择。

## 运行结构

新算法的主循环固定为以下数据流：

1. 按原算法规则初始化种群和 archive。
2. 使用 `HybridPBI_Classification` 生成 `Catalog`、confidence 和代表解；正组数量改为 `ceil(N*rGood)`，默认仍为原来的 `ceil(N/4)`。
3. 始终使用 `GetRelationPairs` 生成无权关系对，并通过普通 `DataProcess` 训练关系网络。
4. 每代训练 SDE indicator 模型；训练失败或模型不可用时，候选模式安全回退到探索分支。
5. 使用 UniformMix：每代从独立的 candidate-mode 随机流抽取一个 `u`，当 `u < pMix` 且 indicator 模型可用时使用 indicator 分支，否则使用探索分支。
6. 将 `qKeep`、`lambda0`、`nMin`、`nMax` 和关系模型 `p_err` 传递给 `AdaMaOSelection`，完成候选解生成、评估和 archive 更新。

新目录不得在运行时依赖旧的 `REMO_new2_AdaMaO_SDEOnly` 混合目录中的同名主类、关系模式基类或加权/课程学习函数。PlatEMO 本身提供的 `ALGORITHM`、`Problem`、`UniformPoint`、`NDSort`、`OperatorGA` 及 MATLAB 神经网络/统计学习工具箱函数属于正常框架依赖，不复制到算法目录。

## 文件边界

新目录只包含主程序和该运行路径实际需要的辅助文件，预计包括：

- 主入口 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m`；
- `private/AdaMaOSelection.m`；
- `private/HybridPBI_Classification.m`，增加 `rGood` 参数；
- `private/GetRelationPairs.m`、`private/DataProcess.m`、`private/onehotconv.m`；
- `private/GetOutput_PBI.m`、`private/RefSelect.m`；
- `private/IndicatorSelectorSDEOnly.m`、`private/Shape_Estimate.m`、`private/calFitness_SDE.m`；
- `private/CreateSDECandidateModeStream.m`；
- 一个仅服务于该算法的 UniformMix 模式解析函数，接收 `pMix`；
- 需要由上述文件直接调用的最小辅助函数。

旧混合目录中的其他算法、实验审计脚本、报告和测试保留不动；但旧混合目录中的同名 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m` 需要移除，以保证 MATLAB 搜索路径只有一个同名主类。

## 兼容性和错误处理

- 默认参数下，初始化规则、随机流名称、UniformMix 每代抽样位置、候选选择参数和 `k_eff` 规则保持与当前 OriginalRelation 版本一致。
- `pMix=0` 时始终选择探索分支，`pMix=1` 时 indicator 可用则始终选择 indicator 分支；indicator 不可用时两个边界都必须安全回退到探索分支。
- 关系对不足以训练模型时，沿用现有空关系对回退：通过 `RefSelect` 保持种群更新，不调用不存在的网络输入。
- indicator 训练失败、SVM 拟合失败或预测结果为空时，不终止算法，改用探索候选生成。
- 参数非法时在进入主循环前抛出带有明确参数名的错误。

## 验证要求

实现采用先写测试、再写代码的方式。测试至少覆盖：

1. 主类 `which` 结果唯一且指向新目录；旧目录不再存在同名入口。
2. GUI 头部和 `ParameterSet` 暴露且只暴露 7 个参数，默认值和顺序准确。
3. 新目录的静态依赖检查不包含 `RelationModeBase`、`GetRelationPairs_confidence`、课程学习筛选、`w_min`、`tau_err`、`debug` 等已删除内容。
4. 参数边界和非法参数错误行为。
5. `pMix` 边界、indicator 不可用回退，以及 `rGood` 对 Catalog 正组数量的影响。
6. 在小预算 DTLZ2 实例上的实际 PlatEMO 短程运行。
7. 默认参数、固定随机种子下与现有 CascadeAudit/操作性参考轨迹的关键状态一致，包括初始化 FE、候选模式随机抽样顺序和最终 archive 规模。
8. 新文件通过 MATLAB `checkcode`，并运行受影响的固定关系模式、CascadeAudit 和基础 SDEOnly 测试。

## 不在本次范围内

本次只整理和验证 UniformMix-OriginalRelation 独立算法，不重做全部性能实验，不修改其他关系模式，不删除旧实验报告，也不改变 `rGood` 的默认值。后续若需要参数敏感性实验，使用 GUI 分别改变 `pMix`、`rGood`、`qKeep`、`lambda0`、`nMin/nMax`，并保持其他参数和随机种子协议不变。
