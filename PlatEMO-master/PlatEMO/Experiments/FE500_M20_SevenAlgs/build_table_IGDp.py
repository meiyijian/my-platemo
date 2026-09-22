# Build the FE500 / M=20 / D=30  seven-algorithm IGDp comparison table over
# runs 1-10, anchored on PACDIS.
#
#   python build_table_runs10_IGDp.py [nRuns]        (default 10)
#
# Reads the FINAL snapshot of metric.IGDp from every stored run, writes
#   FE500_M20_runs10_IGDp.csv   machine-readable (mean, std, symbol per cell)
#   FE500_M20_runs10_IGDp.md    paper-style table (Markdown)
# next to this script and prints the same table to stdout.
#
# Conventions (same as the rest of the project):
#   cell text   "%.4e (%.2e)" with the exponent folded: e+0 -> e+ , e-0 -> e-
#   symbol      vs the PACDIS anchor, p < 0.05; IGDp is min-is-better, so
#               '+' = significantly better than PACDIS,
#               '-' = significantly worse, '=' = no significant difference
#   anchor      PACDIS is the LAST column and carries no symbol
#   best        the lowest mean of the row is shown in bold (blue in the xlsx)
#
# Two significance tests are computed because the seeds are PAIRED:
#   wilcoxon  paired signed-rank on the common runs (the correct test here)
#   ranksum   unpaired Mann-Whitney (asymptotic, tie-corrected) -- this is what
#             the paper's xlsx tables use, kept for consistency with them
# The table uses the PAIRED result; the tally of both is printed so any
# disagreement is visible instead of silent.
import os
import sys
import numpy as np
from scipy.io import loadmat
from scipy.stats import wilcoxon, mannwhitneyu

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("FE500_M20_OUTPUT_ROOT",
                      r"D:\REMOandDREMO测试集\20目标\FE500")
ANCHOR = "PACDIS"
# label -> (output folder, MAT file prefix = class name)
ALGS = {
    "REMO":       ("REMO", "REMO"),
    "PCSAEA":     ("PCSAEA", "PCSAEA"),
    "CSEA":       ("CSEA", "CSEA"),
    "HES_EA":     ("HES_EA", "HES_EA"),
    "SSDE":       ("SSDE", "SSDE"),
    "SAMOEATL2M": ("SAMOEATL2M", "SAMOEATL2M"),
    "PACDIS":     ("REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
                   "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"),
}
ORDER = ["REMO", "PCSAEA", "CSEA", "HES_EA", "SSDE", "SAMOEATL2M", "PACDIS"]
PROBS = ["DTLZ1", "DTLZ2", "DTLZ3", "DTLZ4", "DTLZ5", "DTLZ6", "DTLZ7",
         "WFG1", "WFG2", "WFG3", "WFG4", "WFG5", "WFG6", "WFG7", "WFG8", "WFG9"]


def load(alg, prob, runs, metric="IGDp"):
    folder, cls = ALGS[alg]
    out = {}
    for r in runs:
        f = None
        for d in (30, 31):
            c = os.path.join(ROOT, folder, "%s_%s_M20_D%d_%d.mat" % (cls, prob, d, r))
            if os.path.isfile(c):
                f = c
                break
        if f is None:
            continue
        m = loadmat(f)["metric"][0, 0]
        if metric not in m.dtype.names:
            continue
        out[r] = float(np.asarray(m[metric]).ravel()[-1])
    return out


def fmt(x):
    s = "%.4e (%.2e)" % (x[0], x[1])
    return s.replace("e+0", "e+").replace("e-0", "e-")


def main():
    nruns = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    runs = list(range(1, nruns + 1))

    D = {a: {p: load(a, p, runs) for p in PROBS} for a in ALGS}
    missing = [(a, p) for a in ALGS for p in PROBS if len(D[a][p]) < nruns]

    cols, tally, tally2 = [], {}, {}
    for a in ORDER:
        if a != ANCHOR:
            cols.append(a)
            tally[a] = [0, 0, 0]
            tally2[a] = [0, 0, 0]

    rows = []
    for p in PROBS:
        aV = D[ANCHOR][p]
        cell, means = {}, {}
        for a in ORDER:
            v = D[a][p]
            if not v:
                cell[a] = ("n/a", "", None)
                continue
            arr = np.array([v[r] for r in sorted(v)])
            means[a] = arr.mean()
        best = min(means.values()) if means else None
        for a in ORDER:
            v = D[a][p]
            if not v:
                continue
            arr = np.array([v[r] for r in sorted(v)])
            mean, std = arr.mean(), arr.std(ddof=1) if len(arr) > 1 else 0.0
            sym = ""
            if a != ANCHOR:
                rr = [r for r in sorted(v) if r in aV]
                x = np.array([v[r] for r in rr])
                y = np.array([aV[r] for r in rr])
                if len(rr) >= 5:
                    try:
                        pv = wilcoxon(x, y).pvalue
                    except Exception:
                        pv = 1.0
                    sym = "=" if (pv >= 0.05 or x.mean() == y.mean()) else \
                          ("+" if x.mean() < y.mean() else "-")
                    tally[a]["+-=".index(sym)] += 1
                    try:
                        p2 = mannwhitneyu(x, y, alternative="two-sided",
                                          method="asymptotic").pvalue
                    except Exception:
                        p2 = 1.0
                    s2 = "=" if (p2 >= 0.05 or x.mean() == y.mean()) else \
                         ("+" if x.mean() < y.mean() else "-")
                    tally2[a]["+-=".index(s2)] += 1
                else:
                    sym = "?"
            cell[a] = (fmt((mean, std)), sym, mean)
        rows.append((p, cell, best))

    # ---- Markdown ----
    hdr = "| Problem | " + " | ".join(ORDER) + " |"
    sep = "|---" * (len(ORDER) + 1) + "|"
    lines = ["# FE500 / M=20 / D=30 — final IGDp, runs %d–%d" % (runs[0], runs[-1]), "",
             "Anchor = %s (last column, no symbol). Symbols: paired Wilcoxon signed-rank, "
             "p<0.05; `+` significantly better than %s, `-` worse, `=` no significant "
             "difference; IGDp is min-is-better. **Bold** = lowest mean of the row."
             % (ANCHOR, ANCHOR), "", hdr, sep]
    for p, cell, best in rows:
        cs = []
        for a in ORDER:
            txt, sym, mean = cell[a]
            if txt == "n/a":
                cs.append("n/a")
                continue
            s = txt + (" " + sym if sym else "")
            if best is not None and mean == best:
                s = "**" + s + "**"
            cs.append(s)
        lines.append("| %s | %s |" % (p, " | ".join(cs)))
    lines += ["", "## Tally vs %s (16 problems)" % ANCHOR, "",
              "| Algorithm | + better | - worse | = ns |", "|---|---|---|---|"]
    for a in cols:
        lines.append("| %s | %d | %d | %d |" % (a, tally[a][0], tally[a][1], tally[a][2]))
    lines += ["", "Same tally using the unpaired Mann-Whitney (the paper tables' statistics) — "
              "shown to expose any disagreement:", "",
              "| Algorithm | + | - | = |", "|---|---|---|---|"]
    for a in cols:
        lines.append("| %s | %d | %d | %d |" % (a, tally2[a][0], tally2[a][1], tally2[a][2]))

    md = os.path.join(HERE, "FE500_M20_runs%d_IGDp.md" % nruns)
    with open(md, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

    # ---- CSV ----
    csv = os.path.join(HERE, "FE500_M20_runs%d_IGDp.csv" % nruns)
    with open(csv, "w", encoding="utf-8") as fh:
        fh.write("Problem," + ",".join("%s_mean,%s_std,%s_sym" % (a, a, a) for a in ORDER) + "\n")
        for p, cell, _ in rows:
            out = [p]
            for a in ORDER:
                txt, sym, _ = cell[a]
                if txt == "n/a":
                    out += ["", "", ""]
                else:
                    mean, std = txt.split(" (")
                    out += [mean, std.rstrip(")"), sym]
            fh.write(",".join(out) + "\n")

    print("\n".join(lines))
    print("\nwritten: %s\nwritten: %s" % (md, csv))
    if missing:
        print("\n!! cells with fewer than %d runs: %s" % (nruns, missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
