# Print "<problemIndex>|<run,run,...>" for every chunk of still-missing runs, so
# the driver can relaunch only the gaps at good load balance (10 runs per slice).
# Problem order is the paper's 16-problem list: 1..7 = DTLZ1..7, 8..16 = WFG1..9.
import os

ROOT = r"D:\REMOandDREMO测试集\15目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
ALG = "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"
PROBS = ["DTLZ1", "DTLZ2", "DTLZ3", "DTLZ4", "DTLZ5", "DTLZ6", "DTLZ7",
         "WFG1", "WFG2", "WFG3", "WFG4", "WFG5", "WFG6", "WFG7", "WFG8", "WFG9"]
CHUNK = 10

for index, problem in enumerate(PROBS, 1):
    missing = []
    for run in range(1, 21):
        found = any(os.path.isfile(os.path.join(
            ROOT, "%s_%s_M15_D%d_%d.mat" % (ALG, problem, d, run))) for d in (30, 31))
        if not found:
            missing.append(run)
    for start in range(0, len(missing), CHUNK):
        chunk = missing[start:start + CHUNK]
        print("%d|%s" % (index, ",".join(str(c) for c in chunk)))
