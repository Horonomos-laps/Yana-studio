// Màn Lịch sử trong panel: danh sách gọn từ features/conversations.js và phần nối trong panel.
const assert = require('node:assert');
const Module = require('node:module');
const fs = require('node:fs');
const path = require('node:path');

const ext = path.resolve(process.argv[2] || path.join(__dirname, '../extensions/yana-agent'));
const storage = new Map();
const fakeVscode = {
	EventEmitter: class { constructor() { this.listeners = []; } get event() { return fn => { this.listeners.push(fn); return { dispose() {} }; }; } fire(value) { this.listeners.forEach(fn => fn(value)); } dispose() {} },
	TreeItem: class { constructor(label) { this.label = label; } },
	TreeItemCollapsibleState: { None: 0 },
	ThemeIcon: class { constructor(id) { this.id = id; } },
	window: { createTreeView: () => ({ dispose() {} }), showQuickPick: async () => { throw new Error('quick pick should not open'); } },
	commands: { registerCommand: (id, fn) => { registered[id] = fn; return { dispose() {} }; }, executeCommand: async () => undefined },
};
const registered = {};
const resolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) { return request === 'vscode' ? 'vscode' : resolve.call(this, request, ...rest); };
require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: fakeVscode };
const conversations = require(path.join(ext, 'features/conversations.js'));

(async () => {
	conversations.activate({ subscriptions: [], workspaceState: { get: (k, d) => (storage.has(k) ? storage.get(k) : d), update: async (k, v) => storage.set(k, v) } });
	assert.deepStrictEqual(conversations.summaries(), []);
	console.log('PASS empty history gives an empty list');

	const first = await conversations.create('');
	await new Promise(done => setTimeout(done, 5));
	const second = await conversations.create('');
	assert.deepStrictEqual(conversations.summaries().map(item => item.id), [second.id, first.id]);
	await conversations.pin(first.id, true);
	assert.deepStrictEqual(conversations.summaries().map(item => [item.id, item.pinned]), [[first.id, true], [second.id, false]]);
	console.log('PASS pinned conversations come first');

	const state = storage.get('yana.conversations.v1');
	state.list.find(c => c.id === second.id).messages = [{ role: 'user', content: 'câu hỏi' }, { role: 'assistant', content: `  dòng một\r\n\tdòng hai ${'a'.repeat(65536)}` }];
	const summary = conversations.summaries().find(item => item.id === second.id);
	assert.strictEqual(summary.preview.length, 140);
	assert.ok(summary.preview.startsWith('dòng một dòng hai'), summary.preview.slice(0, 40));
	assert.ok(!('messages' in summary) && !('system' in summary), 'the webview must not receive full messages');
	console.log('PASS the list carries a short preview and no full messages');

	for (const bad of ['', '../x', 'a'.repeat(65536), '__proto__']) await conversations.pin(bad, true);
	assert.strictEqual(conversations.summaries().filter(item => item.pinned).length, 1);
	console.log('PASS unknown ids change nothing');

	let opened = 0;
	conversations.setHistoryOpener(() => { opened += 1; });
	await registered['yana.chat.history']();
	assert.strictEqual(opened, 1);
	console.log('PASS the history command opens the panel screen');

	const panel = fs.readFileSync(path.join(ext, 'media/panel.js'), 'utf8');
	const host = fs.readFileSync(path.join(ext, 'extension.js'), 'utf8');
	assert.match(panel, /window\.yanaHistory\.create/);
	assert.match(panel, /data\?\.type === 'history'/);
	assert.ok(host.indexOf('src="${historyJs}"') < host.indexOf('src="${js}"') && host.includes('src="${historyJs}"'), 'history script loads before the panel');
	assert.ok(host.includes('src="${promptQueueJs}"'), 'the prompt queue script is still loaded');
	console.log('PASS the panel loads and wires the history screen');
	console.log('history-view: 6 PASS');
})().catch(error => { console.error(error.message); process.exit(1); });
