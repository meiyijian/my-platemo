"""Render the manuscript's eight panels from frozen FE-aligned means.

Use --refresh to read the user's existing eight-panel preview data sources.
The default run only needs convergence_eight/means.csv and preserves its values.
Before the first observation, curves remain absent (no backward extension).
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator

HERE = Path(__file__).resolve().parent
OUT = HERE / "convergence_eight"
PACDIS = "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
ORDER = [PACDIS, "REMO", "PCSAEA", "CSEA", "HES_EA", "SSDE", "PIEA"]
LABELS = ["PACDIS", "REMO", "PC-SAEA", "CSEA", "HES-EA", "SSDE", "PIEA"]
COLORS = ["#B23A48", "#24658C", "#5C5187", "#28756B", "#AD5F25", "#776193", "#6D7680"]
MARKERS = ["D", "^", "s", "*", "o", "x", "+"]
PANELS = [("WFG7", 10), ("WFG7", 15), ("WFG7", 20), ("WFG2", 10),
          ("WFG2", 15), ("WFG2", 20), ("DTLZ1", 10), ("WFG3", 10)]
GRID = np.arange(100, 501)


def refresh():
    source = HERE / "build_convergence_eight_preview.py"
    spec = importlib.util.spec_from_file_location("preview_source", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    records, comparisons, provenance = [], [], []
    inputs = {source}
    for prob, m in PANELS:
        means = module.means_for(prob, m)
        if m == 10:
            csv = (HERE.parent / "experiments" / "fe500_convergence_wfg3" / "mean_igdp_fe500.csv"
                   if prob == "WFG3" else
                   HERE.parent / "experiments" / "fe500_convergence" / "convergence_mean_igdp_fe500.csv")
            inputs.add(csv)
            frame = pd.read_csv(csv)
            frame = frame[frame.Problem == prob]
            for alg in ORDER:
                sub = frame[frame.Algorithm == alg].sort_values("FE")
                before = means[alg].copy()
                # The source CSV already contains unit-FE means. Preserve those
                # exact values and remove only preview extrapolation before them.
                first = int(sub.FE.min())
                means[alg][GRID < first] = np.nan
                assert np.array_equal(before[GRID >= first], means[alg][GRID >= first], equal_nan=True)
                comparisons.append({"problem": prob, "M": m, "algorithm": alg,
                                    "removed_pre_observation_points": int(np.isfinite(before[GRID < first]).sum()),
                                    "recorded_values_unchanged": True})
        else:
            for alg in ORDER[:-1]:
                for run in range(1, 21):
                    hits = list((module.ROOT / module.SUBDIR[m] / alg).glob(f"{alg}_{prob}_M{m}_D*_{run}.mat"))
                    if len(hits) != 1:
                        raise ValueError(f"ambiguous source: {alg}/{prob}/{m}/{run}")
                    inputs.add(hits[0])
        inputs.update(module.PIEA_WORST.glob(f"PIEA_{prob}_M{m}_D*_*.mat"))
        for alg in ORDER:
            vals = means[alg]
            assert np.isfinite(vals[-1]) and np.all(vals[np.isfinite(vals)] >= 0)
            for fe, value in zip(GRID, vals):
                if np.isfinite(value):
                    records.append((prob, m, alg, int(fe), float(value), 20))
            provenance.append({"problem": prob, "M": m, "algorithm": alg,
                               "first_FE": int(GRID[np.isfinite(vals)][0]), "endpoint": float(vals[-1])})
    pd.DataFrame(records, columns=["Problem", "M", "Algorithm", "FE", "MeanIGDp", "Runs"]).to_csv(OUT / "means.csv", index=False)
    report = {"source_preview": str(source), "budget": 500,
              "alignment": "unit FE grid, previous-snapshot hold; no pre-observation extrapolation",
              "sampling": "unchanged from the user-supplied eight-panel preview",
              "corrections": comparisons, "curves": provenance,
              "inputs": [{"path": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                         for p in sorted(inputs)]}
    (OUT / "manifest.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")


def style():
    plt.rcParams.update({
        "font.family": "serif", "font.serif": ["Times New Roman"],
        "mathtext.fontset": "stix", "font.size": 6.2,
        "axes.titlesize": 6.2, "axes.labelsize": 6.0,
        "xtick.labelsize": 5.8, "ytick.labelsize": 5.8,
        "axes.linewidth": 0.55, "pdf.fonttype": 42, "ps.fonttype": 42,
    })


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(exist_ok=True)
    if args.refresh:
        refresh()
    style()
    data = pd.read_csv(OUT / "means.csv")
    for k, (prob, m) in enumerate(PANELS, 1):
        fig, ax = plt.subplots(figsize=(44 / 25.4, 36 / 25.4))
        current = data[(data.Problem == prob) & (data.M == m)]
        for alg, color, marker in zip(ORDER, COLORS, MARKERS):
            sub = current[current.Algorithm == alg].sort_values("FE")
            fe, values = sub.FE.to_numpy(), sub.MeanIGDp.to_numpy()
            mark = fe % 50 == 0
            mark[0] = mark[-1] = True
            ax.plot(fe, values, color=color, linewidth=1.4 if alg == PACDIS else 0.9,
                    marker=marker, markevery=np.flatnonzero(mark).tolist(),
                    markersize=3.0 if alg == PACDIS else 2.8,
                    markerfacecolor=color if alg == PACDIS else "none",
                    markeredgecolor=color, markeredgewidth=0.7,
                    zorder=6 if alg == PACDIS else 4)
        lo, hi = current.MeanIGDp.min(), current.MeanIGDp.max()
        span = max(hi - lo, 1e-12)
        ax.set_ylim(lo - .05 * span, hi + .10 * span)
        ax.set_xlim(95, 505)
        ax.set_xticks([100, 200, 300, 400, 500])
        ax.yaxis.set_major_locator(MaxNLocator(nbins=4, steps=[1, 2, 2.5, 5, 10]))
        ax.set_title(f"({chr(96 + k)}) {prob}, $M={m}$", loc="left", pad=3)
        ax.set_xlabel("FEs", labelpad=1.2)
        ax.set_ylabel(r"IGD$^+$", labelpad=1.5)
        ax.set_axisbelow(True)
        ax.grid(True, color="#C7C7C7", linestyle=":", linewidth=.35, alpha=.7)
        fig.subplots_adjust(left=.225, right=.975, top=.885, bottom=.245)
        for ext in ["pdf", "png"]:
            fig.savefig(OUT / f"panel_{k:02d}_{prob}_m{m}.{ext}", dpi=400, facecolor="white")
        plt.close(fig)
    handles = [Line2D([0], [0], color=c, linewidth=1.4 if a == PACDIS else .9,
                      marker=mk, markersize=3, markerfacecolor=c if a == PACDIS else "none",
                      markeredgewidth=.7) for a, c, mk in zip(ORDER, COLORS, MARKERS)]
    fig = plt.figure(figsize=(176 / 25.4, 5 / 25.4))
    fig.legend(handles, LABELS, loc="center", ncol=7, fontsize=6.4, frameon=False,
               handlelength=1.6, columnspacing=1.1, handletextpad=.45)
    fig.savefig(OUT / "legend.pdf")
    fig.savefig(OUT / "legend.png", dpi=400)
    plt.close(fig)
    # Vector composition also supplies the Chinese mirror's single preview.
    import pymupdf
    merged = pymupdf.open()
    page = merged.new_page(width=176 / 25.4 * 72, height=77 / 25.4 * 72)
    with pymupdf.open(OUT / "legend.pdf") as src:
        page.show_pdf_page(pymupdf.Rect(0, 0, page.rect.width, 5 / 25.4 * 72), src, 0)
    w, h = 44 / 25.4 * 72, 36 / 25.4 * 72
    for k, (prob, m) in enumerate(PANELS):
        x, y = k % 4 * w, 5 / 25.4 * 72 + k // 4 * h
        with pymupdf.open(OUT / f"panel_{k+1:02d}_{prob}_m{m}.pdf") as src:
            page.show_pdf_page(pymupdf.Rect(x, y, x + w, y + h), src, 0)
    merged.save(OUT / "convergence_eight.pdf")
    page.get_pixmap(dpi=250).save(OUT / "convergence_eight.png")
    print(data[data.FE == 500][["Problem", "M", "Algorithm", "MeanIGDp"]].to_string(index=False))


if __name__ == "__main__":
    main()
