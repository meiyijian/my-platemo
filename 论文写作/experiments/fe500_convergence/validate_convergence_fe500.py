"""Independently reconstruct plotted means from the original MAT files.

Run after the exporter and drawing script. This check uses a sequential
snapshot traversal rather than the drawing script's searchsorted alignment.
It also exercises budget, initialization, duplicate-FE, and coverage policies.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import warnings

import numpy as np
import pandas as pd
from scipy.io import loadmat
import pymupdf
from PIL import Image

HERE = Path(__file__).resolve().parent
PAPER = HERE.parents[1]
SCRIPT = PAPER / 'figures' / 'build_convergence_fe500.py'


def policy_checks():
    spec = importlib.util.spec_from_file_location('fe500_drawing', SCRIPT)
    drawing = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(drawing)
    held = drawing.resample(
        np.array([329, 350, 350, 501]), np.array([10, 9, 9.5, 1e9]))
    assert np.isnan(held[:229]).all(), 'initialization extended backward'
    assert held[229] == 10 and held[250] == 9.5, 'duplicate FE or rise lost'
    assert held[-1] == 9.5, 'above-budget value entered curve'
    assert np.isnan(drawing.resample(
        np.array([100, 499]), np.array([10, 9]))[-1]), 'short run extrapolated'
    trace = np.ones((20, 401))
    trace[-1] = 21
    mean, count = drawing.complete_run_mean(trace)
    assert np.all(mean == 2) and np.all(count == 20), 'wrong estimator'
    trace[0, -1] = np.nan
    try:
        drawing.complete_run_mean(trace)
    except ValueError:
        pass
    else:
        raise AssertionError('changing-denominator mean accepted')
    return ['initialization', 'duplicate FE', 'preserved increase',
            'budget exclusion', 'short-run coverage', 'arithmetic mean',
            'partial-run rejection']


def style_checks():
    text = (PAPER / 'HPDC-MaOEA.tex').read_text(encoding='utf-8')
    start = text.index('\\paragraph{PACDIS reaches lower endpoint values}')
    end = text.index('\\input{figures/figure_convergence_fe500}', start)
    changed = text[start:end]
    figure = (PAPER / 'figures' / 'figure_convergence_fe500.tex').read_text(encoding='utf-8')
    changed += '\n' + '\n'.join(line for line in figure.splitlines()
                                if not line.lstrip().startswith('%'))
    patterns = {
        'M1_em_dash': r'---|[\u2014\u2013]| -- ',
        'M11_passive': r'\b(is|are|was|were|be|been|being)\s+([a-z]+ed|done|made|shown|given|taken|held|built|drawn|chosen|written|known|found|seen|set|put|sent|kept|met|run|used|based)\b',
        'M2_antithesis': r',? not [0-9A-Za-z\\]|not only .* but|rather than|less .* than|is the point|whatever it is|means nothing|more than just|not in competition with|on one hand|on the other hand',
        'M3_M4_M8_M9_flourish': r'in effect|in a sense|at (its|the) (heart|core)|in essence|\btruly\b|\bgenuinely\b|\bindeed\b|\bin fact\b|precisely because|a testament to|the kind of .* that|exactly the kind|is the point|set(s)? .* apart|no (predecessor|one) .* (made|posed)|the key (insight|idea) is|the machine that|draw(s)? .* power from|under the hood|where .* meets',
        'M6_openers': r'^(Moreover|Furthermore|Additionally|Notably|Importantly|Indeed|Ultimately|Crucially|In turn|That said)',
        'M5_M16_words': r'\bnovel\b|\bsignificant\b|\bsubstantial\b|\bimpressive\b|\bpromising\b|\bcomprehensive\b|\brobust\b|\bpowerful\b|\bseamless|\bcrucial\b|\bparadigm\b|\bleverag|\butiliz|\bfinaliz|[a-z]+-oriented\b|\bfactor\b|\bfeature[ds]?\b|\bmeaningful\b|\binsightful\b|\bprestigious\b|\bpossess|\bcontact(s|ed|ing)?\b|\bcurrently\b|\bimpact(s|ed|ing)?\b',
        'M10_hype_verbs': r'promises to|stands? to|is poised to|opens the door to|is set to|has the potential to|keeps .* from|stands? in the way|\bunlocks?\b',
        'M17_fancy_verbs': r'\b(pit(s|ted|ting)?|dispatch(es|ed|ing)?|chip(s|ped|ping)? (away )?at|marshal(s|led|ling)?|orchestrat(e|es|ed|ing)|wrangl(e|es|ed|ing)|harness(es|ed|ing)?|forge[sd]?|weav(e|es|ed|ing)|delv(e|es|ed|ing) into|usher(s|ed)? in|grappl(e|es|ed|ing) with|anew|afresh)\b',
        'M18_empty_openers': r'In this (paper|section), we',
        'M12_wordiness': r'the fact that|the question (as to |of )?whether|as to whether|in order to|there is no doubt but|the reason .* is because|owing to the fact that|in a [a-z]+ manner|is a (subject|man|woman) (that|who)|in the last analysis|along these lines|in terms of|one of the most',
        'M13_qualifiers': r'\b(rather|very|pretty|little|quite|somewhat|fairly|certainly)\b',
        'M14_adverbs': r'\b(thusly|muchly|overly|firstly|secondly|thirdly)\b|[a-z]+wise\b',
        'M15_exclamation': r'!',
        'B_precision_pairs': r'\bcomprised of\b|\bdata is\b|different than|\bvery unique\b|\bdue to\b|\bless (than )?[0-9]',
    }
    counts, hits = {}, {}
    for category, pattern in patterns.items():
        matches = list(re.finditer(pattern, changed, re.I | re.M))
        counts[category] = len(matches)
        hits[category] = [m.group(0) for m in matches]
        print(category, counts[category], hits[category])
    float_modifiers = len(re.findall(r'\\begin\{figure\}\[![a-z]+\]', changed))
    assert counts['M15_exclamation'] == float_modifiers
    assert sum(counts.values()) == float_modifiers, hits
    print('M15 justification:', float_modifiers,
          'LaTeX float-placement modifiers; zero prose exclamation marks')
    assert figure.count('\\begin{figure}') == 4 and '\\begin{figure*}' not in figure
    return counts


def main():
    policies = policy_checks()
    manifest = json.loads((HERE / 'source_manifest.json').read_text(encoding='utf-8'))
    assert manifest['run_file_count'] == 560
    root = Path(manifest['source_root'])
    reconstructed = {}
    for source in manifest['sources']:
        path = root / source['relative_path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256'], path
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            data = loadmat(path, variable_names=['result', 'metric'],
                           squeeze_me=True, struct_as_record=False)
        result = np.asarray(data['result'], object).reshape(-1, 2)
        fe = np.asarray(result[:, 0], float)
        scores = np.asarray(data['metric'].IGDp, float).ravel()
        values = []
        position = -1
        for target_fe in range(100, 501):
            while position + 1 < len(fe) and fe[position + 1] <= target_fe:
                position += 1
            values.append(float(scores[position]) if position >= 0
                          and target_fe <= fe[-1] else np.nan)
        key = (source['problem'], source['algorithm'])
        reconstructed.setdefault(key, []).append(values)
    aggregated = pd.read_csv(HERE / 'convergence_mean_igdp_fe500.csv')
    assert aggregated['FE'].max() == 500 and (aggregated['N'] == 20).all()
    assert set(aggregated.groupby(['Problem', 'Algorithm']).groups) == set(reconstructed)
    max_error, upturns = 0.0, 0
    for key, values in reconstructed.items():
        matrix = np.asarray(values)
        assert matrix.shape == (20, 401)
        complete = np.isfinite(matrix).all(axis=0)
        expected = matrix[:, complete].sum(axis=0) / 20
        actual = aggregated[(aggregated['Problem'] == key[0])
                            & (aggregated['Algorithm'] == key[1])].sort_values('FE')
        assert np.array_equal(actual['FE'], np.arange(100, 501)[complete]), key
        error = float(np.max(np.abs(actual['MeanIGDp'].to_numpy() - expected)))
        max_error = max(max_error, error)
        assert np.allclose(actual['MeanIGDp'], expected, rtol=1e-13, atol=1e-13), key
        upturns += int(np.count_nonzero(np.diff(expected) > 1e-12))
    figures = []
    for problem in manifest['problems']:
        name = f'fig_convergence_fe500_{problem.lower()}_m10'
        pdf = PAPER / 'figures' / f'{name}.pdf'
        with pymupdf.open(pdf) as doc:
            assert len(doc) == 1 and not doc[0].get_images()
            dimensions = [doc[0].rect.width * 25.4 / 72,
                          doc[0].rect.height * 25.4 / 72]
            assert np.allclose(dimensions, [88, 70], atol=0.01)
            assert all(doc.extract_font(f[0])[3] for f in doc[0].get_fonts(full=True))
        with Image.open(pdf.with_suffix('.png')) as png:
            assert abs(png.width - 88 / 25.4 * 600) < 2
            assert abs(png.height - 70 / 25.4 * 600) < 2
            assert all(abs(v - 600) < 1 for v in png.info['dpi'])
        assert 'font-family' in pdf.with_suffix('.svg').read_text(encoding='utf-8')
        figures.append(name)
    style = style_checks()
    report = {
        'source_runs_verified': 560, 'mean_curves_verified': len(reconstructed),
        'aggregate_rows_verified': len(aggregated), 'plotted_fe_max': 500,
        'all_plotted_sample_sizes': 20, 'max_absolute_mean_error': max_error,
        'upward_steps_retained_in_mean_curves': upturns,
        'policy_checks': policies, 'figures_verified': figures,
        'mechanical_gate_counts': style,
        'mechanical_gate_justifications': {
            'M15_exclamation': 'Four ! characters are LaTeX float-placement modifiers in [!tbp]; zero prose exclamation marks.',
        },
        'source_csv_sha256': manifest['source_csv_sha256'],
        'aggregate_csv_sha256': hashlib.sha256(
            (HERE / 'convergence_mean_igdp_fe500.csv').read_bytes()).hexdigest(),
    }
    (HERE / 'validation.json').write_text(
        json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
