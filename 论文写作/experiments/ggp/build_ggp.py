"""Verify GGP exports, archive provenance, and build the manuscript table."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
EXP = ROOT / 'PlatEMO-master/PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_GoodGroupPrecision'
PROD = ROOT / 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main(from_exports=False):
    cp = pd.read_csv(HERE / 'checkpoints.csv')
    runs = pd.read_csv(HERE / 'per_run.csv')
    tests = pd.read_csv(HERE / 'comparisons.csv')
    keys = ['Problem', 'M', 'Run', 'SnapshotID']
    assert len(cp) == 5440 and len(runs) == 160 and len(tests) == 32
    assert not cp.duplicated(keys).any()
    assert (cp.groupby(['Problem', 'M', 'Run']).size() == 34).all()
    actual = cp.groupby(['Problem','M','Run'])[runs.columns[3:]].mean().sort_index()
    expected = runs.set_index(['Problem','M','Run']).sort_index()
    assert np.allclose(actual.to_numpy(),expected.to_numpy(),atol=1e-12,rtol=0)
    for _, test in tests.iterrows():
        s = runs[(runs.Problem==test.Problem) & (runs.M==test.M)]
        x,y = s[test.Outcome+'PAQC'],s[test.Outcome+test.Control]
        assert abs(x.mean()-test.PAQCMean)<1e-12
        assert abs(y.mean()-test.ControlMean)<1e-12
        d = np.rint(x*850).astype(int)-np.rint(y*850).astype(int)
        assert (int((d>0).sum()),int((d==0).sum()),int((d<0).sum())) == (test.Wins,test.Ties,test.Losses)
    old = None if from_exports else pd.read_csv(EXP / 'results/analysis/formal/NBGGP_CheckpointMetrics.csv')
    for outcome, truth, stem in ([] if from_exports else [('Retention', 'population_final', None), ('Current', None, 'CurrentGood')]):
        if truth:
            for name, view in [('PAQC', 'score_hybrid'), ('Direction', 'score_v'), ('Anchor', 'anchor_margin'), ('Native', 'label_dyn')]:
                s = old[(old.Truth == truth) & (old.View == view)]
                z = cp.merge(s[keys + ['Precision', 'Chance']], on=keys, validate='one_to_one', suffixes=('', 'Old'))
                assert len(z) == 5440
                assert np.allclose(z[outcome+name], z.Precision, atol=1e-12, rtol=0)
                assert np.allclose(z.Chance, z.ChanceOld, atol=1e-12, rtol=0)
        else:
            s = pd.read_csv(EXP / 'results/analysis/formal/current_good_g/CurrentGood_Checkpoints.csv')
            z = cp.merge(s[keys + ['HybridPrecision','DirectionPrecision','AnchorPrecision']], on=keys, validate='one_to_one')
            assert len(z) == 5440
            for a,b in [('PAQC','Hybrid'),('Direction','Direction'),('Anchor','Anchor')]:
                assert np.allclose(z['Current'+a], z[b+'Precision'], atol=1e-12, rtol=0)
    # Independent verification of Holm arithmetic over the 32 reported contrasts.
    order = np.argsort(tests.PRaw.to_numpy(), kind='stable')
    corrected = np.minimum(1, np.maximum.accumulate(tests.PRaw.to_numpy()[order] * np.arange(32,0,-1)))
    assert np.allclose(tests.PHolm.to_numpy()[order], corrected, atol=1e-12, rtol=0)
    means = runs.groupby(['Problem','M']).mean(numeric_only=True)
    sds = runs.groupby(['Problem','M']).std(numeric_only=True, ddof=1)
    means.to_csv(HERE/'configuration_means.csv')
    sds.to_csv(HERE/'configuration_sd.csv')
    stages = cp.groupby(['Problem','M','Run','Stage']).mean(numeric_only=True).reset_index()
    stages.groupby('Stage').mean(numeric_only=True).to_csv(HERE/'stage_means.csv')
    # Resample independent runs within each fixed problem-objective configuration.
    rng = np.random.default_rng(20261004)
    intervals = {}
    for outcome in ['Retention','Current']:
        for baseline in ['Direction','Anchor']:
            bootstrap = np.zeros(10000)
            for _, group in runs.groupby(['Problem','M']):
                d = (group[outcome+'PAQC'] - group[outcome+baseline]).to_numpy()
                bootstrap += d[rng.integers(0,20,size=(10000,20))].mean(axis=1)/8
            delta = float((runs[outcome+'PAQC']-runs[outcome+baseline]).mean())
            intervals[outcome+'Vs'+baseline] = {'delta_pp':100*delta, 'ci95_pp':(100*np.quantile(bootstrap,[.025,.975])).tolist()}
    (HERE/'bootstrap_intervals.json').write_text(json.dumps(intervals,indent=2)+'\n',encoding='utf-8')

    overall = runs.mean(numeric_only=True)
    write_table(means,sds,tests,overall,['Anchor','PAQC'],False)
    write_table(means,sds,tests,overall,['Anchor','Direction','PAQC'],True)

    if from_exports:
        print('GGP_EXPORTS_VERIFIED: 5440 checkpoint rows, 160 run rows, 32 comparisons; main and appendix tables rebuilt from committed exports.')
        return
    sources = HERE/'sources'
    sources.mkdir(exist_ok=True)
    files = list((EXP/'algorithms').rglob('*.m')) + [EXP/x for x in ['README.md','NBGGPProtocol.m','NBGGPStableSeed.m','NBGGPStageBin.m','NBGGPResultPath.m','NBGGPHolmAdjust.m','NBGGPComputeRunMetrics.m','NBGGPBinaryMetrics.m','NBGGPComparePaired.m','NBGGPValidateRunFile.m','run_NoBatchDistGoodGroupPrecision.m','analyze_NBGGPCurrentGoodPrecision.m','verify_NBGGP.m','equivalence_passed.txt']]
    files += list(PROD.rglob('*.m'))
    files += [ROOT/'PlatEMO-master/PlatEMO/Problems/Multi-objective optimization/DTLZ'/f'{p}.m' for p in ['DTLZ2','DTLZ4','DTLZ5','DTLZ7']]
    files += [EXP.parent/'REMO_new2_AdaMaO_UniformMix_LabelValidation/ReconstructFutureLabelOutcomes.m']
    manifest = []
    for file in files:
        rel = file.relative_to(ROOT)
        dest = sources/rel
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(file,dest)
        manifest.append({'path':rel.as_posix(),'sha256':sha(file),'archived':True})
    for file in sorted((EXP/'results/raw/formal').rglob('*.mat')):
        manifest.append({'path':file.relative_to(ROOT).as_posix(),'sha256':sha(file),'bytes':file.stat().st_size,'archived':False})
    for file in [EXP/'results/analysis/formal/NBGGP_CheckpointMetrics.csv',EXP/'results/analysis/formal/current_good_g/CurrentGood_Checkpoints.csv']:
        manifest.append({'path':file.relative_to(ROOT).as_posix(),'sha256':sha(file),'archived':False})
    (HERE/'source_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('GGP_EXPORT_VERIFIED: raw reconstruction matches both original checkpoint exports.')
    print('OVERALL', overall.to_string())
    print('INTERVALS',json.dumps(intervals))
    print(tests.to_string(index=False))


def write_table(means,sds,tests,overall,names,appendix):
    n = len(names)
    env = 'table*'
    placement = '!t' if appendix else 't'
    label = 'tab:app:ggp' if appendix else 'tab:exp:ggp'
    caption = (r'Complete grouping controls on matched population checkpoints.' if appendix else
               r'PAQC versus representative-margin grouping on matched population checkpoints.')
    headers = {'Anchor':r'Margin $A$','Direction':r'Direction $S$','PAQC':r'PAQC $H$'}
    lines = [r'\begin{'+env+'}['+placement+']',r'\centering',
        r'\caption{'+caption+r' Entries report mean precision (\%) and run-level standard deviation.}',
        r'\label{'+label+'}',r'\begingroup',r'\setlength{\tabcolsep}{5pt}',r'\renewcommand{\arraystretch}{1.12}',r'\small',
        r'\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lc '+'c'*n+' '+'c'*(n+1)+'@{}}',r'\toprule',
        r' & & \multicolumn{'+str(n)+r'}{c}{Current convergence precision} & \multicolumn{'+str(n+1)+r'}{c}{Final-retention precision} \\',
        r'\cmidrule(lr){3-'+str(2+n)+r'}\cmidrule(lr){'+str(3+n)+'-'+str(3+2*n)+'}',
        ' & '.join(['Problem',r'$M$']+[headers[x] for _ in range(2) for x in names]+['Chance'])+r' \\',r'\midrule']
    for key, mean in means.iterrows():
        cells = [key[0], str(key[1])]
        for outcome in ['Current','Retention']:
            best = max(mean[outcome+x] for x in names)
            for name in names:
                val, sd = 100*mean[outcome+name], 100*sds.loc[key,outcome+name]
                number = f'{val:.2f}'
                if mean[outcome+name] == best:
                    number = r'\mathbf{'+number+'}'
                mark = ''
                if name != 'PAQC':
                    t = tests[(tests.Problem==key[0]) & (tests.M==key[1]) & (tests.Outcome==outcome) & (tests.Control==name)].iloc[0]
                    mark = '=' if t.PHolm >= .05 else ('-' if t.Delta>0 else '+')
                cells.append(r'\shortstack{$'+number+(r'^{'+mark+'}' if mark else '')+r'$\\$('+f'{sd:.2f}'+r')$}')
            if outcome == 'Retention':
                cells.append(f'{100*mean.Chance:.2f}')
        lines.append(' & '.join(cells)+r' \\')
    lines += [r'\midrule']
    lines.append(' & '.join(['Mean','']+[f'{100*overall[o+n]:.2f}' for o in ['Current','Retention'] for n in names]+[f'{100*overall.Chance:.2f}'])+r' \\')
    lines += [r'\bottomrule', r'\end{tabular*}', r'\endgroup',
        r'\par\vspace{3pt}\begin{minipage}{0.98\textwidth}\scriptsize',
        r'Each of the 160 runs contributes the mean of 34 checkpoints; each configuration contains 20 runs.',
        r'Each rule selects 25 of the same 100 solutions. Bold marks the largest mean among the rules shown for each outcome.',
        r'A baseline superscript $+/-/=$ denotes higher/lower/no detected difference relative to PAQC under two-sided paired Wilcoxon signed-rank tests, with Holm correction across all 32 comparisons ($\alpha=0.05$).',
        r'Chance is checkpoint prevalence for final retention; current convergence has a fixed chance level of 25\%.',
        r'The last row averages the eight configurations and carries no pooled significance test.']
    if not appendix:
        lines.append(r'The correction family includes the direction-only control; \ref{app:ggp} reports all three rules together.')
    lines += [r'\end{minipage}',r'\end{'+env+'}','']
    output = 'table_ggp_complete.tex' if appendix else 'table_ggp.tex'
    (HERE/output).write_text('\n'.join(lines),encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--from-exports',action='store_true',help='Build from committed CSVs without external raw files; retain the source manifest.')
    main(parser.parse_args().from_exports)
