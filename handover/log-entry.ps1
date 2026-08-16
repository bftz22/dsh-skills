# log-entry.ps1 — 向交接日志追加一条结构化记录（Markdown + JSONL 双写）
# 用法：powershell -File log-entry.ps1 -Task "一句话任务" [-Detail "详情" -Files "文件1, 文件2" -Issues "问题" -Pending "待办"]
# 兼容 PS 5.1 / 7；只追加，不删除任何内容
param(
  [Parameter(Mandatory = $true)][string]$Task,
  [string]$Detail = '',
  [string]$Files  = '',
  [string]$Issues = '',
  [string]$Pending = ''
)

$ErrorActionPreference = 'Continue'

# ---- 路径解析：HANDOVER_DIR 优先，D:/C 兜底；优先新版子文件夹结构，兼容旧版平铺 ----
$base = $null
foreach ($b in @($env:HANDOVER_DIR, 'D:\AI交接指南', 'C:\AI交接指南')) {
  if ($b -and (Test-Path $b)) { $base = $b; break }
}
if (-not $base) {
  Write-Output 'ERR: 未找到交接指南目录（请设置环境变量 HANDOVER_DIR）'
  exit 1
}
if (Test-Path (Join-Path $base '01_交接日志')) {
  $logDir = Join-Path $base '01_交接日志'
} else {
  $logDir = $base
}
$mdFile  = Join-Path $logDir '交接日志.md'
$jsonlFile = Join-Path $logDir '交接日志.jsonl'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$now = Get-Date
$session = if ($env:DSH_SESSION_ID) { $env:DSH_SESSION_ID } else { 'unknown' }
$ts = $now.ToString('yyyy-MM-dd HH:mm:ss')

# ---------- Markdown 追加 ----------
$mdEntry = @"
## $ts（会话 $session）

- **任务**：$Task
- **详情**：$Detail
- **变更文件**：$Files
- **问题**：$Issues
- **待办**：$Pending

"@

if (-not (Test-Path $mdFile)) {
  $mdHead = "# 交接日志`r`n`r`n> 由 skills\handover\log-entry.ps1 自动追加，只增不改。`r`n`r`n"
  [System.IO.File]::WriteAllText($mdFile, $mdHead, $utf8)
}
[System.IO.File]::AppendAllText($mdFile, $mdEntry, $utf8)

# ---------- JSONL 追加 ----------
$json = @{
  ts      = $ts
  session = $session
  task    = $Task
  detail  = $Detail
  files   = $Files
  issues  = $Issues
  pending = $Pending
} | ConvertTo-Json -Compress
[System.IO.File]::AppendAllText($jsonlFile, $json + "`r`n", $utf8)

Write-Output "OK: 已写入交接日志 ($mdFile / $jsonlFile)"
