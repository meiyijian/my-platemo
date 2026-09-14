import csv, statistics, os
from collections import defaultdict

base = r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_GoodGroupPrecision\results\analysis\formal\expansion_audit_20260906"
path = os.path.join(base, "cell_summary.csv")

rows = []
with open(path, encoding="utf-8-sig", newline="") as f:
    for r in csv.DictReader(f):
        if r["Truth"] == "population_final" and r["View"] == "score_hybrid":
            rows.append(r)

agg = defaultdict(list)
for r in rows:
    agg[(r["Problem"], int(r["M"]))].append(r)

out = []
for (prob, M), rs in agg.items():
    P = [float(x["MeanPrecision"]) for x in rs]
    C = [float(x["MeanChance"]) for x in rs]
    A = [float(x["MeanAUC"]) for x in rs if x["MeanAUC"] not in ("", "nan")]
    exc = round(sum(p - c for p, c in zip(P, C)) / len(P) * 100, 2)
    out.append({
        "prob": prob, "M": M, "n": len(rs),
        "P": round(sum(P) / len(P) * 100, 2),
        "C": round(sum(C) / len(C) * 100, 2),
        "excess": exc,
        "frac": round((sum(p - c for p, c in zip(P, C)) /
                       sum(min(1.0, c * 100 / 25) - c for c in C)), 3) if True else None,
        "AUC": round(sum(A) / len(A), 3) if A else None,
        "batch": rs[0]["Batch"],
    })

out.sort(key=lambda d: -d["excess"])
print(f"{'Problem':8} {'M':>3} {'batch':6} {'P%':>7} {'Chance%':>8} {'excess':>7} {'AUC':>6}")
for d in out:
    print(f"{d['prob']:8} {d['M']:>3} {d['batch']:6} {d['P']:>7} {d['C']:>8} {d['excess']:>+7} {d['AUC']:>6}")

print()
print("--- 按问题聚合 (M10 与 M20 各 stage 等权) ---")
byp = defaultdict(list)
for d in out:
    byp[d["prob"]].append(d)
for prob, ds in sorted(byp.items(), key=lambda kv: -max(d["excess"] for d in kv[1])):
    m10 = next((d for d in ds if d["M"] == 10), None)
    m20 = next((d for d in ds if d["M"] == 20), None)
    print(f"{prob:8} M10 excess={m10['excess']:>+6} (P={m10['P']:>6} C={m10['C']:>6} AUC={m10['AUC']})  "
          f"M20 excess={m20['excess']:>+6} (P={m20['P']:>6} C={m20['C']:>6} AUC={m20['AUC']})")
