# REMO_UniformMix_Pruned_Weighted_Lambdat030

从 Lambda020 源码独立复制。全程固定 lambda_t=0.30，不随FE衰减，不使用误差门控；公开参数只有 gmax,pMix,rGood,qKeep,nMax，默认 {3000,0.50,0.25,0.70,6}。不接受第六个奖励参数。

探索分支仍先按原始关系得分R的0.70分位筛选。在保留集合内归一化R和预测模糊度U，使用 A=R_norm+0.30*U_norm。首个点取A最大，其余按0.75*归一化A+0.25*归一化批内最小距离贪心选择。ratio字段只供诊断分阶段使用，不控制奖励强度。

PAQC、关系模型、候选生成、指标分支、环境选择、剩余真实FE截断均沿用来源版本。原目录和历史结果不修改，新目录不包含旧实验数据。

运行准备：把本目录加入MATLAB路径，执行 RunLambdat030_10('check')。正式执行 RunLambdat030_10('run',2)，或双击 StartLambdat030_10.cmd。预设沿用原脚本：DTLZ2/4/5/7，M=10，D=30，N=100，maxFE=300，runId=19:28；新版本40次和同环境Weighted对照40次，共80次。实现任务只进行小预算验证，不自动启动正式实验。

结果单独写入桌面 REMOandDREMO测试集/10目标/n30/REMO_UniformMix_Pruned_Weighted_Lambdat030。analyze_lambdat030分析该新目录；诊断字段lambdaT应始终为0.30。保留来源脚本的已有文件跳过规则，正式复用前须确认已有文件完整。

验证：Lambdat030Test 的7项测试通过。探索模式与请求指标模式的小预算运行均结束于实际FE=107；清单检查为80项待跑，无正式实验启动。tests/validation.log保存验证结果。
