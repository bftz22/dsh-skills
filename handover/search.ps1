# search.ps1 - 跨库搜索：一键搜遍交接指南 + 朝堂档案（朝政体系 P1-③ 2026-08-19 宿主拍板）
# 用法：powershell -File search.ps1 -Keyword "关键词"
#       可选：-Dir "04_报告"（限定路径含该子串） -Since "2026-08-01" -Until "2026-08-31"（按文件修改时间）
#             -Max 30（每文件最多显示匹配行数，默认 30） -ListOnly（只列命中文件） -CaseSensitive（区分大小写）
# 兼容 PS 5.1 / 7；只读不写，无任何危险操作
param(
  [Parameter(Mandatory = $true)][string]$Keyword,
  [string]$Dir = '',
  [string]$Since = '',
  [string]$Until = '',
  [int]$Max = 30,
  [switch]$ListOnly,
  [switch]$CaseSensitive
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$gbk = [System.Text.Encoding]::GetEncoding(936)

# ---- 搜索范围：交接指南（日志/报告/政务大臣档案/归档）+ 朝堂档案全部门 ----
$roots = @('{ARCHIVE}', '{COURT_ARCHIVE}')
$exts  = @('.md', '.jsonl', '.txt', '.log', '.ps1', '.cmd', '.bat', '.mjs', '.js', '.json', '.csv', '.ini', '.yml', '.yaml')

# ---- 读文本：UTF-8 出现替换符则按 GBK 兜底（兼容 GBK 编码的旧文件） ----
function Read-Lines([string]$p) {
  $bytes = [System.IO.File]::ReadAllBytes($p)
  $s = $utf8.GetString($bytes)
  if ($s -match '\uFFFD') { $s = $gbk.GetString($bytes) }
  return ($s -split "`r?`n")
}

$cmp = if ($CaseSensitive) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
$sinceD = if ($Since) { [datetime]::Parse($Since) } else { $null }
$untilD = if ($Until) { ([datetime]::Parse($Until)).AddDays(1).AddSeconds(-1) } else { $null }

$fileHits = 0
$lineHits = 0
foreach ($root in $roots) {
  if (-not (Test-Path $root)) { continue }
  $files = Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $exts -contains $_.Extension.ToLower() -and $_.Name -notmatch '\.bak' }
  if ($Dir) { $files = $files | Where-Object { $_.FullName -match [regex]::Escape($Dir) } }
  if ($sinceD) { $files = $files | Where-Object { $_.LastWriteTime -ge $sinceD } }
  if ($untilD) { $files = $files | Where-Object { $_.LastWriteTime -le $untilD } }
  foreach ($f in ($files | Sort-Object FullName)) {
    $lines = Read-Lines $f.FullName
    $hitNos = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
      if ($lines[$i].IndexOf($Keyword, $cmp) -ge 0) { $hitNos += ($i + 1) }
    }
    if ($hitNos.Count -eq 0) { continue }
    $fileHits++
    if (-not $ListOnly) {
      Write-Output ("## {0}  （命中 {1} 行）" -f $f.FullName, $hitNos.Count)
      $shown = 0
      foreach ($no in $hitNos) {
        if ($shown -ge $Max) {
          Write-Output ("  ... 其余 {0} 行省略（-Max {1}）" -f ($hitNos.Count - $shown), $Max)
          break
        }
        $text = $lines[$no - 1].Trim()
        if ($text.Length -gt 200) { $text = $text.Substring(0, 200) + '...' }
        Write-Output ("  {0}: {1}" -f $no, $text)
        $shown++
        $lineHits++
      }
    }
  }
}
Write-Output ""
Write-Output ("统计：命中文件 {0} 个，匹配行 {1} 行（搜索范围：{2}）" -f $fileHits, $lineHits, ($roots -join ' + '))
if ($fileHits -eq 0) { Write-Output '（无结果：可换关键词，或加 -Dir/-Since 缩小范围）' }
