# -*- coding: utf-8 -*-
"""Compare the dacefit / predictor copies that share the file name."""
import hashlib
import os

MO = r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization"
NAMES = ("dacefit", "predictor", "corrgauss", "regpoly0", "correxp")

rows = []
for dirpath, dirnames, filenames in os.walk(MO):
    for n in filenames:
        if n[:-2] in NAMES and n.endswith(".m"):
            p = os.path.join(dirpath, n)
            with open(p, "rb") as fh:
                h = hashlib.sha256(fh.read()).hexdigest()
            rel = os.path.relpath(dirpath, MO)
            rows.append((n, rel, os.path.getsize(p), h[:16]))

rows.sort()
for n, rel, size, h in rows:
    print("%-14s %-52s %7d  %s" % (n, rel, size, h))

print()
print("dacefit 副本数:", sum(1 for r in rows if r[0] == "dacefit.m"))
print("不同的 dacefit 内容版本:", sorted({r[3] for r in rows if r[0] == "dacefit.m"}))
print("predictor 副本数:", sum(1 for r in rows if r[0] == "predictor.m"))
print()
print("genpath 顺序下第一个 dacefit 会是谁 —— 按目录名字典序列出前 10 个:")
for n, rel, size, h in [r for r in rows if r[0] == "dacefit.m"][:10]:
    print("   ", rel)
