import os, glob, re, statistics
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
REF = "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
PROBLEMS = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$", re.I)


def finals(d, M, prob, field="IGDp"):
    out = {}
    for f in glob.glob(os.path.join(d, "*_%s_M%d_D*_*.mat" % (prob, M))):
        m = pat.search(os.path.basename(f))
        if not m or int(m.group(2)) != M:
            continue
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            if hasattr(mt, field):
                out[int(m.group(4))] = float(np.asarray(getattr(mt, field)).ravel()[-1])
        except Exception:
            pass
    return out


def refdir(M):
    return os.path.join(TEST, "10目标", "n30", REF) if M == 10 else os.path.join(TEST, "20目标", REF)


ARMS = [("noCDIS", 10, os.path.join(TEST, "10目标", "n30", "REMO_noBatchDict_noCDIS")),
        ("noCDIS", 20, os.path.join(TEST, "20目标", "REMO_noBatchDict_noCDIS")),
        ("noPAQC", 10, os.path.join(TEST, "10目标", "n30", "REMO_noBatchDict_noPAQC")),
        ("noPAQC", 20, os.path.join(TEST, "20目标", "REMO_noBatchDict_noPAQC"))]

print("per-problem IGDp: arm-so-far vs stored full arm (z = (mean_arm - mean_full)/std_full)")
for arm, M, d in ARMS:
    print("--- %s M=%d" % (arm, M))
    for prob in PROBLEMS:
        a = finals(d, M, prob)
        if len(a) < 3:
            continue
        b = finals(refdir(M), M, prob)
        if len(b) < 3:
            continue
        av = list(a.values())
        bv = list(b.values())
        sd = statistics.stdev(bv)
        z = (statistics.mean(av) - statistics.mean(bv)) / sd if sd else float("nan")
        print("   %-6s n=%-3d arm=%.4f  full=%.4f (sd %.4f)  z=%+.2f" % (
            prob, len(av), statistics.mean(av), statistics.mean(bv), sd, z))
