// Cập nhật yana-rt chỉ được lấy binary do cargo cài từ crates.io. Một thư mục đang mở không được phép
// đưa binary của nó vào ~/.local/bin, vì cả app chat lẫn IDE đều chạy file ở đó.
const assert = require('node:assert');
const childProcess = require('node:child_process');
const Module = require('node:module');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ext = path.resolve(process.argv[2] || path.join(__dirname, '../extensions/yana-agent'));
const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'yana-rt-source-'));
const home = path.join(sandbox, 'home');
const workspace = path.join(sandbox, 'project');
process.env.HOME = home;
process.env.USERPROFILE = home;

function write(file, content) {
	fs.mkdirSync(path.dirname(file), { recursive: true });
	fs.writeFileSync(file, content, { mode: 0o755 });
}

const shared = path.join(home, '.local', 'bin', 'yana-rt');
const cargoBuilt = path.join(home, '.cargo', 'bin', 'yana-rt');
const planted = path.join(workspace, 'target', 'release', 'yana-rt');

// Thay cargo bằng hàm giả: không chạy lệnh thật, không ra mạng.
const commands = [];
let cargoResult = new Error('cargo unavailable');
childProcess.exec = (command, options, callback) => {
	commands.push(command);
	setImmediate(() => callback(cargoResult, '', ''));
};
childProcess.execFile = (file, args, options, callback) => setImmediate(() => callback(null, 'yana-rt 1.0.0\n', ''));

const fakeVscode = {
	ProgressLocation: { Notification: 1 },
	workspace: {
		workspaceFolders: [{ uri: { fsPath: workspace } }],
		isTrusted: true,
		getConfiguration: () => ({ get: (key, fallback) => fallback, update: async () => {} }),
	},
	window: {
		showInformationMessage: async () => undefined,
		showErrorMessage: async () => undefined,
		withProgress: (options, task) => task({ report: () => {} }),
	},
	commands: { executeCommand: async () => undefined, registerCommand: () => ({ dispose() {} }) },
	env: { appRoot: sandbox, openExternal: () => {} },
	Uri: { parse: value => value },
};
const originalResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
	return request === 'vscode' ? 'vscode' : originalResolve.call(this, request, ...rest);
};
require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: fakeVscode };

const updates = require(path.join(ext, 'features/updates.js'));
const text = { updatingRuntime: () => '', runtimeSuccess: () => '', runtimeFailed: () => '', btnOpenTerminal: 'open', btnLater: 'later' };

let passed = 0;
async function test(name, run) {
	fs.rmSync(sandbox, { recursive: true, force: true });
	write(shared, 'shared-original');
	write(planted, 'planted-by-project');
	commands.length = 0;
	cargoResult = new Error('cargo unavailable');
	await run();
	passed += 1;
	console.log(`PASS ${name}`);
}

(async () => {
	await test('a binary inside the open folder never replaces the shared runtime', async () => {
		await updates.performRuntimeUpdate('9.9.9', text);
		assert.strictEqual(fs.readFileSync(shared, 'utf8'), 'shared-original');
	});
	await test('the update installs from crates.io even when the folder has a build', async () => {
		await updates.performRuntimeUpdate('9.9.9', text);
		assert.deepStrictEqual(commands, ['cargo install yana-rt --force']);
	});
	await test('a successful cargo install is copied to the shared runtime', async () => {
		write(cargoBuilt, 'from-cargo');
		cargoResult = null;
		await updates.performRuntimeUpdate('1.0.0', text);
		assert.strictEqual(fs.readFileSync(shared, 'utf8'), 'from-cargo');
	});
	fs.rmSync(sandbox, { recursive: true, force: true });
	console.log(`runtime-update-source: ${passed} PASS`);
})().catch(error => {
	console.error(error.message);
	fs.rmSync(sandbox, { recursive: true, force: true });
	process.exit(1);
});
