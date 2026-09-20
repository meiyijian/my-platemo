import os, glob, re, collections
import scipy.io as sio
import numpy as np

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30"
ALGS = ["REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist", "REMO", "PIEA",
        "CSEA", "PCSAEA_N100", "KRVEA_100", "MCEAD", "SSDE"]
for name in ALGS:
    d = os.path.join(ROOT, name)
    if not os.path.isdir(d):
        print("%-52s (absent)" % name)
        continue
    pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M10_D(\d+)_(\d+)\.mat$")
    low = collections.Counter()   # runs 1..20 : [files, withIGDp]
    high = collections.Counter()  # runs 21..30
    for f in glob.glob(os.path.join(d, "*.mat")):
        m = pat.search(os.path.basename(f))
        if not m:
            continue
        run = int(m.group(3))
        key = "1-20" if run <= 20 else "21-30"
        low[key] += 1
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            if hasattr(mt, "IGDp") and np.asarray(mt.IGDp).ravel().size == S["result"].shape[0]:
                low[key + ":igdp"] += 1
        except Exception:
            pass
    print("%-52s runs1-20 files=%-4d igdp=%-4d | runs21-30 files=%-4d igdp=%-4d" % (
        name, low["1-20"], low["1-20:igdp"], low["21-30"], low["21-30:igdp"]))
