"""Refresh only the two Chinese mirror tables from the manuscript snapshot."""
from pathlib import Path
from collections import defaultdict
from decimal import Decimal
import csv
import json
import re

HERE = Path(__file__).resolve().parent
MIRROR = HERE.parents[1] / 'HPDC-MaOEA_中文版.md'
ORDER = ['REMO','SSDE','PC-SAEA','PIEA','CSEA','HES-EA','PACDIS']


def main():
    records = list(csv.DictReader((HERE / 'igd_snapshot.csv').open(encoding='utf-8-sig')))
    lookup = {(r['problem'],int(r['M']),r['algorithm']):r for r in records}
    summary = json.loads((HERE / 'summary.json').read_text(encoding='utf-8'))
    text = MIRROR.read_text(encoding='utf-8')
    for suite, count in [('DTLZ',7),('WFG',9)]:
        lines = ['| 问题 | M | ' + ' | '.join(ORDER) + ' |',
                 '| --- | --- | ' + ' | '.join(['---']*7) + ' |']
        for i in range(1,count+1):
            problem = f'{suite}{i}'
            for m in [10,15,20]:
                minimum = min(Decimal(lookup[problem,m,a]['mean']) for a in ORDER)
                cells = []
                for a in ORDER:
                    row = lookup[problem,m,a]
                    value = f"{row['mean']} ({row['std']})" + (f" {row['symbol']}" if row['symbol'] else '')
                    cells.append(f'**{value}**' if Decimal(row['mean'])==minimum else value)
                lines.append('| ' + ' | '.join([problem,str(m),*cells]) + ' |')
        totals = summary['by_suite'][suite]['baseline_plus_minus_equal']
        lines.append('| +/-/= | 全部 | ' + ' | '.join('/'.join(map(str,totals[a])) for a in ORDER[:-1]) + ' | 无 |')
        pattern = rf'(?<=\n)(\|[^\n]*\n)+(?=\n)'
        blocks = [m for m in re.finditer(pattern,text) if f'| {suite}1 ' in m.group()
                  and ('SAMOEA-TL2M' in m.group() or '| PIEA |' in m.group())]
        if len(blocks)!=1:
            raise ValueError(f'{suite}: ambiguous mirror table')
        block = blocks[0]
        text = text[:block.start()]+'\n'.join(lines)+'\n'+text[block.end():]
    MIRROR.write_text(text,encoding='utf-8',newline='\n')
    print('Updated 336 Chinese table cells and 12 symbol totals from the same snapshot.')


if __name__ == '__main__':
    main()
