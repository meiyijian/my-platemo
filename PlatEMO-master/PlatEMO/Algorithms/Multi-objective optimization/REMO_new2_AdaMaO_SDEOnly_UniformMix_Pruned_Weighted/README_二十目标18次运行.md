# Weighted 二十目标全系列

运行入口 RunWeightedM20_18；算法 REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted。

- DTLZ1–7、WFG1–9，各 18 次，共 288 次。
- M=20，N=100，请求 D=30，maxFE=300。使用问题类的实际 D，WFG2/3 自动调整为 31。
- 明确传入参数 {3000,0.50,0.25,0.70,6}，即 qKeep=0.70。没有修改算法逻辑。
- 六进程并行。每次独立保存种群轨迹、最终种群、IGD、运行耗时和参数/种子元数据。
- 保存至 C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted。
- 已完整保存且配置匹配的本轮结果会跳过；不完整或不匹配的同名文件会报错，不会覆盖。每次结果先保存种群，再计算 IGD。
- 固定并记录每题每次的全局随机种子。模式流编号沿用 GUI 的回退编号 1，不将历史同编号运行当作共同种子对照。
- 失败信息保存在本算法 diagnostics/Weighted_M20_18runs 下。

PowerShell：

```powershell
$algorithmFolder = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'
& 'D:\mathlab2023a\bin\matlab.exe' -logfile "$algorithmFolder\run_Weighted_M20_18.log" -batch "addpath('$algorithmFolder'); RunWeightedM20_18"
```

本次只生成并检查配置，不自动启动正式实验。
