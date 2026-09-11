# UniformMix Maximin 简化探索版本

算法入口：`REMO_new2_AdaMaO_SDEOnly_UniformMix_Maximin.m`。

以 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original` 当前磁盘代码为基础新增，原目录未修改。包括原目录中尚未提交的 `GetRelationPairs.m` 和 `PBIQualityClassification.m` 修改；不是从旧 Git 提交恢复的版本。未复制旧 k6 入口、历史实验结论和汇报材料，以免混淆版本身份。

## 选择规则

保留原关系模型引导的遗传候选生成、PAQC 分组、模式切换和指标分支。探索分支改为：

\[
x^*=\arg\max_{x\in\mathcal C\setminus\mathcal S}
\min_{z\in\mathcal H\cup\mathcal S}\|\bar x-\bar z\|_2,
\qquad \bar x_j=(x_j-l_j)/(u_j-l_j).
\]

其中 H 是完整真实评价档案 `Archive.decs`，不是当前种群或参考解集合；S 是当前已选批次，初始为空。

- 变量按问题边界缩放，固定变量不参与距离。
- 候选精确按行去重，并排除与历史已评价解完全相同的决策向量。未引入近重复距离阈值。
- 第一个点到历史档案计算距离；每加入一个候选，即更新剩余候选到 H∪S 的最小距离。
- 距离严格相同时，关系分数较高者优先，再按候选原始行顺序选择。
- 实现使用平方欧氏距离，其排序与欧氏距离完全一致。
- 每轮探索最多选择 6 个，受剩余真实评价预算和可用候选数量限制。

不再使用探索分位筛选、预测模糊度奖励、误差门控、阶段衰减和得分—距离混合权重。关系得分内部原有的置信度加权平均仍保留，以保持候选生成行为；这不再构成单独的模糊度探索奖励。网络训练及训练/留出数据划分保留，省略不再使用的留出误差推断。

## 参数与兼容性

新入口只接受三个算法参数，顺序为：

| 参数 | 默认值 | 含义 |
|---|---:|---|
| gmax | 3000 | 累计生成候选的内循环阈值 |
| pMix | 0.50 | 指标模型可用时选择指标分支的概率 |
| rGood | 0.25 | 正组比例 |

探索批次上限固定 6。指标分支保留原默认的补足目标 4、上限 6，以及其关系分数粗筛和指标重排序；这两个批次常数不再暴露为调参接口。原七参数调用不能直接套用新入口。

初始化沿用原 N 规则（D≤10 时 11D−1，否则 100），但在总预算不足时截断初始真实评价数量。原有剩余预算截断继续保留。探索候选全部已评价或没有训练解对时，发出警告并提前结束，避免重复真实评价或无进展循环。指标分支保留原有空候选遗传补充行为。

## 运行

在 PlatEMO 根目录添加平台路径后可运行：

```matlab
addpath(genpath(pwd));
platemo('algorithm',@REMO_new2_AdaMaO_SDEOnly_UniformMix_Maximin, ...
    'problem',@DTLZ2,'N',100,'M',10,'D',30,'maxFE',300);
```

指定三个算法参数：

```matlab
platemo('algorithm',{@REMO_new2_AdaMaO_SDEOnly_UniformMix_Maximin, ...
    3000,0.50,0.25},'problem',@DTLZ2, ...
    'N',100,'M',10,'D',30,'maxFE',300);
```

需要原算法同样使用的神经网络及统计学习工具箱。

## 验证范围

2026-09-11 在本机 MATLAB R2023a 完成验证：11/11 项测试通过。算法入口、`ArchiveMaximinSelection.m` 和修改后的 `private/DiversifiedInfillSelection.m` 的 `checkcode` 检查均为 0 条消息。详细运行记录见 `tests/validation.log`。MATLAB 连接工具附着失败后使用本机批处理执行；首次测试路径配置错误已修正，最终记录对应修正后的完整通过结果。

`tests/TestArchiveMaximinSelection.m` 检查逐点距离更新、变量范围缩放、固定变量、去重与历史过滤、并列规则、空候选和批次预算上限。

`tests/TestMaximinIntegration.m` 使用短预算 DTLZ2 检查探索批次 54→60→61 FE、pMix=1 配置下的完整运行和初始化预算截断。短预算与较小 gmax 仅用于验证接口和执行行为，不是论文实验配置。

```matlab
folder = fileparts(which('REMO_new2_AdaMaO_SDEOnly_UniformMix_Maximin'));
results = runtests(fullfile(folder,'tests'));
assertSuccess(results);
```

测试不证明优化性能优于原版；尚未执行正式多问题、多种子 IGD/HV 对照实验。
