#!/usr/bin/env bash
# Wait until the qKeep080 full-series run finishes (288 files), then verify both
# the qKeep=0.80 and qKeep=0.70 run directories with the same verify script.
set -u

export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"

D080="/d/REMOandDREMO测试集/10目标/n30/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080"
D070="/d/REMOandDREMO测试集/10目标/n30/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned"
LOG="/d/PlatEMO-master/tmp/pruned_fullseries/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080"
PY="C:/Users/lsx/.workbuddy/binaries/python/envs/default/Scripts/python.exe"
VERIFY="D:\\PlatEMO-master\\PlatEMO-master\\PlatEMO\\Experiments\\REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries\\verify_pruned_run.py"
OUT="/d/PlatEMO-master/tmp/qkeep080_final_report"
mkdir -p "$OUT"

count() { ls "$D080"/*.mat 2>/dev/null | grep -v '\.tmp\.mat$' | wc -l | tr -d ' '; }

stall=0
prev=-1
for i in $(seq 1 90); do
  n=$(count)
  donecnt=0
  for p in 1 2 3 4; do
    if grep -q "part ${p}/4 done" "$D080/_runlog_part${p}of4.txt" 2>/dev/null; then
      donecnt=$((donecnt+1))
    fi
  done
  ml=$(tasklist 2>/dev/null | grep -ci 'MATLAB.exe')
  echo "[wait $(date '+%H:%M:%S')] files=$n/288 partitions_done=$donecnt matlab_workers=$ml"
  if [ "$n" -ge 288 ] || [ "$donecnt" -eq 4 ]; then
    echo "[wait] completion condition reached"
    break
  fi
  if [ "$n" -le "$prev" ] && [ "$ml" -eq 0 ]; then
    stall=$((stall+1))
  else
    stall=0
  fi
  prev=$n
  if [ "$stall" -ge 5 ]; then
    echo "[wait] no progress for 5 checks and no MATLAB worker alive -> stop waiting"
    break
  fi
  sleep 60
done

echo
echo "================ FINAL COUNT ================"
count
echo

echo "================ VERIFY qKeep=0.80 ================"
"$PY" "$VERIFY" "$D080" --runs 18 --expect-fe 300 --xlsx "_verify_summary.xlsx" 2>&1 | tee "$OUT/verify_qkeep080.txt"
echo "exit=$?"

echo
echo "================ VERIFY qKeep=0.70 ================"
"$PY" "$VERIFY" "$D070" --runs 18 --expect-fe 300 --xlsx "_verify_summary.xlsx" 2>&1 | tee "$OUT/verify_qkeep070.txt"
echo "exit=$?"

echo
echo "================ DONE ================"
date
