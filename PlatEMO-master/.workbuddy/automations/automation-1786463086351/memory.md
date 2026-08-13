# Automation: 检查 Stage1 screening 实验进度

## 执行历史

### 2026-08-12 00:40（首次运行）
- 命令：`check_Stage1Progress('screening')` 运行成功
- 结果：Expected=100, Completed(valid)=31, Invalid=0, Pending=69（31% 完成）
- allDone=false，未触发分析器；仅简要报告
- 备注：screening 于 8/11 深夜启动，10 个并行 MATLAB 进程；按当前速率（~18 分钟/作业/进程）预计还需约 2 小时（约 02:30-03:00 完成）

### 2026-08-12 01:38
- 命令：`check_Stage1Progress('screening')` 运行成功
- 结果：Expected=100, Completed(valid)=70, Invalid=0, Pending=30（70% 完成）
- allDone=false，未触发分析器；简要报告
- 备注：较 00:40 新增 39 个有效作业（约 1.5 分钟/作业聚合速率，单进程约 15 分钟/作业，符合 8-14 分钟预期）；剩余 30 个，10 并行进程下预计 24-42 分钟完成（约 02:00-02:20）；当前系统有 21 个 MATLAB 进程运行

### 2026-08-12 02:37（完成 + 分析）
- `check_Stage1Progress('screening')`：Expected=100, Completed(valid)=**100**, Invalid=0, Pending=0 → allDone=**true**
- 触发分析器：`run_LabelMechanismSnapshotAudit` + `analyze_LabelMechanismSnapshotAudit`（equivalenceFile=equivalence_passed.txt=PASS）
- **首次运行报错**：analyze 第 110 行 `dirRows(end+1,:)=row` 尺寸不匹配（左侧 1×8，右侧 1×10）——不同 (problem,M,behavior) 组合的 FallbackReason 种类数不同导致。已修复：改为 cell 收集 + 统一补宽 + 动态生成 reasonN/countN 表头（详见 analyze_LabelMechanismSnapshotAudit.m 方向来源汇总段）
- 修复后运行成功：**Decision = PASS_TO_STAGE2**（100 valid、等价性 PASS、自适应覆盖≥50%，ND_KMEANS_below50pct=0）
- 关键结论：方向来源 KMEANS 自适应主导（18/20 组合 100%；DTLZ4 M20 回退 OBJECTIVE_RANGE_LT_1E12，DTLZ7 M10 Hybrid 回退 FRONT1_LT_THRESHOLD）；fallback 候选模式=0；模式 indicator≈32/explore≈35 代对半；每代均值 ~5.97 评估
- 产出：analysis 目录 7 个文件 + Stage1_screening_summary.md 汇总报告
- **实验全部完成，本自动化使命结束**：后续无需再执行进度检查（已 100%），若需归档到桌面 AdaMao实验表 由用户手动确认

### 2026-08-12 03:33（例行复查，无新工作）
- `check_Stage1Progress('screening')` 再次确认：Expected=100, Completed(valid)=100, Invalid=0, Pending=0 → allDone=true
- 分析结果文件验证完整（02:37 产出 7 个文件 + summary.md，equivalence_passed.txt 存在），无需重复运行分析器
- 向用户汇报最终状态；提醒可归档桌面 AdaMao实验表
- 建议：本自动化已无实际检查对象，可暂停/删除

### 2026-08-12 04:30（例行复查，无新工作）
- `check_Stage1Progress('screening')` 确认：Expected=100, Completed(valid)=100, Invalid=0, Pending=0 → allDone=true
- analysis 目录 7 文件 + Stage1_screening_summary.md 完整（02:36-02:37 时间戳），equivalence_passed.txt=PASS，不重复运行分析器
- 简要汇报最终状态 + 展示 summary 报告；提醒可归档
- 再次建议：本自动化已连续 3 次无新工作，建议暂停或删除

### 2026-08-12 05:26（例行复查，无新工作）
- `check_Stage1Progress('screening')` 确认：Expected=100, Completed(valid)=100, Invalid=0, Pending=0 → allDone=true
- analysis 目录 7 文件 + summary 完整（02:36-02:37 时间戳），equivalence_passed.txt 存在，不重复运行分析器
- 简要汇报最终状态；提醒可归档桌面 AdaMao实验表
- 建议：本自动化已连续 4 次（03:33/04:30/05:26…）无新工作，建议暂停或删除（可在配置中把 status 置为 PAUSED）

### 2026-08-12 06:22（例行复查，无新工作）
- `check_Stage1Progress('screening')` 确认：Expected=100, Completed(valid)=100, Invalid=0, Pending=0 → allDone=true
- analysis 目录 7 文件（02:36-02:37）+ summary 完整，equivalence_passed.txt 存在，不重复运行分析器
- 简要汇报最终状态 + 展示 summary 报告；提醒可归档桌面 AdaMao实验表
- 建议：本自动化已连续 5 次（03:33/04:30/05:26/06:22…）无新工作，强烈建议暂停或删除（status 置为 PAUSED）

### 2026-08-12 07:18（例行复查，无新工作）
- `check_Stage1Progress('screening')` 确认：Expected=100, Completed(valid)=100, Invalid=0, Pending=0 → allDone=true
- analysis 目录 7 文件（02:36-02:37）+ summary 完整，equivalence_passed.txt=PASS，不重复运行分析器
- 简要汇报最终状态 + 展示 summary 报告；提醒可归档桌面 AdaMao实验表
- 建议：本自动化已连续 6 次无新工作（00:40 完成使命后 03:33→07:18 连续 6 次空转），强烈建议暂停（status=PAUSED）或删除

### 2026-08-12 08:10（例行复查，无新工作）
- `check_Stage1Progress('screening')` 确认：Expected=100, Completed(valid)=100, Invalid=0, Pending=0 → allDone=true
- analysis 目录 8 文件（7 数据 + summary.md）完整（02:36-02:37），equivalence_passed.txt 存在，不重复运行分析器
- 简要汇报最终状态 + 展示 summary 报告；提醒可归档桌面 AdaMao实验表
- 建议：本自动化已连续 7 次无新工作（03:33→08:10），使命已于 02:37 完成，**强烈建议暂停或删除**（status 置为 PAUSED 即可，无需删除记录）
