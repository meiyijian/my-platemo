@echo off
setlocal
"D:\mathlab2023a\bin\matlab.exe" -wait -batch "addpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'); RunPaperWeighted30('run',2);"
if errorlevel 1 (
  echo Some runs failed or the runner stopped. See diagnostics/paper_30runs.
) else (
  echo All requested runs are complete.
)
pause
