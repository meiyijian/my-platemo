import csv, os, collections

FILES = {
 "GGP_AdaMaO": r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_GoodGroupPrecision\results\analysis\formal\GGP_PairedComparisons.csv",
 "LTGGP_L030": r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision\results\analysis\formal\LTGGP_PairedComparisons.csv",
 "crossArm_L030vsL050": r"D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_GoodGroupPrecision\results\analysis\crossArm\LTGGP_vs_PWGGP_Paired.csv",
}

out = []
for name, path in FILES.items():
    out.append("=" * 70)
    out.append(name)
    out.append("path exists: %s  size: %s" % (os.path.isfile(path), os.path.getsize(path) if os.path.isfile(path) else "-"))
    if not os.path.isfile(path):
        continue
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    out.append("rows: %d" % len(rows))
    out.append("cols: %s" % (list(rows[0].keys()),))
    for col in rows[0].keys():
        vals = sorted({r[col] for r in rows})
        if len(vals) <= 25:
            out.append("  %s (%d) = %s" % (col, len(vals), vals))
        else:
            out.append("  %s (%d unique) e.g. %s" % (col, len(vals), vals[:6]))

open(r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\_ggp_probe.txt", "w", encoding="utf-8").write("\n".join(out))
print("done")
