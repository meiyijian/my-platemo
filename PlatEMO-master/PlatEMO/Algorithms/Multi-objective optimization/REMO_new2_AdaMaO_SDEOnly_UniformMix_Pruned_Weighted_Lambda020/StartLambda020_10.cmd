@echo off
setlocal
set ALG=D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted_Lambda020
echo.
echo 1/2  lambda0=0 equivalence check against the seed-matched baseline control
"D:\mathlab2023a\bin\matlab.exe" -wait -batch "addpath(genpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO')); addpath('%ALG%'); RunLambda020_10('verify0');"
if errorlevel 1 (
  echo.
  echo verify0 FAILED. Do not start the 40 runs before this passes.
  pause
  exit /b 1
)
echo.
echo 2/2  40 runs, DTLZ2/4/5/7 M=10, lambda0=0.20
"D:\mathlab2023a\bin\matlab.exe" -wait -batch "addpath(genpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO')); addpath('%ALG%'); RunLambda020_10('run','max');"
if errorlevel 1 (
  echo Some runs failed or the runner stopped. See diagnostics\lambda020_10runs.
) else (
  echo All requested runs are complete. Run analyze_lambda020 next.
)
pause
