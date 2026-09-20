import os, re, glob, statistics, time, datetime, json, sys
import scipy.io as sio
import numpy as np

TEST = r"C:\Users\lsx\Desktop\REMOandDREMO测试集"
REF = "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
PROBLEMS = ["DTLZ%d" % i for i in range(1, 8)] + ["WFG%d" % i for i in range(1, 10)]
RUNS = 20
# optional filter: "progress_nbd.py 10" reports the 10-objective block only
ONLY_M = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
ARMS = {
    ("noCDIS", 10): os.path.join(TEST, "10目标", "n30", "REMO_noBatchDict_noCDIS"),
    ("noCDIS", 20): os.path.join(TEST, "20目标", "REMO_noBatchDict_noCDIS"),
    ("noPAQC", 10): os.path.join(TEST, "10目标", "n30", "REMO_noBatchDict_noPAQC"),
    ("noPAQC", 20): os.path.join(TEST, "20目标", "REMO_noBatchDict_noPAQC"),
}
if ONLY_M:
    ARMS = {k: v for k, v in ARMS.items() if k[1] in ONLY_M}
pat = re.compile(r"_(DTLZ\d+|WFG\d+)_M(\d+)_D(\d+)_(\d+)\.mat$", re.I)

# expected per-run cost: the recorded mean of the full arm, scaled by the
# measured ratio of the deletion arms (idle smoke: 284.3 / 282.6 vs 263.3)
SCALE = 1.07
expected = {}
for M in (10, 20):
    d = os.path.join(TEST, "10目标", "n30", REF) if M == 10 else os.path.join(TEST, "20目标", REF)
    for p in PROBLEMS:
        v = []
        for f in glob.glob(os.path.join(d, "*_%s_M%d_D*_*.mat" % (p, M))):
            m = pat.search(os.path.basename(f))
            if m and int(m.group(2)) == M:
                try:
                    S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
                    v.append(float(np.asarray(S["metric"][0, 0].runtime).ravel()[0]))
                except Exception:
                    pass
        expected[(M, p)] = (statistics.mean(v) if v else 0.0) * SCALE

total_jobs = 0
done_jobs = 0
done_time = 0.0
total_time = 0.0
rows = []
for (arm, M), d in ARMS.items():
    n = 0
    t = 0.0
    for f in glob.glob(os.path.join(d, "*.mat")):
        m = pat.search(os.path.basename(f))
        if not m:
            continue
        p = m.group(1).upper()
        if int(m.group(2)) != M:
            continue
        n += 1
        try:
            S = sio.loadmat(f, struct_as_record=False, squeeze_me=False)
            mt = S["metric"][0, 0]
            t += float(np.asarray(mt.runtime).ravel()[0])
            exp = expected[(M, p)]
            done_time += exp
        except Exception:
            exp = 0.0
    exp_all = sum(expected[(M, p)] for p in PROBLEMS) * RUNS
    total_jobs += 16 * RUNS
    done_jobs += n
    total_time += exp_all
    rows.append((arm, M, n, 16 * RUNS, t / 3600.0, exp_all / 3600.0))

print("now = %s" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
for arm, M, n, tot, th, eh in rows:
    print("  %-7s M=%-3d %4d/%-4d (%.1f%%)   recorded %.2f h / expected %.2f h" %
          (arm, M, n, tot, 100.0 * n / tot, th, eh))
frac = done_time / total_time if total_time else 0.0
print("  work-weighted progress = %.2f%%  (%d/%d jobs)  [Ms=%s]" % (
    100 * frac, done_jobs, total_jobs, sorted(ONLY_M) if ONLY_M else "10,20"))
if frac > 0.02:
    try:
        first = min(os.path.getmtime(f) for f in glob.glob(os.path.join(ARMS[("noCDIS", 10)], "*.mat"))
                    if ONLY_M is None or 10 in ONLY_M)
    except (ValueError, KeyError):
        first = time.time()
    elapsed_h = (time.time() - first) / 3600.0
    remain_h = elapsed_h / frac - elapsed_h
    print("  elapsed since first result ~ %.2f h ; eta_remaining ~ %.1f h ; finish ~ %s" % (
        elapsed_h, remain_h,
        (datetime.datetime.now() + datetime.timedelta(hours=remain_h)).strftime("%Y-%m-%d %H:%M")))
