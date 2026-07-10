# REMO_new2_AdaMaO_SimpleA 说明

## 定位
`AdaMaO-SimpleA` 是 `AdaMaO-Simple` 的**单因素消融变体**，唯一目的：**验证 `gmax`（代理模型内部 GA 迭代预算）是否为简化版退化的元凶**。

## 相对 Simple 的唯一改动
| 项 | Simple | SimpleA |
|---|---|---|
| 代理内部 GA 迭代预算 | `wmax = N*ceil(log2(N+1))` = 700 (N=100) | `wmax = 3000`（恢复完整版） |

其余所有机制**完全与 Simple 一致**：
- 外部参数仍为 2 个：`[use_indicator, debug]`
- `k` 内生化 `ceil(1.5*M)`、覆盖感知批量（替代 n_min/n_max）、`model_gain` 替代 `lambda0/p_err/0.45`、`w_min` 删除、`q_keep` 删除
- 关系对始终软置信权重（删除模式切换）、`coverage_gap=1-coverage` 连续控制
- 指标子系统 `use_indicator`（默认开）、`degeneracy>=0.45` 触发阈值原样保留

## 如何解读实验结果
跑完 M=10（指标 dormancy，最能暴露损伤）与 M=20 后，比较 **SimpleA vs Simple**：
- 若 SimpleA 性能 ≈ Full、且明显优于 Simple → **gmax 是元凶**，恢复 gmax=3000 即可（外部参数仅增加 1 个）。
- 若 SimpleA 仍 ≈ Simple（未追平 Full）→ gmax 不是主因，需继续回退「关系模式切换」与「探索权重」。

## 命名与文件
- 主类：`REMO_new2_AdaMaO_SimpleA`（与文件名一致）
- 辅助函数：与 Simple 文件夹完全相同（20 个 .m）
- 对照：**Simple**（全削减）↔ **SimpleA**（仅恢复 gmax）↔ **Full / REMO_new2_AdaMaO**（原始 10 参数）
