# 上一个版本（Original 参数版）主性能表——恢复说明

## 来源

- git 标签：`paper-original-params-20260914`
- 对应提交：`f97f5d4af82de22ed816774f5c160f36c4868f3e`
- 原路径：`论文写作/experiments/main_performance/`
- 恢复时间：2026-09-14

本目录的 7 个文件与标签内容逐字节一致，未做任何修改。

## 与当前版本的区别

| 项目 | 本目录（上一个版本） | `../main_performance/`（当前版本） |
|---|---|---|
| 参照算法列 | `..._UniformMix_Original` | `..._UniformMix_Pruned_Weighted` |
| 源工作簿 | `AdaMao实验表\最新版算法总实验` | `AdaMao实验表\参数简化版本` 的 `pruned_weight*` |
| 表结构 | DTLZ 表 + WFG 表，每题 M=10/15/20 三行 | 同 |
| 六基线 | REMO、PIEA、CSEA、PC-SAEA、K-RVEA、MCEA/D | 同 |
| 数值 | 不同（算法参数不同） | 不同 |

## 注意

`table_dtlz.tex` 与 `table_wfg.tex` 中的标签 `tab:exp:dtlz`、`tab:exp:wfg` 与当前版本的同名。
两份**不能同时** `\input` 到同一篇正文，否则会出现重复标签。
需要在正文中切换时，只改 `HPDC-MaOEA.tex` 里两行 `\input` 的路径，不要同时引用。

## 重建

```powershell
python build_tables.py                       # 从本目录 igd_snapshot.csv 重建两张 TeX 表
python build_tables.py --source-dir <目录>   # 从源 Excel 重新提取（会更新 SHA-256，不修改 Excel）
```

`表格预览_上一个版本.html` 为本次生成的可读预览，直接从 `igd_snapshot.csv` 渲染，不参与 LaTeX 编译。
