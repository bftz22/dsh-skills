# ComfyUI 图片生成 Skill（comfyui-image-gen）

> 用途：通过本地 ComfyUI（http://127.0.0.1:8188）单张/批量生成 AI 图片
> 创建：2026-08-16（基于实际调试经验整理）

## 适用场景

- 用户给一个「提示词文件」要求全部生成（角色/场景配图）
- 单张文生图、换模型、换尺寸、换种子
- 查看生成队列、结果、模型清单

## 前置条件

1. **ComfyUI 已运行**：`http://127.0.0.1:8188` 返回 200
   - 未运行时：启动 ComfyUI（`$env:COMFYUI_ROOT` 指向安装目录）
2. **模型就位**：`$env:COMFYUI_ROOT\models\checkpoints\`
   - `animagine-xl-3.1.safetensors`（二次元）
   - `Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors`（写实）
   - `DreamShaper_8_pruned.safetensors`（SD1.5 通用，用 512×512）
3. **PowerShell 5.1**，脚本为 UTF-8 BOM 编码（中文正常）

## 配置（环境变量，均可选）

| 变量 | 默认值 | 说明 |
|---|---|---|
| `COMFYUI_ROOT` | `C:\ComfyUI` | ComfyUI 安装根目录（含 models/、output/、user/ 的上级） |

## 脚本一览

| 脚本 | 作用 | 关键参数 |
|---|---|---|
| `comfy-generate.ps1` | 单张生成 | -Prompt 必填；-Model -Width -Height -Steps -Cfg -Seed -Prefix -Wait |
| `comfy-batch.ps1` | 提示词文件批量生成 | -PromptFile 必填；-Model -Width -Height -SeedBase -DryRun -ReportDir |
| `comfy-status.ps1` | 队列 / 最近结果 / 输出目录 | 无 |
| `comfy-models.ps1` | 列出 checkpoints 模型 | 无 |

## 调用示例

```powershell
# 单张（默认二次元模型 832x1216，等待完成）
powershell -File comfy-generate.ps1 -Prompt "1girl, silver hair, cherry blossoms, masterpiece" -Wait

# 指定模型/尺寸/种子（写实横版）
powershell -File comfy-generate.ps1 -Prompt "..." -Model "Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors" -Width 1216 -Height 832 -Seed 42 -Wait

# 批量：从提示词文件生成（格式见下），先 DryRun 检查解析
powershell -File comfy-batch.ps1 -PromptFile ".\prompts.txt" -DryRun
powershell -File comfy-batch.ps1 -PromptFile ".\prompts.txt"

# 状态与模型
powershell -File comfy-status.ps1
powershell -File comfy-models.ps1
```

## 提示词文件格式（comfy-batch 解析规则）

```
------------------------------------------------
【1】角色名（形态）
------------------------------------------------
Prompt:
(1girl:1.2), ... 英文提示词一行
Negative Prompt:
lowres, bad anatomy, ...
```

- 名称行：`【编号】名称`，编号用于输出前缀（role_01, role_02...）
- `Prompt:` 与 `Negative Prompt:` 后各跟一行文本
- 批量完成后自动生成报告：`<ReportDir>\ComfyUI生成报告-<时间>.md`（含名称↔文件对照，默认当前目录）

## 推荐参数

| 模型 | 尺寸 | Steps | 备注 |
|---|---|---|---|
| animagine-xl-3.1 | 832×1216（人像竖版） | 28 | 二次元，cfg 7 |
| Juggernaut-XL v9 | 1024×1024 / 1216×832 | 28 | 写实，cfg 7 |
| DreamShaper 8 | 512×512 | 20 | SD1.5，cfg 7 |

## 直接调 API（不经过脚本）

| 操作 | 方法 |
|---|---|
| 提交任务 | `POST /prompt` body=`{"prompt":{节点图},"client_id":"x"}` → 返回 prompt_id |
| 查结果 | `GET /history/{prompt_id}` → status.status_str=success/error |
| 查队列 | `GET /queue` → queue_running / queue_pending |
| 清空待办 | `POST /queue` body=`{"clear":true}` |
| 健康检查 | `GET /system_stats` |

## 踩坑记录（重要！）

1. **filename_prefix 必须纯 ASCII**：中文前缀会经 PS5.1 JSON 编码变成 `??`，SaveImage 报 `OSError: Invalid argument`（实测踩过）
2. **提交 body 用 UTF-8 字节**：`[Text.Encoding]::UTF8.GetBytes($json)` + ContentType `application/json; charset=utf-8`，否则提示词里的中文会乱码
3. **队列是串行的**：多任务逐个执行；提交后轮询 `/history` 直到 success/error
4. **先等模型文件就位再提交**：checkpoints 里出现完整文件（大小>1GB）再跑，否则报模型不存在
5. **任务失败要看 exception_message**：history JSON 里 `status.messages` 是嵌套数组，直接 ConvertTo-Json 后搜 `exception_message` 最省事
6. 失败任务不占队列，但会留下 error 记录；重跑前可先 `POST /queue {"clear":true}`

## 输出位置

- 图片：`$env:COMFYUI_ROOT\output\`
- ComfyUI 网页（http://127.0.0.1:8188）右侧历史也能看
