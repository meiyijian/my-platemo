#!/bin/bash
# Resilient driver for REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist @ M=10.
#
#   M=10, D=30, N=100, maxFE=300, params {3000,0.50,0.25,0.70,6},
#   16 problems (DTLZ1-7, WFG1-9) x 20 runs = 320 runs.
#   Data: D:\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
#
# Slices are per problem (the seed needs one problem per process); several
# processes may share a problem through different run vectors. Up to MAXJOBS
# MATLAB processes run at once, started 25 s apart: this machine dies with
# ntdll heap corruption under simultaneous cold starts, staggered starts are
# mandatory, and single-thread processes are the verified house maximum.
#
# The outer loop re-computes the missing (problem, run) pairs after every pass,
# so crashed slices are simply re-driven until the dataset is complete
# (missing_runs.py + the harness skip-valid-files logic make this idempotent).
# Finally the full 320-file integrity check runs.

export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"

MP=/d/software/mathlab/bin/matlab.exe
PY='C:/Users/lsx/.workbuddy/binaries/python/envs/default/Scripts/python.exe'
WORKDIR=/d/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_M10
WORKDIR_ML='D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_M10'
DATADIR=/d/REMOandDREMO测试集/10目标/n30/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
LOGDIR=$WORKDIR/logs
# Windows-style paths for every call that leaves MSYS: Windows executables
# (python.exe, matlab.exe) mangle POSIX '/d/...' into 'd:\d\...'.
LOGDIR_ML="$WORKDIR_ML\\logs"
MISSING_PY_ML="$WORKDIR_ML\\missing_runs.py"
MAXJOBS=12
THREADS=1
ROUNDS=8

mkdir -p "$LOGDIR"
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGDIR/driver.log"; }

log "driver start | maxjobs=$MAXJOBS threads=$THREADS rounds=$ROUNDS"
log "target dir: $DATADIR"

for attempt in $(seq 1 $ROUNDS); do
    mapfile -t SLICES < <("$PY" "$MISSING_PY_ML")
    present=$(ls "$DATADIR"/*.mat 2>/dev/null | wc -l)
    if [ ${#SLICES[@]} -eq 0 ]; then
        log "attempt $attempt: no missing runs (present=$present/320) -> done"
        break
    fi
    log "attempt $attempt: present=$present/320, ${#SLICES[@]} problem slices to run"
    for slice in "${SLICES[@]}"; do
        part=${slice%%|*}
        runs=${slice##*|}
        while [ "$(jobs -rp | wc -l)" -ge "$MAXJOBS" ]; do
            wait -n 2>/dev/null || sleep 10
        done
        log "  start part $part runs [$runs]"
        "$MP" -batch "addpath('$WORKDIR_ML'); run_Lambdat030_NoBatchDist_M10($part,[$runs],$THREADS);" \
            -logfile "$LOGDIR_ML\\p${part}_a${attempt}.log" &
        sleep 25
    done
    wait
    log "attempt $attempt: pool finished; present=$(ls "$DATADIR"/*.mat 2>/dev/null | wc -l)/320"
done

present=$(ls "$DATADIR"/*.mat 2>/dev/null | wc -l)
log "final dataset count: $present/320"
log "running integrity check"
"$MP" -batch "addpath('$WORKDIR_ML'); verify_Lambdat030_NoBatchDist_M10;" \
    -logfile "$LOGDIR_ML\\verify.log"
log "DRIVER_DONE present=$present"
