import os, glob, re, collections
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
pat = re.compile(r"^(?P<alg>.+?)_(?P<prob>DTLZ\d+|WFG\d+)_M(?P<M>\d+)_D(?P<D>\d+)_(?P<run>\d+)\.mat$")

for tag, d in [
    ("HES_EA_N100  M10", os.path.join(TEST, "10目标", "n30", "HES_EA_N100")),
    ("HES_EA_N100  M20", os.path.join(TEST, "20目标", "HES_EA_N100")),
    ("HES_EA       M20", os.path.join(TEST, "20目标", "HES_EA")),
]:
    print("=" * 96)
    print(tag, "->", d, "exists=", os.path.isdir(d))
    if not os.path.isdir(d):
        continue
    fs = sorted(glob.glob(os.path.join(d, "*.mat")))
    per = collections.defaultdict(list)
    fields = collections.Counter()
    for f in fs:
        m = pat.match(os.path.basename(f))
        if not m:
            print("  UNPARSED", os.path.basename(f)); continue
        per[m.group("prob")].append((int(m.group("run")), int(m.group("D")), int(m.group("M")), f))
    order = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
    for p in order:
        if p not in per:
            continue
        ds = sorted({x[1] for x in per[p]})
        ms = sorted({x[2] for x in per[p]})
        runs = sorted(x[0] for x in per[p])
        print("  %-6s n=%-3d runs=%s D=%s M=%s" % (p, len(per[p]),
              ("%d..%d" % (runs[0], runs[-1])) if runs else "-", ds, ms))
    print("  files=%d" % len(fs))
    # metric fields + magnitudes on a sample
    shown = 0
    for p in order:
        if p not in per or shown >= 4:
            continue
        f = per[p][0][3]
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            fn = sorted(getattr(mt, "_fieldnames", []))
            rt = float(np.asarray(mt.runtime).ravel()[0])
            igd = np.asarray(mt.IGD).ravel() if hasattr(mt, "IGD") else []
            has_p = hasattr(mt, "IGDp")
            igdp = np.asarray(mt.IGDp).ravel() if has_p else []
            print("   sample %-6s fields=%s runtime=%.1f IGD(end)=%.4e%s" % (
                p, fn, rt, igd[-1] if igd.size else float("nan"),
                " IGDp(end)=%.4e" % igdp[-1] if has_p and igdp.size else " (no IGDp)"))
            shown += 1
        except Exception as e:
            print("   sample ERR", os.path.basename(f), e)
