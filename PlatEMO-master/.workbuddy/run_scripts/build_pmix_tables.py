# -*- coding: utf-8 -*-
"""
Build the current-configuration pMix sensitivity table (NoBatchDist / PACDIS)
for the manuscript, from the PlatEMO exports on the work machine.

Data layout (work machine):
  C:\\Users\\lsx\\Desktop\\REMOandDREMO测试集\\{10目标\\n30 | 20目标}\\
      REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist[_PMix{000,025,075,100}]\\
          ..._{PROB}_M{M}_D{D}_{run}.mat      run = 1..20

Each .mat carries metric.IGD and metric.IGDp as a 30-point evaluation trajectory;
the last entry is the final-budget value.  p_mix = 0.50 is the NoBatchDist
(original) version; the other settings are separate algorithm folders.

Outputs:
  - experiments/pmix_current_igdplus_table.tex   (main, IGD+)
  - experiments/pmix_current_igd_table.tex       (IGD, for comparison)
  - AdaMao实验表\\lambdat030版本\\pMix灵敏度_NoBatchDist\\*.xlsx / *.md
"""
import os
import re
import numpy as np
from scipy.io import loadmat
from scipy.stats import wilcoxon

BASE = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
TEXDIR = r"D:\PlatEMO-master\论文写作\experiments"
ARCHIVE = r"C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\pMix灵敏度_NoBatchDist"

PROBS = ["DTLZ2", "DTLZ4", "DTLZ7", "WFG1", "WFG3", "WFG8"]
SETTINGS = [0.0, 0.25, 0.5, 0.75, 1.0]
BASE_PMIX = 0.5
NRUN = 20


def folder(M, pmix):
    suffix = "NoBatchDist" if pmix == BASE_PMIX else "NoBatchDist_PMix%03d" % int(round(pmix * 100))
    sub = "10目标\\n30" if M == 10 else "20目标"
    return os.path.join(BASE, sub, "REMO_UniformMix_Pruned_Weighted_Lambdat030_" + suffix)


def load_final(dirpath, prob, metric):
    """run id -> final value of the evaluation trajectory, plus trajectory length."""
    vals, deps = {}, {}
    pat = re.compile(r"_%s_M\d+_D\d+_(\d+)\.mat$" % prob)
    for f in os.listdir(dirpath):
        m = pat.search(f)
        if not m:
            continue
        d = loadmat(os.path.join(dirpath, f), squeeze_me=True, struct_as_record=False)["metric"]
        arr = np.atleast_1d(getattr(d, metric)).astype(float)
        vals[int(m.group(1))] = float(arr[-1])
        deps[int(m.group(1))] = int(arr.size)
    return vals, deps


def fmt(v, digits=4):
    s = "%.*e" % (digits, v)
    mant, exp = s.split("e")
    e = int(exp)
    return "%se%s%d" % (mant, "+" if e >= 0 else "-", abs(e))


NPT = {}


def fmt_std(v):
    return fmt(v, 2)


def star(p, better):
    if p is None:
        return "="
    if p < 0.05:
        return "+" if better else "-"
    return "="


def collect(metric):
    """data[M][prob][pmix] = (mean, std, per-run array, stars vs 0.5, ranks)"""
    data, pairinfo = {}, {}
    for M in (10, 20):
        data[M], pairinfo[M] = {}, {}
        for prob in PROBS:
            per = {}
            ref = None
            for pmix in SETTINGS:
                vals, deps = load_final(folder(M, pmix), prob, metric)
                missing = [r for r in range(1, NRUN + 1) if r not in vals]
                if missing:
                    raise SystemExit("missing runs %s in %s %s pmix=%s" % (missing, M, prob, pmix))
                lens = sorted(set(deps.values()))
                NPT.setdefault(metric, {}).setdefault((M, prob), set()).update(lens)
                arr = np.array([vals[r] for r in range(1, NRUN + 1)])
                per[pmix] = arr
                if pmix == BASE_PMIX:
                    ref = arr
            data[M][prob] = per
            # paired test vs 0.5
            stars = {}
            for pmix in SETTINGS:
                if pmix == BASE_PMIX:
                    stars[pmix] = ""
                    continue
                diff = per[pmix] - ref
                if np.allclose(diff, 0):
                    p = None
                else:
                    try:
                        p = wilcoxon(per[pmix], ref, zero_method="wilcox").pvalue
                    except ValueError:
                        p = None
                stars[pmix] = star(p, per[pmix].mean() < ref.mean())
            data[M][prob] = {"runs": per, "stars": stars}
    return data


def build_metric_block(M, data, metric_label):
    rows, ranksum = [], {s: [] for s in SETTINGS}
    for prob in PROBS:
        rec = data[M][prob]
        means = {s: rec["runs"][s].mean() for s in SETTINGS}
        order = sorted(SETTINGS, key=lambda s: means[s])
        rk = {s: i + 1 for i, s in enumerate(order)}
        for s in SETTINGS:
            ranksum[s].append(rk[s])
        best = order[0]
        D = 31 if prob == "WFG3" else 30
        cells = []
        for s in SETTINGS:
            arr = rec["runs"][s]
            st = rec["stars"][s]
            sup = "" if st == "" else "^{%s}" % st
            body = "$%s\\;(%s)%s$" % (fmt(arr.mean()), fmt_std(arr.std(ddof=1)), sup)
            if s == best:
                body = "\\bestcell" + body
            cells.append(body)
        rows.append("%s & %d & %s \\\\" % (prob, D, " & ".join(cells)))
    avg = {s: float(np.mean(ranksum[s])) for s in SETTINGS}
    best_avg = min(SETTINGS, key=lambda s: avg[s])
    rank_cells = []
    for s in SETTINGS:
        c = "$%.2f$" % avg[s]
        if s == best_avg:
            c = "\\bestcell" + c
        rank_cells.append(c)
    cnt = {}
    for s in SETTINGS:
        if s == BASE_PMIX:
            cnt[s] = None
            continue
        t = [data[M][p]["stars"][s] for p in PROBS]
        cnt[s] = "%d/%d/%d" % (t.count("+"), t.count("-"), t.count("="))
    cnt_cells = [(cnt[s] if cnt[s] else "--") for s in SETTINGS]
    return rows, rank_cells, cnt_cells, avg


def build_tex(data, metric_label, caption_metric, label_suffix):
    out = []
    out.append("% Auto-generated by .workbuddy/run_scripts/build_pmix_tables.py -- do not edit by hand.")
    out.append("\\begin{table*}[tp]")
    out.append("\\centering")
    out.append("\\caption{Sensitivity of the NoBatchDist (PACDIS) configuration to the switching "
               "probability $p_{\\mathrm{mix}}$ at $M=10$ and $M=20$ (%s, %d runs per cell; "
               "$p_{\\mathrm{mix}}=0.50$ is the default reported elsewhere).}" % (caption_metric, NRUN))
    out.append("\\label{tab:exp:pmix%s}" % label_suffix)
    out.append("\\footnotesize")
    out.append("\\setlength{\\tabcolsep}{3.6pt}")
    out.append("\\renewcommand{\\arraystretch}{1.08}")
    out.append("\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}lcccccc@{}}")
    out.append("\\toprule")
    out.append("Problem & $D$ & $p_{\\mathrm{mix}}=0$ & $0.25$ & $0.50$ & $0.75$ & $1.00$ \\\\")
    out.append("\\midrule")
    blocks = {}
    for ci, M in enumerate((10, 20)):
        rows, rank_cells, cnt_cells, avg = build_metric_block(M, data, metric_label)
        blocks[M] = (rank_cells, cnt_cells, avg)
        out.append("\\multicolumn{7}{c}{\\textit{%d-objective problems}} \\\\" % M)
        out.append("\\midrule")
        out.extend(rows)
        out.append("\\midrule")
        out.append("\\multicolumn{2}{l}{Average rank} & %s \\\\" % " & ".join(rank_cells))
        out.append("\\multicolumn{2}{l}{$+/-/=$ vs. $0.50$} & %s \\\\" % " & ".join(cnt_cells))
        if ci == 0:
            out.append("\\midrule")
    # overall
    ov_rank, ov_cnt = {}, {}
    for s in SETTINGS:
        ov_rank[s] = float(np.mean([blocks[M][2][s] for M in (10, 20)]))
        if s == BASE_PMIX:
            ov_cnt[s] = "--"
        else:
            t = [data[M][p]["stars"][s] for M in (10, 20) for p in PROBS]
            ov_cnt[s] = "%d/%d/%d" % (t.count("+"), t.count("-"), t.count("="))
    best_ov = min(SETTINGS, key=lambda s: ov_rank[s])
    orc = []
    for s in SETTINGS:
        c = "$%.2f$" % ov_rank[s]
        if s == best_ov:
            c = "\\bestcell" + c
        orc.append(c)
    out.append("\\multicolumn{2}{l}{Overall average rank} & %s \\\\" % " & ".join(orc))
    out.append("\\multicolumn{2}{l}{Overall $+/-/=$ vs. $0.50$} & %s \\\\" % " & ".join([ov_cnt[s] for s in SETTINGS]))
    out.append("\\bottomrule")
    out.append("\\end{tabular*}")
    out.append("\\par\\smallskip")
    out.append("\\begin{minipage}{\\textwidth}\\footnotesize")
    out.append("Smaller %s is better; shaded cells mark the best mean within each row and the best "
               "average rank. Parentheses give the standard deviation over %d independent runs. "
               "Superscripts report a paired Wilcoxon signed-rank test against $p_{\\mathrm{mix}}=0.50$ "
               "on identical seeds: $+$ means the setting is significantly better, $-$ significantly "
               "worse, and $=$ no significant difference at $\\alpha=0.05$. Average ranks are computed "
               "from the five mean values within each problem." % (caption_metric, NRUN))
    out.append("\\end{minipage}")
    out.append("\\end{table*}")
    return "\n".join(out) + "\n"


def build_markdown(data, metric_label):
    lines = ["# pMix sensitivity, NoBatchDist (PACDIS) configuration", "",
             "Metric: %s, %d runs per cell, last evaluation checkpoint (FE budget of the exported runs)." % (metric_label, NRUN),
             "Significance: paired Wilcoxon signed-rank vs p_mix=0.50 on identical seeds, alpha=0.05.", ""]
    for M in (10, 20):
        lines.append("## M = %d" % M)
        lines.append("")
        lines.append("| Problem | D | " + " | ".join("%.2f" % s for s in SETTINGS) + " |")
        lines.append("|---|---|" + "---|" * len(SETTINGS))
        for prob in PROBS:
            rec = data[M][prob]
            D = 31 if prob == "WFG3" else 30
            cells = []
            for s in SETTINGS:
                arr = rec["runs"][s]
                st = rec["stars"][s] if s != BASE_PMIX else ""
                cells.append("%s (%s) %s" % (fmt(arr.mean()), fmt_std(arr.std(ddof=1)), st))
            lines.append("| %s | %d | %s |" % (prob, D, " | ".join(cells)))
        # ranks
        means = {p: {s: data[M][p]["runs"][s].mean() for s in SETTINGS} for p in PROBS}
        rk = {s: [] for s in SETTINGS}
        for p in PROBS:
            order = sorted(SETTINGS, key=lambda s: means[p][s])
            for i, s in enumerate(order):
                rk[s].append(i + 1)
        lines.append("| **Avg rank** | | " + " | ".join("%.2f" % np.mean(rk[s]) for s in SETTINGS) + " |")
        cnt = []
        for s in SETTINGS:
            if s == BASE_PMIX:
                cnt.append("--")
            else:
                t = [data[M][p]["stars"][s] for p in PROBS]
                cnt.append("%d/%d/%d" % (t.count("+"), t.count("-"), t.count("=")))
        lines.append("| **+/-/= vs 0.50** | | " + " | ".join(cnt) + " |")
        lines.append("")
    return "\n".join(lines) + "\n"


def write_xlsx(path, data):
    from openpyxl import Workbook
    from openpyxl.styles import Font, Alignment, Border, Side, PatternFill
    wb = Workbook()
    thin = Side(style="thin", color="999999")
    bd = Border(left=thin, right=thin, top=thin, bottom=thin)
    fnt = Font(name="Times New Roman", size=11)
    fntb = Font(name="Times New Roman", size=11, bold=True)
    ctr = Alignment(horizontal="center", vertical="center")
    fill_best = PatternFill("solid", fgColor="D9E2F3")

    for metric in ("IGDp", "IGD"):
        d = collect(metric)
        ws = wb.create_sheet(metric)
        hdr = ["M", "Problem", "D", "p_mix", "mean", "std", "vs_pmix050"] + ["run%d" % r for r in range(1, NRUN + 1)]
        ws.append(hdr)
        for M in (10, 20):
            for prob in PROBS:
                rec = d[M][prob]
                means = {s: rec["runs"][s].mean() for s in SETTINGS}
                best = min(SETTINGS, key=lambda s: means[s])
                D = 31 if prob == "WFG3" else 30
                for s in SETTINGS:
                    arr = rec["runs"][s]
                    row = [M, prob, D, "%.2f" % s, float("%.4e" % arr.mean()),
                           float("%.4e" % arr.std(ddof=1)),
                           (rec["stars"][s] if s != BASE_PMIX else "ref")] + list(arr)
                    ws.append(row)
                    i = ws.max_row
                    for c in range(1, len(hdr) + 1):
                        ws.cell(i, c).border = bd
                        ws.cell(i, c).alignment = ctr
                        ws.cell(i, c).font = fnt
                    for c in range(5, len(hdr) + 1):
                        ws.cell(i, c).number_format = "0.0000e+00"
                    if s == best:
                        for c in range(1, len(hdr) + 1):
                            ws.cell(i, c).fill = fill_best
        for c in range(1, len(hdr) + 1):
            ws.cell(1, c).font = fntb
            ws.cell(1, c).alignment = ctr
            ws.cell(1, c).border = bd
    wb.remove(wb["Sheet"])
    wb.save(path)


def main():
    os.makedirs(ARCHIVE, exist_ok=True)
    os.makedirs(TEXDIR, exist_ok=True)

    for metric, caption, suffix, fname in (
            ("IGDp", "IGD$^+$", ":igdplus", "pmix_current_igdplus_table.tex"),
            ("IGD", "IGD", ":igd", "pmix_current_igd_table.tex")):
        d = collect(metric)
        tex = build_tex(d, metric, caption, suffix)
        p = os.path.join(TEXDIR, fname)
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(tex)
        print("wrote", p)
        md = build_markdown(d, caption)
        mp = os.path.join(ARCHIVE, "pMix_NoBatchDist_%s.md" % metric)
        with open(mp, "w", encoding="utf-8", newline="\n") as f:
            f.write(md)
        print("wrote", mp)

    print("\ntrajectory lengths (should be a single value per M x problem):")
    for metric in NPT:
        for (M, prob) in sorted(NPT[metric]):
            print("  %-5s M=%-3d %-6s %s" % (metric, M, prob, sorted(NPT[metric][(M, prob)])))

    xp = os.path.join(ARCHIVE, "pMix_NoBatchDist_sensitivity.xlsx")
    write_xlsx(xp, None)
    print("wrote", xp)


if __name__ == "__main__":
    main()
