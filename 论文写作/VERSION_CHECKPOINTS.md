# 论文版本与回退

## 原始参数版本（用户于2026-09-14指定的修改前版本）

- 固定标签：`paper-original-params-20260914`
- 对应提交：`f97f5d4af82de22ed816774f5c160f36c4868f3e`
- 创建标签时工作区干净；标签保留修改前论文、Original主性能表、配套图件及其来源文件。
- 算法身份：`REMO_new2_AdaMaO_SDEOnly_UniformMix_Original`。
- 今后用户要求“回退到原始参数版本”，默认指此标签。

## PAQC为第一贡献的Weighted版（2026-09-14）

- 算法身份：`REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted`。
- 方法：PAQC为主要贡献；CDIS为辅助策略；探索分支为质量引导的批次分散选择，关系质量预筛选后以0.75质量+0.25批内距离贪心选批次。
- 删除方法中不属于该实现的模糊度奖励、误差门控、nMin、指标二次分位筛选；同步主伪代码和框架图。
- 主性能：参数简化版本目录下三张pruned_weight工作簿，M=10/15/20；六基线与PACDIS全部随源表更新。
- 实验结构：主性能、PAQC×CDIS消融、k控制、GGP、pMix、收敛曲线。只有主性能已有结果，其余保留设计与TODO。
- 未修改MATLAB算法、未运行正式优化实验、未覆盖源Excel。

## 安全回退方式

按用户要求恢复论文范围并产生新提交，不使用整仓库hard reset。恢复前检查现有差异并保存后续未提交修改。

```powershell
git restore --source paper-original-params-20260914 -- '论文写作/HPDC-MaOEA.tex' '论文写作/experiments/main_performance' '论文写作/figures/figure_framework.tex' '论文写作/figures/build_framework_flowchart.py' '论文写作/figures/fig_framework.pdf' '论文写作/figures/fig_framework.svg' '论文写作/figures/fig_framework.png' '论文写作/figures/qa/fig_framework_flowchart.json' '论文写作/figures/qa/fig_framework_render.png' '论文写作/figures/manifest.json'
```

主论文PDF为未跟踪的编译产物，由恢复后的TeX重新生成。随后编译两遍，检查差异，提交并推送恢复结果。本版本说明应保留并记录回退动作。若未来相关路径增加，先核对变更清单再补充恢复，避免恢复无关文件。

## 本次核对

- 336个数据格逐项对照源Excel；TeX表中全部均值和标准差与快照一致；源Excel的SHA-256保持不变。
- PAQC数学、命题及PAQC伪代码与原始标签逐字核对一致；修改集中在贡献定位、CDIS、实验及框架图。
- 六项实验小节均已加入，未完成的五项均有明确待补说明。
- 主论文两遍编译及图表视觉检查；待补作者、摘要/相关工作、RSEA文献信息及实验元数据等原有TODO仍保留。
