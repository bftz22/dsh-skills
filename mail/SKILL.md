# 邮件查询技能（mail）

> 用途：**IMAP 直连任意邮箱**（QQ/163/新浪/Gmail/Outlook 等），不经网页，秒级查询新邮件/未读/要紧邮件
> 工具：`~/mail-tools/`（imapflow）
> 创建：2026-08-16 · 2026-08-17 通用化（不再限定 QQ 邮箱）

## 为什么用 IMAP

IMAP 是标准邮件协议（993 SSL），用**授权码/专用密码**登录，支持绝大多数邮箱。
相比网页抓取：快（秒级）、稳（协议级接口）、不需要打开浏览器。

## 配置（安全要求）

在 `deepseek-harness\.env` 配置（**禁止**写入任何文档/日志/登记簿明文）：

| 变量 | 说明 |
|---|---|
| `MAIL_IMAP_HOST` | IMAP 服务器（如 `imap.qq.com` / `imap.163.com` / `imap.gmail.com`） |
| `MAIL_IMAP_PORT` | 端口，默认 `993`（SSL） |
| `MAIL_IMAP_USER` | 邮箱账号（如 `xxx@qq.com`） |
| `MAIL_IMAP_PASS` | **授权码**（QQ/163）或**应用专用密码**（Gmail/Outlook），非登录密码 |

> 旧变量名 `QQMAIL_IMAP_USER` / `QQMAIL_IMAP_PASS` 仍兼容（自动回退），无需迁移。

### 各邮箱 IMAP 参数速查

| 邮箱 | IMAP 服务器 | 端口 | 授权方式 |
|---|---|---|---|
| QQ 邮箱 | `imap.qq.com` | 993 | 设置→账户→开启 IMAP/SMTP→生成**授权码** |
| 163 邮箱 | `imap.163.com` | 993 | 设置→POP3/SMTP/IMAP→开启→**客户端授权密码** |
| 新浪邮箱 | `imap.sina.com` | 993 | 设置→客户端功能→开启 IMAP→授权码 |
| Gmail | `imap.gmail.com` | 993 | 需开启两步验证→**应用专用密码** |
| Outlook/Office365 | `outlook.office365.com` | 993 | 账户设置→**应用密码**（或直接登录密码） |

## 用法

```powershell
node ~/mail-tools/mail-check.mjs            # 最近 15 封（含要紧度标记）
node ~/mail-tools/mail-check.mjs --unseen   # 只看未读（0 封时直接提示）
node ~/mail-tools/mail-check.mjs --limit 5  # 最近 5 封
node ~/mail-tools/mail-check.mjs --json     # JSON 输出
node ~/mail-tools/folder-status.mjs         # 各文件夹数量
```

## 要紧度规则（mail-check 内置）

| 级别 | 判定 |
|---|---|
| **高** | 主题/发件人含：验证码、安全、security、alert、密码、password、reset、billing、invoice、登录、告警 等 |
| 中 | 普通邮件 |
| 低 | 含 unsubscribe、促销、优惠、digest、newsletter、通知、更新 等 |

## 用户问答范式

用户问「邮箱有什么要紧的」→ 跑 `mail-check.mjs --unseen --limit 10` →
按优先级汇报：先列「高」的（验证码/安全类），再说其他未读/最近邮件。

## 部署说明（面向新用户）

邮件查询是**可选能力**：默认不装；用户明确需要时，问清邮箱类型 → 引导开启 IMAP 并生成授权码 → 写入 `.env`（MAIL_IMAP_*）→ 测试查 3 封邮件验收。

## 待办/可选增强

- 常驻监控：`mail-watch.mjs` 每 5 分钟增量拉取 + 缓存，实现「新邮件自动提醒」（未实现，按需加）
