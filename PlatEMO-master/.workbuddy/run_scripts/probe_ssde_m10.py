import os, glob, re, collections, datetime
import scipy.io as sio
import numpy as np

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\SSDE"
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")
probs = collections.defaultdict(list)
ds, snaps, fe0, fe1, fields = collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter()
mtimes = []
keys = collections.Counter()
for f in sorted(glob.glob(os.path.join(D, "*.mat"))):
    m = pat.search(os.path.basename(f))
    if m:
        probs[m.group(1)].append(int(m.group(4)))
        ds[int(m.group(3))] += 1
    mtimes.append(os.path.getmtime(f))
    S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
    keys[",".join(sorted(k for k in S if not k.startswith("__")))] += 1
    r = S["result"]
    snaps[r.shape[0]] += 1
    fe = [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])]
    fe0[fe[0]] += 1
    fe1[fe[-1]] += 1
    fields[",".join(sorted(getattr(S["metric"][0, 0], "_fieldnames", [])))] += 1

print("files =", sum(len(v) for v in probs.values()), " problems =", len(probs))
print("D:", dict(ds))
print("keys:", dict(keys))
print("metric fields:", dict(fields))
print("FE first:", dict(fe0))
print("FE last :", dict(sorted(fe1.items())))
print("snapshots:", dict(sorted(snaps.items())))
bad = {p: sorted(set(range(1, 21)) - set(v)) for p, v in probs.items() if set(range(1, 21)) - set(v)}
print("missing runIds in 1..20:", bad if bad else "none")
mt = sorted(mtimes)
print("mtime first:", datetime.datetime.fromtimestamp(mt[0]).strftime("%Y-%m-%d %H:%M:%S"))
print("mtime last :", datetime.datetime.fromtimestamp(mt[-1]).strftime("%Y-%m-%d %H:%M:%S"))
