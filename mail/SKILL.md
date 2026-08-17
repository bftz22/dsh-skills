# 邮件查询技能（mail）

> 用途：**IMAP 直连 QQ 邮箱**，不经网页，秒级查询新邮件/未读/要紧邮件
> 工具：`<dsh>\skills\mail\`（mail-check.mjs / folder-status.mjs，依赖 imapflow）
> 创建：2026-08-16 · 已实测（连接成功、文件夹状态正常）

## 为什么用 IMAP

QQ 邮箱支持 IMAP 标准协议（imap.qq.com:993 SSL），用**授权码**登录（非登录密码）。
相比网页抓取：快（秒级）、稳（协议级接口）、不需要打开浏览器。

## 凭据（安全要求）

- 账号：`QQMAIL_IMAP_USER`（你的QQ邮箱地址）
- 授权码：`QQMAIL_IMAP_PASS`（存于 `<dsh>\.env`，**禁止**写入任何文档/日志明文）
- 授权码可随时在 QQ 邮箱网页「设置→账户→开启 IMAP/SMTP」处吊销

## 用法

```powershell
node skills\mail\mail-check.mjs            # 最近 15 封（含要紧度标记）
node skills\mail\mail-check.mjs --unseen   # 只看未读（0 封时直接提示）
node skills\mail\mail-check.mjs --limit 5  # 最近 5 封
node skills\mail\mail-check.mjs --json     # JSON 输出
node skills\mail\folder-status.mjs         # 各文件夹数量
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

## 待办/可选增强

- 常驻监控：`mail-watch.mjs` 每 5 分钟增量拉取 + 缓存，实现「新邮件自动提醒」（未实现，按需加）
- 其他邮箱（163/新浪）可同样方式接入（各自 IMAP 服务器 + 授权码）
