import os, glob, re, statistics
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
ALG = "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
DIRS = {10: os.path.join(TEST, "10目标", "n30", ALG), 20: os.path.join(TEST, "20目标", ALG)}
pat = re.compile(r"_([A-Za-z]+\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")

print("Where does the stored run1 land inside the 20-run distribution?")
for M, d in DIRS.items():
    for prob in ["DTLZ1", "DTLZ7", "WFG2", "WFG9"]:
        vals = {}
        for f in glob.glob(os.path.join(d, "*_%s_M%d_D*_*.mat" % (prob, M))):
            m = pat.search(os.path.basename(f))
            if not m or int(m.group(2)) != M:
                continue
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            vals[int(m.group(4))] = float(np.asarray(mt.IGDp).ravel()[-1])
        v = [vals[r] for r in sorted(vals)]
        if not v:
            continue
        r1 = vals.get(1)
        rank = sum(1 for x in v if x < r1) + 1
        print(" M=%-3d %-6s n=%-3d mean=%.4f std=%.4f min=%.4f max=%.4f | run1=%.4f rank=%d/%d" % (
            M, prob, len(v), statistics.mean(v), statistics.stdev(v), min(v), max(v), r1, rank, len(v)))
