import os, re, collections, sys

roots = {
    10: r"C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标",
    20: r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标",
}
algs = [
    "REMO",
    "RMEO_k_CDIS",
    "REMO_k15",
    "REMO_k",
    "REMO_UniformMix_Pruned_Weighted_Lambdat030",
    "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
    "REMO_noBatchDict_noCDIS",
    "REMO_noBatchDict_noPAQC",
]
pat = re.compile(r"^(?P<alg>.+?)_(?P<prob>DTLZ\d+|WFG\d+)_M(?P<M>\d+)_D(?P<D>\d+)_(?P<run>\d+)\.mat$", re.I)

for M, root in roots.items():
    print("#" * 90)
    print("ROOT M=%d : %s  exists=%s" % (M, root, os.path.isdir(root)))
    if not os.path.isdir(root):
        continue
    # find all mat files recursively
    info = collections.defaultdict(lambda: collections.defaultdict(set))
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            if not fn.lower().endswith(".mat"):
                continue
            m = pat.match(fn)
            if not m:
                continue
            alg = m.group("alg")
            if alg not in algs:
                continue
            key = (alg, m.group("prob").upper())
            info[key][int(m.group("run"))].add((int(m.group("M")), int(m.group("D")), dirpath))
    for a in algs:
        probs = sorted({p for (alg, p) in info if alg == a},
                       key=lambda x: (x.startswith("WFG"), int(re.sub(r"\D", "", x))))
        if not probs:
            print("  %-55s : (none)" % a)
            continue
        tot = sum(len(info[(a, p)]) for p in probs)
        print("  %-55s : %d problems, %d files" % (a, len(probs), tot))
        for p in probs:
            runs = sorted(info[(a, p)])
            ds = sorted({d for runs_ in [info[(a, p)][r] for r in runs] for (mm, d, dp) in runs_})
            ms = sorted({mm for runs_ in [info[(a, p)][r] for r in runs] for (mm, d, dp) in runs_})
            print("      %-6s runs=%-22s n=%-3d M=%-8s D=%s" % (
                p, ("%d..%d" % (runs[0], runs[-1])) if runs else "-", len(runs), ms, ds))
