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

## 标准修复流程
1. 读 `Algorithms/<类别>/<算法名>/<算法名>.m` 的 `main`，定位所有 `SOLUTION(...)` 调用点（常在第 1 次循环构造初始种群、以及注入新解两处）。
2. 把单参 `SOLUTION(X)` 改为 `Problem.Evaluation(X)`。
3. 全文搜 `OperatorGA(`，确认第一个参数是 `Problem`。
4. 若算法目录含子目录且主文件直接调用其中的函数，在 `main` 开头 `addpath` 该子目录。
5. 用廉价测试问题（如 `DTLZ2`，`M=3,D=10`）小预算先跑通验证；再上昂贵问题。

## 验证限制
本机若无 MATLAB 运行环境，只能做代码审查级验证：核对被调用函数签名与
`Problems/SOLUTION.m`、`Problems/PROBLEM.m`、`Algorithms/Utility functions/OperatorGA.m`、
`UniformPoint.m`、`NDSort.m` 一致即可，无法实跑。
