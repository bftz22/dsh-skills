# qq-info.ps1 - 查询贤臣(NapCat)在线状态 / 好友列表
# 用法: powershell -File qq-info.ps1 [-Friends]
# 凭据: 读 .env 的 NAPCAT_API / NAPCAT_TOKEN

param(
  [switch]$Friends
)

$ErrorActionPreference = 'Stop'

function Get-EnvVal($key) {
  $envFile = 'C:\Users\Administrator\deepseek-harness\.env'
  $m = Select-String -Path $envFile -Pattern "^$key\s*=\s*(.*)$"
  if ($m) { return $m.Matches[0].Groups[1].Value.Trim() }
  return $null
}

$api = Get-EnvVal 'NAPCAT_API'
if (-not $api) { $api = 'http://127.0.0.1:3000' }
$token = Get-EnvVal 'NAPCAT_TOKEN'

$headers = @{}
if ($token) { $headers['Authorization'] = "Bearer $token" }

try {
  # 登录信息
  $login = Invoke-RestMethod -Uri "$api/get_login_info" -Headers $headers -TimeoutSec 10
  if ($login.status -eq 'ok') {
    $d = $login.data
    Write-Output "贤臣在线: QQ=$($d.user_id) 昵称=$($d.nickname)"
  } else {
    Write-Output "NapCat 状态异常: $($login.message)"
    exit 1
  }

  # 好友列表
  if ($Friends) {
    $fl = Invoke-RestMethod -Uri "$api/get_friend_list" -Headers $headers -TimeoutSec 15
    if ($fl.status -eq 'ok') {
      Write-Output "好友列表($($fl.data.Count)人):"
      $fl.data | ForEach-Object { Write-Output "  $($_.user_id) | $($_.nickname)" }
    }
  }
} catch {
  Write-Output "ERROR: $($_.Exception.Message) (NapCat 未运行或 3000 端口不通?)"
  exit 1
}
