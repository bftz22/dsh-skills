# log-entry.ps1 — 向交接日志追加一条结构化记录（Markdown + JSONL 双写）
# 用法：powershell -File log-entry.ps1 -Task "一句话任务" [-Detail "详情" -Files "文件1, 文件2" -Issues "问题" -Pending "待办"]
# 兼容 PS 5.1 / 7；只追加，不删除任何内容；写入前自动按月归档历史日志（archive-logs.ps1，P1-① 2026-08-19）
param(
  [Parameter(Mandatory = $true)][string]$Task,
  [string]$Detail = '',
  [string]$Files  = '',
  [string]$Issues = '',
  [string]$Pending = ''
)

$ErrorActionPreference = 'Continue'

# ---- 路径解析：F 优先 D 兜底；优先新版子文件夹结构，兼容旧版平铺 ----
$base = $null
foreach ($b in @('{ARCHIVE}', '{DOWNLOADS}\AI交接指南')) {
  if (Test-Path $b) { $base = $b; break }
}
if (-not $base) { $base = '{DOWNLOADS}\AI交接指南' }
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

# ---------- 按月归档（P1-① 2026-08-19 主公拍板）：早于当月的日志移入 99_归档\交接日志归档 ----------
$me = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $me 'archive-logs.ps1') | Out-Null

# ---------- 详情长度强制（P0 2026-08-19 主公拍板）：超 200 字拒绝写入 ----------
if ($Detail.Length -gt 200) {
  Write-Error ("详情 {0} 字符，超过 200 字上限，已拒绝写入。请精简为：做了什么+结果+关键证据；详细过程放 04_报告。" -f $Detail.Length)
  exit 1
}

# ---------- 同任务 10 分钟内重复条目自动合并（P0 2026-08-19） ----------
# 合并规则：与最后一条记录任务名相同且时间差 <= 10 分钟时，把本条并入最后一条
# （详情/文件/问题/待办拼接，保留原时间戳），避免同一事故刷多条日志
if (Test-Path $jsonlFile) {
  $allLines = @([System.IO.File]::ReadAllLines($jsonlFile, $utf8) | Where-Object { $_.Trim() -ne '' })
  if ($allLines.Count -gt 0) {
    try {
      $last = $allLines[-1] | ConvertFrom-Json
      $lastTask = [string]$last.task
      $lastTs = [datetime]::ParseExact([string]$last.ts, 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
      $sameTask = $lastTask.Trim().Equals($Task.Trim(), [StringComparison]::OrdinalIgnoreCase)
      $within10 = (($now - $lastTs).TotalMinutes -le 10)
      if ($sameTask -and $within10) {
        $mergedDetail = [string]$last.detail
        if ($Detail) { $mergedDetail = if ($mergedDetail) { $mergedDetail + '；' + $Detail } else { $Detail } }
        if ($Files)   { $Files   = if ([string]$last.files)   { [string]$last.files + ';' + $Files }   else { $Files } }
        if ($Issues)  { $Issues  = if ([string]$last.issues)  { [string]$last.issues + '；' + $Issues }  else { $Issues } }
        if ($Pending) { $Pending = if ([string]$last.pending) { [string]$last.pending + '；' + $Pending } else { $Pending } }
        $Task = $lastTask
        $Detail = $mergedDetail
        $ts = [string]$last.ts
        $session = [string]$last.session
        # 截掉 md / jsonl 的最后一条，稍后以合并内容重新追加
        if (Test-Path $mdFile) {
          $mdAll = [System.IO.File]::ReadAllText($mdFile, $utf8)
          $idx = $mdAll.LastIndexOf("`n## ")
          if ($idx -ge 0) {
            [System.IO.File]::WriteAllText($mdFile, $mdAll.Substring(0, $idx + 1), $utf8)
          }
        }
        if ($allLines.Count -gt 1) {
          $jsonlText = ($allLines[0..($allLines.Count - 2)] -join "`r`n")
          [System.IO.File]::WriteAllText($jsonlFile, $jsonlText, $utf8)
        } else {
          [System.IO.File]::WriteAllText($jsonlFile, '', $utf8)
        }
        Write-Output "[合并] 与 10 分钟内同任务记录合并（保留原时间戳）"
      }
    } catch {
      Write-Output "[提示] 合并检查失败，按新条目追加: $($_.Exception.Message)"
    }
  }
}

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
