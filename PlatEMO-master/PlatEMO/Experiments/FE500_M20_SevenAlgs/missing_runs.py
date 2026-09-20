# Print "<problemIndex>|<run,run,...>" for every chunk of still-missing runs of
# ONE algorithm of the FE500 20-objective seven-algorithm sweep, so the driver
# can relaunch only the gaps at a good load balance.
#
#   FE500_ALG    registry key (REMO | PCSAEA | CSEA | HES_EA | SSDE | SAMOEA | PACDIS)
#   FE500_RUNS   run set to complete, e.g. "1-20" (default) or "19,20"
#   FE500_CHUNK  runs per slice, default 10
#   FE500_M20_OUTPUT_ROOT  output root, default D:\REMOandDREMO测试集\20目标\FE500
#
# Problem order is the paper's 16-problem list: 1..7 = DTLZ1..7, 8..16 = WFG1..9.
# WFG2/WFG3 land on D=31, every other problem on D=30, so the D field is probed
# with a wildcard instead of being hard-coded.
#
# A chunk is never emitted with exactly ONE run: a one-element vector is treated
# as a scalar by the shared harness and silently expanded to 1:<run>, so a
# lone tail run is paired with an already-stored neighbour (which the harness
# then skips). Chunk sizes are balanced (11 missing runs -> 6+5, not 10+1).
import os
import sys

DEFAULT_ROOT = r"D:\REMOandDREMO测试集\20目标\FE500"
FOLDERS = {
    "REMO":   "REMO",
    "PCSAEA": "PCSAEA",
    "CSEA":   "CSEA",
    "HES_EA": "HES_EA",
    "SSDE":   "SSDE",
    "SAMOEA": "SAMOEATL2M",
    "PACDIS": "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
}
PROBS = ["DTLZ1", "DTLZ2", "DTLZ3", "DTLZ4", "DTLZ5", "DTLZ6", "DTLZ7",
         "WFG1", "WFG2", "WFG3", "WFG4", "WFG5", "WFG6", "WFG7", "WFG8", "WFG9"]


def parse_runs(spec):
    spec = (spec or "1-20").strip()
    out = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            out.extend(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return sorted(set(out))


def balanced_chunks(items, chunk):
    """Split into <=chunk-sized pieces, never leaving a head of size 1."""
    if not items:
        return []
    if len(items) == 1:
        return [items]
    n = len(items)
    size = -(-n // -(-n // chunk))          # ceil(n / ceil(n/chunk))
    return [items[i:i + size] for i in range(0, n, size)]


def main():
    key = os.environ.get("FE500_ALG", "REMO").strip().upper()
    if key not in FOLDERS:
        sys.stderr.write("unknown FE500_ALG=%r; known: %s\n" % (key, ", ".join(FOLDERS)))
        return 2
    root = os.environ.get("FE500_M20_OUTPUT_ROOT", DEFAULT_ROOT)
    outdir = os.path.join(root, FOLDERS[key])
    runs = parse_runs(os.environ.get("FE500_RUNS", "1-20"))
    chunk = int(os.environ.get("FE500_CHUNK", "10"))
    lo, hi = runs[0], runs[-1]

    for index, problem in enumerate(PROBS, 1):
        missing = []
        for run in runs:
            found = any(os.path.isfile(os.path.join(
                outdir, "%s_%s_M20_D%d_%d.mat" % (key, problem, d, run)))
                for d in (30, 31))
            if not found:
                missing.append(run)
        if not missing:
            continue
        for piece in balanced_chunks(missing, chunk):
            if len(piece) == 1:
                lone = piece[0]
                mate = lone + 1 if lone < hi else lone - 1
                if mate == lone:
                    mate = lone - 1
                if lo <= mate <= hi:
                    piece = sorted({lone, mate})
            print("%d|%s" % (index, ",".join(str(c) for c in piece)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
