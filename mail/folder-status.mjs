// folder-status.mjs - 各文件夹邮件数量（通用 IMAP：QQ/163/新浪/Gmail/Outlook 等）
// 凭据从 deepseek-harness/.env 的 MAIL_IMAP_USER / MAIL_IMAP_PASS 读取（兼容旧 QQMAIL_* 变量名）
import { ImapFlow } from 'imapflow';
import { readFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

const envPath = process.env.DSH_WORKSPACE
  ? process.env.DSH_WORKSPACE + '/.env'
  : join(homedir(), 'deepseek-harness', '.env');
const env = readFileSync(envPath, 'utf8');
const g = (n) => { const m = env.match(new RegExp('^' + n + '=(.*)$', 'm')); return m ? m[1].trim() : ''; };

const host = g('MAIL_IMAP_HOST') || process.env.MAIL_IMAP_HOST || g('QQMAIL_IMAP_HOST') || 'imap.qq.com';
const port = parseInt(g('MAIL_IMAP_PORT') || process.env.MAIL_IMAP_PORT || g('QQMAIL_IMAP_PORT') || '993', 10);
const user = g('MAIL_IMAP_USER') || process.env.MAIL_IMAP_USER || g('QQMAIL_IMAP_USER') || process.env.QQMAIL_IMAP_USER;
const pass = g('MAIL_IMAP_PASS') || process.env.MAIL_IMAP_PASS || g('QQMAIL_IMAP_PASS') || process.env.QQMAIL_IMAP_PASS;
if (!user || !pass) { console.error('ERR: 未配置 IMAP 凭据（MAIL_IMAP_USER/MAIL_IMAP_PASS，兼容旧 QQMAIL_*）'); process.exit(1); }

const c = new ImapFlow({ host, port, secure: true, auth: { user, pass }, logger: false });
await c.connect();
console.log(`[connected] ${user} @ ${host}:${port}`);
for (const f of ['INBOX', 'Deleted Messages', 'Junk', 'Sent Messages']) {
  try { const s = await c.status(f, { messages: true, unseen: true }); console.log(`${f}: 共 ${s.messages} 封 / 未读 ${s.unseen}`); }
  catch { console.log(`${f}: 查询失败`); }
}
await c.logout();
