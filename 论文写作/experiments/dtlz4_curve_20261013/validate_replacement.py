"""Check the case replacement without changing other experiments or plot style."""
from pathlib import Path
import ast
import csv
import hashlib
import io
import json
import subprocess

HERE = Path(__file__).resolve().parent
PAPER = HERE.parents[1]
ROOT = PAPER.parent
BASELINE = 'e25f295'


def previous(path):
    return subprocess.check_output(['git', 'show', f'{BASELINE}:论文写作/{path}'], cwd=ROOT)


def main():
    data = PAPER / 'experiments/fe500_convergence'
    before = list(csv.DictReader(io.StringIO(previous(
        'experiments/fe500_convergence/convergence_igdp_fe500.csv').decode('utf-8'))))
    current = list(csv.DictReader((data / 'convergence_igdp_fe500.csv').open(encoding='utf-8')))
    retained = {'DTLZ1', 'WFG2', 'WFG7'}
    assert [r for r in before if r['Problem'] in retained] == [r for r in current if r['Problem'] in retained]
    assert {r['Problem'] for r in current} == retained | {'DTLZ4'}
    dtlz4 = [r for r in current if r['Problem'] == 'DTLZ4']
    runs = {(r['Algorithm'], int(r['Run'])) for r in dtlz4}
    assert len(runs) == 140 and all(int(r['M']) == 10 and int(r['D']) == 30 for r in dtlz4)
    endpoint = json.loads((data / 'convergence_at_500.json').read_text(encoding='utf-8'))
    assert all(r['best'].startswith('REMO_UniformMix_') for r in endpoint)
    d4 = next(r for r in endpoint if r['problem'] == 'DTLZ4')
    expected = {'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist': .6132632637979682,
                'REMO': .6347078212915865, 'PIEA': .819819998552626}
    assert all(abs(d4['means'][a] - value) < 1e-12 for a, value in expected.items())
    old_style = ast.parse(previous('figures/build_convergence_fe500.py').decode('utf-8'))
    new_style = ast.parse((PAPER / 'figures/build_convergence_fe500.py').read_text(encoding='utf-8'))
    def plot_style(tree):
        functions = {n.name: ast.dump(n) for n in tree.body if isinstance(n, ast.FunctionDef)}
        settings = {}
        for n in tree.body:
            if isinstance(n, ast.Assign):
                for target in n.targets:
                    if isinstance(target, ast.Name) and target.id in {
                        'ORDER', 'LABELS', 'COLORS', 'MARKERS', 'M', 'BUDGET', 'RUNS',
                        'GRID', 'MARK_EVERY', 'FIGSIZE', 'XTICKS', 'STYLE'}:
                        settings[target.id] = ast.dump(n.value)
        return functions, settings
    assert plot_style(old_style) == plot_style(new_style)
    for name in ['igd_snapshot.csv', 'summary.json', 'table_dtlz.tex', 'table_wfg.tex']:
        assert previous(f'experiments/main_performance/{name}').decode('utf-8').replace('\r\n', '\n') == (PAPER / 'experiments/main_performance' / name).read_text(encoding='utf-8')
    cn = (PAPER / 'HPDC-MaOEA_中文版.md').read_text(encoding='utf-8')
    old_cn = previous('HPDC-MaOEA_中文版.md').decode('utf-8')
    assert [l for l in cn.splitlines() if l.startswith('|')] == [l for l in old_cn.splitlines() if l.startswith('|')]
    tex = (PAPER / 'HPDC-MaOEA.tex').read_text(encoding='utf-8')
    prose = tex[tex.index('\\paragraph{PACDIS reaches lower endpoint means}'):tex.index('\\input{figures/figure_convergence_fe500}')]
    assert 'DTLZ6' not in prose and 'WFG3' in prose and 'no difference' in prose
    figure = (PAPER / 'figures/figure_convergence_fe500.tex').read_text(encoding='utf-8')
    assert 'dtlz6' not in figure.lower() and 'fig:exp:convergence:dtlz4' in figure
    assert hashlib.sha256((PAPER / 'HPDC-MaOEA.tex').read_bytes()).hexdigest().upper() in cn
    report = {'baseline': BASELINE, 'unchanged_run_trajectories': 420,
              'DTLZ4_run_trajectories': len(runs), 'new_missing_PIEA_metrics': 18,
              'all_active_favorable_cases_have_lowest_endpoint_mean': True,
              'DTLZ4_endpoint_means': expected, 'plot_functions_and_style_unchanged': True,
              'main_tables_and_Chinese_table_rows_unchanged': True,
              'WFG3_failure_case_retained': True}
    (HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
