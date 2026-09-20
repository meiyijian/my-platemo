import os, glob, re, collections
import scipy.io as sio
import numpy as np

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
TARGETS = [("M20", os.path.join(ROOT, "20目标", "SSDE"), 20),
           ("M15", os.path.join(ROOT, "15目标", "SSDE"), 15)]
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")

for tag, d, M in TARGETS:
    print("=" * 92)
    print(tag, "->", d, " exists =", os.path.isdir(d))
    if not os.path.isdir(d):
        continue
    probs = collections.defaultdict(lambda: {"runs": [], "D": collections.Counter()})
    fe0, fe1, snaps = collections.Counter(), collections.Counter(), collections.Counter()
    fields = collections.Counter()
    for f in sorted(glob.glob(os.path.join(d, "*.mat"))):
        m = pat.search(os.path.basename(f))
        if not m:
            continue
        p = m.group(1)
        probs[p]["runs"].append(int(m.group(4)))
        probs[p]["D"][int(m.group(3))] += 1
        S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
        r = S["result"]
        snaps[r.shape[0]] += 1
        fe = [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])]
        fe0[fe[0]] += 1
        fe1[fe[-1]] += 1
        mt = S["metric"][0, 0]
        fields[",".join(sorted(getattr(mt, "_fieldnames", [])))] += 1
    order = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
    for p in order:
        if p in probs:
            rs = sorted(probs[p]["runs"])
            print("  %-6s n=%-3d runs=%d..%d  D=%s" % (
                p, len(rs), rs[0], rs[-1], dict(probs[p]["D"])))
    print("  metric fields:", dict(fields))
    print("  snapshots:", dict(snaps))
    print("  FE first:", dict(fe0))
    print("  FE last :", dict(sorted(fe1.items())))
