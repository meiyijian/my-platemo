#!/bin/bash
# Resilient driver for HES_EA_N100 @ M=10 (10目标\n30).
#
#   M=10, D=30, N=100, maxFE=300, SaveCount=30,
#   seeds 21260912 + 1000*problemIndex + run,
#   16 problems (DTLZ1-7, WFG1-9) x 20 runs = 320 runs.
#   Algorithm hyper-parameters are the published defaults {wmax,WN,KMeans}
#   = {20,190,4} (Parameters is passed as an empty cell).
#   Each MAT stores result + metric{runtime, IGD, IGDp}.
#   Data: D:\REMOandDREMO测试集\10目标\n30\HES_EA_N100
#
# Same design as the other M=20/M=10 drivers: per-problem run chunks of 10 as
# slices, up to MAXJOBS staggered MATLAB processes (this machine dies with
# ntdll heap corruption on simultaneous cold starts), and an outer loop that
# re-computes the missing (problem, run) pairs after every pass so crashed
# slices are simply re-driven until the dataset is complete. The full 320-file
# integrity check runs at the end.
#
# ---------------------------------------------------------------------------
# RUNNING THIS ON ANOTHER MACHINE
#   The working directory is derived from this script's own location, so the
#   repo can live anywhere. Only these two external paths may need overriding:
#
#     MP   =/d/software/mathlab/bin/matlab.exe                          (MATLAB)
#     PY    =C:/Users/lsx/.workbuddy/binaries/python/envs/default/Scripts/python.exe
#     DATADIR=/d/REMOandDREMO测试集/10目标/n30/HES_EA_N100              (output)
#
#   and, inside the MATLAB runner, the output ROOT (one level above DATADIR)
#   can be overridden with the environment variable HESEA_M10_OUTPUT_ROOT.
#   Example:
#     MP='/c/Program Files/MATLAB/R2024b/bin/matlab.exe' \
#     DATADIR='/d/data/10目标/n30/HES_EA_N100' bash driver.sh
#
#   The sweep is fully RESUMABLE: existing valid MAT files are skipped, so
#   re-running this script only fills the gaps. Progress: logs/driver.log,
#   per-slice detail: logs/p<problem>_a<attempt>.log
#   (line format: [done] <prob> run k | IGD A -> B | runtime Xs | wall Ys | ok)
# ---------------------------------------------------------------------------

export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"

# Self-locating: works wherever the repo is checked out.
SELFDIR_POSIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELFDIR_WIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W | sed 's|/|\\|g')"

MP=${MP:-/d/software/mathlab/bin/matlab.exe}
PY=${PY:-C:/Users/lsx/.workbuddy/binaries/python/envs/default/Scripts/python.exe}
WORKDIR=${WORKDIR:-$SELFDIR_POSIX}
WORKDIR_ML=${WORKDIR_ML:-$SELFDIR_WIN}
DATADIR=${DATADIR:-/d/REMOandDREMO测试集/10目标/n30/HES_EA_N100}
LOGDIR=$WORKDIR/logs
# Windows-style paths for every call that leaves MSYS: Windows executables
# (python.exe, matlab.exe) mangle POSIX '/d/...' into 'd:\d\...'.
LOGDIR_ML="$WORKDIR_ML\\logs"
MISSING_PY_ML="$WORKDIR_ML\\missing_runs.py"
MAXJOBS=${MAXJOBS:-12}
THREADS=${THREADS:-1}
ROUNDS=${ROUNDS:-10}

mkdir -p "$LOGDIR"
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGDIR/driver.log"; }

log "driver start (HES_EA_N100, M=10) | maxjobs=$MAXJOBS threads=$THREADS rounds=$ROUNDS"
log "workdir: $WORKDIR_ML"
log "matlab : $MP"
log "python : $PY"
log "target : $DATADIR"

for attempt in $(seq 1 $ROUNDS); do
    mapfile -t SLICES < <("$PY" "$MISSING_PY_ML")
    present=$(ls "$DATADIR"/*.mat 2>/dev/null | wc -l)
    if [ ${#SLICES[@]} -eq 0 ]; then
        log "attempt $attempt: no missing runs (present=$present/320) -> done"
        break
    fi
    log "attempt $attempt: present=$present/320, ${#SLICES[@]} run slices to go"
    for slice in "${SLICES[@]}"; do
        part=${slice%%|*}
        runs=${slice##*|}
        while [ "$(jobs -rp | wc -l)" -ge "$MAXJOBS" ]; do
            wait -n 2>/dev/null || sleep 10
        done
        log "  start part $part runs [$runs]"
        "$MP" -batch "addpath('$WORKDIR_ML'); run_HES_EA_N100_M10($part,[$runs],$THREADS);" \
            -logfile "$LOGDIR_ML\\p${part}_a${attempt}.log" &
        sleep 20
    done
    wait
    log "attempt $attempt: pool finished; present=$(ls "$DATADIR"/*.mat 2>/dev/null | wc -l)/320"
done

present=$(ls "$DATADIR"/*.mat 2>/dev/null | wc -l)
log "final dataset count: $present/320"
log "running integrity check"
"$MP" -batch "addpath('$WORKDIR_ML'); verify_HES_EA_N100_M10;" \
    -logfile "$LOGDIR_ML\\verify.log"
log "DRIVER_DONE present=$present"
