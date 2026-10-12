import scipy.io as sio, os, glob, sys, collections

ROOT = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
DIRS = {
    10: os.path.join(ROOT, "10目标", "n30", "REMO_NoCDIS_REMOSelection"),
    20: os.path.join(ROOT, "20目标", "REMO_NoCDIS_REMOSelection"),
}
PROBS = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]

grand = dict(files=0, bad=0, noIGD=0, noIGDp=0, badsnap=0, badfe=0)
for M, d in DIRS.items():
    files = sorted(glob.glob(os.path.join(d, "*.mat")))
    bad = noIGD = noIGDp = badsnap = badfe = 0
    per = collections.Counter()
    missing = []
    for f in files:
        per[os.path.basename(f).split("_")[3]] += 1
        try:
            S = sio.loadmat(f, squeeze_me=True, struct_as_record=False)
            r, m = S["result"], S["metric"]
            igd = getattr(m, "IGD", None)
            igdp = getattr(m, "IGDp", None)
            n = r.shape[0]
            if igd is None or len(igd) == 0: noIGD += 1
            if igdp is None or len(igdp) == 0: noIGDp += 1
            else:
                if len(igdp) != n: badsnap += 1
                elif abs(float(igdp[-1]) - float(igdp[-1])) != 0: bad += 1   # NaN guard
            fe = float(r[-1][0])
            if abs(fe - 300) > 1e-9: badfe += 1
        except Exception as e:
            bad += 1
            missing.append((os.path.basename(f), str(e)[:60]))
    # expected grid
    exp = {p: 20 for p in PROBS}
    absent = [p for p in PROBS if per.get(p, 0) != 20]
    print("M=%d  dir files=%d  bad=%d  noIGD=%d  noIGDp=%d  badsnap=%d  badFE=%d" %
          (M, len(files), bad, noIGD, noIGDp, badsnap, badfe))
    print("   per-problem (should all be 20):", {p: per.get(p, 0) for p in PROBS})
    if absent:
        print("   !! problem counts off:", absent)
    if missing:
        print("   !! load errors:", missing[:5])
    grand["files"] += len(files); grand["bad"] += bad; grand["noIGD"] += noIGD
    grand["noIGDp"] += noIGDp; grand["badsnap"] += badsnap; grand["badfe"] += badfe

print("\nTOTAL files=%d  bad=%d  noIGD=%d  noIGDp=%d  badsnap=%d  badFE=%d" % (
    grand["files"], grand["bad"], grand["noIGD"], grand["noIGDp"], grand["badsnap"], grand["badfe"]))
print("VERDICT:", "ALL OK" if (grand["files"] == 640 and sum(
    grand[k] for k in ("bad", "noIGD", "noIGDp", "badsnap", "badfe")) == 0) else "PROBLEM")
