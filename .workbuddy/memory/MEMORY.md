# 项目长期记忆（PlatEMO PACDIS / AdaMaO 研究）

> 本文件只留最高频、最致命的条目；完整细节（环境、坑位、实验框架、数据集、论文）已归档到同目录 `REFERENCE.md`，需要时先读它。

## 现在在哪（截至 2026-09-15 23:58）
- 主线：**pMix 敏感性扫描** —— 判定指标分支概率是否真有贡献，支撑论文创新性论证。
- 数据目录族 `D:\REMOandDREMO测试集\<M>目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030_pMix{000,025,050,075,100}`；框架在 `PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_pMixSweep\`。
- 进度 **439/1200（全在 M=20），用户已要求暂停**；续跑命令+进度表+坑说明见该目录 `RESUME_STATUS.md`；对应巡检自动化已置 PAUSED，续跑时改回 ACTIVE。剩 761 跑 ≈ 7 h。
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
