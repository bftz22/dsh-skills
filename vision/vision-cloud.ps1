# vision-cloud.ps1 — 眼睛方案C：云端视觉 API（智谱 GLM-4V-Flash，免费额度）
# 用法：powershell -File vision-cloud.ps1 -Image "图片路径" -Question "问题"
# 前置：在 open.bigmodel.cn 注册获取 API Key，写入 .env 的 VISION_API_KEY（或 -ApiKey 参数传入）
# 注意：图片会上传到智谱云端，敏感图片请用方案 A（本地）
param(
  [Parameter(Mandatory = $true)][string]$Image,
  [Parameter(Mandatory = $true)][string]$Question,
  [string]$ApiKey = ''
)

$ErrorActionPreference = 'Continue'
if (-not (Test-Path $Image)) { Write-Output "ERR: 图片不存在: $Image"; exit 1 }

# 取密钥：优先 -ApiKey，其次 .env 的 VISION_API_KEY
if (-not $ApiKey) {
  $line = Select-String -Path "C:\Users\Administrator\deepseek-harness\.env" -Pattern '^VISION_API_KEY=' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($line) { $ApiKey = $line.Line.Substring($line.Line.IndexOf('=') + 1).Trim().Trim('"') }
}
if (-not $ApiKey) {
  Write-Output "ERR: 未配置 API Key。请到 https://open.bigmodel.cn 注册获取（GLM-4V-Flash 免费），"
  Write-Output "然后告诉我，我会写入 .env 的 VISION_API_KEY（或运行: 本脚本 -ApiKey sk-xxx）"
  exit 1
}

$ext = [IO.Path]::GetExtension($Image).ToLower()
$mime = if ($ext -eq '.png') { 'image/png' } else { 'image/jpeg' }
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $Image).Path))

$body = @{
  model = 'glm-4v-flash'
  messages = @(@{
    role = 'user'
    content = @(
      @{ type = 'image_url'; image_url = @{ url = "data:$mime;base64,$b64" } },
      @{ type = 'text'; text = $Question }
    )
  })
} | ConvertTo-Json -Depth 8

$headers = @{ 'Authorization' = "Bearer $ApiKey"; 'Content-Type' = 'application/json' }
try {
  $resp = Invoke-RestMethod -Uri 'https://open.bigmodel.cn/api/paas/v4/chat/completions' -Method Post -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 120
  Write-Output '== 云端视觉回答 =='
  Write-Output $resp.choices[0].message.content
} catch {
  Write-Output "ERR: 调用失败: $($_.Exception.Message)"
  if ($_.ErrorDetails.Message) { Write-Output $_.ErrorDetails.Message }
}
