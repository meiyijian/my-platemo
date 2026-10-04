"""Draw four independent FE500 convergence figures for the PACDIS manuscript.

Input columns remain Algorithm,Problem,M,D,Run,Step,FE,IGDp. Each curve is
the arithmetic mean of runs 1-20 after previous-snapshot hold on a unit-FE
grid. Values at FE > 500 never enter a curve. A later recorded FE establishes
observation coverage only; its metric value is excluded. No smoothing or
monotonic-envelope transformation is applied.

Run export_convergence_fe500.py first. Outputs are four 88 x 70 mm PDF/SVG/PNG
figures, their provenance manifests, and aggregate data/coverage reports.
The legacy composite image is not regenerated or included in the manuscript.
"""
from pathlib import Path
import hashlib
import json

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator
import pymupdf

OUT = Path(__file__).resolve().parent
DATA = OUT.parent / 'experiments' / 'fe500_convergence'
CSV = DATA / 'convergence_igdp_fe500.csv'
SOURCE_MANIFEST = DATA / 'source_manifest.json'
QA = OUT / 'qa'
PACDIS = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'
ORDER = [PACDIS, 'REMO', 'PCSAEA', 'CSEA', 'HES_EA', 'SSDE', 'SAMOEATL2M']
LABELS = {
    PACDIS: 'PACDIS', 'REMO': 'REMO', 'PCSAEA': 'PC-SAEA',
    'CSEA': 'CSEA', 'HES_EA': 'HES-EA', 'SSDE': 'SSDE',
    'SAMOEATL2M': 'SAMOEA-TL2M',
}
COLORS = {
    PACDIS: '#B23A48', 'REMO': '#24658C', 'PCSAEA': '#5C5187',
    'CSEA': '#28756B', 'HES_EA': '#AD5F25', 'SSDE': '#776193',
    'SAMOEATL2M': '#6D7680',
}
MARKERS = {
    PACDIS: 'D', 'REMO': '^', 'PCSAEA': 's', 'CSEA': '*',
    'HES_EA': 'o', 'SSDE': 'x', 'SAMOEATL2M': '+',
}
M = 10
BUDGET = 500
PROBLEMS = ['DTLZ1', 'DTLZ6', 'WFG2', 'WFG7']
RUNS = list(range(1, 21))
GRID = np.arange(100, BUDGET + 1)
MARK_EVERY = 50
FIGSIZE = (88 / 25.4, 70 / 25.4)
XTICKS = [100, 200, 300, 400, 500]
STYLE = {
    'font.family': 'serif', 'font.serif': ['Times New Roman'],
    'mathtext.fontset': 'stix', 'font.size': 8,
    'axes.titlesize': 8.5, 'axes.labelsize': 8.5,
    'xtick.labelsize': 8, 'ytick.labelsize': 8,
    'legend.fontsize': 7.5, 'text.color': '#111111',
    'axes.labelcolor': '#111111', 'axes.edgecolor': '#111111',
    'xtick.color': '#111111', 'ytick.color': '#111111',
    'axes.spines.top': True, 'axes.spines.right': True,
    'axes.linewidth': 0.65, 'lines.linewidth': 1.1,
    'pdf.fonttype': 42, 'ps.fonttype': 42, 'svg.fonttype': 'none',
    'savefig.facecolor': 'white', 'figure.facecolor': 'white',
    'legend.frameon': True,
}


def resample(fe, values, grid=GRID, budget=BUDGET):
    """Hold only eligible values, within the observed FE interval."""
    fe, values = np.asarray(fe, float), np.asarray(values, float)
    if (fe.ndim != 1 or values.shape != fe.shape or fe.size == 0
            or not np.isfinite(fe).all() or not np.isfinite(values).all()
            or (np.diff(fe) < 0).any()):
        raise ValueError('invalid snapshot trajectory')
    observed_until = min(budget, fe[-1])
    eligible = fe <= budget
    fe, values = fe[eligible], values[eligible]
    held = np.full(grid.shape, np.nan, dtype=float)
    if fe.size:
        # Right-sided search selects the final entry at a duplicated FE.
        positions = np.searchsorted(fe, grid, side='right') - 1
        valid = (positions >= 0) & (grid <= observed_until)
        held[valid] = values[positions[valid]]
    return held


def complete_run_mean(trace):
    """Average all 20 runs; refuse an accidental changing-denominator mean."""
    if trace.shape != (len(RUNS), GRID.size):
        raise ValueError(f'expected {len(RUNS)} runs, received {trace.shape}')
    counts = np.isfinite(trace).sum(axis=0)
    if np.any((counts != 0) & (counts != len(RUNS))):
        raise ValueError('partial run coverage at an FE coordinate')
    valid = counts == len(RUNS)
    if not valid.any() or not valid[-1]:
        raise ValueError('missing complete-run coverage at the budget')
    if not valid[np.flatnonzero(valid)[0]:].all():
        raise ValueError('gap in complete-run observation coverage')
    mean = np.full(GRID.shape, np.nan, dtype=float)
    mean[valid] = trace[:, valid].mean(axis=0)
    return mean, counts


def load_traces():
    df = pd.read_csv(CSV)
    columns = ['Algorithm', 'Problem', 'M', 'D', 'Run', 'Step', 'FE', 'IGDp']
    if df.columns.tolist() != columns:
        raise ValueError('unexpected input CSV columns')
    if (set(df['M']) != {M} or sorted(df['Run'].unique()) != RUNS
            or df.duplicated(['Algorithm', 'Problem', 'Run', 'Step']).any()):
        raise ValueError('wrong protocol or duplicated snapshot index')
    manifest = json.loads(SOURCE_MANIFEST.read_text(encoding='utf-8'))
    if manifest['source_csv_sha256'] != hashlib.sha256(CSV.read_bytes()).hexdigest():
        raise ValueError('CSV no longer matches source manifest')
    traces, means, counts, coverage = {}, {}, {}, {}
    for (prob, alg), group in df.groupby(['Problem', 'Algorithm'], sort=False):
        expected_d = 31 if prob == 'WFG2' else 30
        if sorted(group['Run'].unique()) != RUNS or set(group['D']) != {expected_d}:
            raise ValueError(f'{prob}/{alg}: run or dimension mismatch')
        run_traces, first, last, eligible_last = [], [], [], []
        for _, run in group.groupby('Run', sort=True):
            run = run.sort_values('Step')
            fe, metric = run['FE'].to_numpy(), run['IGDp'].to_numpy()
            run_traces.append(resample(fe, metric))
            first.append(int(fe[0]))
            last.append(int(fe[-1]))
            eligible_last.append(int(fe[fe <= BUDGET][-1]))
        key = (prob, alg)
        traces[key] = np.vstack(run_traces)
        means[key], counts[key] = complete_run_mean(traces[key])
        coverage.setdefault(prob, {})[alg] = {
            'runs': len(RUNS), 'D': expected_d,
            'first_saved_fe_range': [min(first), max(first)],
            'first_plotted_fe': int(GRID[np.flatnonzero(counts[key] == len(RUNS))[0]]),
            'terminal_fe_range': [min(last), max(last)],
            'last_saved_fe_le500_range': [min(eligible_last), max(eligible_last)],
            'snapshot_count_range': [
                int(group.groupby('Run').size().min()),
                int(group.groupby('Run').size().max()),
            ],
            'snapshots_above_budget_excluded': int((group['FE'] > BUDGET).sum()),
        }
    expected = {(p, a) for p in PROBLEMS for a in ORDER}
    if set(traces) != expected:
        raise ValueError(f'unexpected problem/algorithm cells: {expected ^ set(traces)}')
    return df, traces, means, counts, coverage


def legend_handles():
    return [
        Line2D([0], [0], color=COLORS[a], linestyle='-',
               linewidth=1.65 if a == PACDIS else 1.05,
               marker=MARKERS[a], markersize=3.5,
               markerfacecolor=COLORS[a] if a == PACDIS else 'none',
               markeredgecolor=COLORS[a], markeredgewidth=0.8)
        for a in ORDER
    ]


def build_single(means, prob):
    fig, ax = plt.subplots(figsize=FIGSIZE)
    for alg in ORDER:
        mean = means[(prob, alg)]
        valid = np.flatnonzero(np.isfinite(mean))
        marker_grid = ((GRID[valid] % MARK_EVERY) == 0)
        marker_grid[0] = marker_grid[-1] = True
        ax.plot(
            GRID[valid], mean[valid], color=COLORS[alg],
            linewidth=1.65 if alg == PACDIS else 1.05,
            marker=MARKERS[alg], markevery=np.flatnonzero(marker_grid).tolist(),
            markersize=3.4 if alg == PACDIS else 3.2,
            markerfacecolor=COLORS[alg] if alg == PACDIS else 'none',
            markeredgecolor=COLORS[alg], markeredgewidth=0.8,
            zorder=6 if alg == PACDIS else 4,
        )
    lo = min(np.nanmin(means[(prob, a)]) for a in ORDER)
    hi = max(np.nanmax(means[(prob, a)]) for a in ORDER)
    span = max(hi - lo, 1e-12)
    # Uniform headroom accommodates the same two-column legend in every plot.
    ax.set_ylim(lo - 0.05 * span, hi + 0.48 * span)
    ax.set_xlim(95, 505)
    ax.set_xticks(XTICKS)
    ax.yaxis.set_major_locator(MaxNLocator(nbins=5, steps=[1, 2, 2.5, 5, 10]))
    ax.set_title(f'{prob}, $M={M}$', loc='left', pad=4)
    ax.set_xlabel('Number of real function evaluations', labelpad=3)
    ax.set_ylabel(r'IGD$^+$', labelpad=4)
    ax.set_axisbelow(True)
    ax.grid(True, color='#C7C7C7', linestyle=':', linewidth=0.45, alpha=0.7)
    legend = ax.legend(
        legend_handles(), [LABELS[a] for a in ORDER],
        loc='upper right', ncol=2, fontsize=7.5,
        columnspacing=0.9, handlelength=1.7, handletextpad=0.5,
        borderaxespad=0.45, labelspacing=0.3, borderpad=0.35,
        edgecolor='#A0A0A0', facecolor='white', framealpha=1,
    )
    legend.get_frame().set_linewidth(0.45)
    fig.subplots_adjust(left=0.16, right=0.985, top=0.91, bottom=0.155)
    fig.canvas.draw()
    rectangle = legend.get_window_extent(fig.canvas.get_renderer())
    for line in ax.lines:
        points = ax.transData.transform(line.get_xydata())
        inside = (
            (points[:, 0] >= rectangle.x0) & (points[:, 0] <= rectangle.x1)
            & (points[:, 1] >= rectangle.y0) & (points[:, 1] <= rectangle.y1)
        )
        if inside.any():
            raise ValueError(f'{prob}: legend obscures curve data')
    return fig


def save(fig, prob, coverage):
    name = f'fig_convergence_fe500_{prob.lower()}_m{M}'
    for ext in ('pdf', 'svg', 'png'):
        fig.savefig(OUT / f'{name}.{ext}', dpi=600, facecolor='white')
    svg = OUT / f'{name}.svg'
    svg.write_text('\n'.join(line.rstrip() for line in
                             svg.read_text(encoding='utf-8').splitlines()) + '\n',
                   encoding='utf-8', newline='\n')
    doc = pymupdf.open(OUT / f'{name}.pdf')
    page = doc[0]
    spans = [
        span for block in page.get_text('dict')['blocks'] if 'lines' in block
        for line in block['lines'] for span in line['spans'] if span['text'].strip()
    ]
    outside = [
        span['text'] for span in spans
        if span['bbox'][0] < -0.5 or span['bbox'][1] < -0.5
        or span['bbox'][2] > page.rect.width + 0.5
        or span['bbox'][3] > page.rect.height + 0.5
    ]
    ordinary = [s['size'] for s in spans if s['text'].strip() != '+']
    fonts = page.get_fonts(full=True)
    unembedded = [f[3] for f in fonts if not doc.extract_font(f[0])[3]]
    if outside or min(ordinary) < 6.99 or unembedded:
        raise ValueError(f'{name}: clipping, small ordinary text or unembedded font')
    QA.mkdir(exist_ok=True)
    page.get_pixmap(matrix=pymupdf.Matrix(2, 2), alpha=False).save(
        QA / f'{name}_render.png')
    manifest = {
        'figure': name, 'metric': 'IGDp (IGD+)', 'estimator': 'arithmetic mean',
        'source_csv': str(CSV.relative_to(OUT.parent)),
        'source_csv_sha256': hashlib.sha256(CSV.read_bytes()).hexdigest(),
        'source_manifest': str(SOURCE_MANIFEST.relative_to(OUT.parent)),
        'source_manifest_sha256': hashlib.sha256(SOURCE_MANIFEST.read_bytes()).hexdigest(),
        'drawing_script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'runs_used': RUNS, 'problems': [prob], 'objectives': [M],
        'fe_budget': BUDGET, 'fe_grid': [100, BUDGET, 1],
        'alignment': 'previous-snapshot hold; NaN before initialization; all 20 runs at each plotted FE',
        'budget_policy': 'Exclude all metric values at FE > 500; retain latest eligible value within observed run coverage.',
        'drawing': 'full unit-FE grid; no smoothing; no monotonic envelope',
        'markers': {a: MARKERS[a] for a in ORDER}, 'marker_every_fe': MARK_EVERY,
        'marker_endpoints': True, 'band': 'none', 'line_styles': 'solid',
        'algorithm_labels': LABELS, 'coverage': coverage[prob],
        'page_size_mm': [88, 70],
        'minimum_ordinary_text_pt': round(min(ordinary), 2),
        'minimum_pdf_glyph_pt': round(min(s['size'] for s in spans), 2),
        'font_names': sorted({f[3] for f in fonts}),
        'unembedded_fonts': unembedded, 'text_outside_canvas': outside,
        'legend_obscures_curve_data': False,
    }
    (OUT / f'{name}_manifest.json').write_text(
        json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    doc.close()
    plt.close(fig)
    print(f'saved {name}: 88 x 70 mm; ordinary text >= {min(ordinary):.2f} pt')


def main():
    _, _, means, counts, coverage = load_traces()
    aggregated = []
    endpoints = []
    for prob in PROBLEMS:
        values = {a: float(means[(prob, a)][-1]) for a in ORDER}
        endpoints.append({
            'M': M, 'problem': prob, 'FE': BUDGET, 'estimator': 'arithmetic mean',
            'n': len(RUNS), 'means': values,
            'ranks': {a: 1 + sum(v < values[a] for v in values.values()) for a in ORDER},
            'best': min(values, key=values.get),
            'metric_policy': 'latest saved value with FE <= 500 for each run',
        })
        for alg in ORDER:
            for i in np.flatnonzero(np.isfinite(means[(prob, alg)])):
                aggregated.append({
                    'Algorithm': alg, 'Problem': prob, 'M': M,
                    'D': 31 if prob == 'WFG2' else 30, 'FE': int(GRID[i]),
                    'MeanIGDp': float(means[(prob, alg)][i]),
                    'N': int(counts[(prob, alg)][i]),
                })
    pd.DataFrame(aggregated).to_csv(DATA / 'convergence_mean_igdp_fe500.csv', index=False)
    (DATA / 'convergence_at_500.json').write_text(
        json.dumps(endpoints, indent=2) + '\n', encoding='utf-8')
    (DATA / 'convergence_fe500_coverage.json').write_text(
        json.dumps(coverage, indent=2) + '\n', encoding='utf-8')
    with plt.rc_context(STYLE):
        for prob in PROBLEMS:
            save(build_single(means, prob), prob, coverage)


if __name__ == '__main__':
    main()
