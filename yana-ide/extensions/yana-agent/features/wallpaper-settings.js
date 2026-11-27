'use strict';
// Dữ liệu và thao tác của tab Hình nền. Cảnh được vẽ trong workbench (yana-ide/workbench/yanaWallpaper),
// ở đây chỉ đọc và ghi các khóa yana.wallpaper.* sau khi kiểm tra giá trị.

const vscode = require('vscode');
const fs = require('node:fs');
const path = require('node:path');
const { WALLPAPERS } = require('../host/wallpaper-catalog.cjs');

const MIN_VISIBILITY = 10;
const MAX_VISIBILITY = 80;
const DEFAULT_VISIBILITY = 35;
const GLYPHS = ['ascii', 'braille', 'blocks', 'katakana'];
const DENSITIES = ['fine', 'normal', 'chunky'];
// Giao diện nguyên bản: không hình nền, dùng đúng theme gốc của Yana.
const PLAIN_THEMES = Object.freeze({ light: 'Yana Light', dark: 'Yana Dark' });
// Đúng các đuôi cửa sổ IDE nạp được (workbench/yanaWallpaper/browser/wallpaperMedia.ts).
const MEDIA_EXTENSIONS = Object.freeze(['png', 'jpg', 'jpeg', 'webp', 'mp4']);
// Lớn hơn mức này thì nạp chậm và tốn bộ nhớ.
const MAX_MEDIA_BYTES = 200 * 1024 * 1024;

const isTheme = value => value === 'auto' || value === 'off' || (value === 'custom' && Boolean(savedFile()))
	|| WALLPAPERS.some(entry => entry.id === value);
const savedFile = () => vscode.workspace.getConfiguration('yana').get('wallpaper.file', '');

const VALIDATORS = {
	theme: isTheme,
	visibility: value => Number.isInteger(value) && value >= MIN_VISIBILITY && value <= MAX_VISIBILITY,
	glyphs: value => GLYPHS.includes(value),
	density: value => DENSITIES.includes(value),
	paused: value => typeof value === 'boolean',
	recolor: value => typeof value === 'boolean',
	reactive: value => typeof value === 'boolean',
};

function data() {
	const cfg = vscode.workspace.getConfiguration('yana');
	return {
		wallpapers: WALLPAPERS,
		fileName: path.basename(cfg.get('wallpaper.file', '')),
		theme: cfg.get('wallpaper.theme', 'auto'),
		visibility: cfg.get('wallpaper.visibility', DEFAULT_VISIBILITY),
		glyphs: cfg.get('wallpaper.glyphs', 'ascii'),
		density: cfg.get('wallpaper.density', 'normal'),
		paused: cfg.get('wallpaper.paused', false),
		colorTheme: vscode.workspace.getConfiguration('workbench').get('colorTheme', ''),
		plainThemes: PLAIN_THEMES,
		recolor: cfg.get('wallpaper.recolor', true),
		reactive: cfg.get('wallpaper.reactive', true),
		limits: { min: MIN_VISIBILITY, max: MAX_VISIBILITY },
		glyphOptions: GLYPHS,
		densityOptions: DENSITIES,
	};
}

async function set(key, value) {
	if (!Object.prototype.hasOwnProperty.call(VALIDATORS, key) || !VALIDATORS[key](value)) {
		throw new Error('Invalid wallpaper setting');
	}
	await vscode.workspace.getConfiguration('yana').update(`wallpaper.${key}`, value, vscode.ConfigurationTarget.Global);
	if (key === 'theme') await matchColorTheme(value);
}

// Màu giao diện chỉ đi theo cảnh khi cùng sáng hoặc cùng tối, nên chọn cảnh thì đổi theme Yana cho khớp.
async function matchColorTheme(id) {
	const scene = WALLPAPERS.find(entry => entry.id === id);
	if (!scene || !vscode.workspace.getConfiguration('yana').get('wallpaper.recolor', true)) return;
	const kind = vscode.window?.activeColorTheme?.kind;
	const light = kind === vscode.ColorThemeKind?.Light;
	const dark = kind === vscode.ColorThemeKind?.Dark;
	if ((scene.light && dark) || (!scene.light && light)) {
		const name = PLAIN_THEMES[scene.light ? 'light' : 'dark'];
		await vscode.workspace.getConfiguration('workbench').update('colorTheme', name, vscode.ConfigurationTarget.Global);
	}
}

async function setPlain(variant) {
	if (!Object.prototype.hasOwnProperty.call(PLAIN_THEMES, variant)) throw new Error('Invalid wallpaper setting');
	await set('theme', 'off');
	await vscode.workspace.getConfiguration('workbench').update('colorTheme', PLAIN_THEMES[variant], vscode.ConfigurationTarget.Global);
}

// Vì sao file không dùng được, hoặc '' nếu dùng được.
function mediaProblem(file) {
	if (!path.isAbsolute(file) || !MEDIA_EXTENSIONS.includes(path.extname(file).slice(1).toLowerCase())) {
		return `Use a ${MEDIA_EXTENSIONS.join(', ')} file`;
	}
	let stat;
	try {
		stat = fs.statSync(file);
	} catch {
		return 'The file cannot be read';
	}
	if (!stat.isFile() || stat.size === 0) return 'The file is empty or not a file';
	return stat.size > MAX_MEDIA_BYTES ? 'The file is larger than 200 MB' : '';
}

async function useFile(file) {
	const problem = mediaProblem(file);
	if (problem) throw new Error(problem);
	const cfg = vscode.workspace.getConfiguration('yana');
	await cfg.update('wallpaper.file', file, vscode.ConfigurationTarget.Global);
	await cfg.update('wallpaper.theme', 'custom', vscode.ConfigurationTarget.Global);
}

// Người dùng chọn file bằng hộp thoại của máy; webview không bao giờ đưa đường dẫn vào.
async function pickFile() {
	const picked = await vscode.window.showOpenDialog({
		canSelectMany: false,
		title: 'Choose a picture or video for the wallpaper',
		filters: { 'Picture or video': [...MEDIA_EXTENSIONS] },
	});
	if (picked?.[0]) await useFile(picked[0].fsPath);
}

async function clearFile() {
	const cfg = vscode.workspace.getConfiguration('yana');
	if (cfg.get('wallpaper.theme', 'auto') === 'custom') await cfg.update('wallpaper.theme', 'auto', vscode.ConfigurationTarget.Global);
	await cfg.update('wallpaper.file', '', vscode.ConfigurationTarget.Global);
}

module.exports = { data, set, setPlain, pickFile, useFile, clearFile, mediaProblem };
