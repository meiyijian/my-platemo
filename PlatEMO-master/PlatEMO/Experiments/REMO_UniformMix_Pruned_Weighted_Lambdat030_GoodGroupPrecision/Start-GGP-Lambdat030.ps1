$ErrorActionPreference = 'Stop'
$experimentDir = $PSScriptRoot
$matlabExe = 'D:\software\mathlab\bin\matlab.exe'
$logDir = Join-Path $experimentDir 'results\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Anti Modern-Standby guard (this machine freezes wall-clock when the
# display auto-powers-off; keep the display and system awake during runs).
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
Write-Host 'Power plan set: monitor/standby AC timeouts disabled for this run session.'
Write-Host 'House maximum: 12 MATLAB processes x 1 compute thread (pMix-sweep config).'

$lock = $null
try {
    $lock = [IO.File]::Open((Join-Path $logDir 'supervisor12.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $matlabDir = $experimentDir.Replace('\','/').Replace("'","''")
    $pending = @(1,2,3,4,5,6,7,8,9,10,11,12)
    for ($attempt=1; $attempt -le 3 -and $pending.Count -gt 0; $attempt++) {
        $workers = @()
        foreach ($part in $pending) {
            $log = Join-Path $logDir "part${part}of12_attempt${attempt}.log"
            $batch = "addpath('$matlabDir'); run_LTGGPPartition($part,12);"
            $process = Start-Process -FilePath $matlabExe -ArgumentList @('-batch', ('"'+$batch+'"'), '-logfile', ('"'+$log+'"')) -WindowStyle Hidden -PassThru
            $workers += [pscustomobject]@{ Part=$part; Process=$process; Log=$log }
        }
        $workers | Select-Object Part,@{Name='PID';Expression={$_.Process.Id}},Log | ConvertTo-Json | Set-Content (Join-Path $logDir 'workers12.json')
        $pending = @()
        foreach ($worker in $workers) {
            $worker.Process.WaitForExit()
            $marker = Join-Path $experimentDir "results\PART$($worker.Part)of12_COMPLETE.txt"
            if (-not (Test-Path -LiteralPath $marker)) { $pending += $worker.Part }
        }
    }
    if ($pending.Count -gt 0) { throw "Failed after three resumable attempts: parts=$pending. See MATLAB logs." }
    $batch = "addpath('$matlabDir'); finish_LTGGP;"
    $process = Start-Process -FilePath $matlabExe -ArgumentList @('-batch', ('"'+$batch+'"'), '-logfile', ('"'+(Join-Path $logDir 'analysis.log')+'"')) -WindowStyle Hidden -PassThru
    $process.WaitForExit()
    if (-not (Test-Path (Join-Path $experimentDir 'results\FORMAL_COMPLETE.txt'))) { throw 'Final validation/analysis failed; see analysis.log.' }
    'COMPLETE: 150 validated runs and analysis.' | Set-Content (Join-Path $logDir 'supervisor12_status.txt')
} catch {
    $_ | Out-String | Set-Content (Join-Path $logDir 'supervisor12_error.txt')
    exit 1
} finally {
    if ($lock) { $lock.Dispose() }
}
