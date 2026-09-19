# 项目详细坐标（MEMORY.md 的展开版）

> 本文件是 `MEMORY.md` 的详情备份，专放逐条实验坐标与论文资产细节。
> 主文件只留「长期有效的规则 + 索引」；需要具体路径/参数/结论时读本文件。

## λ 与「执行上下文敏感性」
- `Lambda020`：`A_t = R~ + λ0(1−FE/FEmax)U~`；λ0=0 与基线**逐位等价**
- **同源码同种子在不同线程数下结果不同**（client 6 线程 vs parpool 1 线程）→ 跨会话结果不能逐位配对；新实验必须**同会话同池同种子**
- runId 占用：六个 baseline 与 Pruned_Weighted = 1–30；Original = 1–18；Lambda020 = 19–28
- **λ 不是有效旋钮**（2026-09-15 配对实验，DTLZ2/4/5/7 全不显著）：λ 增大只放大既有差异（DTLZ7 优势与 DTLZ4 劣势同时被放大），别再调 λ，除非先上 n≥25
- 跨臂比较**先统一 runId 集合再算**（混用 18/20/30 跑会改结论）

## GoodGroupPrecision（GGP）实验坐标
- 三臂同协议（N=100、请求 D=30、maxFE=500、25 跑、种子 `problemIndex*10000 + M*100 + run`、视图 {`score_hybrid`,`score_v`,`anchor_margin`} × 真值 {`population_h1/h3/final`,`front_h1/h3/final`} × 4 阶段 × top25 配额）：
  - A `Experiments\REMO_new2_AdaMaO_GoodGroupPrecision`：10 题 × M10/20 = 500 跑（qKeep 0.80、lambda0 0.35）；结论文档在 `results\analysis\formal\expansion_audit_20260906\`（「新增数据集分析」「复算补充」两篇）
  - B `Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision`：DTLZ2/4/5 × M10/20 = 150 跑（qKeep 0.70、λ_t=0.30）；跨臂脚本 `compare_LTGGP_vs_PWGGP.m`
  - C PWGGP（λ_t=0.50）**原始目录已丢失**，只剩 B 的 `results\analysis\crossArm\LTGGP_vs_PWGGP_Paired.csv`（40 行，无逐 run 值）
- 核心结论（写论文用）：hybrid 相对 `score_v` 的优势**只在 `population_*` 真值上为正**，`front_*` 上为负 → 聚合口径胜格率只有 42–43%，与主口径逐阶段表（hybrid−v 在 S1 最强后单调衰减）看似矛盾，必须显式交代真值族
- A 反例：WFG 四题 excess −10.46 pp（池化 10 问题 −1.43 pp），B 未覆盖 → B 的「结论类似」不能给 A 的 WFG 反例背书
- λ 维度：λ0.30 的 IGD 更好但 hybrid Precision 全面更低 → 「标签质量」与「最终 IGD」反向，与「视图排序质量与最终 IGD+ 无显著关联」同源
- 对拍报告归档：`AdaMao实验表\GoodGroupPrecision_跨版本对拍\`；脚本 `.workbuddy\run_scripts\ggp_cross_version_compare{,2}.py`

## NoBatchDict 模块消融（noCDIS / noPAQC）坐标
- 两臂 `REMO_noBatchDict_noCDIS`（去 CDIS 留 PAQC）、`REMO_noBatchDict_noPAQC`（去 PAQC 留 CDIS），都继承 `..._Lambdat030_NoBatchDist`（= 论文里的 PACDIS），k 固定 1.5M
- 用户口径（2026-09-18）：**20 跑/格**、DTLZ1–7+WFG1–9、D=30（WFG2/3 实际 31）、N=100、maxFE=300、save=30、种子 `20260912 + M*1e5 + 1000*题号 + run`（M10 基数 21260912 / M20 基数 22260912）、**线程 1**
- 结果：`10目标\n30\<算法>` 与 `20目标\<算法>`（20目标为扁平结构）；**RMEO 基准 = `REMO_k15`(M10) / `REMO_k`(M20)**
- **原调度器 `Experiments\REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries\` 已丢失**（Experiments/ 被 .gitignore 排除）→ 用 `.workbuddy\run_scripts\RunNBD_Ablation{,All}.m` 重建
- **协议复现法（复用价值高）**：用同一 runner 跑 full 的任一 run，比对存量 `.mat` 的**第 1 个快照 IGD**（FE=100 = 初始 LHS）。命中 ⇒ 种子公式与「造 Problem 前 rng(seed)」接线正确；后续快照发散属项目已承认的「同环境同 seed 轨迹仍不一致」，统计一律用**非配对 rank-sum**
- **基线 `REMO_k15`/`REMO_k` 只有 IGD、没有 IGDp**，表格要用 IGDp 必须先 `MergeIGDpForDir.m` 补算并 `save(...,'metric','-append')` 合并
- 两臂耗时 ≈ full 的 1.07×；M10 单臂 320 跑 ≈ 35.5 CPU·h，M20 ≈ 32.3 CPU·h；5 workers
- **实测速率（2026-09-19 完成十目标后）：整块 640 跑 / 8.4 h = 76 跑/h（5 workers）**；单臂均摊 noCDIS 311.6 s/跑、noPAQC 371.7 s/跑。用存量 full 的 `metric.runtime` 均值反推会低估到 ≈42 跑/h（那些 runtime 含当时的机器争用）⇒ **估 ETA 用「已完成跑数 ÷ 已耗时」反推**
- **十目标结果（IGDp，n=20，非配对 rank-sum，α=0.05）**：锚点 = `REMO (k=15)` 时 full **14/1/1**、w/o CDIS 9/1/6、w/o PAQC 10/1/5；锚点 = full 时 REMO(k=15) 1/14/1、w/o CDIS 2/6/8、w/o PAQC 1/4/11
  - 可写论文：**full 对 REMO(k=15) 14 胜 1 负 1 平 ⇒ 两模块合计是实质提升，收益不能只归因于 k**
  - 模块都有条件贡献（去 CDIS 6 题变差：DTLZ2/4/5、WFG2/8/9；去 PAQC 4 题变差：DTLZ6/7、WFG2/8）
  - **反例集中退化前沿**：去 CDIS 反而在 **DTLZ6、DTLZ7** 显著更好；去 PAQC 只在 WFG3 更好；WFG3 上 full 反而最差（与主表 WFG3 是 PACDIS 弱项一致）
- **M=20 块用户已搁置**；恢复命令 `RunNBD_AblationAll(5,20)` → `FinishNBD_Ablation(20)` → `build_nobatchdict_tables.py`
- ⚠️ **MATLAB→JSON 传二维 cell 必须先 `strjoin` 成行字符串**：`jsonencode` 会把 16×4 cell 按**列主序压平**成一维字符串数组，下游按 `cell[p][a]` 取值就变成取字符（症状：表头/计数行正常、数据行全是单个字符，极隐蔽）。改结构体字段的表示形式后，所有引用点（含 `fprintf` 打印循环）都要一起改
- 表格口径：锚点在**末列不带符号**，`+`显著更好/`-`显著更差/`=`不显著（p≥0.05），行最小值蓝色 `FF3333E9`
- 工具链（`.workbuddy\run_scripts\`）：`RunNBD_Ablation.m`(run/smoke/post) + `RunNBD_AblationAll.m`(workers,Ms) 跑实验；`MergeIGDpForDir.m` 补 IGDp；`FinishNBD_Ablation.m`(Ms) 收尾（覆盖率守卫 + 补 IGDp + 出 JSON）；`build_nobatchdict_tables.py` JSON→xlsx；`progress_nbd.py [M]` 进度+ETA
  - 收尾出 **2 张 xlsx**：`nobatchdict以RMEO为基准十目标IGDp.xlsx`、`nobatchdict以full为基准十目标IGDp.xlsx`（列集合相同，只有符号锚点不同；锚点末列不带符号）
  - M=20 的 JSON 不存在时出表脚本会跳过（正常，不算错）
  - 巡检自动化已于 09-19 删除（十目标完成后无用途；留着每 3 h 白跑、还会重复生成文件）

## 论文资产
- 主文 `论文写作\HPDC-MaOEA.tex`（`elsarticle [final,5p,times,twocolumn]`，**textwidth = 522pt**）；`HPDC-MaOEA_1param.tex` 与主文**共用**主性能表两张 tex
- 主性能表不内联（`\input{experiments/main_performance/table_dtlz|table_wfg}`），数据只能由 `build_tables.py --source-dir <xlsx>` 生成（换源只改脚本 `OURS`/`FILES`）；正文数字全部派生自同目录 `summary.json`，必须一起改并重验定性断言 → skill `paper-main-table-refresh`
- 中文对照稿 `HPDC-MaOEA_中文版.md`（跟 tex 走，整篇覆盖；全部表格一律脚本转：主性能表用 `run_scripts/tex_table_to_md.py`，消融表与内联 p_mix 表用 `run_scripts/tex_ablation_pmix_to_md.py`）→ skill `paper-cn-mirror`
- §4.6 收敛图：`figures/build_convergence.py` ← `figures/source_data/convergence_igd.csv`（由 `ExportConvergenceCSV.m` 只读导出）
- 通用收敛曲线工具（不重跑）：`ConvergencePlot\{PlotConvergenceCurves,PlotConvergenceGrid,demo_Convergence_10obj}.m` + `README.md`；曲线 = `metric.IGD`，横轴 = `cellfun(@(v)v(1),result(:,1))`。**前提是跑实验时 `save=K>0`**（`ALGORITHM.m:122-124` 存快照、`:191-206` 才落盘；默认 `save=-10` 只弹 GUI 单条曲线、不写文件）
- 曲线图两种版式：默认（log 轴 + IQR 带）与**论文风格**（线性轴 + 稀疏 marker 折线 + Times + 左下图例 + 无标题，靠 `gridStep=20` + `markers` + `showBand=false` + `fontName` + `legendLocation` 实现，见 `README.md`「论文风格版式」）；范例 `.workbuddy\run_scripts\PlotConvergencePaperStyle.m`。导出前必须 `ax.Toolbar.Visible='off'`（否则工具栏入图）
- **论文 §4.6 收敛图正式版**：`figures/build_convergence.py` 一次产出 **6 张单面板图** `fig_convergence_<prob>_m<M>.{pdf,svg,png}`（88×66mm，论文用 `\includegraphics[width=0.485\textwidth]` 排 3×2）＋合并总览 `fig_convergence.*`（论文不引用）；横轴 `XMIN=95`（各算法首个快照：CSEA 109 / MCEA-D 30–65 / 其余 100）；marker 必须与 MATLAB 版一致 `REMO ^ / PIEA o / CSEA * / PC-SAEA s / K-RVEA x / MCEA-D + / PACDIS 实心 D`；**图例靠纵轴上方预留空白带（`pad_top=0.42`）承载**，四角都会被曲线压住。tex 侧浮动阈值 `topfraction/bottomfraction/textfraction/floatpagefraction` 必须在 `\begin{document}` **之后**设置（elsarticle 会重置），否则 Table 4 与图会被拆成两张半空浮动页
- 表格宽度：7 列 + 5 个数值列在 522pt 下必然超宽 → `\footnotesize` + 缩短 `\multicolumn` 标签 → skill `paper-tex-section-edit`
- 算法目录：`Lambdat030`（= 论文里的 PACDIS）、`Lambdat050`、`Lambda020`、`RMEO_k_CDIS`（原版 REMO 框架 + CDIS，`k=min(N,max(6,ceil(1.5M)))`，16 题 × M=10/20 × 18 跑已齐）
- 文档：`REMO_DiRel_汇报文档.md`；设计文档 `PlatEMO/docs/superpowers/{specs,plans}/`
