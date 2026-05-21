# REMO_DiRel 双网络对比探针实验

## 实验目标

测试 REMO_DiRel 的双网络结构（全目标网络 `nets_F` + 子目标网络 `nets_S`）的效果：
1. 两个模型的预测是否冲突？冲突率多高？
2. 各模型的预测准确率如何？哪个更准？
3. 逆方差融合权重是否合理？是否自动选择了更准的模型？
4. 冲突场景下，哪个模型更可信？
5. 基于结果，推荐分阶段使用还是加权融合？

## 文件说明

| 文件 | 作用 |
|------|------|
| `REMO_DiRel_dualProbe.m` | 带探针的算法主类，每代记录详细数据 |
| `compute_dualnet_metrics.m` | 核心指标计算函数 |
| `run_dualnet_experiment.m` | 实验运行脚本 |
| `analyze_dualnet_results.m` | 结果分析、CSV输出、图表生成 |

## 运行方法

### 1. 运行实验
```matlab
cd PlatEMO/Experiments/REMO_DiRel_DualNetProbe
addpath(pwd);

% 完整实验（4问题 x 5run，约需1-2小时）
run_dualnet_experiment

% 快速测试（2run，maxFE=200）
run_dualnet_experiment('runs', 2, 'maxFE', 200)

% 只跑指定问题
run_dualnet_experiment('problems', {@DTLZ2, 3, 10}, 'runs', 3)
```

### 2. 分析结果
```matlab
analyze_dualnet_results              % 生成CSV和图表
analyze_dualnet_results('fig', false) % 只生成CSV，不画图
```

## 输出文件

### CSV 文件 (`output/`)

1. **`per_generation_summary.csv`** - 每代汇总
   - `p_err_F`, `p_err_S`: 两个模型的测试集错误率
   - `S_easy`: 选中的易目标子集

2. **`per_candidate_detail.csv`** - 每候选解详细数据
   - `mu_F`, `sigma2_F`: 全目标网络的预测均值和方差
   - `mu_S`, `sigma2_S`: 子目标网络的预测均值和方差
   - `w_F`: 融合权重（全目标网络权重）
   - `base_score`: 融合得分
   - `true_quality`: 真实质量标签（基于Pareto支配）
   - `conflict_type`: 冲突类型 (agree/conflict/abstain/subwin)

3. **`cross_problem_summary.csv`** - 跨问题汇总对比
   - 各问题的冲突率、准确率、权重分布等

4. **`conflict_analysis.csv`** - 冲突场景详细分析
   - 各冲突类型下的两模型准确率对比
   - 哪个模型在冲突时更准确

### 图表 (`output/figures/`)

1. **mu散点图**: mu_F vs mu_S，按冲突类型着色
2. **指标随代变化**: 准确率、冲突率、权重、一致性
3. **权重分布**: w_F 的直方图和与真实质量的关系
4. **冲突准确率**: 冲突场景下两模型的准确率柱状图
5. **选择分析**: 选择重叠和选择质量对比
6. **跨问题对比**: 所有问题的汇总对比柱状图

## 核心分析维度

### 维度1: 模型一致性
- **Sign Agreement**: sign(mu_F) == sign(mu_S) 的比例
- **Catalog Agreement**: PBI分类标签一致的比例
- **冲突率**: sign相反的比例（不含0）

### 维度2: 预测准确率
- 以Pareto支配为ground truth
- 各模型单独的准确率
- 冲突场景下谁更准

### 维度3: 融合效果
- 逆方差权重 w_F 的分布
- 权重是否自动偏向更准的模型
- 融合后是否优于单独模型

### 维度4: 选择影响
- 各模型单独选择 vs 融合选择的重叠度
- 被选中候选的真实质量对比

## 基于结果的建议

根据实验结果，可以从以下策略中选择：

### 策略A: 分阶段使用
- 前期（探索阶段）：只用全目标网络（信息完整）
- 后期（收敛阶段）：只用子目标网络（更精确）
- 切换时机：当冲突率超过阈值时

### 策略B: 自适应加权
- 保持逆方差融合，但调整权重公式
- 如果子目标网络在冲突时更准：增加 w_S 偏置
- 如果全目标网络更稳定：增加 w_F 偏置

### 策略C: 置信度门控
- 只在两个模型一致时才使用融合结果
- 冲突时：选择更确定的那个模型
- 双方都不确定时：fallback到GA

### 策略D: 保持现状
- 如果当前融合效果已经很好，无需修改
