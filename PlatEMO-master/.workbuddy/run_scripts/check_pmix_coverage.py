import os, glob, re
from scipy.io import loadmat
import numpy as np

B = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
PROBS = ["DTLZ2", "DTLZ4", "DTLZ7", "WFG1", "WFG3", "WFG8"]

variants = {
    "10": ("10目标\\n30", "PMix050"),
    "20": ("20目标", "PMix050"),
}
for M, (sub, _) in variants.items():
    print(f"===== M={M}  dir={sub}")
    d = os.path.join(B, sub)
    for name in sorted(os.listdir(d)):
        if "Lambdat030" not in name:
            continue
        if not ("NoBatchDist" in name):
            continue
        full = os.path.join(d, name)
        if not os.path.isdir(full):
            continue
        cnt = {}
        miss = []
        bad = []
        for f in os.listdir(full):
            if not f.endswith(".mat"):
                continue
            mm = re.search(r"_(DTLZ\d|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$", f)
            if not mm:
                bad.append(f)
                continue
            prob = mm.group(1)
            if prob in PROBS:
                cnt.setdefault(prob, []).append(int(mm.group(4)))
        print(f"  {name}")
        for p in PROBS:
            r = sorted(cnt.get(p, []))
            ig = os.path.join(full, "*")
            print(f"     {p}: n={len(r)} runs={r[:3]}...{r[-2:] if r else ''}")
        if bad:
            print("     unmapped:", bad[:3])
