# QQ 渠道 Skill（qq-bridge 技能包）
> 开源级别：**open（可开源）**——已/可同步至 dsh-skills 公开仓库

> 用途：给 AI「QQ 出口」——通过本机 NapCat（小号 3773288651「贤臣」在线挂机）向主公 QQ 号发送私聊消息、查询贤臣在线状态与好友列表、**接收主公 QQ 发来的图片**
> 目录：`{WORKSPACE}\skills\qq\`
> 创建：2026-08-17（配合 D:\qq-bridge 部署，Chatbox 渠道 → QQ 渠道）
> 依赖：NapCat 运行中（端口 3000）、凭据在 `.env`（NAPCAT_API / NAPCAT_TOKEN）

## 脚本一览

| 脚本 | 能力 | 用法 |
|---|---|---|
| `qq-send.ps1` | 给指定 QQ 号发私聊消息 | `-UserId 3565728847 -Message "你好"` |
| `qq-info.ps1` | 查询贤臣登录状态 / 好友列表 | `-Friends`（列好友） |

## 调用示例

```powershell
# 给主公发一条 QQ 消息
powershell -File qq-send.ps1 -UserId 3565728847 -Message "主公，贤臣在 Chatbox 给您捎话：任务已完成"

# 查询贤臣在线状态（账号/昵称）
powershell -File qq-info.ps1

# 列出贤臣好友
powershell -File qq-info.ps1 -Friends
```

## 收图（2026-08-17 新增，qq-bridge.mjs 内置）

- **机制**：主公（白名单大号）给贤臣小号发图片 → NapCat 上报 → qq-bridge 自动下载保存到
  `{DOWNLOADS}\QQ收图\`，文件名 `QQ-<YYYYMMDDHHmmss>-<QQ号>.<ext>`；元信息写 `latest.json`
  （时间/发送者/文件名/路径），每次收图覆盖
- **带斜杠指令的图片**：先收图，再照常执行指令（如 `/贤臣 看看这张图`）
- **AI 侧查看流程**（主公在 Chatbox 说「看QQ收的图」时）：
  1. 读 `{DOWNLOADS}\QQ收图\latest.json` 拿最新图片路径（没有则列出目录最新 5 张让主公选）
  2. 用 `skills\vision\` 技能识别图片内容（OCR / 本地 VLM / 云端 API），按需汇报
- **排障**：收图失败先看 qq-bridge 窗口日志（`复制图片缓存失败`/`下载图片失败 HTTP xxx`）；
  `get_image` 拿本地缓存失败会自动回退到直连下载 url

## 可发消息的 QQ（贤臣好友，已确认）

| QQ | 昵称 | 说明 |
|---|---|---|
| 3565728847 | 比方 | 主公大号（白名单） |
| 2374387456 | — | 主公大号（白名单） |

> 发消息前确认目标号在贤臣好友列表（`qq-info.ps1 -Friends`），非好友私聊会失败。

## 依赖与环境

| 项目 | 位置 |
|---|---|
| NapCat HTTP API | `http://127.0.0.1:3000`（.env 的 `NAPCAT_API`） |
| 访问 token | .env 的 `NAPCAT_TOKEN`（与 qq-bridge.bat 一致） |
| 桥接脚本 | `D:\qq-bridge\qq-bridge.mjs`（8788 收上报，白名单双大号） |
| 收图目录 | `{DOWNLOADS}\QQ收图\`（latest.json 记录最新一张） |

## 注意事项

1. **前置检查**：调用前先 `qq-info.ps1` 确认贤臣在线（NapCat 3000 端口通）；NapCat 重启后 QQ 需重新扫码登录
2. **消息内容**：纯文本；含特殊字符时用单引号包裹；消息长度建议 ≤1500 字（超出 QQ 限制会失败）
3. **隐私**：QQ 消息会经过腾讯服务器，敏感内容（密钥/密码）严禁通过 QQ 发送
4. **只发不读**：本技能只负责「发消息」「查状态」「收主公的图」，不读取 QQ 聊天记录（qq-bridge 侧的白名单与斜杠指令体系不变）
