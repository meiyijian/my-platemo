import os, glob
import scipy.io as sio
import numpy as np

D = r"C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标\HES_EA_N100"
for fn in ["HES_EA_N100_DTLZ1_M20_D30_1.mat", "HES_EA_N100_DTLZ1_M20_D30_18.mat"]:
    f = os.path.join(D, fn)
    S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
    r = S["result"]
    fe = [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])]
    mt = S["metric"][0, 0]
    print(fn)
    print("   snapshots=%d  FE=%s" % (r.shape[0], fe))
    print("   fields=%s runtime=%.1f IGD(first)=%.6f IGD(last)=%.6f" % (
        sorted(getattr(mt, "_fieldnames", [])),
        float(np.asarray(mt.runtime).ravel()[0]),
        float(np.asarray(mt.IGD).ravel()[0]),
        float(np.asarray(mt.IGD).ravel()[-1])))
