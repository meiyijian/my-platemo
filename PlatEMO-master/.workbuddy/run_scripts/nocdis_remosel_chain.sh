#!/usr/bin/env bash
# nocdis_remosel_chain.sh -- M=10 block, then M=20 block, for REMO_NoCDIS_REMOSelection.
# Protocol: 16 problems (DTLZ1-7 + WFG1-9) x 20 runs, N=100, D=30 (WFG2/3 -> 31),
# maxFE=300, save=30, seed 20260912 + M*1e5 + 1000*probIdx + run.
LOG="D:/PlatEMO-master/PlatEMO-master/.workbuddy/nocdis_remosel_logs"
MATLAB="D:/mathlab2023a/bin/matlab.exe"
cd "D:/PlatEMO-master/PlatEMO-master" || exit 1
mkdir -p "$LOG"

stage() {
  local M=$1 W=$2
  echo "=== STAGE run M=$M W=$W START $(date) ===" >> "$LOG/chain.log"
  "$MATLAB" -wait -batch "addpath('D:/PlatEMO-master/PlatEMO-master/.workbuddy/run_scripts'); RunNoCDISREMOSelection('run',$M,$W)" >> "$LOG/stage_M${M}.log" 2>&1
  local rc=$?
  echo "=== STAGE run M=$M W=$W END rc=$rc $(date) ===" >> "$LOG/chain.log"
}

echo "### CHAIN START $(date) ###" >> "$LOG/chain.log"
stage 10 12
stage 20 12
echo "=== STAGE post M=20 START $(date) ===" >> "$LOG/chain.log"
"$MATLAB" -wait -batch "addpath('D:/PlatEMO-master/PlatEMO-master/.workbuddy/run_scripts'); RunNoCDISREMOSelection('post',20)" >> "$LOG/stage_M20_post.log" 2>&1
echo "=== STAGE post M=20 END rc=$? $(date) ===" >> "$LOG/chain.log"
echo "### CHAIN DONE $(date) ###" >> "$LOG/chain.log"
