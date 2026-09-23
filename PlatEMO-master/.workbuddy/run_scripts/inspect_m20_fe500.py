# -*- coding: utf-8 -*-
"""Inspect the 20目标 FE500 data: naming, run numbers, FE grid and metric fields."""
import os
import re

import numpy as np
import scipy.io as sio

BASE = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\FE500"
ALGS = ["REMO", "PCSAEA", "HES_EA", "SSDE", "SAMOEATL2M", "CSEA",
        "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"]

for alg in ALGS:
    d = os.path.join(BASE, alg)
    if not os.path.isdir(d):
        print("%-58s MISSING" % alg)
        continue
    files = sorted(os.listdir(d))
    runs = sorted({int(m.group(1)) for f in files
                   for m in [re.search(r"_M20_D\d+_(\d+)\.mat$", f)] if m})
    probs = sorted({f.split("_M20_")[0].rsplit("_" + alg + "_", 1)[-1].split("_" + alg)[-1]
                    for f in files})
    print("=" * 110)
    print("%-58s files=%d" % (alg, len(files)))
    print("   runs  = %s" % (runs,))
    print("   sample:", files[0])
    # count files per run number to spot mixed batches
    per_run = {}
    for f in files:
        m = re.search(r"_M20_D\d+_(\d+)\.mat$", f)
        if m:
            per_run[int(m.group(1))] = per_run.get(int(m.group(1)), 0) + 1
    print("   per-run counts:", dict(sorted(per_run.items())))
    p = os.path.join(d, files[0])
    try:
        S = sio.loadmat(p, variable_names=["result", "metric"])
    except Exception as exc:  # noqa: BLE001
        print("   unreadable:", exc)
        continue
    if "result" in S:
        r = S["result"]
        fe = [int(np.ravel(r[i, 0])[0]) for i in range(r.shape[0])]
        print("   snapshots=%d  FE first/last = %s / %s" % (len(fe), fe[:4], fe[-3:]))
    if "metric" in S:
        print("   metric fields:", S["metric"].dtype.names)
