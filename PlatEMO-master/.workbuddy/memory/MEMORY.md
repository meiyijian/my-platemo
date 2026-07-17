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
- 直连 GitHub 可用（ping 通，TLS 握手在禁用代理后成功）
- `git pull` 即使 fetch 成功也可能返回非零退出码，需检查 `git status`，必要时手动 `git merge --ff-only origin/master`

## 目录结构要点

- 算法代码：`PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly/`
- 设计文档：`PlatEMO/docs/superpowers/specs/`、`PlatEMO/docs/superpowers/plans/`
- 汇报文档：`REMO_DiRel_汇报文档.md`（项目根目录）
