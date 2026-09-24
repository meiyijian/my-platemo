import glob, os, numpy as np, re
from scipy.io import loadmat

B = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"

def files(dirpath, prob):
    pat = os.path.join(dirpath, f"*_{prob}_*.mat")
    fs = sorted(glob.glob(pat), key=lambda p: int(re.search(r"_(\d+)\.mat$", p).group(1)))
    return fs

cases = [
    ("20目标", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_PMix000", "DTLZ7", 20),
    ("20目标", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_PMix000", "DTLZ2", 20),
    ("10目标/n30", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_PMix000", "DTLZ7", 10),
    ("20目标", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist", "DTLZ2", 20),
]
for sub, al, prob, M in cases:
    fs = files(os.path.join(B, sub, al), prob)
    print(f"### {sub} | {al} | {prob}  -> {len(fs)} files")
    fin_i, fin_p, npts = [], [], set()
    for p in fs:
        d = loadmat(p, squeeze_me=True, struct_as_record=False)["metric"]
        ig = np.atleast_1d(d.IGD).astype(float)
        ip = np.atleast_1d(d.IGDp).astype(float)
        npts.add(ig.size)
        fin_i.append(ig[-1]); fin_p.append(ip[-1])
    fin_i = np.array(fin_i); fin_p = np.array(fin_p)
    print(f"   npoints={sorted(npts)}  IGD last: mean={fin_i.mean():.4e} std={fin_i.std(ddof=1):.4e} min={fin_i.min():.4e} max={fin_i.max():.4e}")
    print(f"                     IGDp last: mean={fin_p.mean():.4e} std={fin_p.std(ddof=1):.4e} min={fin_p.min():.4e} max={fin_p.max():.4e}")
    d0 = loadmat(fs[0], squeeze_me=True, struct_as_record=False)["metric"]
    print("   file1 IGD full:", np.round(np.atleast_1d(d0.IGD).astype(float), 5))
    print("   file1 IGDp full:", np.round(np.atleast_1d(d0.IGDp).astype(float), 5))
    print()
