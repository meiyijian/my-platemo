# -*- coding: utf-8 -*-
"""
Second pass: absolute levels (Precision / Chance / excess / Lift / AUC) and
cell-level agreement between the two Good-group Precision arms.

Wilcoxon signed-rank is implemented with the normal approximation + tie
correction (no scipy in this environment); it is used descriptively, and any
inference that matters is already carried by the arms' own PValueHolm columns.
"""
import csv, os, statistics as st, math
from collections import defaultdict

BASE = r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments"
GGP_STAGE = os.path.join(BASE, "REMO_new2_AdaMaO_GoodGroupPrecision", "results", "analysis", "formal", "GGP_PerRunStage.csv")
LT_STAGE = os.path.join(BASE, "REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision", "results", "analysis", "formal", "LTGGP_PerRunStage.csv")
GGP_PAIR = os.path.join(BASE, "REMO_new2_AdaMaO_GoodGroupPrecision", "results", "analysis", "formal", "GGP_PairedComparisons.csv")
LT_PAIR = os.path.join(BASE, "REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision", "results", "analysis", "formal", "LTGGP_PairedComparisons.csv")

SHARED = ["DTLZ2", "DTLZ4", "DTLZ5"]
TRUTHS = ["population_final", "population_h1", "population_h3", "front_final", "front_h1", "front_h3"]
STAGES = ["S1_[0,0.25]", "S2_(0.25,0.50]", "S3_(0.50,0.75]", "S4_(0.75,1.00]"]
VIEWS = ["score_hybrid", "score_v", "anchor_margin"]

out = []
P = out.append


def load(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def f(x):
    try:
        v = float(x)
        return v
    except (TypeError, ValueError):
        return float("nan")


def wilcoxon_signed_rank(diffs):
    """Normal approximation with tie correction. Returns (n, z, p_two_sided)."""
    d = [x for x in diffs if x != 0 and not math.isnan(x)]
    n = len(d)
    if n < 6:
        return n, float("nan"), float("nan")
    order = sorted(range(n), key=lambda i: abs(d[i]))
    ranks = [0.0] * n
    i = 0
    while i < n:
        j = i
        while j + 1 < n and abs(d[order[j + 1]]) == abs(d[order[i]]):
            j += 1
        avg = (i + j + 2) / 2.0
        for k in range(i, j + 1):
            ranks[order[k]] = avg
        i = j + 1
    w_pos = sum(ranks[i] for i in range(n) if d[i] > 0)
    mean_w = n * (n + 1) / 4.0
    var_w = n * (n + 1) * (2 * n + 1) / 24.0
    # tie correction
    tie_sum = 0.0
    i = 0
    absd = [abs(x) for x in d]
    while i < n:
        j = i
        while j + 1 < n and absd[j + 1] == absd[i]:
            j += 1
        t = j - i + 1
        tie_sum += t ** 3 - t
        i = j + 1
    var_w -= tie_sum / 48.0
    if var_w <= 0:
        return n, float("nan"), float("nan")
    z = (w_pos - mean_w) / math.sqrt(var_w)
    p = 2 * (1 - 0.5 * (1 + math.erf(abs(z) / math.sqrt(2))))
    return n, z, p


# ---------------------------------------------------------------- cell agreement
gp = load(GGP_PAIR)
lp = load(LT_PAIR)
key = lambda r: (r["Problem"], r["M"], r["Stage"], r["Truth"], r["Metric"], r["ViewA"], r["ViewB"])
gm = {key(r): f(r["MeanDelta"]) for r in gp if r["Problem"] in SHARED}
lm = {key(r): f(r["MeanDelta"]) for r in lp}
common = sorted(set(gm) & set(lm))
xs = [gm[k] for k in common]
ys = [lm[k] for k in common]


def pearson(a, b):
    ma, mb = st.mean(a), st.mean(b)
    num = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    den = math.sqrt(sum((x - ma) ** 2 for x in a) * sum((y - mb) ** 2 for y in b))
    return num / den if den else float("nan")


def rank(v):
    order = sorted(range(len(v)), key=lambda i: v[i])
    r = [0.0] * len(v)
    i = 0
    while i < len(v):
        j = i
        while j + 1 < len(v) and v[order[j + 1]] == v[order[i]]:
            j += 1
        avg = (i + j + 2) / 2.0
        for k in range(i, j + 1):
            r[order[k]] = avg
        i = j + 1
    return r


sign_same = sum(1 for x, y in zip(xs, ys) if (x > 0) == (y > 0) and x != 0 and y != 0)
both_nonzero = sum(1 for x, y in zip(xs, ys) if x != 0 and y != 0)

hcell = [k for k in common if k[5] == "score_hybrid"]
hv = [k for k in hcell if k[6] in ("score_v", "anchor_margin")]
xa = [k for k in common if (k[5], k[6]) == ("score_v", "anchor_margin")]


def agree(keys):
    a = [gm[k] for k in keys]
    b = [lm[k] for k in keys]
    nz = [(x, y) for x, y in zip(a, b) if x != 0 and y != 0]
    same = sum(1 for x, y in nz if (x > 0) == (y > 0))
    return len(keys), same, len(nz), pearson(a, b), pearson(rank(a), rank(b)), st.mean(a), st.mean(b)


P("## 1. 逐格一致性：两臂同一 (问题,M,阶段,真值,指标,对比) 单元的 MeanDelta\n")
P("每臂 3 共有问题 × M2 × 阶段4 × 真值6 × 指标3 × 对比3 = 1296 个比较单元。\n")
P("| 单元集合 | cells | 符号一致率 | Pearson r | Spearman rho | AdaMaO 均值Δ | L030 均值Δ |")
P("|---|---:|---:|---:|---:|---:|---:|")
for label, keys in [("全部（含 score_v vs anchor）", common),
                    ("仅含 hybrid 的对比", hv),
                    ("score_v vs anchor_margin", xa)]:
    n, same, nz, r, rho, ma, mb = agree(keys)
    P("| %s | %d | %.1f%% (%d/%d 非零对) | %.3f | %.3f | %+.4f | %+.4f |" % (
        label, n, 100.0 * same / nz, same, nz, r, rho, ma, mb))
P("")

# per-metric agreement
P("| Metric | Contrast | r | 符号一致率 | AdaMaO 均值Δ | L030 均值Δ |")
P("|---|---|---:|---:|---:|---:|")
for metric in ["Precision", "AUC", "Lift"]:
    for va, vb in [("score_hybrid", "score_v"), ("score_hybrid", "anchor_margin")]:
        ks = [k for k in common if k[4] == metric and k[5] == va and k[6] == vb]
        a = [gm[k] for k in ks]
        b = [lm[k] for k in ks]
        sn = sum(1 for x, y in zip(a, b) if (x > 0) == (y > 0) and x != 0 and y != 0)
        bnz = sum(1 for x, y in zip(a, b) if x != 0 and y != 0)
        P("| %s | %s vs %s | %.3f | %.1f%% | %+.4f | %+.4f |" % (
            metric, va, vb, pearson(a, b), 100.0 * sn / bnz, st.mean(a), st.mean(b)))
P("")

# ---------------------------------------------------------------- absolute levels
P("## 2. 绝对水平与相对 Chance 的富集（主口径 Precision@25%，共 3 问题）\n")
P("单元=run-stage（每 run 4 阶段先聚合，再跨 run 汇总）；excess = Precision − 同检查点 Chance。\n")

stage_rows = {"A_AdaMaO": [r for r in load(GGP_STAGE) if r["Problem"] in SHARED],
              "B_Lambdat030": load(LT_STAGE)}
P("| 臂 | View | Truth | Precision | Chance | excess(pp) | excess>0 的 run-stage | Lift | AUC |")
P("|---|---|---|---:|---:|---:|---:|---:|---:|")
for arm in ["A_AdaMaO", "B_Lambdat030"]:
    rows = stage_rows[arm]
    for view in VIEWS:
        for truth in ["population_final", "front_final"]:
            sel = [r for r in rows if r["View"] == view and r["Truth"] == truth]
            pr = [f(r["MeanPrecision"]) for r in sel if f(r["MeanPrecision"]) == f(r["MeanPrecision"])]
            ch = [f(r["MeanChance"]) for r in sel if f(r["MeanChance"]) == f(r["MeanChance"])]
            ex = [f(r["MeanPrecision"]) - f(r["MeanChance"]) for r in sel
                  if f(r["MeanPrecision"]) == f(r["MeanPrecision"]) and f(r["MeanChance"]) == f(r["MeanChance"])]
            lf = [f(r["MeanLift"]) for r in sel if f(r["MeanLift"]) == f(r["MeanLift"])]
            au = [f(r["MeanAUC"]) for r in sel if f(r["MeanAUC"]) == f(r["MeanAUC"])]
            P("| %s | %s | %s | %.4f | %.4f | %+.2f | %.1f%% (%d/%d) | %.3f | %.3f |" % (
                arm, view, truth, st.mean(pr), st.mean(ch), 100.0 * st.mean(ex),
                100.0 * sum(1 for v in ex if v > 0) / len(ex), sum(1 for v in ex if v > 0), len(ex),
                st.mean(lf), st.mean(au)))
P("")

# paired excess vs 0, per arm per view
P("## 3. excess = Precision − Chance 的配对检验（run-stage 为单位，Wilcoxon 近似）\n")
P("| 臂 | View | Truth | n | 均值 excess(pp) | z | p(双侧) |")
P("|---|---|---|---:|---:|---:|---:|")
for arm in ["A_AdaMaO", "B_Lambdat030"]:
    rows = stage_rows[arm]
    for view in VIEWS:
        for truth in ["population_final", "front_final"]:
            ex = [f(r["MeanPrecision"]) - f(r["MeanChance"]) for r in rows
                  if r["View"] == view and r["Truth"] == truth
                  and f(r["MeanPrecision"]) == f(r["MeanPrecision"]) and f(r["MeanChance"]) == f(r["MeanChance"])]
            n, z, p = wilcoxon_signed_rank(ex)
            P("| %s | %s | %s | %d | %+.2f | %+.2f | %.3g |" % (arm, view, truth, n, 100.0 * st.mean(ex), z, p))
P("")

# ---------------------------------------------------------------- AdaMaO: shared vs rest
P("## 4. AdaMaO 臂：共有 3 问题 vs 其余 7 问题（展示 Lambdat030 选题未覆盖的部分）\n")
allggp = load(GGP_STAGE)
P("| 子集 | View | Precision(pop_final) | Chance | excess(pp) | Lift |")
P("|---|---|---:|---:|---:|---:|")
for label, sel0 in [("DTLZ2/4/5（=L030 覆盖）", [r for r in allggp if r["Problem"] in SHARED]),
                    ("其余 7 问题", [r for r in allggp if r["Problem"] not in SHARED]),
                    ("其中 WFG4 题", [r for r in allggp if r["Problem"].startswith("WFG")]),
                    ("其中 DTLZ3/6/7", [r for r in allggp if r["Problem"] in ("DTLZ3", "DTLZ6", "DTLZ7")])]:
    for view in VIEWS:
        sel = [r for r in sel0 if r["View"] == view and r["Truth"] == "population_final"]
        pr = [f(r["MeanPrecision"]) for r in sel]
        ch = [f(r["MeanChance"]) for r in sel]
        lf = [f(r["MeanLift"]) for r in sel if f(r["MeanLift"]) == f(r["MeanLift"])]
        P("| %s | %s | %.4f | %.4f | %+.2f | %.3f |" % (
            label, view, st.mean(pr), st.mean(ch), 100.0 * (st.mean(pr) - st.mean(ch)), st.mean(lf)))
P("")

path = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\_ggp_compare2.md"
open(path, "w", encoding="utf-8").write("\n".join(out))
print("wrote", path)
