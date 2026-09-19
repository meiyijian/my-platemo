import os, glob, sys, re
import scipy.io as sio
import numpy as np

pat = re.compile(r"^(?P<alg>.+?)_(?P<prob>DTLZ\d+|WFG\d+)_M(?P<M>\d+)_D(?P<D>\d+)_(?P<run>\d+)\.mat$", re.I)

for root in sys.argv[1:]:
    print("=" * 100)
    print("ROOT:", root)
    for f in sorted(glob.glob(os.path.join(root, "**", "*.mat"), recursive=True)):
        m = pat.match(os.path.basename(f))
        tag = "%s %s M%s D%s run%s" % (m.group("alg"), m.group("prob"), m.group("M"), m.group("D"), m.group("run")) if m else os.path.basename(f)
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            r = S["result"]
            fe = [int(np.asarray(r[i, 0]).ravel()[0]) for i in range(r.shape[0])]
            mt = S["metric"][0, 0]
            fields = list(getattr(mt, "_fieldnames", []))
            line = "  %-58s snaps=%-3d FE=%-4d runtime=%-8s fields=%s" % (
                tag, r.shape[0], fe[-1], ("%.1f" % float(np.asarray(mt.runtime).ravel()[0])) if "runtime" in fields else "-",
                ",".join(fields))
            for k in ("IGD", "IGDp"):
                if k in fields:
                    v = np.asarray(getattr(mt, k)).ravel()
                    line += " %s[%d] end=%.6e" % (k, v.size, v[-1])
            print(line)
            if fe != sorted(fe) or fe[-1] != 300:
                print("      !! FE sequence problem:", fe)
        except Exception as e:
            print("  %-58s LOAD ERR %s" % (tag, e))
