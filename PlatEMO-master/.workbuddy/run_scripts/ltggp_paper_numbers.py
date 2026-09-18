# -*- coding: utf-8 -*-
"""
Extract the writing-ready numbers for the Lambdat030 (LTGGP) arm, framed as an
internal ablation of PAQC's three selection rules under one fixed quota:
    H  = score_hybrid    = (1-t)*S + t*L        <- production rule
    S  = score_v         = continuous PBI quality score   (no anchor branch)
    A  = anchor_margin   = 1 - normalized g     (anchor branch, continuous margin)
Only LTGGP_L030 is used.  Significance is taken from the CSV's own PValueHolm.
"""
import csv, os, statistics as st
from collections import defaultdict

ROOT = r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision"
PAIR = os.path.join(ROOT, "results", "analysis", "formal", "LTGGP_PairedComparisons.csv")
STAGE = os.path.join(ROOT, "results", "analysis", "formal", "LTGGP_PerRunStage.csv")
LABEL = os.path.join(ROOT, "results", "analysis", "formal", "LTGGP_LabelDynNative.csv")

PROBS = ["DTLZ2", "DTLZ4", "DTLZ5"]
STAGES = ["S1_[0,0.25]", "S2_(0.25,0.50]", "S3_(0.50,0.75]", "S4_(0.75,1.00]"]

out = []
P = out.append


def load(p):
    with open(p, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def f(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


pair = load(PAIR)
stage = load(STAGE)

# ---- 1. head-to-head counts for the primary metric, Precision
P("## 1. 主指标 Precision 的 Holm 判定计数（全部 3 问题 × M2 × 4 阶段 × 6 真值 = 144 格/对比）\n")
P("| 对比 | 显著胜 | 显著负 | 未显著 | 未显著中方向为正 |")
P("|---|---:|---:|---:|---:|")
for va, vb, lab in [("score_hybrid", "score_v", "H vs S（融合 vs 只用连续得分）"),
                    ("score_hybrid", "anchor_margin", "H vs A（融合 vs 只用分类裕量）"),
                    ("score_v", "anchor_margin", "S vs A（两条单分支互比）")]:
    sel = [r for r in pair if r["Metric"] == "Precision" and r["ViewA"] == va and r["ViewB"] == vb]
    sp = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
    sn = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) < 0)
    ns = sum(1 for r in sel if r["RejectHolm05"] != "1")
    nsp = sum(1 for r in sel if r["RejectHolm05"] != "1" and f(r["MeanDelta"]) > 0)
    P("| %s | %d | %d | %d | %d |" % (lab, sp, sn, ns, nsp))
P("")

# ---- 2. significance split by truth family
P("## 2. 同上，但拆到真值族（Precision）\n")
P("| 对比 | 真值族 | 显著胜 | 显著负 | 未显著 | 均值差(pp) |")
P("|---|---|---:|---:|---:|---:|")
for va, vb, lab in [("score_hybrid", "score_v", "H vs S"), ("score_hybrid", "anchor_margin", "H vs A")]:
    for fam, pref in [("population_*（最终/未来仍在种群）", "population_"), ("front_*（档案中非支配）", "front_")]:
        sel = [r for r in pair if r["Metric"] == "Precision" and r["ViewA"] == va and r["ViewB"] == vb
               and r["Truth"].startswith(pref)]
        sp = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) > 0)
        sn = sum(1 for r in sel if r["RejectHolm05"] == "1" and f(r["MeanDelta"]) < 0)
        ns = sum(1 for r in sel if r["RejectHolm05"] != "1")
        P("| %s | %s | %d | %d | %d | %+.3f |" % (
            lab, fam, sp, sn, ns, 100.0 * st.mean([f(r["MeanDelta"]) for r in sel])))
P("")

# ---- 3. 主真值 population_final 逐问题-M
P("## 3. 主口径逐问题-M：Precision@25% vs population_final（全阶段均值，pp）\n")
P("| 问题 | M | S | A | H | H−S | p_Holm | H−A | p_Holm | H−Chance |")
P("|---|---|---:|---:|---:|---:|---|---:|---|---:|")
for prob in PROBS:
    for m in ["10", "20"]:
        row = [prob, m]
        vals = {}
        for v in ["score_hybrid", "score_v", "anchor_margin"]:
            sel = [r for r in stage if r["Problem"] == prob and r["M"] == m and r["Truth"] == "population_final" and r["View"] == v]
            vals[v] = (st.mean([f(r["MeanPrecision"]) for r in sel]),
                       st.mean([f(r["MeanChance"]) for r in sel]))
        cells = []
        for vb in ["score_v", "anchor_margin"]:
            sel = [r for r in pair if r["Problem"] == prob and r["M"] == m and r["Truth"] == "population_final"
                   and r["Metric"] == "Precision" and r["ViewA"] == "score_hybrid" and r["ViewB"] == vb]
            cells.append((100.0 * st.mean([f(r["MeanDelta"]) for r in sel]),
                          st.median([f(r["PValueHolm"]) for r in sel])))
        hc = 100.0 * (vals["score_hybrid"][0] - vals["score_hybrid"][1])
        P("| %s | %s | %.4f | %.4f | %.4f | %+.3f | %.4g | %+.3f | %.4g | %+.2f |" % (
            prob, m, vals["score_v"][0], vals["anchor_margin"][0], vals["score_hybrid"][0],
            cells[0][0], cells[0][1], cells[1][0], cells[1][1], hc))
P("")

# ---- 4. 逐阶段
P("## 4. 逐阶段：Precision@25% vs population_final\n")
P("| 阶段 | H−S(pp) | p_Holm | H−A(pp) | p_Holm | 格数 |")
P("|---|---:|---|---:|---|---:|")
for s in STAGES:
    cells = []
    for vb in ["score_v", "anchor_margin"]:
        sel = [r for r in pair if r["Stage"] == s and r["Truth"] == "population_final"
               and r["Metric"] == "Precision" and r["ViewA"] == "score_hybrid" and r["ViewB"] == vb]
        cells.append((100.0 * st.mean([f(r["MeanDelta"]) for r in sel]),
                      st.median([f(r["PValueHolm"]) for r in sel]), len(sel)))
    P("| %s | %+.3f | %.4g | %+.3f | %.4g | %d |" % (
        s.split("_")[0], cells[0][0], cells[0][1], cells[1][0], cells[1][1], cells[0][2]))
P("")

# ---- 5. 全局：绝对水平 / 富集 / Lift / AUC，三视图对照
P("## 5. 三视图绝对水平（population_final，单元=run-stage）\n")
P("| 视图 | Precision | Chance | excess(pp) | Lift | AUC |")
P("|---|---:|---:|---:|---:|---:|")
for v in ["score_hybrid", "score_v", "anchor_margin"]:
    sel = [r for r in stage if r["Truth"] == "population_final" and r["View"] == v]
    pr = st.mean([f(r["MeanPrecision"]) for r in sel])
    ch = st.mean([f(r["MeanChance"]) for r in sel])
    P("| %s | %.4f | %.4f | %+.2f | %.3f | %.3f |" % (
        v, pr, ch, 100.0 * (pr - ch),
        st.mean([f(r["MeanLift"]) for r in sel if f(r["MeanLift"]) == f(r["MeanLift"])]),
        st.mean([f(r["MeanAUC"]) for r in sel if f(r["MeanAUC"]) == f(r["MeanAUC"])])))
P("")

# ---- 6. 最能写的正面单元：H 同时显著优于 S 与 A，且两者都显著
P("## 6. H 同时显著优于 S 与 A 的单元（Precision，Holm 双侧）\n")
bycell = defaultdict(dict)
for r in pair:
    if r["Metric"] == "Precision":
        bycell[(r["Problem"], r["M"], r["Stage"], r["Truth"])][(r["ViewA"], r["ViewB"])] = r
hits = []
for k, d in bycell.items():
    a = d.get(("score_hybrid", "score_v"))
    b = d.get(("score_hybrid", "anchor_margin"))
    if not a or not b:
        continue
    if a["RejectHolm05"] == "1" and f(a["MeanDelta"]) > 0 and b["RejectHolm05"] == "1" and f(b["MeanDelta"]) > 0:
        hits.append((k, a, b))
hits.sort(key=lambda t: -(f(t[1]["MeanDelta"]) + f(t[2]["MeanDelta"])))
P("共 %d 个单元。\n" % len(hits))
P("| 问题 | M | 阶段 | 真值 | H | S | A | H−S(pp) | p_Holm | H−A(pp) | p_Holm |")
P("|---|---|---|---|---:|---:|---:|---:|---|---:|---|")
for (prob, m, s, truth), a, b in hits:
    P("| %s | %s | %s | %s | %.4f | %.4f | %.4f | %+.3f | %.4g | %+.3f | %.4g |" % (
        prob, m, s.split("_")[0], truth, f(a["MeanA"]), f(a["MeanB"]), f(b["MeanB"]),
        100.0 * f(a["MeanDelta"]), f(a["PValueHolm"]),
        100.0 * f(b["MeanDelta"]), f(b["PValueHolm"])))
P("")

# ---- 7. 换算成"每 25 个位置多识别多少"
P("## 7. 把百分点换算成筛选位置（每格固定选 25 个解）\n")
for lab, va, vb in [("H 相对 S", "score_hybrid", "score_v"), ("H 相对 A", "score_hybrid", "anchor_margin")]:
    sel = [r for r in pair if r["Metric"] == "Precision" and r["Truth"] == "population_final"
           and r["ViewA"] == va and r["ViewB"] == vb]
    d = st.mean([f(r["MeanDelta"]) for r in sel])
    P("- %s（population_final，全阶段全格均值）：%+.3f pp → 每 25 个筛选位置平均多识别 %.2f 个最终保留个体。" % (
        lab, 100.0 * d, 25 * d))
P("")

# ---- 8. label_dyn 原生（辅助口）
if os.path.isfile(LABEL):
    lab_rows = load(LABEL)
    P("## 8. label_dyn 原生口径（辅助报告，正例率非 25%）\n")
    P("| 视图 | NativePrecision | 行数 |")
    P("|---|---|---:|")
    keys = [k for k in lab_rows[0].keys() if "recision" in k or k == "View"]
    for v in sorted({r["View"] for r in lab_rows}):
        sel = [r for r in lab_rows if r["View"] == v]
        pc = [k for k in sel[0] if "recision" in k.lower()]
        if pc:
            P("| %s | %.4f | %d |" % (v, st.mean([f(r[pc[0]]) for r in sel]), len(sel)))
    P("\n字段：%s" % keys)

path = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\_ltggp_paper_numbers.md"
open(path, "w", encoding="utf-8").write("\n".join(out))
print("wrote", path)
