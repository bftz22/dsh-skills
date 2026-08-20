# vision-face.ps1 — 眼睛方案B：人脸检测（本地 YOLOv8m ONNX）
# 用法：powershell -File vision-face.ps1 -Image "图片路径"
# 输出：检测到的人脸数量、位置（xyxy 像素坐标）、置信度
param([Parameter(Mandatory = $true)][string]$Image)

$ErrorActionPreference = 'Continue'
if (-not (Test-Path $Image)) { Write-Output "ERR: 图片不存在: $Image"; exit 1 }

$py = @'
import sys, os, numpy as np, cv2, onnxruntime
img_path = sys.argv[1]
img = cv2.imread(img_path)  # BGR
if img is None:
    print('ERR: 无法读取图片'); sys.exit(1)
h, w = img.shape[:2]
sess = onnxruntime.InferenceSession(r'{COMFYUI}\models\onnx\bbox\face_yolov8m.onnx', providers=['CPUExecutionProvider'])
in_h, in_w = 640, 640
r = min(in_h / h, in_w / w)
new_w, new_h = max(1, int(round(w * r))), max(1, int(round(h * r)))
resized = cv2.resize(img, (new_w, new_h))
canvas = np.full((in_h, in_w, 3), 114, dtype=np.uint8)
dw, dh = (in_w - new_w) // 2, (in_h - new_h) // 2
canvas[dh:dh+new_h, dw:dw+new_w] = resized
inp = canvas.astype(np.float32) / 255.0
inp = np.transpose(inp, (2, 0, 1))[None, ...]
pred = sess.run(None, {sess.get_inputs()[0].name: inp})[0][0]
if pred.shape[0] < pred.shape[1]:
    pred = pred.T
boxes_xywh = pred[:, :4]
scores = pred[:, 4]
mask = scores > 0.3
boxes_xywh, scores = boxes_xywh[mask], scores[mask]
if len(scores) == 0:
    print('检测到人脸: 0 张'); sys.exit(0)
cx, cy, bw, bh = boxes_xywh[:, 0], boxes_xywh[:, 1], boxes_xywh[:, 2], boxes_xywh[:, 3]
x1, y1 = (cx - bw/2 - dw) / r, (cy - bh/2 - dh) / r
x2, y2 = (cx + bw/2 - dw) / r, (cy + bh/2 - dh) / r
x1 = np.clip(x1, 0, w-1); y1 = np.clip(y1, 0, h-1)
x2 = np.clip(x2, 0, w-1); y2 = np.clip(y2, 0, h-1)
# NMS 去重（同一张脸只保留最高置信度框）
order = scores.argsort()[::-1]
keep = []
while order.size > 0:
    i = int(order[0]); keep.append(i)
    rest = order[1:]
    if rest.size == 0:
        break
    xx1 = np.maximum(x1[i], x1[rest]); yy1 = np.maximum(y1[i], y1[rest])
    xx2 = np.minimum(x2[i], x2[rest]); yy2 = np.minimum(y2[i], y2[rest])
    inter = np.maximum(0, xx2-xx1) * np.maximum(0, yy2-yy1)
    area_i = (x2[i]-x1[i]) * (y2[i]-y1[i])
    area_r = (x2[rest]-x1[rest]) * (y2[rest]-y1[rest])
    iou = inter / (area_i + area_r - inter + 1e-9)
    order = rest[iou <= 0.45]
keep = np.array(keep)
scores, x1, y1, x2, y2 = scores[keep], x1[keep], y1[keep], x2[keep], y2[keep]
print('检测到人脸: %d 张' % len(scores))
for i in range(len(scores)):
    print('  [%d] 置信度 %.2f | 位置 x:%d-%d y:%d-%d' % (i+1, scores[i], int(x1[i]), int(x2[i]), int(y1[i]), int(y2[i])))
'@
$tmpPy = Join-Path $env:TEMP ("vision-face-" + [guid]::NewGuid().ToString('N') + ".py")
[System.IO.File]::WriteAllText($tmpPy, $py, (New-Object System.Text.UTF8Encoding($false)))
# 强制 Python 以 UTF-8 输出（防止 cp1252/GBK 区域下 print 中文报 UnicodeEncodeError）
$env:PYTHONIOENCODING = 'utf-8'
& "{COMFYUI_PYTHON}\python.exe" $tmpPy (Resolve-Path $Image).Path
Remove-Item Env:PYTHONIOENCODING -ErrorAction SilentlyContinue
if (Test-Path $tmpPy) { Remove-Item $tmpPy -Force }
