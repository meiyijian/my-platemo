import os, glob, re, collections
import scipy.io as sio
import numpy as np

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\2目标\DISK"
pat = re.compile(r"^(?P<alg>.+?)_(?P<prob>[A-Za-z]+\d*)_M(?P<M>\d+)_D(?P<D>\d+)_(?P<run>\d+)\.mat$")
fs = sorted(glob.glob(os.path.join(D, "*.mat")))
print("n files =", len(fs))
print("sample names:", [os.path.basename(f) for f in fs[:4]])
ms, ds, snaps, fe0, fe1 = collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter()
keys = collections.Counter()
fields = collections.Counter()
for f in fs:
    m = pat.match(os.path.basename(f))
    if m:
        ms[m.group("M")] += 1
        ds[m.group("D")] += 1
    try:
        S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
    except Exception as e:
        print("  LOADERR", os.path.basename(f), e)
        continue
    keys[",".join(sorted(k for k in S if not k.startswith("__")))] += 1
    r = S["result"]
    snaps[r.shape[0]] += 1
    fe = [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])]
    fe0[fe[0]] += 1
    fe1[fe[-1]] += 1
    try:
        mt = S["metric"][0, 0]
        fields[",".join(sorted(getattr(mt, "_fieldnames", [])))] += 1
    except Exception:
        fields["?"] += 1
print("M:", dict(ms), " D:", dict(ds))
print("keys:", dict(keys))
print("metric fields:", dict(fields))
print("snapshots:", dict(snaps))
print("FE first:", dict(fe0), " FE last:", dict(fe1))
