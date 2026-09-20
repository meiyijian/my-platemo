import os, glob, re, collections, statistics
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
M = 20
PROBLEMS = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
ALGS = {
    "PACDIS(NoBatchDist)": "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
    "REMO": "REMO",
    "PIEA": "PIEA",
    "CSEA": "CSEA",
    "PCSAEA_N100": "PCSAEA_N100",
    "KRVEA_100": "KRVEA_100",
    "MCEAD": "MCEAD",
    "HES_EA_N100": "HES_EA_N100",
}
d20 = os.path.join(TEST, "20目标")
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M20_D(\d+)_(\d+)\.mat$")

print("M=20 run 1..20 completeness + IGDp presence:")
for label, name in ALGS.items():
    d = os.path.join(d20, name)
    if not os.path.isdir(d):
        print("  %-20s MISSING DIR" % label)
        continue
    got = collections.Counter()
    igdp_missing = 0
    n = 0
    snaps = collections.Counter()
    fe_end = collections.Counter()
    for f in glob.glob(os.path.join(d, "*.mat")):
        m = pat.search(os.path.basename(f))
        if not m:
            continue
        p, dd, run = m.group(1), int(m.group(2)), int(m.group(3))
        if not (1 <= run <= 20):
            continue
        got[p] += 1
        n += 1
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            r = S["result"]
            snaps[r.shape[0]] += 1
            fe_end[int(np.asarray(r[r.shape[0] - 1, 0]).ravel()[0])] += 1
            if not (hasattr(mt, "IGDp") and np.asarray(mt.IGDp).ravel().size == r.shape[0]):
                igdp_missing += 1
        except Exception:
            igdp_missing += 1
    missing_probs = [p for p in PROBLEMS if got[p] < 20]
    extra = {p: c for p, c in got.items() if c != 20}
    print("  %-22s files(run1-20)=%d  IGDp-missing=%d  probs<20=%s  snapshots=%s FE=%s" % (
        label, n, igdp_missing, missing_probs if missing_probs else "none",
        dict(snaps), dict(fe_end)))
