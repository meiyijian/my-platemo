import os, glob, re, collections
import scipy.io as sio
import numpy as np

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\SSDE"
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")
snaps, fe0, fe1, keys, fields = collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter()
ds = collections.Counter()
probs = collections.defaultdict(list)
for f in glob.glob(os.path.join(D, "*.mat")):
    b = os.path.basename(f)
    m = pat.search(b)
    if m:
        ds[m.group(3)] += 1
        probs[m.group(1)].append(int(m.group(4)))
    S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
    keys[",".join(sorted(k for k in S if not k.startswith("__")))] += 1
    r = S["result"]
    snaps[r.shape[0]] += 1
    fe = [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])]
    fe0[fe[0]] += 1
    fe1[fe[-1]] += 1
    mt = S["metric"][0, 0]
    fields[",".join(sorted(getattr(mt, "_fieldnames", [])))] += 1

print("D values:", dict(ds))
print("keys:", dict(keys))
print("metric fields:", dict(fields))
print("snapshots:", dict(snaps))
print("FE first:", dict(fe0), " FE last:", dict(fe1))
bad = {p: sorted(set(range(1, 19)) - set(v)) for p, v in probs.items() if set(range(1, 19)) - set(v)}
print("missing runIds in 1..18:", bad if bad else "none")
print("extra runIds outside 1..18:",
      {p: sorted(set(v) - set(range(1, 19))) for p, v in probs.items() if set(v) - set(range(1, 19))})

# one concrete example: FE grid + IGD/IGDp of DTLZ1 run1
f = os.path.join(D, "SSDE_DTLZ1_M20_D30_1.mat")
S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
r = S["result"]
print("\nDTLZ1 run1 FE grid:", [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])])
mt = S["metric"][0, 0]
print("  metric fields:", sorted(getattr(mt, "_fieldnames", [])))
for fn in sorted(getattr(mt, "_fieldnames", [])):
    v = np.asarray(getattr(mt, fn)).ravel()
    print("   %-8s len=%d first=%s last=%s" % (fn, v.size, v[0] if v.size else None, v[-1] if v.size else None))
