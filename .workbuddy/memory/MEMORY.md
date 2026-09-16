# 项目长期记忆（PlatEMO PACDIS / AdaMaO 研究）

> 本文件只留最高频、最致命的条目；完整细节（环境、坑位、实验框架、数据集、论文）已归档到同目录 `REFERENCE.md`，需要时先读它。

## 现在在哪（截至 2026-09-16 08:30）
- 主线：**pMix 敏感性扫描 —— ✅ 已完成 1200/1200**（09-15 16:28 起两轮，累计约 10 h 50 min；第二轮 09-16 01:24→08:19 补完 761 跑）。全量校验通过（缺失 0 / 失败 0 / MAT-only / 无待机污染），IGD 已导出 `PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_pMixSweep\logs\pMix_finalIGD.csv`（1200 行）。
- **pMix 扫描的结论（可直接引用）**：pMix=0.50 是**最稳健的默认值**——12 个 (M,问题) 格中平均秩最低（2.621）、最差秩最小（3.00），合并 240 配对块 Friedman p<1e-6，且**显著优于 pMix=0.75（Holm p=0.030）与 pMix=1.00（Holm p=0.00036）**。**但不能说"处处最优"**：只在 2/12 格夺冠，且**与 pMix=0.25 无统计差异（Holm p=1.0）**。效应方向随问题翻转：DTLZ2/WFG3 偏好高 pMix，DTLZ7/WFG8 偏好低 pMix，**DTLZ7 最敏感（pMix=1 相对 0.5 差 +81%/+74%）**；pMix0 vs pMix1 合并 p=1.0（极端臂互补，故折中值平均秩占优）；**pMix=0 最危险**（DTLZ2 差 +30.9%）。完整表见该目录 `RESUME_STATUS.md` 第 9 节。
- 数据目录族 `D:\REMOandDREMO测试集\<M>目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030_pMix{000,025,050,075,100}`（M=20 无 n30 层）；巡检自动化 `87c95710-...` 已置 PAUSED（实验结束）。
- 固定参数序 `{gmax,pMix,rGood,qKeep,nMax}` = `{3000, 0.50, 0.25, 0.70, 6}`；默认 N=100、D=30、maxFE=300。
- 已完成：M=20 基线 320/320；Weighted WFG sweep M=15、M=8(D=10) 各 270/270。待办：Weighted M=5(D=10) 停在 159/270。
- 分工：**用户亲自跑重活，AI 负责开发/归档/自动化**；长任务先预估时长与排程间隔。

## 本机红线（违反就白跑/毁数据）
- Bash 每条命令首行必须：
  `export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"`
- **运行脚本/driver/日志一律放 `PlatEMO/Experiments/<实验名>/`（含 logs/）**；`tmp/` 会被用户随时清空（曾让 10 路 MATLAB 秒退）。
- **长跑前必须** `powercfg /change monitor-timeout-ac 0` + `standby-timeout-ac 0`，不合盖（本机 S0 Modern Standby，显示器关闭即冻结墙钟，09-15 吞掉 5.6 h）。
- 固定种子不能 `rng()`+`platemo()`（本地 platemo.m 会 `rng('shuffle')`）→ 直接构造 problem/algorithm，Solve 前 `rng(seed,'twister')`，模式流传 `'run',r`。
- **同一张对比表绝不能混用 maxNumCompThreads**（对 patternnet/fitrsvm 类算法非中性，会被模型驱动选择混沌放大）。
- Git：**严禁 `pull --rebase`**（0914 事故清空 refs/objects）；两台机器别并发操作同一 .git。
- MATLAB `-batch` 退出偶发 `0xc0000374`：发生在写盘后，数据安全；长跑配"守护+断点续跑"。
- Edit 偶发报成功但未落盘 → 关键编辑后 Read/Grep 复核。

## 常用口径
- 单跑 wall（M=20/D=30/N=100/maxFE=300，12 路 × threads=1）：DTLZ2≈420s、WFG1≈383s、WFG3≈377s、WFG8≈368s；**单跑成本几乎不随 M 变化**（M=10 ≈ 0.97×M=20）。
- 进程池利用率≈98% → 总墙钟 ≈ 切片数 × 65 min / 12（1200 跑 = 120 切片 ≈ 10.5 h）。
- 进度探针：`logs/stdout_<切片>.log`，行格式 `[done] <prob> run k | IGD A -> B | runtime Xs | wall Ys | ok`。
- 数据文件命名取自**算法类名**而非文件夹名 → 同算法不同参数的多臂靠文件夹区分，统计脚本模式串用类名。
- LaTeX：MiKTeX 25.12 + Strawberry Perl 已装好；中文目录下命令行编译须 `env -u LC_ALL -u LANG latexmk ...`（否则 Perl 写 .aux 失败）。详见 REFERENCE.md。
