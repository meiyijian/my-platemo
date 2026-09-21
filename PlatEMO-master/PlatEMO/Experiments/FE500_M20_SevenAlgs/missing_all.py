# Print "<KEY>|<problemIndex>|<run,run,...>" for every still-missing slice across
# ALL algorithms, in FE500_ALGS order, so the driver can feed ONE global pool of
# workers instead of running the algorithms one after another.
#
# Why: with a per-algorithm loop, the tail of one algorithm drains the pool to
# 1-2 busy cores before the next algorithm starts (a "fragmented tail" wastes
# tens of minutes per algorithm). A global queue lets the driver hand a freed
# slot straight to the next algorithm's work, so the pool stays full as long as
# ANY work is left anywhere.
#
# Reuses every rule from missing_runs.py (class-based file names, balanced
# chunks, split-when-starved, per-algorithm poison). The only new thing is the
# ordering and the KEY column.
#
#   FE500_ALGS   order (space/comma separated), default the heavy-first order
#   FE500_POISON_DIR  Windows path of the logs/ dir, for per-algorithm poison
import os
import sys

import missing_runs as mr

DEFAULT_ORDER = "REMO PACDIS HES_EA CSEA PCSAEA SAMOEA SSDE"


def main():
    order = (os.environ.get("FE500_ALGS", DEFAULT_ORDER)
             .replace(",", " ").split())
    seen = set()
    n = 0
    for key in order:
        key = key.strip().upper()
        if not key or key in seen:
            continue
        seen.add(key)
        if key not in mr.FOLDERS:
            sys.stderr.write("!! unknown algorithm key %r (skipped)\n" % key)
            continue
        work = mr.collect_slices(key)
        if work is None:
            continue
        for part, piece in work:
            print("%s|%d|%s" % (key, part, ",".join(str(c) for c in piece)))
            n += 1
    if n == 0:
        sys.stderr.write("[missing_all] no missing slices across %s\n"
                         % ", ".join(seen))
    return 0


if __name__ == "__main__":
    sys.exit(main())
