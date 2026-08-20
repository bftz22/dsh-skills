# IDM 多线程下载 Skill（idm-download）
> 开源级别：**open（可开源）**——已/可同步至 dsh-skills 公开仓库

> 用途：用 Internet Download Manager（IDM）多线程下载文件——**突破 CDN 单连接限速**（2026-08-16 实战：Modrinth CDN 对本机 IP 限速 1.8KB/s，curl/Node fetch 全部挂起，IDM 多线程 173 秒下完 82.5MB/23 个文件）
> 目录：`{WORKSPACE}\skills\idm\`
> 创建：2026-08-17（香草纪元整合包部署实战提炼）

## 适用场景

- 大文件 / 慢速下载（<100KB/s）挂起、断流、超时
- 单连接工具（curl / Invoke-WebRequest / Node fetch）失败的 URL
- 批量下载队列（URL 列表文件）
- 需要断点续传 / 多线程加速 / 下载后 sha1 校验

## 前置条件

1. **IDM 已安装**：`{IDM_DIR}\IDMan.exe`（开机自启，通常已在运行；未运行脚本会自动拉起）
2. **PowerShell 5.1**；脚本输出为 ASCII（无中文编码问题）

## 脚本一览

| 脚本 | 作用 | 关键参数 |
|---|---|---|
| `idm-download.ps1` | 单文件下载 + 等待完成 + 可选 sha1 校验 | -Url 必填；-Dir -File -Sha1 -TimeoutSec |
| `idm-batch.ps1` | URL 列表批量排队下载 | -ListFile 必填；-Wait -Sha1File -TimeoutSec |

## 调用示例

```powershell
# 单文件：下载到指定目录并等待完成（默认 {DOWNLOADS}）
powershell -File idm-download.ps1 -Url "https://cdn.modrinth.com/data/xxx/versions/yyy/file.jar" -Dir "H:\PCL\.minecraft\mods" -File "file.jar"

# 带 sha1 校验（不匹配会重试并报告）
powershell -File idm-download.ps1 -Url "https://..." -Dir "{DOWNLOADS}" -Sha1 "52570f40e0fde4f5b0402174e170360d4f463e4b"

# 批量：列表文件每行一条 URL（支持 URL|目录|文件名 三列，| 分隔）
powershell -File idm-batch.ps1 -ListFile "{DOWNLOADS}\urls.txt" -Wait

# 批量 + sha1 校验（每行：本地文件路径|sha1）
powershell -File idm-batch.ps1 -ListFile "{DOWNLOADS}\urls.txt" -Sha1File "{DOWNLOADS}\sha1s.txt" -Wait
```

## 列表文件格式（idm-batch）

```
# 注释行以 # 开头，空行跳过
https://example.com/a.zip
https://example.com/b.zip|{DOWNLOADS}\sub|b.zip
https://example.com/c.jar|H:\PCL\.minecraft\mods|c.jar
```

- 每行 1~3 列，用 `|` 分隔：URL | 保存目录 | 保存文件名
- 缺省目录 = `{DOWNLOADS}`；缺省文件名 = URL 最后一段
- Sha1File 每行：`本地完整路径|sha1`，下载完成后逐行校验

## 工作原理（实战经验）

- **IDM 命令行**：`IDMan.exe /d <URL> /p <目录> /f <文件名> /n /s`
  - `/n` 不弹对话框直接开始；`/s` 开始队列；**不要加 `/q`**（会退出 IDM，可能中断队列）
- **多线程**：IDM 默认 8~16 连接，能突破单连接限速（Modrinth CDN 实测 1.8KB/s → 300KB/s+）
- **等待完成**：脚本轮询目标文件（存在 + 大小增长停止），再按 sha1 校验（如有）
- **幂等**：目标文件已存在且（校验通过 / 未给 Sha1 时大小>0）→ 跳过不重下

## 注意事项

1. IDM 未运行时第一次调用会弹窗（自动启动），等 5~10 秒再排队
2. 文件名含 `+` `%20` 等特殊字符：URL 保持编码原样（如 `%2B`），-File 给解码后的真实文件名（如 `a+b.jar`）
3. 下载完成后若 sha1 不匹配：脚本自动删除重下（最多 3 轮），仍失败则输出 FAIL
4. IDM 下载到 `D:\idm\...` 的默认目录配置不影响 `/p` 指定目录
5. 队列任务在 IDM 进程里顺序/并发执行；批量大文件时轮询间隔 10 秒

## 故障排查

| 现象 | 原因与处理 |
|---|---|
| 排队后文件长时间不出现 | IDM 未运行或弹窗等待确认 → 检查进程，重新调用（脚本会自动拉起） |
| 一直下载中（大小不增长） | CDN 断流 → 等 IDM 自动重试；仍不行换 URL 源（备用 CDN / 镜像） |
| sha1 反复不匹配 | 文件被 CDN 截断 → IDM 会重试；确认 URL 与期望版本一致 |
| IDM 崩溃 | 重新 Start-Process IDMan.exe 后重排队列（队列任务需重新 /d） |
