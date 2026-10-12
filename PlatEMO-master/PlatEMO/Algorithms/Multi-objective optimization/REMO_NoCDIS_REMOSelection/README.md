# REMO_NoCDIS_REMOSelection：完整 CDIS 替换消融

本版本保留完整算法 `REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist`
的 PAQC 与优化宿主，以本仓库 `REMO/RSurrogateAssistedSelection.m` 原始模块
替换整个 CDIS。原有 `REMO_noBatchDict_noCDIS` 是保留歧义奖励分支的历史对照，
本版本采用独立类名和结果标识，两者不能混用或重命名已有结果。

## 参数与调用

参数顺序为 `{gmax,rGood,nMax}`，默认 `{3000,0.25,6}`。
`pMix` 和 `qKeep` 已删除，不再保留无效参数占位。

```matlab
platemo('algorithm',{@REMO_NoCDIS_REMOSelection,3000,0.25,6}, ...
        'problem',@DTLZ2,'N',100,'M',10,'D',30,'maxFE',500, ...
        'save',30,'run',1);
```

这是单次调用示例，不是已经执行的正式实验协议。正式运行前设置种子、运行编号、
线程数和独立输出目录；WFG 构造后检查实际 M/D/K/L。预算由调用者提供，
本算法不固定为 300 或 500 FE。

## 保留与替换的边界

保留 Full 的 Latin 初始化及初始化 FE 截断、PAQC 的连续评分/动态融合/正组配额、
`k_eff=min(Problem.N,max(6,ceil(1.5*Problem.M)))`、theta=5、关系训练的
数据划分及网络拓扑、累计已评价档案、环境选择和空候选 GA 回退。
六个相关私有函数逐字节复制自 Full，见 `source_manifest.json`。

CDIS 的探索和指标分支都已删除：没有置信度加权、关系分位数筛选、
`R_norm+0.30*U_norm` 奖励、累计候选池、SDE 指标及其 SVR，也没有模式抽样。
原始 REMO 模块逐代使用关系排名选择父代，最后仅从末代候选中选择：
`R>3.9` 的数量不足 4 时取关系排名前 4 个，否则返回所有超过阈值的候选。
REMO 的内部计数器不计最初一次 GA 生成；这一原始口径原样保留。

**宿主批量控制：**原始 REMO 可返回超过 6 个候选。为满足“其他部分与 Full 一样”，
宿主在真实评价前保留返回顺序的前 `min(nMax,候选数,剩余FE)` 个。
因此本版本是“Full 宿主中的原始 REMO 候选模块”，不是整个原始 REMO 算法。
在阈值分支中，原模块返回的是末代顺序；此处不增加新的排序或去重。
只有初始化和最后选中批次调用 `Problem.Evaluation`；内部 GA 接收决策矩阵，
生成候选不会消耗真实 FE。

## 原始源码身份与已知问题

私有 `RSurrogateAssistedSelection.m` 与清单记录的本地 REMO 源文件逐字节一致，
本次没有修正原始模块。原文件包含两个需要在实验说明中保留的实现细节：

- `scores=zeros(Next_num,2)`，评分写入第一列，第二列保持零。
- `Xi–C2` 累积项使用 `pre_XiC1(1)`，而非对应的 `pre_XiC2(1)`。

这是对**本地原始实现**的替换消融，不声称复现经索引修正后的关系公式。
若后续修正，建立另一独立版本；基准 REMO 与使用其模块的消融臂必须采用同一修正口径。
不要修改此私有副本后继续沿用已生成结果的身份。

## 验证

`tests/TestREMONoCDIS.m` 通过公共算法入口检查小预算结束点、逐轮 FE、批量限制、
低维初始化预算和参数错误。该测试使用定制 outputFcn，不保存正式实验结果。
源码清单、静态分析及运行记录放在 `diagnostics/`。
验证运行仅说明实现和预算控制通过，不提供最终 IGD+/HV 优势证据。

将算法目录加入 MATLAB 路径后，可重跑公共入口测试：

```matlab
algorithmDir = fileparts(which('REMO_NoCDIS_REMOSelection'));
results = runtests(fullfile(algorithmDir,'tests','TestREMONoCDIS.m'));
assert(all([results.Passed]));
```

本次验证结果：9 个 `.m` 文件静态检查无消息，6 个测试全部通过；
10/20 目标实际 FE 截断、每批上限和低维初始化预算均通过检查。

论文可将本版本标注为“w/o CDIS：保留 PAQC，候选模块恢复为本地 REMO 原始实现，
同时沿用 Full 的批量上限和真实评价预算截断”。论文和已有表格在本任务中不改动。
