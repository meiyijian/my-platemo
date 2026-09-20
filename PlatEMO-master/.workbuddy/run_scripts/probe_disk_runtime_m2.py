import os, glob, re, statistics
import scipy.io as sio
import numpy as np

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\2目标\DISK"
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")

# DISK runtime recorded in the M=2 dataset (N=100, maxFE=300, 30 snapshots)
per = {}
for f in sorted(glob.glob(os.path.join(D, "*.mat"))):
    m = pat.search(os.path.basename(f))
    if not m:
        continue
    S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
    mt = S["metric"][0, 0]
    rt = float(np.asarray(mt.runtime).ravel()[0])
    fe = int(np.asarray(S["result"][S["result"].shape[0] - 1, 0]).ravel()[0])
    per.setdefault(m.group(1), []).append((rt, fe))
print("2目标 DISK recorded runtime (N=100, maxFE=300):")
for p in sorted(per):
    v = [x[0] for x in per[p]]
    fe = [x[1] for x in per[p]]
    print("  %-6s n=%-3d runtime mean=%7.1f s  min=%7.1f max=%7.1f   FE last %s" % (
        p, len(v), statistics.mean(v), min(v), max(v), sorted(set(fe))))
allv = [x[0] for p in per for x in per[p]]
print("  ALL n=%d mean=%.1f s" % (len(allv), statistics.mean(allv)))
