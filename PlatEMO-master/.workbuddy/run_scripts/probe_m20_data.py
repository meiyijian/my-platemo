import os, glob, re, collections, statistics
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
DIRS = {
    "REMO_noBatchDict_noCDIS": os.path.join(TEST, "20目标", "REMO_noBatchDict_noCDIS"),
    "REMO_noBatchDict_noPAQC": os.path.join(TEST, "20目标", "REMO_noBatchDict_noPAQC"),
}
REF_M20 = os.path.join(TEST, "20目标", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist")
REF_M10 = os.path.join(TEST, "10目标", "n30", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist")
NEW_M10 = {
    "REMO_noBatchDict_noCDIS": os.path.join(TEST, "10目标", "n30", "REMO_noBatchDict_noCDIS"),
    "REMO_noBatchDict_noPAQC": os.path.join(TEST, "10目标", "n30", "REMO_noBatchDict_noPAQC"),
}
pat = re.compile(r"^(?P<alg>.+?)_(?P<prob>DTLZ\d+|WFG\d+)_M(?P<M>\d+)_D(?P<D>\d+)_(?P<run>\d+)\.mat$", re.I)

for tag, d in DIRS.items():
    print("=" * 100)
    print(tag, "->", d)
    files = sorted(glob.glob(os.path.join(d, "*.mat")))
    print("  files:", len(files))
    print("  first 3 names:", [os.path.basename(f) for f in files[:3]])
    shapes = collections.Counter()
    ms = collections.Counter()
    ds = collections.Counter()
    fe_end = collections.Counter()
    snaps = collections.Counter()
    fields = collections.Counter()
    sizes = []
    for f in files:
        m = pat.match(os.path.basename(f))
        if not m:
            print("   UNPARSED:", os.path.basename(f)); continue
        ms[m.group("M")] += 1
        ds[m.group("D")] += 1
        sizes.append(os.path.getsize(f))
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
        except Exception as e:
            print("   LOADERR", os.path.basename(f), e); continue
        r = S["result"]
        snaps[r.shape[0]] += 1
        fe_end[int(np.asarray(r[r.shape[0] - 1, 0]).ravel()[0])] += 1
        mt = S["metric"][0, 0]
        fn = tuple(sorted(getattr(mt, "_fieldnames", [])))
        fields[",".join(fn)] += 1
        # objective count of the stored population
        try:
            P = r[0, 1]
            objs = None
            for attr in ("objs",):
                if hasattr(P, attr):
                    objs = np.asarray(getattr(P, attr))
            shapes[objs.shape if objs is not None else "?"] += 1
        except Exception:
            pass
    print("  filename M:", dict(ms), " D:", dict(ds))
    print("  snapshots:", dict(snaps), " final FE:", dict(fe_end))
    print("  metric fields:", dict(fields))
    print("  file size: min=%d max=%d mean=%.0f" % (min(sizes), max(sizes), statistics.mean(sizes)))
    top = shapes.most_common(4)
    print("  snapshot1 objs shape (top4):", top)

    # compare with the M=10 sibling: identical content?
    d10 = NEW_M10[tag]
    same = 0
    diffname = 0
    checked = 0
    for f in files[:60]:
        b = os.path.basename(f)
        f10 = os.path.join(d10, b)
        if not os.path.isfile(f10):
            diffname += 1
            continue
        checked += 1
        if os.path.getsize(f) == os.path.getsize(f10):
            A = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            B = sio.loadmat(f10, struct_as_record=False, squeeze_me=False)
            if np.array_equal(np.asarray(A["metric"][0, 0].IGDp).ravel(),
                              np.asarray(B["metric"][0, 0].IGDp).ravel()):
                same += 1
    print("  vs 10目标同名文件: 有同名=%d, IGDp逐位相同=%d" % (checked, same))
