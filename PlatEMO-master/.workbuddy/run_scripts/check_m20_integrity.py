import os, glob, sys, re
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$")

targets = {
    "noCDIS_M20_DTLZ7": (os.path.join(TEST, "20目标", "REMO_noBatchDict_noCDIS"), "DTLZ7", 20),
    "noPAQC_M20_DTLZ7": (os.path.join(TEST, "20目标", "REMO_noBatchDict_noPAQC"), "DTLZ7", 20),
    "noCDIS_M20_all":   (os.path.join(TEST, "20目标", "REMO_noBatchDict_noCDIS"), None, 20),
    "noPAQC_M20_all":   (os.path.join(TEST, "20目标", "REMO_noBatchDict_noPAQC"), None, 20),
}
for tag, (d, prob, M) in targets.items():
    print("=" * 90)
    print(tag)
    if prob:
        fs = glob.glob(os.path.join(d, "*_%s_M%d_D*_*.mat" % (prob, M)))
    else:
        fs = glob.glob(os.path.join(d, "*.mat"))
    bad = []
    n_ok = 0
    igdp = 0
    for f in sorted(fs):
        b = os.path.basename(f)
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            r = S["result"]
            mt = S["metric"][0, 0]
            fn = set(getattr(mt, "_fieldnames", []))
            n = r.shape[0]
            fe = int(np.asarray(r[n - 1, 0]).ravel()[0])
            if n != 30 or fe != 300 or "IGD" not in fn or "runtime" not in fn:
                bad.append("%s : snaps=%d FE=%d fields=%s" % (b, n, fe, sorted(fn)))
            elif "IGDp" in fn:
                igdp += 1
            else:
                n_ok += 1
        except Exception as e:
            bad.append("%s : LOADERR %s" % (b, e))
    print("  files=%d  intact-without-IGDp=%d  with-IGDp=%d  broken=%d" % (len(fs), n_ok, igdp, len(bad)))
    for x in bad[:10]:
        print("    ", x)
