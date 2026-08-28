# Dual-PBI Decision Layer 实验

## 当前状态

- 状态：`PLANNING_ONLY`
- 是否允许运行：否
- 是否已实现算法或分析脚本：否
- 是否已创建结果目录：否
- 用户批准要求：必须先审阅并确认 `docs/DLD_EXPERIMENT_PLAN_CN.md`

本目录专门用于验证下面的决策层问题：

> 仅利用决策时刻已经可观测的信号，能否在未参与训练的问题配置上判断应选择方向视图、Anchor-derived 视图、固定混合，还是回退到冻结的原始 Hybrid？

本目录与已有互补性实验并列，避免把决策模型、闭环算法和新结果混入以下已冻结目录：

- `../DualPBI_Complementarity/`
- `../results/`
- `../../REMO_new2_AdaMaO_UniformMix_LabelValidation/`

## 当前文件

- `docs/DLD_EXPERIMENT_PLAN_CN.md`：详细研究问题、数据契约、留出方案、对照、统计方法、停止门槛和拟建目录。

## 范围约束

在用户批准前，本目录只允许保存规划文档，不允许：

- 修改冻结的 UniformMix/Hybrid 算法；
- 新增可执行 MATLAB 入口；
- 训练决策模型；
- 重放或启动任何 PlatEMO 搜索；
- 创建 `results/raw` 或写入实验结果；
- 根据试算结果修改 Primary 指标、留出划分或成功门槛。

## 批准后拟采用的目录

```text
DualPBI_DecisionLayer/
├─ README.md
├─ docs/
│  ├─ DLD_EXPERIMENT_PLAN_CN.md
│  ├─ DLD_PROTOCOL_LOCK.md
│  └─ DLD_DECISION_LOG.md
├─ config/
├─ builders/
├─ policy/
├─ algorithms/
├─ analysis/
├─ tests/
└─ results/
   ├─ feasibility/
   │  ├─ manifests/
   │  ├─ tables/
   │  ├─ models/
   │  └─ logs/
   ├─ screening/
   │  ├─ raw/
   │  ├─ analysis/
   │  ├─ manifests/
   │  └─ logs/
   └─ formal/
      ├─ raw/
      ├─ analysis/
      ├─ manifests/
      └─ logs/
```

现有 250 个互补性 MAT 文件始终作为只读数据源使用，不复制进本目录。新实验只保存来源清单、校验信息和派生表。
