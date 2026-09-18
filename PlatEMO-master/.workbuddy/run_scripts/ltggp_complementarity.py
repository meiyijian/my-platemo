# -*- coding: utf-8 -*-
"""
The complementarity test: does the continuous branch S and the anchor branch A
each own a different part of the task?  If so, H = (1-t)S + tL fusing them is
exactly the right move, and that is PAQC's contribution claim.
"""
import csv, os, statistics as st

ROOT = r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision"
PAIR = os.path.join(ROOT, "results", "analysis", "formal", "LTGGP_PairedComparisons.csv")
STAGES = ["S1_[0,0.25]", "S2_(0.25,0.50]", "S3_(0.50,0.75]", "S4_(0.75,1.00]"]

with open(PAIR, newline="", encoding="utf-8-sig") as f:
    pair = list(csv.DictReader(f))


def f(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


out = []
P = out.append

P("S = score_v（连续 PBI 得分），A = anchor_margin（参考解分类裕量），H = score_hybrid = (1-t)S + tL")
P("方向约定：以下 Delta 一律为「前者 − 后者」，正表示前者更准。\n")

P("## 1. S vs A 按真值族（Precision，144 格）\n")
P("| 真值族 | S 显著胜 | S 显著负 | 未显著 | 均值差 S−A(pp) |")
P("|---|---:|---:|---:|---:|")
for fam, pref in [("population_*", "population_"), ("front_*", "front_")]:
    sel = [r for r in pair if r["Metric"] == "Precision" and r["ViewA"] == "score_v"
           and r["ViewB"] == "anchor_margin" and r["Truth"].startswith(pref)]
    sp = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
    sn = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) < 0)
    ns = sum(1 for r in sel if r["RejectHolm05"] != "1")
    P("| %s | %d | %d | %d | %+.3f |" % (fam, sp, sn, ns, 100.0 * st.mean([f(r["MeanDelta"]) for r in sel])))
P("")

P("## 2. S vs A 按阶段（Precision，24 格/阶段；负值 = A 更好）\n")
P("| 阶段 | 均值差 S−A(pp) | S 显著胜 | S 显著负 | 未显著 |")
P("|---|---:|---:|---:|---:|")
for s in STAGES:
    sel = [r for r in pair if r["Metric"] == "Precision" and r["ViewA"] == "score_v"
           and r["ViewB"] == "anchor_margin" and r["Stage"] == s]
    sp = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
    sn = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) < 0)
    ns = sum(1 for r in sel if r["RejectHolm05"] != "1")
    P("| %s | %+.3f | %d | %d | %d |" % (s.split("_")[0], 100.0 * st.mean([f(r["MeanDelta"]) for r in sel]), sp, sn, ns))
P("")

P("## 3. S vs A 按真值族 × 阶段（Precision，6 格/单元）\n")
P("| 真值族 | 阶段 | 均值差 S−A(pp) | S 显著胜 | S 显著负 |")
P("|---|---|---:|---:|---:|")
for fam, pref in [("population_*", "population_"), ("front_*", "front_")]:
    for s in STAGES:
        sel = [r for r in pair if r["Metric"] == "Precision" and r["ViewA"] == "score_v"
               and r["ViewB"] == "anchor_margin" and r["Truth"].startswith(pref) and r["Stage"] == s]
        sp = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
        sn = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) < 0)
        P("| %s | %s | %+.3f | %d | %d |" % (fam, s.split("_")[0],
                                             100.0 * st.mean([f(r["MeanDelta"]) for r in sel]), sp, sn))
P("")

P("## 4. 双赢校验：S 强的地方 H 是否也强（相对 A 的比较）\n")
P("| 真值族 | 阶段 | H−A(pp) | H 显著胜 | H 显著负 | S−A(pp) |")
P("|---|---|---:|---:|---:|---:|")
for fam, pref in [("population_*", "population_"), ("front_*", "front_")]:
    for s in STAGES:
        selh = [r for r in pair if r["Metric"] == "Precision" and r["ViewA"] == "score_hybrid"
                and r["ViewB"] == "anchor_margin" and r["Truth"].startswith(pref) and r["Stage"] == s]
        sels = [r for r in pair if r["Metric"] == "Precision" and r["ViewA"] == "score_v"
                and r["ViewB"] == "anchor_margin" and r["Truth"].startswith(pref) and r["Stage"] == s]
        sp = sum(1 for r in selh if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
        sn = sum(1 for r in selh if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) < 0)
        P("| %s | %s | %+.3f | %d | %d | %+.3f |" % (
            fam, s.split("_")[0], 100.0 * st.mean([f(r["MeanDelta"]) for r in selh]), sp, sn,
            100.0 * st.mean([f(r["MeanDelta"]) for r in sels])))
P("")

path = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\_ltggp_complementarity.md"
open(path, "w", encoding="utf-8").write("\n".join(out))
print("wrote", path)
