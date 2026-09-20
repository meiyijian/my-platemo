import os, glob, re, collections
import scipy.io as sio
import scipy.stats as st
import numpy as np

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
PROB = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
ALGS = [("REMO", "REMO"), ("PIEA", "PIEA"), ("CSEA", "CSEA"),
        ("PCSAEA_N100", "PCSAEA_N100"), ("KRVEA_100", "KRVEA_100"), ("MCEAD", "MCEAD"),
        ("SSDE", "SSDE"),
        ("PACDIS", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist")]
RUNS = range(1, 21)


def subdir(M):
    return os.path.join("10目标", "n30") if M == 10 else ("%d目标" % M)


def load(M):
    """-> vals[algLabel][prob] = np.array of IGDp(end) for runs 1..20"""
    out = {}
    for label, name in ALGS:
        d = os.path.join(ROOT, subdir(M), name)
        per = collections.defaultdict(list)
        for r in RUNS:
            f = None
            for dd in (30, 31):
                c = os.path.join(d, "%s_%s_M%d_D%d_%d.mat" % (name, None, M, dd, r))
                # glob instead of guessing the problem name
            for p in PROB:
                hit = glob.glob(os.path.join(d, "%s_%s_M%d_D*_%d.mat" % (name, p, M, r)))
                if len(hit) == 1:
                    S = sio.loadmat(hit[0], struct_as_record=False, squeeze_me=False)
                    v = np.asarray(S["metric"][0, 0].IGDp).ravel()
                    per[p].append(float(v[-1]))
                else:
                    per[p].append(np.nan)
        out[label] = {p: np.array(v) for p, v in per.items()}
    return out


for M in (10, 15, 20):
    V = load(M)
    print("=" * 100)
    print("M=%d   SSDE 与六个基线的正面对比（IGDp，run 1-20，ranksum p<0.05）" % M)
    print("  %-12s %-14s %-30s" % ("baseline", "SSDE + / - / =", "备注"))
    for label, _ in ALGS[:-1]:
        if label == "SSDE":
            continue
        w = l = t = 0
        better, worse = [], []
        for p in PROB:
            a, b = V["SSDE"][p], V[label][p]
            ok = ~(np.isnan(a) | np.isnan(b))
            pv = st.ranksum(a[ok], b[ok]).pvalue
            if pv < 0.05:
                if np.mean(a[ok]) < np.mean(b[ok]):
                    w += 1; better.append(p)
                else:
                    l += 1; worse.append(p)
            else:
                t += 1
        print("  %-12s %-14s SSDE 好于它的题: %s" % (
            label, "%d / %d / %d" % (w, l, t), ", ".join(better) if better else "-"))
    # strength profile: mean rank of each algorithm across the 16 problems
    print("\n  各算法强度画像（按每题 8 个算法的 IGDp 均值排名，1=最好）")
    ranks = collections.defaultdict(list)
    for p in PROB:
        means = {lab: np.nanmean(V[lab][p]) for lab, _ in ALGS}
        order = sorted(means, key=means.get)
        for i, lab in enumerate(order, start=1):
            ranks[lab].append(i)
    for lab, _ in ALGS:
        r = ranks[lab]
        print("    %-12s 平均排名 %.2f   拿过第1名的题数 %d" % (
            lab, np.mean(r), sum(1 for x in r if x == 1)))
    # MCEAD vs SSDE specifically
    print("\n  MCEAD vs SSDE 逐题（均值）")
    for p in PROB:
        a, b = V["SSDE"][p], V["MCEAD"][p]
        pv = st.ranksum(a, b).pvalue
        tag = "SSDE 更好" if (pv < 0.05 and np.mean(a) < np.mean(b)) else (
              "MCEAD 更好" if (pv < 0.05 and np.mean(a) > np.mean(b)) else "无差异")
        print("    %-6s SSDE %12.5f   MCEAD %12.5f   p=%.3g  %s" % (
            p, np.mean(a), np.mean(b), pv, tag))
