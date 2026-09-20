import os, glob, re, statistics
import scipy.io as sio
import numpy as np

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")
ORDER = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]

for M in (20, 15):
    d = os.path.join(ROOT, "%d目标" % M, "SSDE")
    print("=" * 100)
    print("SSDE  M=%d   %s" % (M, d))
    data = {}
    for f in glob.glob(os.path.join(d, "*.mat")):
        m = pat.search(os.path.basename(f))
        if not m:
            continue
        S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
        mt = S["metric"][0, 0]
        p, run = m.group(1), int(m.group(4))
        data.setdefault(p, {})[run] = (float(np.asarray(mt.IGD).ravel()[-1]),
                                       float(np.asarray(mt.IGDp).ravel()[-1]))
    print("%-6s %-22s %-22s %-22s %s" % ("prob", "IGDp mean r1-18", "IGDp mean r19-20", "ratio new/old", "IGD mean r1-18 -> r19-20"))
    worst = []
    for p in ORDER:
        if p not in data:
            continue
        old = [v[1] for k, v in data[p].items() if k <= 18]
        new = [v[1] for k, v in data[p].items() if k >= 19]
        oi = [v[0] for k, v in data[p].items() if k <= 18]
        ni = [v[0] for k, v in data[p].items() if k >= 19]
        mo, mn = statistics.mean(old), statistics.mean(new)
        r = mn / mo
        worst.append((abs(r - 1), p, r))
        print("%-6s %-22.5f %-22.5f %-22.3f %.4f -> %.4f  (n old=%d new=%d)" % (
            p, mo, mn, r, statistics.mean(oi), statistics.mean(ni), len(old), len(new)))
    worst.sort(reverse=True)
    print("  largest deviation of the new runs from the old mean: %s" % (
        ", ".join("%s %.2fx" % (p, r) for _, p, r in worst[:3])))
