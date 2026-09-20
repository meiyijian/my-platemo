import os, re, glob, statistics
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
D20 = os.path.join(TEST, "20目标")
D10 = os.path.join(TEST, "10目标", "n30")
pat = re.compile(r"^(?P<alg>.+?)_(?P<prob>DTLZ\d+|WFG\d+)_M(?P<M>\d+)_D(?P<D>\d+)_(?P<run>\d+)\.mat$")

for tag, d, M in [("noCDIS M20", os.path.join(D20, "REMO_noBatchDict_noCDIS"), 20),
                  ("noPAQC M20", os.path.join(D20, "REMO_noBatchDict_noPAQC"), 20),
                  ("full M20 (stored)", os.path.join(D20, "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"), 20),
                  ("noCDIS M10 (mine)", os.path.join(D10, "REMO_noBatchDict_noCDIS"), 10)]:
    print("=" * 96)
    print(tag, "->", d)
    fs = sorted(glob.glob(os.path.join(d, "*.mat")))
    keysets = {}
    fe0, fe1, runs = set(), set(), {}
    rts = []
    for f in fs:
        b = os.path.basename(f)
        m = pat.match(b)
        if not m:
            continue
        runs.setdefault(m.group("prob"), set()).add(int(m.group("run")))
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
        except Exception as e:
            print("  LOADERR", b, e); continue
        keysets[",".join(sorted(k for k in S if not k.startswith("__")))] = \
            keysets.get(",".join(sorted(k for k in S if not k.startswith("__"))), 0) + 1
        r = S["result"]
        fe = [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])]
        fe0.add(fe[0]); fe1.add(fe[-1])
        rts.append(float(np.asarray(S["metric"][0, 0].runtime).ravel()[0]))
    print("  keys:", keysets)
    print("  FE first values:", sorted(fe0), " FE last values:", sorted(fe1))
    print("  per-problem run counts: min=%d max=%d over %d problems" % (
        min(len(v) for v in runs.values()), max(len(v) for v in runs.values()), len(runs)))
    miss = {p: sorted(set(range(1, 21)) - v) for p, v in runs.items() if set(range(1, 21)) - v}
    print("  missing runIds in 1..20:", miss if miss else "none")
    print("  runtime: min=%.1f mean=%.1f max=%.1f  (sum %.1f h)" % (
        min(rts), statistics.mean(rts), max(rts), sum(rts) / 3600))
