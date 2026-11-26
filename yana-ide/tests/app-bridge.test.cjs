// Cầu yêu cầu từ app chat: chỉ chạy việc trong danh sách, mỗi yêu cầu một lần.
const assert = require('node:assert');
const Module = require('node:module');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ext = path.resolve(process.argv[2] || path.join(__dirname, '../extensions/yana-agent'));
const home = fs.mkdtempSync(path.join(os.tmpdir(), 'yana-bridge-'));
process.env.HOME = home;
const state = path.join(home, 'Library', 'Application Support', 'YanaApp');
const request = path.join(state, 'ide-request.json');
fs.mkdirSync(state, { recursive: true });

const executed = [];
const warnings = [];
const fakeVscode = {
	commands: { executeCommand: async (...args) => executed.push(args) },
	window: {
		createOutputChannel: () => ({ info() {}, warn: text => warnings.push(text), error: text => warnings.push(text), dispose() {} }),
		createTerminal: () => { throw new Error('no terminal expected'); },
		showErrorMessage: () => {},
	},
};
const resolve = Module._resolveFilename;
Module._resolveFilename = function (id, ...rest) { return id === 'vscode' ? 'vscode' : resolve.call(this, id, ...rest); };
require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: fakeVscode };
const bridge = require(path.join(ext, 'features/app-bridge.js'));

function run(body) {
	fs.writeFileSync(request, body);
	const context = { subscriptions: [] };
	bridge.activate(context);
	context.subscriptions.forEach(item => item.dispose());
}

(async () => {
	run(JSON.stringify({ action: 'open-models' }));
	await new Promise(done => setImmediate(done));
	assert.deepStrictEqual(executed, [['yana.settings.open', 'models']]);
	assert.ok(!fs.existsSync(request), 'a request is used once');
	console.log('PASS open-models opens the Models page once');

	for (const bad of ['', 'not json', '{}', '{"action":5}', '{"action":"constructor"}', '{"action":"__proto__"}',
		'{"action":"rm -rf /"}', JSON.stringify({ action: 'open-models', pad: 'a'.repeat(65536) })]) run(bad);
	await new Promise(done => setImmediate(done));
	assert.strictEqual(executed.length, 1);
	console.log('PASS other, malformed and oversized requests run nothing');
	console.log('app-bridge: 2 PASS');
	fs.rmSync(home, { recursive: true, force: true });
})().catch(error => { console.error(error.message); process.exit(1); });
