import sys, numpy as np
from scipy.io import loadmat

for p in sys.argv[1:]:
    d = loadmat(p, squeeze_me=True, struct_as_record=False)
    m = d['metric']
    print("FILE:", p.split('/')[-1])
    for f in m._fieldnames:
        v = getattr(m, f)
        a = np.atleast_1d(v)
        print(f"   {f}: size={a.size} dtype={a.dtype}", np.round(np.ravel(a)[:5].astype(float), 6) if a.dtype.kind in 'fiu' else '')
    print()
