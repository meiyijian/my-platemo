"""Build the fixed-k ablation table from the preserved exports."""
from pathlib import Path
import re
import openpyxl

ROOT = Path(__file__).resolve().parent
lines = [r'\begin{table*}[p]', r'\centering',
    r'\caption{IGD results of the PAQC and CDIS ablation with $k=1.5M$. Entries report mean (standard deviation). Bold marks the lowest available mean per row. A dash denotes results not yet available. Symbols $+/-/=$ retain the exported comparison of each configuration against Full (better/worse/no detected difference); they have not been recomputed from individual runs.}',
    r'\label{tab:exp:ablation}', r'\footnotesize',
    r'\setlength{\tabcolsep}{5pt}', r'\renewcommand{\arraystretch}{1.12}',
    r'\begin{tabular}{lc cccc}', r'\toprule',
    r'Problem & $M$ & REMO & REMO+PAQC & REMO+CDIS & Full (PACDIS) \\', r'\midrule']
data = {}
for m in (10, 20):
    rows = list(openpyxl.load_workbook(ROOT/'sources'/f'full_{m}.xlsx', data_only=True).active.values)
    k = 15 if m == 10 else 30
    cols = [rows[0].index(s) for s in [f'REMO (k={k})', f'REMO+HPC (k={k})', f'full (k={k})']]
    data[m] = {}
    for row in rows[1:-1]:
        if row[2] != m:
            continue
        parsed = [re.fullmatch(r'([\deE+.\-]+) \(([\deE+.\-]+)\)(?: ([+=\-]))?', row[c]).groups() for c in cols]
        data[m][row[0]] = parsed
for p in [f'DTLZ{i}' for i in range(1,8)]+[f'WFG{i}' for i in range(1,10)]:
    for m in (10,20):
        if p not in data[m]:
            continue
        vals=data[m][p]
        best=min(float(v[0]) for v in vals)
        cells=[]
        for mean,sd,symbol in vals:
            text=mean+' ('+sd+')'
            if float(mean)==best:
                text=r'\textbf{'+text+'}'
            if symbol:
                text+=r'\,$'+symbol+'$'
            cells.append(text)
        lines.append(p+' & '+str(m)+' & '+cells[0]+' & '+cells[1]+' & --- & '+cells[2]+r' \\')
    lines.append(r'\addlinespace[2pt]')
lines += [r'\bottomrule',r'\end{tabular}',r'\end{table*}']
(ROOT/'table_fixed_k.tex').write_text('\n'.join(lines)+'\n',encoding='utf-8')
assert sum(len(x) for x in data.values()) == 31
print('31 problem-objective rows; 93 source values; REMO+CDIS left missing.')
