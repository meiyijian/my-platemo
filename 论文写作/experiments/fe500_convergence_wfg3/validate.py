"""Reconstruct WFG3 means directly from 140 MAT files, independently of plotting."""
from pathlib import Path
import ast
import hashlib
import json
import re
import warnings

import numpy as np
import pandas as pd
import pymupdf
from scipy.io import loadmat
from PIL import Image

HERE = Path(__file__).resolve().parent
PAPER = HERE.parents[1]


def main():
    manifest = json.loads((HERE / 'source_manifest.json').read_text(encoding='utf-8'))
    raw = pd.read_csv(HERE / 'convergence_igdp_fe500.csv', float_precision='round_trip')
    aggregate = pd.read_csv(HERE / 'mean_igdp_fe500.csv', float_precision='round_trip')
    assert hashlib.sha256((HERE / 'convergence_igdp_fe500.csv').read_bytes()).hexdigest() == manifest['source_csv_sha256']
    assert len(manifest['sources']) == 140
    traces = {}
    for item in manifest['sources']:
        path = Path(manifest['source_root']) / item['relative_path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], path
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            mat = loadmat(path, variable_names=['result', 'metric'],
                          squeeze_me=True, struct_as_record=False)
        fe = np.asarray(mat['result'], object).reshape(-1, 2)[:, 0].astype(float)
        metric = np.asarray(mat['metric'].IGDp, float).ravel()
        csv_run = raw[(raw.Algorithm == item['algorithm']) & (raw.Run == item['run'])].sort_values('Step')
        assert np.array_equal(csv_run.FE.to_numpy(), fe)
        assert np.array_equal(csv_run.IGDp.to_numpy(), metric)
        values, position = [], -1
        for target in range(100, 501):
            while position + 1 < len(fe) and fe[position + 1] <= target:
                position += 1
            values.append(metric[position] if position >= 0 and target <= fe[-1] else np.nan)
        traces.setdefault(item['algorithm'], []).append(values)
    means, max_error = {}, 0.0
    for alg, values in traces.items():
        matrix = np.asarray(values)
        assert matrix.shape == (20, 401)
        count = np.isfinite(matrix).sum(axis=0)
        assert set(count) <= {0, 20} and count[-1] == 20
        mean = matrix.mean(axis=0)
        record = aggregate[aggregate.Algorithm == alg].sort_values('FE')
        assert np.array_equal(record.FE.to_numpy(), np.arange(100, 501))
        assert np.array_equal(record.Runs.to_numpy(), count)
        assert np.allclose(record.MeanIGDp, mean, rtol=1e-13, atol=1e-13, equal_nan=True)
        max_error = max(max_error, float(np.nanmax(np.abs(record.MeanIGDp - mean))))
        means[alg] = mean
    pac_name = next(a for a in means if a.startswith('REMO_Uniform'))
    pac = means[pac_name]
    assert (np.diff(pac) <= 1e-12).all()
    assert (means['REMO'][240:] < pac[240:]).all()
    assert means['SAMOEATL2M'][240] > pac[240] and means['SAMOEATL2M'][-1] < pac[-1]
    for alg, rounded in [(pac_name, '1.4387'), ('REMO', '1.2630'), ('SAMOEATL2M', '0.89820')]:
        assert f'{means[alg][-1]:.{len(rounded.split(".")[1])}f}' == rounded
    name = 'fig_convergence_fe500_wfg3_m10'
    figure = PAPER / 'figures' / (name + '.pdf')
    with pymupdf.open(figure) as doc:
        assert len(doc) == 1 and not doc[0].get_images()
        assert np.allclose([doc[0].rect.width * 25.4 / 72, doc[0].rect.height * 25.4 / 72], [88, 70], atol=.01)
        assert all(doc.extract_font(f[0])[3] for f in doc[0].get_fonts(full=True))
    with Image.open(figure.with_suffix('.png')) as png:
        assert abs(png.width - 88 / 25.4 * 600) < 2
        assert abs(png.height - 70 / 25.4 * 600) < 2
        assert all(abs(v - 600) < 1 for v in png.info['dpi'])
    assert 'font-family' in figure.with_suffix('.svg').read_text(encoding='utf-8')

    # Reuse only the literal grep patterns, never the old scope or pass/fail rules.
    old_validator = HERE.parent / 'fe500_convergence' / 'validate_convergence_fe500.py'
    tree = ast.parse(old_validator.read_text(encoding='utf-8'))
    patterns = next(ast.literal_eval(n.value) for n in ast.walk(tree)
                    if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name)
                    and t.id == 'patterns' for t in n.targets))
    manuscript = (PAPER / 'HPDC-MaOEA.tex').read_text(encoding='utf-8')
    starts_ends = [
        ('We select DTLZ1, DTLZ6', 'Every curve averages'),
        ('\\paragraph{WFG3 remains', '\\subsection{REMO-Referenced Component Comparisons}'),
        ('The WFG3 results limit', 'candidate pool itself.'),
    ]
    selected = []
    for first, last in starts_ends:
        start = manuscript.index(first)
        end = manuscript.index(last, start) + len(last)
        selected.extend((f'HPDC-MaOEA.tex:{manuscript[:start].count(chr(10))+i+1}', line)
                        for i, line in enumerate(manuscript[start:end].splitlines()))
    selected.extend((f'figure_convergence_wfg3_fe500.tex:{i}', line)
                    for i, line in enumerate((PAPER / 'figures' / 'figure_convergence_wfg3_fe500.tex').read_text(encoding='utf-8').splitlines(), 1))
    counts, hits = {}, {}
    for category, pattern in patterns.items():
        found = [{'location': loc, 'match': m.group(0), 'line': line}
                 for loc, line in selected for m in re.finditer(pattern, line, re.I)]
        counts[category], hits[category] = len(found), found
        print(category, len(found))
        for entry in found:
            print(' ', entry['location'], entry['line'])
    # Factual limits are allowed by M2; ! is solely a LaTeX float placement flag.
    assert all(count == 0 for rule, count in counts.items() if rule not in {'M2_antithesis', 'M15_exclamation'})
    assert counts['M15_exclamation'] == 0
    write = {
        'source_runs_verified': 140, 'mean_curves_verified': len(means),
        'raw_rows_verified': len(raw), 'grid_rows_verified': len(aggregate),
        'max_absolute_mean_error': max_error,
        'all_plotted_sample_sizes': 20, 'plotted_fe_max': 500,
        'manuscript_trajectory_and_endpoint_claims_verified': True,
        'vector_pdf_embedded_fonts_dimensions_and_png_resolution_verified': True,
        'mechanical_gate_counts': counts, 'mechanical_gate_hits': hits,
        'justifications': {
            'M2_antithesis': 'Factual evidence limits: no coverage measurement or causal WFG3 attribution; over-budget metrics excluded.',
            'M15_exclamation': 'No prose exclamations or new float-placement flags.',
        },
    }
    (HERE / 'validation.json').write_text(json.dumps(write, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('PASS: 140 original runs; seven curves; all numerical manuscript claims.')


if __name__ == '__main__':
    main()
