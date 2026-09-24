#!/bin/bash
# Resilient driver for the FE500 / 20-objective / D=30 seven-algorithm sweep.
#
#   M=20, D=30 requested (WFG2/WFG3 -> 31), N=100, maxFE=500, SaveCount=30,
#   seeds 22260912 + 1000*problemIndex + run,
#   16 problems (DTLZ1-7, WFG1-9) x 20 runs = 320 runs PER ALGORITHM.
#   Each MAT stores result + metric{runtime, IGD, IGDp}.
#
#   Algorithms (see fe500_m20_registry.m for why each class was chosen):
#     REMO     PCSAEA   CSEA   HES_EA   SSDE   SAMOEA   PACDIS
#
#   Data: D:\REMOandDREMO测试集\20目标\FE500\<folder>\
#
#   GLOBAL QUEUE design (2026-09-21): the missing slices of ALL algorithms are
#   pooled into ONE queue per attempt, fed into MAXJOBS staggered MATLAB
#   processes. This lets a freed slot pick up the NEXT algorithm's work the
#   moment the current one's tail starts draining -- no more "fragmented tail"
#   where one algorithm's last few slices leave 14 cores idle. Everything is
#   RESUMABLE: valid MAT files are skipped; a crashed or timed-out slice is
#   re-driven on the next attempt, and a run killed by SLICE_TIMEOUT
#   MAX_SLICE_FAILS times is poisoned (deterministic hang, see mark_poison.py).
#
# ---- Environment overrides -------------------------------------------------
#   ALGS      space separated keys, default "REMO PACDIS HES_EA CSEA PCSAEA SAMOEA SSDE"
#   RUNS      run set to complete, default 1-20
#   CHUNK     runs per slice, default 10
#   MAXJOBS   concurrent MATLAB processes, default 16
#   ROUNDS    re-drive passes over the global queue, default 8
#   SKIP_PARTS  comma-separated problem indices to defer (e.g. 7 = DTLZ7)
#   MP        MATLAB executable,   default /d/software/mathlab/bin/matlab.exe
#   PY        python executable,   default <managed venv>
#   FE500_M20_OUTPUT_ROOT  output root override, read by the runner as well
#
# Progress:  logs/driver.log                (one line per slice start/finish)
#            logs/<KEY>/driver.log          (per-algorithm journal, poison notes)
#            logs/<KEY>/p<NN>.log           (per-slice MATLAB log;
#                                            "[done] <prob> run k | IGD a -> b |
#                                             runtime Xs | wall Ys | ok")
# ---------------------------------------------------------------------------

export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"

# Self-locating: works wherever the repo is checked out.
SELFDIR_POSIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELFDIR_WIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W | sed 's|/|\\|g')"

MP=${MP:-/d/software/mathlab/bin/matlab.exe}
PY=${PY:-C:/Users/lsx/.workbuddy/binaries/python/envs/default/Scripts/python.exe}
WORKDIR=${WORKDIR:-$SELFDIR_POSIX}
WORKDIR_ML=${WORKDIR_ML:-$SELFDIR_WIN}
LOGDIR=$WORKDIR/logs
LOGDIR_ML="$WORKDIR_ML\\logs"
MISSING_ALL_PY_ML="$WORKDIR_ML\\missing_all.py"
MARK_POISON_PY_ML="$WORKDIR_ML\\mark_poison.py"
ALGS=${ALGS:-"REMO PACDIS HES_EA CSEA PCSAEA SAMOEA SSDE"}
export FE500_ALGS="$ALGS"
export FE500_RUNS=${RUNS:-1-20}
export FE500_CHUNK=${CHUNK:-10}
export FE500_MAXJOBS=${MAXJOBS:-16}
export FE500_SKIP_PARTS=${SKIP_PARTS:-}
MAXJOBS=${MAXJOBS:-16}
THREADS=${THREADS:-1}
ROUNDS=${ROUNDS:-8}
SKIP_VERIFY=${SKIP_VERIFY:-0}
# Per-slice wall-clock cap in seconds (0 disables). The published HES_EA can hang
# forever on a stranded cluster (see fe500_m20_registry.m); without a cap one
# such process would block a pool slot indefinitely. 4 h covers the slowest
# healthy slice (10 runs of the slowest algorithm, under full pool contention).
SLICE_TIMEOUT=${SLICE_TIMEOUT:-14400}
MAX_SLICE_FAILS=${MAX_SLICE_FAILS:-2}
# Launch pacing: this box dies with ntdll heap corruption when many MATLAB
# processes COLD-start at the same moment, so the first COLD_STARTS launches of a
# run pay LAUNCH_GAP, everything after that only LAUNCH_GAP_WARM.
LAUNCH_GAP=${LAUNCH_GAP:-20}
COLD_STARTS=${COLD_STARTS:-4}
LAUNCH_GAP_WARM=${LAUNCH_GAP_WARM:-5}
# Optional memory gate, DISABLED by default (MIN_FREE_MB=0). 14-16 workers leave
# only a few GB for the memory-hungry algorithms; set a positive floor to make the
# driver hold launches until free memory recovers.
MIN_FREE_MB=${MIN_FREE_MB:-0}
memfree_mb() { awk '/MemFree/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 999999; }
RUN_TOTAL=$(echo "$FE500_RUNS" | awk -F'[-]' '{if (NF==2) print $2-$1+1; else {n=split($0,a,","); print n}}')

mkdir -p "$LOGDIR"
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGDIR/driver.log"; }

log "=========== FE500 M=20 driver (global queue) ==========="
log "workdir : $WORKDIR_ML"
log "matlab  : $MP"
log "python  : $PY"
log "algs    : $ALGS"
log "runs    : $FE500_RUNS ($RUN_TOTAL per problem)  chunk=$FE500_CHUNK  maxjobs=$MAXJOBS  rounds=$ROUNDS  slice_timeout=${SLICE_TIMEOUT}s  max_slice_fails=$MAX_SLICE_FAILS  cores=$(nproc 2>/dev/null || echo '?')"
log "skip    : problems [${FE500_SKIP_PARTS:-none}]"
log "pacing  : gap=${LAUNCH_GAP}s for the first $COLD_STARTS launches, then ${LAUNCH_GAP_WARM}s ; memory gate $( [ "${MIN_FREE_MB:-0}" -gt 0 ] && echo "on, floor ${MIN_FREE_MB} MB" || echo off )"
log "data    : ${FE500_M20_OUTPUT_ROOT:-D:\\REMOandDREMO测试集\\20目标\\FE500}"
log "========================================="

# Output sub-folder per algorithm. MUST stay in sync with
# fe500_m20_registry.m / missing_runs.py FOLDERS.
keydir() {
    case "$1" in
        REMO)   echo "REMO" ;;
        PCSAEA) echo "PCSAEA" ;;
        CSEA)   echo "CSEA" ;;
        HES_EA) echo "HES_EA" ;;
        SSDE)   echo "SSDE" ;;
        SAMOEA|SAMOEATL2M) echo "SAMOEATL2M" ;;
        PACDIS) echo "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist" ;;
        *)      echo "" ;;
    esac
}

# Canonicalize the key and set every per-algorithm variable the launch needs.
# Returns 0 on success, 1 for an unknown key.
setup_alg() {
    local k="$1"
    case "$k" in SAMOEA|SAMOEATL2M) k="SAMOEA" ;; esac
    KEYDIR="$(keydir "$k")"
    [ -n "$KEYDIR" ] || return 1
    local ovr; ovr=$(printenv "FE500_CLS_$k")
    [ -n "$ovr" ] && KEYDIR="$ovr"
    export FE500_ALG="$k"
    export FE500_FOLDER="$KEYDIR"
    ADIR="$LOGDIR/$k"
    ADIR_ML="$LOGDIR_ML\\$k"
    mkdir -p "$ADIR"
    export FE500_POISON="$ADIR_ML\\poison.txt"
    export FE500_POISON_DIR="$LOGDIR_ML"
    return 0
}

BADKEY=""
launched=0
for attempt in $(seq 1 $ROUNDS); do
    mapfile -t ALL_SLICES < <("$PY" "$MISSING_ALL_PY_ML" 2>/tmp/missing_all.err)
    if [ ${#ALL_SLICES[@]} -eq 0 ]; then
        present=$(ls /d/REMOandDREMO测试集/20目标/FE500/*/*.mat 2>/dev/null | wc -l)
        log "attempt $attempt: no missing slices (present=$present) -> done"
        break
    fi
    log "attempt $attempt: ${#ALL_SLICES[@]} slices to launch"

    for slice in "${ALL_SLICES[@]}"; do
        key="${slice%%|*}"; rest="${slice#*|}"; part="${rest%%|*}"; runs="${rest#*|}"
        setup_alg "$key" || { log "  !! unknown key '$key' -> skip"; BADKEY="$BADKEY $key"; continue; }

        # Refill a free slot.
        while [ "$(jobs -rp | wc -l)" -ge "$MAXJOBS" ]; do
            wait -n 2>/dev/null || sleep 10
        done
        if [ "${MIN_FREE_MB:-0}" -gt 0 ]; then
            while [ "$(memfree_mb)" -lt "$MIN_FREE_MB" ]; do
                log "  [mem] $(memfree_mb) MB free < ${MIN_FREE_MB} MB -> holding"
                wait -n 2>/dev/null || sleep 15
            done
        fi

        log "  [$key] start part $part runs [$runs]"
        RCF="$ADIR/rc_part${part}.txt"
        if [ "$SLICE_TIMEOUT" -gt 0 ] && command -v timeout >/dev/null 2>&1; then
            ( timeout -k 60 "$SLICE_TIMEOUT" \
                "$MP" -batch "addpath('$WORKDIR_ML'); run_FE500_M20('$FE500_ALG',$part,[$runs],$THREADS);" \
                -logfile "$ADIR_ML\\p${part}.log" ; echo "$runs|$?" >> "$RCF" ) &
        else
            ( "$MP" -batch "addpath('$WORKDIR_ML'); run_FE500_M20('$FE500_ALG',$part,[$runs],$THREADS);" \
                -logfile "$ADIR_ML\\p${part}.log" ; echo "$runs|$?" >> "$RCF" ) &
        fi
        launched=$((launched + 1))
        if [ "$launched" -le "$COLD_STARTS" ]; then
            sleep "$LAUNCH_GAP"
        else
            sleep "$LAUNCH_GAP_WARM"
        fi
    done
    wait

    # Poison pass: a slice killed by SLICE_TIMEOUT MAX_SLICE_FAILS times cannot be
    # rescued (fixed seed); drop its first still-missing run.
    for slice in "${ALL_SLICES[@]}"; do
        key="${slice%%|*}"; rest="${slice#*|}"; part="${rest%%|*}"; runs="${rest#*|}"
        setup_alg "$key" || continue
        RCF="$ADIR/rc_part${part}.txt"
        [ -f "$RCF" ] || continue
        nSig=$(grep -c "^${runs}|" "$RCF" 2>/dev/null || true)
        lastRc=$(grep "^${runs}|" "$RCF" 2>/dev/null | tail -1 | cut -d'|' -f2)
        if [ "${lastRc:-0}" = "124" ] && [ "${nSig:-0}" -ge "$MAX_SLICE_FAILS" ]; then
            log "  [timeout] $key part $part runs [$runs] killed ${nSig}x -> poison"
            "$PY" "$MARK_POISON_PY_ML" "$FE500_ALG" "$part" "$runs" "$FE500_POISON" \
                2>&1 | while IFS= read -r l; do log "  $l"; done
        fi
    done
done

# Per-algorithm closing summary.
for key in $ALGS; do
    setup_alg "$key" || continue
    k="$(keydir "$key")"
    d="${FE500_DATA_PREFIX:-/d/REMOandDREMO测试集/20目标/FE500}/$k"
    present=$(ls "$d"/*.mat 2>/dev/null | wc -l)
    poisoned=$( [ -f "$ADIR/poison.txt" ] && wc -l < "$ADIR/poison.txt" || echo 0 )
    log "SUMMARY $key: present=$present  poisoned=$poisoned"
done

if [ "$SKIP_VERIFY" != "1" ]; then
    log "running integrity check (all algorithms)"
    for key in $ALGS; do
        "$MP" -batch "addpath('$WORKDIR_ML'); verify_FE500_M20('$key');" \
            -logfile "$LOGDIR_ML\\verify_${key}.log" &
        sleep 5
    done
    wait
fi
if [ -n "$BADKEY" ]; then
    log "!! UNKNOWN ALGORITHM KEY(S) SKIPPED:$BADKEY"
fi
log "DRIVER_DONE algs=[$ALGS]"
