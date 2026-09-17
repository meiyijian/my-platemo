#!/bin/bash
# Chain watcher: start the M=20 sweep once the M=10 sweep has really finished.
#
# 2026-09-18 lesson: a plain "grep DRIVER_DONE" is NOT safe, because the log
# still contains the line from an earlier aborted driver start ("present=0"),
# which fired this watcher while M=10 was only half done. The completion test
# must therefore also require that the M=10 MATLAB pool has drained, twice in a
# row, and accept either the final driver line or a complete 320-file dataset.
#
# The watcher never edits a running driver (bash re-reads scripts by byte
# offset, so editing a live script corrupts its parse).

export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"

W10=/d/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_M10
W20=/d/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_M20
D10=/d/REMOandDREMO测试集/10目标/n30/REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
CHAINLOG=$W20/logs/chain.log
mkdir -p "$W20/logs"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$CHAINLOG"; }

log "chain watcher start (robust completion test); waiting for M=10"
ok_streak=0
while true; do
    running=$(tasklist 2>/dev/null | grep -c MATLAB.exe)
    present=$(ls "$D10"/*.mat 2>/dev/null | wc -l)
    if [ "$running" -eq 0 ]; then
        if grep -q "DRIVER_DONE" "$W10/logs/driver.log" 2>/dev/null || [ "$present" -eq 320 ]; then
            ok_streak=$((ok_streak+1))
        else
            ok_streak=0
        fi
    else
        ok_streak=0
    fi
    log "wait: m10_files=$present matlab_procs=$running streak=$ok_streak"
    if [ "$ok_streak" -ge 2 ]; then
        log "M=10 finished (pool drained twice with a completion marker)"
        break
    fi
    sleep 60
done

present=$(ls "$D10"/*.mat 2>/dev/null | wc -l)
log "M=10 dataset: $present/320 stored; launching M=20 driver in 20 s"
sleep 20
bash "$W20/driver.sh" >> "$CHAINLOG" 2>&1
log "M=20 driver returned"
