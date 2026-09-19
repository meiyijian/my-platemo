"""Read-only MAT/source inventory. Writes audit files beside this script.

No optimization, data renaming, or edits to source workbooks/MAT files.
Requires scipy; all paths written into the manifest retain their source identity.
"""
from pathlib import Path
import csv
import hashlib
import json
import re
import warnings
from collections import Counter, defaultdict
import numpy as np
from scipy.io import loadmat

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ROOT = Path(r'C:\Users\lsx\Desktop\REMOandDREMO测试集')
BASE = 'REMO_UniformMix_Pruned_Weighted_Lambdat030'
FULL = BASE + '_NoBatchDist'
BASELINES = ['REMO', 'PIEA', 'CSEA', 'PCSAEA_N100', 'KRVEA_100', 'MCEAD']
LEGACY = ['REMO_new2_k15', 'REMO_new2_k', 'RMEO_k_CDIS',
          'REMO_UniformMixCandidate', 'REMO_k15', 'REMO_k',
          'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original']
PATTERN = re.compile(r'_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    records, traces, groups = [], [], []
    for m in [10, 15, 20]:
        data_dir = ROOT / f'{m}目标'
        if m == 10:
            data_dir /= 'n30'
        names = [FULL, BASE] + [BASE + '_pMix' + p for p in ['000','025','050','075','100']] + LEGACY + BASELINES
        for name in names:
            folder = data_dir / name
            if not folder.is_dir():
                continue
            group = {'M': m, 'algorithm': name, 'path': str(folder), 'files_total': 0,
                     'run_1_20': 0, 'final_fe': Counter(), 'snapshots': Counter(),
                     'metrics': Counter(), 'problems': Counter(), 'issues': []}
            for f in sorted(folder.glob('*.mat')):
                match = PATTERN.search(f.name)
                if not match:
                    continue
                problem, fm, d, run = match.groups()
                group['files_total'] += 1
                if int(run) > 20:
                    continue
                record = {'algorithm':name,'problem':problem,'M':int(fm),'folder_M':m,'D':int(d),'run':int(run),
                          'path':str(f),'sha256':digest(f),'final_fe':'','snapshots':'','metric_fields':'','error':''}
                try:
                    with warnings.catch_warnings():
                        warnings.simplefilter('ignore')
                        s = loadmat(f, variable_names=['result','metric'], squeeze_me=True, struct_as_record=False)
                    result = np.asarray(s['result'], dtype=object)
                    if result.ndim == 1:
                        result = result.reshape(1, 2)
                    fe = np.asarray(result[:, 0], dtype=float)
                    metric = s['metric']
                    fields = sorted(metric._fieldnames)
                    record.update(final_fe=float(fe[-1]), snapshots=len(fe), metric_fields=';'.join(fields))
                    group['run_1_20'] += 1
                    group['final_fe'][str(int(fe[-1]))] += 1
                    group['snapshots'][str(len(fe))] += 1
                    group['metrics'][';'.join(fields)] += 1
                    group['problems'][problem] += 1
                    if not np.all(np.isfinite(fe)) or np.any(np.diff(fe) < 0):
                        group['issues'].append(f.name + ': invalid FE sequence')
                    for key in ['IGD', 'IGDp']:
                        if key in fields:
                            values = np.asarray(getattr(metric,key),dtype=float).ravel()
                            record[key+'_count'] = len(values)
                            record[key+'_final'] = float(values[-1])
                            if not np.all(np.isfinite(values)):
                                group['issues'].append(f.name+': nonfinite '+key)
                    if int(fm) != m:
                        group['issues'].append(f.name + ': filename M differs from directory M; excluded from main-table matching')
                    if int(fm) == m and name in [FULL]+BASELINES and problem in ['WFG7','WFG8']:
                        values = np.asarray(getattr(metric,'IGDp',[]),dtype=float).ravel()
                        if len(values) == len(fe) and np.all(np.isfinite(values)):
                            for step,(budget,value) in enumerate(zip(fe,values),1):
                                traces.append({'Algorithm':name,'Problem':problem,'M':m,'D':int(d),
                                               'Run':int(run),'Step':step,'FE':int(budget),'IGDp':float(value)})
                        else:
                            group['issues'].append(f.name+': IGDp trace unavailable or mismatched')
                except Exception as exc:
                    record['error'] = str(exc)
                    group['issues'].append(f.name+': '+str(exc))
                records.append(record)
            groups.append(group)
            print(m,name,group['run_1_20'],dict(group['final_fe']),len(group['issues']),flush=True)
    fields = ['algorithm','problem','M','folder_M','D','run','path','sha256','final_fe','snapshots',
              'metric_fields','IGD_count','IGD_final','IGDp_count','IGDp_final','error']
    with (HERE/'run_inventory.csv').open('w',encoding='utf-8-sig',newline='') as out:
        writer=csv.DictWriter(out,fieldnames=fields);writer.writeheader();writer.writerows(records)
    src=REPO/'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization'
    hashes=[]
    for name in [BASE,FULL,'RMEO_k_CDIS']+[BASE+'_pMix'+p for p in ['000','025','050','075','100']]:
        for f in sorted((src/name).rglob('*.m')):
            hashes.append({'path':str(f.relative_to(REPO)), 'sha256':digest(f)})
    (HERE/'inventory_summary.json').write_text(json.dumps({'data_root':str(ROOT),
        'scope':'Existing run IDs 1-20; no optimization executed; current source hashes do not prove historical execution identity',
        'groups':groups,'source_hashes':hashes},ensure_ascii=False,indent=2),encoding='utf-8')
    with (HERE/'convergence_igdp.csv').open('w',encoding='utf-8',newline='') as out:
        writer=csv.DictWriter(out,fieldnames=['Algorithm','Problem','M','D','Run','Step','FE','IGDp'])
        writer.writeheader();writer.writerows(traces)
    print('AUDIT_DONE',len(records),'files;',len(traces),'IGDp trace rows')


if __name__ == '__main__':
    main()
