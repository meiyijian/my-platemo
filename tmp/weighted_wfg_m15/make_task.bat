@echo off
schtasks /Create /TN WeightedWFG_Resume_M15_M8D10 /XML D:\PlatEMO-master\tmp\weighted_wfg_m15\task_utf16.xml /F
echo --- query ---
schtasks /Query /TN WeightedWFG_Resume_M15_M8D10 /V /FO LIST
