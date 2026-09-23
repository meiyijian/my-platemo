# -*- coding: utf-8 -*-
"""Inspect the existing 10目标\n30\FE500 data: naming, run numbers and FE grid."""
import glob
import os
import re

import numpy as np
import scipy.io as sio

BASE = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\FE500"
ALGS = ["REMO", "PCSAEA", "HES_EA", "MCEAD", "PIEA", "R2AEA", "KRVEA",
        "REMO_new2_AdaMaO_SDEOnly_UniformMix"]

for alg in ALGS:
    d = os.path.join(BASE, alg)
    if not os.path.isdir(d):
        print("%-40s MISSING" % alg)
        continue
    files = sorted(os.listdir(d))
    runs = sorted({int(m.group(1)) for f in files
                   for m in [re.search(r"_M10_D\d+_(\d+)\.mat$", f)] if m})
    probs = sorted({f.split("_M10_")[0].split(alg + "_")[-1] for f in files})
    print("=" * 100)
    print("%-40s files=%d runs=%s probs=%d" % (alg, len(files), runs, len(probs)))
    print("   sample:", files[0])
    # read one file for the FE grid and metric fields
    p = os.path.join(d, files[0])
    try:
        S = sio.loadmat(p, variable_names=["result", "metric", "metadata"])
    except Exception as exc:  # noqa: BLE001
        print("   unreadable:", exc)
        continue
    if "result" in S:
        r = S["result"]
        fe = [int(np.ravel(r[i, 0])[0]) for i in range(r.shape[0])]
        print("   snapshots=%d  FE=%s" % (len(fe), fe))
    if "metric" in S:
        print("   metric fields:", S["metric"].dtype.names)
    if "metadata" in S:
        md = S["metadata"]
        got = {}
        for n in md.dtype.names:
            v = md[n][0, 0]
            arr = np.ravel(v)
            if arr.size <= 3:
                got[n] = arr[0] if arr.size else v
        print("   metadata:", got)
