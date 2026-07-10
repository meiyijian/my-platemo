# 第二轮实验：10 次运行 + 逐代诊断量

> 研究演进节点：在第一轮（`mode_stat/`，3 次，仅模式计数）发现 6 大问题后，
> 本轮补足统计意义并记录触发模式的诊断量，用于验证阈值假设。

## 本轮要验证的 3 个假设（来自第一轮报告）

1. **DTLZ4/7 在 M=20 为何是 explore 而非 indicator？**
   假设：`degeneracy < 0.45`（阈值未满足）。本轮直接记录 degeneracy 逐代值验证。
2. **curriculum 触发时 p_err 是否真的高？**
   假设：仅 gen1 因 prev_p_err 初值=1 触发，p_err 其实未算（NaN）或不高。
3. **weighted 触发时 coverage 是否真的低？**
   假设：coverage < 0.60 满足。本轮直接记录 coverage 逐代值验证。

## 与第一轮的区别

| 项 | 第一轮（mode_stat/） | 第二轮（experiment_round2/） |
|---|---|---|
| 运行次数 | 3 次/问题 | **10 次/问题** |
| 记录内容 | 模式计数 + 轨迹 | 模式计数 + 轨迹 **+ 逐代诊断量** |
| 诊断量 | 无 | p_err, prev_p_err, coverage, degeneracy, mean_conf |
| 总运行数 | 48 | **160**（8问题×2M×10次） |
| CSV | 1 份（模式分布） | **2 份**（模式分布 + 逐代诊断） |
| 数据目录 | mode_stat/stat_data/ | experiment_round2/stat_data/ |

**两轮数据完全独立，互不覆盖。** 第一轮数据保留在 `mode_stat/`，本轮在 `experiment_round2/`。

## 文件清单

```
notes/experiment_round2/
├── run_round2.m                    ← 运行脚本（10次，M=[10,20]，跑完自动生成CSV）
├── collect_round2.m                ← 汇总脚本（生成2份CSV）
├── stat_data/                      ← .mat 输出目录（运行时填充）
├── mode_distribution_r2.csv        ← 模式占比汇总（160行，同第一轮格式）
├── diagnostics_r2.csv              ← 逐代诊断量（每行一代，约5440行）
└── README_round2.md                ← 本说明
```

> 注：算法文件 `REMO_new2_AdaMaO_Stat.m` 已升级（增加 `stat.diag_trace` 字段），
> 升级是向后兼容的——第一轮的旧 .mat 没有该字段，不影响读取。

## 如何运行

```matlab
% 在 MATLAB 命令行
cd 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round2'

run_round2                        % 默认：10次，M=[10,20]，跑完自动生成2份CSV
run_round2('n_run',5)             % 先跑5次（约3.3小时）
run_round2('reproducible',true)   % 固定种子，可复现
```

**预计耗时**：160 次运行 × 约 5 分钟/次 ≈ **13 小时**。建议：
- 先跑 `run_round2('n_run',3)` 验证流程（约4小时）；
- 确认无误后跑完整 10 次，可挂着过夜。

## CSV 字段说明

### mode_distribution_r2.csv（与第一轮格式完全一致，便于对比）

22 列：run_global, problem, M, D, N, maxFE, final_FE, total_gen, skip_gen, eval_gen,
rel_{conservative,curriculum,weighted}_{cnt,ratio}, cand_{conservative,explore,indicator}_{cnt,ratio}

### diagnostics_r2.csv（新增，逐代诊断量）

| 字段 | 说明 |
|---|---|
| run_global | 全局行号 |
| problem | 问题名 |
| M | 目标维度 |
| run_id | 同问题同M内的运行编号 |
| gen | 代数（1,2,3,...） |
| p_err | 当代模型测试误差（跳过轮记 NaN） |
| prev_p_err | 决定 relation_mode 的上一代误差 |
| coverage | 参考向量覆盖率（<0.60 触发 weighted/explore） |
| degeneracy | 种群退化度（>=0.45 触发 indicator） |
| mean_conf | 平均置信度（>=0.55 且 coverage<0.60 触发 weighted） |
| relation_mode | 该代关系对模式（conservative/curriculum/weighted） |
| candidate_mode | 该代候选解模式（conservative/explore/indicator/skipped） |

## 向老师汇报的要点（研究演进）

1. **第一轮**（3次，仅模式）：发现 curriculum 名存实亡、候选模式一次性锁定、DTLZ4/7 反常等 6 大问题。
2. **第二轮**（10次，+诊断量）：补足统计意义，并直接记录触发模式的诊断量，验证阈值假设——这是从"发现问题"到"定位根因"的关键一步。
3. 两轮数据独立存放，可清晰展示研究递进过程。
