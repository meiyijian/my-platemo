# -*- coding: utf-8 -*-
"""Side-by-side comparison of qKeep=0.80 vs qKeep=0.70 Pruned full-series runs."""
import os
import re
import numpy as np
import scipy.io as sio
from scipy import stats

D080 = r"D:\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080"
D070 = r"D:\REMOandDREMO测试集\10目标\n30\REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned"
OUT = r"D:\PlatEMO-master\tmp\qkeep080_final_report"
PROBLEMS = ["DTLZ1", "DTLZ2", "DTLZ3", "DTLZ4", "DTLZ5", "DTLZ6", "DTLZ7",
            "WFG1", "WFG2", "WFG3", "WFG4", "WFG5", "WFG6", "WFG7", "WFG8", "WFG9"]
PAT = re.compile(r"^(?P<alg>.+?)_(?P<pro>[A-Za-z0-9\-]+)_M(?P<m>\d+)_D(?P<d>\d+)_(?P<run>\d+)\.mat$")


def collect(d):
    out = {}
    for f in os.listdir(d):
        if not f.lower().endswith(".mat"):
            continue
        m = PAT.match(f)
        if not m:
            continue
        g = m.groupdict()
        data = sio.loadmat(os.path.join(d, f), struct_as_record=False, squeeze_me=True)
        igd = np.atleast_1d(np.asarray(data["metric"].IGD, dtype=float)).ravel()
        out[(g["pro"], int(g["run"]))] = float(igd[-1])
    return out


a = collect(D080)
b = collect(D070)
print(f"qKeep080 valid={len(a)}  qKeep070 valid={len(b)}")

rows = []
for p in PROBLEMS:
    va = np.array([a[(p, r)] for r in range(1, 19)])
    vb = np.array([b[(p, r)] for r in range(1, 19)])
    diff = va - vb                      # negative => 0.80 better
    try:
        w, pw = stats.wilcoxon(va, vb)
    except Exception:
        w, pw = np.nan, 1.0
    rows.append({
        "Problem": p,
        "qKeep080_mean": va.mean(), "qKeep080_std": va.std(ddof=1),
        "qKeep070_mean": vb.mean(), "qKeep070_std": vb.std(ddof=1),
        "diff_(080-070)": diff.mean(),
        "pct_change_%": diff.mean() / vb.mean() * 100.0,
        "better": "qKeep=0.80" if diff.mean() < 0 else "qKeep=0.70",
        "wins080": int((diff < 0).sum()), "wins070": int((diff > 0).sum()),
        "wilcoxon_p": pw, "W": w,
    })

# Holm correction across the 16 problems
ps = np.array([r["wilcoxon_p"] for r in rows])
order = np.argsort(ps)
m = len(ps)
adj = np.empty(m)
prev = 0.0
for k, idx in enumerate(order):
    val = min(1.0, (m - k) * ps[idx])
    prev = max(prev, val)
    adj[idx] = prev
for r, av in zip(rows, adj):
    r["holm_p"] = av
    r["sig_0.05"] = "yes" if av < 0.05 else "no"

# per-run ranks (1 = better) then average rank per problem
ranks080, ranks070 = [], []
for p in PROBLEMS:
    va = np.array([a[(p, r)] for r in range(1, 19)])
    vb = np.array([b[(p, r)] for r in range(1, 19)])
    # rank across the 36 pooled runs, then average per algorithm
    pooled = np.concatenate([va, vb])
    rk = stats.rankdata(pooled)
    ranks080.append(rk[:18].mean())
    ranks070.append(rk[18:].mean())

mean_rank080 = float(np.mean(ranks080))
mean_rank070 = float(np.mean(ranks070))
n_win080 = sum(1 for r in rows if r["better"] == "qKeep=0.80")
n_sig080 = sum(1 for r in rows if r["better"] == "qKeep=0.80" and r["sig_0.05"] == "yes")
n_sig070 = sum(1 for r in rows if r["better"] == "qKeep=0.70" and r["sig_0.05"] == "yes")

# Wilcoxon on the 16 problem means (paired)
wm = stats.wilcoxon([r["qKeep080_mean"] for r in rows], [r["qKeep070_mean"] for r in rows])
# Friedman across the 16 problems using per-run IGD as repeated measures
fr_stat, fr_p = stats.friedmanchisquare(*[[r["qKeep080_mean"], r["qKeep070_mean"]] for r in rows])

print("\n--- Side by side (final IGD, lower is better) ---")
hdr = f"{'Problem':<8}{'0.80 mean':>12}{'0.80 std':>11}{'0.70 mean':>12}{'0.70 std':>11}{'diff':>11}{'%':>9}  {'better':<11}{'W p':>8}{'Holm p':>9}"
print(hdr)
print("-" * len(hdr))
for r in rows:
    print(f"{r['Problem']:<8}{r['qKeep080_mean']:>12.6f}{r['qKeep080_std']:>11.6f}"
          f"{r['qKeep070_mean']:>12.6f}{r['qKeep070_std']:>11.6f}"
          f"{r['diff_(080-070)']:>11.6f}{r['pct_change_%']:>9.2f}  "
          f"{r['better']:<11}{r['wilcoxon_p']:>8.4f}{r['holm_p']:>9.4f}")

print(f"\n0.80 better on {n_win080}/16 problems (Holm-significant: {n_sig080}); "
      f"0.70 better on {16-n_win080}/16 (significant: {n_sig070})")
print(f"mean rank (1=best): 0.80 -> {mean_rank080:.3f} | 0.70 -> {mean_rank070:.3f}")
print(f"Wilcoxon on 16 problem means: W={wm.statistic:.1f}, p={wm.pvalue:.4f}")
print(f"Friedman(2 configs x 16 problems): chi2={fr_stat:.4f}, p={fr_p:.4f}")

import pandas as pd
os.makedirs(OUT, exist_ok=True)
xlsx = os.path.join(OUT, "qkeep080_vs_070_comparison.xlsx")
with pd.ExcelWriter(xlsx, engine="openpyxl") as xw:
    pd.DataFrame(rows).to_excel(xw, sheet_name="per_problem", index=False)
    pd.DataFrame({
        "metric": ["win_count_080", "win_count_070", "holm_sig_080", "holm_sig_070",
                   "mean_rank_080", "mean_rank_070",
                   "wilcoxon_16means_p", "friedman_p"],
        "value": [n_win080, 16 - n_win080, n_sig080, n_sig070,
                  mean_rank080, mean_rank070, wm.pvalue, fr_p],
    }).to_excel(xw, sheet_name="overall", index=False)
print(f"\nxlsx -> {xlsx}")

# markdown
md = ["# qKeep=0.80 vs qKeep=0.70（Pruned 全系列，M=10 / D=30 / N=100 / maxFE=300，18 跑/题）",
      "",
      "IGD 越小越好。diff = 0.80 − 0.70，负值表示 qKeep=0.80 更好。",
      "",
      "| 问题 | 0.80 均值 | 0.80 标准差 | 0.70 均值 | 0.70 标准差 | 差值 | 变化% | 更优 | 配对 Wilcoxon p | Holm p |",
      "|---|---|---|---|---|---|---|---|---|---|"]
for r in rows:
    md.append(f"| {r['Problem']} | {r['qKeep080_mean']:.6f} | {r['qKeep080_std']:.6f} | "
              f"{r['qKeep070_mean']:.6f} | {r['qKeep070_std']:.6f} | {r['diff_(080-070)']:+.6f} | "
              f"{r['pct_change_%']:+.2f}% | {r['better']} | {r['wilcoxon_p']:.4f} | {r['holm_p']:.4f} |")
md += ["",
       f"- 0.80 在 **{n_win080}/16** 题更优（Holm 显著 {n_sig080} 题）；0.70 在 **{16-n_win080}/16** 题更优（Holm 显著 {n_sig070} 题）。",
       f"- 平均秩（1=最优）：0.80 = {mean_rank080:.3f}，0.70 = {mean_rank070:.3f}。",
       f"- 16 个问题均值的配对 Wilcoxon：p = {wm.pvalue:.4f}。",
       f"- Friedman（2 配置 × 16 问题）：chi2 = {fr_stat:.4f}，p = {fr_p:.4f}。",
       "",
       "## 说明",
       "- 两组除 qKeep 外全部一致（同种子、同 `run` 分流、同 16 题、同参数 {3000,0.50,0.25,·,6}），因此可按运行号配对比较。",
       "- Holm 校正在 16 个问题上做多重比较控制。"]
mdp = os.path.join(OUT, "qkeep080_vs_070_comparison.md")
with open(mdp, "w", encoding="utf-8") as fh:
    fh.write("\n".join(md))
print(f"md   -> {mdp}")

# plot
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(1, 2, figsize=(15, 6))
    names = [r["Problem"] for r in rows]
    pct = [r["pct_change_%"] for r in rows]
    colors = ["#c0392b" if v < 0 else "#27ae60" for v in pct]
    axes[0].barh(names, pct, color=colors)
    axes[0].axvline(0, color="black", lw=0.8)
    axes[0].set_xlabel("IGD change %  (negative = qKeep=0.80 better)")
    axes[0].set_title("qKeep=0.80 vs 0.70 : relative IGD change")
    axes[0].invert_yaxis()
    x = np.arange(len(names))
    wdt = 0.38
    axes[1].bar(x - wdt / 2, [r["qKeep080_mean"] for r in rows], wdt, label="qKeep=0.80", color="#2980b9")
    axes[1].bar(x + wdt / 2, [r["qKeep070_mean"] for r in rows], wdt, label="qKeep=0.70", color="#e67e22")
    axes[1].set_yscale("log")
    axes[1].set_xticks(x)
    axes[1].set_xticklabels(names, rotation=90)
    axes[1].set_ylabel("mean final IGD (log)")
    axes[1].legend()
    axes[1].set_title("mean final IGD per problem")
    fig.tight_layout()
    png = os.path.join(OUT, "qkeep080_vs_070.png")
    fig.savefig(png, dpi=150)
    print(f"png  -> {png}")
except Exception as exc:
    print(f"[warn] plot skipped: {exc}")
