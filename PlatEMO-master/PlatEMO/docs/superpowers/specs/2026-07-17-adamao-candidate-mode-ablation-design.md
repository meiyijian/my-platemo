# AdaMaO SDE 候选模式消融设计

## 目标

以现有 `REMO_new2_AdaMaO_SDEOnly` 作为 `CurrentGate` 基线，不修改它的三模式门控；新增四个只改变候选解模式规则的 PlatEMO 算法入口：

- `AlwaysExplore`：始终使用 `explore`。
- `AlwaysIndicator`：SDE 指标模型可用时使用 `indicator`，否则回退 `explore`。
- `UniformMix`：SDE 指标模型可用时以固定概率 `P_ind=0.5` 使用 `indicator`，否则使用 `explore`。
- `LinearSchedule`：SDE 指标模型可用时以 `P_ind=progress` 使用 `indicator`，否则使用 `explore`。

除候选模式路由外，四个新版本的初始化、关系模式、SDE 计算、SVR 训练、代理模型、候选生成、真实评估和环境选择完全一致。

## 进度定义

初始种群完成真实评估后立即记录：

```matlab
InitFE = Problem.FE;
```

候选模式使用独立于现有 HPC 内部 `ratio=FE/maxFE` 的进度：

```matlab
progress = min(1,max(0,(FE-InitFE)/(maxFE-InitFE)));
```

当 `maxFE <= InitFE` 时令 `progress=1`，避免除零。这样不同问题或不同决策维度导致的初始评估量差异不会改变线性策略的初始概率；第一代的 `P_ind` 为 0，剩余评估预算耗尽时为 1。

## 架构

`CurrentGate` 主文件保持原样。四个新入口继承一个共享基类，基类保存四个实验版本共同的算法主体；入口类只返回一个策略名。纯函数 `ResolveSDECandidateMode` 负责计算 `progress`、`P_ind` 和最终模式，便于独立单元测试。

```text
REMO_new2_AdaMaO_SDEOnly/
├── REMO_new2_AdaMaO_SDEOnly.m                 # CurrentGate，保持原样
├── REMO_new2_AdaMaO_SDEOnly_ModeBase.m        # 四个新版本共享主体
├── REMO_new2_AdaMaO_SDEOnly_AlwaysExplore.m
├── REMO_new2_AdaMaO_SDEOnly_AlwaysIndicator.m
├── REMO_new2_AdaMaO_SDEOnly_UniformMix.m
├── REMO_new2_AdaMaO_SDEOnly_LinearSchedule.m
├── ResolveSDECandidateMode.m                   # 纯路由函数
├── CreateSDECandidateModeStream.m              # 可复现实验专用随机流
└── tests/test_REMO_new2_AdaMaO_SDEOnly_Policies.m
```

共享基类与 CurrentGate 位于同一目录，因此继续使用该目录现有的 `IndicatorSelectorSDEOnly.m` 和 `private/` 依赖，不复制同名私有函数，也不引入 MATLAB 路径冲突。

## 随机数隔离

`UniformMix` 与 `LinearSchedule` 每代都从专用 `RandStream` 各取一个 `u`，即使该代指标模型不可用也照常取样。`CreateSDECandidateModeStream` 根据 `Algorithm.run` 创建专用流：

```matlab
modeSeed = 10000000 + runId;
modeStream = RandStream('mt19937ar','Seed',modeSeed);
```

未传入 `run` 时 `runId=1`。正式实验应为同一“问题 × 目标数 × 重复编号”给所有版本传入相同 `run`，并在每次求解前重置相同的全局 RNG 种子。专用流不消耗全局 RNG，且 UniformMix 与 LinearSchedule 在相同 `run` 下使用相同的逐代 `u` 序列。

## 路由规则

路由按以下优先级执行：

1. 计算 `progress` 和策略对应的 `P_ind`。
2. 若 `IndicatorModel` 为空，最终模式固定为 `explore`。
3. `always_explore` 始终返回 `explore`。
4. `always_indicator` 在模型可用时返回 `indicator`。
5. 两个随机混合策略在模型可用且 `u < P_ind` 时返回 `indicator`，否则返回 `explore`。

四个新版本在每个能够生成候选解的代次都尝试计算 SDE 并训练 `IndicatorModel`，包括 `AlwaysExplore`。若关系对为空，沿用 CurrentGate 的原始提前退出路径，不额外训练一个不会被使用的模型；但随机混合版本仍在退出前消耗该代专用随机数，避免后续代次的配对序列错位。这样消融变量仅是“模型是否参与候选重排”，不是“是否支付候选代次的模型训练成本”。`p_err`、`coverage` 和 `degeneracy` 不再参与四个新版本的候选模式选择，但继续保留在关系模式和诊断代码中。

## 验证标准

- CurrentGate 主文件 SHA-256 仍为 `73F1CE787679D9E4AAB308110FC49A1218718A4108F99C6C51287FD253687110`。
- 四个类均可被 MATLAB `which` 发现，并映射到唯一策略。
- 修正进度对不同 `InitFE` 具有平移/缩放一致性，且被限制在 `[0,1]`。
- 模型不可用时四个新版本均回退 `explore`。
- UniformMix 的 `P_ind` 恒为 0.5；LinearSchedule 的 `P_ind` 等于修正进度。
- 相同 `run` 产生相同模式随机流，不同 `run` 产生不同模式随机流，且专用流不改变全局 RNG 状态。
- MATLAB 单元测试通过，并至少用一个小预算问题分别启动四个新算法，排除类继承、私有函数解析和运行时错误。

## 非目标

本次不改变 CurrentGate，不调整关系模式门控，不修改 SDE 公式，不新增 ReverseSchedule，不运行正式 IGD 消融，也不修改 `platemo.m` 的随机种子行为。
