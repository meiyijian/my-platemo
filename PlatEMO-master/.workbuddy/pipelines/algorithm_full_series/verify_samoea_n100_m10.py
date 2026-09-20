# -*- coding: utf-8 -*-
"""Verify the SAMOEATL2M_N100 M=10 batch: 16 problems x 20 runs, FE=300 each."""
import glob
import os
import re

import numpy as np
import scipy.io as sio

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\SAMOEATL2M_N100"
PROBS = ["DTLZ1", "DTLZ2", "DTLZ3", "DTLZ4", "DTLZ5", "DTLZ6", "DTLZ7",
         "WFG1", "WFG2", "WFG3", "WFG4", "WFG5", "WFG6", "WFG7", "WFG8", "WFG9"]

all_files = [f for f in os.listdir(D) if f.endswith(".mat")]
print("files in folder: %d  (expected 320)" % len(all_files))

problems = 0
bad = []
fe_counts = {}
igd_means = {}
ds = set()

for p in PROBS:
    runs = []
    for r in range(1, 21):
        hits = glob.glob(os.path.join(D, "SAMOEATL2M_N100_%s_M10_D*_%d.mat" % (p, r)))
        if len(hits) != 1:
            bad.append("%s run %d -> %d files" % (p, r, len(hits)))
            continue
        runs.append(hits[0])
    problems += 1
    if len(runs) != 20:
        bad.append("%s has %d runs" % (p, len(runs)))
        continue
    igd_end = []
    for f in runs:
        try:
            d = sio.loadmat(f, variable_names=["result", "metric", "metadata"])
        except Exception as exc:  # noqa: BLE001
            bad.append("%s unreadable: %s" % (os.path.basename(f), exc))
            continue
        md = d["metadata"]
        fe = int(np.ravel(md["actualFE"][0, 0])[0])
        dval = int(np.ravel(md["D"][0, 0])[0])
        seed = int(np.ravel(md["seed"][0, 0])[0])
        ds.add(dval)
        fe_counts[fe] = fe_counts.get(fe, 0) + 1
        igd = np.ravel(d["metric"]["IGD"][0, 0]).astype(float)
        if not np.all(np.isfinite(igd)) or np.any(igd < 0):
            bad.append("%s bad IGD" % os.path.basename(f))
        igd_end.append(igd[-1])
        # seed rule check
        pos = PROBS.index(p) + 1
        want = 20260912 + 10 * 100000 + pos * 1000 + int(re.search(r"_(\d+)\.mat$", f).group(1))
        if seed != want:
            bad.append("%s seed %d != %d" % (os.path.basename(f), seed, want))
    igd_means[p] = float(np.mean(igd_end))

print("D values seen:", sorted(ds))
print("FE distribution:", fe_counts)
print()
print("%-8s %s" % ("Problem", "mean final IGD (n=20)"))
for p in PROBS:
    if p in igd_means:
        print("%-8s %.6g" % (p, igd_means[p]))
print()
if bad:
    print("PROBLEMS FOUND (%d):" % len(bad))
    for b in bad[:30]:
        print("   ", b)
else:
    print("OK: 320/320 files, all FE=300, seeds follow the rule, IGD finite")
