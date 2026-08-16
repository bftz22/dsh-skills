// browser-run.mjs - Playwright 浏览器操作统一入口
// 用法: node browser-run.mjs <url> [--text] [--shot <路径>] [--wait <毫秒>]
//       [--click <选择器>] [--fill <选择器>=<值>] [--headful] [--out <文本输出文件>]
// 示例:
//   node browser-run.mjs https://www.baidu.com --text --shot C:\tmp\baidu.png
//   node browser-run.mjs https://example.com --fill "input[name=q]=hello" --click "button[type=submit]" --text
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';

const here = dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const a = { url: null, text: false, shot: null, wait: 0, clicks: [], fills: [], headful: false, out: null };
  for (let i = 0; i < argv.length; i++) {
    const v = argv[i];
    if (v === '--text') a.text = true;
    else if (v === '--headful') a.headful = true;
    else if (v === '--shot') a.shot = argv[++i];
    else if (v === '--wait') a.wait = parseInt(argv[++i], 10) || 0;
    else if (v === '--click') a.clicks.push(argv[++i]);
    else if (v === '--fill') a.fills.push(argv[++i]);
    else if (v === '--out') a.out = argv[++i];
    else if (!a.url) a.url = v;
  }
  return a;
}

const a = parseArgs(process.argv.slice(2));
if (!a.url) { console.error('缺少 URL'); process.exit(1); }

const browser = await chromium.launch({ headless: !a.headful });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const t0 = Date.now();
  await page.goto(a.url, { waitUntil: 'domcontentloaded', timeout: 45000 });
  console.log(`[loaded] ${a.url} (${Date.now() - t0}ms)`);

  for (const f of a.fills) {
    const eq = f.lastIndexOf('='); // 选择器可能含 '='（如 input[name=wd]），按最后一个切分
    if (eq < 0) { console.error(`--fill 格式应为 选择器=值: ${f}`); continue; }
    const sel = f.slice(0, eq), val = f.slice(eq + 1);
    try {
      await page.fill(sel, val, { timeout: 8000 });
    } catch {
      // 兜底：直接赋值 + 派发 input/change 事件（部分站点对 headless fill 有限制）
      await page.$eval(sel, (el, v) => {
        el.value = v;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      }, val);
    }
    console.log(`[fill] ${sel} = ${val}`);
  }
  for (const sel of a.clicks) {
    await page.click(sel, { timeout: 15000 });
    console.log(`[click] ${sel}`);
    await page.waitForTimeout(1200);
  }
  if (a.wait > 0) await page.waitForTimeout(a.wait);

  const title = await page.title();
  console.log(`[title] ${title}`);

  if (a.text) {
    const text = await page.evaluate(() => document.body ? document.body.innerText.slice(0, 8000) : '');
    console.log(`[text] ${text.replace(/\n{3,}/g, '\n\n')}`);
    if (a.out) writeFileSync(resolve(a.out), text, 'utf8');
  }
  if (a.shot) {
    mkdirSync(dirname(resolve(a.shot)), { recursive: true });
    await page.screenshot({ path: resolve(a.shot), fullPage: true });
    console.log(`[shot] ${a.shot}`);
  }
} finally {
  await browser.close();
}
