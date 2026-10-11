"""Export and draw the WFG3 failure case using the existing FE500 plot style.

Read stored FE/IGDp trajectories only. No new objective evaluations are run.
Run with --export to refresh the immutable-source CSV and manifest; otherwise
rebuild from the checked-in CSV. See experiments/fe500_convergence_wfg3/README.md.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import warnings

import numpy as np
import pandas as pd
from scipy.io import loadmat

import build_convergence_fe500 as shared

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / 'experiments' / 'fe500_convergence_wfg3'
ROOT = Path(r'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\FE500')
CSV = DATA / 'convergence_igdp_fe500.csv'
MANIFEST = DATA / 'source_manifest.json'
PROBLEM = 'WFG3'
COLUMNS = ['Algorithm', 'Problem', 'M', 'D', 'Run', 'Step', 'FE', 'IGDp']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n',
                    encoding='utf-8')


def export():
    rows, sources = [], []
    for alg in shared.ORDER:
        for run in shared.RUNS:
            hits = list((ROOT / alg).glob(f'{alg}_WFG3_M10_D*_{run}.mat'))
            if len(hits) != 1 or f'_D31_{run}.mat' not in hits[0].name:
                raise ValueError(f'{alg}/{run}: ambiguous source or wrong dimension')
            source = hits[0]
            with warnings.catch_warnings():
                warnings.simplefilter('ignore')
                mat = loadmat(source, variable_names=['result', 'metric'],
                              squeeze_me=True, struct_as_record=False)
            result = np.asarray(mat['result'], dtype=object).reshape(-1, 2)
            fe = np.asarray(result[:, 0], dtype=float)
            values = np.asarray(mat['metric'].IGDp, dtype=float).ravel()
            if (values.shape != fe.shape or not np.isfinite(fe).all()
                    or not np.isfinite(values).all() or (np.diff(fe) < 0).any()
                    or (fe != np.floor(fe)).any() or (fe <= 0).any()
                    or (values < 0).any() or fe[-1] < 500 or fe[0] > 500):
                raise ValueError(f'{source.name}: invalid trajectory or coverage')
            sources.append({
                'algorithm': alg, 'problem': PROBLEM, 'M': 10, 'D': 31,
                'run': run, 'relative_path': source.relative_to(ROOT).as_posix(),
                'sha256': sha(source), 'snapshot_count': len(fe),
                'first_fe': int(fe[0]), 'terminal_fe': int(fe[-1]),
                'last_saved_fe_le500': int(fe[fe <= 500][-1]),
                'snapshots_above_budget': int((fe > 500).sum()),
            })
            rows.extend(dict(zip(COLUMNS, [alg, PROBLEM, 10, 31, run, step,
                                           int(f), float(v)]))
                        for step, (f, v) in enumerate(zip(fe, values), 1))
    DATA.mkdir(parents=True, exist_ok=True)
    with CSV.open('w', encoding='utf-8', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    write_json(MANIFEST, {
        'source_root': str(ROOT), 'source_csv_sha256': sha(CSV),
        'configured_fe_budget': 500, 'M': 10, 'D': 31, 'problems': [PROBLEM],
        'runs': shared.RUNS, 'algorithm_labels': shared.LABELS,
        'run_file_count': len(sources), 'trajectory_row_count': len(rows),
        'raw_export_policy': 'Retain recorded snapshots; plotting excludes metric values at FE > 500.',
        'sources': sources,
    })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', action='store_true')
    args = parser.parse_args()
    if args.export:
        export()
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if manifest['source_csv_sha256'] != sha(CSV):
        raise ValueError('source CSV hash mismatch')
    df = pd.read_csv(CSV, float_precision='round_trip')
    if (df.columns.tolist() != COLUMNS or set(df.Algorithm) != set(shared.ORDER)
            or set(df.Problem) != {PROBLEM} or set(df.M) != {10}
            or set(df.D) != {31} or df.duplicated(['Algorithm', 'Run', 'Step']).any()):
        raise ValueError('wrong data identity or duplicate rows')
    means, coverage, endpoints, aggregate = {}, {PROBLEM: {}}, {}, []
    for alg in shared.ORDER:
        group = df[df.Algorithm == alg]
        if sorted(group.Run.unique()) != shared.RUNS:
            raise ValueError(f'{alg}: missing runs')
        traces, first, terminal, last = [], [], [], []
        for run in shared.RUNS:
            rows = group[group.Run == run].sort_values('Step')
            fe, values = rows.FE.to_numpy(), rows.IGDp.to_numpy()
            traces.append(shared.resample(fe, values))
            first.append(int(fe[0]))
            terminal.append(int(fe[-1]))
            last.append(int(fe[fe <= 500][-1]))
        traces = np.vstack(traces)
        mean, counts = shared.complete_run_mean(traces)
        means[(PROBLEM, alg)] = mean
        coverage[PROBLEM][alg] = {
            'runs': 20, 'D': 31, 'first_saved_fe_range': [min(first), max(first)],
            'first_plotted_fe': int(shared.GRID[np.flatnonzero(counts == 20)[0]]),
            'terminal_fe_range': [min(terminal), max(terminal)],
            'last_saved_fe_le500_range': [min(last), max(last)],
            'snapshots_above_budget_excluded': int((group.FE > 500).sum()),
        }
        endpoints[alg] = {'mean': float(mean[-1]),
                          'std_sample': float(traces[:, -1].std(ddof=1)),
                          'run_values': traces[:, -1].tolist()}
        aggregate.extend({'Problem': PROBLEM, 'Algorithm': alg, 'FE': int(fe),
                          'MeanIGDp': float(value), 'Runs': int(count)}
                         for fe, value, count in zip(shared.GRID, mean, counts))
    pd.DataFrame(aggregate).to_csv(DATA / 'mean_igdp_fe500.csv', index=False)
    write_json(DATA / 'coverage_fe500.json', coverage)
    write_json(DATA / 'endpoints_fe500.json', endpoints)
    shared.CSV, shared.SOURCE_MANIFEST = CSV, MANIFEST
    with shared.plt.rc_context(shared.STYLE):
        figure = shared.build_single(means, PROBLEM)
        shared.save(figure, PROBLEM, coverage)
        shared.plt.close(figure)
    figure_manifest = HERE / 'fig_convergence_fe500_wfg3_m10_manifest.json'
    record = json.loads(figure_manifest.read_text(encoding='utf-8'))
    record['drawing_script_sha256'] = sha(Path(__file__))
    record['drawing_script'] = Path(__file__).name
    record['shared_style_and_alignment_script'] = Path(shared.__file__).name
    record['shared_style_and_alignment_script_sha256'] = sha(Path(shared.__file__))
    write_json(figure_manifest, record)
    for alg, result in endpoints.items():
        print(f'{shared.LABELS[alg]}: {result["mean"]:.8f} ({result["std_sample"]:.8f})')
    print('Exported 140 runs; drew WFG3 with all 20 runs at each plotted FE.')


if __name__ == '__main__':
    main()
