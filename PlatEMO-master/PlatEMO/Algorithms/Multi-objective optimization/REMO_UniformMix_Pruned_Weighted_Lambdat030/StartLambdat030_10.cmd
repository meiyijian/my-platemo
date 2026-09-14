@echo off
setlocal
set "ALG=%~dp0"
echo Fixed lambda_t=0.30; DTLZ2/4/5/7 M=10; 10 runs per arm, 80 runs total.
"D:\mathlab2023a\bin\matlab.exe" -wait -batch "addpath('%ALG%'); RunLambdat030_10('run',2);"
if errorlevel 1 exit /b 1
echo Run analyze_lambdat030 to summarize completed runs.
pause
