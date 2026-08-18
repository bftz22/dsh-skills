# brief.ps1 — 交接简报：让接手 AI 快速了解机器与服务现状
# 用法：powershell -File brief.ps1
# 输出：控制台简报 + 保存 F:\AI交接指南\简报-<时间>.md
# 兼容 PS 5.1 / 7；只读，不改任何文件
$ErrorActionPreference = 'Continue'

# 自动探测交接指南目录（F 优先 D 兜底；优先新版子文件夹结构，兼容旧版平铺）
$base = $null
foreach ($b in @('F:\AI交接指南', 'D:\下载\AI交接指南')) {
  if (Test-Path $b) { $base = $b; break }
}
if (-not $base) {
  Write-Output 'ERR: 未找到交接指南目录（F:\AI交接指南 或 D:\下载\AI交接指南）'
  exit 1
}
if (Test-Path (Join-Path $base '00_主指南\AI交接指南-2026-08-16.md')) {
  $guide = Join-Path $base '00_主指南\AI交接指南-2026-08-16.md'
} elseif (Test-Path (Join-Path $base 'AI交接指南-2026-08-16.md')) {
  $guide = Join-Path $base 'AI交接指南-2026-08-16.md'
} else {
  Write-Output "ERR: 未找到主指南文件（$base）"
  exit 1
}
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

# ---------- 廷议·待主公拍板（2026-08-19 主公确立：开场必报） ----------
Add-Line "## 2. 廷议·待主公拍板（任务清单.md）"
Add-Line ""
$taskMd = Join-Path $base '06_贤臣档案\任务清单.md'
if (Test-Path $taskMd) {
  $tl = [System.IO.File]::ReadAllLines($taskMd, $utf8)
  $inYan = $false
  $found = $false
  foreach ($ln in $tl) {
    if ($ln -match '^## .*廷议') { $inYan = $true; $found = $true; continue }
    if ($inYan -and $ln -match '^## ') { break }
    if ($inYan -and $ln.Trim() -ne '') { Add-Line $ln }
  }
  if (-not $found) { Add-Line "（任务清单.md 中未找到廷议区）" }
} else { Add-Line "（未找到任务清单.md）" }
Add-Line ""

# ---------- 快捷指令（贤臣第 4 层 2026-08-19 主公确立：一句话出报） ----------
Add-Line "## 2.1 快捷指令（主公一句话出报）"
Add-Line ""
$cmdMd = 'F:\朝堂档案\10_内侍省·通传\快捷指令.md'
if (Test-Path $cmdMd) {
  ([System.IO.File]::ReadAllLines($cmdMd, $utf8) | Select-Object -First 30) | ForEach-Object { Add-Line $_ }
} else { Add-Line "（未找到快捷指令.md）" }
Add-Line ""

Add-Line "## 3. AI 操作守则（指南第 6 节）"
Add-Line ""
(Get-Section '## 6. AI 操作守则*') | ForEach-Object { Add-Line $_ }
Add-Line ""

Add-Line "## 4. 已知问题与待办（指南第 5 节）"
Add-Line ""
(Get-Section '## 5. 已知问题与待办*') | ForEach-Object { Add-Line $_ }
Add-Line ""

# ---------- 最近状态快照 ----------
Add-Line "## 5. 最近状态快照"
Add-Line ""
$snap = Get-ChildItem $snapDir -Filter '状态快照-*.md' -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($snap) {
  Add-Line "（来源：$($snap.Name)；历史快照与完整版见指南第 8 节）"
  Add-Line ""
  ([System.IO.File]::ReadAllLines($snap.FullName, $utf8) | Select-Object -First 40) | ForEach-Object { Add-Line $_ }
} else {
  Add-Line "（暂无快照，可先运行 update-guide.ps1 生成）"
}
Add-Line ""

# ---------- 最近交接日志 ----------
Add-Line "## 6. 最近交接日志（5 条）"
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
Add-Line "## 7. 实时状态（采集时刻）"
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

# ---------- 自动归档旧简报（仅保留最新 1 份，2026-08-18 整理优化） ----------
$arcBrief = Join-Path $base '99_归档\简报归档'
if (-not (Test-Path $arcBrief)) { New-Item -ItemType Directory -Force -Path $arcBrief | Out-Null }
Get-ChildItem $briefDir -File -Filter '简报-*.md' | Where-Object { $_.FullName -ne $briefFile } | ForEach-Object {
  Move-Item $_.FullName (Join-Path $arcBrief $_.Name) -Force
}
