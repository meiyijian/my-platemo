# -*- coding: utf-8 -*-
"""
Cross-version comparison of Good-group Precision audits.

Arms
  A  GGP_AdaMaO   : REMO_new2_AdaMaO_GoodGroupPrecision            (10 problems, 500 runs)
  B  LTGGP_L030   : REMO_UniformMix_Pruned_Weighted_Lambdat030_GGP ( 3 problems, 150 runs)
  C  PWGGP_L050   : lambda_t=0.50 arm, derived from the crossArm table's MeanA/MeanB
                    (only DTLZ2/DTLZ4, M10/M20, 3 views x 3 truths)

All arms ran the same frozen protocol: N=100, D=30, maxFE=500, 25 runs, seeds
problemIndex*10000 + M*100 + run, views {score_hybrid, score_v, anchor_margin},
truths {population_h1/h3/final, front_h1/h3/final}, stages S1..S4, top-25% quota.
"""
import csv, os, statistics as st
from collections import defaultdict

BASE = r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments"
GGP_CSV = os.path.join(BASE, "REMO_new2_AdaMaO_GoodGroupPrecision", "results", "analysis",
                       "formal", "GGP_PairedComparisons.csv")
LT_CSV = os.path.join(BASE, "REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision",
                      "results", "analysis", "formal", "LTGGP_PairedComparisons.csv")
X_CSV = os.path.join(BASE, "REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision",
                     "results", "analysis", "crossArm", "LTGGP_vs_PWGGP_Paired.csv")

SHARED = {"DTLZ2", "DTLZ4", "DTLZ5"}
STAGES = ["S1_[0,0.25]", "S2_(0.25,0.50]", "S3_(0.50,0.75]", "S4_(0.75,1.00]"]
METRICS = ["Precision", "AUC", "Lift"]
TRUTHS = ["population_final", "population_h1", "population_h3", "front_final", "front_h1", "front_h3"]


def load(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def f(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


def contrast_of(r):
    """Return (A,B) view pair key."""
    return (r["ViewA"], r["ViewB"])


out = []
P = out.append

ggp = [r for r in load(GGP_CSV) if r["Problem"] in SHARED]
lt = load(LT_CSV)
out.append("# Good-group Precision 跨算法版本结论对拍\n")
out.append("可比子集：DTLZ2 / DTLZ4 / DTLZ5 x M10,M20（三臂共有）；主口径 Top-25% 等规模筛选、valid pairs=25。\n")
out.append("行数：AdaMaO 全 10 问题 %d 行，其中共有 3 问题 %d 行；Lambdat030 %d 行。\n" % (
    len(load(GGP_CSV)), len(ggp), len(lt)))


def summarize(rows, tag):
    """Per-contrast aggregated evidence, per metric."""
    P("## %s\n" % tag)
    P("| Metric | Contrast (A vs B) | cells | A>B | A<B | Holm 显著胜 | Holm 显著负 | 中位相对增益% | 中位 win prob | cells(ValidPairs<25) |")
    P("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for metric in METRICS:
        for va, vb in [("score_hybrid", "score_v"), ("score_hybrid", "anchor_margin")]:
            sel = [r for r in rows if r["Metric"] == metric and contrast_of(r) == (va, vb)]
            if not sel:
                continue
            pos = sum(1 for r in sel if f(r["MeanDelta"]) > 0)
            neg = sum(1 for r in sel if f(r["MeanDelta"]) < 0)
            sigpos = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
            signeg = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) < 0)
            rel = [f(r["MeanRelativeImprovementPct"]) for r in sel if f(r["MeanRelativeImprovementPct"]) == f(r["MeanRelativeImprovementPct"])]
            wp = [f(r["PairedWinProbability"]) for r in sel if f(r["PairedWinProbability"]) == f(r["PairedWinProbability"])]
            lowp = sum(1 for r in sel if int(r["ValidPairs"]) < 25)
            P("| %s | %s vs %s | %d | %d (%.0f%%) | %d (%.0f%%) | %d | %d | %+.3f | %.3f | %d |" % (
                metric, va, vb, len(sel), pos, 100.0 * pos / len(sel), neg, 100.0 * neg / len(sel),
                sigpos, signeg, st.median(rel) if rel else float("nan"),
                st.median(wp) if wp else float("nan"), lowp))
    P("")


summarize(ggp, "臂 A：AdaMaO 版（REMO_new2_AdaMaO，qKeep=0.8, lambda0=0.35）— 仅共有 3 问题")
summarize(lt, "臂 B：Lambdat030 版（Pruned/Weighted, qKeep=0.70, lambda_t=0.30）")

# ---------------- primary cell: Precision @ top25, population_final, per stage -------------
out.append("## 主口径逐阶段：Precision@25% vs population_final（相对两基线）\n")
for name, rows in [("A: AdaMaO版", ggp), ("B: Lambdat030版", lt)]:
    P("### %s\n" % name)
    P("| Stage | hybrid vs score_v: 均值差(pp) | 胜格/总格 | Holm显著 | hybrid vs anchor: 均值差(pp) | 胜格/总格 | Holm显著 |")
    P("|---|---:|---:|---:|---:|---:|---:|")
    for s in STAGES:
        cells = []
        for va, vb in [("score_hybrid", "score_v"), ("score_hybrid", "anchor_margin")]:
            sel = [r for r in rows if r["Metric"] == "Precision" and r["Stage"] == s
                   and r["Truth"] == "population_final" and contrast_of(r) == (va, vb)]
            d = 100.0 * st.mean([f(r["MeanDelta"]) for r in sel])
            w = sum(1 for r in sel if f(r["MeanDelta"]) > 0)
            sg = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
            cells.append((d, w, len(sel), sg))
        P("| %s | %+.3f | %d/%d | %d | %+.3f | %d/%d | %d |" % (
            s.split("_")[0], cells[0][0], cells[0][1], cells[0][2], cells[0][3],
            cells[1][0], cells[1][1], cells[1][2], cells[1][3]))
    P("")

# ---------------- truth family split -------------
out.append("## 按真值族拆分：Precision 相对 score_v（全部阶段、共有 3 问题）\n")
P("| 臂 | population_* 均值差(pp) | 胜格/总 | front_* 均值差(pp) | 胜格/总 |")
P("|---|---:|---:|---:|---:|")
for name, rows in [("A: AdaMaO版", ggp), ("B: Lambdat030版", lt)]:
    r1 = [r for r in rows if r["Metric"] == "Precision" and r["Truth"].startswith("population_")
          and contrast_of(r) == ("score_hybrid", "score_v")]
    r2 = [r for r in rows if r["Metric"] == "Precision" and r["Truth"].startswith("front_")
          and contrast_of(r) == ("score_hybrid", "score_v")]
    P("| %s | %+.3f | %d/%d | %+.3f | %d/%d |" % (
        name, 100.0 * st.mean([f(r["MeanDelta"]) for r in r1]),
        sum(1 for r in r1 if f(r["MeanDelta"]) > 0), len(r1),
        100.0 * st.mean([f(r["MeanDelta"]) for r in r2]),
        sum(1 for r in r2 if f(r["MeanDelta"]) > 0), len(r2)))
P("")

# ---------------- M split -------------
out.append("## 按目标数拆分：Precision 相对 score_v / anchor（共有 3 问题）\n")
P("| 臂 | M | vs score_v 均值差(pp) | vs anchor 均值差(pp) |")
P("|---|---|---:|---:|")
for name, rows in [("A: AdaMaO版", ggp), ("B: Lambdat030版", lt)]:
    for m in ["10", "20"]:
        a = [r for r in rows if r["Metric"] == "Precision" and r["M"] == m
             and contrast_of(r) == ("score_hybrid", "score_v")]
        b = [r for r in rows if r["Metric"] == "Precision" and r["M"] == m
             and contrast_of(r) == ("score_hybrid", "anchor_margin")]
        P("| %s | M%s | %+.3f | %+.3f |" % (
            name, m, 100.0 * st.mean([f(r["MeanDelta"]) for r in a]),
            100.0 * st.mean([f(r["MeanDelta"]) for r in b])))
P("")

# ---------------- per problem ----------------
out.append("## 逐问题主口径：Precision@25% vs population_final（全阶段均值）\n")
P("| 问题 | M | A: hybrid | A: vs V(pp) | A: vs Anchor(pp) | B: hybrid | B: vs V(pp) | B: vs Anchor(pp) |")
P("|---|---|---:|---:|---:|---:|---:|---:|")
for prob in ["DTLZ2", "DTLZ4", "DTLZ5"]:
    for m in ["10", "20"]:
        cells = []
        for rows in [ggp, lt]:
            res = []
            for va, vb in [("score_hybrid", "score_v"), ("score_hybrid", "anchor_margin")]:
                sel = [r for r in rows if r["Problem"] == prob and r["M"] == m
                       and r["Metric"] == "Precision" and r["Truth"] == "population_final"
                       and contrast_of(r) == (va, vb)]
                res.append(st.mean([f(r["MeanA"]) for r in sel]) if sel else float("nan"))
                res.append(100.0 * st.mean([f(r["MeanDelta"]) for r in sel]) if sel else float("nan"))
            cells.append(res)
        P("| %s | %s | %.4f | %+.3f | %+.3f | %.4f | %+.3f | %+.3f |" % (
            prob, m, cells[0][0], cells[0][1], cells[0][3],
            cells[1][0], cells[1][1], cells[1][3]))
P("")

# ---------------- arm C: lambda050 derived ----------------
xr = load(X_CSV)
derived = defaultdict(dict)   # (prob,M,view,truth) -> (mean_l030, mean_l050)
for r in xr:
    if r["Metric"] == "Precision":
        derived[(r["Problem"], r["M"], r["View"], r["Truth"])] = (f(r["MeanA"]), f(r["MeanB"]))

out.append("## 臂 C：lambda_t=0.50（PWGGP）由跨臂表 MeanA/MeanB 反推的视图差\n")
out.append("说明：跨臂表只给每视图的 25 跑均值，无逐 run 值，故此处只有方向与幅度，**无 p 值**。\n")
P("| 问题 | M | Truth | hybrid-v  L030(pp) | hybrid-v  L050(pp) | hybrid-anchor L030(pp) | hybrid-anchor L050(pp) |")
P("|---|---|---|---:|---:|---:|---:|")
for prob in ["DTLZ2", "DTLZ4"]:
    for m in ["10", "20"]:
        for truth in ["population_final", "front_final", "population_h1"]:
            vals = {}
            for view in ["score_hybrid", "score_v", "anchor_margin"]:
                k = (prob, m, view, truth)
                if k in derived:
                    vals[view] = derived[k]
            if len(vals) < 3:
                continue
            d_v = [(1989.0 * 0 + 100.0 * (v[0] - vals["score_v"][0]), 100.0 * (v[1] - vals["score_v"][1])) for v in [vals["score_hybrid"]]][0]
            d_a = (100.0 * (vals["score_hybrid"][0] - vals["anchor_margin"][0]),
                   100.0 * (vals["score_hybrid"][1] - vals["anchor_margin"][1]))
            P("| %s | %s | %s | %+.3f | %+.3f | %+.3f | %+.3f |" % (prob, m, truth, d_v[0], d_v[1], d_a[0], d_a[1]))
P("")

# also aggregate arm C directional counts
cnt = {"v_pos": 0, "v_neg": 0, "a_pos": 0, "a_neg": 0, "n": 0}
for prob in ["DTLZ2", "DTLZ4"]:
    for m in ["10", "20"]:
        for truth in ["population_final", "front_final", "population_h1"]:
            keys = [(prob, m, v, truth) for v in ["score_hybrid", "score_v", "anchor_margin"]]
            if not all(k in derived for k in keys):
                continue
            h30, h50 = derived[keys[0]]
            v30, v50 = derived[keys[1]]
            a30, a50 = derived[keys[2]]
            cnt["n"] += 1
            cnt["v_pos" if h50 - v50 > 0 else "v_neg"] += 1
            cnt["a_pos" if h50 - a50 > 0 else "a_neg"] += 1
out.append("臂 C 方向汇总（%d 个 问题-M-真值 单元，来源为跨臂表）：hybrid 优于 score_v 的单元 %d 个，劣于 %d 个；"
           "hybrid 优于 anchor 的单元 %d 个，劣于 %d 个。\n" % (
               cnt["n"], cnt["v_pos"], cnt["v_neg"], cnt["a_pos"], cnt["a_neg"]))

# ---------------- lambda030 derived from same table, for a like-for-like check ----------------
out.append("## 同源校验：用跨臂表的 L030 均值反推的视图差 vs LTGGP 配对表的 MeanDelta（仅 DTLZ2/DTLZ4）\n")
P("| 问题 | M | Truth | 反推 L030 hybrid-v(pp) | 配对表 MeanDelta(pp) | 反推 L030 hybrid-anchor(pp) | 配对表 MeanDelta(pp) |")
P("|---|---|---|---:|---:|---:|---:|")
for prob in ["DTLZ2", "DTLZ4"]:
    for m in ["10", "20"]:
        for truth in ["population_final", "front_final", "population_h1"]:
            def dvp(view_pair):
                sel = [r for r in lt if r["Problem"] == prob and r["M"] == m and r["Metric"] == "Precision"
                       and r["Truth"] == truth and contrast_of(r) == view_pair]
                return 100.0 * st.mean([f(r["MeanDelta"]) for r in sel]) if sel else float("nan")
            k = lambda v: (prob, m, v, truth)
            if not all(k(v) in derived for v in ["score_hybrid", "score_v", "anchor_margin"]):
                continue
            d1 = 100.0 * (derived[k("score_hybrid")][0] - derived[k("score_v")][0])
            d2 = dvp(("score_hybrid", "score_v"))
            d3 = 100.0 * (derived[k("score_hybrid")][0] - derived[k("anchor_margin")][0])
            d4 = dvp(("score_hybrid", "anchor_margin"))
            P("| %s | %s | %s | %+.3f | %+.3f | %+.3f | %+.3f |" % (prob, m, truth, d1, d2, d3, d4))
P("")

path = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\_ggp_compare.md"
open(path, "w", encoding="utf-8").write("\n".join(out))
print("wrote", path)
