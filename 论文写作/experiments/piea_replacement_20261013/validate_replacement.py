"""Audit workbook replacement, unchanged comparators and plot styling."""
from pathlib import Path
import ast
import csv
import hashlib
import io
import json
import re
import subprocess

import numpy as np
import pandas as pd
from openpyxl import load_workbook

HERE = Path(__file__).resolve().parent
PAPER = HERE.parents[1]
ROOT = PAPER.parent
BASELINE = '9c2c4d6'


def git_source(relative):
    return subprocess.check_output(['git','show',f'{BASELINE}:{relative}'],cwd=ROOT).decode('utf-8-sig')


def constants(text):
    result = {}
    def literal(node):
        if isinstance(node,ast.Name):
            return result[node.id]
        if isinstance(node,ast.List):
            return [literal(n) for n in node.elts]
        if isinstance(node,ast.Dict):
            return {literal(k):literal(v) for k,v in zip(node.keys,node.values)}
        return ast.literal_eval(node)
    for node in ast.parse(text).body:
        if isinstance(node,ast.Assign) and isinstance(node.targets[0],ast.Name):
            try:
                result[node.targets[0].id] = literal(node.value)
            except (ValueError,TypeError,KeyError):
                pass
    return result


def main():
    main_data = PAPER / 'experiments' / 'main_performance'
    rows = list(csv.DictReader((main_data/'igd_snapshot.csv').open(encoding='utf-8-sig')))
    old = list(csv.DictReader(io.StringIO(git_source('论文写作/experiments/main_performance/igd_snapshot.csv'))))
    fields = ['mean','std','symbol']
    prior = {(r['M'],r['problem'],r['algorithm']):r for r in old}
    unchanged = 0
    for row in rows:
        if row['algorithm'] != 'PIEA':
            expected = prior[row['M'],row['problem'],row['algorithm']]
            assert all(row[k]==expected[k] for k in fields),row
            unchanged += 1
    assert unchanged==288 and sum(r['algorithm']=='PIEA' for r in rows)==48
    manifest = json.loads((main_data/'source_manifest.json').read_text(encoding='utf-8'))
    for source in manifest['sources']:
        original = Path(source['source_path'])
        copy = main_data/'sources'/source['filename']
        assert hashlib.sha256(original.read_bytes()).hexdigest()==source['sha256']
        assert original.read_bytes()==copy.read_bytes()
        workbook = load_workbook(copy,data_only=True)
        sheet = workbook['IGDp']
        for row in rows:
            if row['source_file']==copy.name:
                assert sheet[row['source_cell']].value==row['raw']
        workbook.close()
    comparator_trajectories = 0
    for folder in ['fe500_convergence','fe500_convergence_wfg3']:
        relative=f'论文写作/experiments/{folder}/convergence_igdp_fe500.csv'
        before=pd.read_csv(io.StringIO(git_source(relative)),float_precision='round_trip')
        after=pd.read_csv(ROOT/relative,float_precision='round_trip')
        before=before[before.Algorithm!='SAMOEATL2M'].reset_index(drop=True)
        after=after[after.Algorithm!='PIEA'].reset_index(drop=True)
        assert before.equals(after),folder
        comparator_trajectories += len(before.groupby(['Algorithm','Problem','Run']))
    assert comparator_trajectories==600
    drawing=PAPER/'figures'/'build_convergence_fe500.py'
    before=constants(git_source('论文写作/figures/build_convergence_fe500.py'))
    after=constants(drawing.read_text(encoding='utf-8'))
    for setting in ['STYLE','M','BUDGET','PROBLEMS','MARK_EVERY','XTICKS']:
        assert before[setting]==after[setting],setting
    for setting in ['RUNS','GRID','FIGSIZE']:
        extract=lambda text: next(ast.dump(n.value,include_attributes=False) for n in ast.parse(text).body if isinstance(n,ast.Assign) and isinstance(n.targets[0],ast.Name) and n.targets[0].id==setting)
        assert extract(git_source('论文写作/figures/build_convergence_fe500.py'))==extract(drawing.read_text(encoding='utf-8'))
    for setting in ['ORDER','LABELS','COLORS','MARKERS']:
        expected=before[setting]
        if isinstance(expected,list):
            expected=['PIEA' if v=='SAMOEATL2M' else v for v in expected]
        else:
            expected={('PIEA' if k=='SAMOEATL2M' else k):('PIEA' if k=='SAMOEATL2M' and setting=='LABELS' else v) for k,v in expected.items()}
        assert expected==after[setting],setting
    # All styling/alignment implementations below the identity mapping are identical.
    for function in ['resample','complete_run_mean','legend_handles','build_single','save']:
        extract=lambda text: next(ast.dump(n,include_attributes=False) for n in ast.parse(text).body if isinstance(n,ast.FunctionDef) and n.name==function)
        assert extract(git_source('论文写作/figures/build_convergence_fe500.py'))==extract(drawing.read_text(encoding='utf-8'))
    summary=json.loads((main_data/'summary.json').read_text(encoding='utf-8'))
    assert [summary['by_objectives'][str(m)]['best_mean_counts']['PACDIS'] for m in [10,15,20]]==[5,3,3]
    for m in [10,15,20]:
        for problem in ['DTLZ6','WFG3']:
            cell=[r for r in rows if int(r['M'])==m and r['problem']==problem]
            assert min(cell,key=lambda r:float(r['mean']))['algorithm']=='PIEA'
    tex=(PAPER/'HPDC-MaOEA.tex').read_text(encoding='utf-8')
    cn=(PAPER/'HPDC-MaOEA_中文版.md').read_text(encoding='utf-8')
    assert not re.search(r'SAMOEA|TL2M|samoeatl2m',tex+cn)
    definitions=set(re.findall(r'\\bibitem\{([^}]+)\}',tex))
    citations={key.strip() for group in re.findall(r'\\cite\{([^}]+)\}',tex) for key in group.split(',')}
    assert citations<=definitions,citations-definitions
    assert len(definitions)==len(re.findall(r'\\bibitem\{([^}]+)\}',tex))
    assert 'in 11 configurations' in tex and 'on 5, 3, and 3' in tex
    assert 'in 15 configurations' not in tex
    assert '标识为 1–20 的 20 次独立运行' not in cn
    report={'baseline_commit':BASELINE,'workbook_cells_checked':336,'PIEA_cells_replaced':48,
            'unchanged_comparator_cells':unchanged,'unchanged_comparator_run_trajectories':comparator_trajectories,
            'source_workbooks_archived_without_changes':3,'style_parameters_and_drawing_functions_unchanged':True,
            'PACDIS_best_counts_M10_M15_M20':[5,3,3],'PACDIS_best_total':11,
            'active_English_and_Chinese_old_algorithm_mentions':0,'citation_keys_checked':len(citations),
            'curve_run_ids':list(range(1,21)),
            'table_and_curve_sampling_policy':'Final supplied workbook results for tables; original runs 1--20 for curves.'}
    (HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
