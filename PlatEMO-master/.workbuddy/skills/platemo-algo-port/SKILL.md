---
name: platemo-algo-port
description: Diagnose third-party or older algorithm failures against the local PlatEMO checkout, especially SOLUTION, OperatorGA, helper paths, and clustering. Verify local signatures and preserve real-evaluation accounting.
---

# PlatEMO 算法接口适配

## 先确认实际调用

读取算法入口、报错栈及当前 checkout 的 `Problems/SOLUTION.m`、`Problems/PROBLEM.m`、`Algorithms/ALGORITHM.m` 和被调用算子。有 MATLAB 时用 `which -all` 排除同名函数遮蔽；不要仅凭“2025 版”等年份推断接口。

## 真实评估和算子

- 当前 `SOLUTION(PopDec,PopObj,PopCon,PopAdd)` 不能只传决策矩阵。先判断原调用需要真实目标、已有目标还是代理预测：仅需真实评估时使用 `Problem.Evaluation(PopDec)`；已有真实结果不重复评估，代理候选不为修复接口而提前真实评估。
- `Problem.Evaluation` 会增加 FE；核对剩余预算及修改前后的真实评估次数，不能机械替换所有 `SOLUTION(X)`。
- 当前 `OperatorGA(Problem,Parent,Parameter)` 接收决策矩阵时返回未评估矩阵；接收 `SOLUTION` 数组时内部调用真实评估。调用处必须明确所需类型。
- `ALGORITHM.Solve` 添加算法和问题所在目录，不递归添加普通辅助子目录。缺失函数先核对文件、`private` 可见性和同名冲突，确有需要再按算法位置添加特定目录；不默认移动文件或全库 `genpath`。
- `Problem.N` 是种群规模；实验中的初始化真实评估数需单独核对，不能仅凭参数名推断。

## 聚类和依赖

- 零向量的余弦距离可能产生 NaN。检查归一化、有效行、有限角度以及最终标签是否是合法整数。如何分配零向量应依据原机制决定；不能将某次 HES-EA 修复推广为通用 `NaN -> pi` 规则。
- `acos` 输入可因浮点误差越界；裁剪只修复有限的舍入误差，不能代替对 NaN、Inf、零范数的处理。
- `kmeans` 当前官方文档中的 `EmptyAction` 默认是 `singleton`。检查实际函数版本、显式选项、样本数、不同点数量、请求簇数及下游空索引；使用 singleton 不能保证所有后续索引安全。
- `acos` 是基础 MATLAB 函数。`fitcknn`、`kmeans`、`pdist2` 等需分别核对工具箱与路径；`predict` 需确认模型类型及其方法，不能将所有“未定义”统一判成缺工具箱。

## 验证与报告

围绕实际报错做廉价问题、小预算验证；聚类修改覆盖零向量、重复点和空集合，评估修改核对 FE。固定随机种子比较受影响路径，未验证不能声称“无异常时完全不改结果”。没有可用 MATLAB 时明确仅完成静态核对。

来源：本 checkout 的上述源码；[MathWorks kmeans 文档](https://www.mathworks.com/help/stats/kmeans.html)，核对日期 2026-09-13。未来适配仍以实际安装为准。
