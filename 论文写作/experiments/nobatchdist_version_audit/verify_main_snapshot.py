"""Match main-table means/SDs to cached IGDp at run IDs 1-20 and source D."""
from pathlib import Path
import csv
import json
import math
from collections import defaultdict
import numpy as np

HERE = Path(__file__).resolve().parent
MAIN = HERE.parent/'main_performance'
manifest = json.loads((MAIN/'source_manifest.json').read_text(encoding='utf-8'))
dims = {(s['M'],r['problem']):r['D'] for s in manifest['sources'] for r in s['metadata']}
records = list(csv.DictReader((HERE/'run_inventory.csv').open(encoding='utf-8-sig')))
index = defaultdict(list)
for r in records:
    if r['M'] != r['folder_M']:
        continue
    index[(int(r['M']),r['problem'],int(r['D']),r['algorithm'])].append(r)
checks=[]
for cell in csv.DictReader((MAIN/'igd_snapshot.csv').open(encoding='utf-8-sig')):
    m=int(cell['M']);d=dims[(m,cell['problem'])]
    runs=index[(m,cell['problem'],d,cell['source_algorithm'])]
    assert sorted(int(r['run']) for r in runs)==list(range(1,21)),(m,cell['problem'],cell['algorithm'],'missing/duplicate run')
    assert all(not r['error'] and r['IGDp_final'] for r in runs)
    values=np.asarray([float(r['IGDp_final']) for r in runs])
    mean=float(values.mean());sd=float(values.std(ddof=1))
    # Half a unit at the printed scientific-notation precision.
    def matches(value,printed):
        mantissa,exponent=printed.lower().split('e')
        decimals=len(mantissa.split('.')[1])
        return abs(value-float(printed))<=0.50001*10**(int(exponent)-decimals)
    checks.append({'M':m,'problem':cell['problem'],'algorithm':cell['source_algorithm'],'D':d,
                   'n':len(runs),'mean':mean,'sd':sd,'table_mean':cell['mean'],'table_sd':cell['std'],
                   'mean_matches':matches(mean,cell['mean']),'sd_matches':matches(sd,cell['std']),
                   'min_final_fe':min(float(r['final_fe']) for r in runs),
                   'max_final_fe':max(float(r['final_fe']) for r in runs)})
report={'cells':len(checks),'mean_matches':sum(r['mean_matches'] for r in checks),
        'sd_matches':sum(r['sd_matches'] for r in checks),'checks':checks}
(HERE/'main_snapshot_check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print({k:v for k,v in report.items() if k!='checks'})
for r in checks:
    if not r['mean_matches'] or not r['sd_matches']:print('MISMATCH',r)
assert report['mean_matches']==len(checks) and report['sd_matches']==len(checks)
