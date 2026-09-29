"""Export the FE=500 IGD+ traces for the renewed Section 4.6 convergence figure.

Source: the PlatEMO MAT exports on the work machine,

    C:\\Users\\lsx\\Desktop\\REMOandDREMO测试集\\10目标\\n30\\FE500\\<algorithm>\\*.mat

Each file stores result(:,1) = FE at every snapshot and metric.IGDp = the IGD+
trajectory of that snapshot. Only runs 1-20 are exported, the subset every
algorithm in the comparison has.

The output CSV keeps the column layout of
experiments/nobatchdist_version_audit/convergence_igdp.csv so that the drawing
code and the provenance notes carry over unchanged:

    Algorithm,Problem,M,D,Run,Step,FE,IGDp

Run:
    C:\\Users\\lsx\\.workbuddy\\binaries\\python\\envs\\default\\Scripts\\python.exe export_convergence_fe500.py
"""
from pathlib import Path
import csv
import re
import warnings
from collections import Counter

import numpy as np
from scipy.io import loadmat

HERE = Path(__file__).resolve().parent
ROOT = Path(r'C:\Users\lsx\Desktop\REMOandDREMO测试集')
SUBDIR = Path('10目标') / 'n30' / 'FE500'

PACDIS = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'
ALGORITHMS = [PACDIS, 'REMO', 'PCSAEA', 'CSEA', 'HES_EA', 'SSDE', 'SAMOEATL2M']
PROBLEMS = ['DTLZ1', 'DTLZ6', 'WFG2', 'WFG7']
M = 10
RUNS = list(range(1, 21))
PATTERN = re.compile(r'_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$')


def main():
    traces, notes = [], []
    summary = {}
    for alg in ALGORITHMS:
        folder = ROOT / SUBDIR / alg
        assert folder.is_dir(), folder
        counter = Counter()
        for prob in PROBLEMS:
            for run in RUNS:
                hits = list(folder.glob(f'*_{prob}_M{M}_D*_{run}.mat'))
                if len(hits) != 1:
                    notes.append(f'{alg}/{prob}/run{run}: {len(hits)} files')
                    continue
                f = hits[0]
                d = int(re.search(r'_D(\d+)_', f.name).group(1))
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore')
                    s = loadmat(f, variable_names=['result', 'metric'],
                                squeeze_me=True, struct_as_record=False)
                result = np.asarray(s['result'], dtype=object)
                if result.ndim == 1:
                    result = result.reshape(1, 2)
                fe = np.asarray(result[:, 0], dtype=float).ravel()
                metric = s['metric']
                igdp = np.asarray(getattr(metric, 'IGDp'), dtype=float).ravel()
                if igdp.size != fe.size:
                    notes.append(f'{f.name}: FE {fe.size} vs IGDp {igdp.size}')
                    continue
                if not np.all(np.isfinite(igdp)) or np.any(np.diff(fe) < 0):
                    notes.append(f'{f.name}: nonfinite IGDp or non-monotone FE')
                    continue
                for step, (budget, value) in enumerate(zip(fe, igdp), 1):
                    traces.append({'Algorithm': alg, 'Problem': prob, 'M': M, 'D': d,
                                   'Run': run, 'Step': step, 'FE': int(budget),
                                   'IGDp': float(value)})
                counter[prob] += 1
        summary[alg] = dict(counter)

    assert len(traces) > 0, 'no traces exported'
    out = HERE / 'convergence_igdp_fe500.csv'
    with out.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.DictWriter(fh, fieldnames=['Algorithm', 'Problem', 'M', 'D',
                                                'Run', 'Step', 'FE', 'IGDp'])
        writer.writeheader()
        writer.writerows(traces)
    print('wrote', out)
    print('trace rows:', len(traces))
    for alg, c in summary.items():
        print(f'  {alg:<52} {dict(c)}')
    if notes:
        print('NOTES:')
        for n in notes:
            print('  ', n)
    else:
        print('no issues')


if __name__ == '__main__':
    main()
