'use strict';
// Dữ liệu và thao tác của tab Hình nền. Cảnh được vẽ trong workbench (yana-ide/workbench/yanaWallpaper),
// ở đây chỉ đọc và ghi các khóa yana.wallpaper.* sau khi kiểm tra giá trị.

const vscode = require('vscode');
const { WALLPAPERS } = require('../host/wallpaper-catalog.cjs');

const MIN_VISIBILITY = 10;
const MAX_VISIBILITY = 80;
const DEFAULT_VISIBILITY = 35;
const GLYPHS = ['ascii', 'braille', 'blocks', 'katakana'];
const DENSITIES = ['fine', 'normal', 'chunky'];
// Giao diện nguyên bản: không hình nền, dùng đúng theme gốc của Yana.
const PLAIN_THEMES = Object.freeze({ light: 'Yana Light', dark: 'Yana Dark' });

const isTheme = value => value === 'auto' || value === 'off' || WALLPAPERS.some(entry => entry.id === value);

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

module.exports = { data, set, setPlain };
