# archive-logs.ps1 - 交接日志按月归档（朝政体系 P1-① 2026-08-19 主公拍板）
# 用法：powershell -File archive-logs.ps1 [-Base "F:\AI交接指南"]（Base 缺省自动探测）
# 作用：把 交接日志.md / 交接日志.jsonl 中"早于当月"的历史条目按月移入
#       99_归档\交接日志归档\YYYY-MM\，主文件只保留当月条目保持轻量；归档文件只增不改。
# 兼容 PS 5.1 / 7；只读写交接指南目录，无任何危险操作
param(
  [string]$Base = ''
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 路径解析：-Base 优先，否则 F 优先 D 兜底；优先新版子文件夹结构 ----
if (-not $Base) {
  foreach ($b in @('F:\AI交接指南', 'D:\下载\AI交接指南')) {
    if (Test-Path $b) { $Base = $b; break }
  }
}
if (-not $Base) { Write-Output 'ERR: 未找到交接指南目录（F:\AI交接指南 或 D:\下载\AI交接指南）'; exit 1 }
if (Test-Path (Join-Path $Base '01_交接日志')) {
  $logDir = Join-Path $Base '01_交接日志'
} else {
  $logDir = $Base
}
$mdFile    = Join-Path $logDir '交接日志.md'
$jsonlFile = Join-Path $logDir '交接日志.jsonl'

$nowMonth = (Get-Date).ToString('yyyy-MM')

function Get-MonthOfTs([string]$ts) {
  # 从 "yyyy-MM-dd HH:mm:ss" 时间戳取月
  if ($ts -match '^(\d{4}-\d{2})-\d{2}') { return $Matches[1] }
  return ''
}

# ---------- JSONL 归档：早于当月的行按月份分组 ----------
$jsonlArchive = @{}
if (Test-Path $jsonlFile) {
  $lines = @([System.IO.File]::ReadAllLines($jsonlFile, $utf8) | Where-Object { $_.Trim() -ne '' })
  $keep = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    $m = ''
    try { $d = $ln | ConvertFrom-Json; $m = Get-MonthOfTs ([string]$d.ts) } catch {}
    if ($m -and $m -lt $nowMonth) {
      if (-not $jsonlArchive.ContainsKey($m)) { $jsonlArchive[$m] = New-Object System.Collections.Generic.List[string] }
      $jsonlArchive[$m].Add($ln)
    } else {
      $keep.Add($ln)
    }
  }
  if ($jsonlArchive.Count -gt 0) {
    [System.IO.File]::WriteAllText($jsonlFile, ($keep -join "`r`n"), $utf8)
  }
}

# ---------- Markdown 归档：按 "## yyyy-MM-dd" 块切分 ----------
$mdArchive = @{}
if (Test-Path $mdFile) {
  $mdLines = [System.IO.File]::ReadAllLines($mdFile, $utf8)
  $head = New-Object System.Collections.Generic.List[string]   # 首个 ## 之前的文件头（保留在主文件）
  $curBlock = $null
  $curMonth = ''
  $keepBlocks = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $mdLines) {
    if ($ln -match '^## (\d{4}-\d{2})-\d{2}') {
      # 新块开始：先结算上一块
      if ($null -ne $curBlock) {
        $blockText = $curBlock -join "`r`n"
        if ($curMonth -and $curMonth -lt $nowMonth) {
          if (-not $mdArchive.ContainsKey($curMonth)) { $mdArchive[$curMonth] = New-Object System.Collections.Generic.List[string] }
          $mdArchive[$curMonth].Add($blockText)
        } else {
          $keepBlocks.Add($blockText)
        }
      }
      $curBlock = New-Object System.Collections.Generic.List[string]
      $curMonth = $Matches[1]
      $curBlock.Add($ln)
    } elseif ($null -ne $curBlock) {
      $curBlock.Add($ln)
    } else {
      $head.Add($ln)
    }
  }
  # 结算最后一块
  if ($null -ne $curBlock) {
    $blockText = $curBlock -join "`r`n"
    if ($curMonth -and $curMonth -lt $nowMonth) {
      if (-not $mdArchive.ContainsKey($curMonth)) { $mdArchive[$curMonth] = New-Object System.Collections.Generic.List[string] }
      $mdArchive[$curMonth].Add($blockText)
    } else {
      $keepBlocks.Add($blockText)
    }
  }
  if ($mdArchive.Count -gt 0) {
    $newMd = ($head -join "`r`n")
    if ($newMd -and -not $newMd.EndsWith("`r`n")) { $newMd += "`r`n" }
    if ($keepBlocks.Count -gt 0) { $newMd += ($keepBlocks -join "`r`n`r`n") + "`r`n" }
    [System.IO.File]::WriteAllText($mdFile, $newMd, $utf8)
  }
}

# ---------- 写归档文件（追加，不覆盖） ----------
$done = @()
$arcRoot = Join-Path $Base '99_归档\交接日志归档'
$hasAny = ($jsonlArchive.Count -gt 0 -or $mdArchive.Count -gt 0)
if ($hasAny -and -not (Test-Path $arcRoot)) { New-Item -ItemType Directory -Force -Path $arcRoot | Out-Null }

foreach ($m in ($jsonlArchive.Keys | Sort-Object)) {
  $dir = Join-Path $arcRoot $m
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $f = Join-Path $dir ("交接日志-" + $m + '.jsonl')
  $content = $jsonlArchive[$m] -join "`r`n"
  if ((Test-Path $f) -and ([System.IO.File]::ReadAllText($f, $utf8).Trim() -ne '')) { $content = "`r`n" + $content }
  [System.IO.File]::AppendAllText($f, $content + "`r`n", $utf8)
  $done += $m + '.jsonl'
}

foreach ($m in ($mdArchive.Keys | Sort-Object)) {
  $dir = Join-Path $arcRoot $m
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $f = Join-Path $dir ("交接日志-" + $m + '.md')
  if (-not (Test-Path $f)) {
    [System.IO.File]::WriteAllText($f, "# 交接日志归档 " + $m + "`r`n`r`n> 由 skills\handover\archive-logs.ps1 按月自动归档，只增不改。`r`n`r`n", $utf8)
  }
  [System.IO.File]::AppendAllText($f, ($mdArchive[$m] -join "`r`n`r`n") + "`r`n`r`n", $utf8)
  $done += $m + '.md'
}

if ($hasAny) {
  Write-Output ("OK: 已归档 {0} 项 -> {1}" -f $done.Count, $arcRoot)
  $done | ForEach-Object { Write-Output ('  - ' + $_) }
} else {
  Write-Output "OK: 无早于当月的日志，无需归档（主文件保留当月条目）"
}
