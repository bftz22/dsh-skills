# dsh-skills

给 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 智能体（Agent）用的七个实战技能包：
**ComfyUI 图像生成 / 视觉眼睛 / 浏览器自动化 / 交接维护 / IDM 多线程下载 / 邮件查询 / QQ 渠道**。

> 这些技能来自一台真实运行 dsh 的 Windows 机器上的日常实践——每个脚本都经过实际任务验证，
> 踩坑记录直接写在对应 SKILL.md 里。适合想让自己的 Agent "会出图、会看图、会上网、会交接、会下载、会查邮件、会发 QQ"的用户。

```
skills\
├── comfyui\   图像生成：单张/批量文生图、状态/模型查询（调本地 ComfyUI API）
├── vision\    视觉眼睛：OCR、人脸检测、本地 VLM 看图问答（Qwen2.5-VL）、云端 API
├── browser\   浏览器：无头 Chromium 自动化（抓文本/填表/点击/截图）
├── handover\  交接维护：简报/日志/状态快照，让多任 AI 会话无缝衔接
├── idm\       IDM 多线程下载：突破 CDN 单连接限速、批量队列、sha1 校验
├── mail\      邮件查询：IMAP 直连 QQ 邮箱（秒级、要紧度分级、附件下载/分流）
└── qq\        QQ 渠道：经 NapCat 发私聊消息、查在线状态、接收白名单图片
```

## ✨ 技能一览

| 技能 | 能做什么 | 依赖 |
|---|---|---|
| **comfyui** | 提示词单张/批量生成、换模型/尺寸/种子、队列与模型查询、失败排查 | 本地 ComfyUI（127.0.0.1:8188）+ 模型 |
| **vision** | 中英文 OCR（Windows 内置）、人脸检测（YOLOv8m ONNX）、本地 Qwen2.5-VL 真正"看懂"图片、智谱 GLM-4V 云端看图 | 方案 A 需 venv+模型（~7GB）；B 免依赖；C 需免费 API Key |
| **browser** | 网页文本抓取、表单填写、点击、全页截图、等待渲染 | Node.js >= 18 + Playwright + Chromium |
| **handover** | 接手简报、任务日志（md+jsonl 双写）、状态快照刷新、一键收尾 | PowerShell 5.1+；交接指南目录 |
| **idm** | 单文件/批量多线程下载（URL 列表）、等待完成、sha1 校验自动重试 | IDM（IDMan.exe，可用 `IDM_PATH` 指定） |
| **mail** | IMAP 直连 QQ 邮箱：最近/未读邮件、要紧度分级、附件下载、报错邮件分流 | Node.js + imapflow；.env 授权码 |
| **qq** | 经本机 NapCat 发私聊消息、查在线/好友列表、接收白名单大号图片 | NapCat（127.0.0.1:3000）；.env 凭据 |

## 🚀 快速开始

### 安装

```powershell
# 1) 克隆到 dsh 工作区的 skills 目录下（或任意位置）
git clone https://github.com/bftz22/dsh-skills.git
# 把需要的子目录复制到 <dsh>\skills\ 下即可

# 2) 按需安装依赖
# ComfyUI 技能：无需安装（调本机 ComfyUI API）
# 视觉技能 A：python -m venv <VISION_ENV> && pip install transformers torch qwen-vl-utils
# 浏览器技能：npm install playwright && npx playwright install chromium
# 邮件技能：cd skills\mail && npm install（imapflow）
# QQ 技能：需部署 NapCat（参考 qq/SKILL.md 与 qq-bridge 文档）
```

### 配置（环境变量，均可选）

| 变量 | 默认值 | 用于 |
|---|---|---|
| `COMFYUI_ROOT` | `C:\ComfyUI` | comfyui / vision-face（模型与输出路径） |
| `COMFYUI_PYTHON` | `$COMFYUI_ROOT\python\python.exe` | vision-face（需 numpy/cv2/onnxruntime） |
| `VISION_ENV` | `%USERPROFILE%\vision-env` | vision-ask（Qwen2.5-VL 的 venv） |
| `VISION_MODEL_PATH` | `%USERPROFILE%\vision-models\Qwen2.5-VL-3B-Instruct` | vision-ask（本地模型） |
| `VISION_API_KEY` | 空 | vision-cloud（智谱 GLM-4V-Flash） |
| `HANDOVER_DIR` | `D:\AI交接指南` | handover（交接指南目录） |
| `BRIDGE_LOG` / `COMFYUI_LOG` / `COMFYUI_WORKFLOWS` | 常见默认路径 | handover 快照采集 |
| `IDM_PATH` | 自动探测常见安装位置 | idm（IDMan.exe 完整路径，非默认安装时设置） |
| `NAPCAT_API` / `NAPCAT_TOKEN` | `http://127.0.0.1:3000` / 空 | qq（NapCat HTTP API 与访问令牌，存于 .env） |
| `QQMAIL_IMAP_USER` / `QQMAIL_IMAP_PASS` | 空 | mail（QQ 邮箱账号与 IMAP 授权码，存于 .env） |

### 常用调用

```powershell
# 出图（comfyui）
powershell -File skills\comfyui\comfy-generate.ps1 -Prompt "1girl, silver hair, masterpiece" -Wait

# 看图（vision，推荐本地方案 A）
powershell -File skills\vision\vision-ask.ps1 -Image "photo.jpg" -Question "描述这张图片"

# 网页自动化（browser）
node skills\browser\browser-run.mjs https://www.baidu.com --text

# 交接收尾（handover）
powershell -File skills\handover\finish.ps1 -Task "本次任务一句话总结"

# 多线程下载（idm）
powershell -File skills\idm\idm-download.ps1 -Url "https://example.com/file.jar" -Dir "D:\download"

# 查邮件（mail）
node skills\mail\mail-check.mjs --unseen --limit 10

# QQ 发消息（qq，NapCat 在线时）
powershell -File skills\qq\qq-send.ps1 -UserId 10001 -Message "你好"
```

详细用法见每个子目录的 `SKILL.md`。

## ⚠️ 说明

- 脚本主要面向 **Windows + PowerShell 5.1**（中文环境实测）；脚本文件为 UTF-8 带 BOM
- 各技能是"薄胶水"：核心能力（ComfyUI、模型、Playwright）都是成熟开源组件，本仓库提供的是
  与 dsh Agent 工作流结合的调用封装与踩坑经验
- 人脸检测模型 `face_yolov8m.onnx` 与本地 VLM 模型体积较大，需自行下载（参考 vision/SKILL.md）

## 📜 License

MIT © 2026 dsh-skills contributors。详见 [LICENSE](LICENSE)。
