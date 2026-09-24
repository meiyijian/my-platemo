import sys, numpy as np
from scipy.io import loadmat

for p in sys.argv[1:]:
    d = loadmat(p, squeeze_me=True, struct_as_record=False)
    m = d['metric']
    r = d['result']
    print("FILE:", p.split('/')[-1])
    print("  result shape", np.shape(r), "dtype", r.dtype)
    try:
        print("  result[0]:", r[0])
        print("  result[1]:", r[1])
    except Exception as e:
        print("  err", e)
    print("  IGD  n=", np.size(m.IGD), "vals:", np.atleast_1d(m.IGD)[:6])
    print("  IGDp n=", np.size(m.IGDp), "vals:", np.atleast_1d(m.IGDp)[:6])
    print("  runtime", m.runtime)
    print()
