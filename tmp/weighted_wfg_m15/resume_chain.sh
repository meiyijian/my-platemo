#!/usr/bin/env bash
# Weighted WFG sweep chain (launched by WorkBuddy automation at 2026-09-14 00:00).
#
#   Phase 1: resume the paused M=15 sweep (144 remaining runs of 270).
#   Phase 2: WFG1-9 x 30 runs at M=8, D=10 (starts only after Phase 1 ends).
#   Final  : verify both data folders; append RESULT lines to the chain log.
#
# Resumable: re-running never overwrites valid files. Guarded by a lock dir
# with a heartbeat: a second instance exits immediately unless the lock is
# stale (>30 min without heartbeat, e.g. after a hard kill).
set -u
export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"

ROOT=/d/PlatEMO-master/tmp/weighted_wfg_m15
CHAIN_LOG="$ROOT/chain_20260914_0000.log"
LOCK="$ROOT/chain_active.lock"
mkdir -p "$ROOT"

acquire_lock() {
    if mkdir "$LOCK" 2>/dev/null; then
        date +%s > "$LOCK/ts"
        ( while :; do sleep 600; date +%s > "$LOCK/ts" 2>/dev/null; done ) &
        HEARTBEAT=$!
        trap 'kill $HEARTBEAT 2>/dev/null; rm -rf "$LOCK"' EXIT
        return 0
    fi
    local now ts
    now=$(date +%s); ts=$(cat "$LOCK/ts" 2>/dev/null || echo 0)
    if [ $((now - ts)) -gt 1800 ]; then
        rm -rf "$LOCK"
        acquire_lock
    else
        return 1
    fi
}

if acquire_lock; then
    echo "[$(date '+%F %T')] lock acquired"
else
    echo "[$(date '+%F %T')] another chain instance is active (lock held) - exit"
    exit 0
fi

exec >> "$CHAIN_LOG" 2>&1
echo "[$(date '+%F %T')] ===== chain start ====="

export ALG="REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted"
export FOLDER="REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted"
export PARAMS="3000,0.50,0.25,0.70,6"
export HARNESS="D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_Weighted_WFG_M15"
export SCRATCHROOT="D:/PlatEMO-master/tmp/weighted_wfg_m15"

# ---- Phase 1: resume M=15 (WFG1-4 complete; ~144 runs left) ----
export FUNC="run_WeightedWFG_M15"
export OUTDIR="D:/REMOandDREMO测试集/15目标/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted"
echo "[$(date '+%F %T')] phase1 start: M=15 resume (target 270 files in OUTDIR)"
PIDS=""
for i in 1 2 3 4; do bash /d/PlatEMO-master/tmp/supervise_part.sh $i 4 & PIDS="$PIDS $!"; done
wait $PIDS
echo "[$(date '+%F %T')] phase1 supervise loops finished"

# ---- Phase 2: M=8, D=10 (9 problems x 30 runs) ----
export FUNC="run_WeightedWFG_M8D10"
export OUTDIR="D:/REMOandDREMO测试集/8目标/n10/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted"
echo "[$(date '+%F %T')] phase2 start: M=8 D=10 (target 270 files in OUTDIR)"
PIDS=""
for i in 1 2 3 4; do bash /d/PlatEMO-master/tmp/supervise_part.sh $i 4 & PIDS="$PIDS $!"; done
wait $PIDS
echo "[$(date '+%F %T')] phase2 supervise loops finished"

# ---- Final verification of both phases ----
PY="C:/Users/lsx/.workbuddy/binaries/python/envs/default/Scripts/python.exe"
VFY="D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_Weighted_WFG_M15/verify_weighted_wfg_m15.py"
echo "[$(date '+%F %T')] verify phase1 (M=15)"
"$PY" "$VFY" "D:/REMOandDREMO测试集/15目标/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted" --runs 30 --snapshots 30 --expect-fe 300 --m 15
echo "[$(date '+%F %T')] verify phase2 (M=8, D=10)"
"$PY" "$VFY" "D:/REMOandDREMO测试集/8目标/n10/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted" --runs 30 --snapshots 30 --expect-fe 300 --m 8
echo "[$(date '+%F %T')] ===== chain COMPLETE ====="
