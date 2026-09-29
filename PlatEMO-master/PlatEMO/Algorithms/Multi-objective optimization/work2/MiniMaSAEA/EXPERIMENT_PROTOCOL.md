# MiniMaSAEA 第一层阶段实验（2026-09-29）

## 固定配置

- 目标数：`M = 3, 5, 8, 10`。`M=3` 用作低目标数锚点。
- 每题使用当前 PlatEMO 类的默认 `D`；运行器构造问题后读取实际 `Problem.D`，不传入 `D`。
- `N=100`，总真实评价上限 `maxFE=300`，每个“模式 × 问题 × M”运行 10 次。
- 四个模式：`PBI`、`TCH`、`SDE`、`OBJ`。前三者用一个相同配置的 DACE GP；
  `OBJ` 对每个归一化目标建一个同配置 GP，并对预测向量用 PBI 选点。
- 候选生成、GP 配置、一次选一个点的预测值预筛选均由同一份算法代码实现。
  初始化也计入 300 FE，实际初始数为 `min(11D−1,100,150)`。
- 协议版本 `v2`：候选和 GP 训练输入按变量范围归一化后以 `1e-12` 精度去重。
  这是处理 DACE 不接受重复设计点的固定规则，四模式一致适用；此前失败的
  `SDE/DTLZ2/M3/run06` 是触发该规则的回归测试。
- 配对种子：`20260929 + M×100000 + 问题序号×1000 + runId`。
  问题序号固定为下表顺序，四模式共用同一种子和参考向量抽取序列。
- 主指标为当前 PlatEMO `IGDp.m` 对最终可行非支配存档的 IGD+，
  参考集来自该问题对象的 `GetOptimum(10000)`。同时保存原始决策、目标、约束、
  30 个左右的 FE 快照、参考集、真实 FE、种子、运行时间与源码 SHA-256。
  不在本阶段计算 Monte Carlo HV。

## 预先固定的问题清单

| 顺序 | 阶段 | 问题 | 选择原因 | D (M=3/5/8/10) |
| ---: | --- | --- | --- | --- |
| 1 | 开发 | DTLZ2 | 平滑、球形前沿基线 | 12 / 14 / 17 / 19 |
| 2 | 开发 | DTLZ4 | 强偏置的变量到前沿映射 | 12 / 14 / 17 / 19 |
| 3 | 开发 | WFG3 | 退化的线性前沿 | 12 / 14 / 17 / 19 |
| 4 | 开发 | WFG4 | 多峰距离变换 | 12 / 14 / 17 / 19 |
| 5 | 留出 | DTLZ1 | 线性前沿与多峰收敛困难 | 7 / 9 / 12 / 14 |
| 6 | 留出 | DTLZ7 | 不连通前沿 | 22 / 24 / 27 / 29 |
| 7 | 留出 | WFG2 | 不连通前沿和不同 WFG 变换 | 12 / 14 / 17 / 19 |
| 8 | 留出 | WFG5 | 欺骗性距离变换 | 12 / 14 / 17 / 19 |

开发集和留出集各 `4×4×4×10=640` 个作业，总计 1280 个。
先分析开发集，再只使用已经冻结的判断检查留出集；不要根据开发结果更换留出题。
这是阶段性证据，不把 10 次运行描述成正式的 20 次实验。

## 结果位置与运行

结果根目录：`C:\Users\lsx\Desktop\AutoSAEA`。
单次结果示例：

```text
AutoSAEA/
  manifest.csv
  MiniMaSAEA_PBI/DTLZ2/M03/D12/FE300/run_001.mat
  MiniMaSAEA_TCH/DTLZ2/M03/D12/FE300/run_001.mat
  MiniMaSAEA_SDE/DTLZ2/M03/D12/FE300/run_001.mat
  MiniMaSAEA_OBJ/DTLZ2/M03/D12/FE300/run_001.mat
```

在 MATLAB 加载 PlatEMO 路径后调用：

```matlab
RunMiniMaSAEAStage('probe')             % DTLZ2/M3/run 1 的四模式完整 FE300 测速
RunMiniMaSAEAStage('regression')        % 曾失败的 SDE/DTLZ2/M3/run 6
RunMiniMaSAEAStage('development','max') % 本机 Processes 配置的最大进程数；可重启
RunMiniMaSAEAStage('validation','max')  % 留出集
RunMiniMaSAEAStage('check')         % 核对文件和元数据
```

运行器只跳过元数据和源码 SHA-256 都匹配的已完成文件；冲突文件会失败，
不会静默覆盖。每个失败作业在目标文件旁写 `.error.txt`。
早期 v1 已完成结果保存在 `_superseded_v1/`，不与 v2 混用。
