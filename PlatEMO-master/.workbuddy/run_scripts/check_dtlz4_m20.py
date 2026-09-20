import os, glob
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标"
DIRS = {
    "full": "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
    "noCDIS": "REMO_noBatchDict_noCDIS",
    "noPAQC": "REMO_noBatchDict_noPAQC",
}
for tag, name in DIRS.items():
    d = os.path.join(TEST, name)
    vals, runs = [], []
    for f in sorted(glob.glob(os.path.join(d, "*_DTLZ4_M20_D*_*.mat"))):
        S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
        vals.append(float(np.asarray(S["metric"][0, 0].IGDp).ravel()[-1]))
        runs.append(int(re.findall(r"_(\d+)\.mat$", os.path.basename(f))[0]) if False else 0)
    print("%-8s DTLZ4 M20 n=%d" % (tag, len(vals)))
    print("   values:", " ".join("%.6f" % v for v in sorted(vals)))
    print("   unique:", len(set(round(v, 12) for v in vals)))
