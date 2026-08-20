# joint-task-check.ps1 - 联合任务启用检查：三桥状态 + 看板摘要（开源通用版）
# 用法：powershell -File joint-task-check.ps1
# 开源版说明：端口与通传区路径已占位化，接入时设置环境变量 COURT_DIR 或将下方 $courtDir 改为实际路径
$ErrorActionPreference = 'SilentlyContinue'

# 通传区根目录（原本机通传区路径，开源版用环境变量或占位）
$courtDir = if ($env:COURT_DIR) { $env:COURT_DIR } else { '<COURT_DIR>' }

Write-Output ("===== 联合任务启用检查 " + (Get-Date).ToString('yyyy-MM-dd HH:mm') + " =====")
Write-Output ""
Write-Output "--- 三臣桥状态 ---"
$ports = @{ '<PORT_MAIN>' = '政务大臣'; '<PORT_TECH>' = '技术大臣'; '<PORT_CONTENT>' = '内容大臣' }
foreach ($p in $ports.Keys) {
    try {
        $r = Invoke-WebRequest -Uri ("http://127.0.0.1:" + $p + "/healthz") -TimeoutSec 4 -UseBasicParsing
        $h = ($r.Content | ConvertFrom-Json)
        Write-Output ("  " + $ports[$p] + " (" + $p + ") : OK harnesses=" + $h.harnesses)
    } catch {
        Write-Output ("  " + $ports[$p] + " (" + $p + ") : 未响应！")
    }
}

Write-Output ""
Write-Output "--- 公务看板（协作事项）---"
$kb = Join-Path $courtDir '公务看板.md'
if (Test-Path $kb) {
    Get-Content $kb -Encoding UTF8 | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|-' -and $_ -notmatch '事项' -and $_ -notmatch '示例' } | ForEach-Object { Write-Output ("  " + $_) }
} else { Write-Output "  看板不存在（请设置 COURT_DIR 环境变量）" }

Write-Output ""
Write-Output "--- 移交书存档（最近 5 份）---"
$dir = Join-Path $courtDir '移交书存档'
if (Test-Path $dir) {
    Get-ChildItem $dir -Filter "移交书*" | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | ForEach-Object { Write-Output ("  " + $_.Name + " (" + $_.LastWriteTime.ToString('MM-dd HH:mm') + ")") }
} else { Write-Output "  存档目录不存在" }

Write-Output ""
Write-Output "===== 检查完毕，可向宿主呈报后开工 ====="