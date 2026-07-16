# AdaMaO SDE-only 版本设计

## 目标

在不改变 AdaMaO 其他机制的前提下，新建一个固定使用现有 SDE 指标的独立算法版本，用于与当前多指标轮盘版和已有 NoIndicator 版进行公平对照。

新算法目录和 MATLAB 类名统一为 `REMO_new2_AdaMaO_SDEOnly`。

## 设计选择

采用最小差异方案：保留外层 `use_indicator` 开关、候选模式切换、关系模型、混合 PBI、自适应参考向量、SVR 指标模型和当前 `calFitness_SDE` 的 Minkowski(Lp) 低分兜底，只删除多指标轮盘及其反馈状态。

不采用以下两种方案：

- 不把候选模式强制设为 `indicator`，因为这会同时修改外层路由机制，无法单独判断取消轮盘的作用。
- 不把当前 SDE 改成纯 SDE，因为删除 Minkowski 兜底会引入第二个实验变量。

## 目录结构

```text
Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/
├── REMO_new2_AdaMaO_SDEOnly.m
├── IndicatorSelectorSDEOnly.m
├── private/
│   ├── AdaMaOSelection.m
│   ├── calFitness_SDE.m
│   ├── DataProcess.m
│   ├── DataProcess_confidence.m
│   ├── GetOutput_PBI.m
│   ├── GetRelationPairs.m
│   ├── GetRelationPairs_confidence.m
│   ├── HybridPBI_Classification.m
│   ├── onehotconv.m
│   ├── RefSelect.m
│   └── Shape_Estimate.m
└── tests/
    └── test_REMO_new2_AdaMaO_SDEOnly.m
```

辅助函数使用 `private` 目录保存当前实现快照，使新算法运行时优先解析自己的辅助函数，同时避免 PlatEMO 对全部算法目录执行 `addpath(genpath(...))` 后发生同名函数串用。

## 代码改动

`REMO_new2_AdaMaO_SDEOnly.m` 从当前 `REMO_new2_AdaMaO.m` 建立基线，只做以下改动：

1. 将类名改为 `REMO_new2_AdaMaO_SDEOnly`。
2. 删除 `tau_indicator`、三个 `indicator` 结构体、`Choose_record`、`Win_record` 和 `Pw`。
3. 将 `IndicatorSelector(Population,indicator,Lp)` 替换为 `IndicatorSelectorSDEOnly(Population,Lp)`。
4. 删除 `indicator_flag`、`UpdateInformation` 调用和本地 `IndicatorFeedbackScore` 函数。
5. 保留 `Lp`，因为当前 SDE 对接近零的得分仍使用 Minkowski(Lp) 兜底。
6. 保留原来的异常回退：指标计算或 SVR 训练失败时令 `IndicatorModel=[]`，候选选择函数按原逻辑回退。

`IndicatorSelectorSDEOnly.m` 每代执行以下固定流程：

1. 用 `Shape_Estimate` 更新 `Lp`，失败时沿用上一代值。
2. 对空值、NaN、Inf 或非正 `Lp` 回退为 1。
3. 直接调用当前 `calFitness_SDE(Population.objs,Lp)`。
4. 不调用 `rand`，不计算 epsilon/MD 指标，不维护轮盘反馈。

## 明确保持不变的行为

- 算法参数及默认值保持不变，包括 `use_indicator`。
- `candidate_mode` 的 `conservative/explore/indicator` 判定保持不变。
- 只有进入原有指标分支时，SDE 训练出的 SVR 才参与候选重排。
- 种群初始化、评估预算、关系对模式、混合 PBI、候选生成及环境选择保持不变。
- 当前 SDE 的公式和 Minkowski 兜底保持原样。

## 验证标准

自动化测试必须证明：

1. 新类和固定 SDE 选择器可以被 MATLAB 找到。
2. 固定选择器输出与直接调用当前 `calFitness_SDE` 一致。
3. 不同随机种子下固定选择器给出相同结果，且选择器本身不消耗随机数。
4. 新主文件不包含轮盘状态、`UpdateInformation`、epsilon 指标或独立 MD 指标调用。
5. 用小评估预算启动一次 PlatEMO 运行时，无未定义函数、类名冲突或路径串用错误。

## 非目标

本次不修复候选模式判定指标，不简化关系对模式，不修改混合 PBI，不删除 SDE 内部的 Minkowski 兜底，也不生成正式消融结果。这些改动需要单独实验，不能与取消轮盘混在同一个版本中。
