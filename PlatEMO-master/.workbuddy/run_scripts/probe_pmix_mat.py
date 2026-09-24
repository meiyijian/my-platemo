import sys, glob, os, numpy as np
from scipy.io import loadmat

p = sys.argv[1]
d = loadmat(p, squeeze_me=True, struct_as_record=False)
def walk(obj, prefix, depth=0):
    if depth > 3:
        return
    if hasattr(obj, '_fieldnames'):
        for f in obj._fieldnames:
            walk(getattr(obj, f), prefix + '.' + f, depth + 1)
    elif isinstance(obj, np.ndarray):
        print(f"{prefix}: ndarray shape={obj.shape} dtype={obj.dtype}")
    else:
        s = repr(obj)
        print(f"{prefix}: {type(obj).__name__} = {s[:200]}")

for k in d:
    if k.startswith('__'):
        continue
    print("== ", k)
    walk(d[k], k)
