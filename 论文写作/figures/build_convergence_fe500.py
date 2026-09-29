"""Build the FE=500 convergence figures for the PACDIS manuscript.

Companion of build_convergence.py: same drawing code and paper style, but the
comparison set and the budget are the current ones.

Source: experiments/fe500_convergence/convergence_igdp_fe500.csv, exported by
export_convergence_fe500.py from the saved FE=500 MAT snapshots on the work
machine (10目标/n30/FE500). Algorithms are the six current baselines plus
PACDIS implemented as REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist.

Deliverables, all from the same drawing code:

* four single-column panels, fig_convergence_fe500_<problem>_m10.{pdf,svg,png}
* one 2x2 combined panel, fig_convergence_fe500_m10.{pdf,svg,png}

Style: median IGD+ traces, matched runs 1-20, zero-order-hold alignment on a
unit-FE grid, straight polylines with one vertex every 50 evaluations, no
interquartile band, markers carry the algorithm identity.

Run:
    C:\\Users\\lsx\\.workbuddy\\binaries\\python\\envs\\default\\Scripts\\python.exe build_convergence_fe500.py
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
CSV = OUT.parent / 'experiments/fe500_convergence/convergence_igdp_fe500.csv'
QA = OUT / 'qa'

INK = '#253442'
GRAY = '#6D7680'
BLUE = '#24658C'
ORANGE = '#AD5F25'
PURPLE = '#776193'
TEAL = '#28756B'

PACDIS = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'
ORDER = [PACDIS, 'REMO', 'PCSAEA', 'CSEA', 'HES_EA', 'SSDE', 'SAMOEATL2M']
LABELS = {
    PACDIS: 'PACDIS (ours)',
    'REMO': 'REMO',
    'PCSAEA': 'PC-SAEA',
    'CSEA': 'CSEA',
    'HES_EA': 'HES-EA',
    'SSDE': 'SSDE',
    'SAMOEATL2M': 'SAMOEA-TL2M',
}
COLORS = {
    PACDIS: '#B23A48',
    'REMO': BLUE,
    'PCSAEA': '#5C5187',
    'CSEA': TEAL,
    'HES_EA': ORANGE,
    'SSDE': PURPLE,
    'SAMOEATL2M': GRAY,
}
MARKERS = {                       # marker shape follows the role, as in the 300-FE study
    PACDIS: 'D',
    'REMO': '^',
    'PCSAEA': 's',
    'CSEA': '*',
    'HES_EA': 'o',
    'SSDE': 'x',
    'SAMOEATL2M': '+',
}
MARK_EVERY = 50     # one vertex every 50 real evaluations (200 -> 400 FE span)
SHOW_BAND = False   # paper style: no shaded interquartile band

M = 10
PROBLEMS = ['DTLZ1', 'DTLZ6', 'WFG2', 'WFG7']
RUNS = list(range(1, 21))          # matched subset: run ids 1-20
# The initial design consumes real evaluations and the first snapshot lands at
# FE=100, so the axis starts just left of 100 and the axis padding keeps the
# plot from touching the frame.
XMIN, XMAX = 95, 505
GRID = np.arange(XMIN, 501)        # never plot past FE=500
LETTERS = 'abcdef'

QUAD_FIGSIZE = (180 / 25.4, 132 / 25.4)
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
XTICKS = [100, 200, 300, 400, 500]


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
    fe_u, igd_u = [], []          # duplicated FE -> last snapshot wins
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
    ok = (idx >= 0) & (grid <= fe_u[-1])
    g[ok] = igd_u[idx[ok]]
    return g


def load_traces():
    df = pd.read_csv(CSV)
    df = df[(df['M'] == M) & (df['Run'].isin(RUNS))]
    traces = {}
    for (prob, alg), grp in df.groupby(['Problem', 'Algorithm']):
        assert sorted(grp['Run'].unique()) == RUNS, (prob, alg, 'incomplete runs')
        assert not grp.duplicated(['Run', 'Step']).any(), (prob, alg, 'duplicate snapshots')
        runs = [resample(r['FE'].to_numpy(), r['IGDp'].to_numpy(), GRID)
                for _, r in grp.groupby('Run')]
        traces[(prob, alg)] = np.vstack(runs)
    expected = {(p, a) for p in PROBLEMS for a in ORDER}
    assert set(traces) == expected, sorted(expected ^ set(traces))
    return df, traces


def percentiles(trace):
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
    if SHOW_BAND:
        for alg in ORDER:
            q25, q50, q75 = curves[alg]
            if alg == PACDIS:
                ax.fill_between(GRID, q25, q75, color=COLORS[alg],
                                alpha=0.15, linewidth=0, zorder=2)
    for alg in ORDER:
        q25, q50, q75 = curves[alg]
        if alg == PACDIS:
            ax.plot(mark_x, q50[mark_idx], color=COLORS[alg], linewidth=1.6,
                    marker=MARKERS[alg], markersize=3.0,
                    markerfacecolor=COLORS[alg], markeredgecolor=COLORS[alg],
                    zorder=6)
        else:
            ax.plot(mark_x, q50[mark_idx], color=COLORS[alg], linewidth=1.0,
                    marker=MARKERS[alg], markersize=2.8, markerfacecolor='none',
                    markeredgecolor=COLORS[alg], markeredgewidth=0.8, zorder=4)


def panel_limits(curves, pad=0.05, pad_top=None):
    lo = min(np.nanmin(v[0]) for v in curves.values())
    hi = max(np.nanmax(v[2]) for v in curves.values())
    span = hi - lo
    if span <= 0:
        span = max(abs(hi), 1.0)
    return lo - pad * span, hi + (pad if pad_top is None else pad_top) * span


def build_single(stats, prob, letter):
    mark_idx = np.where(GRID % MARK_EVERY == 0)[0]
    mark_x = GRID[mark_idx]
    curves = {alg: stats[(prob, alg)] for alg in ORDER}
    ylo, yhi = panel_limits(curves, pad=0.05, pad_top=0.42)

    fig, ax = plt.subplots(figsize=SINGLE_FIGSIZE)
    draw_curves(ax, curves, mark_idx, mark_x)
    ax.set_title(f'({letter}) {prob}, $M={M}$', loc='left', pad=4)
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(ylo, yhi)
    ax.set_xticks(XTICKS)
    ax.yaxis.set_major_locator(MaxNLocator(nbins=4, steps=[1, 2, 5, 10]))
    ax.set_xlabel('Number of real function evaluations')
    ax.set_ylabel(r'IGD$^+$')
    ax.legend(legend_handles(), [LABELS[a] for a in ORDER],
              loc='upper right', ncol=2, fontsize=6.5,
              columnspacing=0.9, handlelength=1.8, handletextpad=0.5,
              borderaxespad=0.4, labelspacing=0.32)
    fig.subplots_adjust(left=0.155, right=0.985, top=0.905, bottom=0.155)
    return fig


def build_quad(stats):
    """Four panels in one 2x2 layout; each panel keeps its own y range, because
    the problems differ by orders of magnitude (DTLZ1 ~ 1e2, DTLZ6 ~ 1e1) and a
    shared scale would flatten the small-magnitude panels."""
    mark_idx = np.where(GRID % MARK_EVERY == 0)[0]
    mark_x = GRID[mark_idx]
    rows = [PROBLEMS[:2], PROBLEMS[2:]]
    fig, axes = plt.subplots(2, 2, figsize=QUAD_FIGSIZE)
    for i, row in enumerate(rows):
        for j, prob in enumerate(row):
            ax = axes[i, j]
            draw_curves(ax, {alg: stats[(prob, alg)] for alg in ORDER},
                        mark_idx, mark_x)
            ylo, yhi = panel_limits({alg: stats[(prob, alg)] for alg in ORDER})
            letter = LETTERS[i * 2 + j]
            ax.set_title(f'({letter}) {prob}, $M={M}$', loc='left', pad=3)
            ax.set_xlim(XMIN, XMAX)
            ax.set_ylim(ylo, yhi)
            ax.set_xticks(XTICKS)
            ax.yaxis.set_major_locator(MaxNLocator(nbins=5, steps=[1, 2, 5, 10]))
            if i == 1:
                ax.set_xlabel('Number of real function evaluations')
            if j == 0:
                ax.set_ylabel(r'IGD$^+$')
    fig.legend(legend_handles(), [LABELS[a] for a in ORDER],
               loc='lower center', ncol=7, bbox_to_anchor=(0.5, 0.008),
               columnspacing=1.2, handlelength=2.2, fontsize=7)
    fig.subplots_adjust(left=0.075, right=0.995, top=0.955, bottom=0.135,
                        hspace=0.30, wspace=0.16)
    return fig


def save(fig, name, panel_runs, problems, objectives):
    for ext in ('pdf', 'svg', 'png'):
        fig.savefig(OUT / f'{name}.{ext}', dpi=600, facecolor='white')
    import pymupdf
    doc = pymupdf.open(OUT / f'{name}.pdf')
    page = doc[0]
    spans = [s for b in page.get_text('dict')['blocks'] if 'lines' in b
             for l in b['lines'] for s in l['spans'] if s['text'].strip()]
    page_w, page_h = page.rect.width, page.rect.height
    outside = [s['text'] for s in spans
               if s['bbox'][0] < -0.5 or s['bbox'][1] < -0.5
               or s['bbox'][2] > page_w + 0.5 or s['bbox'][3] > page_h + 0.5]
    if outside:
        raise ValueError(f'{name}: text outside canvas: {outside}')
    minimum = min(s['size'] for s in spans)
    if minimum < 4.99:
        raise ValueError(f'{name}: glyph below 5 pt: {minimum}')
    QA.mkdir(exist_ok=True)
    doc[0].get_pixmap(matrix=pymupdf.Matrix(1.8, 1.8), alpha=False).save(
        QA / f'{name}_render.png')
    manifest = {
        'figure': name,
        'metric': 'IGDp (IGD+)',
        'source_csv': str(CSV),
        'source_csv_sha256': hashlib.sha256(CSV.read_bytes()).hexdigest(),
        'algorithm_folders': {a: a for a in ORDER},
        'runs_used': RUNS,
        'problems': problems,
        'objectives': objectives,
        'panel_runs': panel_runs,
        'fe_budget': 500,
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
    df, traces = load_traces()
    stats = {k: percentiles(v) for k, v in traces.items()}
    runs_for = lambda ps: {p: {a: int(traces[(p, a)].shape[0]) for a in ORDER}
                           for p in ps}                                  # noqa: E731

    endpoint_report = []
    for prob in PROBLEMS:
        values = {a: float(stats[(prob, a)][1][-1]) for a in ORDER}
        ranks = {a: 1 + sum(1 for b in ORDER if values[b] < values[a]) for a in ORDER}
        endpoint_report.append({'M': M, 'problem': prob, 'FE': 500,
                                'medians': values, 'ranks': ranks,
                                'best': min(values, key=values.get)})
    (CSV.parent / 'convergence_at_500.json').write_text(
        json.dumps(endpoint_report, indent=2), encoding='utf-8')

    # Snapshot coverage: three baselines start recording late on this export,
    # so the figure has to state the interval each trace actually spans.
    coverage = {}
    for prob in PROBLEMS:
        coverage[prob] = {}
        for alg in ORDER:
            g = df[(df['Problem'] == prob) & (df['Algorithm'] == alg)]
            per_run = g.groupby('Run').size()
            coverage[prob][alg] = {'first_fe': int(g['FE'].min()),
                                   'last_fe': int(g['FE'].max()),
                                   'points_per_run_min': int(per_run.min()),
                                   'points_per_run_max': int(per_run.max())}
    (CSV.parent / 'convergence_fe500_coverage.json').write_text(
        json.dumps(coverage, indent=2), encoding='utf-8')
    starts = sorted({v['first_fe'] for c in coverage.values() for v in c.values()})
    print('first recorded snapshot across all panels:', starts)

    for i, prob in enumerate(PROBLEMS):
        fig = build_single(stats, prob, LETTERS[i])
        save(fig, f'fig_convergence_fe500_{prob.lower()}_m{M}', runs_for([prob]),
             [prob], [M])

    fig = build_quad(stats)
    save(fig, f'fig_convergence_fe500_m{M}', runs_for(PROBLEMS), PROBLEMS, [M])
