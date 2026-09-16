"""Build the Section 4.6 convergence figures for the PACDIS manuscript.

Source: figures/source_data/convergence_igd.csv, exported by
.workbuddy/run_scripts/ExportConvergenceCSV.m from the saved PlatEMO result
files of the main study (IGD stored per snapshot, run with 'save',30).

Two sets of deliverables come out of the same drawing code:

* six single-panel figures, fig_convergence_<problem>_m<M>.{pdf,svg,png},
  each sized for one column. These are the files included in the paper, so
  that no panel is scaled down by a combined layout.
* one combined figure, fig_convergence.{pdf,svg,png}, kept as an overview.

Style: median IGD traces of PACDIS and the six baselines on WFG7 and WFG8 at
M = 10, 15 and 20. Runs 1-20 are used for every algorithm (the matched
subset; the baselines have 30 stored runs, PACDIS 20). Traces are aligned on
a unit-FE grid by zero-order hold and drawn as straight polylines with one
vertex every 25 evaluations, which is the layout used by most EMTO papers.

Run:
    C:\\Users\\lsx\\.workbuddy\\binaries\\python\\envs\\default\\Scripts\\python.exe build_convergence.py
"""
from pathlib import Path
import hashlib
import json
import warnings

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator

OUT = Path(__file__).resolve().parent
DATA = OUT / 'source_data'
QA = OUT / 'qa'

INK = '#253442'
GRAY = '#6D7680'
BLUE = '#24658C'
ORANGE = '#AD5F25'
PURPLE = '#776193'
TEAL = '#28756B'

PACDIS = 'REMO_UniformMix_Pruned_Weighted_Lambdat030'
ORDER = [PACDIS, 'REMO', 'PIEA', 'CSEA', 'PCSAEA_N100', 'KRVEA_100', 'MCEAD']
LABELS = {
    PACDIS: 'PACDIS (ours)',
    'REMO': 'REMO',
    'PIEA': 'PIEA',
    'CSEA': 'CSEA',
    'PCSAEA_N100': 'PC-SAEA',
    'KRVEA_100': 'K-RVEA',
    'MCEAD': 'MCEA/D',
}
COLORS = {
    PACDIS: '#B23A48',
    'REMO': BLUE,
    'PIEA': ORANGE,
    'CSEA': TEAL,
    'PCSAEA_N100': '#5C5187',
    'KRVEA_100': '#7C828B',
    'MCEAD': '#414B54',
}
STYLES = {a: '-' for a in ORDER}   # paper style: solid lines, identity comes from colour + marker
MARKERS = {
    PACDIS: 'D',
    'REMO': 'o',
    'PIEA': '^',
    'CSEA': 's',
    'PCSAEA_N100': 'v',
    'KRVEA_100': 'x',
    'MCEAD': '+',
}
MARK_EVERY = 25     # place a vertex marker every 25 real evaluations
SHOW_BAND = False   # paper style: no shaded interquartile band

MS = [10, 15, 20]
PROBLEMS = ['WFG7', 'WFG8']
RUNS = list(range(1, 21))          # matched subset: run ids 1-20
XMIN, XMAX = 20, 305
GRID = np.arange(XMIN, XMAX + 1)
LETTERS = 'abcdef'

COMBINED_FIGSIZE = (180 / 25.4, 185 / 25.4)
SINGLE_FIGSIZE = (88 / 25.4, 66 / 25.4)

plt.rcParams.update({
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'Times', 'DejaVu Serif'],
    'mathtext.fontset': 'stix',
    'font.size': 8, 'axes.titlesize': 8.5, 'axes.labelsize': 8,
    'xtick.labelsize': 7.5, 'ytick.labelsize': 7.5,
    'legend.fontsize': 7.5, 'text.color': INK, 'axes.labelcolor': INK,
    'axes.edgecolor': INK, 'xtick.color': INK, 'ytick.color': INK,
    'axes.spines.top': True, 'axes.spines.right': True,
    'axes.linewidth': .65, 'lines.linewidth': 1.2,
    'pdf.fonttype': 42, 'ps.fonttype': 42, 'svg.fonttype': 'none',
    'savefig.facecolor': 'white', 'figure.facecolor': 'white',
    'legend.frameon': False,
})


def resample(fe, igd, grid):
    """Zero-order hold onto the common FE grid; NaN before the first snapshot."""
    fe = np.asarray(fe, float)
    igd = np.asarray(igd, float)
    keep = np.isfinite(fe) & np.isfinite(igd)
    fe, igd = fe[keep], igd[keep]
    if fe.size == 0:
        return np.full(grid.shape, np.nan)
    order = np.argsort(fe, kind='stable')
    fe, igd = fe[order], igd[order]
    # duplicated FE -> last snapshot wins
    fe_u, igd_u = [], []
    pos = 0
    while pos < fe.size:
        q = pos
        while q + 1 < fe.size and fe[q + 1] == fe[pos]:
            q += 1
        fe_u.append(fe[q])
        igd_u.append(igd[q])
        pos = q + 1
    fe_u = np.asarray(fe_u)
    igd_u = np.asarray(igd_u)
    g = np.full(grid.shape, np.nan)
    idx = np.searchsorted(fe_u, grid, side='right') - 1
    ok = idx >= 0
    g[ok] = igd_u[idx[ok]]
    return g


def load_traces():
    csv = DATA / 'convergence_igd.csv'
    df = pd.read_csv(csv)
    df = df[df['Run'].isin(RUNS)]
    traces = {}
    for (m, prob, alg), grp in df.groupby(['M', 'Problem', 'Algorithm']):
        runs = []
        for _, r in grp.groupby('Run'):
            runs.append(resample(r['FE'].to_numpy(), r['IGD'].to_numpy(), GRID))
        traces[(m, prob, alg)] = np.vstack(runs)
    return csv, df, traces


def percentiles(trace):
    """25/50/75 percentiles per grid point, ignoring not-yet-started runs."""
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', category=RuntimeWarning)
        return np.nanpercentile(trace, [25, 50, 75], axis=0)


def legend_handles():
    return [Line2D([0], [0], color=COLORS[a], linestyle='-',
                   linewidth=1.9 if a == PACDIS else 1.3,
                   marker=MARKERS[a], markersize=3.6,
                   markerfacecolor=COLORS[a] if a == PACDIS else 'none',
                   markeredgecolor=COLORS[a], markeredgewidth=0.9)
            for a in ORDER]


def draw_curves(ax, curves, mark_idx, mark_x):
    """Draw the seven median traces of one panel."""
    if SHOW_BAND:
        for alg in ORDER:
            q25, q50, q75 = curves[alg]
            if alg == PACDIS:
                ax.fill_between(GRID, q25, q75, color=COLORS[alg],
                                alpha=0.15, linewidth=0, zorder=2)
    for alg in ORDER:
        q25, q50, q75 = curves[alg]
        if alg == PACDIS:
            ax.plot(mark_x, q50[mark_idx], color=COLORS[alg],
                    linewidth=1.6, marker=MARKERS[alg], markersize=3.0,
                    markerfacecolor=COLORS[alg],
                    markeredgecolor=COLORS[alg], zorder=6)
        else:
            ax.plot(mark_x, q50[mark_idx], color=COLORS[alg],
                    linewidth=1.0, marker=MARKERS[alg], markersize=2.8,
                    markerfacecolor='none',
                    markeredgecolor=COLORS[alg],
                    markeredgewidth=0.8, zorder=4)


def panel_limits(curves, pad=0.05, pad_top=None):
    lo = min(np.nanmin(v[0]) for v in curves.values())
    hi = max(np.nanmax(v[2]) for v in curves.values())
    span = hi - lo
    if span <= 0:
        span = max(abs(hi), 1.0)
    return lo - pad * span, hi + (pad if pad_top is None else pad_top) * span


def build_single(stats, m, prob, letter):
    """One problem at one objective count, sized for a single column."""
    mark_idx = np.where(GRID % MARK_EVERY == 0)[0]
    mark_x = GRID[mark_idx]
    curves = {alg: stats[(m, prob, alg)] for alg in ORDER}
    # extra headroom on top: the seven traces fill the panel, so the legend
    # needs a clean band of its own instead of sitting on a curve
    ylo, yhi = panel_limits(curves, pad=0.05, pad_top=0.42)

    fig, ax = plt.subplots(figsize=SINGLE_FIGSIZE)
    draw_curves(ax, curves, mark_idx, mark_x)
    ax.set_title(f'({letter}) {prob}, $M={m}$', loc='left', pad=4)
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(ylo, yhi)
    ax.set_xticks([50, 100, 150, 200, 250, 300])
    ax.yaxis.set_major_locator(MaxNLocator(nbins=4, steps=[1, 2, 5, 10]))
    ax.set_xlabel('Number of real function evaluations')
    ax.set_ylabel('IGD')
    ax.legend(legend_handles(), [LABELS[a] for a in ORDER],
              loc='upper right', ncol=2, fontsize=6.5,
              columnspacing=0.9, handlelength=1.8, handletextpad=0.5,
              borderaxespad=0.4, labelspacing=0.32)
    fig.subplots_adjust(left=0.155, right=0.985, top=0.905, bottom=0.155)
    return fig


def build_combined(stats):
    """All six panels in one 3x2 layout, kept as an overview."""
    mark_idx = np.where(GRID % MARK_EVERY == 0)[0]
    mark_x = GRID[mark_idx]
    fig, axes = plt.subplots(len(MS), len(PROBLEMS),
                             figsize=COMBINED_FIGSIZE, sharex=True)
    for i, m in enumerate(MS):
        curves_row = {}
        for j, prob in enumerate(PROBLEMS):
            for alg in ORDER:
                curves_row[(j, alg)] = stats[(m, prob, alg)]
        ylo, yhi = panel_limits(curves_row)
        for j, prob in enumerate(PROBLEMS):
            ax = axes[i, j]
            draw_curves(ax, {alg: curves_row[(j, alg)] for alg in ORDER},
                        mark_idx, mark_x)
            letter = LETTERS[i * len(PROBLEMS) + j]
            ax.set_title(f'({letter}) {prob}, $M={m}$', loc='left', pad=4)
            ax.set_xlim(XMIN, XMAX)
            ax.set_ylim(ylo, yhi)
            ax.set_xticks([50, 100, 150, 200, 250, 300])
            ax.yaxis.set_major_locator(MaxNLocator(nbins=5, steps=[1, 2, 5, 10]))
            if i == len(MS) - 1:
                ax.set_xlabel('Number of real function evaluations')
            if j == 0:
                ax.set_ylabel('IGD')
    fig.legend(legend_handles(), [LABELS[a] for a in ORDER],
               loc='lower center', ncol=7, bbox_to_anchor=(0.5, 0.008),
               columnspacing=1.6, handlelength=2.6)
    fig.subplots_adjust(left=0.075, right=0.995, top=0.975, bottom=0.105,
                        hspace=0.34, wspace=0.16)
    return fig


def save(fig, name, csv, panel_runs, problems, objectives):
    for ext in ('pdf', 'svg', 'png'):
        fig.savefig(OUT / f'{name}.{ext}', dpi=600, facecolor='white')
    import pymupdf
    doc = pymupdf.open(OUT / f'{name}.pdf')
    page = doc[0]
    spans = [s for b in page.get_text('dict')['blocks'] if 'lines' in b
             for l in b['lines'] for s in l['spans'] if s['text'].strip()]
    # Overflow is tested on the rendered PDF. matplotlib keeps off-range tick
    # labels in the artist tree with coordinates outside the axes even though
    # they are never painted, so an artist-level test reports false positives.
    page_w, page_h = page.rect.width, page.rect.height
    outside = [s['text'] for s in spans
               if s['bbox'][0] < -0.5 or s['bbox'][1] < -0.5
               or s['bbox'][2] > page_w + 0.5 or s['bbox'][3] > page_h + 0.5]
    if outside:
        raise ValueError(f'{name}: text outside canvas: {outside}')
    minimum = min(s['size'] for s in spans)
    if minimum < 4.99:
        raise ValueError(f'{name}: glyph below 5 pt: {minimum}')
    doc[0].get_pixmap(matrix=pymupdf.Matrix(1.8, 1.8), alpha=False).save(
        QA / f'{name}_render.png')
    manifest = {
        'figure': name,
        'source_csv': str(csv),
        'source_csv_sha256': hashlib.sha256(csv.read_bytes()).hexdigest(),
        'runs_used': RUNS,
        'algorithms': ORDER,
        'problems': problems,
        'objectives': objectives,
        'panel_runs': panel_runs,
        'alignment': 'zero-order hold on unit-FE grid, no extrapolation past the last snapshot',
        'drawing': f'vertices every {MARK_EVERY} real evaluations, straight-line joins',
        'band': ('none (paper style)' if not SHOW_BAND else
                 '25-75% interquartile range across runs, PACDIS only'),
        'markers': {a: MARKERS[a] for a in ORDER},
        'marker_every_fe': MARK_EVERY,
        'line_styles': 'all solid; identity carried by colour + marker shape',
        'page_size_mm': [round(fig.get_size_inches()[0] * 25.4, 1),
                         round(fig.get_size_inches()[1] * 25.4, 1)],
        'minimum_pdf_glyph_pt': round(minimum, 2),
        'text_outside_canvas': outside,
    }
    (OUT / f'{name}_manifest.json').write_text(
        json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'saved {name}  [{manifest["page_size_mm"][0]}x'
          f'{manifest["page_size_mm"][1]} mm, min glyph {minimum:.2f} pt]')
    plt.close(fig)


if __name__ == '__main__':
    QA.mkdir(exist_ok=True)
    csv, df, traces = load_traces()
    stats = {k: percentiles(v) for k, v in traces.items()}
    runs_for = lambda ms, ps: {f'M{m}|{p}':                       # noqa: E731
                               {a: int(traces[(m, p, a)].shape[0]) for a in ORDER}
                               for m in ms for p in ps}

    for i, m in enumerate(MS):
        for j, prob in enumerate(PROBLEMS):
            letter = LETTERS[i * len(PROBLEMS) + j]
            fig = build_single(stats, m, prob, letter)
            save(fig, f'fig_convergence_{prob.lower()}_m{m}', csv,
                 runs_for([m], [prob]), [prob], [m])

    fig = build_combined(stats)
    save(fig, 'fig_convergence', csv, runs_for(MS, PROBLEMS), PROBLEMS, MS)
