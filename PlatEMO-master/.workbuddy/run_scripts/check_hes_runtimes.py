import os, glob, re, statistics
import scipy.io as sio
import numpy as np

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\HES_EA_N100"
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M20_D(\d+)_(\d+)\.mat$")
rows = []
for f in sorted(glob.glob(os.path.join(D, "*.mat"))):
    m = pat.search(os.path.basename(f))
    S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
    mt = S["metric"][0, 0]
    rows.append((m.group(1), int(m.group(3)),
                 float(np.asarray(mt.runtime).ravel()[0]),
                 float(np.asarray(mt.IGD).ravel()[-1])))
rows.sort(key=lambda x: (x[0], x[1]))
for p, r, rt, igd in rows:
    print("%-6s run%-3d runtime=%7.1f s  IGD(end)=%10.4f" % (p, r, rt, igd))
print("n=%d" % len(rows))
for p in sorted({x[0] for x in rows}):
    v = [x[2] for x in rows if x[0] == p]
    print("  %-6s n=%-3d runtime mean=%.1f min=%.1f max=%.1f" % (
        p, len(v), statistics.mean(v), min(v), max(v)))
