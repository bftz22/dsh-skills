# 视觉眼睛 Skill（vision-eye）
> 开源级别：**open（可开源）**——已/可同步至 dsh-skills 公开仓库

> 用途：给 AI「外接眼睛」——按需调用本机/云端视觉能力识别图片内容
> 目录：`C:\Users\Administrator\deepseek-harness\skills\vision\`
> 创建：2026-08-16（三方案齐全：B 轻量 / A 本地大模型 / C 云端 API）

## 三只眼睛怎么选

| 眼睛 | 脚本 | 能力 | 速度 | 隐私 | 适用 |
|---|---|---|---|---|---|
| **B 轻量** | `vision-ocr.ps1` | 中英文 OCR 文字识别（Windows 内置） | 秒级 | ✅ 本机 | 截图/图片文字提取 |
| **B 轻量** | `vision-face.ps1` | 人脸检测（YOLOv8m ONNX，含 NMS） | 秒级 | ✅ 本机 | 有没有人脸/位置/数量 |
| **A 大模型** | `vision-ask.ps1` | **真正看懂图片**（Qwen2.5-VL-3B 本地） | 首次约 1 分钟，之后秒级 | ✅ 本机 | 画面描述/看图问答 |
| **C 云端** | `vision-cloud.ps1` | 云端视觉大模型（GLM-4V-Flash 免费） | 秒级 | ⚠️ 图片上传智谱 | 快速高质量；需 API Key |

## 调用示例

```powershell
# OCR 文字（B）
powershell -File vision-ocr.ps1 -Image "D:\图片\截图.png"

# 人脸检测（B）
powershell -File vision-face.ps1 -Image "D:\图片\合影.jpg"

# 本地大模型看图问答（A，推荐默认）
powershell -File vision-ask.ps1 -Image "D:\图片\照片.jpg" -Question "描述一下这张图片的内容"

# 云端看图（C，需先配置 VISION_API_KEY）
powershell -File vision-cloud.ps1 -Image "D:\图片\照片.jpg" -Question "图里有什么？"
```

## 依赖与环境

| 项目 | 位置 |
|---|---|
| venv（方案 A 专用，隔离于 ComfyUI） | `F:\vision-env`（python 3.13 + transformers 4.57 + torch 2.13 cu130） |
| 本地视觉模型 | `F:\vision-models\Qwen2.5-VL-3B-Instruct`（~7GB，bf16） |
| 人脸检测模型 | `F:\ComfyUI-aki-v3.2\ComfyUI\models\onnx\bbox\face_yolov8m.onnx` |
| OCR | Windows 自带（Win10 22H2 含中文语言包） |
| 云端 Key | `.env` 的 `VISION_API_KEY`（智谱 GLM-4V-Flash，免费） |

## 注意事项

1. **隐私分级**：敏感图片只用 A/B（不出本机）；C 会上传云端，用前说明
2. **首跑慢**：vision-ask 首次加载模型约 1 分钟；之后模型留在显存，回答秒级
3. **显存**：Qwen2.5-VL-3B bf16 约 7GB，与 ComfyUI 共用 16GB 显存——ComfyUI 出图时避免同时看图
4. **模型更新**：如需更强（7B/72B）或更换模型，修改 vision-ask.ps1 内 `model_path` 即可（下载走 hf-mirror）
5. 图片来自 Chatbox 附件时：先落到本机路径再调用对应脚本；回复中只引用文字结果，不塞 base64
