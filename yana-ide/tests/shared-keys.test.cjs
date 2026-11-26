// API key dùng chung: key đi qua stdin, không ghi đè key mới hơn, key cũ không sống lại. Không đụng yana-rt thật.
const assert = require('node:assert');
const Module = require('node:module');
const path = require('node:path');

const ext = path.resolve(process.argv[2] || path.join(__dirname, '../extensions/yana-agent'));
const world = { secrets: new Map(), global: new Map(), shared: new Map(), calls: [], probe: 0, silent: false, refuse: false };
const picks = [];
const fakeVscode = {
	EventEmitter: class { constructor() { this.listeners = []; } get event() { return fn => { this.listeners.push(fn); return { dispose() {} }; }; } fire() { this.listeners.forEach(fn => fn()); } dispose() {} },
	workspace: { getConfiguration: () => ({ get: (_k, d) => d, inspect: () => ({ workspaceValue: '/tmp/planted', globalValue: '' }), update: async () => {} }) },
	window: {
		showInformationMessage: async () => undefined, showWarningMessage: async () => undefined, showErrorMessage: async () => undefined,
		showQuickPick: async items => { picks.push(items); return undefined; }, showInputBox: async () => undefined,withProgress: async (_o, work) => work(),
		createTreeView: () => ({ dispose() {} }), registerTreeDataProvider: () => ({ dispose() {} }), onDidChangeWindowState: () => ({ dispose() {} }),
	},
	commands: { registerCommand: () => ({ dispose() {} }) },
	ProgressLocation: { Notification: 1 }, QuickPickItemKind: { Separator: -1 },TreeItem: class {}, ThemeIcon: class {}, TreeItemCollapsibleState: { None: 0 }, ConfigurationTarget: { Global: 1 },
};
const resolve = Module._resolveFilename;
Module._resolveFilename = function (id, ...rest) { return id === 'vscode' ? 'vscode' : resolve.call(this, id, ...rest); };
require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: fakeVscode };
const shared = require(path.join(ext, 'features/shared-keys.js'));
const models = require(path.join(ext, 'features/models.js'));

async function runtime(args, input) {
	world.calls.push({ args, input });
	const [, , verb, id] = args;
	const reply = (status, output = '', error = '') => ({ status, output, error });
	if (id === '--help') return world.probe === undefined ? undefined : reply(world.probe);
	if (verb === 'status') return world.silent ? undefined : reply(0, JSON.stringify([...world.shared.keys()].map(provider => ({ provider, native_secret_configured: true }))));
	if (verb === 'models') return reply(0, JSON.stringify({ data: [{ id: 'gpt-x' }, { id: 'text-embedding-3' }] }));
	if (world.refuse) return reply(2, '', '[os] locked\n');
	if (verb === 'set') world.shared.set(id, input); else world.shared.delete(id);
	return reply(0);
}

const local = id => world.secrets.get(`yana.key.${id}`);

(async () => {
	for (const id of ['openai', 'mistral']) assert.ok(shared.canShare(id), id);
	for (const id of ['custom', '9router', 'ollama', 'vllm', '', 'OpenAI', 'a'.repeat(65536)]) assert.ok(!shared.canShare(id), String(id).slice(0, 12));
	for (const bad of ['', 'x', '{}', 'null', '\u0000']) assert.strictEqual(shared.parseStatus(bad), undefined);
	console.log('PASS only catalog cloud providers are shared');

	shared.use(runtime);
	models.activate({
		subscriptions: [],
		secrets: { get: async k => world.secrets.get(k), store: async (k, v) => world.secrets.set(k, v), delete: async k => world.secrets.delete(k) },
		globalState: { get: (k, d) => (world.global.has(k) ? world.global.get(k) : d), update: async (k, v) => world.global.set(k, v) },
	});

	for (const [platform, probe] of [['linux', 0], ['win32', 0], ['darwin', 2], ['darwin', 127]]) {
		shared.use(runtime, platform);
		world.probe = probe;
		await models.saveKey('openai', `sk-${platform}-${probe}`);
		assert.strictEqual(local('openai'), `sk-${platform}-${probe}`);
		assert.strictEqual(world.shared.size, 0);
	}
	console.log('PASS without a store (other system, old or missing runtime) keys stay in the IDE');

	shared.use(runtime);
	world.probe = 0;
	world.silent = true;
	await assert.rejects(models.saveKey('openai', 'sk-typed'), /did not answer/);
	assert.notStrictEqual(local('openai'), 'sk-typed', 'nothing is written only locally on a transient failure');
	await assert.rejects(models.forgetKey('openai'), /may still be stored/);
	world.silent = false;
	world.shared.set('groq', 'x');
	await models.refreshKeys();
	world.silent = true;
	await models.refreshKeys();
	assert.strictEqual(await models.hasKey('groq'), true, 'a silent runtime does not forget the known keys');
	world.silent = false;
	world.shared.clear();
	console.log('PASS no answer means no silent local write and no false "removed"');

	world.secrets.set('yana.key.openai', 'sk-old');
	world.secrets.set('yana.key.groq', 'gsk-mine');
	world.shared.set('openai', 'sk-newer-from-the-app');
	world.refuse = true;
	assert.strictEqual((await models.shareLocalKeys()).length, 1);
	assert.strictEqual(local('groq'), 'gsk-mine', 'kept when the store refused');
	world.refuse = false;
	world.calls.length = 0;
	assert.deepStrictEqual(await models.shareLocalKeys(), []);
	assert.strictEqual(world.shared.get('openai'), 'sk-newer-from-the-app', 'never overwritten');
	assert.strictEqual(world.shared.get('groq'), 'gsk-mine');
	const sets = world.calls.filter(c => c.args[2] === 'set');
	assert.deepStrictEqual(sets.map(c => c.args), [['os', 'credential', 'set', 'groq']]);
	assert.ok(!world.secrets.has('yana.key.groq'));
	console.log('PASS migration moves over stdin and never overwrites a shared key');

	assert.strictEqual(await models.keyFor('openai'), '');
	world.shared.delete('openai');
	await models.refreshKeys();
	assert.strictEqual(local('openai'), 'sk-old', 'kept, not deleted');
	assert.strictEqual(await models.keyFor('openai'), '', 'an old local key does not come back');
	assert.strictEqual(await models.hasKey('openai'), false);
	console.log('PASS removing the shared key elsewhere does not revive the old one');

	world.shared.set('mistral', 'saved-after-the-last-look');
	await models.forgetKey('mistral');
	assert.ok(!world.shared.has('mistral'), 'removed although the cache did not list it');
	console.log('PASS remove also removes a key saved by the other app meanwhile');

	await models.refreshKeys();
	assert.strictEqual(await models.hasKey('groq'), true);
	assert.deepStrictEqual(await models.fetchModels('groq', ''), ['gpt-x']);
	for (const id of ['groq', 'ollama', 'openai']) await models.chooseModel(id);
	assert.ok(picks.length >= 2, 'the model list opens');
	console.log('PASS a shared key lists models and choosing a model works');
	console.log('shared-keys: 7 PASS');
})().catch(error => { console.error(error.stack); process.exit(1); });
