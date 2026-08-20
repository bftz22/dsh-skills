param(
  [Parameter(Mandatory = $true)][string]$Prompt,
  [string]$Negative = 'lowres, bad anatomy, bad hands, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, deformed, blurry',
  [string]$Model = 'animagine-xl-3.1.safetensors',
  [int]$Width = 832,
  [int]$Height = 1216,
  [int]$Steps = 28,
  [double]$Cfg = 7.0,
  [string]$Sampler = 'dpmpp_2m',
  [string]$Scheduler = 'karras',
  [int]$Seed = -1,
  [string]$Prefix = 'comfy_out',
  [switch]$Wait
)
$ErrorActionPreference = 'Continue'
if ($Seed -lt 0) { $Seed = Get-Random -Minimum 1 -Maximum 2147483647 }

# 检查 ComfyUI
try { Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 5 | Out-Null }
catch { Write-Host "[FAIL] ComfyUI 未运行 (127.0.0.1:8188)"; exit 1 }

# 检查模型
$modelPath = "{COMFYUI}\models\checkpoints\$Model"
if (-not (Test-Path $modelPath)) { Write-Host "[FAIL] 模型不存在: $modelPath"; exit 1 }

$wf = @{
  "3" = @{ class_type = "KSampler"; inputs = @{ cfg = $Cfg; denoise = 1.0; latent_image = @("5",0); model = @("4",0); negative = @("7",0); positive = @("6",0); sampler_name = $Sampler; scheduler = $Scheduler; seed = $Seed; steps = $Steps } }
  "4" = @{ class_type = "CheckpointLoaderSimple"; inputs = @{ ckpt_name = $Model } }
  "5" = @{ class_type = "EmptyLatentImage"; inputs = @{ batch_size = 1; height = $Height; width = $Width } }
  "6" = @{ class_type = "CLIPTextEncode"; inputs = @{ clip = @("4",1); text = $Prompt } }
  "7" = @{ class_type = "CLIPTextEncode"; inputs = @{ clip = @("4",1); text = $Negative } }
  "8" = @{ class_type = "VAEDecode"; inputs = @{ samples = @("3",0); vae = @("4",2) } }
  "9" = @{ class_type = "SaveImage"; inputs = @{ filename_prefix = $Prefix; images = @("8",0) } }
}
$body = [System.Text.Encoding]::UTF8.GetBytes((@{ prompt = $wf; client_id = "skill-gen" } | ConvertTo-Json -Depth 10))
try {
  $r = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/prompt' -Method Post -ContentType 'application/json; charset=utf-8' -Body $body -TimeoutSec 30
} catch { Write-Host "[FAIL] 提交失败: $($_.Exception.Message)"; exit 1 }
$id = $r.prompt_id
Write-Host "prompt_id=$id  model=$Model  size=${Width}x${Height}  seed=$Seed"

if ($Wait) {
  $deadline = (Get-Date).AddMinutes(10)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    try {
      $h = Invoke-RestMethod -Uri "http://127.0.0.1:8188/history/$id" -TimeoutSec 10
      if ($h.$id) {
        $st = $h.$id.status.status_str
        if ($st -eq 'success') {
          foreach ($o in $h.$id.outputs.PSObject.Properties) { foreach ($img in $o.Value.images) {
            Write-Host "OK $($img.filename)"
            $bp = if ($env:DSH_BRIDGE_PORT) { $env:DSH_BRIDGE_PORT } else { '<PORT_MAIN>' }
            Write-Host "URL http://127.0.0.1:$bp/output/$($img.filename)"
          } }
          exit 0
        } elseif ($st -eq 'error') {
          $raw = $h | ConvertTo-Json -Depth 12
          $i = $raw.IndexOf('exception_message')
          if ($i -ge 0) { Write-Host "[FAIL] $($raw.Substring($i, [Math]::Min(300, $raw.Length - $i)))" }
          else { Write-Host "[FAIL] 生成失败(无详情)" }
          exit 1
        }
      }
    } catch {}
  }
  Write-Host "[FAIL] 等待超时"; exit 1
}
