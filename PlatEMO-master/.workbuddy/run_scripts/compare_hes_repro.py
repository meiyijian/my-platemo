import os
import scipy.io as sio
import numpy as np

NEW = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\_smoke_hes\HES_EA_N100"
OLD = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\HES_EA_N100"
fn = "HES_EA_N100_DTLZ1_M20_D30_1.mat"

A = sio.loadmat(os.path.join(NEW, fn), struct_as_record=False, squeeze_me=False)
B = sio.loadmat(os.path.join(OLD, fn), struct_as_record=False, squeeze_me=False)
ma, mb = A["metric"][0, 0], B["metric"][0, 0]
print("stored run1 : runtime=%.1f  IGD(end)=%.8f" % (
    float(np.asarray(mb.runtime).ravel()[0]), float(np.asarray(mb.IGD).ravel()[-1])))
print("my run1     : runtime=%.1f  IGD(end)=%.8f" % (
    float(np.asarray(ma.runtime).ravel()[0]), float(np.asarray(ma.IGD).ravel()[-1])))
va = np.asarray(ma.IGD).ravel()
vb = np.asarray(mb.IGD).ravel()
print("IGD traces identical:", np.array_equal(va, vb))
if not np.array_equal(va, vb):
    print("  maxAbsDiff=%.6e  maxRelDiff=%.3e" % (
        np.max(np.abs(va - vb)), np.max(np.abs(va - vb) / np.maximum(np.abs(vb), 1e-30))))
print("  new[:3]=%s" % va[:3])
print("  old[:3]=%s" % vb[:3])
print("  new fields:", sorted(getattr(ma, "_fieldnames", [])))
