# REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist

从 `REMO_UniformMix_Pruned_Weighted_Lambdat030` 复制，**只删一处**：探索分支批次构造里的批内距离项。

## 唯一改动

来源版本（Lambdat030）探索分支三步：
1. 关系得分 R 的 0.70 分位筛选（保留集合）；
2. 保留集合内归一化，`A_t(x) = R~(x) + 0.30*U~(x)`（U = 预测模糊度）；
3. 批构造：首个点取 `A_t` 最大；**后续每个点取 `0.75*A_t~ + 0.25*d~` 最大**（d = 与已选点的最小距离）。

本版本：**第 3 步删掉 `0.25*d~` 项**，每个成员都只最大化 `A_t`（在剩余集合上重新归一化）。由于重新归一化是单调变换，批等价于"保留集合按 `A_t` 降序取前 target 个"，**全程不再计算任何距离**。第 2 步的 **0.30 模糊度奖励保持不变**。

## 不变量

- 公开参数不变，仍是 5 个：`{gmax,pMix,rGood,qKeep,nMax}` = `{3000,0.50,0.25,0.70,6}`；不接受第六个参数。
- PAQC、关系模型、候选生成、指标分支（`PrunedIndicatorSelection`）、环境选择（`RefSelect`）、`pMix`、`nMax`、剩余真实 FE 截断、初始采样与 N 规则全部与来源版本逐行一致。
- `private/` 11 个文件里**只有 `DiversifiedInfillSelection.m` 不同**（改调用 `NoBatchDistWeightedBatchSelection` + 诊断全局改名为 `ADAMAO_NOBATCHDIST_DIAG`，避免同进程多类混记）；其余 10 个文件与来源逐字节相同。
- 类文件与来源的代码差异仅：类名、诊断全局名、诊断结构新增 `distWeight = 0.00` 字段。

## 实验

框架与数据：`PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_M10/`
- M=10、D=30、N=100、maxFE=300、16 题（DTLZ1-7、WFG1-9）× 20 跑 = 320 跑；
- 种子 `21260912 + 1000*题目全局索引 + run`（与 10 目标数据集其余算法一致）；
- 数据落 `D:\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`。
