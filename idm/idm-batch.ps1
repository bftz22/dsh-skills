# idm-batch.ps1 - batch queue downloads via IDM from a URL list file
# list format (per line): URL | Dir | File   (# comment / blank lines skipped)
# usage: powershell -File idm-batch.ps1 -ListFile "D:\urls.txt" [-Wait] [-Sha1File "D:\sha1s.txt"] [-TimeoutSec 1800]
param(
  [Parameter(Mandatory = $true)][string]$ListFile,
  [switch]$Wait,
  [string]$Sha1File = "",
  [int]$TimeoutSec = 1800
)

$IDM = "{IDM_DIR}\IDMan.exe"
$ErrorActionPreference = "Stop"
$DefaultDir = "D:\download"

function Get-Sha1($path) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $fs = [System.IO.File]::OpenRead($path)
  try { $hash = $sha.ComputeHash($fs) } finally { $fs.Close() }
  return ([BitConverter]::ToString($hash)).Replace("-", "").ToLower()
}

# parse list
$tasks = @()
foreach ($line in Get-Content $ListFile -Encoding UTF8) {
  $t = $line.Trim()
  if ($t -eq "" -or $t.StartsWith("#")) { continue }
  $parts = $t.Split("|")
  $url = $parts[0].Trim()
  $dir = if ($parts.Count -gt 1 -and $parts[1].Trim() -ne "") { $parts[1].Trim() } else { $DefaultDir }
  $file = if ($parts.Count -gt 2 -and $parts[2].Trim() -ne "") { $parts[2].Trim() } else { $url.Split("/")[-1].Split("?")[0] }
  $tasks += ,@($url, $dir, $file)
}
Write-Host "[idm-batch] parsed $($tasks.Count) tasks from $ListFile"
if ($tasks.Count -eq 0) { Write-Host "[FAIL] no tasks"; exit 1 }

# sha1 map (full path -> sha1)
$shaMap = @{}
if ($Sha1File -ne "" -and (Test-Path $Sha1File)) {
  foreach ($line in Get-Content $Sha1File -Encoding UTF8) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $p = $t.Split("|")
    if ($p.Count -ge 2) { $shaMap[$p[0].Trim()] = $p[1].Trim().ToLower() }
  }
  Write-Host "[idm-batch] loaded $($shaMap.Count) sha1 entries"
}

# ensure IDM running
if (-not (Get-Process -Name "IDMan" -ErrorAction SilentlyContinue)) {
  Write-Host "[idm-batch] starting IDM..."
  Start-Process $IDM | Out-Null
  Start-Sleep -Seconds 8
}

# queue each task (skip already-present valid files)
$queued = 0; $skipped = 0
foreach ($t in $tasks) {
  $url = $t[0]; $dir = $t[1]; $file = $t[2]
  $dest = Join-Path $dir $file
  $want = $shaMap[$dest]
  if (Test-Path $dest) {
    if ($want -ne $null -and (Get-Sha1 $dest) -eq $want) { $skipped++; Write-Host "[SKIP] $dest"; continue }
    if ($want -eq $null -and (Get-Item $dest).Length -gt 0) { $skipped++; Write-Host "[SKIP] $dest (exists)"; continue }
    Remove-Item $dest -Force
  }
  & $IDM /d $url /p $dir /f $file /n /s 2>$null
  $queued++
  Start-Sleep -Milliseconds 500
}
Write-Host "[idm-batch] queued $queued, skipped $skipped"

if (-not $Wait) {
  Write-Host "[idm-batch] queued in IDM (run with -Wait to poll completion)"
  exit 0
}

# wait for all tasks
$t0 = Get-Date
$lastSizes = @{}
$stable = @{}
while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  Start-Sleep -Seconds 10
  $done = 0
  foreach ($t in $tasks) {
    $dir = $t[1]; $file = $t[2]
    $dest = Join-Path $dir $file
    $want = $shaMap[$dest]
    if (-not (Test-Path $dest)) { continue }
    $sz = (Get-Item $dest).Length
    if ($sz -eq 0) { continue }
    $valid = $true
    if ($want -ne $null) { $valid = ((Get-Sha1 $dest) -eq $want) }
    if ($valid) { $done++ }
    else {
      if ($lastSizes[$dest] -eq $sz) { $stable[$dest] = ($stable[$dest] -as [int]) + 1 } else { $stable[$dest] = 0 }
      if (($stable[$dest] -as [int]) -ge 3) {
        Write-Host "[WARN] size stable but sha1 mismatch (30s): $dest - will keep waiting, check URL"
      }
    }
    $lastSizes[$dest] = $sz
  }
  if ($done -eq $tasks.Count) { Write-Host "[DONE] all $done tasks completed in $([math]::Round(((Get-Date)-$t0).TotalSeconds))s"; exit 0 }
}
Write-Host "[FAIL] timeout after $TimeoutSec s, completed $done/$($tasks.Count)"
exit 1
