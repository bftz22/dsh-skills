# update-guide.ps1 — 刷新 AI 交接指南的状态快照段 + 生成带时间戳快照文件
# 用法：powershell -File update-guide.ps1
# 兼容 PS 5.1 / 7；只读写交接指南目录（HANDOVER_DIR 优先），无任何危险操作
$ErrorActionPreference = 'Continue'

# 自动探测指南目录（HANDOVER_DIR 优先，D:/C 兜底；优先新版子文件夹结构，兼容旧版平铺）
function Find-HandoverBase {
  foreach ($b in @($env:HANDOVER_DIR, 'D:\AI交接指南', 'C:\AI交接指南')) {
    if ($b -and (Test-Path $b)) { return $b }
  }
  return $null
}
$base = Find-HandoverBase
if (-not $base) {
  Write-Output 'ERR: 未找到交接指南目录（请设置环境变量 HANDOVER_DIR）'
  exit 1
}
$guide = Get-ChildItem $base -Recurse -Filter 'AI交接指南-*.md' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $guide) {
  Write-Output "ERR: 未找到主指南文件（$base）"
  exit 1
}
$guide = $guide.FullName
if (Test-Path (Join-Path $base '03_状态快照')) {
  $snapDir = Join-Path $base '03_状态快照'
} else {
  $snapDir = $base
}
$utf8   = New-Object System.Text.UTF8Encoding($false)

# 服务日志与工作流路径（可用环境变量覆盖）
$bridgeLog = $env:BRIDGE_LOG;      if (-not $bridgeLog) { $bridgeLog = 'C:\deepseek-harness\bridge.log' }
$comfyLog  = $env:COMFYUI_LOG;     if (-not $comfyLog)  { $comfyLog  = 'C:\ComfyUI\user\comfyui.log' }
$wfDir     = $env:COMFYUI_WORKFLOWS; if (-not $wfDir)   { $wfDir     = 'C:\ComfyUI\user\default\workflows' }

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
$bridge = Test-Http 'http://127.0.0.1:8787/v1/models'
$comfy  = Test-Http 'http://127.0.0.1:8188/system_stats'

$procs = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -match 'node|python|guard|cmd' -and $_.CommandLine -match 'server\.mjs|main\.py|guard\.exe|watchdog'
}
$pBridge = ($procs | Where-Object { $_.CommandLine -match 'server\.mjs' } | Select-Object -First 1).ProcessId
$pComfy  = ($procs | Where-Object { $_.CommandLine -match 'main\.py' } | Select-Object -First 1).ProcessId
$pGuard  = ($procs | Where-Object { $_.CommandLine -match 'guard\.exe' } | Select-Object -First 1).ProcessId
$pWatch  = ($procs | Where-Object { $_.CommandLine -match 'watchdog' } | Select-Object -First 1).ProcessId

Add-Line ("| 服务 | 状态 | PID |")
Add-Line ("|---|---|---|")
Add-Line ("| dsh-openai-bridge (8787) | $bridge | $pBridge |")
Add-Line ("| ComfyUI (8188) | $comfy | $pComfy |")
Add-Line ("| guard 安全闸门 | $([int]($null -ne $pGuard)) | $pGuard |")
Add-Line ("| watchdog 看门狗 | $([int]($null -ne $pWatch)) | $pWatch |")

# ---------- ComfyUI 队列 ----------
try {
  $q = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/queue' -TimeoutSec 3
  Add-Line ("- ComfyUI 队列：运行 {0} / 待办 {1}" -f @($q.queue_running).Count, @($q.queue_pending).Count)
} catch { Add-Line "- ComfyUI 队列：无法获取" }

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
  @{ N = 'bridge.log'; P = $bridgeLog },
  @{ N = 'comfyui.log'; P = $comfyLog }
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
if (Test-Path $wfDir) {
  Get-ChildItem $wfDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object {
    Add-Line ("- {0}（{1:MM-dd HH:mm}）" -f $_.Name, $_.LastWriteTime)
  }
} else { Add-Line "- 工作流目录不存在" }

$snapshot = $sb.ToString()

# ---------- 写回指南标记区（只动标记区） ----------
$startTag = '<!-- SNAPSHOT:START -->'
$endTag   = '<!-- SNAPSHOT:END -->'
$content = [System.IO.File]::ReadAllText($guide, $utf8)
$si = $content.IndexOf($startTag)
$ei = $content.IndexOf($endTag)
if ($si -ge 0 -and $ei -gt $si) {
  $head = $content.Substring(0, $si + $startTag.Length)
  $tail = $content.Substring($ei)
  $newContent = $head + "`r`n" + $snapshot + "`r`n" + $tail
  [System.IO.File]::WriteAllText($guide, $newContent, $utf8)
  Write-Output "OK: 指南状态快照已刷新 ($guide)"
} else {
  Write-Output "WARN: 指南中未找到快照标记，跳过写入（请先在指南中放置 $startTag ... $endTag 标记段）"
}

# ---------- 生成带时间戳快照文件（保留历史） ----------
$snapFile = Join-Path $snapDir ("状态快照-" + $now.ToString('yyyyMMdd-HHmm') + '.md')
$header = "# 状态快照 $($now.ToString('yyyy-MM-dd HH:mm'))`r`n`r`n"
[System.IO.File]::WriteAllText($snapFile, $header + $snapshot, $utf8)
Write-Output "OK: 快照文件已生成 ($snapFile)"
