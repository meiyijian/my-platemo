import os, sys
import scipy.io as sio
import numpy as np

NEW = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\_smoke\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
OLD = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
fn = "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_WFG9_M10_D30_1.mat"

A = sio.loadmat(os.path.join(NEW, fn), struct_as_record=False, squeeze_me=False)
B = sio.loadmat(os.path.join(OLD, fn), struct_as_record=False, squeeze_me=False)
ma, mb = A["metric"][0, 0], B["metric"][0, 0]
for k in ("runtime", "IGD", "IGDp"):
    va = np.asarray(getattr(ma, k)).ravel()
    vb = np.asarray(getattr(mb, k)).ravel()
    n = min(va.size, vb.size)
    same = np.array_equal(va, vb)
    print("%-8s new[%d] old[%d] identical=%s" % (k, va.size, vb.size, same))
    if not same:
        d = np.max(np.abs(va[:n] - vb[:n]))
        rd = np.max(np.abs(va[:n] - vb[:n]) / np.maximum(np.abs(vb[:n]), 1e-30))
        print("         maxAbsDiff=%.6e maxRelDiff=%.6e" % (d, rd))
        print("         new[:4]=%s" % va[:4])
        print("         old[:4]=%s" % vb[:4])
        print("         new[-2:]=%s  old[-2:]=%s" % (va[-2:], vb[-2:]))

ra = np.asarray(A["result"][:, 1]).ravel()
rb = np.asarray(B["result"][:, 1]).ravel()
print("result cols:", A["result"].shape, B["result"].shape)
