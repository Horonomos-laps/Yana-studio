// Kiểm tra hàng đợi lời nhắc của panel chat (media/prompt-queue.js) và việc nó được nối vào panel.
// Dùng: node tests/prompt-queue.test.cjs <đường dẫn tới extensions/yana-agent>
// Chỉ kiểm logic thuần và cấu trúc nối dây. Việc bấm thật trong cửa sổ Studio phải thử bằng tay.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ext = path.resolve(process.argv[2] || path.resolve(__dirname, '../extensions/yana-agent'));
const queue = require(path.join(ext, 'media/prompt-queue.js'));

let pass = 0;
let fail = 0;
const check = (name, ok, extra = '') => { (ok ? pass++ : fail++); console.log(ok ? 'PASS' : 'FAIL', name, ok ? '' : extra); };
const item = (id, text = id) => ({ id, text, images: [], files: [], mode: 'act' });
const ids = state => state.items.map(entry => entry.id).join(',');
const build = (...names) => names.reduce((state, name) => queue.enqueue(state, item(name)), queue.create());

// --- xếp hàng cơ bản ---
const abc = build('a', 'b', 'c');
check('enqueue keeps arrival order', ids(abc) === 'a,b,c');
const before = ids(abc);
queue.enqueue(abc, item('d')); queue.remove(abc, 'a'); queue.move(abc, 'a', 1); queue.pause(abc, 'x');
check('operations never mutate the previous state', ids(abc) === before && abc.items.length === 3 && abc.paused === false);
check('first() is the oldest item and an empty queue has none', queue.first(abc).id === 'a' && queue.first(queue.create()) === undefined);

// --- giới hạn ---
let full = queue.create();
for (let i = 0; i < queue.MAX_ITEMS; i += 1) full = queue.enqueue(full, item(`i${i}`));
check('queue holds exactly MAX_ITEMS', full.items.length === queue.MAX_ITEMS);
check('enqueue on a full queue returns the same state (caller can detect it)', queue.enqueue(full, item('extra')) === full);

// --- sắp xếp, xoá ---
check('move down and up swap neighbours', ids(queue.move(abc, 'a', 1)) === 'b,a,c' && ids(queue.move(abc, 'c', -1)) === 'a,c,b');
check('move past either end changes nothing', queue.move(abc, 'a', -1) === abc && queue.move(abc, 'c', 1) === abc && queue.move(abc, 'missing', 1) === abc);
check('remove drops one item, removing the last one resets to an empty queue', ids(queue.remove(abc, 'b')) === 'a,c' && queue.remove(build('a'), 'a').items.length === 0);
check('clear empties the queue', queue.clear().items.length === 0);
check('dropFirst removes the oldest item and resets when it was the last', ids(queue.dropFirst(abc)) === 'b,c' && queue.dropFirst(build('a')).paused === false);

// --- tạm dừng ---
const paused = queue.pause(abc, 'stopped');
check('pause records the reason', paused.paused === true && paused.note === 'stopped');
check('pausing an empty queue is a no-op (no stale flag for the next enqueue)', queue.pause(queue.create(), 'x').paused === false);
check('resume clears the pause and its reason', queue.resume(paused).paused === false && queue.resume(paused).note === '');
check('first enqueue into an empty queue clears an old pause', queue.enqueue({ items: [], paused: true, note: 'old' }, item('a')).paused === false);
check('enqueue into a paused non-empty queue stays paused', queue.enqueue(paused, item('d')).paused === true);

// --- chính sách afterTurn: phần an toàn nhất ---
const policy = (state, outcome) => queue.afterTurn(state, outcome);
check('nothing queued: idle whatever happened', ['completed', 'paused', 'cancelled', 'error', null].every(outcome => policy(queue.create(), outcome) === 'idle'));
check('completed turn sends the next queued message', policy(abc, 'completed') === 'send');
check('a turn paused for approval never sends (the approval is still pending)', policy(abc, 'paused') === 'wait');
check('cancelled and failed turns pause the queue instead of sending', policy(abc, 'cancelled') === 'pause' && policy(abc, 'error') === 'pause');
check('unknown or missing outcome fails closed: pause, never send', policy(abc, null) === 'pause' && policy(abc, undefined) === 'pause' && policy(abc, 'surprise') === 'pause');
check('an already paused queue waits even after a completed turn', policy(paused, 'completed') === 'wait');

// --- nối dây vào panel ---
const mediaDir = path.join(ext, 'media');
const panel = fs.readFileSync(path.join(mediaDir, 'panel.js'), 'utf8');
const host = fs.readFileSync(path.join(ext, 'extension.js'), 'utf8');
let syntaxOk = true;
let syntaxErr = '';
for (const file of ['panel.js', 'prompt-queue.js']) {
	try { execFileSync(process.execPath, ['--check', path.join(mediaDir, file)], { stdio: 'pipe' }); } catch (error) { syntaxOk = false; syntaxErr = String(error.stderr || error.message); }
}
check('panel.js and prompt-queue.js parse', syntaxOk, syntaxErr);
check('the webview loads prompt-queue.js before panel.js', host.indexOf('${promptQueueJs}') > -1 && host.indexOf('${promptQueueJs}') < host.lastIndexOf('${js}'));
check('panel.js uses the queue module', panel.includes('window.YanaPromptQueue') && panel.includes('promptQueue.afterTurn'));
check('Enter while busy no longer cancels the turn directly (it queues or goes through stopTurn)', !/function submit\(\)\s*\{\s*if \(ui\.busy\) \{\s*vscode\.postMessage\(\{ type: 'stop' \}\)/.test(panel));
check('every Stop path pauses the queue (Escape and the send button go through stopTurn)', panel.includes("else if (ui.busy) stopTurn();") && panel.includes("queue = promptQueue.pause(queue, 'stopped');"));
check('the turn end reason is recorded for completed, paused, cancelled and error', ["ui.lastEnd = 'completed'", "ui.lastEnd = 'paused'", "ui.lastEnd = 'cancelled'", "ui.lastEnd = 'error'"].every(text => panel.includes(text)));
check('a conversation change pauses the queue', panel.includes("promptQueue.pause(queue, 'conversation changed')"));
// Lỗi có sẵn trên origin/main: biến này chưa từng được khai báo, mà panel.js chạy 'use strict' nên mỗi lần gửi đều ném ReferenceError.
check('panel.js no longer assigns the undeclared attachedImages (strict mode throws after every send)', !panel.includes('attachedImages'));
// Mọi biến mà clearComposer() gán phải được khai báo bằng let/const trong panel.js.
const clearBody = (/function clearComposer\(\) \{([\s\S]*?)\n\t\}/.exec(panel) || [])[1] || '';
const assigned = [...clearBody.matchAll(/^\s*([A-Za-z_]\w*)\s*=[^=]/gm)].map(m => m[1]);
check('every variable clearComposer() assigns is declared', assigned.length > 0 && assigned.every(name => new RegExp(`\\b(let|var)\\s+${name}\\b`).test(panel)), assigned.join(','));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
