// folder-status.mjs - 各文件夹邮件数量
import { ImapFlow } from 'imapflow';
import { readFileSync } from 'fs';
import { join } from 'path';
import os from 'os';
const env = readFileSync(join(os.homedir(), 'deepseek-harness', '.env'), 'utf8');
const g = (n) => { const m = env.match(new RegExp('^' + n + '=(.*)$', 'm')); return m ? m[1].trim() : ''; };
const c = new ImapFlow({ host: 'imap.qq.com', port: 993, secure: true, auth: { user: g('QQMAIL_IMAP_USER'), pass: g('QQMAIL_IMAP_PASS') }, logger: false });
await c.connect();
for (const f of ['INBOX', 'Deleted Messages', 'Junk', 'Sent Messages']) {
  try { const s = await c.status(f, { messages: true, unseen: true }); console.log(`${f}: 共 ${s.messages} 封 / 未读 ${s.unseen}`); }
  catch { console.log(`${f}: 查询失败`); }
}
await c.logout();
