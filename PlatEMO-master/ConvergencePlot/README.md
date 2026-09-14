# ConvergencePlot

从已保存的 PlatEMO 结果文件里直接画收敛曲线（convergence curves），**不需要重跑实验**。

## 为什么不用重跑

PlatEMO 在 `ALGORITHM.m` 里每代调用一次 `NotTerminated`，把当时的种群写进 `result`，
并按 `save` 指定的份数保留快照：

```
index = max(1,min(min(num,size(obj.result,1)+1),ceil(num*pro.FE/pro.maxFE)));
obj.result(index,:) = {obj.pro.FE,Population};      % num = abs(save)
```

所以只要运行时给了 `'save',K`，结果文件里就同时有：

| 变量 | 含义 |
| --- | --- |
| `result{k,1}` | 第 k 个快照时的函数评价次数（FE） |
| `result{k,2}` | 第 k 个快照时的种群（`SOLUTION` 对象） |
| `metric.IGD` | **逐快照的 IGD 轨迹**，长度与快照数一致 |
| `metric.runtime` | 总运行时间 |

`metric.IGD` 就是收敛曲线本身，`result(:,1)` 就是横坐标。本项目的主实验
（`RunPaperWeighted30.m`）用 `'save',30` 并把 `CalMetric('IGD')` 的结果存进文件，
因此 564 + 480 个 `.mat` 全部自带 30 点（或 18 点）的收敛轨迹。

## 文件

| 文件 | 作用 |
| --- | --- |
| `PlotConvergenceCurves.m` | 单张图：一个测试问题、多个算法，画中位数曲线 + IQR 阴影带 |
| `PlotConvergenceGrid.m` | 多问题拼图（默认 4×4），并导出每个问题的单图 |
| `demo_Convergence_10obj.m` | 现成示例：10 目标 / D=30 / 16 题 / REMO vs Weighted，输出 PNG + 终值对照表 |

## 用法

```matlab
cd D:\PlatEMO-master\PlatEMO-master
addpath(genpath('PlatEMO')); addpath('ConvergencePlot')

% 一键出全部图 + 终值表
demo_Convergence_10obj

% 或者单张图
PlotConvergenceCurves('DTLZ1', ...
    'dataRoot','C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30', ...
    'algorithms',{'REMO','REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'}, ...
    'labels',{'REMO','AdaMaO-W'},'metric','IGD','M',10,'maxFE',300);
```

常用可调项：

| 参数 | 说明 |
| --- | --- |
| `metric` | `'IGD'`（默认）、`'IGDp'`，或文件里存的任意指标字段 |
| `M` | 目标个数，用于拼文件名 |
| `runs` | 用哪些 run，默认 `1:30` |
| `maxFE` | 横轴上限，默认 300 |
| `gridStep` | 公共 FE 网格步长，默认 1 |
| `logY` | 纵轴取对数，默认 `true` |
| `showFinal` | 图例里附带终值中位数，默认 `true` |
| `colors` / `labels` | 配色 / 图例名 |
| `outputDir` / `fileTag` / `formats` | 导出目录 / 文件名前缀 / `{'png','pdf'}` |

## 三个实现要点

1. **横轴对齐**：不同算法、不同 run 的快照 FE 并不一致（REMO 到 303，Weighted 到 300）。
   所有 run 统一重采样到 `0:gridStep:maxFE` 网格，用 **零阶保持**（`interp1(...,'previous')`）——
   IGD 只在写入快照那一刻改善，两点之间应当保持前值，不能线性插值。
2. **统计口径**：画中位数曲线并叠加 25%–75% 分位带；分位数逐列丢弃 NaN，
   避免某个 run 尚未开始的位置被当成劣值拉偏。
3. **终值两套口径**：`finalMedian` 是 FE=300 处的中位数（与图右边缘一致）；
   `finalSnapshotMedian` 是各 run 自己最后一次快照值的中位数，与论文表格口径一致。
   REMO 末次快照有时落在 FE=303，两者会略有差别，报告时注意统一。

## 注意

- 结果文件里 `metric.HV` 在部分算法下全是 0（参考点未适配高维），**别用 HV，用 IGD**。
- PlatEMO 的 `IGD.m` 算的是 `Population.best.objs`（best-so-far 档案）到真实前沿的 IGD，
  不是末代种群。两个算法口径一致，比较是公平的，但写论文时要说明。
- `save` 决定曲线分辨率上限：每代最多存 1 个快照，所以 `save` 大于总代数没有意义。
  `maxFE=300, N=100` 时 REMO 大约 34 代，`save`,30 已接近上限。
