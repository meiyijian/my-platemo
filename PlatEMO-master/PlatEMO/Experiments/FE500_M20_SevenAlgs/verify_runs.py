# Integrity check for the FE500 / M=20 seven-algorithm sweep -- Python port of
# verify_FE500_M20.m.
#
#   python verify_runs.py [nRuns] [--all]
#       nRuns   runs 1..N to require (default 10)
#       --all   check every .mat in each folder instead of runs 1..N
#
# WHY THIS EXISTS: on this machine verify_FE500_M20.m dies with a MATLAB access
# violation (0xc0000005) inside libxml2 / addons_registry_core / libmwflhttpclient
# -- the MATLAB add-on registry's background HTTP thread, i.e. MATLAB's own
# startup machinery, not the check itself. This script does the same checks with
# no MATLAB in the loop, so it cannot be taken down by that.
#
# Per (algorithm, problem, run) it asserts:
#   * the file exists (D probed as 30 or 31, since WFG2/WFG3 report D=31)
#   * payload = result + metric{runtime, IGD, IGDp}
#   * numel(IGD) == numel(IGDp) == numel(result(:,1)) <= 30
#   * every IGD / IGDp sample is finite
#   * the final FE lies in [500, 600]  (batch-evaluating algorithms overshoot)
#
# Exit status 0 when everything passes, 1 otherwise.
import os
import sys
import numpy as np
from scipy.io import loadmat

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("FE500_M20_OUTPUT_ROOT",
                      r"D:\REMOandDREMO测试集\20目标\FE500")
EXPECT_FE = 500
FE_SLACK = 100
ALGS = [
    ("REMO", "REMO", "REMO"),
    ("PCSAEA", "PCSAEA", "PCSAEA"),
    ("CSEA", "CSEA", "CSEA"),
    ("HES_EA", "HES_EA", "HES_EA"),
    ("SSDE", "SSDE", "SSDE"),
    ("SAMOEA", "SAMOEATL2M", "SAMOEATL2M"),
    ("PACDIS", "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
     "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"),
]
PROBS = ["DTLZ1", "DTLZ2", "DTLZ3", "DTLZ4", "DTLZ5", "DTLZ6", "DTLZ7",
         "WFG1", "WFG2", "WFG3", "WFG4", "WFG5", "WFG6", "WFG7", "WFG8", "WFG9"]


def find(folder, cls, prob, run):
    for d in (30, 31):
        f = os.path.join(ROOT, folder, "%s_%s_M20_D%d_%d.mat" % (cls, prob, d, run))
        if os.path.isfile(f):
            return f
    return None


def check(path):
    try:
        S = loadmat(path)
        res = S["result"]
        m = S["metric"][0, 0]
        names = set(m.dtype.names)
        if not {"runtime", "IGD", "IGDp"} <= names:
            return False, "metric fields %s" % sorted(names)
        fe = [np.asarray(v).ravel()[0] for v in res[:, 0]]
        igd = np.asarray(m["IGD"]).ravel()
        igdp = np.asarray(m["IGDp"]).ravel()
        if not (len(igd) == len(igdp) == len(fe)):
            return False, "len IGD=%d IGDp=%d FE=%d" % (len(igd), len(igdp), len(fe))
        if len(fe) > 30:
            return False, "%d snapshots > 30" % len(fe)
        if not (np.all(np.isfinite(igd)) and np.all(np.isfinite(igdp))):
            return False, "non-finite metric"
        if not (EXPECT_FE <= fe[-1] <= EXPECT_FE + FE_SLACK):
            return False, "final FE=%g outside [%d,%d]" % (fe[-1], EXPECT_FE, EXPECT_FE + FE_SLACK)
        return True, ""
    except Exception as e:                                   # noqa: BLE001
        return False, str(e)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    allmode = "--all" in sys.argv
    nruns = int(args[0]) if args else 10

    nOK = nBad = 0
    bad = []
    feLo, feHi = 1e9, -1e9
    for label, folder, cls in ALGS:
        if allmode:
            import glob
            runs = sorted({int(os.path.basename(x).rsplit("_", 1)[1][:-4])
                           for x in glob.glob(os.path.join(ROOT, folder, "*.mat"))})
        else:
            runs = list(range(1, nruns + 1))
        for p in PROBS:
            for r in runs:
                f = find(folder, cls, p, r)
                if f is None:
                    nBad += 1
                    bad.append("%s %s run %d MISSING" % (label, p, r))
                    continue
                ok, why = check(f)
                if ok:
                    nOK += 1
                else:
                    nBad += 1
                    bad.append("%s %s run %d BAD: %s" % (label, p, r, why))
        n_expected = len(PROBS) * len(runs)
        print("%-12s %d files checked over %d problems" % (label, n_expected, len(PROBS)))

    print("\nOK = %d   BAD = %d" % (nOK, nBad))
    for b in bad[:40]:
        print("  !!", b)
    if nBad == 0:
        print("=== ALL %d FILES VALID (result + metric{runtime,IGD,IGDp}, final FE in [%d,%d]) ==="
              % (nOK, EXPECT_FE, EXPECT_FE + FE_SLACK))
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
