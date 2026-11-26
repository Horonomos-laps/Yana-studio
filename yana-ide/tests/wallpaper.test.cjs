// Kiểm danh sách hình nền khớp workbench, và features/wallpaper-settings.js chỉ ghi giá trị hợp lệ.
const assert = require('node:assert');
const Module = require('node:module');
const path = require('node:path');
const fs = require('node:fs');

const ext = path.resolve(process.argv[2] || path.join(__dirname, '../extensions/yana-agent'));
const written = new Map();
const fakeVscode = {
	ConfigurationTarget: { Global: 1 },
	workspace: { getConfiguration: () => ({ get: (k, d) => (written.has(k) ? written.get(k) : d), update: async (k, v) => written.set(k, v) }) },
};
const origResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
	return request === 'vscode' ? 'vscode' : origResolve.call(this, request, ...rest);
};
require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: fakeVscode };

const { WALLPAPERS } = require(path.join(ext, 'host/wallpaper-catalog.cjs'));
const settings = require(path.join(ext, 'features/wallpaper-settings.js'));
const workbench = path.join(__dirname, '../workbench/yanaWallpaper/browser');
const themes = fs.readFileSync(path.join(workbench, 'themes.ts'), 'utf8');
const scenes = fs.readFileSync(path.join(workbench, 'scenes.ts'), 'utf8');

let passed = 0;
async function test(name, run) {
	await run();
	passed += 1;
	console.log(`PASS ${name}`);
}

(async () => {
	await test('catalog matches workbench themes', () => {
		const ids = [...themes.matchAll(/\{ id: '([a-z]+)'/g)].map(match => match[1]);
		assert.deepStrictEqual(WALLPAPERS.map(entry => entry.id), ids);
		assert.strictEqual(new Set(ids).size, ids.length);
	});
	await test('default scenes for auto exist', () => {
		for (const id of ['moon', 'clouds']) assert.ok(WALLPAPERS.some(entry => entry.id === id), id);
	});
	await test('renderer keeps the upstream licence notice', () => {
		assert.match(scenes, /Copyright \(c\) 2026 Mix4o445/);
		assert.match(themes, /Copyright \(c\) 2026 Mix4o445/);
	});
	await test('defaults when nothing is configured', () => {
		const data = settings.data();
		assert.strictEqual(data.theme, 'auto');
		assert.strictEqual(data.visibility, 35);
		assert.strictEqual(data.paused, false);
	});
	await test('accepts valid values', async () => {
		await settings.set('theme', 'koi');
		await settings.set('visibility', 10);
		await settings.set('visibility', 80);
		await settings.set('glyphs', 'braille');
		await settings.set('density', 'chunky');
		await settings.set('paused', true);
		assert.strictEqual(written.get('wallpaper.theme'), 'koi');
	});
	await test('rejects empty, oversized, hostile and unknown values', async () => {
		written.clear();
		const bad = [
			['theme', ''], ['theme', 'a'.repeat(65536)], ['theme', 'koi\0'], ['theme', '../../etc/passwd'], ['theme', null],
			['visibility', 9], ['visibility', 81], ['visibility', '35'], ['visibility', NaN], ['visibility', 35.5],
			['glyphs', 'emoji'], ['density', ''], ['paused', 'true'],
			['__proto__', true], ['constructor', 'x'], ['', 'x'], ['provider', 'openai'],
		];
		for (const [key, value] of bad) await assert.rejects(settings.set(key, value), /Invalid wallpaper setting/, String(key));
		assert.strictEqual(written.size, 0);
	});
	await test('original light and dark turn the wallpaper off and pick the Yana theme', async () => {
		for (const [variant, name] of [['light', 'Yana Light'], ['dark', 'Yana Dark']]) {
			written.clear();
			await settings.setPlain(variant);
			assert.strictEqual(written.get('wallpaper.theme'), 'off');
			assert.strictEqual(written.get('colorTheme'), name);
		}
	});
	await test('original rejects unknown variants without writing', async () => {
		written.clear();
		for (const bad of ['', 'auto', '__proto__', 'constructor', 'a'.repeat(65536), null, undefined]) {
			await assert.rejects(settings.setPlain(bad), /Invalid wallpaper setting/);
		}
		assert.strictEqual(written.size, 0);
	});
	await test('preview renderer is the same code as the workbench one', () => {
		const body = text => text.slice(text.indexOf("'use strict';"), text.lastIndexOf('})();'));
		const preview = fs.readFileSync(path.join(ext, 'media/wallpaper-scenes.js'), 'utf8');
		assert.strictEqual(body(preview), body(scenes));
		assert.ok(body(scenes).length > 1000);
	});
	await test('catalog carries every colour the preview and recolour need', () => {
		for (const entry of WALLPAPERS) {
			for (const key of ['sky', 'floor', 'beam', 'chrome', 'panel', 'card', 'fg', 'muted', 'border', 'accent', 'ink', 'glyph']) {
				assert.match(entry[key], /^#[0-9a-f]{6}$/i, `${entry.id}.${key}`);
			}
		}
	});
	await test('recolor and reactive accept booleans only', async () => {
		written.clear();
		for (const key of ['recolor', 'reactive']) {
			await settings.set(key, false);
			for (const bad of ['', 'false', 0, null, undefined, {}]) await assert.rejects(settings.set(key, bad), /Invalid wallpaper setting/);
		}
		assert.strictEqual(written.size, 2);
	});
	await test('picking a scene switches to the matching Yana theme', async () => {
		fakeVscode.ColorThemeKind = { Light: 1, Dark: 2, HighContrast: 3 };
		for (const [kind, scene, expected] of [[1, 'moon', 'Yana Dark'], [2, 'clouds', 'Yana Light'], [2, 'moon', undefined], [3, 'clouds', undefined]]) {
			written.clear();
			fakeVscode.window = { activeColorTheme: { kind } };
			await settings.set('theme', scene);
			assert.strictEqual(written.get('colorTheme'), expected, `${kind} ${scene}`);
		}
		written.clear();
		written.set('wallpaper.recolor', false);
		fakeVscode.window = { activeColorTheme: { kind: 1 } };
		await settings.set('theme', 'moon');
		assert.strictEqual(written.get('colorTheme'), undefined);
	});
	await test('running turn count rises and falls with each turn', async () => {
		const runtime = require(path.join(ext, 'runtime.js'));
		const seen = [];
		runtime.activity.on('turns', count => seen.push(count));
		await new Promise(resolve => runtime.startTurn({ binary: '/nonexistent/yana-rt', cwd: __dirname, provider: 'ollama', payload: {} }, () => {}, resolve));
		assert.deepStrictEqual(seen, [1, 0]);
	});
	console.log(`wallpaper: ${passed} PASS`);
})().catch(error => { console.error(error); process.exit(1); });
