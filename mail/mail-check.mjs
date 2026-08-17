// mail-check.mjs - IMAP 直连 QQ 邮箱查询（不经网页）
// 用法: node mail-check.mjs [--unseen] [--limit N] [--folders] [--json] [--download <目录>] [--route [关键词]]
// --download <目录>: 下载最近 --limit 封邮件中的附件到指定目录（用于收取诊断文件等）
// --route [关键词]: 分流模式——主题含关键词（默认"诊断信息"）的邮件：附件下载到
//    %USERPROFILE%\AI交接指南\04_报告\报错收集\ 并将邮件移入 IMAP 文件夹"报错收集"（自动创建），
//    与正常邮件分离，不混在收件箱。关键词可带参：--route "报错|诊断"
// 凭据从 <dsh>/.env 的 QQMAIL_IMAP_USER / QQMAIL_IMAP_PASS 读取
import { ImapFlow } from 'imapflow';
import { readFileSync, createWriteStream, mkdirSync, existsSync } from 'fs';
import { join } from 'path';
import os from 'os';

const args = process.argv.slice(2);
const opt = {
  unseen: args.includes('--unseen'),
  folders: args.includes('--folders'),
  json: args.includes('--json'),
  limit: 15,
};
const li = args.indexOf('--limit');
if (li >= 0) opt.limit = parseInt(args[li + 1], 10) || 15;
const di = args.indexOf('--download');
if (di >= 0) opt.download = args[di + 1] || 'attachments';
if (opt.download) mkdirSync(opt.download, { recursive: true });
// --route [关键词]：关键词可选（--route 后跟非--开头的参数）
const ri = args.indexOf('--route');
if (ri >= 0) {
  opt.route = true;
  if (args[ri + 1] && !args[ri + 1].startsWith('--')) opt.routeKeyword = args[ri + 1];
}
const ROUTE_FOLDER = '报错收集';
const ROUTE_DIR = join(os.homedir(), 'AI交接指南', '04_报告', '报错收集');
if (opt.route) mkdirSync(ROUTE_DIR, { recursive: true });

// 附件文件名解码（=?UTF-8?B?...?= 与 =?GBK?B?...?=）
function decodeMimeWord(s) {
  if (!s) return s;
  const m = s.match(/=\?([^?]+)\?([BQ])\?([^?]*)\?=/i);
  if (!m) return s;
  const [, charset, enc, data] = m;
  try {
    if (enc.toUpperCase() === 'B') {
      const buf = Buffer.from(data, 'base64');
      return buf.toString(charset || 'utf8');
    }
    const q = data.replace(/_/g, ' ').replace(/=([0-9A-Fa-f]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
    return Buffer.from(q, 'latin1').toString(charset || 'utf8');
  } catch { return s; }
}

// 读 .env（默认桥工作区；可用 --env 指定）
const envPath = process.env.DSH_WORKSPACE
  ? process.env.DSH_WORKSPACE + '/.env'
  : join(os.homedir(), 'deepseek-harness', '.env');
const envText = readFileSync(envPath, 'utf8');
const getEnv = (n) => {
  const m = envText.match(new RegExp('^' + n + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};
const user = getEnv('QQMAIL_IMAP_USER') || process.env.QQMAIL_IMAP_USER;
const pass = getEnv('QQMAIL_IMAP_PASS') || process.env.QQMAIL_IMAP_PASS;
if (!user || !pass) { console.error('ERR: 未配置 QQMAIL_IMAP_USER/PASS'); process.exit(1); }

// 要紧度规则
const HIGH = /验证码|安全|security|alert|密码|password|reset|billing|invoice|验证|verify|authenticat|登录|sign\s*in|告警/i;
const LOW = /unsubscribe|促销|优惠|digest|newsletter|sale|discount|周刊|月报|日报|通知|更新|公告/i;
function priority(subject, from) {
  const s = `${subject} ${from}`;
  if (LOW.test(s) && !HIGH.test(s)) return '低';
  if (HIGH.test(s)) return '高';
  return '中';
}

// 兼容 imapflow 的 flags（旧版数组 / 新版 Set）
function hasFlag(m, name) {
  const f = m.flags || [];
  if (typeof f.includes === 'function') return f.includes(name);
  if (typeof f.has === 'function') return f.has(name);
  return false;
}

// 扫描"报错收集"文件夹：收取所有附件（配合网页收信规则直达场景，无需移动）
async function routeOnly(client) {
  let downloaded = 0;
  try {
    await client.mailboxCreate(ROUTE_FOLDER);
  } catch { /* 已存在则忽略 */ }
  try {
    const lock2 = await client.getMailboxLock(ROUTE_FOLDER);
    try {
      const st2 = await client.status(ROUTE_FOLDER, { messages: true });
      if (st2.messages > 0) {
        console.log(`  [${ROUTE_FOLDER}] ${st2.messages} 封（网页规则直达或已移入）`);
        // 先完整收集消息，再下载（在 fetch 迭代器循环体内直接 download 会挂起）
        const msgs2 = [];
        for await (const m2 of client.fetch('1:*', { uid: true, bodyStructure: true, envelope: true })) {
          msgs2.push(m2);
        }
        for (const m2 of msgs2) {
          const parts2 = [];
          const walk2 = (node) => {
            if (!node) return;
            const isLeaf = !node.childNodes || node.childNodes.length === 0;
            const isText = node.type && String(node.type).startsWith('text/');
            if (isLeaf && !isText && node.part) parts2.push(node);
            if (node.childNodes) node.childNodes.forEach(walk2);
          };
          walk2(m2.bodyStructure);
          for (const part of parts2) {
            const rawName = (part.parameters && (part.parameters.name || part.parameters.filename)) || `part-${m2.uid}-${part.part}`;
            const fname = decodeMimeWord(rawName).replace(/[\\/:*?"<>|]/g, '_');
            const dest = join(ROUTE_DIR, `${m2.uid}-${fname}`);
            try {
              const { content } = await client.download(m2.uid, part.part, { uid: true });
              const ws = createWriteStream(dest);
              for await (const chunk of content) ws.write(chunk);
              await new Promise((res, rej) => { ws.on('finish', res); ws.on('error', rej); ws.end(); });
              console.log(`    [附件] ${dest}`);
              downloaded++;
            } catch (e) {
              console.log(`    [附件失败] ${e.message}`);
            }
          }
        }
      }
    } finally { lock2.release(); }
  } catch (e) {
    console.log(`  [${ROUTE_FOLDER} 扫描失败] ${e.message}`);
  }
  return downloaded;
}

const client = new ImapFlow({
  host: 'imap.qq.com', port: 993, secure: true,
  auth: { user, pass },
  logger: false,
});

try {
  await client.connect();
  console.log(`[connected] ${user} @ imap.qq.com:993`);

  if (opt.folders) {
    const list = await client.list();
    console.log('--- 文件夹 ---');
    for (const f of list) {
      const fl = Array.isArray(f.flags) ? f.flags.join(',') : '';
      console.log(`  ${f.path}${fl ? ' (' + fl + ')' : ''}`);
    }
  }

  // INBOX 状态
  const status = await client.status('INBOX', { messages: true, unseen: true });
  console.log(`[INBOX] 总 ${status.messages} 封 / 未读 ${status.unseen} 封`);

  if (opt.unseen && status.unseen === 0) {
    console.log('（没有未读邮件）');
  } else if (status.messages === 0) {
    console.log('（收件箱为空）');
    // 分流模式下仍继续扫描"报错收集"文件夹
    if (opt.route) await routeOnly(client);
  } else {
    const lock = await client.getMailboxLock('INBOX');
    try {
      const from = Math.max(1, status.messages - opt.limit + 1);
      const range = `${from}:*`;
      const msgs = [];
      const fetchQuery = { envelope: true, flags: true, uid: true };
      if (opt.download || opt.route) fetchQuery.bodyStructure = true;
      for await (const m of client.fetch(range, fetchQuery)) {
        msgs.push(m);
      }
      msgs.sort((a, b) => b.uid - a.uid);
      const rows = msgs.map((m) => {
        const env = m.envelope || {};
        const fromAddr = (env.from && env.from[0]) ? `${env.from[0].name || ''} <${env.from[0].address || ''}>` : '';
        const date = env.date ? new Date(env.date) : null;
        return {
          uid: m.uid,
          seen: hasFlag(m, '\\Seen'),
          from: fromAddr,
          subject: (env.subject || '').slice(0, 120),
          date: date ? date.toISOString().replace('T', ' ').slice(0, 16) : '',
          priority: priority(env.subject || '', fromAddr),
        };
      });
      if (opt.json) {
        console.log(JSON.stringify({ status, mails: rows }, null, 1));
      } else {
        console.log('--- 最近邮件 ---');
        for (const r of rows) {
          const mark = r.seen ? ' ' : '●';
          console.log(`[${r.priority}]${mark} ${r.date} ${r.from}`);
          console.log(`     ${r.subject}`);
        }
      }

      // 下载附件（--download <目录>）
      if (opt.download) {
        console.log(`--- 下载附件到 ${opt.download} ---`);
        let got = 0;
        for (const m of msgs) {
          const parts = [];
          const walk = (node) => {
            if (!node) return;
            // 附件 = 叶子节点（无子节点）且非 text/*（QQ 服务器不返回 disposition，用类型判断）
            const isLeaf = !node.childNodes || node.childNodes.length === 0;
            const isText = node.type && String(node.type).startsWith('text/');
            if (isLeaf && !isText && node.part) parts.push(node);
            if (node.childNodes) node.childNodes.forEach(walk);
          };
          walk(m.bodyStructure);
          for (const part of parts) {
            const rawName = (part.parameters && (part.parameters.name || part.parameters.filename)) || `part-${m.uid}-${part.part}`;
            const fname = decodeMimeWord(rawName).replace(/[\\/:*?"<>|]/g, '_');
            const dest = join(opt.download, `${m.uid}-${fname}`);
            try {
              const { content } = await client.download(m.uid, part.part, { uid: true });
              const ws = createWriteStream(dest);
              for await (const chunk of content) ws.write(chunk);
              await new Promise((res, rej) => { ws.on('finish', res); ws.on('error', rej); ws.end(); });
              console.log(`  [附件] ${dest}`);
              got++;
            } catch (e) {
              console.log(`  [失败] uid=${m.uid} part=${part.part}: ${e.message}`);
            }
          }
        }
        console.log(`共下载 ${got} 个附件`);
      }

      // 分流模式（--route）：主题含关键词的邮件 → 附件存报错收集目录 + 邮件移入"报错收集"文件夹
      if (opt.route) {
        const kw = opt.routeKeyword || '诊断信息';
        console.log(`--- 分流模式（关键词: ${kw}）---`);
        // 确保目标文件夹存在
        try { await client.mailboxCreate(ROUTE_FOLDER); } catch { /* 已存在则忽略 */ }
        let routed = 0, downloaded = 0;
        // 1) 收件箱：命中 → 下载附件 + 移入"报错收集"
        for (const m of msgs) {
          const subj = (m.envelope && m.envelope.subject) || '';
          if (!subj.includes(kw)) continue;
          console.log(`  [命中] uid=${m.uid} 主题: ${subj.slice(0, 60)}`);
          // 1) 下载附件到报错收集目录
          const parts = [];
          const walk = (node) => {
            if (!node) return;
            const isLeaf = !node.childNodes || node.childNodes.length === 0;
            const isText = node.type && String(node.type).startsWith('text/');
            if (isLeaf && !isText && node.part) parts.push(node);
            if (node.childNodes) node.childNodes.forEach(walk);
          };
          walk(m.bodyStructure);
          for (const part of parts) {
            const rawName = (part.parameters && (part.parameters.name || part.parameters.filename)) || `part-${m.uid}-${part.part}`;
            const fname = decodeMimeWord(rawName).replace(/[\\/:*?"<>|]/g, '_');
            const dest = join(ROUTE_DIR, `${m.uid}-${fname}`);
            try {
              const { content } = await client.download(m.uid, part.part, { uid: true });
              const ws = createWriteStream(dest);
              for await (const chunk of content) ws.write(chunk);
              await new Promise((res, rej) => { ws.on('finish', res); ws.on('error', rej); ws.end(); });
              console.log(`    [附件] ${dest}`);
              downloaded++;
            } catch (e) {
              console.log(`    [附件失败] ${e.message}`);
            }
          }
          // 2) 移动邮件到"报错收集"文件夹（与正常邮件分离）
          try {
            await client.messageMove(String(m.uid), ROUTE_FOLDER, { uid: true });
            console.log(`    [已移入] ${ROUTE_FOLDER}`);
            routed++;
          } catch (e) {
            console.log(`    [移动失败] ${e.message}（附件已保留，邮件仍在收件箱）`);
          }
        }
        // 2) "报错收集"文件夹：收取所有附件（配合网页收信规则直达场景，无需移动）
        downloaded += await routeOnly(client);
        console.log(`分流完成：命中 ${routed} 封，附件 ${downloaded} 个 → ${ROUTE_DIR}`);
      }
    } finally {
      lock.release();
    }
  }
  await client.logout();
} catch (e) {
  console.error('ERR: ' + e.message);
  process.exit(1);
}
