import os, re, glob, statistics
import scipy.io as sio
import numpy as np

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
ALG = "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
dirs = {10: os.path.join(ROOT, "10目标", "n30", ALG), 20: os.path.join(ROOT, "20目标", ALG)}

pat = re.compile(r"_([A-Za-z]+\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")
grand = {}
for M, d in dirs.items():
    per = {}
    for f in sorted(glob.glob(os.path.join(d, "*.mat"))):
        m = pat.search(os.path.basename(f))
        if not m:
            continue
        if int(m.group(2)) != M:
            continue
        prob = m.group(1).upper()
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            rt = float(np.asarray(S["metric"][0, 0].runtime).ravel()[0])
        except Exception as e:
            print("skip", f, e)
            continue
        per.setdefault(prob, []).append(rt)
    order = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
    tot = 0.0
    print("=== M=%d  (%s)" % (M, d))
    for p in order:
        v = per.get(p, [])
        if not v:
            print("   %-6s n=0" % p)
            continue
        tot += sum(v)
        print("   %-6s n=%-3d mean=%6.1f s  min=%6.1f  max=%6.1f" % (p, len(v), statistics.mean(v), min(v), max(v)))
    print("   TOTAL measured = %.1f h over %d runs ; per-run mean %.1f s" % (
        tot / 3600, sum(len(v) for v in per.values()),
        tot / max(1, sum(len(v) for v in per.values()))))
    grand[M] = tot
print("GRAND measured (one arm, M10+M20) = %.1f h" % (sum(grand.values()) / 3600))
