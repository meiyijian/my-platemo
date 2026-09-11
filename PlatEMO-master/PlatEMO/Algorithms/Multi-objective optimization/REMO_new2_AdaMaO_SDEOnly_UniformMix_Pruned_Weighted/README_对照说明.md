# Pruned_Weighted：仅恢复批次内质量—距离权重的对照

## 目的与基线

基于当前 `REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned` 新建独立目录和算法入口。冻结已有 Pruned、Original、Maximin 源码，不覆盖原算法或历史结果。

研究对照为：同样的 Pruned 配置下，将探索分支后续批次点的“纯距离选择”替换为原版的 `0.75×归一化关系得分＋0.25×归一化距离`，检验持续质量约束的作用。本版不是恢复完整 Original。

## 参数

| 参数顺序 | 名称 | 默认值 |
|---|---|---:|
| 1 | gmax | 3000 |
| 2 | pMix | 0.50 |
| 3 | rGood | 0.25 |
| 4 | qKeep | 0.70 |
| 5 | nMax | 6 |

Pruned 原文件默认 qKeep=0.80 未修改；此前正式实验通过配置覆盖为0.70。本对照默认设为0.70，比较时两个入口都显式使用 `{3000,0.50,0.25,0.70,6}`。0.75/0.25作为本对照固定权重，不新增可调参数。

## 唯一预期机制变化

探索仍按关系得分第 qKeep 分位点筛选（默认保留最高约30%），没有模糊度奖励。先选择最高关系得分点，再对剩余合格候选计算：

\[
d(x,S)=\min_{s\in S}\|x-s\|_2,
\qquad
A(x)=0.75\widehat R(x)+0.25\widehat d(x,S).
\]

每步在**本步剩余候选集合**上分别对关系得分与距离作 min-max 归一化。范围小于 `1e-12` 时取常数0.5，沿用 Original 的规则。选择A最大的点并更新距离，直至达到候选数、剩余FE和nMax的共同上限。

- 距离是原始决策空间的**欧氏距离**，不是平方距离；加权前使用平方距离会改变相对数值，不能视作等价实现。
- 不使用完整历史档案距离，不增加边界缩放或变量权重。
- A严格相等时保留原始候选顺序，沿用Original的max规则。
- 筛选集合全部可被评价时，按关系得分降序返回全部候选，沿用Original的批次规则。
- 没有恢复nMin或门槛外补足逻辑。

## 冻结内容

- PAQC、参考解数量规则、关系对生成、网络训练及其划分、模式随机流、GA候选生成过程均保持。
- 指标分支保持Pruned：关系前30%，再直接按预测SDE排序；不恢复最少20个或第二次0.70指标分位筛选。
- 不恢复lambda0、p_err推断、0.45误差门控、探索模糊度奖励或其进度衰减。
- 初始化、真实FE截断、空候选回退和环境选择保持Pruned。

文件层面的改动只有：新入口的类名/说明及qKeep默认值；`private/DiversifiedInfillSelection.m` 的探索选择器调用及说明；新增加权选择器。其他复制的12个共享文件字节一致。`frozen_baseline_manifest.json` 记录创建时基线15个运行源文件的SHA256，校验报告见 `tests/freeze_verification.json`。

## 运行

在PlatEMO根目录运行，例如：

```matlab
addpath(genpath(pwd));
problem = DTLZ2('N',100,'M',10,'D',30,'maxFE',300);
algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted( ...
    'parameter',{3000,0.50,0.25,0.70,6},'run',1, ...
    'save',-10,'outputFcn',@(a,p) []);
rng(1,'twister');
algorithm.Solve(problem);
result = algorithm.result{end,2};
```

示例结果留在内存中；未自动写入正式运行数据目录。PlatEMO GUI中可以按新类名选择此算法。原版七参数调用仍被拒绝。

进行共同种子对照时，基线和对照分别构造问题/算法后，在Solve前设置相同全局种子及run。直接在`platemo(...)`前调用rng不能保证相同种子，因为本地platemo入口会调用rng('shuffle')。

## 验证

本次仅运行候选选择检查与短预算集成检查，不启动正式九次实验。验证内容：质量约束恢复、距离仍起作用、欧氏距离而非平方距离、并列与小候选池行为、指标粗筛不恢复20个下限、剩余FE截断，以及同种子纯指标模式与冻结Pruned的最终决策/目标档案一致性。

2026-09-11在本机MATLAB R2023a完成验证：10/10测试通过，全部16个.m文件静态分析为0条消息；15个基线运行源文件未变，12个复制共享文件字节一致，入口与候选分派仅含预期差异。纯指标模式的同种子短预算运行最终决策与目标档案完全一致。实际测试结果记录在 `tests/validation.log`；通过检查只证明实现行为，不证明最终IGD/HV提升。

## 材料位置

原Pruned诊断材料已移至其目录下：

`../REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned/diagnostics/pruned_diagnosis_20260911/`

本对照的说明、测试和校验材料全部存放在当前算法目录内。原始运行数据约定保存在 `C:\Users\lsx\Desktop\REMOandDREMO测试集`；结果汇总表保存在 `C:\Users\lsx\Desktop\AdaMao实验表`。
