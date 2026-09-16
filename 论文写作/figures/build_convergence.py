"""Build the Section 4.7 convergence figure (fig_convergence) for the PACDIS
manuscript.

Source: figures/source_data/convergence_igd.csv, exported by
.workbuddy/run_scripts/ExportConvergenceCSV.m from the saved PlatEMO result
files of the main study (IGD stored per snapshot, run with 'save',30).

Figure: median IGD trajectories of PACDIS and the six baselines on WFG7 and
WFG8 at M = 10, 15, 20. Runs 1-20 are used for every algorithm (the matched
subset; the baselines have 30 stored runs, PACDIS 20). Traces are aligned on
a unit-FE grid by zero-order hold; the band around PACDIS is the 25-75%
interquartile range across runs. The x-axis starts at the first recorded
snapshot because the initial design already consumes evaluations.

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
import matplotlib.text
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


def build():
    csv, df, traces = load_traces()
    mark_idx = np.where(GRID % MARK_EVERY == 0)[0]
    mark_x = GRID[mark_idx]
    fig, axes = plt.subplots(
        len(MS), len(PROBLEMS),
        figsize=(180 / 25.4, 185 / 25.4),
        sharex=True,
    )
    letters = 'abcdef'
    handles = None
    for i, m in enumerate(MS):
        # shared y-limits across the two problems of one row
        row_min, row_max = np.inf, -np.inf
        curves = {}
        for j, prob in enumerate(PROBLEMS):
            for alg in ORDER:
                t = traces[(m, prob, alg)]
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore', category=RuntimeWarning)
                    q25, q50, q75 = np.nanpercentile(t, [25, 50, 75], axis=0)
                curves[(j, alg)] = (q25, q50, q75)
                row_min = min(row_min, np.nanmin(q25))
                row_max = max(row_max, np.nanmax(q75))
        span = row_max - row_min
        ylo, yhi = row_min - 0.05 * span, row_max + 0.05 * span
        for j, prob in enumerate(PROBLEMS):
            ax = axes[i, j]
            if SHOW_BAND:
                for alg in ORDER:
                    q25, q50, q75 = curves[(j, alg)]
                    if alg == PACDIS:
                        ax.fill_between(GRID, q25, q75, color=COLORS[alg],
                                        alpha=0.15, linewidth=0, zorder=2)
            for alg in ORDER:
                q25, q50, q75 = curves[(j, alg)]
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
            letter = letters[i * len(PROBLEMS) + j]
            ax.set_title(f'({letter}) {prob}, $M={m}$', loc='left', pad=4)
            ax.set_xlim(XMIN, XMAX)
            ax.set_ylim(ylo, yhi)
            ax.set_xticks([50, 100, 150, 200, 250, 300])
            ax.yaxis.set_major_locator(
                MaxNLocator(nbins=5, steps=[1, 2, 5, 10]))
            if i == len(MS) - 1:
                ax.set_xlabel('Number of real function evaluations')
            if j == 0:
                ax.set_ylabel('IGD')
    # shared legend below the panels
    handles = [Line2D([0], [0], color=COLORS[a], linestyle='-',
                      linewidth=1.9 if a == PACDIS else 1.3,
                      marker=MARKERS[a], markersize=3.6,
                      markerfacecolor=COLORS[a] if a == PACDIS else 'none',
                      markeredgecolor=COLORS[a], markeredgewidth=0.9)
               for a in ORDER]
    labels = [LABELS[a] for a in ORDER]
    fig.legend(handles, labels, loc='lower center', ncol=7,
               bbox_to_anchor=(0.5, 0.008), columnspacing=1.6,
               handlelength=2.6)
    fig.subplots_adjust(left=0.075, right=0.995, top=0.975, bottom=0.105,
                        hspace=0.34, wspace=0.16)
    return fig, csv, df, traces


def save(fig, name, csv, df, traces):
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
        'problems': PROBLEMS,
        'objectives': MS,
        'panel_runs': {f'M{m}|{p}': {a: int(traces[(m, p, a)].shape[0])
                                     for a in ORDER}
                       for m in MS for p in PROBLEMS},
        'alignment': 'zero-order hold on unit-FE grid, no extrapolation past the last snapshot',
        'drawing': f'vertices every {MARK_EVERY} real evaluations, straight-line joins',
        'band': ('none (paper style)' if not SHOW_BAND else
                 '25-75% interquartile range across runs, PACDIS only'),
        'markers': {a: MARKERS[a] for a in ORDER},
        'marker_every_fe': MARK_EVERY,
        'line_styles': 'all solid; identity carried by colour + marker shape',
        'minimum_pdf_glyph_pt': round(minimum, 2),
        'text_outside_canvas': outside,
    }
    (OUT / f'{name}_manifest.json').write_text(
        json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'saved {name}.pdf/svg/png, min glyph {minimum:.2f} pt, '
          f'{len(spans)} text spans')
    plt.close(fig)


if __name__ == '__main__':
    QA.mkdir(exist_ok=True)
    fig, csv, df, traces = build()
    save(fig, 'fig_convergence', csv, df, traces)
