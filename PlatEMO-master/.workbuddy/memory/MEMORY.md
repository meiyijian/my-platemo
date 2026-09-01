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
- `Algorithms/NeuroEA/`：2026-08-29 从官方 v4.16 同步进来的新分类（9 文件，与本地 `Algorithms/Blocks` 重名，已隔离到 private）

## PlatEMO 版本与上游同步（2026-08-29）

- 本地为 PlatEMO **v4.12**（GUI.m 中写死），官方 BIMK/PlatEMO 已到 **v4.16**；框架文件差异多为版权年份，**不要整体升级 GUI/框架**
- 已同步官方新增 35 个多目标算法 + NeuroEA + 单目标 MiSACO/SSIO-RL；多目标目录 358 → 393
- `ESBCEO` = 官方 `ESB-CEO`（官方改名），本地保留原名，勿重复引入

### 铁律：往 Algorithms/ 加新算法前必须做重名隔离

- `platemo.m` 用 `addpath(genpath(cd))`，MATLAB 按**文件名**解析、且不看调用者目录 → 字典序靠前的目录会遮蔽后面所有同名 .m
- 新增目录中凡与既有目录重名的 .m，一律移入该目录自己的 `private/`（genpath 跳过 private，private 对父目录优先级最高）
- 惨痛案例：`MaOEA-HAP/Shape_Estimate.m` 是 4 参数版，会抢占 PIEA / REMO_new2_AdaMaO 等的两参数版调用，直接报错
- 验收标准：隔离后「新增目录在全局路径上的重名 .m 文件数 = 0」，且主类文件（classdef < ALGORITHM）必须留在顶层以便 GUI 发现
- 完整流程与踩坑记录见 `.workbuddy/memory/2026-08-29.md`

## Stage1 标签机制审计实验状态（2026-08-12 更新）

- 实验根目录：`PlatEMO/Experiments/REMO_new2_AdaMaO_UniformMix_LabelValidation/`
- 进度检查：`check_Stage1Progress('screening')`；聚合/分析：`run_LabelMechanismSnapshotAudit` / `analyze_LabelMechanismSnapshotAudit`
- **screening（100 作业）已完成并分析：Decision = PASS_TO_STAGE2**（100 valid、等价性 PASS、自适应覆盖≥50%）
  - 方向来源：KMEANS 自适应主导（≥90%，多数 100%）；仅 DTLZ4 M20（OBJECTIVE_RANGE_LT_1E12）与 DTLZ7 M10 Hybrid（FRONT1_LT_THRESHOLD）有少量回退
  - 候选模式：fallback=0，indicator/explore 约对半；每代 ~5.97 评估
  - 结果与汇总报告：`results/stage1/screening/analysis/`（含 Stage1_screening_summary.md）
- 遗留提醒：分析器曾修 bug（方向来源汇总列宽不匹配，已修复）；用户可归档实验到桌面「AdaMao实验表」文件夹；Stage1 通过后可启动 Stage2
