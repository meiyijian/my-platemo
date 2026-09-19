import os, glob, collections
import scipy.io as sio

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
targets = [
    (r"10目标\n30\REMO_k15", "REMO_k15_", 10),
    (r"20目标\REMO_k", "REMO_k_", 20),
    (r"20目标\REMO", "REMO_", 20),
    (r"10目标\n30\REMO", "REMO_", 10),
    (r"10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_", 10),
    (r"20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_", 20),
]
for rel, prefix, M in targets:
    d = os.path.join(TEST, rel)
    probs = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
    print("=" * 90)
    print("DIR:", d)
    nfiles = len(glob.glob(os.path.join(d, "*.mat")))
    print("  total mat files:", nfiles)
    for p in probs:
        fs = sorted(glob.glob(os.path.join(d, "%s%s_M%d_D*_*.mat" % (prefix, p, M))))
        have = {"IGD": 0, "IGDp": 0, "other": 0}
        n = 0
        for f in fs:
            try:
                S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
                mt = S["metric"][0, 0]
                fn = set(getattr(mt, "_fieldnames", []))
                n += 1
                if "IGD" in fn:
                    have["IGD"] += 1
                if "IGDp" in fn:
                    have["IGDp"] += 1
                if "IGD" not in fn and "IGDp" not in fn:
                    have["other"] += 1
            except Exception as e:
                print("   err", os.path.basename(f), e)
        print("   %-6s files=%-3d IGD=%-3d IGDp=%-3d none=%-3d" % (p, n, have["IGD"], have["IGDp"], have["other"]))
