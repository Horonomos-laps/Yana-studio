// Tab Hình nền trong Yana Settings: chọn cảnh, độ hiện, bộ ký tự, mật độ.
(function () {
	'use strict';
	const tabs = window.YanaSettingsTabs = window.YanaSettingsTabs || {};

	const TEXT = {
		vi: {
			scenes: 'Cảnh', scenesSub: 'Hình nền động phía sau toàn bộ giao diện.', auto: 'Tự động theo sáng/tối', plain: 'Nguyên bản', plainSub: 'Giao diện gốc một màu, không hình nền.', plainLight: 'Nguyên bản sáng', plainDark: 'Nguyên bản tối',
			search: 'Tìm cảnh', all: 'Tất cả', light: 'Sáng', dark: 'Tối', empty: 'Không có cảnh nào khớp.',
			look: 'Hiển thị', visibility: 'Độ hiện của hình nền', visibilitySub: 'Càng cao càng rõ cảnh, chữ khó đọc hơn.',
			recolor: 'Đổi màu giao diện theo cảnh', recolorSub: 'Thanh bên, nút và viền lấy màu của cảnh.', reactive: 'Phản ứng khi agent chạy', reactiveSub: 'Cảnh nhanh hơn khi Yana đang làm, gợn sóng khi xong.', glyphs: 'Bộ ký tự', density: 'Mật độ lưới', paused: 'Đứng yên', pausedSub: 'Vẽ một khung hình, đỡ tốn pin.',
		},
		ko: {
			scenes: '장면', scenesSub: '전체 화면 뒤에 표시되는 움직이는 배경입니다.', auto: '밝기 테마에 맞춤', plain: '기본', plainSub: '배경 없이 단색의 기본 화면입니다.', plainLight: '기본 밝게', plainDark: '기본 어둡게',
			search: '장면 검색', all: '전체', light: '밝음', dark: '어두움', empty: '일치하는 장면이 없습니다.',
			look: '표시', visibility: '배경 표시 정도', visibilitySub: '높을수록 장면이 선명하고 글자는 읽기 어려워집니다.',
			recolor: '장면에 맞춰 화면 색 바꾸기', recolorSub: '사이드바, 버튼, 테두리가 장면 색을 따릅니다.', reactive: '에이전트 실행에 반응', reactiveSub: 'Yana가 작업 중이면 빨라지고 끝나면 파문이 생깁니다.', glyphs: '문자 세트', density: '격자 밀도', paused: '정지', pausedSub: '정지 화면으로 배터리를 아낍니다.',
		},
		en: {
			scenes: 'Scenes', scenesSub: 'Animated wallpaper behind the whole interface.', auto: 'Follow light or dark theme', plain: 'Original', plainSub: 'The plain original interface, no wallpaper.', plainLight: 'Original light', plainDark: 'Original dark',
			search: 'Search scenes', all: 'All', light: 'Light', dark: 'Dark', empty: 'No scenes match.',
			look: 'Appearance', visibility: 'Wallpaper visibility', visibilitySub: 'Higher shows more of the scene and makes text harder to read.',
			recolor: 'Colour the interface to match', recolorSub: 'Side bar, buttons and borders take the scene colours.', reactive: 'React to agents', reactiveSub: 'The scene speeds up while Yana works and ripples when done.', glyphs: 'Characters', density: 'Grid density', paused: 'Still picture', pausedSub: 'Draw one frame to save battery.',
		},
	};

	const PREVIEW_WIDTH = 160;
	const PREVIEW_HEIGHT = 100;
	// Vẽ vài ô mỗi khung hình để trang không đứng khi có 50 cảnh.
	const PREVIEWS_PER_FRAME = 6;
	let previewFrame = 0;

	function drawPreviews(grid, entries) {
		cancelAnimationFrame(previewFrame);
		let next = 0;
		const step = () => {
			const canvases = grid.querySelectorAll('canvas');
			for (let count = 0; count < PREVIEWS_PER_FRAME && next < entries.length && next < canvases.length; count++, next++) {
				window.drawAsciiScene(canvases[next].getContext('2d'), PREVIEW_WIDTH, PREVIEW_HEIGHT, entries[next], 4, 1, null, {});
			}
			if (next < entries.length) previewFrame = requestAnimationFrame(step);
		};
		previewFrame = requestAnimationFrame(step);
	}

	const tr = key => (TEXT[window.YanaUI.currentLang] || TEXT.en)[key];
	let query = '';
	let filter = 'all';

	function save(key, value) {
		window.YanaUI.request('setWallpaper', { key, value }).then(() => window.YanaUI.load('wallpaper'));
	}

	function row(title, detail, control) {
		const { el } = window.YanaUI;
		const node = el('div', 'item');
		const text = el('div');
		text.append(el('div', '', title));
		if (detail) text.append(el('div', 'muted', detail));
		node.append(text, control);
		return node;
	}

	function select(options, value, onChange) {
		const { el } = window.YanaUI;
		const node = el('select', 'wallpaper-select');
		for (const option of options) {
			const item = el('option', '', option);
			item.value = option;
			node.append(item);
		}
		node.value = value;
		node.addEventListener('change', () => onChange(node.value));
		return node;
	}

	function tile(entry, active) {
		const { el } = window.YanaUI;
		const node = el('button', `wallpaper-tile ${active ? 'active' : ''}`.trim());
		node.type = 'button';
		node.setAttribute('aria-pressed', String(active));
		const preview = el('canvas', 'wallpaper-preview');
		preview.width = PREVIEW_WIDTH;
		preview.height = PREVIEW_HEIGHT;
		preview.setAttribute('aria-hidden', 'true');
		node.append(preview, el('span', '', entry.name));
		node.addEventListener('click', () => save('theme', entry.id));
		return node;
	}

	function plainCard(data) {
		const { el, card, request, load } = window.YanaUI;
		const node = card(tr('plain'), tr('plainSub'));
		const grid = el('div', 'wallpaper-grid');
		for (const [variant, label] of [['light', tr('plainLight')], ['dark', tr('plainDark')]]) {
			const active = data.theme === 'off' && data.colorTheme === data.plainThemes[variant];
			const choice = el('button', `wallpaper-tile ${active ? 'active' : ''}`.trim());
			choice.type = 'button';
			choice.setAttribute('aria-pressed', String(active));
			choice.append(el('span', `wallpaper-swatch wallpaper-plain-${variant}`), el('span', '', label));
			choice.addEventListener('click', () => request('setPlainWallpaper', { variant }).then(() => load('wallpaper')));
			grid.append(choice);
		}
		node.append(grid);
		return node;
	}

	function scenesCard(data) {
		const { el, button, card } = window.YanaUI;
		const node = card(tr('scenes'), tr('scenesSub'));
		const grid = el('div', 'wallpaper-grid');
		const draw = () => {
			const shown = data.wallpapers.filter(entry => (filter === 'all' || (filter === 'light') === entry.light)
				&& entry.name.toLowerCase().includes(query.toLowerCase()));
			grid.replaceChildren(...(shown.length ? shown.map(entry => tile(entry, entry.id === data.theme)) : [el('div', 'muted', tr('empty'))]));
			drawPreviews(grid, shown);
		};
		const modes = el('div', 'row');
		modes.append(button(tr('auto'), data.theme === 'auto' ? 'primary' : '', () => save('theme', 'auto')));
		const search = el('input', 'wallpaper-search');
		search.type = 'search';
		search.placeholder = tr('search');
		search.setAttribute('aria-label', tr('search'));
		search.value = query;
		search.addEventListener('input', () => { query = search.value; draw(); });
		const kinds = select(['all', 'light', 'dark'], filter, value => { filter = value; draw(); });
		for (const option of kinds.options) option.textContent = tr(option.value);
		const tools = el('div', 'row');
		tools.append(search, kinds);
		draw();
		node.append(modes, tools, grid);
		return node;
	}

	function lookCard(data) {
		const { el, card, toggle } = window.YanaUI;
		const node = card(tr('look'));
		const range = el('input');
		range.type = 'range';
		range.min = String(data.limits.min);
		range.max = String(data.limits.max);
		range.value = String(data.visibility);
		range.setAttribute('aria-label', tr('visibility'));
		range.addEventListener('change', () => save('visibility', Number(range.value)));
		const items = el('div', 'list');
		items.append(
			row(tr('visibility'), tr('visibilitySub'), range),
			row(tr('recolor'), tr('recolorSub'), toggle(data.recolor, value => save('recolor', value))),
			row(tr('reactive'), tr('reactiveSub'), toggle(data.reactive, value => save('reactive', value))),
			row(tr('glyphs'), '', select(data.glyphOptions, data.glyphs, value => save('glyphs', value))),
			row(tr('density'), '', select(data.densityOptions, data.density, value => save('density', value))),
			row(tr('paused'), tr('pausedSub'), toggle(data.paused, value => save('paused', value))),
		);
		node.append(items);
		return node;
	}

	tabs.wallpaper = data => [plainCard(data), lookCard(data), scenesCard(data)];
})();
