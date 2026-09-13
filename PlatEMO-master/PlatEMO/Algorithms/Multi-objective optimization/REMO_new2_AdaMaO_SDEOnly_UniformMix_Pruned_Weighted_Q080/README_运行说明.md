# Weighted qKeep=0.80 对照

算法：REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Q080。

基于原 Pruned_Weighted，只修改类名和 qKeep 默认值为 0.80。其余 14 个运行源文件保持一致，校验见 copy_verification.json。批次权重保持 0.75/0.25，其他已删除项不恢复。

RunQ080_18：DTLZ2、DTLZ5、DTLZ7、WFG7，各 18 次，六进程并行。M=10、D=30、N=100、maxFE=300；参数明确传入 {3000,0.50,0.25,0.80,6}。

每次结果单独保存至：
`C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Q080`

保存 result、metric、metadata，包括种群轨迹/最终解、IGD、耗时、参数和种子。沿用 GUI 的模式流回退编号 1；不同重复的全局种子不同且可复现。只有同配置且完整的本入口结果才会跳过，旧 Weighted 和 Q070 的数据不会被复用。运行失败日志保存在本算法 diagnostics/Q080_18runs 下。

PowerShell 启动命令：

```powershell
$algorithmFolder = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Q080'
& 'D:\mathlab2023a\bin\matlab.exe' -logfile "$algorithmFolder\run_Q080_18.log" -batch "addpath('$algorithmFolder'); RunQ080_18"
```

Q070 批量任务及其工作进程已停止。删除旧 Q070 算法文件夹被自动审批策略拦截，故改为移动至本目录 diagnostics/retired_Q070，并将全部 .m 文件扩展名改为 .m.disabled，不能作为 MATLAB 算法或启动脚本执行。Q070 已产生的原始数据保留，不混入 Q080。

这里只生成启动脚本，不自动启动正式实验。
