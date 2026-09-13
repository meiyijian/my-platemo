# Weighted qKeep=0.70 独立运行入口

新算法名：`REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Q070`。

2026-09-12 从现有 Pruned_Weighted 复制全部 15 个运行源文件，仅修改入口类名及对应文件名。其余运行代码保持一致；核对记录见 `copy_verification.json`。未修改旧算法或历史数据，未启动实验。

默认参数按顺序为 `{3000,0.50,0.25,0.70,6}`，对应 gmax、pMix、rGood、qKeep、nMax。批次内权重仍为 0.75×关系得分＋0.25×距离。qKeep=0.70 是分位阈值，通常保留最高约 30% 的关系得分候选；仍可在界面覆盖，运行前请确认参数。

旧 Weighted 的默认值及上一轮实际配置也为 qKeep=0.70。本入口用于同参数重新运行，并非 qKeep 单因素对照。

在 PlatEMO 实验界面中选择带 `_Q070` 后缀的新算法。结果按新类名保存至独立子目录，不会加载旧 Weighted 类名下的结果。如果以后继续使用本新类名，其已保存结果仍会被正常复用。

原始数据根目录：`C:\Users\lsx\Desktop\REMOandDREMO测试集`。
结果汇总表根目录：`C:\Users\lsx\Desktop\AdaMao实验表`。

## 四题各 18 次批量运行

`RunQ070_18.m` 运行 DTLZ2、DTLZ5、DTLZ7、WFG7，各 18 次，共 72 次，六进程并行。设置 M=10、D=30、N=100、maxFE=300、保存参数 save=18，保存轨迹种群、最终种群、IGD、耗时和配置/种子元数据。每次独立写入上述原始数据根目录的 `10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Q070` 子目录，文件字段兼容 PlatEMO GUI。

运行编号用于文件编号；为沿用既有 GUI 行为，独立模式随机流仍使用回退编号 1。全局随机种子逐题逐次固定且不同，并写入 metadata。请勿将本轮与旧 GUI 的同编号结果假定为共同种子配对。

正常完成的同配置结果会在重启时跳过；不完整或不同配置的同名文件会报错，不会覆盖。单次失败写入算法目录内 `diagnostics/Q070_18runs`，其余已提交任务继续运行。指标计算失败时也先保存原始种群。

在 PowerShell 执行：

```powershell
$algorithmFolder = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Q070'
& 'D:\mathlab2023a\bin\matlab.exe' -logfile "$algorithmFolder\run_Q070_18.log" -batch "addpath('$algorithmFolder'); RunQ070_18"
```

2026-09-12 已通过入口、四题参数、72 个任务的配置检查与 MATLAB 解析检查。未启动正式优化运行或并行池。静态分析只提示固定类名可直接调用以及一个多余的未使用变量抑制标记，不影响执行。
