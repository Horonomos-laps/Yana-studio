// Danh sách nhà cung cấp phải khớp nhau ở mọi nơi hiện nó: catalog, enum cài đặt, app chat, số trên màn hình.
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ext = path.resolve(process.argv[2] || path.join(__dirname, '../extensions/yana-agent'));
const read = file => fs.readFileSync(path.join(ext, file), 'utf8');
const { PROVIDERS, publicCatalog } = require(path.join(ext, 'host/model-catalog.cjs'));
const ids = PROVIDERS.map(p => p.id);

assert.strictEqual(new Set(ids).size, ids.length);
for (const p of PROVIDERS) {
	assert.ok(p.id && p.label && p.baseModels.length, `incomplete entry ${p.id}`);
	if (p.kind === 'cloud') assert.ok(p.requiresKey && p.envVar, `cloud provider ${p.id} must name its key`);
}
console.log('PASS every provider is complete and listed once');

const enumIds = JSON.parse(read('package.json')).contributes.configuration.properties['yana.provider'].enum;
assert.deepStrictEqual([...enumIds].sort(), [...ids].sort());
console.log('PASS the yana.provider setting offers exactly the catalog');

const swift = fs.readFileSync(path.resolve(ext, '../../../yana-app/Sources/YanaApp/AppSettings.swift'), 'utf8');
const block = swift.slice(swift.indexOf('let providerCatalog'), swift.indexOf('final class AppSettings'));
const list = block.slice(block.indexOf('let ids = ['), block.indexOf(']', block.indexOf('let ids = [')));
assert.deepStrictEqual([...list.matchAll(/"([^"]+)"/g)].map(m => m[1]).sort(), [...ids].sort());
console.log('PASS the chat app offers the same providers');

const builtIn = ids.length - 1; // trừ mục custom
const cloudAndRouters = PROVIDERS.filter(p => p.category === 'cloud' || p.category === 'router').length;
for (const file of ['media/welcome.js', 'media/onboarding.js', 'media/settings-models.js']) {
	const stated = read(file).split('\n').filter(line => /provider|nhà cung cấp|공급/i.test(line))
		.flatMap(line => [...line.matchAll(/(?<![\d#.-])(\d{2})(?![\d.])/g)].map(m => Number(m[1])));
	assert.deepStrictEqual([...new Set(stated)].filter(n => n !== builtIn && n !== cloudAndRouters), [], `${file} states a wrong provider count`);
}
assert.ok(!/cat(All|Cloud|Local|Router|Enterprise): '[^']*\(\d+\)'/.test(read('media/settings-models.js')), 'tab labels must not hard-code counts');
console.log('PASS stated counts match and tabs count themselves');

const view = publicCatalog();
const discovery = read('host/model-discovery.cjs');
for (const p of view.filter(item => item.discoverable && item.kind === 'cloud')) {
	assert.ok(new RegExp(`^\\s+"?${p.id}"?: \\{`, 'm').test(discovery), `${p.id} is marked discoverable but has no adapter`);
}
console.log('PASS cloud providers marked discoverable have an adapter');
(async () => {
	const { inspectLocalModels } = require(path.join(ext, 'host/local-models.cjs'));
	const refuse = async () => { throw new Error('offline'); };
	const scanned = (await inspectLocalModels(refuse)).map(item => item.provider).sort();
	const local = PROVIDERS.filter(p => p.kind === 'local').map(p => p.id).sort();
	assert.deepStrictEqual(scanned, local);
	console.log('PASS every local provider is scanned');
	console.log('provider-catalog: 6 PASS');
})().catch(error => { console.error(error.message); process.exit(1); });
