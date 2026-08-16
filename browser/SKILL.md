# 浏览器操作技能（browser）

> 用途：抓取网页内容 / 打开浏览器页面 / 无头浏览器自动化（填表、点击、截图）
> 依赖：Node.js >= 18 + Playwright（`npm install playwright && npx playwright install chromium`）
> 创建：2026-08-16 · 已实测验证

## 三种能力与选择

| 需求 | 用什么 | 说明 |
|---|---|---|
| 简单抓取（HTML/API/下载文件） | `Invoke-WebRequest` / `curl` | 不渲染 JS，最快 |
| 打开页面给用户看 | `Start-Process "url"` | 用系统默认浏览器打开（用户可见） |
| 自动化（填表/点击/截图/读渲染后内容） | `browser-run.mjs`（Playwright 无头 Chromium） | 本文档重点 |

## 自动化用法

```
node browser-run.mjs <url> [参数...]
```

| 参数 | 说明 |
|---|---|
| `--text` | 输出页面可见文本（前 8000 字符） |
| `--shot <路径>` | 全页截图（PNG） |
| `--fill "选择器=值"` | 填表（可多次；选择器本身含 `=` 时按**最后一个** `=` 切分；fill 失败自动兜底 JS 赋值+事件） |
| `--click <选择器>` | 点击（可多次，点击后自动等 1.2 秒） |
| `--wait <毫秒>` | 额外等待（页面跳转/异步加载） |
| `--headful` | 有头模式（弹出可见窗口，调试/反爬用） |
| `--out <路径>` | 把 `--text` 的文本另存为文件 |

示例：

```powershell
# 读页面文本
node browser-run.mjs https://www.baidu.com --text

# 搜索流程：填表 → 点击 → 等待 → 截图
node browser-run.mjs https://www.baidu.com --fill "input[name=wd]=天气预报" --click "input[type=submit]" --wait 2500 --shot C:\tmp\search.png
```

## 注意事项

1. **反爬**：部分站点对无头浏览器有限制（如百度搜索框 fill 超时）——脚本已内置兜底（JS 直接赋值），仍失败可加 `--wait` 或 `--headful`
2. **登录态**：Playwright 是无痕环境，需要登录的站点需另行处理 Cookie（暂未封装）
3. **回归验证**：修改 `browser-run.mjs` 后，先跑本地测试页确认不破坏：
   ```powershell
   node browser-run.mjs "file:///<本目录>/test-form.html" --fill "#kw=测试" --click "#btn" --text
   ```
   预期输出包含「你输入了: 测试」
4. **截图产物**：可配合 vision 技能（本地 Qwen2.5-VL）理解截图内容——"眼睛+网页"

## 与其他技能的关系

- `vision`：浏览器截图 → 视觉技能看内容
- `handover`：新增/变更本技能后记得写交接日志
