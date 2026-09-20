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
    # Alias: the CLASS name is SAMOEATL2M while the registry key is SAMOEA. Both
    # are accepted so that a key typed as the class name cannot silently run to
    # nothing (it already cost one full pass once -- see driver.sh).
    "SAMOEATL2M": "SAMOEATL2M",
    "PACDIS": "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
}

# MAT files are named after the CLASS, not after the key. For six of the seven
# algorithms the two are identical; SAMOEA is the exception (key SAMOEA, class
# SAMOEATL2M). Building the filename from the key would make every file look
# missing and re-launch a fully stored algorithm, so the class is kept here
# explicitly. Keep in sync with fe500_m20_registry.m.
CLASSES = {
    "REMO":   "REMO",
    "PCSAEA": "PCSAEA",
    "CSEA":   "CSEA",
    "HES_EA": "HES_EA",
    "SSDE":   "SSDE",
    "SAMOEA": "SAMOEATL2M",
    "SAMOEATL2M": "SAMOEATL2M",
    "PACDIS": "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist",
}


def resolve(key):
    """(class name used in file names, folder used for output, class-name list)"""
    key = (key or "").strip().upper()
    if key not in FOLDERS:
        return None
    cls = CLASSES[key]
    folder = os.environ.get("FE500_FOLDER") or FOLDERS[key]
    return cls, folder, key
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


def split_starved(work, target, minchunk):
    """Subdivide the biggest pieces until there are >= TARGET pieces.

    WORK is a list of (problemIndex, [run, ...]). Returns the same shape.

    Why: a slice list shorter than the worker pool leaves cores idle for no
    reason. With 74 runs left and 16 workers, 8 slices of ~9 runs keep only 8
    cores busy, while 15 slices of ~5 runs keep 15 busy -- identical total work,
    roughly half the wall clock. The problem index travels with each piece, so
    the seed of every run is untouched by the split.

    Stops when no piece can be halved while keeping both halves >= MINCHUNK:
    very short slices are the configuration that makes MATLAB -batch crash on
    this machine, so MINCHUNK is a floor, not a suggestion.
    """
    out = [(i, list(p)) for i, p in work]
    while len(out) < target:
        cand = None
        for k, (_, p) in enumerate(out):
            if len(p) >= 2 * minchunk and (cand is None or len(p) > len(out[cand][1])):
                cand = k
        if cand is None:
            break
        i, p = out.pop(cand)
        half = len(p) // 2
        out.append((i, p[:half]))
        out.append((i, p[half:]))
    return out


def read_poison(path):
    """<part>|<run> pairs that must never be re-driven (they hang; see mark_poison.py)."""
    out = set()
    if path and os.path.isfile(path):
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if not line or "|" not in line:
                    continue
                a, b = line.split("|", 1)
                try:
                    out.add((int(a), int(b)))
                except ValueError:
                    continue
    return out


def main():
    key = os.environ.get("FE500_ALG", "REMO").strip().upper()
    if key not in FOLDERS:
        sys.stderr.write("unknown FE500_ALG=%r; known: %s\n" % (key, ", ".join(FOLDERS)))
        return 2
    cls, folderName, key = resolve(key)
    root = os.environ.get("FE500_M20_OUTPUT_ROOT", DEFAULT_ROOT)
    outdir = os.path.join(root, folderName)
    runs = parse_runs(os.environ.get("FE500_RUNS", "1-20"))
    chunk = int(os.environ.get("FE500_CHUNK", "10"))
    poison = read_poison(os.environ.get("FE500_POISON", ""))
    # Worker pool size and the shortest slice we are willing to create. Used only
    # to subdivide when the remaining work is smaller than the pool (see
    # split_starved); over-splitting is harmless, an idle core is not.
    maxjobs = int(os.environ.get("FE500_MAXJOBS", "16"))
    minchunk = int(os.environ.get("FE500_MINCHUNK", "3"))
    # Problem indices (1..16, DTLZ1..DTLZ7 then WFG1..WFG9) to leave untouched for
    # now. Used to run the BULK first and defer the slow tail: DTLZ7 (index 7) is
    # the long pole of every algorithm because its IGDp reference set has 2^19
    # points, so FE500_SKIP_PARTS=7 defers all of DTLZ7 to a later pass.
    skipparts = {int(x) for x in os.environ.get("FE500_SKIP_PARTS", "").split(",")
                 if x.strip()}
    lo, hi = runs[0], runs[-1]

    nSkipped = 0
    work = []                                   # [(problemIndex, [run, ...]), ...]
    for index, problem in enumerate(PROBS, 1):
        if index in skipparts:
            continue
        missing = []
        for run in runs:
            if (index, run) in poison:
                nSkipped += 1
                continue
            found = any(os.path.isfile(os.path.join(
                outdir, "%s_%s_M20_D%d_%d.mat" % (cls, problem, d, run)))
                for d in (30, 31))
            if not found:
                missing.append(run)
        if not missing:
            continue
        for piece in balanced_chunks(missing, chunk):
            if len(piece) == 1:
                # A one-element run list is read as a SCALAR by the shared harness
                # and silently expanded to 1:<run>; pair the lone run with an
                # already-stored neighbour instead (the harness then skips it).
                lone = piece[0]
                mate = lone + 1 if lone < hi else lone - 1
                if lo <= mate <= hi and (index, mate) not in poison:
                    piece = sorted({lone, mate})
            work.append((index, piece))

    if len(work) < maxjobs:
        work = split_starved(work, maxjobs, minchunk)

    for index, piece in work:
        print("%d|%s" % (index, ",".join(str(c) for c in piece)))
    if nSkipped:
        sys.stderr.write("[missing_runs] %s: %d (problem,run) poisoned and skipped\n"
                         % (key, nSkipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
