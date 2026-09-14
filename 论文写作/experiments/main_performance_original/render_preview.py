"""Render a light-theme HTML preview of the two main-performance tables.

Source of truth is igd_snapshot.csv (recovered from git tag
paper-original-params-20260914). Nothing is re-derived: means, standard
deviations and statistical symbols are copied verbatim.
"""
import csv
import html
from collections import Counter
from decimal import Decimal
from pathlib import Path

HERE = Path(__file__).resolve().parent
ORDER = ["REMO", "PIEA", "CSEA", "PC-SAEA", "K-RVEA", "MCEA/D", "PACDIS"]
LABEL = {"MCEA/D": "MCEA/D", "PC-SAEA": "PC-SAEA", "K-RVEA": "K-RVEA"}
MS = [10, 15, 20]
SUITES = [("DTLZ", [f"DTLZ{i}" for i in range(1, 8)]), ("WFG", [f"WFG{i}" for i in range(1, 10)])]

with (HERE / "igd_snapshot.csv").open(encoding="utf-8-sig", newline="") as f:
    records = list(csv.DictReader(f))
assert len(records) == 336, len(records)
lookup = {(r["problem"], int(r["M"]), r["algorithm"]): r for r in records}
assert len(lookup) == 336

CSS = """
:root{--ink:#1f2328;--muted:#57606a;--line:#d0d7de;--shade:#d9d9d9;--head:#f3f4f6;}
*{box-sizing:border-box}
body{margin:0;padding:28px 30px 60px;background:#ffffff;color:var(--ink);
 font-family:"Microsoft YaHei","Segoe UI",system-ui,sans-serif;font-size:13px;line-height:1.45;}
h1{font-size:19px;margin:0 0 6px;font-weight:700;}
h2{font-size:16px;margin:34px 0 4px;font-weight:700;}
p.meta{margin:0 0 14px;color:var(--muted);font-size:12.5px;}
table{border-collapse:collapse;width:100%;margin-top:8px;table-layout:fixed;}
th,td{border-top:1px solid var(--line);border-bottom:1px solid var(--line);
 padding:5px 4px;text-align:center;vertical-align:middle;font-variant-numeric:tabular-nums;}
thead th{background:var(--head);border-top:1.2pt solid #1f2328;border-bottom:1.2pt solid #1f2328;
 font-weight:700;}
th.prob,td.prob{width:64px;font-weight:600;text-align:center;border-right:1px solid var(--line);}
th.mcol,td.mcol{width:34px;color:var(--muted);border-right:1px solid var(--line);}
td .mean{display:block;font-family:Consolas,"Courier New",monospace;font-size:12.5px;}
td .sd{display:block;font-family:Consolas,"Courier New",monospace;font-size:12.5px;color:var(--muted);}
td.best{background:var(--shade);}
td.best .mean,td.best .sd{font-weight:700;color:var(--ink);}
tr.sep td{border-top:1.2pt solid #8b949e;}
tr.total td{border-top:1.2pt solid #1f2328;border-bottom:1.2pt solid #1f2328;
 font-family:Consolas,"Courier New",monospace;font-weight:600;}
tr.total td.lbl{font-family:inherit;font-style:italic;font-weight:600;}
td.pacdis,th.pacdis{border-left:1px solid var(--line);}
.note{color:var(--muted);font-size:12px;margin-top:6px;}
"""

parts = [
    "<!DOCTYPE html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>上一个版本（Original 参数版）主性能两张表</title><style>" + CSS + "</style></head><body>",
    "<h1>上一个版本（Original 参数版）主性能两张表</h1>",
    "<p class=\"meta\">参照算法 <code>REMO_new2_AdaMaO_SDEOnly_UniformMix_Original</code>（正文记作 PACDIS）｜"
    "六基线：REMO、PIEA、CSEA、PC-SAEA、K-RVEA、MCEA/D｜N=100，FE<sub>max</sub>=300｜"
    "问题 DTLZ1&ndash;7、WFG1&ndash;9｜M=10/15/20｜数据取自 git 标签 <code>paper-original-params-20260914</code>，"
    "源工作簿 <code>AdaMao实验表\\最新版算法总实验</code>。</p>",
]

for suite, problems in SUITES:
    totals = {}
    for a in ORDER[:-1]:
        c = Counter(lookup[p, m, a]["symbol"] for p in problems for m in MS)
        totals[a] = [c["+"], c["-"], c["="]]
    parts.append(f"<h2>表 {1 if suite == 'DTLZ' else 2}　{suite}1&ndash;{len(problems)} 上的 IGD 比较</h2>")
    parts.append("<table><thead><tr><th class=\"prob\">Problem</th><th class=\"mcol\">M</th>"
                 + "".join(f"<th class=\"{'pacdis' if a == 'PACDIS' else ''}\">{LABEL.get(a, a)}</th>" for a in ORDER)
                 + "</tr></thead><tbody>")
    for i, p in enumerate(problems):
        for j, m in enumerate(MS):
            lowest = min(Decimal(lookup[p, m, a]["mean"]) for a in ORDER)
            cells = []
            for a in ORDER:
                r = lookup[p, m, a]
                best = Decimal(r["mean"]) == lowest
                sym = f" {r['symbol']}" if r["symbol"] else ""
                cls = "best" if best else ""
                cells.append(
                    f"<td class=\"{cls}{' pacdis' if a == 'PACDIS' else ''}\">"
                    f"<span class=\"mean\">{html.escape(r['mean'])}</span>"
                    f"<span class=\"sd\">({html.escape(r['std'])}){sym}</span></td>")
            row_cls = " class=\"sep\"" if (j == 0 and i) else ""
            prob_cell = (f"<td class=\"prob\" rowspan=\"3\">{p}</td>" if j == 0
                         else "")
            parts.append(f"<tr{row_cls}>{prob_cell}<td class=\"mcol\">{m}</td>" + "".join(cells) + "</tr>")
    parts.append("<tr class=\"total\"><td class=\"lbl\" colspan=\"2\">+ / &minus; / =</td>"
                 + "".join(f"<td>{'/'.join(map(str, totals[a]))}</td>" for a in ORDER[:-1])
                 + "<td class=\"pacdis\">&mdash;</td></tr>")
    parts.append("</tbody></table>")
    parts.append("<p class=\"note\">每格上行是均值，下行括号内是标准差。灰底加粗表示该行七个算法中的最低均值。"
                 "符号是该基线相对 PACDIS 的导出结果：<code>+</code> 基线更优、<code>&minus;</code> 基线更差、"
                 "<code>=</code> 未检出差异；末行按 <code>+ / &minus; / =</code> 顺序统计。"
                 "符号为源工作簿导出，未由均值与标准差重新推断。</p>")

parts.append("</body></html>")
(HERE / "表格预览_上一个版本.html").write_text("\n".join(parts), encoding="utf-8")

for suite, problems in SUITES:
    line = " | ".join(
        f"{a} " + "/".join(str(x) for x in [Counter(lookup[p, m, a]['symbol'] for p in problems for m in MS)['+'],
                                            Counter(lookup[p, m, a]['symbol'] for p in problems for m in MS)['-'],
                                            Counter(lookup[p, m, a]['symbol'] for p in problems for m in MS)['=']])
        for a in ORDER[:-1])
    print(suite, "->", line)
print("wrote 表格预览_上一个版本.html")
