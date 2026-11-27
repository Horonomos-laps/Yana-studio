'use strict';
// API key dùng chung với app chat Yana: yana-rt giữ trong Keychain của macOS, nhập một lần dùng cả hai app.
// IDE chỉ ghi, xoá và hỏi "có hay chưa" qua `yana-rt os credential`, không bao giờ đọc lại key đã dùng chung.
// Key đi qua stdin, không bao giờ qua đối số. Không dùng chung: custom (địa chỉ do người dùng đặt) và 9router
// (http thường); những nhà đó, và mọi nhà khi yana-rt quá cũ hoặc không phải macOS, vẫn nằm trong SecretStorage.
//
// App kia cũng thay đổi kho, nên mọi thao tác đều hỏi trạng thái hiện tại trước. Key IDE giữ từ trước không bao giờ
// bị xoá chỉ vì đã có key dùng chung; nó được đánh dấu "đã thay thế" và bỏ qua, để xoá key chung không làm key cũ
// sống lại.

const vscode = require('vscode');
const { execFile } = require('node:child_process');
const os = require('node:os');
const { publicCatalog } = require('../host/model-catalog.cjs');
const { resolveBinary } = require('../runtime');

const NOT_SHARED = new Set(['custom', '9router']);
const NOT_INSTALLED = 127;
const ALREADY_STORED = 3; // `set --if-absent` thấy đã có key
const MAX_KEY_BYTES = 8 * 1024; // giới hạn của yana-rt
const PROBE_TIMEOUT_MS = 20000;
const CHANGE_TIMEOUT_MS = 120000; // thao tác có thể chờ hộp thoại Keychain; ngắt giữa chừng có thể mất key
const LIST_TIMEOUT_MS = 180000; // yana-rt chờ Keychain tới 60 s rồi chờ nhà cung cấp tới 90 s
const MAX_OUTPUT_BYTES = 8 * 1024 * 1024;

function canShare(id) {
	return !NOT_SHARED.has(id) && publicCatalog().some(p => p.id === id && p.kind === 'cloud');
}

// Chỉ lấy đường dẫn do người dùng đặt ở cấp máy: cấu hình của một thư mục dự án không được chọn chương trình nhận key.
function binary() {
	const setting = vscode.workspace.getConfiguration('yana').inspect?.('runtimePath');
	return resolveBinary(setting?.globalValue || '');
}

// Trả undefined khi không trả lời kịp; status 127 khi chưa cài yana-rt.
function execRuntime(args, input, timeout) {
	return new Promise(resolve => {
		const bin = binary();
		if (!bin) return resolve({ status: NOT_INSTALLED, output: '', error: '' });
		// Kho key thuộc về người dùng, không thuộc thư mục nào: chạy ở thư mục nhà.
		const child = execFile(bin, args, { cwd: os.homedir(), timeout, maxBuffer: MAX_OUTPUT_BYTES }, (error, stdout, stderr) => {
			if (error && typeof error.code !== 'number') return resolve(undefined);
			resolve({ status: error ? error.code : 0, output: String(stdout), error: String(stderr) });
		});
		child.stdin?.on('error', () => {});
		child.stdin?.end(input || '');
	});
}

let runner = execRuntime;
let platform = process.platform;
// 'unsupported' (không có kho), 'unknown' (có thể có nhưng không trả lời), hoặc 'known' kèm tập nhà đã có key.
let state = { kind: 'unknown', held: new Set() };
let emitter;
let queue = Promise.resolve();

const unsupported = () => ({ kind: 'unsupported', held: new Set() });
const unknown = () => ({ kind: 'unknown', held: new Set() });
const known = held => ({ kind: 'known', held });
const has = id => state.held.has(id);
const current = () => state.kind;

function publish(answer) {
	// Không trả lời thì giữ danh sách đã biết, để các nhà dùng chung không đồng loạt thành "chưa có key".
	const next = answer.kind === 'unknown' ? { kind: 'unknown', held: state.held } : answer;
	const differs = next.kind !== state.kind || [...next.held].sort().join() !== [...state.held].sort().join();
	state = next;
	if (differs) emitter?.fire();
}

function parseRows(text) {
	try {
		const rows = JSON.parse(text);
		return Array.isArray(rows) ? rows : undefined;
	} catch {
		return undefined;
	}
}

const flagged = (rows, flag) => new Set(rows.filter(row => row?.[flag] === true && canShare(row.provider)).map(row => row.provider));

// undefined khi không đọc được, hoặc kho không trả lời cho một nhà: lúc đó chưa biết là "không có key".
function parseStatus(text) {
	const rows = parseRows(text);
	if (!rows || rows.some(row => row?.native_secret_unknown === true)) return undefined;
	return flagged(rows, 'native_secret_configured');
}

async function ask() {
	if (platform !== 'darwin') return unsupported();
	// Cờ mới nhất IDE cần: runtime không có nó thì chỉ có một phần kho.
	const probe = await runner(['os', 'credential', 'set', '--help'], '', PROBE_TIMEOUT_MS);
	if (!probe) return unknown();
	if (probe.status !== 0 || !String(probe.output).includes('--if-absent')) return unsupported();
	const status = await runner(['os', 'credential', 'status', '--json'], '', CHANGE_TIMEOUT_MS);
	const held = status?.status === 0 ? parseStatus(status.output) : undefined;
	// removed: key đã bị xoá khỏi kho và chưa lưu lại; bản cũ của nó không được dùng nữa.
	return held ? { ...known(held), removed: flagged(parseRows(status.output), 'native_secret_removed') } : unknown();
}

// Thao tác chạy lần lượt, để một lần hỏi cũ không ghi đè kết quả mới.
function inTurn(work) {
	const result = queue.then(work, work);
	queue = result.catch(() => {});
	return result;
}

// local: { read, exists, write, delete (đều theo id, trả Promise), superseded() -> Set, setSuperseded(Set) }
async function mark(local, id, yes) {
	const set = local.superseded();
	if (set.has(id) === yes) return;
	if (yes) set.add(id); else set.delete(id);
	await local.setSuperseded(set);
}

async function askAndMark(local) {
	const next = await ask();
	for (const id of [...next.held, ...(next.removed || [])]) if (await local.exists(id)) await mark(local, id, true);
	publish(next);
	return next;
}

function failure(reply) {
	if (!reply) return 'yana-rt did not answer';
	return String(reply.error).trim().slice(0, 300) || `yana-rt exited with ${reply.status}`;
}

const refresh = local => inTurn(() => askAndMark(local));

const save = (id, key, local) => inTurn(async () => {
	const now = await askAndMark(local);
	if (Buffer.byteLength(key) > MAX_KEY_BYTES) throw new Error('the key is too long');
	// Chỉ ghi ở IDE khi chắc chắn không có kho chung, nếu không key chung cũ vẫn được dùng.
	if (now.kind === 'unknown') throw new Error('yana-rt did not answer, try again');
	if (now.kind === 'unsupported') {
		await local.write(id, key);
		await mark(local, id, false);
		return;
	}
	const reply = await runner(['os', 'credential', 'set', id], key, CHANGE_TIMEOUT_MS);
	if (reply?.status !== 0) {
		await askAndMark(local);
		throw new Error(failure(reply));
	}
	await local.delete(id);
	await mark(local, id, false);
	publish(known(new Set([...now.held, id])));
});

const remove = (id, local) => inTurn(async () => {
	const now = await askAndMark(local);
	if (now.kind === 'known') {
		// Luôn yêu cầu xoá, kể cả khi trạng thái không liệt kê: xoá thứ không có không phải là lỗi.
		const reply = await runner(['os', 'credential', 'remove', id], '', CHANGE_TIMEOUT_MS);
		if (reply?.status !== 0) {
			await askAndMark(local);
			throw new Error(failure(reply));
		}
		publish(known(new Set([...now.held].filter(other => other !== id))));
	}
	await local.delete(id);
	await mark(local, id, false);
	if (now.kind === 'unknown') throw new Error('yana-rt did not answer, so a shared key may still be stored; remove it again');
});

async function movableNow(ids, local) {
	if (state.kind !== 'known') return [];
	const waiting = [];
	for (const id of ids) {
		if (canShare(id) && !state.held.has(id) && !local.superseded().has(id) && await local.exists(id)) waiting.push(id);
	}
	return waiting;
}

// Chuyển key chỉ IDE đang giữ. Key đã dùng chung được để nguyên vì có thể mới hơn.
const migrate = (ids, local) => inTurn(async () => {
	const now = await askAndMark(local);
	if (now.kind === 'unsupported') return ['this system or yana-rt has no shared key store'];
	if (now.kind !== 'known') return ['yana-rt did not answer, nothing was moved'];
	const failed = [];
	for (const id of await movableNow(ids, local)) {
		const reply = await runner(['os', 'credential', 'set', '--if-absent', id], await local.read(id), CHANGE_TIMEOUT_MS);
		if (reply?.status !== 0 && reply?.status !== ALREADY_STORED) {
			failed.push(`${id}: ${failure(reply)}`);
			continue;
		}
		// App kia vừa lưu: giữ key của nó, bản này để lại và không dùng.
		if (reply.status === ALREADY_STORED) await mark(local, id, true);
		else await local.delete(id);
		publish(known(new Set([...state.held, id])));
	}
	return failed;
});

const hasOldCopy = async (id, local) => local.superseded().has(id) && await local.exists(id);

// Chỉ xoá bản cũ IDE không còn dùng; không đụng kho chung.
const dropOldCopy = (id, local) => inTurn(async () => {
	if (!await hasOldCopy(id, local)) return;
	await local.delete(id);
	await mark(local, id, false);
	emitter?.fire();
});

// JSON danh sách model của chính nhà cung cấp, do yana-rt lấy bằng key đã lưu.
async function modelList(id) {
	const reply = await runner(['os', 'credential', 'models', id], '', LIST_TIMEOUT_MS);
	if (reply?.status !== 0) throw new Error(failure(reply));
	return reply.output;
}

function onDidChange(callback) {
	emitter ||= new vscode.EventEmitter();
	return emitter.event(callback);
}

// Dùng cho test: thay yana-rt thật và hệ điều hành.
function use(fake, as = 'darwin') {
	runner = fake || execRuntime;
	platform = fake ? as : process.platform;
	state = unknown();
}

module.exports = { canShare, current, has, refresh, save, remove, hasOldCopy, dropOldCopy, migrate, movable: movableNow, modelList, parseStatus, onDidChange, use };
