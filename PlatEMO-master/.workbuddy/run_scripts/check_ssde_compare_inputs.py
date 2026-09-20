import os, glob, re, collections
import scipy.io as sio
import numpy as np

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
ALGS = {
    "PACDIS": "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
    "REMO": "REMO", "PIEA": "PIEA", "CSEA": "CSEA",
    "PCSAEA_N100": "PCSAEA_N100", "KRVEA_100": "KRVEA_100", "MCEAD": "MCEAD",
    "SSDE": "SSDE",
}
PROB = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]


def probe(path, M):
    """-> (files_in_root, per-problem run counts for 1..20, igdp_missing)"""
    if not os.path.isdir(path):
        return None
    pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M%d_D(\d+)_(\d+)\.mat$" % M)
    got = collections.Counter()
    igdp = 0
    n = 0
    for f in glob.glob(os.path.join(path, "*.mat")):
        m = pat.search(os.path.basename(f))
        if not m:
            continue
        run = int(m.group(3))
        if 1 <= run <= 20:
            got[m.group(1)] += 1
            n += 1
            try:
                S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
                mt = S["metric"][0, 0]
                r = S["result"]
                if hasattr(mt, "IGDp") and np.asarray(mt.IGDp).ravel().size == r.shape[0]:
                    igdp += 1
            except Exception:
                pass
    return n, got, igdp


for M, sub in ((20, "20目标"), (15, "15目标"), (10, "10目标")):
    print("=" * 104)
    print("M=%d   root=%s" % (M, os.path.join(ROOT, sub)))
    for label, name in ALGS.items():
        # M=10 uses a nested n30 folder for most algorithms
        cands = [os.path.join(ROOT, sub, name)]
        if M == 10:
            cands = [os.path.join(ROOT, sub, "n30", name), os.path.join(ROOT, sub, name)]
        res = None
        used = None
        for c in cands:
            r = probe(c, M)
            if r and r[0] > 0:
                res, used = r, c
                break
        if res is None:
            print("  %-12s : (no data)   tried %s" % (label, " | ".join(
                os.path.relpath(c, ROOT) for c in cands)))
            continue
        n, got, igdp = res
        missing = [p for p in PROB if got[p] < 20]
        print("  %-12s : files(run1-20)=%-4d IGDp=%-4d  %s  [%s]" % (
            label, n, igdp,
            ("probs<20: %s" % ",".join(missing)) if missing else "all 16 probs x20 OK",
            os.path.relpath(used, ROOT)))
