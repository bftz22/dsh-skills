# qq-send.ps1 - 通过本机 NapCat 给指定 QQ 发私聊消息
# 用法: powershell -File qq-send.ps1 -UserId 3565728847 -Message "内容"
# 凭据: 读 .env 的 NAPCAT_API / NAPCAT_TOKEN

param(
  [Parameter(Mandatory = $true)][string]$UserId,
  [Parameter(Mandatory = $true)][string]$Message
)

$ErrorActionPreference = 'Stop'

# 读 .env 凭据
function Get-EnvVal($key) {
  $envFile = '{WORKSPACE}\.env'
  $m = Select-String -Path $envFile -Pattern "^$key\s*=\s*(.*)$"
  if ($m) { return $m.Matches[0].Groups[1].Value.Trim() }
  return $null
}

$api = Get-EnvVal 'NAPCAT_API'
if (-not $api) { $api = 'http://127.0.0.1:3000' }
$token = Get-EnvVal 'NAPCAT_TOKEN'

# 校验 QQ 号格式
if ($UserId -notmatch '^\d{5,12}$') { Write-Error "QQ 号格式不对: $UserId"; exit 1 }

$headers = @{}
if ($token) { $headers['Authorization'] = "Bearer $token" }

# 调用 NapCat 发送私聊消息
$url = "$api/send_private_msg?user_id=$UserId&message=$([uri]::EscapeDataString($Message))"
try {
  $r = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 30
  if ($r.status -eq 'ok') {
    Write-Output "OK: 已发送给 $UserId (message_id=$($r.data.message_id))"
  } else {
    Write-Output "FAIL: $($r.message) / $($r.wording)"
    exit 1
  }
} catch {
  Write-Output "ERROR: $($_.Exception.Message)"
  exit 1
}
