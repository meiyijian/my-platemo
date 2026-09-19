import os, re, glob, collections, statistics, sys
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
TARGETS = ["REMO_k15", "REMO_k", "REMO",
           "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
           "REMO_noBatchDict_noCDIS", "REMO_noBatchDict_noPAQC"]
pat = re.compile(r"^(?P<alg>.+?)_(?P<prob>DTLZ\d+|WFG\d+)_M(?P<M>\d+)_D(?P<D>\d+)_(?P<run>\d+)\.mat$", re.I)

found = collections.defaultdict(set)   # (alg, M) -> {(dir, D, prob)}
for root, dirs, files in os.walk(TEST):
    for fn in files:
        if not fn.lower().endswith(".mat"):
            continue
        m = pat.match(fn)
        if not m:
            continue
        alg = m.group("alg")
        if alg not in TARGETS:
            continue
        found[(alg, int(m.group("M")))].add((root, int(m.group("D"))))

print("### physical locations")
for k in sorted(found):
    locs = collections.Counter((d, D) for (d, D) in found[k])
    print(" %-45s M=%-3d" % (k[0], k[1]))
    for (d, D), c in sorted(locs.items()):
        print("      D=%-3d %s" % (D, d))

print()
print("### reference cross-check (metric IGD, runs 1-20, mean)")


def collect(alg, M, ddir, D, runs=range(1, 21), metric="IGD"):
    probs = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
    out = {}
    for p in probs:
        vals = {}
        for r in runs:
            f = os.path.join(ddir, "%s_%s_M%d_D%d_%d.mat" % (alg, p, M, D, r))
            if not os.path.isfile(f):
                continue
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            if not hasattr(mt, metric):
                continue
            vals[r] = float(np.asarray(getattr(mt, metric)).ravel()[-1])
        out[p] = vals
    return out


checks = [
    ("REMO_k15", 10, "DTLZ1", 255.72),
    ("REMO_k15", 10, "WFG4", 7.2123),
    ("REMO_k15", 10, "DTLZ7", 21.381),
    ("REMO_k", 20, "DTLZ1", 101.94),
    ("REMO_k", 20, "DTLZ7", 42.108),
    ("REMO", 10, "DTLZ1", 207.48),
    ("REMO", 20, "DTLZ1", 67.408),
]
# locate dir/D for these
for alg, M, prob, expect in checks:
    cands = sorted(found.get((alg, M), []))
    if not cands:
        print("  %-12s M=%-3d %-6s  -> NO DIR" % (alg, M, prob))
        continue
    got = []
    for ddir, D in cands:
        v = collect(alg, M, ddir, D, metric="IGD").get(prob, {})
        if not v:
            continue
        got.append((D, ddir, statistics.mean(v.values()), len(v)))
    for D, ddir, mean, n in got:
        flag = "  <== MATCH" if abs(mean - expect) < max(0.01, 0.001 * expect) else ""
        print("  %-12s M=%-3d D=%-3d %-6s n=%-3d mean=%12.5f expect=%12.5f%s" %
              (alg, M, D, prob, n, mean, expect, flag))
        print("        dir=%s" % ddir)
