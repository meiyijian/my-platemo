import os, glob, re, statistics
import scipy.io as sio
import numpy as np

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\HES_EA_N100"
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M20_D(\d+)_(\d+)\.mat$")
rts, probs = [], {}
for f in sorted(glob.glob(os.path.join(D, "*.mat"))):
    m = pat.search(os.path.basename(f))
    if not m:
        continue
    S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
    mt = S["metric"][0, 0]
    rt = float(np.asarray(mt.runtime).ravel()[0])
    rts.append(rt)
    probs.setdefault(m.group(1), []).append(rt)
    print("%-40s runtime=%7.1f s  IGD(end)=%10.4f  IGDp(end)=%10.4f  snaps=%d" % (
        os.path.basename(f), rt,
        float(np.asarray(mt.IGD).ravel()[-1]),
        float(np.asarray(mt.IGDp).ravel()[-1]) if hasattr(mt, "IGDp") else float("nan"),
        S["result"].shape[0]))
if rts:
    print("n=%d  runtime mean=%.1f min=%.1f max=%.1f  sum=%.2f h" % (
        len(rts), statistics.mean(rts), min(rts), max(rts), sum(rts) / 3600))
    print("implied throughput at 5 workers = %.1f runs/h" % (5 * 3600 / statistics.mean(rts)))
