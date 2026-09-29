# -*- coding: utf-8 -*-
"""Check matched runs across the FE500 algorithms (six baselines + PACDIS/NoBatchDist)."""
import os
import re
import numpy as np

BASE = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
SUBS = {"10": "10目标\\n30\\FE500", "15": "15目标\\FE500", "20": "20目标\\FE500"}
ALGS = ["REMO", "PCSAEA", "CSEA", "HES_EA", "SSDE", "SAMOEATL2M",
        "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"]

for M, sub in SUBS.items():
    root = os.path.join(BASE, sub)
    per = {}
    for alg in ALGS:
        d = os.path.join(root, alg)
        ids = {}
        for f in os.listdir(d):
            m = re.match(r".*_([A-Z]+\d+)_M\d+_D\d+_(\d+)\.mat$", f)
            if m:
                ids.setdefault(m.group(1), set()).add(int(m.group(2)))
        per[alg] = ids
    probs = sorted(set().union(*[set(v) for v in per.values()]))
    print("===== M =", M)
    # global intersection across algorithms, per problem
    for p in probs:
        sets = [per[a].get(p, set()) for a in ALGS]
        inter = set.intersection(*sets) if all(sets) else set()
        union = set.union(*sets) if any(sets) else set()
        flag = "" if len(inter) == 20 else "   <-- matched runs = %d" % len(inter)
        print("  %-6s matched=%2d union=%2d%s" % (p, len(inter), len(union), flag))
