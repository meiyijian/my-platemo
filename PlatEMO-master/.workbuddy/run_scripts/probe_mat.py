import sys, os, glob, re
import scipy.io as sio
import numpy as np

paths = sys.argv[1:]
for p in paths:
    print("=" * 90)
    print("FILE:", p)
    if not os.path.isfile(p):
        print("  MISSING")
        continue
    print("  size = %.2f MB" % (os.path.getsize(p) / 1048576))
    try:
        S = sio.loadmat(p, squeeze_me=False, struct_as_record=False)
    except Exception as e:
        print("  loadmat failed:", e)
        continue
    keys = [k for k in S.keys() if not k.startswith("__")]
    print("  keys:", keys)
    for k in keys:
        v = S[k]
        try:
            print("   %s: shape=%s dtype=%s" % (k, getattr(v, "shape", None), getattr(v, "dtype", None)))
        except Exception:
            pass
    if "metric" in S:
        m = S["metric"]
        try:
            m = m[0, 0]
            for f in m._fieldnames:
                val = getattr(m, f)
                arr = np.asarray(val).ravel()
                if f == "runtime":
                    print("   metric.runtime = %s" % arr)
                else:
                    print("   metric.%s len=%d first=%s last=%s" % (f, arr.size, arr[:2], arr[-2:]))
        except Exception as e:
            print("   metric parse failed:", e)
    if "result" in S:
        r = S["result"]
        try:
            print("   result shape = %s ; FE col = %s" % (r.shape, np.asarray(r[:, 0]).ravel()))
        except Exception as e:
            print("   result parse failed:", e)
