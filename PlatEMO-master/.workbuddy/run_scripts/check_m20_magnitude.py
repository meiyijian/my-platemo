import os, glob, re, statistics
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
NEW = {
    "noCDIS_M20": os.path.join(TEST, "20目标", "REMO_noBatchDict_noCDIS"),
    "noPAQC_M20": os.path.join(TEST, "20目标", "REMO_noBatchDict_noPAQC"),
}
REF = {
    "full_M20": os.path.join(TEST, "20目标", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"),
    "full_M20_sibling": os.path.join(TEST, "20目标", "REMO_UniformMix_Pruned_Weighted_Lambdat030"),
}
PROBS = ["DTLZ1", "DTLZ7", "WFG2", "WFG5", "WFG9"]

def load_finals(d, M, prob, field="IGD"):
    out = {}
    for f in glob.glob(os.path.join(d, "*_%s_M%d_D*_*.mat" % (prob, M))):
        m = re.search(r"_M%d_D(\d+)_(\d+)\.mat$" % M, os.path.basename(f))
        if not m:
            continue
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            if hasattr(mt, field):
                out[int(m.group(2))] = float(np.asarray(getattr(mt, field)).ravel()[-1])
        except Exception as e:
            print("  err", os.path.basename(f), e)
    return out

print("### IGD(final) magnitudes, M=20 dirs  vs  stored M=20 full")
for prob in PROBS:
    line = "  %-6s" % prob
    for tag, d in NEW.items():
        v = load_finals(d, 20, prob)
        line += "  %s n=%d mean=%.4f" % (tag, len(v), statistics.mean(v.values()) if v else float("nan"))
    for tag, d in REF.items():
        v = load_finals(d, 20, prob)
        if v:
            line += "  [%s mean=%.4f]" % (tag, statistics.mean(v.values()))
    print(line)

print()
print("### a 10-objective reference row for contrast")
D10 = os.path.join(TEST, "10目标", "n30", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist")
for prob in ["DTLZ1", "WFG5"]:
    v = load_finals(D10, 10, prob)
    print("  %-6s M=10 full mean=%.4f" % (prob, statistics.mean(v.values())))

print()
print("### structural check of one new file")
f = os.path.join(TEST, "20目标", "REMO_noBatchDict_noCDIS",
                 "REMO_noBatchDict_noCDIS_DTLZ1_M20_D30_1.mat")
S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
r = S["result"]
print("  result shape:", r.shape)
P = r[0, 1]
print("  result{1,2} type:", type(P), getattr(P, "shape", None), getattr(P, "dtype", None))
arr = np.asarray(P).ravel()
print("  n elements:", arr.size)
if arr.size:
    o = arr[0]
    print("  element type:", type(o), getattr(o, "_fieldnames", None))
    if hasattr(o, "_fieldnames"):
        for fn in o._fieldnames:
            v = getattr(o, fn)
            try:
                print("    .%-8s shape=%s dtype=%s" % (fn, np.asarray(v).shape, np.asarray(v).dtype))
            except Exception:
                print("    .%-8s %r" % (fn, type(v)))
    objs = np.asarray(getattr(o, "objs"))
    print("  -> objective count of a stored solution:", objs.shape)
print("  metric.runtime:", np.asarray(S["metric"][0, 0].runtime).ravel())
print("  metric.IGD[:3]:", np.asarray(S["metric"][0, 0].IGD).ravel()[:3])
