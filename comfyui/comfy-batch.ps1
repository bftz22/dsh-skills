param(
  [Parameter(Mandatory = $true)][string]$PromptFile,
  [string]$Model = 'animagine-xl-3.1.safetensors',
  [int]$Width = 832,
  [int]$Height = 1216,
  [int]$Steps = 28,
  [double]$Cfg = 7.0,
  [string]$Sampler = 'dpmpp_2m',
  [string]$Scheduler = 'karras',
  [int]$SeedBase = 1000,
  [string]$Prefix = 'role',
  [int]$TimeoutMinutes = 15,
  [string]$ReportDir = '',
  [switch]$DryRun
)
$ErrorActionPreference = 'Continue'

# 配置：ComfyUI 根目录（可用环境变量 COMFYUI_ROOT 覆盖）
$ComfyRoot = $env:COMFYUI_ROOT; if (-not $ComfyRoot) { $ComfyRoot = 'C:\ComfyUI' }
if (-not $ReportDir) { $ReportDir = (Get-Location).Path }

# ---------- 解析提示词文件 ----------
$lines = Get-Content $PromptFile -Encoding UTF8 -ErrorAction SilentlyContinue
if (-not $lines) { $lines = Get-Content $PromptFile -Encoding Default }
if (-not $lines) { Write-Host "[FAIL] 无法读取文件: $PromptFile"; exit 1 }

$items = @()
$cur = $null
$state = $null
foreach ($line in $lines) {
  $t = $line.Trim()
  if ($t -match '^【.+】(.+)$') {
    if ($cur -and $cur.prompt) { $items += $cur }
    $cur = @{ name = $Matches[1].Trim(); prompt = ''; neg = '' }
    $state = $null
  } elseif ($t -eq 'Prompt:') { $state = 'p' }
  elseif ($t -eq 'Negative Prompt:') { $state = 'n' }
  elseif ($t -eq '' -or $t -like '----*' -or $t -like '====*') { $state = $null }
  elseif ($cur -and $state -eq 'p') { $cur.prompt += (' ' + $t) }
  elseif ($cur -and $state -eq 'n') { $cur.neg += (' ' + $t) }
}
if ($cur -and $cur.prompt) { $items += $cur }

if ($items.Count -eq 0) { Write-Host "[FAIL] 未解析到任何条目 (格式: 【编号】名称 / Prompt: / Negative Prompt:)"; exit 1 }
Write-Host "解析到 $($items.Count) 个条目:"
for ($i = 0; $i -lt $items.Count; $i++) { Write-Host ("  {0:00}  {1}" -f ($i+1), $items[$i].name) }

if ($DryRun) { Write-Host "[DryRun] 解析验证通过, 不提交"; exit 0 }

# ---------- 检查 ComfyUI / 模型 ----------
try { Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 5 | Out-Null }
catch { Write-Host "[FAIL] ComfyUI 未运行"; exit 1 }
$modelPath = Join-Path $ComfyRoot "models\checkpoints\$Model"
if (-not (Test-Path $modelPath)) { Write-Host "[FAIL] 模型不存在: $modelPath"; exit 1 }

# ---------- 批量提交 ----------
$ids = @()
for ($i = 0; $i -lt $items.Count; $i++) {
  $c = $items[$i]
  $prefix = '{0}_{1:00}' -f $Prefix, ($i + 1)
  $wf = @{
    "3" = @{ class_type = "KSampler"; inputs = @{ cfg = $Cfg; denoise = 1.0; latent_image = @("5",0); model = @("4",0); negative = @("7",0); positive = @("6",0); sampler_name = $Sampler; scheduler = $Scheduler; seed = ($SeedBase + $i); steps = $Steps } }
    "4" = @{ class_type = "CheckpointLoaderSimple"; inputs = @{ ckpt_name = $Model } }
    "5" = @{ class_type = "EmptyLatentImage"; inputs = @{ batch_size = 1; height = $Height; width = $Width } }
    "6" = @{ class_type = "CLIPTextEncode"; inputs = @{ clip = @("4",1); text = $c.prompt.Trim() } }
    "7" = @{ class_type = "CLIPTextEncode"; inputs = @{ clip = @("4",1); text = $c.neg.Trim() } }
    "8" = @{ class_type = "VAEDecode"; inputs = @{ samples = @("3",0); vae = @("4",2) } }
    "9" = @{ class_type = "SaveImage"; inputs = @{ filename_prefix = $prefix; images = @("8",0) } }
  }
  $body = [System.Text.Encoding]::UTF8.GetBytes((@{ prompt = $wf; client_id = "skill-batch" } | ConvertTo-Json -Depth 10))
  try {
    $r = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/prompt' -Method Post -ContentType 'application/json; charset=utf-8' -Body $body -TimeoutSec 30
    Write-Host "submitted $prefix ($($c.name)) -> $($r.prompt_id)"
    $ids += @{ idx = $i; name = $c.name; id = $r.prompt_id }
  } catch { Write-Host "submit FAIL ${prefix}: $($_.Exception.Message)" }
}

# ---------- 等待完成 ----------
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$results = @{}
while ($results.Count -lt $ids.Count -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 10
  foreach ($j in $ids) {
    if ($results.ContainsKey($j.id)) { continue }
    try {
      $h = Invoke-RestMethod -Uri "http://127.0.0.1:8188/history/$($j.id)" -TimeoutSec 10
      if ($h.($j.id)) {
        $st = $h.($j.id).status.status_str
        if ($st -eq 'success') {
          $imgs = @()
          foreach ($o in $h.($j.id).outputs.PSObject.Properties) { foreach ($img in $o.Value.images) { $imgs += $img.filename } }
          Write-Host "done $($j.name) -> $($imgs -join ',')"
          $results[$j.id] = @{ ok = $true; files = ($imgs -join ',') }
        } elseif ($st -eq 'error') {
          $raw = $h | ConvertTo-Json -Depth 12
          $i = $raw.IndexOf('exception_message')
          $msg = if ($i -ge 0) { $raw.Substring($i, [Math]::Min(200, $raw.Length - $i)) } else { 'unknown' }
          Write-Host "error $($j.name): $msg"
          $results[$j.id] = @{ ok = $false; files = $msg }
        }
      }
    } catch {}
  }
}

# ---------- 生成报告 ----------
$report = Join-Path $ReportDir ("ComfyUI生成报告-" + (Get-Date -Format 'yyyyMMdd-HHmm') + ".md")
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# ComfyUI 批量生成报告")
[void]$sb.AppendLine('')
[void]$sb.AppendLine("生成时间：" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
[void]$sb.AppendLine("模型：$Model  尺寸：${Width}x${Height}  参数：steps=$Steps cfg=$Cfg $Sampler/$Scheduler")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| # | 名称 | 结果 | 文件 |')
[void]$sb.AppendLine('|---|---|---|---|')
foreach ($j in $ids) {
  $r = $results[$j.id]
  $st = if ($r) { if ($r.ok) { '✅' } else { '❌' } } else { '⏳' }
  $f = if ($r) { $r.files } else { '超时/未完成' }
  [void]$sb.AppendLine(('| {0} | {1} | {2} | `{3}` |' -f ($j.idx+1), $j.name, $st, $f))
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('图片目录：$env:COMFYUI_ROOT\output\')
[IO.File]::WriteAllText($report, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Host "报告: $report"
Write-Host "完成 $($results.Count)/$($ids.Count)"
