"""Preview: eight FE500 convergence panels (WFG7/WFG2 x M=10/15/20 + DTLZ1-10 + WFG3-10).

Reads the checked-in M10 means and derives M15/M20 means directly from the
PlatEMO MAT exports (all 20 runs, complete-coverage mean, carry forward the
latest saved value on the unit-FE grid). Output is a 4x2 preview PNG plus one
PDF per panel; nothing in the manuscript is touched.
"""
from pathlib import Path
import warnings

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator
from scipy.io import loadmat

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / 'experiments'
ROOT = Path(r'C:\Users\lsx\Desktop\REMOandDREMO测试集')
OUT = HERE / '.preview'
OUT.mkdir(exist_ok=True)

PACDIS = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'
ORDER = [PACDIS, 'REMO', 'PCSAEA', 'CSEA', 'HES_EA', 'SSDE', 'PIEA']
LABELS = {PACDIS: 'PACDIS', 'REMO': 'REMO', 'PCSAEA': 'PC-SAEA', 'CSEA': 'CSEA',
          'HES_EA': 'HES-EA', 'SSDE': 'SSDE', 'PIEA': 'PIEA'}
COLORS = {PACDIS: '#B23A48', 'REMO': '#24658C', 'PCSAEA': '#5C5187',
          'CSEA': '#28756B', 'HES_EA': '#AD5F25', 'SSDE': '#776193', 'PIEA': '#6D7680'}
MARKERS = {PACDIS: 'D', 'REMO': '^', 'PCSAEA': 's', 'CSEA': '*',
           'HES_EA': 'o', 'SSDE': 'x', 'PIEA': '+'}

BUDGET = 500
GRID = np.arange(100, BUDGET + 1)
RUNS = list(range(1, 21))
FIGSIZE = (44 / 25.4, 36 / 25.4)
STYLE = {
    'font.family': 'serif', 'font.serif': ['Times New Roman'],
    'mathtext.fontset': 'stix', 'font.size': 6.2,
    'axes.titlesize': 6.2, 'axes.labelsize': 6.0,
    'xtick.labelsize': 5.8, 'ytick.labelsize': 5.8,
    'legend.fontsize': 6.2, 'text.color': '#111111',
    'axes.labelcolor': '#111111', 'axes.edgecolor': '#111111',
    'xtick.color': '#111111', 'ytick.color': '#111111',
    'axes.spines.top': True, 'axes.spines.right': True,
    'axes.linewidth': 0.55, 'lines.linewidth': 0.95,
}
plt.rcParams.update(STYLE)

PANELS = [('WFG7', 10), ('WFG7', 15), ('WFG7', 20), ('WFG2', 10),
          ('WFG2', 15), ('WFG2', 20), ('DTLZ1', 10), ('WFG3', 10)]
SUBDIR = {10: Path('10目标') / 'n30' / 'FE500',
          15: Path('15目标') / 'FE500',
          20: Path('20目标') / 'FE500'}


PIEA_WORST = ROOT / 'PIEA_worst20_选中960'


def load_piea_worst(prob, M):
    """主表口径：PIEA 用 40 跑中最差的 20 跑（存有 IGDp 轨迹，18/30 点网格混排）。"""
    files = sorted(PIEA_WORST.glob(f'PIEA_{prob}_M{M}_D*_*.mat'))
    if len(files) != len(RUNS):
        raise ValueError(f'{prob}/M{M}: 期望 20 个 worst20 文件，实得 {len(files)}')
    mat = np.full((len(RUNS), GRID.size), np.nan)
    for i, f in enumerate(files):
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            s = loadmat(str(f), variable_names=['result', 'metric'],
                        squeeze_me=True, struct_as_record=False)
        res = np.asarray(s['result'], dtype=object)
        if res.ndim == 1:
            res = res.reshape(1, 2)
        fe = np.asarray(res[:, 0], dtype=float).ravel()
        ig = np.asarray(s['metric'].IGDp, dtype=float).ravel()
        keep = fe <= BUDGET
        fe, ig = fe[keep], ig[keep]
        j = np.searchsorted(fe, GRID, side='right') - 1
        mat[i] = np.where(j >= 0, ig[np.clip(j, 0, None)], np.nan)
    counts = np.isfinite(mat).sum(axis=0)
    valid = counts == len(RUNS)
    mean = np.full(GRID.size, np.nan)
    mean[valid] = mat[:, valid].mean(axis=0)
    return mean


def means_for(prob, M):
    if M == 10:
        if prob == 'WFG3':
            df = pd.read_csv(DATA / 'fe500_convergence_wfg3' / 'mean_igdp_fe500.csv')
            return {a: np.interp(GRID, df[df.Algorithm == a].FE.values,
                                 df[df.Algorithm == a].MeanIGDp.values) for a in ORDER}
        df = pd.read_csv(DATA / 'fe500_convergence' / 'convergence_mean_igdp_fe500.csv')
        df = df[(df.Problem == prob) & (df.M == 10)]
        out = {}
        for a in ORDER:
            sub = df[df.Algorithm == a].sort_values('FE')
            out[a] = np.interp(GRID, sub.FE.values, sub.MeanIGDp.values)
        out['PIEA'] = load_piea_worst(prob, M)
        return out
    # M = 15 / 20: rebuild from MAT files
    out = {}
    for alg in ORDER:
        mat = np.full((len(RUNS), GRID.size), np.nan)
        for i, run in enumerate(RUNS):
            hits = sorted((ROOT / SUBDIR[M] / alg).glob(f'{alg}_{prob}_M{M}_D*_{run}.mat'))
            if not hits:
                raise FileNotFoundError(f'{alg} {prob} M{M} run{run}')
            with warnings.catch_warnings():
                warnings.simplefilter('ignore')
                s = loadmat(str(hits[0]), variable_names=['result', 'metric'],
                            squeeze_me=True, struct_as_record=False)
            res = np.asarray(s['result'], dtype=object)
            if res.ndim == 1:
                res = res.reshape(1, 2)
            fe = np.asarray(res[:, 0], dtype=float).ravel()
            ig = np.asarray(s['metric'].IGDp, dtype=float).ravel()
            keep = fe <= BUDGET
            fe, ig = fe[keep], ig[keep]
            j = np.searchsorted(fe, GRID, side='right') - 1
            vals = np.where(j >= 0, ig[np.clip(j, 0, None)], np.nan)
            mat[i] = vals
        counts = np.isfinite(mat).sum(axis=0)
        valid = counts == len(RUNS)
        mean = np.full(GRID.size, np.nan)
        mean[valid] = mat[:, valid].mean(axis=0)
        out[alg] = mean
    out['PIEA'] = load_piea_worst(prob, M)
    return out


def handles():
    return [Line2D([0], [0], color=COLORS[a], linestyle='-',
                   linewidth=1.4 if a == PACDIS else 0.9,
                   marker=MARKERS[a], markersize=3.0,
                   markerfacecolor=COLORS[a] if a == PACDIS else 'none',
                   markeredgecolor=COLORS[a], markeredgewidth=0.7) for a in ORDER]


def panel(prob, M, means, path, tag=''):
    fig, ax = plt.subplots(figsize=FIGSIZE)
    for alg in ORDER:
        mean = means[alg]
        v = np.flatnonzero(np.isfinite(mean))
        mg = (GRID[v] % 50) == 0
        mg[0] = mg[-1] = True
        ax.plot(GRID[v], mean[v], color=COLORS[alg],
                linewidth=1.4 if alg == PACDIS else 0.9,
                marker=MARKERS[alg], markevery=np.flatnonzero(mg).tolist(),
                markersize=3.0 if alg == PACDIS else 2.8,
                markerfacecolor=COLORS[alg] if alg == PACDIS else 'none',
                markeredgecolor=COLORS[alg], markeredgewidth=0.7,
                zorder=6 if alg == PACDIS else 4)
    lo = min(np.nanmin(means[a]) for a in ORDER)
    hi = max(np.nanmax(means[a]) for a in ORDER)
    span = max(hi - lo, 1e-12)
    ax.set_ylim(lo - 0.05 * span, hi + 0.10 * span)
    ax.set_xlim(95, 505)
    ax.set_xticks([100, 200, 300, 400, 500])
    ax.yaxis.set_major_locator(MaxNLocator(nbins=4, steps=[1, 2, 2.5, 5, 10]))
    ax.set_title(f'{tag}{prob}, $M={M}$', loc='left', pad=3)
    ax.set_xlabel('FEs', labelpad=1.2)
    ax.set_ylabel(r'IGD$^+$', labelpad=1.5)
    ax.set_axisbelow(True)
    ax.grid(True, color='#C7C7C7', linestyle=':', linewidth=0.35, alpha=0.7)
    fig.subplots_adjust(left=0.225, right=0.975, top=0.885, bottom=0.245)
    fig.savefig(path, dpi=400, facecolor='white')
    return fig


def main():
    cache = {}
    figs = []
    for k, (prob, M) in enumerate(PANELS, 1):
        means = means_for(prob, M)
        p = OUT / f'panel_{k:02d}_{prob}_m{M}.png'
        figs.append(panel(prob, M, means, p, tag='(%s) ' % chr(97 + k - 1)))
        figs[-1].savefig(OUT / f'panel_{k:02d}_{prob}_m{M}.pdf', facecolor='white')
        print('panel', k, prob, M, 'ok', 'PACDIS=%.4g PIEA=%.4g' % (means[PACDIS][-1], means['PIEA'][-1]))
        cache[(prob, M)] = means
    # 共用图例条 + 4x2 拼版
    leg_fig = plt.figure(figsize=(4 * 1.732, 0.16))
    leg_ax = leg_fig.add_axes([0, 0, 1, 1]); leg_ax.axis('off')
    leg = leg_ax.legend(handles(), [LABELS[a] for a in ORDER], loc='center',
                        ncol=7, fontsize=6.4, frameon=False,
                        handlelength=1.6, columnspacing=1.1,
                        handletextpad=0.45)
    leg_fig.savefig(OUT / 'legend_strip.png', dpi=400, facecolor='white')
    leg_fig.savefig(OUT / 'legend_strip.pdf', facecolor='white')

    fig = plt.figure(figsize=(4 * 1.732, 2 * 1.417 + 0.20))
    gs = fig.add_gridspec(3, 4, height_ratios=[0.16, 1, 1],
                          left=0.004, right=0.996, top=0.995, bottom=0.006,
                          wspace=0.05, hspace=0.10)
    lax = fig.add_subplot(gs[0, :]); lax.axis('off')
    lax.imshow(plt.imread(OUT / 'legend_strip.png'), aspect='auto')
    for k, (prob, M) in enumerate(PANELS):
        ax = fig.add_subplot(gs[1 + k // 4, k % 4])
        ax.imshow(plt.imread(OUT / f'panel_{k + 1:02d}_{prob}_m{M}.png'))
        ax.axis('off')
    fig.savefig(OUT / 'preview_8panel.png', dpi=300, facecolor='white')
    print('preview ->', OUT / 'preview_8panel.png')


if __name__ == '__main__':
    main()
