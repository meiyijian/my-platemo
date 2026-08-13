# 项目长期备忘 (MEMORY.md)

## 项目概况

- PlatEMO 项目（进化多目标优化平台），fork 自 https://github.com/meiyijian/my-platemo.git
- 主要开发语言：MATLAB
- 工作目录：`D:\PlatEMO-master\PlatEMO-master`
- 当前主要工作：REMO_new2_AdaMaO 系列算法及其 SDE-only 变体、候选模式消融实验

## Git / 网络配置备忘

- 远程仓库：`origin` → https://github.com/meiyijian/my-platemo.git（HTTPS 协议）
- 默认分支：`master`
- **代理陷阱**：git 全局配置了代理 `http://127.0.0.1:7897`（Clash 端口），但该代理常未运行，会导致 `git pull/push/fetch` 报 TLS 错误
  - 临时绕过：`git -c http.proxy= -c https.proxy= pull origin master`
  - 彻底解决：`git config --global --unset http.proxy && git config --global --unset https.proxy`
- 2026-08-11 实测：直连 GitHub 与走代理（7897）均在 TLS 握手阶段失败（error:0A000126 / schannel failed to receive handshake），疑似 Clash 节点失效或被墙；git 同步需在能正常联网的终端进行（当前沙箱环境无法连通）
- `git pull` 即使 fetch 成功也可能返回非零退出码，需检查 `git status`，必要时手动 `git merge --ff-only origin/master`

## 目录结构要点

- 算法代码：`PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/`
- 设计文档：`PlatEMO/docs/superpowers/specs/`、`PlatEMO/docs/superpowers/plans/`
- 汇报文档：`REMO_DiRel_汇报文档.md`（项目根目录）

## Stage1 标签机制审计实验状态（2026-08-12 更新）

- 实验根目录：`PlatEMO/Experiments/REMO_new2_AdaMaO_UniformMix_LabelValidation/`
- 进度检查：`check_Stage1Progress('screening')`；聚合/分析：`run_LabelMechanismSnapshotAudit` / `analyze_LabelMechanismSnapshotAudit`
- **screening（100 作业）已完成并分析：Decision = PASS_TO_STAGE2**（100 valid、等价性 PASS、自适应覆盖≥50%）
  - 方向来源：KMEANS 自适应主导（≥90%，多数 100%）；仅 DTLZ4 M20（OBJECTIVE_RANGE_LT_1E12）与 DTLZ7 M10 Hybrid（FRONT1_LT_THRESHOLD）有少量回退
  - 候选模式：fallback=0，indicator/explore 约对半；每代 ~5.97 评估
  - 结果与汇总报告：`results/stage1/screening/analysis/`（含 Stage1_screening_summary.md）
- 遗留提醒：分析器曾修 bug（方向来源汇总列宽不匹配，已修复）；用户可归档实验到桌面「AdaMao实验表」文件夹；Stage1 通过后可启动 Stage2
