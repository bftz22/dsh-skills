# idm-download.ps1 - download a single file via IDM with optional sha1 verify
# usage: powershell -File idm-download.ps1 -Url "https://..." [-Dir "D:\download"] [-File "name.jar"] [-Sha1 "hex"] [-TimeoutSec 900]
param(
  [Parameter(Mandatory = $true)][string]$Url,
  [string]$Dir = "",
  [string]$File = "",
  [string]$Sha1 = "",
  [int]$TimeoutSec = 900
)

# resolve IDM path: env IDM_PATH > common install locations
$IDM = $env:IDM_PATH
if (-not $IDM) {
  $candidates = @(
    "$env:ProgramFiles\Internet Download Manager\IDMan.exe",
    "${env:ProgramFiles(x86)}\Internet Download Manager\IDMan.exe",
    "$env:LOCALAPPDATA\Programs\Internet Download Manager\IDMan.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { $IDM = $c; break } }
}
if (-not $IDM) { Write-Host "[FAIL] IDM not found. Set env IDM_PATH to IDMan.exe full path."; exit 1 }
if ($Dir -eq "") { $Dir = "$env:USERPROFILE\Downloads" }
$ErrorActionPreference = "Stop"

function Get-Sha1($path) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $fs = [System.IO.File]::OpenRead($path)
  try { $hash = $sha.ComputeHash($fs) } finally { $fs.Close() }
  return ([BitConverter]::ToString($hash)).Replace("-", "").ToLower()
}

# resolve target file name
if ($File -eq "") {
  $File = $Url.Split("/")[-1]
  if ($File -match "\?") { $File = $File.Split("?")[0] }
}
$dest = Join-Path $Dir $File

# ensure IDM running
if (-not (Get-Process -Name "IDMan" -ErrorAction SilentlyContinue)) {
  Write-Host "[idm] starting IDM..."
  Start-Process $IDM | Out-Null
  Start-Sleep -Seconds 8
  if (-not (Get-Process -Name "IDMan" -ErrorAction SilentlyContinue)) {
    Write-Host "[FAIL] IDM did not start: $IDM"
    exit 1
  }
}

# skip if already present and valid
if (Test-Path $dest) {
  if ($Sha1 -ne "") {
    $cur = Get-Sha1 $dest
    if ($cur -eq $Sha1.ToLower()) { Write-Host "[SKIP] exists and sha1 match: $dest"; exit 0 }
    Write-Host "[idm] existing file sha1 mismatch ($cur), re-download"
    Remove-Item $dest -Force
  } else {
    if ((Get-Item $dest).Length -gt 0) { Write-Host "[SKIP] exists (size>0, no sha1 given): $dest"; exit 0 }
    Remove-Item $dest -Force
  }
}

# queue to IDM
Write-Host "[idm] queue: $Url -> $dest"
& $IDM /d $Url /p $Dir /f $File /n /s 2>$null
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
  Write-Host "[idm] IDM queue returned exit $LASTEXITCODE (continue waiting)"
}

# wait for completion
$t0 = Get-Date
$lastSize = -1
$stable = 0
while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  Start-Sleep -Seconds 10
  if (Test-Path $dest) {
    $sz = (Get-Item $dest).Length
    if ($sz -eq $lastSize -and $sz -gt 0) { $stable++; } else { $stable = 0 }
    if ($stable -ge 3) { break }  # size stable for 30s -> done
    $lastSize = $sz
  }
}

if (-not (Test-Path $dest)) {
  Write-Host "[FAIL] file not found after $TimeoutSec s: $dest"
  exit 1
}
$size = (Get-Item $dest).Length
if ($size -eq 0) {
  Write-Host "[FAIL] file is 0 bytes: $dest"
  exit 1
}

# verify sha1 with retries
if ($Sha1 -ne "") {
  $want = $Sha1.ToLower()
  for ($try = 1; $try -le 3; $try++) {
    $cur = Get-Sha1 $dest
    if ($cur -eq $want) { Write-Host "[OK] sha1 match ($cur) - $dest ($size bytes)"; exit 0 }
    Write-Host "[idm] sha1 mismatch attempt $try/3: got $cur want $want - retry download"
    Remove-Item $dest -Force
    & $IDM /d $Url /p $Dir /f $File /n /s 2>$null
    Start-Sleep -Seconds 30
  }
  Write-Host "[FAIL] sha1 still mismatch after retries: $dest"
  exit 1
}

Write-Host "[OK] downloaded: $dest ($size bytes)"
