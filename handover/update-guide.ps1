# update-guide.ps1 — 生成带时间戳的状态快照文件（P1-② 2026-08-19 宿主拍板：主指南不再被自动改写）
# 用法：powershell -File update-guide.ps1
# 兼容 PS 5.1 / 7；只读写交接指南目录（自动探测 {ARCHIVE} 优先，{DOWNLOADS}\AI交接指南 兜底），无任何危险操作
$ErrorActionPreference = 'Continue'

# 自动探测指南目录（F 优先 D 兜底；优先新版子文件夹结构，兼容旧版平铺）
$base = $null
foreach ($b in @('{ARCHIVE}', '{DOWNLOADS}\AI交接指南')) {
  if (Test-Path $b) { $base = $b; break }
}
# 都没有：自动创建目录骨架（HANDOVER_DIR 环境变量优先，其次 F 盘）
if (-not $base) {
  $base = $env:HANDOVER_DIR
  if (-not $base) { $base = '{ARCHIVE}' }
  Write-Output "INFO: 未找到交接指南目录，自动创建：$base"
  foreach ($d in @('00_主指南', '01_交接日志', '02_简报', '03_状态快照', '04_报告', '06_政务大臣档案')) {
    $p = Join-Path $base $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  }
}
# 主指南不再被本脚本改写（P1-② 2026-08-19 宿主拍板）：仅确保文件存在，缺失时创建最小占位
$guide = Join-Path $base '00_主指南\AI交接指南-2026-08-16.md'
if (-not (Test-Path $guide) -and -not (Test-Path (Join-Path $base 'AI交接指南-2026-08-16.md'))) {
  $placeholder = @"
# AI 交接指南（自动初始化）

> 由 update-guide.ps1 自动创建（$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))）
> 状态快照见 03_状态快照\ 目录（由 update-guide.ps1 生成，主指南不再内嵌快照段）
"@
  [System.IO.File]::WriteAllText($guide, $placeholder, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output "INFO: 已创建主指南占位文件：$guide"
}
if (Test-Path (Join-Path $base '03_状态快照')) {
  $snapDir = Join-Path $base '03_状态快照'
} else {
  $snapDir = $base
}
$utf8   = New-Object System.Text.UTF8Encoding($false)

$now = Get-Date
$sb = New-Object System.Text.StringBuilder

function Add-Line($t) { [void]$sb.AppendLine($t) }

Add-Line "> 快照时间：$($now.ToString('yyyy-MM-dd HH:mm:ss'))（由 update-guide.ps1 自动生成，仅反映采集时刻）"
Add-Line ""

# ---------- 系统与运行时长 ----------
try {
  $os = Get-CimInstance Win32_OperatingSystem
  $up = (Get-Date) - $os.LastBootUpTime
  Add-Line ("- 开机：{0:yyyy-MM-dd HH:mm}（已运行 {1} 天 {2} 小时）" -f $os.LastBootUpTime, $up.Days, $up.Hours)
} catch { Add-Line "- 开机时间：获取失败" }

# ---------- 磁盘 ----------
Add-Line ""
Add-Line "### 磁盘空间"
Add-Line ""
Add-Line "| 盘 | 可用 | 备注 |"
Add-Line "|---|---|---|"
Get-PSDrive -PSProvider FileSystem | Sort-Object Name | ForEach-Object {
  $free = [math]::Round($_.Free / 1GB, 1)
  $note = if ($free -lt 20) { '⚠ 紧张' } elseif ($free -lt 60) { '偏紧' } else { '' }
  Add-Line ("| {0} | {1} GB | {2} |" -f $_.Name, $free, $note)
}

# ---------- 服务状态 ----------
Add-Line ""
Add-Line "### 服务状态"
Add-Line ""
function Test-Http([string]$u) {
  try { $r = Invoke-WebRequest -Uri $u -TimeoutSec 3 -UseBasicParsing; return "OK ($($r.StatusCode))" }
  catch { return "DOWN" }
}
$bridge = Test-Http 'http://127.0.0.1:<PORT_MAIN>/v1/models'
$comfyRaw = Test-Http 'http://127.0.0.1:8188/system_stats'
# 按需启动模式（2026-08-16 用户定）：ComfyUI 平时不常驻，DOWN 属正常
$comfy  = if ($comfyRaw -eq 'DOWN') { 'DOWN（按需启动，正常）' } else { $comfyRaw }

$procs = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -match 'node|python|guard|cmd' -and $_.CommandLine -match 'server\.mjs|main\.py|guard\.exe|watchdog'
}
$pBridge = ($procs | Where-Object { $_.CommandLine -match 'server\.mjs' } | Select-Object -First 1).ProcessId
$pComfy  = ($procs | Where-Object { $_.CommandLine -match 'main\.py' } | Select-Object -First 1).ProcessId
$pGuard  = ($procs | Where-Object { $_.CommandLine -match 'guard\.exe' } | Select-Object -First 1).ProcessId
$pWatch  = ($procs | Where-Object { $_.CommandLine -match 'watchdog' } | Select-Object -First 1).ProcessId

Add-Line ("| 服务 | 状态 | PID |")
Add-Line ("|---|---|---|")
Add-Line ("| dsh-openai-bridge (<PORT_MAIN>) | $bridge | $pBridge |")
Add-Line ("| ComfyUI (8188) | $comfy | $pComfy |")
Add-Line ("| guard 安全闸门 | $([int]($null -ne $pGuard)) | $pGuard |")
Add-Line ("| watchdog 看门狗 | $([int]($null -ne $pWatch)) | $pWatch |")

# ---------- ComfyUI 队列 ----------
try {
  $q = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/queue' -TimeoutSec 3
  Add-Line ("- ComfyUI 队列：运行 {0} / 待办 {1}" -f @($q.queue_running).Count, @($q.queue_pending).Count)
} catch { Add-Line "- ComfyUI 队列：未运行（按需启动，正常）" }

# ---------- 日志尾部 ----------
Add-Line ""
Add-Line "### 关键日志尾部"
Add-Line ""
# 日志被服务进程持续写入，用 FileShare.ReadWrite 才能读
function Read-Tail([string]$path, [int]$n) {
  try {
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
      $sr = New-Object System.IO.StreamReader($fs, $utf8)
      $lines = @()
      while (-not $sr.EndOfStream) { $lines += $sr.ReadLine() }
      $sr.Close()
      return (($lines | Select-Object -Last $n) -join ' | ')
    } finally { $fs.Dispose() }
  } catch {
    return ('读取失败: ' + $_.Exception.Message)
  }
}
foreach ($lg in @(
  @{ N = 'bridge.log'; P = '{WORKSPACE}\bridge.log' },
  @{ N = 'comfyui.log'; P = '{COMFYUI}\user\comfyui.log' }
)) {
  if (Test-Path $lg.P) {
    $tail = Read-Tail $lg.P 2
    if ($tail.Length -gt 200) { $tail = $tail.Substring($tail.Length - 200) }
    Add-Line ("- **{0}**（尾部）：{1}" -f $lg.N, $tail)
  } else {
    Add-Line ("- **{0}**：文件不存在" -f $lg.N)
  }
}

# ---------- 工作流与模型 ----------
Add-Line ""
Add-Line "### 工作流 / 模型（最近修改时间）"
Add-Line ""
$wfDir = '{COMFYUI}\user\default\workflows'
if (Test-Path $wfDir) {
  Get-ChildItem $wfDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object {
    Add-Line ("- {0}（{1:MM-dd HH:mm}）" -f $_.Name, $_.LastWriteTime)
  }
} else { Add-Line "- 工作流目录不存在" }

$snapshot = $sb.ToString()

# ---------- 生成带时间戳快照文件（保留历史） ----------
$snapFile = Join-Path $snapDir ("状态快照-" + $now.ToString('yyyyMMdd-HHmm') + '.md')
$header = "# 状态快照 $($now.ToString('yyyy-MM-dd HH:mm'))`r`n`r`n"
[System.IO.File]::WriteAllText($snapFile, $header + $snapshot, $utf8)
Write-Output "OK: 快照文件已生成 ($snapFile)"

# ---------- 自动归档旧快照（仅保留最新 1 份，2026-08-18 整理优化） ----------
$arcSnap = Join-Path $base '99_归档\状态快照归档'
if (-not (Test-Path $arcSnap)) { New-Item -ItemType Directory -Force -Path $arcSnap | Out-Null }
Get-ChildItem $snapDir -File -Filter '状态快照-*.md' | Where-Object { $_.FullName -ne $snapFile } | ForEach-Object {
  Move-Item $_.FullName (Join-Path $arcSnap $_.Name) -Force
}
