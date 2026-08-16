# brief.ps1 — 交接简报：让接手 AI 快速了解机器与服务现状
# 用法：powershell -File brief.ps1
# 输出：控制台简报 + 保存 <HANDOVER_DIR>\02_简报\简报-<时间>.md
# 兼容 PS 5.1 / 7；只读，不改任何文件
$ErrorActionPreference = 'Continue'

# 自动探测交接指南目录（HANDOVER_DIR 优先，D:/C 兜底；优先新版子文件夹结构，兼容旧版平铺）
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
$logDir   = if (Test-Path (Join-Path $base '01_交接日志')) { Join-Path $base '01_交接日志' } else { $base }
$briefDir = if (Test-Path (Join-Path $base '02_简报')) { Join-Path $base '02_简报' } else { $base }
$snapDir  = if (Test-Path (Join-Path $base '03_状态快照')) { Join-Path $base '03_状态快照' } else { $base }
$utf8 = New-Object System.Text.UTF8Encoding($false)

$sb = New-Object System.Text.StringBuilder
function Add-Line($t) { [void]$sb.AppendLine($t) }
$now = Get-Date

Add-Line "# 交接简报 $($now.ToString('yyyy-MM-dd HH:mm'))"
Add-Line ""
Add-Line "> 生成：skills\handover\brief.ps1 · 完整指南：$guide"
Add-Line ""

# ---------- 提取指南指定章节（## N. 标题 到 下一个 ##） ----------
function Get-Section([string]$startMatch) {
  $lines = [System.IO.File]::ReadAllLines($guide, $utf8)
  $si = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like $startMatch) { $si = $i; break }
  }
  if ($si -lt 0) { return @('（未找到该章节）') }
  $out = @()
  for ($i = $si + 1; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^## ') { break }
    $out += $lines[$i]
  }
  return $out
}

Add-Line "## 1. 本机速查（指南第 0 节）"
Add-Line ""
(Get-Section '## 0. 本机速查表*') | ForEach-Object { Add-Line $_ }
Add-Line ""

Add-Line "## 2. AI 操作守则（指南第 6 节）"
Add-Line ""
(Get-Section '## 6. AI 操作守则*') | ForEach-Object { Add-Line $_ }
Add-Line ""

Add-Line "## 3. 已知问题与待办（指南第 5 节）"
Add-Line ""
(Get-Section '## 5. 已知问题与待办*') | ForEach-Object { Add-Line $_ }
Add-Line ""

# ---------- 最近状态快照 ----------
Add-Line "## 4. 最近状态快照"
Add-Line ""
$snap = Get-ChildItem $snapDir -Filter '状态快照-*.md' -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($snap) {
  Add-Line "（来源：$($snap.Name)；历史快照与完整版见指南状态快照段）"
  Add-Line ""
  ([System.IO.File]::ReadAllLines($snap.FullName, $utf8) | Select-Object -First 40) | ForEach-Object { Add-Line $_ }
} else {
  Add-Line "（暂无快照，可先运行 update-guide.ps1 生成）"
}
Add-Line ""

# ---------- 最近交接日志 ----------
Add-Line "## 5. 最近交接日志（5 条）"
Add-Line ""
$jsonl = Join-Path $logDir '交接日志.jsonl'
if (Test-Path $jsonl) {
  ([System.IO.File]::ReadAllLines($jsonl, $utf8) | Select-Object -Last 5) | ForEach-Object {
    try { $d = $_ | ConvertFrom-Json; Add-Line ("- {0} | {1}" -f $d.ts, $d.task) }
    catch { Add-Line ("- (无法解析) {0}" -f $_) }
  }
} else { Add-Line "（暂无日志）" }
Add-Line ""

# ---------- 实时状态 ----------
Add-Line "## 6. 实时状态（采集时刻）"
Add-Line ""
function Test-Http([string]$u) {
  try { $null = Invoke-WebRequest -Uri $u -TimeoutSec 3 -UseBasicParsing; return 'OK' }
  catch { return 'DOWN' }
}
$bridge = Test-Http 'http://127.0.0.1:8787/v1/models'
$comfy  = Test-Http 'http://127.0.0.1:8188/system_stats'
Add-Line "- dsh-openai-bridge (8787)：$bridge"
Add-Line "- ComfyUI (8188)：$comfy"
try {
  $q = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/queue' -TimeoutSec 3
  Add-Line ("- ComfyUI 队列：运行 {0} / 待办 {1}" -f @($q.queue_running).Count, @($q.queue_pending).Count)
} catch { Add-Line '- ComfyUI 队列：无法获取' }
Get-PSDrive -PSProvider FileSystem | Sort-Object Name | ForEach-Object {
  Add-Line ("- {0}: 盘可用 {1} GB" -f $_.Name, [math]::Round($_.Free / 1GB, 1))
}

$out = $sb.ToString()
$briefFile = Join-Path $briefDir ("简报-" + $now.ToString('yyyyMMdd-HHmm') + '.md')
[System.IO.File]::WriteAllText($briefFile, $out, $utf8)
Write-Output $out
Write-Output "OK: 简报已保存 ($briefFile)"
