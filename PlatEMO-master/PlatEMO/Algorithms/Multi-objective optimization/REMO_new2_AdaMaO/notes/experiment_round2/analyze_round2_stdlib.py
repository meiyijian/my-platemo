# -*- coding: utf-8 -*-
"""第二轮实验数据独立分析（纯标准库，不依赖 pandas）。
目的：独立复算 mode_distribution_r2.csv + diagnostics_r2.csv，
核对《第二轮实验报告.md》的关键论断，并挖掘被均值掩盖的细节。"""
import csv, math, os, sys
from collections import defaultdict, Counter

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

HERE = os.path.dirname(os.path.abspath(__file__))
MODE = os.path.join(HERE, 'mode_distribution_r2.csv')
DIAG = os.path.join(HERE, 'diagnostics_r2.csv')
R1   = os.path.join(HERE, '..', 'mode_distribution.csv')  # 第一轮（可选）

def read_csv(path):
    with open(path, newline='', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

def fnum(x):
    if x is None: return None
    x = x.strip()
    if x == '' or x.lower() == 'nan': return None
    try: return float(x)
    except ValueError: return None

def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else float('nan')

def std(xs):  # 样本标准差
    xs = [x for x in xs if x is not None]
    if len(xs) < 2: return 0.0
    m = sum(xs) / len(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1))

def pctl(xs, p):
    xs = sorted(x for x in xs if x is not None)
    if not xs: return float('nan')
    k = (len(xs) - 1) * p
    f, c = math.floor(k), math.ceil(k)
    if f == c: return xs[int(k)]
    return xs[f] * (c - k) + xs[c] * (k - f)

def frac(xs, pred):
    xs = [x for x in xs if x is not None]
    return (sum(1 for x in xs if pred(x)) / len(xs) * 100) if xs else float('nan')

dm = read_csv(MODE)
dd = read_csv(DIAG)
for r in dm:
    r['M'] = int(r['M'])
    for c in r:
        if c.endswith('_ratio') or c in ('total_gen', 'skip_gen'):
            r[c] = fnum(r[c])
for r in dd:
    r['M'] = int(r['M']); r['gen'] = int(r['gen']); r['run_id'] = int(r['run_id'])
    for c in ('p_err', 'prev_p_err', 'coverage', 'degeneracy', 'mean_conf'):
        r[c] = fnum(r[c])

REL = ['rel_conservative_ratio', 'rel_curriculum_ratio', 'rel_weighted_ratio']
CAND = ['cand_conservative_ratio', 'cand_explore_ratio', 'cand_indicator_ratio']

print("=" * 72)
print(" 数据概览")
print("=" * 72)
probs = sorted(set(r['problem'] for r in dm))
Ms = sorted(set(r['M'] for r in dm))
print(f"模式表: {len(dm)} 运行 | 诊断表: {len(dd)} 代行")
print(f"问题({len(probs)}): {probs}")
print(f"M: {Ms} | 每 problem×M 运行数: {len(dm)//(len(probs)*len(Ms))}")
print(f"total_gen: 均 {mean([r['total_gen'] for r in dm]):.1f}  "
      f"skip_gen 总和: {int(sum(r['skip_gen'] for r in dm))}")

print("\n" + "=" * 72)
print(" A. 模式分布 10 次统计 (mean±std, 按 problem×M)")
print("=" * 72)
grp = defaultdict(list)
for r in dm:
    grp[(r['problem'], r['M'])].append(r)
for key in sorted(grp):
    rows = grp[key]
    v = {c: mean([r[c] for r in rows]) for c in REL + CAND}
    s = {c: std([r[c] for r in rows]) for c in REL + CAND}
    print(f"{key[0]:6s} M{key[1]:2d} | rel cons {v[REL[0]]:.2f}±{s[REL[0]]:.2f} "
          f"curr {v[REL[1]]:.2f}±{s[REL[1]]:.2f} weig {v[REL[2]]:.2f}±{s[REL[2]]:.2f} "
          f"|| cand cons {v[CAND[0]]:.2f} expl {v[CAND[1]]:.2f}±{s[CAND[1]]:.2f} "
          f"indi {v[CAND[2]]:.2f}±{s[CAND[2]]:.2f}")

print("\n" + "=" * 72)
print(" B. 【核实】p_err 真实分布 — 报告称『全程 <0.1』是否成立")
print("=" * 72)
allp = [r['p_err'] for r in dd]
print(f"全局 p_err: n={sum(1 for x in allp if x is not None)} "
      f"NaN={sum(1 for x in allp if x is None)}")
print(f"  mean={mean(allp):.3f} median={pctl(allp,.5):.3f} "
      f"p90={pctl(allp,.9):.3f} p99={pctl(allp,.99):.3f} max={max(x for x in allp if x is not None):.3f}")
print(f"  >0.1 占比={frac(allp, lambda x: x>0.1):.1f}%  "
      f">0.35 占比={frac(allp, lambda x: x>0.35):.1f}%")
print("  按 gen 阶段（复现报告 G 的分组）:")
for name, gens in [('gen1',[1]),('gen2-5',[2,3,4,5]),('gen6-15',list(range(6,16))),('gen16+',list(range(16,40)))]:
    sub = [r['p_err'] for r in dd if r['gen'] in gens]
    print(f"    {name:8s}: mean={mean(sub):.3f} max={max((x for x in sub if x is not None), default=float('nan')):.3f} "
          f"<=0.35占比={frac(sub, lambda x: x<=0.35):.0f}%  >0.35占比={frac(sub, lambda x: x>0.35):.0f}%")

print("\n" + "=" * 72)
print(" C. 假设1: degeneracy 是否 <0.45 (按 problem×M)")
print("=" * 72)
for prob in probs:
    for m in Ms:
        sub = [r['degeneracy'] for r in dd if r['problem']==prob and r['M']==m]
        if not sub: continue
        print(f"{prob:6s} M{m:2d}: degeneracy mean={mean(sub):.3f} "
              f"min={min(x for x in sub if x is not None):.3f} max={max(x for x in sub if x is not None):.3f} "
              f"| <0.45占比={frac(sub, lambda x: x<0.45):.0f}%")

print("\n" + "=" * 72)
print(" D. 假设2: curriculum 触发分析")
print("=" * 72)
curr = [r for r in dd if r['relation_mode']=='curriculum']
print(f"curriculum: {len(curr)}/{len(dd)} ({len(curr)/len(dd)*100:.1f}%)")
gen1c = [r for r in curr if r['gen']==1]
restc = [r for r in curr if r['gen']!=1]
print(f"  gen1: {len(gen1c)} 次 | 非gen1: {len(restc)} 次")
print(f"  [全部] prev_p_err mean={mean([r['prev_p_err'] for r in curr]):.3f}  "
      f"p_err mean={mean([r['p_err'] for r in curr]):.3f}")
print(f"  [非gen1] prev_p_err mean={mean([r['prev_p_err'] for r in restc]):.3f} "
      f">0.35占比={frac([r['prev_p_err'] for r in restc], lambda x: x>0.35):.0f}% "
      f"| p_err mean={mean([r['p_err'] for r in restc]):.3f}")
gd = Counter(r['gen'] for r in restc)
print(f"  非gen1 的 gen 分布(top): {sorted(gd.items())}")

print("\n" + "=" * 72)
print(" E. 假设3: weighted 触发分析")
print("=" * 72)
weig = [r for r in dd if r['relation_mode']=='weighted']
print(f"weighted: {len(weig)}/{len(dd)} ({len(weig)/len(dd)*100:.1f}%)")
print(f"  coverage  mean={mean([r['coverage'] for r in weig]):.3f} <0.60占比={frac([r['coverage'] for r in weig], lambda x: x<0.60):.0f}%")
print(f"  prev_p_err mean={mean([r['prev_p_err'] for r in weig]):.3f} <=0.35占比={frac([r['prev_p_err'] for r in weig], lambda x: x<=0.35):.0f}%")
print(f"  mean_conf mean={mean([r['mean_conf'] for r in weig]):.3f} >=0.55占比={frac([r['mean_conf'] for r in weig], lambda x: x>=0.55):.0f}%")

print("\n" + "=" * 72)
print(" F. relation_mode / candidate_mode 全局占比 + 联合分布")
print("=" * 72)
relc = Counter(r['relation_mode'] for r in dd)
canc = Counter(r['candidate_mode'] for r in dd)
print(f"  relation : {dict(relc)}")
print(f"  candidate: {dict(canc)}")
print("  联合 (relation × candidate):")
joint = Counter((r['relation_mode'], r['candidate_mode']) for r in dd)
for k in sorted(joint):
    print(f"    {k[0]:12s} × {k[1]:12s}: {joint[k]:4d} ({joint[k]/len(dd)*100:.1f}%)")

print("\n" + "=" * 72)
print(" G. 候选模式切换频率 (按 problem×M×run 分组)")
print("=" * 72)
runs = defaultdict(list)
for r in dd:
    runs[(r['problem'], r['M'], r['run_id'])].append(r)
switches = {}
for key, rows in runs.items():
    rows = sorted(rows, key=lambda r: r['gen'])
    seq = [r['candidate_mode'] for r in rows]
    switches[key] = sum(1 for i in range(1, len(seq)) if seq[i] != seq[i-1])
sw = list(switches.values())
print(f"  每运行切换次数: mean={mean(sw):.1f} min={min(sw)} max={max(sw)}")
print(f"  0次(锁定)占比={sum(1 for x in sw if x==0)/len(sw)*100:.0f}%  >=2次占比={sum(1 for x in sw if x>=2)/len(sw)*100:.0f}%")
byPM = defaultdict(list)
for (p,m,_), n in switches.items():
    byPM[(p,m)].append(n)
print("  按 problem×M 平均切换次数:")
for key in sorted(byPM):
    print(f"    {key[0]:6s} M{key[1]:2d}: {mean(byPM[key]):.1f}")

print("\n" + "=" * 72)
print(" H. degeneracy 与 M 的关系")
print("=" * 72)
for m in Ms:
    sub = [r['degeneracy'] for r in dd if r['M']==m]
    print(f"  M={m}: degeneracy mean={mean(sub):.3f} >=0.45占比={frac(sub, lambda x: x>=0.45):.0f}%")

print("\n" + "=" * 72)
print(" I. indicator 触发条件拆解 (DTLZ4/7 M20 为何不触发)")
print("=" * 72)
for prob in ['DTLZ4', 'DTLZ7']:
    sub = [r for r in dd if r['problem']==prob and r['M']==20]
    if not sub: continue
    deg = frac([r['degeneracy'] for r in sub], lambda x: x>=0.45)
    pe  = frac([r['p_err'] for r in sub], lambda x: x<=0.35)
    both = sum(1 for r in sub if r['degeneracy'] is not None and r['p_err'] is not None
               and r['degeneracy']>=0.45 and r['p_err']<=0.35)/len(sub)*100
    print(f"  {prob} M20: deg>=0.45={deg:.0f}%  p_err<=0.35={pe:.0f}%  两者同时={both:.0f}%")

print("\n" + "=" * 72)
print(" J. DTLZ7_M20 不稳健性 — 逐次 weighted 占比")
print("=" * 72)
d7 = sorted([r for r in dm if r['problem']=='DTLZ7' and r['M']==20], key=lambda r: r['run_global'])
vals = [r['rel_weighted_ratio'] for r in d7]
print(f"  10 次 weighted 占比: {[round(v,2) for v in vals]}")
print(f"  mean={mean(vals):.3f} std={std(vals):.3f} "
      f"95%CI=[{mean(vals)-1.96*std(vals)/math.sqrt(len(vals)):.3f}, {mean(vals)+1.96*std(vals)/math.sqrt(len(vals)):.3f}]")

print("\n" + "=" * 72)
print(" K. coverage / degeneracy 随代数趋势 (全体均值)")
print("=" * 72)
for name, gens in [('gen1',[1]),('gen2-5',[2,3,4,5]),('gen6-15',list(range(6,16))),('gen16+',list(range(16,40)))]:
    cov = [r['coverage'] for r in dd if r['gen'] in gens]
    deg = [r['degeneracy'] for r in dd if r['gen'] in gens]
    print(f"  {name:8s}: coverage mean={mean(cov):.3f}  degeneracy mean={mean(deg):.3f}")

print("\n分析完成。")
