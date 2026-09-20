# -*- coding: utf-8 -*-
"""Per-problem IGD of the two FE500 algorithms, printed for inspection."""
import glob
import os

import numpy as np
import scipy.io as sio

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\FE500"
ALGS = [("HES_EA", "HES_EA"),
        ("SDEOnly_UniformMix", "REMO_new2_AdaMaO_SDEOnly_UniformMix")]
PROBS = [f"DTLZ{i}" for i in range(1, 8)] + [f"WFG{i}" for i in range(1, 10)]
RUNS = range(1, 19)

data = {}
fe_info = {}
for key, alg in ALGS:
    p = os.path.join(D, alg)
    for prob in PROBS:
        vals, fes = [], []
        for r in RUNS:
            hits = glob.glob(os.path.join(p, "%s_%s_M10_D*_%d.mat" % (alg, prob, r)))
            if len(hits) != 1:
                vals.append(np.nan)
                continue
            d = sio.loadmat(hits[0], variable_names=["metric", "result"])
            igd = np.ravel(np.asarray(d["metric"]["IGD"][0, 0], dtype=float))
            vals.append(igd[-1])
            res = d["result"]
            fes.append(int(np.ravel(res[res.shape[0] - 1, 0])[0]))
        data[(key, prob)] = np.array(vals, dtype=float)
        fe_info[(key, prob)] = (min(fes), max(fes)) if fes else (None, None)

print("last-snapshot IGD, runs 1-18")
print("%-7s | %-34s | %-34s" % ("Problem", "HES_EA  mean (std)", "SDEOnly_UniformMix  mean (std)"))
print("-" * 88)
for prob in PROBS:
    a = data[("HES_EA", prob)]
    b = data[("SDEOnly_UniformMix", prob)]
    print("%-7s | %-34s | %-34s" % (
        prob,
        "%12.6g (%9.3g)" % (np.nanmean(a), np.nanstd(a, ddof=1)),
        "%12.6g (%9.3g)" % (np.nanmean(b), np.nanstd(b, ddof=1))))

print()
print("FE window per algorithm (min first-snapshot FE, max last-snapshot FE)")
ks = ["HES_EA", "SDEOnly_UniformMix"]
for k in ks:
    wins = {fe_info[(k, p)] for p in PROBS}
    print("  %-22s %s" % (k, sorted(wins)))

print()
print("detail: per-problem, per-run last IGD (HES_EA | SDEOnly_UniformMix), and which is smaller")
for prob in PROBS:
    a = data[("HES_EA", prob)]
    b = data[("SDEOnly_UniformMix", prob)]
    wins_a = int(np.sum(a < b))
    wins_b = int(np.sum(b < a))
    print()
    print("%s   HES_EA better in %d/18, SDEOnly better in %d/18, tie %d"
          % (prob, wins_a, wins_b, 18 - wins_a - wins_b))
    for i in range(18):
        flag = "HES " if a[i] < b[i] else ("SDE " if b[i] < a[i] else "tie ")
        print("   run %2d  %14.7g  %14.7g   %s" % (i + 1, a[i], b[i], flag))
