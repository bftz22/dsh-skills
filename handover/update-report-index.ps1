# ============================================================
# update-report-index.ps1 - 报告索引自动生成 (2026-08-19 P0)
# 扫描 04_报告 子目录, 生成 INDEX.md (任务/文件/时间/大小)
# 用法: powershell -File update-report-index.ps1
# 注意: 本脚本含中文, 必须 UTF-8 带 BOM (PS 5.1 按 GBK 读无 BOM 文件会解析失败)
#       生成的 INDEX.md 为 .md, 用 UTF-8 无 BOM 即可
# ============================================================
$ErrorActionPreference = 'Stop'
$reportRoot = '{ARCHIVE}\04_报告'
$indexPath = Join-Path $reportRoot 'INDEX.md'

$files = Get-ChildItem -LiteralPath $reportRoot -Recurse -File -Filter '*.md' |
  Where-Object { $_.Name -ne 'INDEX.md' } |
  Sort-Object FullName

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# 报告索引（自动生成，勿手改）')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> 生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' · 由 update-report-index.ps1 自动生成 · 共 ' + $files.Count + ' 份报告')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| 任务 | 文件 | 时间 | 大小 |')
[void]$sb.AppendLine('|---|---|---|---|')
foreach ($f in $files) {
  $task = $f.Directory.Name
  $size = if ($f.Length -ge 1MB) { '{0:N1} MB' -f ($f.Length / 1MB) }
          elseif ($f.Length -ge 1KB) { '{0:N1} KB' -f ($f.Length / 1KB) }
          else { "$($f.Length) B" }
  $time = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
  $link = $f.FullName -replace '\\', '/'
  [void]$sb.AppendLine(('| {0} | [{1}]({2}) | {3} | {4} |' -f $task, $f.Name, $link, $time, $size))
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> 命名规范：`任务名-YYYYMMDD-HHMMSS.md`；新报告请存 `04_报告\<任务名>\` 子目录，旧报告沿用原文件名。')
[IO.File]::WriteAllText($indexPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ('报告索引已生成: ' + $indexPath + ' (共 ' + $files.Count + ' 份)')
