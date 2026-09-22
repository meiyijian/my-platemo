# -*- coding: utf-8 -*-
"""Coverage audit of the FE500 seven-algorithm export used by the main table.

For every (M, algorithm, problem) count the .mat files whose run id lies in
1..10, so a silently narrower mean (missing runs) cannot pass unnoticed.
Read-only: nothing is written into the dataset folder.
"""
import os
import re
import sys
from collections import defaultdict

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
ALGS = ["REMO", "SSDE", "PCSAEA", "SAMOEATL2M", "CSEA", "HES_EA",
        "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"]
PROBLEMS = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
RUNS = set(range(1, 11))


def base_dir(m):
    if m == 10:
        return os.path.join(ROOT, "10目标", "n30", "FE500")
    return os.path.join(ROOT, "%d目标" % m, "FE500")


def main():
    lines, bad = [], []
    for m in (10, 15, 20):
        base = base_dir(m)
        lines.append("=" * 100)
        lines.append("M=%d  base=%s  exists=%s" % (m, base, os.path.isdir(base)))
        if not os.path.isdir(base):
            bad.append("M=%d missing base dir" % m)
            continue
        counts = defaultdict(set)
        for alg in ALGS:
            d = os.path.join(base, alg)
            if not os.path.isdir(d):
                bad.append("M=%d %s: directory missing" % (m, alg))
                lines.append("  %-58s DIR MISSING" % alg)
                continue
            for name in os.listdir(d):
                if not name.endswith(".mat"):
                    continue
                mt = re.search(r"_M(\d+)_D(\d+)_(\d+)\.mat$", name)
                if not mt:
                    continue
                if int(mt.group(1)) != m:
                    continue
                run = int(mt.group(3))
                if run not in RUNS:
                    continue
                prob = name.rsplit("_M%d_" % m, 1)[0].split("_")[-1]
                counts[(alg, prob)].add(run)
        for alg in ALGS:
            row = []
            for prob in PROBLEMS:
                n = len(counts.get((alg, prob), ()))
                row.append("%s=%d" % (prob, n))
                if n != 10:
                    bad.append("M=%d %s %s: n=%d" % (m, alg, prob, n))
            lines.append("  %-58s %s" % (alg, " ".join(row)))
    lines.append("")
    if bad:
        lines.append("PROBLEMS (%d):" % len(bad))
        lines.extend("  " + b for b in bad)
    else:
        lines.append("OK: every (M, algorithm, problem) has exactly 10 runs in 1..10.")
    with open(sys.argv[1], "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("OK")


if __name__ == "__main__":
    main()
