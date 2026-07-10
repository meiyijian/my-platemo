---
name: platemo-algo-port
summary: 将第三方/旧版 PlatEMO 算法适配到当前安装的 PlatEMO 版本，定位并修复“SOLUTION 输入参数不足”“函数或变量未定义”“OperatorGA 参数错误”等典型接口不兼容报错。
description: >
  当用户把从论文/仓库下载的算法（如 HES-EA、各类 SAEA）放进 PlatEMO 的
  Algorithms 目录后运行报接口错误时使用。覆盖 2025 版 PlatEMO 与旧版之间
  最常见的三类不兼容：(1) SOLUTION 构造必须带 (PopDec,PopObj,PopCon) 或用
  Problem.Evaluation；(2) OperatorGA 第一个参数必须是 Problem；(3) 算法自带
  的辅助函数若放在子目录里不会被自动加入路径。
---

# 将旧版/第三方 PlatEMO 算法适配到当前版本

当用户报告在 PlatEMO 上运行某算法报错（常见：`错误使用 SOLUTION 输入参数的数目不足`、
`未定义函数或变量 'xxx'`、`OperatorGA` 参数错误、`fetchNext 函数计算已完成，但有错误`），
按以下清单逐项排查。这些是新版（2025）PlatEMO 与旧版算法代码之间最高频的接口差异。

## 排查清单（按出现概率排序）

### 1. SOLUTION 不能以“只传决策变量”的方式构造
- **现象**：`SOLUTION(decMatrix)` 报“输入参数的数目不足”。
- **原因**：2025 版 `SOLUTION` 构造签名是 `SOLUTION(PopDec,PopObj,PopCon,PopAdd)`，
  内部 `if nargin>0` 后直接访问 `PopObj(i,:)`/`PopCon(i,:)`，未传参即抛此错。
- **修复**：需要评估时用 `Problem.Evaluation(PopDec)` 代替。
  - 初始种群：`Population = Problem.Evaluation(PopDec);`
  - 注入/新解：`PopNew = Problem.Evaluation(NewArc); Population = [Population,PopNew];`
- 注意：`Problem.Evaluation` 会自动累加 `Problem.FE`（昂贵算法评估预算据此统计），
  比手写 `SOLUTION(dec,obj,zeros(...))` 更稳妥。

### 2. OperatorGA 的第一个参数必须是 Problem
- **现象**：`OperatorGA(ArcDec)` 报参数不足或行为异常。
- **签名**：`function Offspring = OperatorGA(Problem,Parent,Parameter)`。
- **修复**：`OffDec = OperatorGA(Problem, ArcDec);`
- 当 `Parent` 是决策变量矩阵时，返回的是未评估的矩阵（符合要求）。

### 3. 算法自带辅助函数若放在子目录里，不会被自动加路径
- **现象**：报 `未定义函数或变量 'dacefit' / 'dsmerge' / 'predictor' / ...`。
- **原因**：`ALGORITHM.Solve` 只执行 `addpath(fileparts(which(class(obj))))`，
  即只把算法自身目录（如 `HES-EA/`）加入路径；其下的子目录（如 `GP model/`）不会自动加入。
- **修复**：在 `main` 开头加：
  ```matlab
  addpath(fullfile(fileparts(mfilename('fullpath')),'GP model'));
  ```
  也可直接把辅助 .m 文件移到算法根目录（同样能进路径）。

### 4. 其它常见接口差异（顺带核对）
- `UniformPoint(N,M,'Latin')` 返回 `[W,N]`，用 `[W,~]=...` 取点即可，'Latin' 选项本版支持。
- `NDSort(F,inf)` 返回 `[FrontNo,MaxFNo]`，`[front,~]=NDSort(F,inf)` 正确。
- `Problem.N` 在本版是“种群规模/population size”，不是约束数；`Problem.M`=目标数，`Problem.D`=变量数。
- 昂贵算法通常带 `<expensive>` 标记，依赖 Statistics and Machine Learning Toolbox
  的 `fitcknn`、`kmeans`、`pdist2`、`predict`、`acos`——若报这些未定义，是缺工具箱而非代码错。

### 5. 余弦/角度聚类在“解落在理想点”时崩溃（M 越小越易触发）
- **现象**：`HES_EA/main` 抛 `数组索引必须为正整数或逻辑值`；目标数少（如 5 目标）崩，多（如 10 目标）正常。
- **根因**：聚类用 `acos(1-pdist2(ClObj,ClW,'cosine'))` 选最近簇心。当某解在选中的若干目标上
  恰好等于理想点时，`NormObj` 该行为 0 向量，余弦距离=NaN，`min` 永远选不到它 → 该解簇标签
  保持初值 `inf` 未分配 → `fitcknn` 把 inf 当类别训练 → `predict` 返回 `Inf` → `Model_c{Inf}`
  cell 索引报错。目标数少 ⇒ 单解同时在多个目标达理想的概率更高 ⇒ 更易复现。
- **修复**：把“未分配且为零向量行”的 NaN 角度置为 `pi`（最远），使其仍被分配到合法簇；
  已分配行（设为 Inf）仍 NaN 被 min 跳过。簇标签初值用 `0`，循环后全部赋为 1..KMeans。
  ```matlab
  ang = acos(min(1,max(-1,1-pdist2(ClObj,ClW(i,:),'cosine'))));
  ang(isnan(ang) & ~isinf(ClObj(:,1))) = pi;
  [~,loc] = min(ang);
  ```
- 该修复对“无零向量行”的情形（如十目标）是纯 no-op，不改结果。

### 6. infill 的 kmeans 空簇崩溃
- **现象**：`kmeans(ArcDec,5)` 在 ArcDec 集中时空簇 → 默认 `EmptyAction='error'` 直接报错，
  或 `find(clus==i)` 为空 → `randperm(0,1)` 报错。
- **修复**：`kmeans(ArcDec,5,'EmptyAction','singleton')`，并对空簇/空前沿 `continue`。
  对无空簇情形是 no-op。

## 标准修复流程
1. 读 `Algorithms/<类别>/<算法名>/<算法名>.m` 的 `main`，定位所有 `SOLUTION(...)` 调用点（常在第 1 次循环构造初始种群、以及注入新解两处）。
2. 把单参 `SOLUTION(X)` 改为 `Problem.Evaluation(X)`。
3. 全文搜 `OperatorGA(`，确认第一个参数是 `Problem`。
4. 若算法目录含子目录且主文件直接调用其中的函数，在 `main` 开头 `addpath` 该子目录。
5. 若算法跑通后“目标数少才崩、目标数多正常”，重点查余弦/角度聚类（见第 5 条）。
6. 用廉价测试问题（如 `DTLZ2`，`M=3,D=10` 与 `M=5` 都跑一遍）小预算验证；再上昂贵问题。

## 验证限制
本机若无 MATLAB 运行环境，只能做代码审查级验证：核对被调用函数签名与
`Problems/SOLUTION.m`、`Problems/PROBLEM.m`、`Algorithms/Utility functions/OperatorGA.m`、
`UniformPoint.m`、`NDSort.m` 一致即可，无法实跑。
