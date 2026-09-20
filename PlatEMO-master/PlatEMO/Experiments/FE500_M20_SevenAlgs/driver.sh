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
# Design is the same as the other drivers of this project: per-problem run
# chunks as slices, up to MAXJOBS staggered MATLAB processes (this machine dies
# with ntdll heap corruption on simultaneous cold starts), and an outer loop that
# re-computes the missing (problem, run) pairs after every pass so crashed slices
# are simply re-driven until the dataset is complete. The full integrity check
# runs at the end. Everything is RESUMABLE: valid MAT files are skipped.
#
# ---- Environment overrides -------------------------------------------------
#   ALGS      space separated keys, default "REMO PCSAEA CSEA HES_EA SSDE SAMOEA PACDIS"
#   RUNS      run set to complete, default 1-20
#   CHUNK     runs per slice, default 10
#   MAXJOBS   concurrent MATLAB processes, default 12
#   ROUNDS    outer re-drive passes per algorithm, default 8
#   MP        MATLAB executable,   default /d/software/mathlab/bin/matlab.exe
#   PY        python executable,   default <managed venv>
#   FE500_M20_OUTPUT_ROOT  output root override, read by the runner as well
#
# Examples
#   bash driver.sh                                  # full run, all seven
#   ALGS="SAMOEA SSDE" RUNS=19,20 bash driver.sh    # stage-2 timing probe
#   ALGS="PACDIS" ROUNDS=3 bash driver.sh           # one algorithm only
#
# Progress:  logs/driver.log                (one line per slice start/finish)
#            logs/<KEY>/driver.log          (per-algorithm journal)
#            logs/<KEY>/p<NN>_a<N>.log      (per-slice MATLAB log;
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
MISSING_PY_ML="$WORKDIR_ML\\missing_runs.py"
ALGS=${ALGS:-"REMO PCSAEA CSEA HES_EA SSDE SAMOEA PACDIS"}
export FE500_RUNS=${RUNS:-1-20}
export FE500_CHUNK=${CHUNK:-10}
MAXJOBS=${MAXJOBS:-12}
THREADS=${THREADS:-1}
ROUNDS=${ROUNDS:-8}
SKIP_VERIFY=${SKIP_VERIFY:-0}
# Per-slice wall-clock cap in seconds (0 disables). The published HES_EA can hang
# forever on a stranded cluster (see fe500_m20_registry.m); without a cap one
# such process would block a pool slot indefinitely. 4 h covers the slowest
# healthy slice (10 runs of the slowest algorithm, under full pool contention).
SLICE_TIMEOUT=${SLICE_TIMEOUT:-14400}
# How many times the SAME slice may be killed by SLICE_TIMEOUT before its first
# still-missing run is declared poisoned and dropped. The seed is fixed per
# (problem, run), so a run that hangs hangs again on every re-drive; without
# poisoning, one stuck run would burn SLICE_TIMEOUT on a slot once per round.
MAX_SLICE_FAILS=${MAX_SLICE_FAILS:-2}
# Launch pacing. This box dies with ntdll heap corruption when many MATLAB
# processes COLD-start at the same moment, so launches are always spaced out --
# but the hazard is the cold start, not the steady state. A single fixed gap of
# 20 s also throttled fast algorithms to a crawl: an SSDE slice finishes in ~25 s
# while launches were 22 s apart, so the pool never got past 2-3 of 14 processes
# and the CPU sat at ~12%. Hence: the first COLD_STARTS launches of each pass pay
# the full LAUNCH_GAP, everything after that only pays LAUNCH_GAP_WARM.
LAUNCH_GAP=${LAUNCH_GAP:-20}
COLD_STARTS=${COLD_STARTS:-4}
LAUNCH_GAP_WARM=${LAUNCH_GAP_WARM:-5}
# Optional memory gate, DISABLED by default (MIN_FREE_MB=0).
#
# History: at MAXJOBS=14 this box got tight -- 31.3 GB total, ~16 GB already taken
# by the OS and apps, one MATLAB worker 0.6 GB (SSDE) to ~1.2 GB (patternnet /
# dacefit algorithms), so 14 workers would have left only ~2 GB and the heavy
# algorithms (REMO, PACDIS, HES_EA) could start paging. MAXJOBS is 12 now, the
# value this machine has always run at (~98% CPU utilisation, comfortable
# headroom), so the gate is off. Set MIN_FREE_MB to a positive number (e.g. 3000)
# if there is ever a reason to run more workers than the memory can safely hold:
# before each launch the driver then waits until free memory recovers.
MIN_FREE_MB=${MIN_FREE_MB:-0}
memfree_mb() { awk '/MemFree/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 999999; }
RUN_TOTAL=$(echo "$FE500_RUNS" | awk -F'[-]' '{if (NF==2) print $2-$1+1; else {n=split($0,a,","); print n}}')

mkdir -p "$LOGDIR"
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGDIR/driver.log"; }

log "=========== FE500 M=20 driver ==========="
log "workdir : $WORKDIR_ML"
log "matlab  : $MP"
log "python  : $PY"
log "algs    : $ALGS"
log "runs    : $FE500_RUNS ($RUN_TOTAL per problem)  chunk=$FE500_CHUNK  maxjobs=$MAXJOBS  rounds=$ROUNDS  slice_timeout=${SLICE_TIMEOUT}s  max_slice_fails=$MAX_SLICE_FAILS  cores=$(nproc 2>/dev/null || echo '?')"
log "pacing  : gap=${LAUNCH_GAP}s for the first $COLD_STARTS launches, then ${LAUNCH_GAP_WARM}s ; memory gate $( [ "${MIN_FREE_MB:-0}" -gt 0 ] && echo "on, floor ${MIN_FREE_MB} MB" || echo off )"
log "data    : ${FE500_M20_OUTPUT_ROOT:-D:\\REMOandDREMO测试集\\20目标\\FE500}"
log "========================================="

for key in $ALGS; do
    export FE500_ALG="$key"
    # Output sub-folder per algorithm. MUST stay in sync with
    # fe500_m20_registry.m / missing_runs.py FOLDERS.
    case "$key" in
        REMO)   KEYDIR="REMO" ;;
        PCSAEA) KEYDIR="PCSAEA" ;;
        CSEA)   KEYDIR="CSEA" ;;
        HES_EA) KEYDIR="HES_EA" ;;
        SSDE)   KEYDIR="SSDE" ;;
        SAMOEA) KEYDIR="SAMOEATL2M" ;;
        PACDIS) KEYDIR="REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist" ;;
        *)      echo "unknown algorithm key '$key'"; exit 2 ;;
    esac
    # A class override (run_FE500_M20 reads FE500_CLS_<KEY>) also moves the
    # output folder, so mirror that here by pointing at the overridden name.
    CLS_OVR=$(printenv "FE500_CLS_$key")
    if [ -n "$CLS_OVR" ]; then KEYDIR="$CLS_OVR"; fi
    ADIR="$LOGDIR/$key"
    ADIR_ML="$LOGDIR_ML\\$key"
    mkdir -p "$ADIR"
    alog() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$ADIR/driver.log"; }
    # Poison list: (problem,run) pairs that hang deterministically and are skipped.
    export FE500_POISON="$ADIR_ML\\poison.txt"
    if [ -s "$ADIR/poison.txt" ]; then
        alog "  WARNING: $(wc -l < "$ADIR/poison.txt") previously poisoned (problem,run) pair(s) will be skipped:"
        sed 's/^/    poisoned /' "$ADIR/poison.txt" | while IFS= read -r l; do alog "$l"; done
    fi

    alog "---------- $key start (folder $KEYDIR) ----------"
    DATA_SUB="${FE500_DATA_PREFIX:-/d/REMOandDREMO测试集/20目标/FE500}/$KEYDIR"
    TOTAL=$((16 * RUN_TOTAL))

    for attempt in $(seq 1 $ROUNDS); do
        mapfile -t SLICES < <("$PY" "$MISSING_PY_ML")
        present=$(ls "$DATA_SUB"/*.mat 2>/dev/null | wc -l)
        if [ ${#SLICES[@]} -eq 0 ]; then
            alog "attempt $attempt: no missing runs (present=$present/$TOTAL) -> done"
            break
        fi
        alog "attempt $attempt: present=$present/$TOTAL, ${#SLICES[@]} slices to go"
        launched=0
        for slice in "${SLICES[@]}"; do
            part=${slice%%|*}
            runs=${slice##*|}
            while [ "$(jobs -rp | wc -l)" -ge "$MAXJOBS" ]; do
                wait -n 2>/dev/null || sleep 10
            done
            if [ "${MIN_FREE_MB:-0}" -gt 0 ]; then
                while [ "$(memfree_mb)" -lt "$MIN_FREE_MB" ]; do
                    alog "  [mem] $(memfree_mb) MB free < ${MIN_FREE_MB} MB -> holding next launch"
                    wait -n 2>/dev/null || sleep 15
                done
            fi
            alog "  start part $part runs [$runs]"
            # rc journal: one "<runs>|<exit code>" line per launch, so the poison
            # pass can count how often THIS exact slice has been killed.
            RCF="$ADIR/rc_part${part}.txt"
            if [ "$SLICE_TIMEOUT" -gt 0 ] && command -v timeout >/dev/null 2>&1; then
                ( timeout -k 60 "$SLICE_TIMEOUT" \
                    "$MP" -batch "addpath('$WORKDIR_ML'); run_FE500_M20('$key',$part,[$runs],$THREADS);" \
                    -logfile "$ADIR_ML\\p${part}_a${attempt}.log" ; echo "$runs|$?" >> "$RCF" ) &
            else
                ( "$MP" -batch "addpath('$WORKDIR_ML'); run_FE500_M20('$key',$part,[$runs],$THREADS);" \
                    -logfile "$ADIR_ML\\p${part}_a${attempt}.log" ; echo "$runs|$?" >> "$RCF" ) &
            fi
            launched=$((launched + 1))
            if [ "$launched" -le "$COLD_STARTS" ]; then
                sleep "$LAUNCH_GAP"
            else
                sleep "$LAUNCH_GAP_WARM"
            fi
        done
        wait
        present=$(ls "$DATA_SUB"/*.mat 2>/dev/null | wc -l)
        alog "attempt $attempt: pool finished; present=$present/$TOTAL"

        # --- poison pass: a slice killed by SLICE_TIMEOUT MAX_SLICE_FAILS times
        #     cannot be rescued by re-driving it (fixed seed) -> drop the culprit.
        for slice in "${SLICES[@]}"; do
            part=${slice%%|*}
            runs=${slice##*|}
            RCF="$ADIR/rc_part${part}.txt"
            [ -f "$RCF" ] || continue
            nSig=$(grep -c "^${runs}|" "$RCF" 2>/dev/null || true)
            lastRc=$(grep "^${runs}|" "$RCF" 2>/dev/null | tail -1 | cut -d'|' -f2)
            if [ "${lastRc:-0}" = "124" ] && [ "${nSig:-0}" -ge "$MAX_SLICE_FAILS" ]; then
                alog "  [timeout] part $part runs [$runs] killed ${nSig}x -> lookup culprit"
                "$PY" "$WORKDIR_ML\\mark_poison.py" "$key" "$part" "$runs" "$ADIR_ML\\poison.txt" \
                    2>&1 | while IFS= read -r l; do alog "  $l"; done
            fi
        done
    done

    present=$(ls "$DATA_SUB"/*.mat 2>/dev/null | wc -l)
    poisoned=$(wc -l < "$ADIR/poison.txt" 2>/dev/null || echo 0)
    alog "---------- $key done: present=$present/$TOTAL  poisoned=$poisoned ----------"
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
log "DRIVER_DONE algs=[$ALGS]"
