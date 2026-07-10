import scipy.io as sio
import numpy as np
import os

STAT_DIR = r'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\stat_data'

def load_trace(f):
    d = sio.loadmat(f, struct_as_record=False, squeeze_me=True)
    st = d['stat']
    rel = list(st.rel_trace) if hasattr(st,'rel_trace') else []
    cand = list(st.cand_trace) if hasattr(st,'cand_trace') else []
    # 转 python str
    rel = [str(x) for x in rel]
    cand = [str(x) for x in cand]
    return rel, cand, st

cases = [
    ('DTLZ2','M20','DTLZ2_M20_D30_run1.mat'),     # 平滑→看indicator何时主导
    ('DTLZ7','M20','DTLZ7_M20_D30_run2.mat'),     # weighted 88%那次
    ('WFG4','M10','WFG4_M10_D30_run1.mat'),       # 混合
    ('DTLZ1','M10','DTLZ1_M10_D30_run1.mat'),     # curriculum首代
    ('DTLZ4','M20','DTLZ4_M20_D30_run1.mat'),     # explore而非indicator
]

for label,mlabel,fname in cases:
    f = os.path.join(STAT_DIR, fname)
    if not os.path.exists(f):
        print(f"[跳过] {fname} 不存在")
        continue
    rel, cand, st = load_trace(f)
    print("="*70)
    print(f"{label} {mlabel}  {fname}")
    print(f"  total_gen={st.total_gen} skip={st.skip_gen}")
    print(f"  rel: cons={st.rel_count.conservative} curr={st.rel_count.curriculum} weig={st.rel_count.weighted}")
    print(f"  cand: cons={st.cand_count.conservative} expl={st.cand_count.explore} indi={st.cand_count.indicator}")
    print(f"  --- 逐代轨迹 (gen: rel→cand) ---")
    for i in range(len(rel)):
        c = cand[i] if i < len(cand) else '?'
        print(f"  gen{i+1:2d}: {rel[i]:12s} -> {c}")
    print()
