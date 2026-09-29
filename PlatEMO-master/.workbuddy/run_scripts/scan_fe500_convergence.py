# -*- coding: utf-8 -*-
"""Scan the FE500 exports (six baselines + PACDIS/NoBatchDist) for convergence plotting."""
import os
import re
import numpy as np
from scipy.io import loadmat

BASE = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
SUBS = {"10": "10目标\\n30\\FE500", "15": "15目标\\FE500", "20": "20目标\\FE500"}
ALGS = ["REMO", "PCSAEA", "CSEA", "HES_EA", "SSDE", "SAMOEATL2M",
        "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"]

for M, sub in SUBS.items():
    root = os.path.join(BASE, sub)
    if not os.path.isdir(root):
        print("MISSING", root)
        continue
    print("===== M =", M, "|", sub)
    for alg in ALGS:
        d = os.path.join(root, alg)
        if not os.path.isdir(d):
            print("  %-52s MISSING DIR" % alg)
            continue
        probs, runs, npt = {}, {}, set()
        for f in os.listdir(d):
            m = re.match(r".*_([A-Z]+\d+)_M\d+_D\d+_(\d+)\.mat$", f)
            if not m:
                continue
            p, r = m.group(1), int(m.group(2))
            probs.setdefault(p, []).append(r)
        # trajectory length from one file
        f0 = sorted(os.listdir(d))[0]
        try:
            mm = loadmat(os.path.join(d, f0), squeeze_me=True, struct_as_record=False)["metric"]
            npt = {f: np.atleast_1d(getattr(mm, f)).size for f in mm._fieldnames}
        except Exception as e:
            npt = "err %s" % e
        nprob = len(probs)
        runsets = sorted(set(len(v) for v in probs.values()))
        print("  %-52s files=%3d probs=%2d runs=%s metric=%s"
              % (alg, sum(len(v) for v in probs.values()), nprob, runsets, npt))
