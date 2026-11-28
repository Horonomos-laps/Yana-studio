// Nhãn phiên bản Studio trên thanh trạng thái lấy từ product.json, không ghi cứng.
const assert = require('node:assert');
const Module = require('node:module');
const path = require('node:path');

const ext = path.resolve(process.argv[2] || path.join(__dirname, '../extensions/yana-agent'));
const origResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
	return request === 'vscode' ? 'vscode' : origResolve.call(this, request, ...rest);
};
require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: { workspace: {}, env: {} } };

const { studioLabel } = require(path.join(ext, 'features/statusbar.js'));

assert.strictEqual(studioLabel('1.1.2'), '$(versions) Yana Studio v1.1.2');
console.log('PASS a known version is shown');
for (const missing of [null, undefined, '']) {
	assert.strictEqual(studioLabel(missing), undefined);
}
console.log('PASS no version, no label');
console.log('statusbar: 2 PASS');
