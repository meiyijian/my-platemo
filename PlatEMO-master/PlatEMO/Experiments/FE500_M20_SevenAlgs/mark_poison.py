# Mark the poisoned (problem, run) pair of a slice that has just been killed by
# SLICE_TIMEOUT, and append it to the poison file so missing_runs.py stops
# re-driving it.
#
# WHY THIS EXISTS
#   The seed is fixed per (problem, run), so a run that hangs inside the
#   algorithm hangs again on every re-drive. Without this, one stuck run would
#   burn SLICE_TIMEOUT on a pool slot once per round (8 rounds by default) and
#   the sweep would never converge.
#
# WHICH run is the culprit
#   A slice executes its run list in order and each finished run is written
#   atomically, so the FIRST run of the list with no MAT file on disk is exactly
#   the one that got stuck. Everything after it simply never had a chance to
#   run. Only that single first-missing run is poisoned; the tail stays eligible
#   and will be re-driven.
#
# Usage (called by driver.sh, not by hand):
#   python mark_poison.py <KEY> <part> <runs-csv> <poison-file>
import os
import sys

import missing_runs as mr


def main():
    if len(sys.argv) < 5:
        sys.stderr.write("usage: mark_poison.py KEY PART RUNS_CSV POISON_FILE\n")
        return 2
    key = sys.argv[1].strip().upper()
    part = int(sys.argv[2])
    runs = [int(x) for x in sys.argv[3].split(",") if x.strip()]
    poison = sys.argv[4]

    if key not in mr.FOLDERS:
        sys.stderr.write("unknown key %r\n" % key)
        return 2
    cls, folderName, key = mr.resolve(key)
    root = os.environ.get("FE500_M20_OUTPUT_ROOT", mr.DEFAULT_ROOT)
    outdir = os.path.join(root, folderName)
    if not (1 <= part <= len(mr.PROBS)):
        sys.stderr.write("part %d out of range\n" % part)
        return 2
    problem = mr.PROBS[part - 1]

    culprit = None
    for run in runs:
        found = any(os.path.isfile(os.path.join(
            outdir, "%s_%s_M20_D%d_%d.mat" % (cls, problem, d, run)))
            for d in (30, 31))
        if not found:
            culprit = run
            break

    if culprit is None:
        print("[poison] %s part %d: every run of the slice is on disk, nothing to poison"
              % (key, part))
        return 0

    line = "%d|%d" % (part, culprit)
    existing = set()
    if os.path.isfile(poison):
        with open(poison) as fh:
            existing = {ln.strip() for ln in fh if ln.strip()}
    if line in existing:
        print("[poison] %s already poisoned: %s" % (key, line))
        return 0
    with open(poison, "a") as fh:
        fh.write(line + "\n")
    print("[poison] %s %s run %d KILLED by SLICE_TIMEOUT twice -> poisoned, will be skipped"
          % (key, problem, culprit))
    return 0


if __name__ == "__main__":
    sys.exit(main())
