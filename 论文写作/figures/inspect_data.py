from pathlib import Path
import json
import pandas as pd

REPO = Path(__file__).resolve().parents[2]
EXPS = REPO / 'PlatEMO-master/PlatEMO/Experiments'
ggp = pd.read_csv(EXPS / 'REMO_new2_AdaMaO_GoodGroupPrecision/results/analysis/formal/GGP_PerRunStage.csv')
g = ggp[(ggp.Truth == 'population_final') & (ggp.SelectionRule == 'top25')]
print('GGP rows',len(ggp),len(g))
print(g.groupby(['Stage','View']).agg(n=('MeanPrecision','size'),mean=('MeanPrecision','mean')).to_string())
print('problems',g.Problem.unique())
cvp = pd.read_csv(EXPS / 'REMO_new2_AdaMaO_CandidateValueProbe/docs/data/runs.csv')
print('CVP arms',cvp.Arm.unique())
print(cvp.groupby('Arm')[['BatchSizeMean','BatchSpreadMean','SurvivalRateLate','OracleGainRatioLate']].mean().to_string())
books=json.loads((REPO/'论文写作/.experiment_work/books.json').read_text(encoding='utf-8'))
for m in [10,20]:
    key=f'最新版算法总实验\\{m}目标.xlsx'
    rows=next(iter(books[key].values()))
    print('MAIN',m,rows[0],rows[1],rows[-1])
