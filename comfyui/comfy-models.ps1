# 列出 checkpoints 模型
Get-ChildItem 'F:\ComfyUI-aki-v3.2\ComfyUI\models\checkpoints' -ErrorAction SilentlyContinue | ForEach-Object {
  if ($_.PSIsContainer) { "  [目录] $($_.Name)" }
  else { "  $($_.Name)  $([math]::Round($_.Length/1GB,2)) GB" }
}
