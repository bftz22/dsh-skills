# ComfyUI 状态查看: 队列 / 最近结果 / 输出 / 模型
$ErrorActionPreference = 'Continue'
$ComfyRoot = $env:COMFYUI_ROOT; if (-not $ComfyRoot) { $ComfyRoot = 'C:\ComfyUI' }

try {
  $s = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 5
  Write-Host "ComfyUI: 运行中 (v$($s.system.comfyui_version))"
} catch { Write-Host "ComfyUI: 未运行"; exit 1 }

$q = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/queue' -TimeoutSec 10
Write-Host "队列: 运行中 $($q.queue_running.Count) / 待处理 $($q.queue_pending.Count)"

Write-Host "`n最近输出文件:"
Get-ChildItem (Join-Path $ComfyRoot 'output\*.png') -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 8 |
  ForEach-Object { "  $($_.Name)  $([math]::Round($_.Length/1KB,0)) KB  $($_.LastWriteTime.ToString('HH:mm:ss'))" }

Write-Host "`n可用模型 (checkpoints):"
Get-ChildItem (Join-Path $ComfyRoot 'models\checkpoints\*.safetensors') -ErrorAction SilentlyContinue |
  ForEach-Object { "  $($_.Name)  $([math]::Round($_.Length/1GB,2)) GB" }
