#!/usr/bin/env bash
# Supervise one partition of a Pruned-family full-series sweep.
#
#   bash supervise_part.sh <part> <nParts> [maxAttempts]
#
# The MATLAB harness is resumable (valid result files are skipped), so this
# wrapper just relaunches MATLAB until the partition reports completion. That
# makes the sweep immune to an individual MATLAB process dying - MATLAB R2021b
# is known to exit with 0xc0000374 heap corruption in this environment, always
# AFTER the pending result file has been written to disk.
#
# Overridable through environment variables:
#   ALG      algorithm class name      (default ..._Pruned_qKeep080)
#   FOLDER   result sub-directory name (default: $ALG)
#   PARAMS   comma-separated parameter list (default 3000,0.50,0.25,0.80,6)
#   HARNESS  harness directory         (default the FullSeries experiment)
set -u

PART=${1:?part index required}
NPARTS=${2:?nParts required}
MAXATTEMPTS=${3:-200}

ALG=${ALG:-REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080}
FOLDER=${FOLDER:-$ALG}
PARAMS=${PARAMS:-3000,0.50,0.25,0.80,6}
HARNESS=${HARNESS:-D:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries}

MATLAB="/d/software/mathlab/bin/matlab.exe"
SCRATCH="D:/PlatEMO-master/tmp/pruned_fullseries/$FOLDER"
OUTDIR="D:/REMOandDREMO测试集/10目标/n30/$FOLDER"
RUNLOG="$OUTDIR/_runlog_part${PART}of${NPARTS}.txt"
STDOUT="$SCRATCH/part${PART}of${NPARTS}_stdout.log"

mkdir -p "$SCRATCH" "$OUTDIR"

STAMP() { date '+%Y-%m-%d %H:%M:%S'; }

for attempt in $(seq 1 "$MAXATTEMPTS"); do
    echo "[$(STAMP)] part $PART attempt $attempt launching MATLAB (alg=$ALG params=$PARAMS)" >> "$STDOUT"
    "$MATLAB" -batch "maxNumCompThreads(4); addpath('$HARNESS'); run_UniformMixPrunedFullSeries($PART,$NPARTS,'Algorithm','$ALG','FolderName','$FOLDER','Parameters',{$PARAMS})" >> "$STDOUT" 2>&1
    rc=$?
    echo "[$(STAMP)] part $PART attempt $attempt exited rc=$rc" >> "$STDOUT"

    if [ -f "$RUNLOG" ] && grep -q "part ${PART}/${NPARTS} done" "$RUNLOG"; then
        echo "[$(STAMP)] part $PART COMPLETE after $attempt attempt(s)" >> "$STDOUT"
        exit 0
    fi

    nfiles=$(find "$OUTDIR" -maxdepth 1 -name '*.mat' ! -name '*.tmp.mat' 2>/dev/null | wc -l)
    echo "[$(STAMP)] part $PART attempt $attempt ended early, $nfiles result files present so far" >> "$STDOUT"
    sleep 5
done

echo "[$(STAMP)] part $PART gave up after $MAXATTEMPTS attempts" >> "$STDOUT"
exit 1
