# vision-ask.ps1 — 眼睛方案A：本地视觉大模型 Qwen2.5-VL-3B（真正"看懂"图片）
# 用法：powershell -File vision-ask.ps1 -Image "图片路径" -Question "图片里有什么？"
# 说明：首次运行需加载模型（约 30-60 秒，7GB 显存）；图不出本机
param(
  [Parameter(Mandatory = $true)][string]$Image,
  [Parameter(Mandatory = $true)][string]$Question
)

$ErrorActionPreference = 'Continue'
if (-not (Test-Path $Image)) { Write-Output "ERR: 图片不存在: $Image"; exit 1 }

$py = @'
import sys, os, torch, base64
sys.stdout.reconfigure(encoding='utf-8')
from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
from qwen_vl_utils import process_vision_info

image_path = sys.argv[1]
question = sys.argv[2]

ext = image_path.lower().rsplit('.', 1)[-1]
mime = 'image/png' if ext == 'png' else 'image/jpeg'
with open(image_path, 'rb') as f:
    b64 = base64.b64encode(f.read()).decode('ascii')
img_url = 'data:%s;base64,%s' % (mime, b64)

messages = [{'role': 'user', 'content': [
    {'type': 'image', 'image': img_url},
    {'type': 'text', 'text': question},
]}]

model_path = r'F:\vision-models\Qwen2.5-VL-3B-Instruct'
model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
    model_path, torch_dtype=torch.bfloat16, device_map='cuda')
processor = AutoProcessor.from_pretrained(model_path)

text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
image_inputs, video_inputs = process_vision_info(messages)
inputs = processor(text=[text], images=image_inputs, videos=video_inputs,
                   padding=True, return_tensors='pt').to('cuda')
with torch.no_grad():
    out = model.generate(**inputs, max_new_tokens=768, do_sample=False)
answer = processor.batch_decode(out[:, inputs.input_ids.shape[1]:], skip_special_tokens=True)[0]
print('== 视觉回答 ==')
print(answer.strip())
'@
$tmpPy = Join-Path $env:TEMP ("vision-ask-" + [guid]::NewGuid().ToString('N') + ".py")
[System.IO.File]::WriteAllText($tmpPy, $py, (New-Object System.Text.UTF8Encoding($false)))
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 强制 Python 以 UTF-8 输出（防止 cp1252/GBK 区域下 print 中文报 UnicodeEncodeError）
$env:PYTHONIOENCODING = 'utf-8'
& "F:\vision-env\Scripts\python.exe" $tmpPy (Resolve-Path $Image).Path $Question
Remove-Item Env:PYTHONIOENCODING -ErrorAction SilentlyContinue
if (Test-Path $tmpPy) { Remove-Item $tmpPy -Force }
