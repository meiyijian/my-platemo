# AdaMaO 模式占比统计实验 — 使用说明

## 目的

统计 `REMO_new2_AdaMaO`（完整版 Full）每次运行中，两类自适应模式被选中的**次数及比例**：

1. **关系对模式** `relation_mode`：`conservative` / `curriculum` / `weighted`
2. **候选解模式** `candidate_mode`：`conservative` / `explore` / `indicator`

输出一张 CSV 表，每次实验运行为一行。

---

## 文件清单

所有文件都在算法目录下：

```
Algorithms/Multi-objective optimization/REMO_new2_AdaMaO/
├── REMO_new2_AdaMaO_Stat.m          ← 统计版算法（必须在此目录，被PlatEMO识别+复用同目录辅助函数）
└── notes/mode_stat/
    ├── run_mode_stat.m              ← 实验运行脚本（遍历问题×M×运行次数）
    ├── collect_mode_stat.m          ← 汇总CSV脚本（读.mat→算占比→写CSV）
    ├── smoke_test.m                 ← 最小冒烟测试（验证端到端）
    ├── stat_data/                   ← 正式实验的 .mat 输出目录（运行时自动填充）
    ├── stat_data_smoke/             ← 冒烟测试的 .mat 输出目录
    └── mode_distribution.csv        ← 最终CSV（collect后生成）
```

> **设计原则**：`REMO_new2_AdaMaO_Stat.m` 与原版 `REMO_new2_AdaMaO.m` 的优化逻辑**完全一致**，仅增加计数器与 `.mat` 保存。所有插桩点用 `%%% [STAT]` 注释标记，可对照审查。算法行为不受影响。

---

## 统计口径（重要，请先读）

| 量 | 含义 | 说明 |
|---|---|---|
| `total_gen` | 主循环代数 | 每进入一次循环体 +1，**含跳过轮** |
| `skip_gen` | 跳过轮数 | 关系对为空(`XXs`为空)被 `continue` 跳过的代数。此时代码里 `relation_mode` 已确定、`candidate_mode` 尚未确定 |
| `eval_gen` | 实际完成候选模式选择的代数 | `= total_gen - skip_gen` |

**占比分母约定**（已与你确认）：

- **关系对模式占比** 分母 = `total_gen`（每代都确定了 `relation_mode`，含跳过轮）
- **候选解模式占比** 分母 = `eval_gen`（跳过轮未选 `candidate_mode`，不计入）

这样两类模式的分母各自干净，且 `skip_gen` 单独成列可追溯。

---

## 如何运行

### 前置条件
- MATLAB（R2018a+，建议 R2020b+）
- PlatEMO 已在 `D:\PlatEMO-master\PlatEMO-master\PlatEMO`

### 第 0 步：冒烟测试（可选，建议先跑）

验证统计插桩没破坏算法、`.mat` 能正常生成。约 1–3 分钟。

```matlab
% 在 MATLAB 命令行
cd 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\mode_stat'
smoke_test
```

预期输出末尾打印 `冒烟测试通过。` 及两类模式的计数。

### 第 1 步：运行统计实验

```matlab
cd 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\mode_stat'
run_mode_stat
```

**默认配置**（与你确认的方案一致）：

| 配置项 | 默认值 |
|---|---|
| 问题集 | DTLZ1-7 + WFG1-9（共16个） |
| 目标维度 M | [10, 20] |
| 决策变量 D | 30 |
| 种群规模 N | 100 |
| 最大评估 maxFE | 300 |
| 每问题独立运行 | 10 次 |
| **总运行次数** | **16 × 2 × 10 = 320** |

每次运行约几十秒到几分钟（取决于问题与 M），320 次总计可能数小时。可先用小配置试跑：

```matlab
run_mode_stat('n_run',2, 'problems',{@DTLZ2,@WFG4}, 'M_list',[10])  % 只跑2问题×1个M×2次=4次
```

**全部可选参数**：

```matlab
run_mode_stat( ...
    'problems', {@DTLZ2,@DTLZ7,@WFG4}, ...  % 测试问题（默认DTLZ1-7+WFG1-9）
    'M_list', [10,20], ...                  % 目标维度（默认[10,20]）
    'D', 30, ...                            % 决策变量维度（默认30）
    'N', 100, ...                           % 种群规模（默认100）
    'maxFE', 300, ...                       % 最大评估次数（默认300）
    'n_run', 10, ...                        % 每问题运行次数（默认10）
    'reproducible', false, ...              % true则rng(runid)固定种子，可复现
    'stat_dir', '' ...                      % 自定义.mat输出目录（默认stat_data/）
)
```

运行过程中，进度会实时打印（`[  1/320] DTLZ1 M=10 run= 1 ... done (xx.xs)`）。

### 第 2 步：生成 CSV 汇总

```matlab
collect_mode_stat
```

会读取 `stat_data/` 下所有 `.mat`，计算占比，输出：

```
notes/mode_stat/mode_distribution.csv
```

并在命令行打印「按 问题×M 分组的平均模式占比」速览表。

---

## CSV 字段说明

| 字段 | 类型 | 说明 |
|---|---|---|
| `run_global` | int | 全局行号 1..N |
| `problem` | str | 问题名（如 DTLZ2） |
| `M` `D` `N` `maxFE` | int | 实验配置 |
| `final_FE` | int | 实际消耗的评估次数 |
| `total_gen` | int | 主循环代数（含跳过轮） |
| `skip_gen` | int | 关系对为空被跳过的代数 |
| `eval_gen` | int | = total_gen - skip_gen |
| `rel_conservative_cnt` | int | 关系对-保守模式 次数 |
| `rel_curriculum_cnt` | int | 关系对-课程学习模式 次数 |
| `rel_weighted_cnt` | int | 关系对-加权模式 次数 |
| `rel_conservative_ratio` | float | 关系对-保守占比（分母=total_gen） |
| `rel_curriculum_ratio` | float | 关系对-课程学习占比 |
| `rel_weighted_ratio` | float | 关系对-加权占比 |
| `cand_conservative_cnt` | int | 候选解-保守模式 次数 |
| `cand_explore_cnt` | int | 候选解-探索模式 次数 |
| `cand_indicator_cnt` | int | 候选解-指标模式 次数 |
| `cand_conservative_ratio` | float | 候选解-保守占比（分母=eval_gen） |
| `cand_explore_ratio` | float | 候选解-探索占比 |
| `cand_indicator_ratio` | float | 候选解-指标占比 |

---

## 两类模式的触发逻辑（速查）

### 关系对模式 `relation_mode`（主算法，按此优先级判定）

| 模式 | 触发条件 |
|---|---|
| `curriculum` | `prev_p_err > tau_err(0.35)`（上一代模型误差大） |
| `weighted` | `prev_p_err <= tau_err` 且 `mean_conf >= 0.55` 且 `coverage < 0.60` |
| `conservative` | 默认（以上都不满足） |

### 候选解模式 `candidate_mode`（主算法，按此优先级判定）

| 模式 | 触发条件 |
|---|---|
| `indicator` | `use_indicator` 且 `p_err <= tau_err` 且 `degeneracy >= 0.45` |
| `explore` | `p_err <= tau_err` 且 `coverage < 0.60` |
| `conservative` | 默认（以上都不满足） |

> 注意：两类模式的优先级顺序**相反**（关系对先判 curriculum，候选解先判 indicator）。

---

## 可追溯性

- 每个 `.mat` 文件名 = `<Problem>_M<M>_D<D>_run<runid>.mat`，与一次运行一一对应。
- `.mat` 内 `stat` 结构体除计数外，还保存 `rel_trace` / `cand_trace`（每代模式字符串轨迹），便于事后复盘某一代选了什么模式。
- `runid` 由 `platemo('run',r)` 设置，写入 `stat.runid`。
- 若需可复现：`run_mode_stat('reproducible',true)` 会对第 r 次运行用 `rng(r)`，同 runid 可复现。

---

## 常见问题

**Q: 为什么 WFG 只到 WFG9，没有 WFG10？**
A: PlatEMO 标准库无 WFG10 问题。若你有自定义 WFG10 问题文件，加入 `run_mode_stat` 的 `problems` 列表即可。

**Q: skip_gen 一般会是多少？**
A: 取决于问题与种群状态。正常情况下 `skip_gen` 很小或为 0（关系对极少为空）。若 `skip_gen` 偏大，说明分类器频繁把所有样本归为同类，值得排查。

**Q: 想看某一次运行的逐代模式轨迹？**
A: 直接 `load` 对应 `.mat`，看 `stat.rel_trace` 和 `stat.cand_trace`（cell 数组，每代一个字符串）。

**Q: 算法跑了但没生成 .mat？**
A: 检查环境变量 `ADAMAO_STAT_DIR` 是否设置（`run_mode_stat` 会自动设置）。也可手动 `setenv('ADAMAO_STAT_DIR','你的目录')` 后直接调 `platemo`。
